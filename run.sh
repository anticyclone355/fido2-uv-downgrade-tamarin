#!/usr/bin/env bash

# Run 4 channel configurations x 10 lemmas = 40 Tamarin proofs.
#
# Outputs:
#   proofs/*.spthy
#   logs/*.log
#   tamarin_results.md
#
# Usage:
#   chmod +x run_all.sh
#   ./run_all.sh

set -u
set -o pipefail

MODEL="fido.spthy"
TAMARIN="${TAMARIN:-tamarin-prover}"

PROOF_DIR="proofs"
LOG_DIR="logs"
RESULT_MD="tamarin_results.md"

mkdir -p "$PROOF_DIR" "$LOG_DIR"

if [[ ! -f "$MODEL" ]]; then
    echo "ERROR: Cannot find $MODEL in current directory." >&2
    exit 1
fi

if ! command -v "$TAMARIN" >/dev/null 2>&1; then
    echo "ERROR: Cannot find Tamarin executable: $TAMARIN" >&2
    exit 1
fi

LEMMAS=(
    "executable_authentication"
    "rp_required_uv_acceptance"
    "credential_private_key_secrecy"
    "pin_secrecy"
    "ga_token_secrecy"
    "pin_authorizes_token_issuance"
    "noninjective_agreement_authentication_context"
    "injective_agreement_authentication_context"
    "authentication_context_consistency"
    "authentication_assurance_provenance"
)

CONFIGS=(
    "secure_secure"
    "webauthn_insecure"
    "ctap_insecure"
    "both_insecure"
)

config_args() {
    case "$1" in
        secure_secure)
            ;;
        webauthn_insecure)
            printf '%s\n' "-DWEBAUTHN_INSECURE"
            ;;
        ctap_insecure)
            printf '%s\n' "-DCTAP_INSECURE"
            ;;
        both_insecure)
            printf '%s\n' "-DWEBAUTHN_INSECURE" "-DCTAP_INSECURE"
            ;;
        *)
            echo "ERROR: Unknown configuration: $1" >&2
            return 1
            ;;
    esac
}

config_description() {
    case "$1" in
        secure_secure)
            echo "WebAuthn secure / CTAP secure"
            ;;
        webauthn_insecure)
            echo "WebAuthn insecure / CTAP secure"
            ;;
        ctap_insecure)
            echo "WebAuthn secure / CTAP insecure"
            ;;
        both_insecure)
            echo "WebAuthn insecure / CTAP insecure"
            ;;
    esac
}

markdown_escape_file_tail() {
    local file="$1"

    tail -n 20 "$file" \
        | sed \
            -e 's/&/\&amp;/g' \
            -e 's/</\&lt;/g' \
            -e 's/>/\&gt;/g' \
            -e 's/|/\&#124;/g' \
        | awk 'BEGIN { ORS="&#10;" } { print }'
}

{
    echo "# Tamarin Proof Results"
    echo
    echo "- Model: \`$MODEL\`"
    echo "- Total configurations: 4"
    echo "- Lemmas per configuration: ${#LEMMAS[@]}"
    echo "- Total proof runs: $(( ${#CONFIGS[@]} * ${#LEMMAS[@]} ))"
    echo
    echo "| # | Channel configuration | Lemma | Exit code | Proof file | Last 20 lines |"
    echo "|---:|---|---|---:|---|---|"
} > "$RESULT_MD"

run_no=0
total_runs=$(( ${#CONFIGS[@]} * ${#LEMMAS[@]} ))

for config in "${CONFIGS[@]}"; do
    description="$(config_description "$config")"
    mapfile -t DEFINES < <(config_args "$config")

    for lemma in "${LEMMAS[@]}"; do
        run_no=$((run_no + 1))

        proof_file="${PROOF_DIR}/${config}_${lemma}_proof.spthy"
        log_file="${LOG_DIR}/${config}_${lemma}.log"

        echo
        echo "=============================================================================="
        echo "[$run_no/$total_runs] $description"
        echo "Lemma: $lemma"
        echo "Proof: $proof_file"
        echo "Log:   $log_file"
        echo "=============================================================================="

        "$TAMARIN" \
            --prove="$lemma" \
            "$MODEL" \
            "${DEFINES[@]}" \
            --output="$proof_file" \
            2>&1 | tee "$log_file"

        rc=${PIPESTATUS[0]}

        tail20="$(markdown_escape_file_tail "$log_file")"

        printf '| %d | %s | `%s` | %d | `%s` | <pre>%s</pre> |\n' \
            "$run_no" \
            "$description" \
            "$lemma" \
            "$rc" \
            "$proof_file" \
            "$tail20" \
            >> "$RESULT_MD"
    done
done

echo
echo "=============================================================================="
echo "All proof runs finished."
echo "Markdown report: $RESULT_MD"
echo "Proof directory: $PROOF_DIR"
echo "Log directory:   $LOG_DIR"
echo "=============================================================================="
