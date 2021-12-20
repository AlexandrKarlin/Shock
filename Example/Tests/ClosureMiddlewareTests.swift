//
//  ClosureMiddlewareTests.swift
//  Shock_Tests
//
//  Created by Jack Newcombe on 07/10/2020.
//  Copyright © 2018 Just Eat. All rights reserved.
//

import XCTest
import Shock

class ClosureMiddlewareTests: ShockTestCase {

    func testSimpleClosureMiddleware() {
        
        let expectedResponseBody = "Test Response Body"
        let expectedHeaders = [ "X-Test-Header": "Test" ]
        let expectedStatusCode = 200
        
        let middleware = ClosureMiddleware { request, response, next in
            response.statusCode = expectedStatusCode
            response.headers = expectedHeaders
            response.responseBody = expectedResponseBody.data(using: .utf8)
            next()
        }
        server.add(middleware: middleware)
        
        let getExpectation = expectation(description: "GET request succeeeds")
        HTTPClient.get(url: "\(server.hostURL)/") { code, body, headers, error in
            XCTAssertNil(error)
            XCTAssertEqual(code, expectedStatusCode)
            expectedHeaders.forEach {
                XCTAssertEqual(headers[$0.key], $0.value)
            }
            XCTAssertEqual(body, expectedResponseBody)
            getExpectation.fulfill()
        }

        let postExpectation = expectation(description: "GET request succeeeds")
        HTTPClient.post(url: "\(server.hostURL)/") { code, body, headers, error in
            XCTAssertNil(error)
            XCTAssertEqual(code, expectedStatusCode)
            expectedHeaders.forEach {
                XCTAssertEqual(headers[$0.key], $0.value)
            }
            XCTAssertEqual(body, expectedResponseBody)
            postExpectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout)
    }
    
    func testMiddlewareReplace() {
        
        let expectedHeaders = [ "X-Test-Header": "Test" ]
        let route: MockHTTPRoute = .custom(method: .get,
                                           urlPath: "/testendpoint",
                                           query: [:],
                                           requestHeaders: [:],
                                           requestBody: nil,
                                           responseHeaders: ["responseHeader": "responseHeaderValue"],
                                           code: 200,
                                           filename: "testCustomRoute.txt")
        
        
        let middleware = ClosureMiddleware { request, response, next in
            if request.path == "/testendpoint" {
                response.responseBody = "hello world".data(using: .utf8)
                response.headers = expectedHeaders
            }
            next()
        }
        self.server.setup(route: route)
        
        let expectation = self.expectation(description: "Middleware test")
        HTTPClient.get(url: "\(server.hostURL)/testendpoint") { code, body, headers, error in
            XCTAssertEqual(code, 200)
            XCTAssertEqual(body, "testCustomRoute test fixture\n")
            print("\(body)")
            
            self.server.replace(middleware: [middleware, ])
            
            HTTPClient.get(url: "\(self.server.hostURL)/testendpoint") { code2, body2, headers2, error2 in
                
                print("\(body2)")
                XCTAssertEqual(body2, "hello world")
                expectedHeaders.forEach {
                    XCTAssertEqual(headers2[$0.key], $0.value)
                }
                
                expectation.fulfill()
            }
            
        }
        self.waitForExpectations(timeout: timeout, handler: nil)
    }
}
