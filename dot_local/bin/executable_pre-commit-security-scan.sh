#!/usr/bin/env bash
# Pre-commit security scan — checks staged changes for secrets and credentials
set -euo pipefail

# Skip entirely if env var is set
if [[ "${SKIP_SECURITY_SCAN:-0}" = "1" ]]; then
    echo "Security scan: skipped (SKIP_SECURITY_SCAN=1)"
    exit 0
fi

PATTERN_FILE="${PATTERN_FILE:-$HOME/.config/opencode/tools/pre-commit-patterns.conf}"

# Canonical email pattern — used to identify email checks and for non-code file filtering
EMAIL_PATTERN='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'

# Minimal fallback patterns — used only when config file is missing.
# Config file is canonical; keep this in sync.
declare -a DEFAULT_PATTERNS=(
    "BLOCK::sk-::Stripe/OpenAI API key"
    "BLOCK::AKIA[A-Z0-9]{16}::AWS access key"
    "BLOCK::ghp_[a-zA-Z0-9]{36}::GitHub personal access token"
    "BLOCK::gho_[a-zA-Z0-9]{36}::GitHub OAuth token"
    "BLOCK::-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----::Private key header"
    "BLOCK::[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][[:space:]]*[:=][[:space:]]*::Password hardcoded"
    "BLOCK::api[_-]?key[[:space:]]*[:=][[:space:]]*['\"][a-zA-Z0-9_-]{16,}['\"]::API key hardcoded"
    "WARN::${EMAIL_PATTERN}::Email address in code"
)

# Email check only applies to code files (not docs, .env, .md, .txt)
CODE_FILE_REGEX="\\.(ts|js|tsx|jsx|py|go|rs|sh|yaml|yml|json)$"

# Global counters (updated by scan_staged_file)
TOTAL_BLOCKS=0
TOTAL_WARNS=0

load_patterns() {
    local IFS=$'\n'
    if [[ -f "$PATTERN_FILE" ]]; then
        mapfile -t PATTERNS < "$PATTERN_FILE"
    else
        PATTERNS=("${DEFAULT_PATTERNS[@]}")
    fi
}

scan_staged_file() {
    local file="$1"
    local content
    local is_code_file=0

    if echo "$file" | grep -qE "$CODE_FILE_REGEX"; then
        is_code_file=1
    fi

    # Read staged content (only added lines)
    content="$(git diff --cached -- "$file" 2>/dev/null || true)"

    # Skip binary files or empty diffs
    if [[ -z "$content" ]]; then
        return 0
    fi

    # Extract added lines (prefixed with +, but not +++ for diff header)
    local added_lines
    added_lines="$(echo "$content" | grep '^+' | grep -v '^+++ ' | sed 's/^+//' || true)"

    if [[ -z "$added_lines" ]]; then
        return 0
    fi

    local pattern_entry severity pattern desc rest
    for pattern_entry in "${PATTERNS[@]}"; do
        severity="${pattern_entry%%::*}"
        rest="${pattern_entry#*::}"
        desc="${rest##*::}"
        pattern="${rest%::*}"

        # Skip email WARN for non-code files
        if [[ "$severity" = "WARN" ]] && [[ "$pattern" = "$EMAIL_PATTERN" ]] && [[ "$is_code_file" -eq 0 ]]; then
            continue
        fi

        while IFS= read -r line; do
            if [[ "$severity" = "WARN" ]]; then
                echo "WARNING: $desc found in $file: ${line:0:120}"
                TOTAL_WARNS=$((TOTAL_WARNS + 1))
            else
                echo "BLOCKED: $desc found in $file: ${line:0:120}"
                TOTAL_BLOCKS=$((TOTAL_BLOCKS + 1))
            fi
        done < <(grep -E -- "$pattern" <<< "$added_lines" || true)
    done
}

main() {
    load_patterns

    local staged_files
    local total_files=0
    local file

    # Get list of staged files (added, copied, modified, renamed)
    staged_files="$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)"

    if [[ -z "$staged_files" ]]; then
        echo "Security scan: no staged files to check"
        exit 0
    fi

    while IFS= read -r file; do
        if [[ -z "$file" ]]; then
            continue
        fi
        total_files=$((total_files + 1))
        scan_staged_file "$file"
    done <<< "$staged_files"

    if [[ "$TOTAL_WARNS" -gt 0 ]]; then
        echo "Security scan: $TOTAL_WARNS warnings flagged"
    fi

    if [[ "$TOTAL_BLOCKS" -gt 0 ]]; then
        echo "Security scan: $total_files files checked, $TOTAL_BLOCKS blocked"
        exit 1
    fi

    echo "Security scan: $total_files files checked, 0 blocked"
}

main
