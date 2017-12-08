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
        let data = DataUnit(myProperty: "Some value")

        connection.send(data: data, for: DataUnitType.testType) { reply in
            switch reply {
            case .success(let value):
                XCTAssertTrue(value == nil)
            case .error:
                XCTFail("Evaluation failed")
            }
        }

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"type\":\"testType\",\"data\":{\"myProperty\":\"Some value\"}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand)
    }

    func testReceive() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)
        let promise = expectation(description: "async")

        connection.addHandler(for: DataUnitType.testType) { (data: DataUnit, _) in
            XCTAssertEqual("Some value", data.myProperty)
            promise.fulfill()
        }

        let data = ["myProperty": "Some value"]
        connection.receive(payload: ["type": "testType", "data": data])
        wait(for: [promise], timeout: 1)
    }

    func testReceive_illegalPayloadFormat() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        connection.receive(payload: "illegal format")

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"type\":\"error\",\"data\":{\"errors\":[{\"message\":\"Illegal payload format\",\"errorCode\":1}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }

    func testReceive_missingPayloadFields() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        connection.receive(payload: ["missing": "types"])

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"type\":\"error\",\"data\":{\"errors\":[{\"message\":\"Missing field: 'type'\",\"errorCode\":2},{\"message\":\"Missing field: 'data'\",\"errorCode\":3}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }

    func testReceive_missingDataPayloadFields() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        connection.receive(payload: ["type": "testType"])

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"type\":\"testType\",\"data\":{\"errors\":[{\"message\":\"Missing field: 'data'\",\"errorCode\":3}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }

    func testReceive_missingHandler() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        let data = ["myProperty": "Some value"]
        connection.receive(payload: ["type": "testType", "data": data])

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"type\":\"testType\",\"data\":{\"errors\":[{\"message\":\"Missing type handler\",\"errorCode\":4}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }

    func testReceive_invalidData() {
        let evaluator = Evaluator({ (nil, nil) })
        let connection = WebViewConnection(webView: evaluator)

        connection.addHandler(for: DataUnitType.testType) { (_: DataUnit, _) in }

        let data = ["unknownProperty": "Some value"]
        connection.receive(payload: ["type": "testType", "data": data])

        let expectedScript = "window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":{\"type\":\"testType\",\"data\":{\"errors\":[{\"message\":\"Invalid data for type. Expected data type: 'DataUnit'\",\"errorCode\":5}]}}}))"
        XCTAssertEqual(expectedScript, evaluator.lastCommand!)
    }
}

enum DataUnitType: String, TypeRepresentable {
    case testType

    var key: String {
        return rawValue
    }
}

struct DataUnit: Codable {
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
