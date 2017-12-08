//
//  ViewController.swift
//  nativebridge-ios
//
//  Created by Hans Olav Færevaag Nome on 12/07/2017.
//  Copyright (c) 2017 Hans Olav Færevaag Nome. All rights reserved.
//

import UIKit
import WebKit
import NativeBridge

class ViewController: UIViewController {
    private var webView: WKWebView!
    private var webViewConnection: WebViewConnection!

    enum NativeBridgeMessageName: String {
        case nativebridgeiOS
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        webView = createWebView()
        embedWebView()
        setupWebViewConnection()
        loadHtml()
    }

    private func createWebView() -> WKWebView {
        let userContentController = WKUserContentController()

        // Listen for messages posted to "nativebridgeiOS"
        userContentController.add(self, name: NativeBridgeMessageName.nativebridgeiOS.rawValue)

        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.userContentController = userContentController

        return WKWebView(frame: .zero, configuration: webViewConfiguration)
    }

    private func setupWebViewConnection() {
        enum ExampleType: String, TypeRepresentable {
            case ping

            var key: String { return rawValue}
        }

        struct IncomingData: Codable {
            var incomingMessage: String
        }

        struct OutgoingData: Codable {
            var outgoingMessage: String
        }

        webViewConnection = WebViewConnection(webView: webView)
        webViewConnection.addHandler(for: ExampleType.ping) { (incoming: IncomingData, connection) in
            let outgoing = OutgoingData(outgoingMessage: "Got incoming message: '\(incoming.incomingMessage)'")
            connection.send(data: outgoing, for: ExampleType.ping, completion: { (reply) in
                switch reply {
                case .success(_): print("Success!")
                case .error(let error): print (error)
                }
            })
        }
    }

    private func embedWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
    }

    private func loadHtml() {
        let html =
        """
<html lang="no">
    <head>
        <script>
            document.addEventListener("DOMContentLoaded", function() {
                if (window.webkit && window.webkit.messageHandlers) {
                    const detail = {type: "ping", data: {incomingMessage: "Ping!"}}
                    print("Sending:")
                    print(JSON.stringify(detail))
                    window.webkit.messageHandlers.nativebridgeiOS.postMessage(detail);
                }
            })

            window.addEventListener('nativebridge', function(event) {
                const message = event.detail;
                if(message.type === 'ping'){
                    print("Did receive")
                    print(JSON.stringify(event.detail))
                }
            })

            function print(text) {
                document.body.insertAdjacentHTML('beforeend', "<h1>" + text + "</h1>")
            }

        </script>
    </head>
    <body>
    </body>
</html>
"""
        webView.loadHTMLString(html, baseURL: nil)
    }
}

extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let massageName = NativeBridgeMessageName.init(rawValue: message.name) else { return }
        switch massageName {
        case .nativebridgeiOS:
            webViewConnection.receive(payload: message.body)
        }
    }
}
