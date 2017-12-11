# nativebridge-ios

This Swift module is the native part of a RPC communication bridge between your app and a webview javascript.
It is designed to work together with its javascript counterpart, [nrkno/nativebridge](https://github.com/nrkno/nativebridge).


## Requirements

In addition to [nrkno/nativebridge](https://github.com/nrkno/nativebridge), nativebridge-ios relies on WKWebView and script message handlers to work. 

## Installation

nativebridge-ios is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'nativebridge-ios'
```

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Usage

All communication with the javascript is managed through the `WebViewConnnection` class. 

Communication follows a protocol where messages are sent back and forth between the javascript and your code.
Messages have a topic, and some data.
The data must implement the [`Codable`](https://developer.apple.com/documentation/swift/codable) protocol.

### Establishing the javscript connection

One must configure the WKWebView instance by adding a script message handler ([WKScriptMessageHandler](https://developer.apple.com/documentation/webkit/wkscriptmessagehandler)) that will listen to messages sent to 'nativebridgeiOS'.

See the example project for details on how to do this.

### Sending data

```swift
let data = SomeDataType()
webViewConnection.send(data: data, for: Topic.someTopic)
```

### Adding topic handlers

In order to react on messages sent from the javascript, one must add handlers to the `WebViewConnnection` instance: 

```swift 
webViewConnection.addHandler(for Topic.someTopic, {
    (input: InputDataType, connection) in {
        let message = "Received incoming: '\(input.inputMessage)'"
        let output = OutputData(outputMessage: message)
        connection.send(data: output, for: Topic.someTopic)
    }
})
```


## License

nativebridge-ios is available under the MIT license. See the LICENSE file for more info.
