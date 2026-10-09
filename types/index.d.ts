export interface SignInWithAppleName {
    namePrefix: string | null;
    givenName: string | null;
    middleName: string | null;
    familyName: string | null;
    nameSuffix: string | null;
    nickname: string | null;
    phoneticRepresentation?: SignInWithAppleName;
}

export interface SignInWithAppleCredential {
    user: string;
    authorizedScopes: number[];
    state: string | null;
    authorizationCode: string | null;
    identityToken: string | null;
    email: string | null;
    fullName: SignInWithAppleName | null;
    /** 0 unsupported, 1 unknown, 2 likelyReal */
    realUserStatus: number;
}

export interface SignInWithAppleRequestOptions {
    requestedScopes?: number[];
    requestedOperation?: number;
    user?: string;
    state?: string;
    /** Apple expects a SHA-256 hash of the raw nonce, not the raw value. */
    nonce?: string;
}

export interface SignInWithAppleError {
    error: "UNAVAILABLE_ERROR" | "ARGUMENT_ERROR" | "REQUEST_ERROR" | "REQUEST_IN_PROGRESS" | string;
    message: string;
    /** ASAuthorizationError code. 1001 means the user canceled. */
    code?: number;
}

interface SignInWithApplePlugin {
    Scope: {
        FullName: 0;
        Email: 1;
    };
    Operation: {
        Implicit: 0;
        Login: 1;
        Refresh: 2;
        Logout: 3;
    };
    CredentialState: {
        Revoked: 0;
        Authorized: 1;
        NotFound: 2;
        Transferred: 3;
    };
    isAvailable(): Promise<boolean>;
    request(options?: SignInWithAppleRequestOptions): Promise<SignInWithAppleCredential>;
    getCredentialState(options: { userId: string }): Promise<number>;
}

declare const SignInWithApple: SignInWithApplePlugin;

export default SignInWithApple;
