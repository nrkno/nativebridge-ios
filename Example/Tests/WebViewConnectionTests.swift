//
//  WebViewConnectionTests.swift
//  nrk.no
//
//  Created by Johan Sørensen on 12/07/2017.
//  Copyright © 2017 NRK. All rights reserved.
//

import XCTest
import NativeBridge

class WebViewConnectionTests: XCTestCase {

    func testSendMessage() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)
        let data = TestDataObject(myProperty: "Some value")

        connection.send(data: data, for: Topic.test) { reply in
            switch reply {
            case .success(let value):
                XCTAssertTrue(value == nil)
            case .error:
                XCTFail("Evaluation failed")
            }
        }

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"topic\":\"test\",\"data\":{\"myProperty\":\"Some value\"}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand)
    }

    func testReceive() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)
        let promise = expectation(description: "async")

        connection.addHandler(for: Topic.test) { (data: TestDataObject, _) in
            XCTAssertEqual("Some value", data.myProperty)
            promise.fulfill()
        }

        let data = ["myProperty": "Some value"]
        connection.receive(payload: ["topic": "test", "data": data])
        wait(for: [promise], timeout: 1)
    }

    func testReceive_illegalPayloadFormat() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        connection.receive(payload: "illegal format")

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"topic\":\"error\",\"data\":{\"errors\":[{\"message\":\"Illegal payload format\",\"errorCode\":1}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }

    func testReceive_missingPayloadFields() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        connection.receive(payload: ["missing": "fields"])

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"topic\":\"error\",\"data\":{\"errors\":[{\"message\":\"Missing field: 'topic'\",\"errorCode\":2},{\"message\":\"Missing field: 'data'\",\"errorCode\":3}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }

    func testReceive_missingDataPayloadFields() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        connection.receive(payload: ["topic": "test"])

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"topic\":\"test\",\"data\":{\"errors\":[{\"message\":\"Missing field: 'data'\",\"errorCode\":3}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }

    func testReceive_missingHandler() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        let data = ["myProperty": "Some value"]
        connection.receive(payload: ["topic": "test", "data": data])

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"topic\":\"test\",\"data\":{\"errors\":[{\"message\":\"Missing topic handler\",\"errorCode\":4}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }

    func testReceive_invalidData() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        connection.addHandler(for: Topic.test) { (_: TestDataObject, _) in }

        let data = ["unknownProperty": "Some value"]
        connection.receive(payload: ["topic": "test", "data": data])

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"topic\":\"test\",\"data\":{\"errors\":[{\"message\":\"Invalid data for topic. Expected data type: 'TestDataObject'\",\"errorCode\":5}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }
}

enum Topic: String, TopicRepresentable {
    case test

    var name: String { return rawValue }
}

struct TestDataObject: Codable {
    var myProperty: String
}

private final class Evaluator: JavascriptEvaluating {
    typealias EvaluationResult = (Any?, Error?)

    let evaluator: () -> (EvaluationResult)
    var lastCommand: String?

    init(_ evaluator: @escaping () -> (EvaluationResult)) {
        self.evaluator = evaluator
    }

    func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)?) {
        lastCommand = javaScriptString
        let result = evaluator()
        completionHandler?(result.0, result.1)
    }
}
