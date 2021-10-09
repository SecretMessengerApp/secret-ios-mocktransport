////
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

import Foundation

extension MockTransportSession {

    @objc(fetchConversationWithIdentifier:)
    public func fetchConversation(with identifier: String) -> MockConversation? {
        let request = MockConversation.sortedFetchRequest()
        request.predicate = NSPredicate(format: "identifier == %@", identifier.lowercased())
        let conversations = managedObjectContext.executeFetchRequestOrAssert(request) as? [MockConversation]
        return conversations?.first
    }
    
    @objc(processReceiptModeUpdateForConversation:payload:)
    public func processReceiptModeUpdate(for conversationId: String, payload: [String:  AnyHashable]) -> ZMTransportResponse {
        guard let conversation = fetchConversation(with: conversationId) else {
            return ZMTransportResponse(payload: nil, httpStatus: 404, transportSessionError: nil)
        }
        guard let receiptMode = payload["receipt_mode"] as? Int else {
            return ZMTransportResponse(payload: nil, httpStatus: 400, transportSessionError: nil)
        }
        guard receiptMode != conversation.receiptMode?.intValue else {
            return ZMTransportResponse(payload: nil, httpStatus: 204, transportSessionError: nil)
        }
        
        conversation.receiptMode = NSNumber(value: receiptMode)
        
        let responsePayload = [
            "conversation" : conversation.identifier,
            "type" : "conversation.receipt-mode-update",
            "time" : NSDate().transportString(),
            "from" : selfUser.identifier,
            "data" : ["receipt_mode": receiptMode]] as ZMTransportData
        
        return ZMTransportResponse(payload: responsePayload, httpStatus: 200, transportSessionError: nil)
    }

    @objc(processAccessModeUpdateForConversation:payload:)
    public func processAccessModeUpdate(for conversationId: String, payload: [String : AnyHashable]) -> ZMTransportResponse {
        guard let conversation = fetchConversation(with: conversationId) else {
            return ZMTransportResponse(payload: nil, httpStatus: 404, transportSessionError: nil)
        }
        guard let accessRole = payload["access_role"] as? String else {
            return ZMTransportResponse(payload: nil, httpStatus: 400, transportSessionError: nil)
        }
        guard let access = payload["access"] as? [String] else {
            return ZMTransportResponse(payload: nil, httpStatus: 400, transportSessionError: nil)
        }

        conversation.accessRole = accessRole
        conversation.accessMode = access

        let responsePayload = [
            "conversation" : conversation.identifier,
            "type" : "conversation.access-update",
            "time" : NSDate().transportString(),
            "from" : selfUser.identifier,
            "data" : [
                "access_role" : conversation.accessRole,
                "access" : conversation.accessMode
            ]
        ] as ZMTransportData
        return ZMTransportResponse(payload: responsePayload, httpStatus: 200, transportSessionError: nil)
    }
    
    @objc(processFetchLinkForConversation:payload:)
    public func processFetchLink(for conversationId: String, payload: [String: AnyHashable]) -> ZMTransportResponse {
        guard let conversation = fetchConversation(with: conversationId) else {
            return ZMTransportResponse(payload: nil, httpStatus: 404, transportSessionError: nil)
        }
        
        guard Set(conversation.accessMode) == Set(["invite", "code"]) else {
            return ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
        }
        
        guard let link = conversation.link else {
            return ZMTransportResponse(payload: ["label": "no-conversation-code"] as ZMTransportData, httpStatus: 404, transportSessionError: nil)
        }
        
        return ZMTransportResponse(payload: ["uri": link,
                                             "key": "test-key",
                                             "code": "test-code"] as ZMTransportData, httpStatus: 200, transportSessionError: nil)
    }
    
    @objc(processCreateLinkForConversation:payload:)
    public func processCreateLink(for conversationId: String, payload: [String: AnyHashable]) -> ZMTransportResponse {
        guard let conversation = fetchConversation(with: conversationId) else {
            return ZMTransportResponse(payload: nil, httpStatus: 404, transportSessionError: nil)
        }
        
        guard Set(conversation.accessMode) == Set(["invite", "code"]) else {
            return ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
        }
        
        // link already exists
        if let link = conversation.link {
            return ZMTransportResponse(payload: ["uri": link,
                                                 "key": "test-key",
                                                 "code": "test-code"] as ZMTransportData, httpStatus: 200, transportSessionError: nil)
        }
        // new link must be created
        else {
            let link = "https://wire-website.com/test-link"
            
            conversation.link = link
            
            let payload = [
                    "conversation" : conversationId,
                    "data" : [
                        "uri" : link,
                        "key" : "test-key",
                        "code" : "test-code"
                    ],
                    "type" : "conversation.code-update",
                    "time" : NSDate().transportString(),
                    "from" : selfUser.identifier
            ] as ZMTransportData
            return ZMTransportResponse(payload: payload, httpStatus: 201, transportSessionError: nil)
        }
        
    }
    
    @objc(processDeleteLinkForConversation:payload:)
    public func processDeleteLink(for conversationId: String, payload: [String: AnyHashable]) -> ZMTransportResponse {
        guard let conversation = fetchConversation(with: conversationId) else {
            return ZMTransportResponse(payload: nil, httpStatus: 404, transportSessionError: nil)
        }
        
        guard Set(conversation.accessMode) == Set(["invite", "code"]) else {
            return ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
        }
        
        // link already exists
        if let _ = conversation.link {
            conversation.link = nil
            return ZMTransportResponse(payload: nil, httpStatus: 200, transportSessionError: nil)
        }
        // new link must be created
        else {
            return ZMTransportResponse(payload: nil, httpStatus: 403, transportSessionError: nil)
        }
    }
}
