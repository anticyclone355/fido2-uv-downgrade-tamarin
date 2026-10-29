# Cross-Layer Formal Analysis of FIDO2 User-Verification Downgrade

Tamarin artifact for the symbolic formal analysis of the FIDO2 authentication
ceremony across its two protocol layers:

```
RP  <-- WebAuthn -->  Browser/Platform  <-- CTAP -->  Authenticator
```

The model (theory `FIDO2_UV_Downgrade_AuthFocused`) studies user-verification
(UV) downgrade: whether the relying party can still be sure that a received
assertion was produced under genuine user verification (PIN / biometrics) when
one or both protocol channels are adversary-controlled. Channel security is
configured per layer through preprocessor flags, giving four configurations.
Ten security lemmas (executability, secrecy, local authorization, agreement,
and assurance properties) are proven in each configuration, for 40 proof runs
in total. Counterexample traces are found automatically for the authentication
agreement properties whenever a channel is compromised.

The repository contains the vulnerable model (root directory) and a repaired
model (`fixed/`) that evaluates a countermeasure; see
[The fixed model](#the-fixed-model-countermeasure) below.

## Repository structure

| Path | Content |
|------|---------|
| `fido.spthy` | The vulnerable Tamarin model (single file, four channel configurations via `#ifdef`) |
| `run.sh` | Reproduction script: runs all 4 × 10 = 40 proofs, writes `proofs/`, `logs/`, `tamarin_results.md` |
| `lemma_sum.md` | One-line summary of the ten lemmas (Chinese) |
| `tamarin_results.md` | Machine-generated report of all 40 proof runs (vulnerable model) |
| `fido_tamarin_verification_results.xlsx` | Verification results spreadsheet |
| `proofs/` | Tamarin proof output files, vulnerable model (40 files) |
| `logs/` | Raw console logs of each proof run, vulnerable model (40 files) |
| `traces/` | Counterexample trace of the vulnerable model's AUTH3 violation (DOT source + rendered PDF) |
| `fixed/` | The repaired model with its own `run.sh` and complete 40-proof artifacts (`proofs/`, `logs/`, `tamarin_results.md`) |

## Requirements

- [Tamarin prover](https://tamarin-prover.github.io/) (proof logs in this
  repository were produced with the Maude 3.1 backend)
- Bash (to run `run.sh`)

Each individual proof finishes in seconds; all 40 runs together take a few
minutes on a typical laptop.

## Reproducing the results

Run all 40 proofs of the vulnerable model and regenerate the report:

```bash
chmod +x run.sh
./run.sh
```

Reproduce the fixed model the same way:

```bash
cd fixed && chmod +x run.sh && ./run.sh
```

Or run a single proof for one configuration manually, e.g. the
WebAuthn-insecure / CTAP-secure configuration:

```bash
tamarin-prover --prove=rp_required_uv_acceptance fido.spthy -DWEBAUTHN_INSECURE
```

### Channel configurations

| Configuration | Preprocessor flags | Meaning |
|---------------|--------------------|---------|
| `secure_secure` | (none) | WebAuthn secure, CTAP secure |
| `webauthn_insecure` | `-DWEBAUTHN_INSECURE` | WebAuthn channel Dolev–Yao controlled, CTAP secure |
| `ctap_insecure` | `-DCTAP_INSECURE` | WebAuthn secure, CTAP channel Dolev–Yao controlled |
| `both_insecure` | `-DWEBAUTHN_INSECURE -DCTAP_INSECURE` | Both channels Dolev–Yao controlled |

## Security properties

| ID | Lemma | Statement |
|----|-------|-----------|
| E1 | `executable_authentication` | The honest authentication ceremony is executable (rules out vacuous proofs) |
| R1 | `rp_required_uv_acceptance` | An RP that requires UV only accepts assertions with `UV = true` |
| S1 | `credential_private_key_secrecy` | The credential private key is never leaked |
| S2 | `pin_secrecy` | The PIN is never leaked |
| S3 | `ga_token_secrecy` | The pinUvAuthToken is never leaked |
| A1 | `pin_authorizes_token_issuance` | Every issued pinUvAuthToken originates from a PIN/UV authorization |
| AUTH1 | `noninjective_agreement_authentication_context` | RP, platform, and authenticator agree on the authentication context |
| AUTH2 | `injective_agreement_authentication_context` | AUTH1 with a unique session correspondence |
| AUTH3 | `authentication_context_consistency` | The RP's expected assurance equals the assurance actually performed by the authenticator |
| AUTH4 | `authentication_assurance_provenance` | A true `user_verified` flag must originate from a real UV/PIN authorization |

## Results (verified with this artifact)

✓ = verified, ✗ = falsified with counterexample trace (numbers = proof steps /
trace length).

| Lemma | ID | both secure | WebAuthn insecure | CTAP insecure | both insecure |
|-------|:--:|:-----------:|:-----------------:|:-------------:|:-------------:|
| `executable_authentication` | E1 | ✓ (7) | ✓ (11) | ✓ (13) | ✓ (13) |
| `rp_required_uv_acceptance` | R1 | ✓ (2) | ✓ (2) | ✓ (2) | ✓ (2) |
| `credential_private_key_secrecy` | S1 | ✓ (2) | ✓ (2) | ✓ (2) | ✓ (2) |
| `pin_secrecy` | S2 | ✓ (2) | ✓ (2) | ✓ (2) | ✓ (2) |
| `ga_token_secrecy` | S3 | ✓ (4) | ✓ (4) | ✓ (4) | ✓ (4) |
| `pin_authorizes_token_issuance` | A1 | ✓ (2) | ✓ (2) | ✓ (2) | ✓ (2) |
| `noninjective_agreement_authentication_context` | AUTH1 | ✓ (10) | ✗ (7) | ✗ (8) | ✗ (8) |
| `injective_agreement_authentication_context` | AUTH2 | ✓ (46) | ✗ (7) | ✗ (8) | ✗ (8) |
| `authentication_context_consistency` | AUTH3 | ✓ (5) | ✗ (8) | ✗ (7) | ✗ (8) |
| `authentication_assurance_provenance` | AUTH4 | ✓ (5) | ✓ (5) | ✓ (7) | ✓ (7) |

In the fully secure configuration all ten properties hold. As soon as either
channel is adversary-controlled, the three authentication-context
agreement/consistency properties (AUTH1–AUTH3) are falsified; Tamarin
constructs the corresponding downgrade traces automatically, while secrecy,
local authorization, provenance, and the RP's final UV acceptance decision are
preserved. The DOT source and a rendered PDF of the AUTH3 counterexample trace
are provided in `traces/`.

## The fixed model (countermeasure)

The repaired model in `fixed/` enforces UV-policy agreement at the
assertion-signing point. The two rules that sign an assertion without user
verification while the ceremony requires it (`Authenticator_GA_WithoutUV_Insecure`
and `Authenticator_GA_WithoutUV_Secure`, covering both channel variants) are
extended with explicit `requiredUV` / `actualUV` bindings and a premise
constraint `Eq(requiredUV, actualUV)`. Since these rules set
`(requiredUV, actualUV) = ('true', 'false')`, the constraint is
unsatisfiable and the rules become unexecutable: the authenticator never
issues a UV-less assertion when the RP requested user verification.

Results of the fixed model (same 4 × 10 runs; only AUTH3 changed with respect
to the vulnerable model):

| Lemma | ID | both secure | WebAuthn insecure | CTAP insecure | both insecure |
|-------|:--:|:-----------:|:-----------------:|:-------------:|:-------------:|
| `executable_authentication` | E1 | ✓ (7) | ✓ (11) | ✓ (13) | ✓ (13) |
| `rp_required_uv_acceptance` | R1 | ✓ (2) | ✓ (2) | ✓ (2) | ✓ (2) |
| `credential_private_key_secrecy` | S1 | ✓ (2) | ✓ (2) | ✓ (2) | ✓ (2) |
| `pin_secrecy` | S2 | ✓ (2) | ✓ (2) | ✓ (2) | ✓ (2) |
| `ga_token_secrecy` | S3 | ✓ (4) | ✓ (4) | ✓ (4) | ✓ (4) |
| `pin_authorizes_token_issuance` | A1 | ✓ (2) | ✓ (2) | ✓ (2) | ✓ (2) |
| `noninjective_agreement_authentication_context` | AUTH1 | ✓ (10) | ✗ (7) | ✗ (8) | ✗ (8) |
| `injective_agreement_authentication_context` | AUTH2 | ✓ (46) | ✗ (7) | ✗ (8) | ✗ (8) |
| `authentication_context_consistency` | AUTH3 | ✓ (5) | ✓ (5) | ✓ (5) | ✓ (5) |
| `authentication_assurance_provenance` | AUTH4 | ✓ (5) | ✓ (5) | ✓ (7) | ✓ (7) |

The countermeasure restores `authentication_context_consistency` (AUTH3) in
every channel configuration while leaving all other results unchanged. AUTH1
and AUTH2, however, remain falsified whenever a channel is
adversary-controlled: authenticator-side UV-policy enforcement alone cannot
restore cross-layer agreement over a Dolev–Yao controlled channel.

## Modeling notes

The header of `fido.spthy` documents all modeling decisions:

- Registration is abstracted: a successful registration is modeled by the
  rule `Provision_Registered_Credential`, which pre-provisions a matching
  credential ID/key pair at the RP and the authenticator. This is faithful
  for the target property because the authentication ceremony starts from
  exactly the state WebAuthn assumes after successful registration.
- There is no dedicated downgrade transition: in insecure configurations the
  adversary must construct modified protocol messages using ordinary Tamarin
  `In`/`Out` events, and the counterexample traces are found automatically.
- Security-relevant fields preserved: fresh RP challenge, credential ID/key,
  WebAuthn userVerification policy, clientData and clientDataHash, rpIdHash,
  UP/UV bits, fresh pinUvAuthToken, pinUvAuthParam
  (= HMAC(token, clientDataHash)), the assertion signature, and the RP's
  original pending UV policy.
- Fixed or abstracted: rpId and origin constants, known-account
  authentication with `allowCredentials`, zero signature counter, and
  omission of GetInfo, PIN-ECDH details, token encryption, extensions, and
  COSE wrappers.

## Citation

This artifact accompanies the paper *"A Tale of Two Verifications: A Formal
Analysis of Cross-Layer UV Downgrades in FIDO2"* (citation to be added upon
publication).
