var exec = require('cordova/exec');

var SERVICE = 'SignInWithApple';

function call(action, args) {
    return new Promise(function (resolve, reject) {
        exec(resolve, reject, SERVICE, action, args || []);
    });
}

/**
 * Sign in with Apple. The iOS implementation is Swift.
 */
var SignInWithApple = {
    Scope: {
        FullName: 0,
        Email: 1
    },
    Operation: {
        Implicit: 0,
        Login: 1,
        Refresh: 2,
        Logout: 3
    },
    CredentialState: {
        Revoked: 0,
        Authorized: 1,
        NotFound: 2,
        Transferred: 3
    },

    /**
     * @returns {Promise<boolean>} true when the device supports Sign in with Apple (iOS 13+).
     */
    isAvailable: function () {
        return call('isAvailable');
    },

    /**
     * Present the Apple ID authorization sheet.
     *
     * @param {Object} [options]
     * @param {number[]} [options.requestedScopes] SignInWithApple.Scope values.
     * @param {number} [options.requestedOperation] SignInWithApple.Operation value.
     * @param {string} [options.user] Apple user identifier, used with refresh/logout.
     * @param {string} [options.state] Opaque value returned unchanged in the credential.
     * @param {string} [options.nonce] Nonce. Apple expects the SHA-256 hash of your raw nonce.
     * @returns {Promise<Object>} ASAuthorizationAppleIDCredential as a plain object.
     */
    request: function (options) {
        return call('request', [options || {}]);
    },

    /**
     * Look up the credential state for a previously authorized Apple user.
     *
     * @param {{ userId: string }} options
     * @returns {Promise<number>} SignInWithApple.CredentialState value.
     */
    getCredentialState: function (options) {
        return call('getCredentialState', [options || {}]);
    }
};

module.exports = SignInWithApple;
