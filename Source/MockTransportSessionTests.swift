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

import Foundation

extension MockTransportSessionTests {
    
    func response(forAssetData assetData: Data, contentType: String, path: String) -> ZMTransportResponse? {
        let expectation = self.expectation(description: "Got an asset response")
        
        var response: ZMTransportResponse?
        let result = sut.mockedTransportSession().attemptToEnqueueSyncRequest {
            let request = ZMTransportRequest.multipartRequest(withPath: path, imageData: assetData, metaData: [:], mediaContentType: contentType)
            let completion = ZMCompletionHandler(on: self.fakeSyncContext) {
                response = $0
                expectation.fulfill()
            }
            request?.add(completion)
            return request
        }
        
        XCTAssertTrue(result.didHaveLessRequestThanMax)
        XCTAssertTrue(result.didGenerateNonNullRequest)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        return response
    }
    
}
