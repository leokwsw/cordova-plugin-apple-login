import AuthenticationServices
import Foundation
import UIKit

/// Cordova bridge for Sign in with Apple.
///
/// The JavaScript service name is `SignInWithApple`. Selectors must keep the
/// trailing colon so they match `CDVCommandQueue`'s `action:` lookup.
@objc(SignInWithApple)
class SignInWithApple: CDVPlugin {
    private var currentCommand: CDVInvokedUrlCommand?
    private var authorizationController: NSObject?

    @objc(isAvailable:)
    func isAvailable(_ command: CDVInvokedUrlCommand) {
        let available = ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)
        )
        send(CDVPluginResult(status: .ok, messageAs: available), callbackId: command.callbackId)
    }

    @objc(request:)
    func request(_ command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            fail(command, error: "UNAVAILABLE_ERROR", message: "This device does not support Sign in with Apple.")
            return
        }

        if currentCommand != nil {
            fail(command, error: "REQUEST_IN_PROGRESS", message: "A Sign in with Apple request is already in progress.")
            return
        }

        let options = dictionaryArgument(from: command)
        currentCommand = command
        performRequest(options: options)
    }

    @objc(getCredentialState:)
    func getCredentialState(_ command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            fail(command, error: "UNAVAILABLE_ERROR", message: "This device does not support Sign in with Apple.")
            return
        }

        let options = dictionaryArgument(from: command)
        guard let userId = options["userId"] as? String, !userId.isEmpty else {
            fail(command, error: "ARGUMENT_ERROR", message: "userId is required.")
            return
        }

        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userId) { [weak self] state, error in
            guard let self = self else { return }

            if let error = error {
                self.fail(
                    command,
                    error: "REQUEST_ERROR",
                    code: (error as NSError).code,
                    message: error.localizedDescription
                )
                return
            }

            self.send(
                CDVPluginResult(status: .ok, messageAs: state.rawValue),
                callbackId: command.callbackId
            )
        }
    }

    private func dictionaryArgument(from command: CDVInvokedUrlCommand) -> [String: Any] {
        guard let arguments = command.arguments,
              let options = arguments.first as? [String: Any] else {
            return [:]
        }
        return options
    }

    private func send(_ result: CDVPluginResult, callbackId: String) {
        DispatchQueue.main.async {
            self.commandDelegate.send(result, callbackId: callbackId)
        }
    }

    private func fail(
        _ command: CDVInvokedUrlCommand,
        error: String,
        code: Int? = nil,
        message: String
    ) {
        var payload: [String: Any] = [
            "error": error,
            "message": message
        ]
        if let code = code {
            payload["code"] = code
        }
        send(CDVPluginResult(status: .error, messageAs: payload), callbackId: command.callbackId)
    }
}

@available(iOS 13.0, *)
extension SignInWithApple: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    fileprivate func performRequest(options: [String: Any]) {
        let request = ASAuthorizationAppleIDProvider().createRequest()

        if let rawScopes = options["requestedScopes"] as? [Any] {
            request.requestedScopes = Self.scopes(from: rawScopes)
        }
        if let operation = (options["requestedOperation"] as? NSNumber)?.intValue,
           let converted = Self.operation(from: operation) {
            request.requestedOperation = converted
        }
        if let user = options["user"] as? String {
            request.user = user
        }
        if let state = options["state"] as? String {
            request.state = state
        }
        if let nonce = options["nonce"] as? String {
            request.nonce = nonce
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        authorizationController = controller

        DispatchQueue.main.async {
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { finishRequest() }

        guard let command = currentCommand else { return }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            fail(command, error: "REQUEST_ERROR", message: "Unexpected Apple authorization credential.")
            return
        }

        send(
            CDVPluginResult(status: .ok, messageAs: Self.credentialPayload(credential)),
            callbackId: command.callbackId
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { finishRequest() }

        guard let command = currentCommand else { return }
        let nsError = error as NSError
        fail(
            command,
            error: "REQUEST_ERROR",
            code: nsError.code,
            message: nsError.localizedDescription
        )
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = viewController?.view.window {
            return window
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if #available(iOS 15.0, *) {
            if let window = scenes.compactMap({ $0.keyWindow }).first {
                return window
            }
        }
        if let window = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) {
            return window
        }

        return ASPresentationAnchor()
    }

    private func finishRequest() {
        currentCommand = nil
        authorizationController = nil
    }

    private static func scopes(from values: [Any]) -> [ASAuthorization.Scope] {
        values.compactMap { value in
            switch (value as? NSNumber)?.intValue {
            case 0:
                return .fullName
            case 1:
                return .email
            default:
                return nil
            }
        }
    }

    private static func operation(from value: Int) -> ASAuthorization.OpenIDOperation? {
        switch value {
        case 0:
            return .implicit
        case 1:
            return .login
        case 2:
            return .refresh
        case 3:
            return .logout
        default:
            return nil
        }
    }

    private static func credentialPayload(_ credential: ASAuthorizationAppleIDCredential) -> [String: Any] {
        var payload: [String: Any] = [
            "user": credential.user,
            "authorizedScopes": credential.authorizedScopes.compactMap(Self.scopeValue),
            "state": json(credential.state),
            "authorizationCode": string(from: credential.authorizationCode),
            "identityToken": string(from: credential.identityToken),
            "email": json(credential.email),
            "realUserStatus": credential.realUserStatus.rawValue
        ]
        if let fullName = namePayload(credential.fullName) {
            payload["fullName"] = fullName
        } else {
            payload["fullName"] = NSNull()
        }
        return payload
    }

    private static func json(_ value: String?) -> Any {
        if let value = value {
            return value
        }
        return NSNull()
    }

    private static func scopeValue(_ scope: ASAuthorization.Scope) -> Int? {
        if scope == .fullName {
            return 0
        }
        if scope == .email {
            return 1
        }
        return nil
    }

    private static func string(from data: Data?) -> Any {
        guard let data = data, let value = String(data: data, encoding: .utf8) else {
            return NSNull()
        }
        return value
    }

    private static func namePayload(_ name: PersonNameComponents?) -> [String: Any]? {
        guard let name = name else { return nil }

        var payload: [String: Any] = [
            "namePrefix": name.namePrefix ?? NSNull(),
            "givenName": name.givenName ?? NSNull(),
            "middleName": name.middleName ?? NSNull(),
            "familyName": name.familyName ?? NSNull(),
            "nameSuffix": name.nameSuffix ?? NSNull(),
            "nickname": name.nickname ?? NSNull()
        ]

        if let phonetic = namePayload(name.phoneticRepresentation) {
            payload["phoneticRepresentation"] = phonetic
        }

        return payload
    }
}
