#!/bin/bash
# sanitize-secrets.sh - Pre-commit hook to sanitize secrets
# Replaces sensitive passwords with REDACTED-LINE-N placeholders

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
    echo "[SANITIZE] $1"
}

# Main logic
main() {
    # Change to repo root
    cd "$REPO_ROOT" || error_exit "Cannot change to repo root"

    # Check .secrets exists
    if [ ! -f "$SECRETS_FILE" ]; then
        error_exit "Missing $SECRETS_FILE file. Create one using .secrets.example:
    cp .secrets.example .secrets
    chmod 600 .secrets
    # Edit .secrets with your actual passwords"
    fi

    # Read secrets into array
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

        # Skip documentation and example files
        if [ "$file" = ".secrets.example" ] || [ "$file" = "README.md" ]; then
            continue
        fi

        # Skip binary files
        if file -b --mime-encoding "$file" | grep -q "binary"; then
            continue
        fi

        # Create temp file
        TEMP_FILE=$(mktemp)
        trap "rm -f $TEMP_FILE" EXIT

        # Copy original to temp
        cp "$file" "$TEMP_FILE"

        FILE_MODIFIED=0

        # Replace secrets (longest first to avoid substring issues)
        # Process in reverse order (higher indices first)
        for ((i=${#SECRETS[@]}; i>=1; i--)); do
            secret="${SECRETS[$i]}"
            placeholder="REDACTED-LINE-$i"

            # Skip if already contains this placeholder (already sanitized)
            if grep -q "$placeholder" "$TEMP_FILE" 2>/dev/null; then
                continue
            fi

            # Escape special characters for sed (search pattern)
            escaped_secret=$(printf '%s\n' "$secret" | sed 's/[[\.*^$/]/\\&/g')

            # Count occurrences before replacement
            BEFORE_COUNT=$(grep -o "$escaped_secret" "$TEMP_FILE" 2>/dev/null | wc -l || echo 0)

            if [ "$BEFORE_COUNT" -gt 0 ]; then
                # Perform replacement
                sed -i "s/$escaped_secret/$placeholder/g" "$TEMP_FILE"
                REPLACEMENT_COUNT=$((REPLACEMENT_COUNT + BEFORE_COUNT))
                FILE_MODIFIED=1
                info "  $file: Replaced $BEFORE_COUNT occurrence(s) of secret $i"
            fi
        done

        # Only update if file changed
        if [ "$FILE_MODIFIED" -eq 1 ]; then
            mv "$TEMP_FILE" "$file"
            git add "$file"
            FILE_COUNT=$((FILE_COUNT + 1))
        else
            rm -f "$TEMP_FILE"
        fi
    done

    if [ $FILE_COUNT -eq 0 ]; then
        info "No secrets found in tracked files (already sanitized)"
    else
        info "Successfully sanitized $FILE_COUNT file(s), $REPLACEMENT_COUNT replacement(s)"
    fi

    exit 0
}

main "$@"
