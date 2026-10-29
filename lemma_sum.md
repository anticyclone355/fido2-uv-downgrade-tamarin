E1   Executability

S1   Credential-key secrecy
S2   PIN secrecy
S3   pinUvAuthToken secrecy

A1   PIN-to-token authorization

AUTH1 Non-injective authentication-context agreement
AUTH2 Injective authentication-context agreement
AUTH3 Authentication-context consistency
AUTH4 Authentication-assurance provenance

R1   RP required-UV acceptance


| 类别            | Lemma                                           | 作用                                                  |
| ------------- | ----------------------------------------------- | --------------------------------------------------- |
| 可执行性          | `executable_authentication`                     | 排除模型不可执行导致的空证明                                      |
| RP 最终安全       | `rp_required_uv_acceptance`                     | RP 要求 UV 时只接受 `UV=true`                             |
| 机密性           | `credential_private_key_secrecy`                | 私钥不泄露                                               |
|               | `pin_secrecy`                                   | PIN 不泄露                                             |
|               | `ga_token_secrecy`                              | pinUvAuthToken 不泄露                                  |
| 本地授权          | `pin_authorizes_token_issuance`                 | token 必须来自 PIN/UV 授权                                |
| 通用认证性         | `noninjective_agreement_authentication_context` | 三方对认证上下文应达成一致                                       |
| 强认证性          | `injective_agreement_authentication_context`    | 再要求 session 唯一对应                                    |
| Assurance 一致性 | `authentication_context_consistency`            | RP 期望的 assurance 必须等于 Authenticator 实际完成的 assurance |
| Assurance 来源  | `authentication_assurance_provenance`           | 真正的 `user_verified` 必须有真实 UV/PIN 授权来源               |
