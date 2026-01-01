#!/bin/bash
# restore-secrets.sh - Restore sanitized secrets to working directory
# Replaces REDACTED-LINE-N placeholders with actual passwords from .secrets

set -e  # Exit on error
set -u  # Exit on undefined variable

# Constants
SECRETS_FILE=".secrets"
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Function: Print error and exit
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Function: Print info message
info() {
    echo "[RESTORE] $1"
}

# Main logic
main() {
    # Change to repo root
    cd "$REPO_ROOT" || error_exit "Cannot change to repo root"

    # Check .secrets exists
    if [ ! -f "$SECRETS_FILE" ]; then
        error_exit "Missing $SECRETS_FILE file. Cannot restore secrets.
Create .secrets file using .secrets.example as a template."
    fi

    # Read secrets into array (same logic as sanitize)
    declare -a SECRETS
    LINE_NUM=1
    while IFS= read -r line || [ -n "$line" ]; do
        # Trim whitespace
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        # Skip empty lines and comments
        if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
            continue
        fi

        SECRETS[$LINE_NUM]="$line"
        LINE_NUM=$((LINE_NUM + 1))
    done < "$SECRETS_FILE"

    # Validate we have secrets
    if [ ${#SECRETS[@]} -eq 0 ]; then
        error_exit "No secrets found in $SECRETS_FILE (only comments/empty lines)"
    fi

    info "Loaded ${#SECRETS[@]} secret(s) from $SECRETS_FILE"

    # Get all tracked files
    TRACKED_FILES=$(git ls-files)

    # Process each file
    FILE_COUNT=0
    REPLACEMENT_COUNT=0

    for file in $TRACKED_FILES; do
        # Skip if file doesn't exist
        [ -f "$file" ] || continue

        # Skip binary files
        if file -b --mime-encoding "$file" | grep -q "binary"; then
            continue
        fi

        # Check if file contains REDACTED placeholders
        if ! grep -q "REDACTED-LINE-" "$file" 2>/dev/null; then
            continue
        fi

        # Create temp file
        TEMP_FILE=$(mktemp)
        trap "rm -f $TEMP_FILE" EXIT

        # Copy original to temp
        cp "$file" "$TEMP_FILE"

        FILE_MODIFIED=0

        # Restore secrets
        for i in $(seq 1 ${#SECRETS[@]}); do
            placeholder="REDACTED-LINE-$i"
            secret="${SECRETS[$i]}"

            # Count occurrences before replacement
            BEFORE_COUNT=$(grep -o "$placeholder" "$TEMP_FILE" 2>/dev/null | wc -l || echo 0)

            if [ "$BEFORE_COUNT" -gt 0 ]; then
                # Escape special characters for sed replacement (different from search!)
                escaped_secret=$(printf '%s\n' "$secret" | sed 's/[&/\]/\\&/g')

                # Perform replacement
                sed -i "s/$placeholder/$escaped_secret/g" "$TEMP_FILE"
                REPLACEMENT_COUNT=$((REPLACEMENT_COUNT + BEFORE_COUNT))
                FILE_MODIFIED=1
                info "  $file: Restored $BEFORE_COUNT occurrence(s) of secret $i"
            fi
        done

        # Check for orphaned placeholders (REDACTED-LINE-N where N > number of secrets)
        ORPHANED=$(grep -o "REDACTED-LINE-[0-9]\+" "$TEMP_FILE" 2>/dev/null || echo "")
        if [ -n "$ORPHANED" ]; then
            echo "WARNING: Found orphaned placeholders in $file: $ORPHANED" >&2
            echo "  Your .secrets file may be missing entries." >&2
        fi

        # Update file
        if [ "$FILE_MODIFIED" -eq 1 ]; then
            mv "$TEMP_FILE" "$file"
            FILE_COUNT=$((FILE_COUNT + 1))
        else
            rm -f "$TEMP_FILE"
        fi
    done

    if [ $FILE_COUNT -eq 0 ]; then
        info "No REDACTED placeholders found (already restored)"
    else
        info "Successfully restored $FILE_COUNT file(s), $REPLACEMENT_COUNT replacement(s)"
    fi

    exit 0
}

main "$@"
