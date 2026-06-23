#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# INPUT
###############################################################################

INPUT_PATH="${1:-}"
MODE="${2:-}"

if [[ -z "$INPUT_PATH" || -z "$MODE" ]]; then
    echo "Usage: $0 <repo-path> <unpushed|since-push>"
    exit 1
fi

###############################################################################
# RESOLVE REAL GIT ROOT (IMPORTANT FIX)
###############################################################################

if [[ ! -d "$INPUT_PATH" ]]; then
    echo "Error: Path not found -> $INPUT_PATH"
    exit 1
fi

REPO_ROOT="$(cd "$INPUT_PATH" && git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
    echo "Error: Not a git repository -> $INPUT_PATH"
    exit 1
fi

cd "$REPO_ROOT"

###############################################################################
# GIT INFO
###############################################################################

BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD_COMMIT=$(git rev-parse HEAD)

UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)

if [[ -z "$UPSTREAM" ]]; then
    echo "Error: No upstream branch configured."
    exit 1
fi

LAST_PUSH_COMMIT=$(git merge-base HEAD "$UPSTREAM")

###############################################################################
# DEPLOY STRUCTURE (INSIDE REPO ROOT)  ✔ FIXED
###############################################################################

DEPLOY_DIR="${REPO_ROOT}/deploy"
PACKAGE_NAME="$(date +"%Y%m%d_%H%M%S")"
PACKAGE_DIR="${DEPLOY_DIR}/${PACKAGE_NAME}"

MANIFEST_FILE="${PACKAGE_DIR}/manifest.txt"
DELETED_FILE="${PACKAGE_DIR}/deleted_files.txt"
DEPLOY_INFO="${PACKAGE_DIR}/deploy_info.txt"
HISTORY_FILE="${DEPLOY_DIR}/history.log"

mkdir -p "$PACKAGE_DIR"

touch "$MANIFEST_FILE" "$DELETED_FILE"

###############################################################################
# COLLECT FILES
###############################################################################

TMP_FILE=$(mktemp)

if [[ "$MODE" == "unpushed" ]]; then

    git diff --name-only "$UPSTREAM"..HEAD > "$TMP_FILE"

    git diff --name-status "$UPSTREAM"..HEAD \
        | awk '$1=="D"{print $2}' \
        > "$DELETED_FILE"

elif [[ "$MODE" == "since-push" ]]; then

    git diff --name-only "$LAST_PUSH_COMMIT"..HEAD >> "$TMP_FILE"
    git diff --cached --name-only >> "$TMP_FILE"
    git ls-files --others --exclude-standard >> "$TMP_FILE"

    sort -u "$TMP_FILE" -o "$TMP_FILE"

    git diff --name-status "$LAST_PUSH_COMMIT"..HEAD \
        | awk '$1=="D"{print $2}' \
        > "$DELETED_FILE"

else
    echo "Invalid mode: $MODE"
    exit 1
fi

###############################################################################
# SAFETY CHECK
###############################################################################

if [[ ! -s "$TMP_FILE" ]]; then
    echo "No changes detected. Nothing to deploy."
    rm -f "$TMP_FILE"
    rm -rf "$PACKAGE_DIR"
    exit 0
fi

###############################################################################
# COPY FILES (CORRECT RELATIVE HANDLING FIXED)
###############################################################################

FILE_COUNT=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    FULL_PATH="${REPO_ROOT}/${file}"

    if [[ -f "$FULL_PATH" ]]; then
        mkdir -p "$PACKAGE_DIR/$(dirname "$file")"
        cp -p "$FULL_PATH" "$PACKAGE_DIR/$file"
        echo "$file" >> "$MANIFEST_FILE"
        ((FILE_COUNT++))
    fi

done < "$TMP_FILE"

rm -f "$TMP_FILE"

###############################################################################
# FINAL CHECK
###############################################################################

if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "No valid files found to deploy."
    rm -rf "$PACKAGE_DIR"
    exit 1
fi

###############################################################################
# DEPLOY INFO
###############################################################################

cat > "$DEPLOY_INFO" <<EOF
Deployment Package
==================

Mode         : ${MODE}
Branch       : ${BRANCH}
Commit       : ${HEAD_COMMIT}
Generated At : $(date)

Files        : ${FILE_COUNT}
EOF

###############################################################################
# HISTORY LOG
###############################################################################

cat >> "$HISTORY_FILE" <<EOF
------------------------------------------------------------
Time      : $(date)
Package   : ${PACKAGE_NAME}
Mode      : ${MODE}
Branch    : ${BRANCH}
Commit    : ${HEAD_COMMIT}
EOF

###############################################################################
# OUTPUT
###############################################################################

echo
echo "Deployment created successfully"
echo "Repo: $REPO_ROOT"
echo "Package: $PACKAGE_DIR"
echo "Files: $FILE_COUNT"
echo