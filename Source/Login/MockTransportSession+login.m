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
@import WireTesting;
@import WireProtos;
#import "MockTransportSession+assets.h"
#import "MockTransportSession+OTR.h"
#import "MockAsset.h"
#import <WireMockTransport/WireMockTransport-Swift.h>

static NSString * const HardcodedAccessToken = @"5hWQOipmcwJvw7BVwikKKN4glSue1Q7REFVR2hCk6r9AtUXtUX1YpC3NFdrA-KjztS6AgxgrnZSgcyFIHrULCw==.1403273423.a.39562cc3-717d-4395-979c-5387ae17f5c3.6885777252650447174";

@implementation MockTransportSession (Login)

/// handles /login
- (ZMTransportResponse *)processLoginRequest:(ZMTransportRequest *)request;
{
    if([request matchesWithPath:@"/login" method:ZMMethodPOST]) {
        NSString *password = [request.payload.asDictionary optionalStringForKey:@"password"];
        NSString *email = [request.payload.asDictionary optionalStringForKey:@"email"];
        NSString *phone = [request.payload.asDictionary optionalStringForKey:@"phone"];
        NSString *code = [request.payload.asDictionary optionalStringForKey:@"code"];
        
        if((password == nil || email == nil) && (code == nil || phone == nil)) {
            return [self errorResponseWithCode:400 reason:@"missing-key"];
        }
        
        if(phone != nil
           && (
               ! [self.phoneNumbersWaitingForVerificationForLogin containsObject:phone] ||
               ! [self.phoneVerificationCodeForLogin isEqualToString:code]
               )
           )
        {
            return [self errorResponseWithCode:404 reason:@"invalid-key"];
        }
        
        NSFetchRequest *fetchRequest = [MockUser sortedFetchRequest];
        if(email != nil) {
            fetchRequest.predicate = [NSPredicate predicateWithFormat: @"email == %@ AND password == %@", email, password];
        }
        else if(phone != nil) {
            fetchRequest.predicate = [NSPredicate predicateWithFormat: @"phone == %@", phone];
        }
        
        NSArray *users = [self.managedObjectContext executeFetchRequestOrAssert:fetchRequest];
        
        if (users.count < 1) {
            return [self errorResponseWithCode:403 reason:@"invalid-credentials"];
        }
        
        
        MockUser *user = users[0];
        if(!user.isEmailValidated) {
            return [self errorResponseWithCode:403 reason:@"pending-activation"];
        }
        
        if(phone != nil) {
            [self.phoneNumbersWaitingForVerificationForLogin removeObject:phone];
        }
        
        NSString *cookiesValue = @"fake cookie";

        if ([ZMPersistentCookieStorage cookiesPolicy] != NSHTTPCookieAcceptPolicyNever) {
            self.cookieStorage.authenticationCookieData = [cookiesValue dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        self.selfUser = user;
        self.clientCompletedLogin = YES;
        
        NSDictionary *responsePayload = @{
                                          @"access_token" : HardcodedAccessToken,
                                          @"expires_in" : @900,
                                          @"token_type" : @"Bearer",
                                          @"user": user.identifier
                                          };

        NSDictionary *headers = @{ @"Set-Cookie": [NSString stringWithFormat:@"zuid=%@", cookiesValue] };
        return [ZMTransportResponse responseWithPayload:responsePayload HTTPStatus:200 transportSessionError:nil headers:headers];
    }
    return [self errorResponseWithCode:400 reason:@"invalid-method"];
}

/// handles /login/send
- (ZMTransportResponse *)processLoginCodeRequest:(ZMTransportRequest *)request;
{
    if ([request matchesWithPath:@"/login/send" method:ZMMethodPOST]) {
        NSString *phone = [request.payload.asDictionary optionalStringForKey:@"phone"];
        
        if(phone == nil) {
            [self errorResponseWithCode:400 reason:@"missing-key"];
        }
        
        NSFetchRequest *fetchRequest = [MockUser sortedFetchRequest];
        fetchRequest.predicate = [NSPredicate predicateWithFormat: @"phone == %@", phone];
        NSArray *users = [self.managedObjectContext executeFetchRequestOrAssert:fetchRequest];
        
        if (users.count < 1) {
            return [self errorResponseWithCode:404 reason:@"not-found"];
        }
        else {
            [self.phoneNumbersWaitingForVerificationForLogin addObject:phone];
            return [ZMTransportResponse responseWithPayload:nil HTTPStatus:200 transportSessionError:nil];
        }
        
    }
    return [self errorResponseWithCode:400 reason:@"invalid-method"];
}



@end
