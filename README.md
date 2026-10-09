# cordova-plugin-apple-login

Cordova plugin for [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/). The iOS native side is written in Swift and uses `AuthenticationServices`.

Author: [Leo Wu](https://github.com/leokwsw) (leokwsw@gmail.com)

Requires **cordova-ios >= 6** and **iOS >= 13**.

## Install

```bash
cordova plugin add @leokwsw/cordova-plugin-apple-login
```

Before the button can succeed, the App ID needs the Sign in with Apple capability, and the provisioning profile must include it. This plugin writes `com.apple.developer.applesignin = [Default]` into the Cordova iOS Debug and Release entitlements.

## Usage

### `SignInWithApple.isAvailable()`

Resolves `true` on iOS 13 and later.

```js
SignInWithApple.isAvailable().then(function (isAvailable) {
  console.info(isAvailable);
});
```

### `SignInWithApple.request(options)`

Presents the system Apple ID sheet.

```js
SignInWithApple.request({
  requestedScopes: [
    SignInWithApple.Scope.Email,
    SignInWithApple.Scope.FullName
  ],
  requestedOperation: SignInWithApple.Operation.Login,
  state: "state",
  nonce: "sha256-hex-of-your-raw-nonce"
}).then(function (credential) {
  console.info(credential.user);
  console.info(credential.identityToken);
  console.info(credential.authorizationCode);
}).catch(function (error) {
  console.error(error.error, error.code, error.message);
});
```

Options:

| Field | Type | Description |
| --- | --- | --- |
| `requestedScopes` | `number[]` | `SignInWithApple.Scope.FullName` (`0`) and/or `Scope.Email` (`1`) |
| `requestedOperation` | `number` | `Operation.Implicit` (`0`), `Login` (`1`), `Refresh` (`2`), `Logout` (`3`) |
| `user` | `string` | Apple user id, used with refresh or logout |
| `state` | `string` | Returned unchanged on the credential |
| `nonce` | `string` | Passed through as-is. Apple expects the SHA-256 hash of your raw nonce |

Apple only returns `email` and `fullName` on the first authorization for that user. Persist them on your server when they are present.

Resolved credential:

```js
{
  user: "userId",
  authorizedScopes: [0, 1],
  identityToken: "jwt",
  authorizationCode: "code",
  realUserStatus: 1,
  email: null,
  state: null,
  fullName: {
    namePrefix: null,
    givenName: null,
    middleName: null,
    familyName: null,
    nameSuffix: null,
    nickname: null
  }
}
```

`realUserStatus`: `0` unsupported, `1` unknown, `2` likely real. See [ASAuthorizationAppleIDCredential](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidcredential).

`identityToken` and `authorizationCode` are UTF-8 strings. Verify the token on your server. Do not trust the client email or user id by themselves.

### `SignInWithApple.getCredentialState(options)`

```js
SignInWithApple.getCredentialState({
  userId: "userId"
}).then(function (state) {
  if (state === SignInWithApple.CredentialState.Authorized) {
    // still signed in
  }
});
```

| Value | Constant |
| --- | --- |
| `0` | `CredentialState.Revoked` |
| `1` | `CredentialState.Authorized` |
| `2` | `CredentialState.NotFound` |
| `3` | `CredentialState.Transferred` |

See [credentialState](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider/credentialstate).

## Errors

Failures reject with `{ error, message, code? }`.

| `error` | When |
| --- | --- |
| `UNAVAILABLE_ERROR` | iOS older than 13 |
| `ARGUMENT_ERROR` | `getCredentialState` was called without `userId` |
| `REQUEST_IN_PROGRESS` | Another `request` is still showing |
| `REQUEST_ERROR` | Apple returned an error. `code` `1001` means the user canceled |

## Notes

- cordova-ios 6 and later compile plugin Swift sources and generate the Cordova bridging header. No extra Swift-support plugin is required.
- Only one authorization sheet can be open at a time. The controller is retained until Apple calls the delegate.
