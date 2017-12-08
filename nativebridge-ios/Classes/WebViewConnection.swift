//
//  WebViewMessageHandler.swift
//  nrk.no
//
//  Created by Johan Sørensen on 11/07/2017.
//  Copyright © 2017 NRK. All rights reserved.
//

import Foundation
import WebKit

public protocol JavascriptEvaluating {
    func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)?)
}

extension WKWebView: JavascriptEvaluating {}

private extension Encodable {
    var data: Data {
        return try! JSONEncoder().encode(self)
    }

    var json: Any {
        return try! JSONSerialization.jsonObject(with: data, options: [])
    }
}

extension JSONSerialization {
    static func from<T>(data: Data) -> T? where T: Decodable {
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func from<T>(json: Any) -> T? where T: Decodable {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            return from(data: data)
        } catch {
            return nil
        }
    }
}

public protocol TopicRepresentable {
    var name: String { get }
}

public final class WebViewConnection {
    let webView: JavascriptEvaluating
    private var generators: [String: (Any) -> Void] = [:]

    public init(webView: JavascriptEvaluating) {
        self.webView = webView
    }
}

extension WebViewConnection {
    public enum Reply {
        case success(Any?)
        case error(Error)
    }

    public struct EmptyData: Codable {}

    private enum PayloadKey: String {
        case topic
        case data
    }

    private enum FallbackErrorTopic: String, TopicRepresentable {
        case error

        var name: String { return rawValue }
    }

    private enum ConnectionErrorType {
        case illegalPayloadFormat
        case missingField(PayloadKey)
        case missingTopicHandler
        case invalidDataForHandler(String)

        var message: String {
            switch self {
            case .illegalPayloadFormat: return "Illegal payload format"
            case .missingField(let payloadKey): return "Missing field: '\(payloadKey)'"
            case .missingTopicHandler: return "Missing topic handler"
            case .invalidDataForHandler(let expectedDataType): return "Invalid data for topic. Expected data type: '\(expectedDataType)'"
            }
        }

        var errorCode: Int {
            switch self {
            case .illegalPayloadFormat: return 1
            case .missingField(let payLoadKey):
                switch payLoadKey {
                case .topic: return 2
                case .data: return 3
                }
            case .missingTopicHandler: return 4
            case .invalidDataForHandler: return 5
            }
        }
    }

    private struct ErrorDetailObject: Codable {
        var message: String
        var errorCode: Int
    }

    private struct ErrorObject: Codable {
        var errors: [ErrorDetailObject]
    }

    private struct StringEncodingError: Error {}

    public func send(data: Codable, for topic: TopicRepresentable, completion: ((Reply) -> Void)? = nil) {
        send(data: data, for: topic.name, completion: completion)
    }

    private func send(data: Codable, for topic: String, completion: ((Reply) -> Void)? = nil) {
        var payload: [String: Any] = [:]
        payload[PayloadKey.topic.rawValue] = topic
        payload[PayloadKey.data.rawValue] = data.json

        do {
            let payloadString = try jsonString(from: payload)
            send(json: payloadString, completion: completion)
        } catch {
            completion?(.error(error))
        }
    }

    private func jsonString(from object: Any) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
        if let json = String(data: jsonData, encoding: .utf8) {
            return json
        } else {
            throw StringEncodingError()
        }
    }

    private func send(json: String, completion: ((Reply) -> Void)? = nil) {
        webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent(\"nativebridge\", {\"detail\":\(json)}))") { (value, error) in
            if let error = error {
                completion?(.error(error))
            } else {
                completion?(.success(value))
            }
        }
    }

    private func send(errorTypes: [ConnectionErrorType], for topic: String? = nil) {
        let errorDetails = errorTypes.map {ErrorDetailObject(message: $0.message, errorCode: $0.errorCode)}
        let error = ErrorObject(errors: errorDetails)
        send(data: error, for: topic ?? FallbackErrorTopic.error.name)
    }
}

extension WebViewConnection {
    public func addHandler<T>(for topic: TopicRepresentable, handler: @escaping (T, WebViewConnection) -> Void) where T: Codable {
        let generator: (Any) -> Void = { [weak self] data in
            guard let `self` = self else { return }
            guard let dataObject: T = JSONSerialization.from(json: data) else {
                self.send(errorTypes: [.invalidDataForHandler(String(describing: T.self))], for: topic.name)
                return
            }
            handler(dataObject, self)
        }

        self.generators[topic.name] = generator
    }

    public func receive(payload: Any) {
        guard let payloadDictionary = payload as? [String: Any] else {
            send(errorTypes: [.illegalPayloadFormat])
            return
        }

        var errorTypes: [ConnectionErrorType] = []
        let receivedTopic: String? = payloadDictionary.get(key: PayloadKey.topic.rawValue, orElse: {
            errorTypes.append(.missingField(.topic))
        })
        let receivedData: Any? = payloadDictionary.get(key: PayloadKey.data.rawValue, orElse: {
            errorTypes.append(.missingField(.data))
        })
        guard let topic = receivedTopic, let data = receivedData else {
            send(errorTypes: errorTypes, for: receivedTopic)
            return
        }

        guard let generator = generators[topic] else {
            send(errorTypes: [ConnectionErrorType.missingTopicHandler], for: topic)
            return }

        generator(data)
    }
}

private extension Dictionary where Key == String {
    func  get<T>(key: String, orElse closure: () -> Void) -> T? {
        guard let value = self[key] as? T else {
            closure()
            return nil
        }
        return value
    }
}
