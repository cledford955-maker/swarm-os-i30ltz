using Fido2NetLib;
using Fido2NetLib.Objects;

namespace LucyServer.Services;

public interface IAuthService
{
    AssertionOptions GetLoginOptions();
    Task<AssertionVerificationResult> VerifyLoginAsync(AuthenticatorAssertionRawResponse clientResponse);
    
    CredentialCreateOptions GetRegisterOptions();
    Task<Fido2.CredentialMakeResult> VerifyRegisterAsync(AuthenticatorAttestationRawResponse clientResponse);

    List<object> ListCredentials();
    void ClearCredentials();
}
