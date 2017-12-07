//
//  WebViewMessageHandler.swift
//  nrk.no
//
//  Created by Johan Sørensen on 11/07/2017.
//  Copyright © 2017 NRK. All rights reserved.
//

import Foundation
import WebKit

protocol JavascriptEvaluating {
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

protocol TypeRepresentable {
    var key: String { get }
}

final class WebViewConnection {
    let webView: JavascriptEvaluating
    fileprivate var generators: [String: (Any) -> Void] = [:]

    init(webView: JavascriptEvaluating) {
        self.webView = webView
    }
}

extension WebViewConnection {
    enum Reply {
        case success(Any?)
        case error(Error)
    }

    struct EmptyData: Codable {}

    private enum PayloadKey: String {
        case type
        case data
    }

    private enum FallbackErrorType: String, TypeRepresentable {
        case error

        var key: String { return rawValue }
    }

    private enum ConnectionErrorType {
        case illegalPayloadFormat
        case missingField(PayloadKey)
        case missingTypeHandler
        case invalidDataForHandler(String)

        var message: String {
            switch self {
            case .illegalPayloadFormat: return "Illegal payload format"
            case .missingField(let payloadKey): return "Missing field: '\(payloadKey)'"
            case .missingTypeHandler: return "Missing type handler"
            case .invalidDataForHandler(let expectedDataType): return "Invalid data for type. Expected data type: '\(expectedDataType)'"
            }
        }

        var errorCode: Int {
            switch self {
            case .illegalPayloadFormat: return 1
            case .missingField(let payLoadKey):
                switch payLoadKey {
                case .type: return 2
                case .data: return 3
                }
            case .missingTypeHandler: return 4
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

    func send(data: Codable, for type: TypeRepresentable, completion: ((Reply) -> Void)? = nil) {
        send(data: data, for: type.key, completion: completion)
    }

    private func send(data: Codable, for type: String, completion: ((Reply) -> Void)? = nil) {
        var payload: [String: Any] = [:]
        payload[PayloadKey.type.rawValue] = type
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

    private func send(errorTypes: [ConnectionErrorType], for type: String? = nil) {
        let errorDetails = errorTypes.map {ErrorDetailObject(message: $0.message, errorCode: $0.errorCode)}
        let error = ErrorObject(errors: errorDetails)
        send(data: error, for: type ?? FallbackErrorType.error.key)
    }
}

extension WebViewConnection {
    func addHandler<T>(for type: TypeRepresentable, handler: @escaping (T, WebViewConnection) -> Void) where T: Codable {
        let generator: (Any) -> Void = { [weak self] data in
            guard let `self` = self else { return }
            guard let dataObject: T = JSONSerialization.from(json: data) else {
                self.send(errorTypes: [.invalidDataForHandler(String(describing: T.self))], for: type.key)
                return
            }
            handler(dataObject, self)
        }

        self.generators[type.key] = generator
    }

    func receive(payload: Any) {
        guard let payloadDictionary = payload as? [String: Any] else {
            send(errorTypes: [.illegalPayloadFormat])
            return
        }

        var errorTypes: [ConnectionErrorType] = []
        let receivedType: String? = payloadDictionary.get(key: PayloadKey.type.rawValue, orElse: {
            errorTypes.append(.missingField(.type))
        })
        let receivedData: Any? = payloadDictionary.get(key: PayloadKey.data.rawValue, orElse: {
            errorTypes.append(.missingField(.data))
        })
        guard let type = receivedType, let data = receivedData else {
            send(errorTypes: errorTypes, for: receivedType)
            return
        }

        guard let generator = generators[type] else {
            send(errorTypes: [ConnectionErrorType.missingTypeHandler], for: type)
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
