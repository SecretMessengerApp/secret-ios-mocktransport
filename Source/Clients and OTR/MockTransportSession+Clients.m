// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


@import WireTransport;
@import WireUtilities;

#import "MockTransportSession+Clients.h"
#import "MockTransportSession+internal.h"
#import <WireMockTransport/WireMockTransport-Swift.h>


@implementation MockTransportSession (Clients)

// /clients
- (ZMTransportResponse *)processClientsRequest:(ZMTransportRequest *)request;
{
    if ([request matchesWithPath:@"/clients" method:ZMMethodPOST]) {
        return [self processRegisterClientWithPayload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/clients" method:ZMMethodGET]) {
        return [self processGetClientsListRequest];
    }
    else if ([request matchesWithPath:@"/clients/*" method:ZMMethodGET]) {
        return [self processGetClientById:[request RESTComponentAtIndex:1]];
    }
    else if ([request matchesWithPath:@"/clients/*" method:ZMMethodPUT]) {
        return [self processUpdateClient:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/clients/*" method:ZMMethodDELETE]) {
        return [self processDeleteClientRequest:[request RESTComponentAtIndex:1]];
    }
    else if ([request matchesWithPath:@"/clients/*/prekeys" method:ZMMethodGET]) {
        return [self processClientPreKeysForClient:[request RESTComponentAtIndex:1]];
    }
    return [self errorResponseWithCode:400 reason:@"invalid method"];
}

static NSInteger const MaxUserClientsAllowed = 2;

- (ZMTransportResponse *)processRegisterClientWithPayload:(NSDictionary *)payload
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"UserClient"];
    NSArray *existingClients = [self.managedObjectContext executeFetchRequestOrAssert:fetchRequest];
    if (existingClients.count == MaxUserClientsAllowed) {
        return [self errorResponseWithCode:403 reason:@"too-many-clients"];
    }
    
    BOOL selfClientExists = nil != [existingClients firstObjectMatchingWithBlock:^BOOL(MockUserClient *userClient){
        return userClient.user == self.selfUser;
    }];
    
    NSString *password = [payload optionalStringForKey:@"password"];
    if (selfClientExists &&
        !(password != nil && [password isEqualToString:self.selfUser.password])) {
        return [self errorResponseWithCode:403 reason:@"missing-auth"];
    }
    
    MockUserClient *newClient = [MockUserClient insertClientWithPayload:payload context:self.managedObjectContext];
    newClient.user = self.selfUser;
    
    if (newClient != nil) {
        return [ZMTransportResponse responseWithPayload:[newClient transportData] HTTPStatus:200 transportSessionError:nil];
    }
    
    return [self errorResponseWithCode:400 reason:@"bad request"];
}

- (MockUserClient *)userClientByIdentifier:(NSString *)identifier
{
    NSFetchRequest *request = [MockUserClient fetchRequestWithPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]];
    
    NSArray *userClients = [self.managedObjectContext executeFetchRequestOrAssert:request];
    RequireString(userClients.count <= 1, "Too many user clients with one identifier");
    
    return userClients.firstObject;
}

- (ZMTransportResponse *)processGetClientsListRequest
{
    NSArray *payload = [self.selfUser.clients mapWithBlock:^id(MockUserClient *client) {
        return [client transportData];
    }].allObjects;
    return [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
}

- (ZMTransportResponse *)processGetClientById:(NSString *)clientId
{
    MockUserClient *userClient = [self userClientByIdentifier:clientId];
    if (userClient == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    return [ZMTransportResponse responseWithPayload:userClient.transportData HTTPStatus:200 transportSessionError:nil];
}

- (ZMTransportResponse *)processClientPreKeysForClient:(NSString *__unused)clientId
{
    return [self errorResponseWithCode:418 reason:@"Not implemented"];
}

- (ZMTransportResponse *)processUpdateClient:(NSString *__unused)clientId payload:(NSDictionary *__unused)payload;
{
    return [self errorResponseWithCode:418 reason:@"Not implemented"];
}

- (ZMTransportResponse *)processDeleteClientRequest:(NSString *)clientId;
{
    MockUserClient *userClient = [self userClientByIdentifier:clientId];
    if (userClient == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    [self.managedObjectContext deleteObject:userClient];
    
    return [ZMTransportResponse responseWithPayload:nil HTTPStatus:200 transportSessionError:nil];    
}


@end
