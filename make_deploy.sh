#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# INPUT
###############################################################################

INPUT_PATH="${1:-}"
MODE="${2:-}"

DEPLOY_FTP=false
SITE_NAME=""

if [[ "${3:-}" == "--deploy" ]]; then
    DEPLOY_FTP=true
    SITE_NAME="${4:-}"
fi

###############################################################################
# VALIDATION
###############################################################################

if [[ -z "$INPUT_PATH" || -z "$MODE" ]]; then
    echo
    echo "Usage:"
    echo "  $0 <repo-path> <unpushed|since-push>"
    echo "  $0 <repo-path> <unpushed|since-push> --deploy <site-profile>"
    echo
    exit 1
fi

if [[ "$MODE" != "unpushed" && "$MODE" != "since-push" ]]; then
    echo "Invalid mode: $MODE"
    exit 1
fi

if [[ ! -d "$INPUT_PATH" ]]; then
    echo "Repository path not found:"
    echo "$INPUT_PATH"
    exit 1
fi

if [[ "$DEPLOY_FTP" == true && -z "$SITE_NAME" ]]; then
    echo
    echo "Site profile required."
    echo
    echo "Example:"
    echo "  $0 ../php/folermela.com since-push --deploy folermela_com"
    echo
    exit 1
fi

###############################################################################
# LOAD .deploy.env
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ENV_FILE="${SCRIPT_DIR}/.deploy.env"

if [[ -f "$DEPLOY_ENV_FILE" ]]; then
    set -a
    source "$DEPLOY_ENV_FILE"
    set +a
fi

###############################################################################
# RESOLVE REPO ROOT
###############################################################################

REPO_ROOT="$(cd "$INPUT_PATH" && git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
    echo "Not a git repository:"
    echo "$INPUT_PATH"
    exit 1
fi

cd "$REPO_ROOT"

###############################################################################
# GIT INFO
###############################################################################

BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD_COMMIT=$(git rev-parse HEAD)
SHORT_COMMIT=$(git rev-parse --short HEAD)

UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)

if [[ -z "$UPSTREAM" ]]; then
    echo "No upstream branch configured."
    exit 1
fi

LAST_PUSH_COMMIT=$(git merge-base HEAD "$UPSTREAM")

###############################################################################
# DEPLOY STRUCTURE
###############################################################################

DEPLOY_DIR="${REPO_ROOT}/deploy"

PACKAGE_NAME="$(date +"%Y%m%d_%H%M%S")"
PACKAGE_DIR="${DEPLOY_DIR}/${PACKAGE_NAME}"

MANIFEST_FILE="${PACKAGE_DIR}/manifest.txt"
DELETED_FILE="${PACKAGE_DIR}/deleted_files.txt"
DEPLOY_INFO="${PACKAGE_DIR}/deploy_info.txt"

HISTORY_FILE="${DEPLOY_DIR}/history.log"

mkdir -p "$PACKAGE_DIR"

touch "$MANIFEST_FILE"
touch "$DELETED_FILE"

###############################################################################
# COLLECT FILES
###############################################################################

TMP_FILE=$(mktemp)

if [[ "$MODE" == "unpushed" ]]; then

    git diff --name-only "$UPSTREAM"..HEAD > "$TMP_FILE"

    git diff --name-status "$UPSTREAM"..HEAD \
        | awk '$1=="D"{print $2}' \
        > "$DELETED_FILE"

else

    git diff --name-only "$LAST_PUSH_COMMIT"..HEAD >> "$TMP_FILE"

    git diff --cached --name-only >> "$TMP_FILE"

    git ls-files --others --exclude-standard >> "$TMP_FILE"

    sort -u "$TMP_FILE" -o "$TMP_FILE"

    git diff --name-status "$LAST_PUSH_COMMIT"..HEAD \
        | awk '$1=="D"{print $2}' \
        > "$DELETED_FILE"

fi

###############################################################################
# NO CHANGES
###############################################################################

if [[ ! -s "$TMP_FILE" ]]; then

    echo
    echo "No changes detected."
    echo

    rm -f "$TMP_FILE"
    rm -rf "$PACKAGE_DIR"

    exit 0
fi

###############################################################################
# COPY FILES
###############################################################################

FILE_COUNT=0

while IFS= read -r file; do

    [[ -z "$file" ]] && continue

    FULL_PATH="${REPO_ROOT}/${file}"

    if [[ -f "$FULL_PATH" ]]; then

        mkdir -p "$PACKAGE_DIR/$(dirname "$file")"

        cp -p "$FULL_PATH" "$PACKAGE_DIR/$file"

        echo "$file" >> "$MANIFEST_FILE"

        ((FILE_COUNT+=1))

    fi

done < "$TMP_FILE"

rm -f "$TMP_FILE"

###############################################################################
# FINAL CHECK
###############################################################################

if [[ "$FILE_COUNT" -eq 0 ]]; then

    echo "No valid files found."

    rm -rf "$PACKAGE_DIR"

    exit 1
fi

###############################################################################
# DEPLOY INFO
###############################################################################

cat > "$DEPLOY_INFO" <<EOF
Deployment Package
==================

Package Name : ${PACKAGE_NAME}
Mode         : ${MODE}
Branch       : ${BRANCH}
Commit       : ${HEAD_COMMIT}
Short Commit : ${SHORT_COMMIT}
Generated At : $(date)
Files        : $(wc -l < "$MANIFEST_FILE")
Deleted      : $(wc -l < "$DELETED_FILE")
EOF

###############################################################################
# FTP DEPLOYMENT
###############################################################################

FTP_STATUS="NOT_DEPLOYED"

if [[ "$DEPLOY_FTP" == true ]]; then

    FTP_HOST_VAR="SITE_${SITE_NAME}_FTP_HOST"
    FTP_USER_VAR="SITE_${SITE_NAME}_FTP_USER"
    FTP_PASSWORD_VAR="SITE_${SITE_NAME}_FTP_PASSWORD"
    FTP_REMOTE_DIR_VAR="SITE_${SITE_NAME}_FTP_REMOTE_DIR"

    FTP_HOST="${!FTP_HOST_VAR:-}"
    FTP_USER="${!FTP_USER_VAR:-}"
    FTP_PASSWORD="${!FTP_PASSWORD_VAR:-}"
    FTP_REMOTE_DIR="${!FTP_REMOTE_DIR_VAR:-}"

    FTP_HOST="${FTP_HOST#sftp://}"
    FTP_HOST="${FTP_HOST#ftp://}"

    MISSING=()

    [[ -z "$FTP_HOST" ]] && MISSING+=("$FTP_HOST_VAR")
    [[ -z "$FTP_USER" ]] && MISSING+=("$FTP_USER_VAR")
    [[ -z "$FTP_PASSWORD" ]] && MISSING+=("$FTP_PASSWORD_VAR")
    [[ -z "$FTP_REMOTE_DIR" ]] && MISSING+=("$FTP_REMOTE_DIR_VAR")

    if [[ ${#MISSING[@]} -gt 0 ]]; then

        echo
        echo "Missing configuration in .deploy.env"
        printf '%s\n' "${MISSING[@]}"
        echo

        exit 1

    fi

    if ! command -v lftp >/dev/null 2>&1; then
        echo "lftp is not installed."
        exit 1
    fi

    echo
    echo "Starting deployment..."
    echo "Site   : $SITE_NAME"
    echo "Host   : $FTP_HOST"
    echo "Remote : $FTP_REMOTE_DIR"
    echo

    ###########################################################################
    # BUILD DELETE COMMANDS
    ###########################################################################

    DELETE_CMDS=""

    if [[ -f "$DELETED_FILE" ]]; then

        while IFS= read -r file; do

            [[ -z "$file" ]] && continue

            DELETE_CMDS="${DELETE_CMDS}
rm -f \"$FTP_REMOTE_DIR/$file\""

        done < "$DELETED_FILE"

    fi

    ###########################################################################
    # SINGLE CONNECTION DEPLOY
    ###########################################################################

    if lftp -u "$FTP_USER","$FTP_PASSWORD" "sftp://$FTP_HOST" <<EOF

set sftp:auto-confirm yes
set ssl:verify-certificate no
set xfer:clobber yes
set cmd:trace no

echo Uploading files...

mirror -R \
    --verbose \
    --overwrite \
    "$PACKAGE_DIR" \
    "$FTP_REMOTE_DIR"

echo Removing deleted files...

$DELETE_CMDS

bye

EOF
    then

        FTP_STATUS="SUCCESS"

        echo
        echo "Deployment completed successfully."
        echo

    else

        FTP_STATUS="FAILED"

        echo
        echo "Deployment failed."
        echo

    fi

fi

###############################################################################
# HISTORY
###############################################################################

cat >> "$HISTORY_FILE" <<EOF

------------------------------------------------------------
Time       : $(date)
Package    : ${PACKAGE_NAME}
Mode       : ${MODE}
Branch     : ${BRANCH}
Commit     : ${HEAD_COMMIT}
Files      : ${FILE_COUNT}
Site       : ${SITE_NAME:-N/A}
FTP Status : ${FTP_STATUS}
EOF

###############################################################################
# OUTPUT
###############################################################################

echo
echo "Deployment package created successfully."
echo
echo "Repository : $REPO_ROOT"
echo "Package    : $PACKAGE_DIR"
echo "Files      : $FILE_COUNT"
echo "FTP Status : $FTP_STATUS"
echo