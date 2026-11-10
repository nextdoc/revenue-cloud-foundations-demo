#!/usr/bin/env bash
#
# Configure the Nextdoc external connection in a demo scratch org.
#
# Runs two anonymous-Apex steps against the org via `sf apex run`:
#   1. Create the External Credential (PostInstall.ApiCredentials)
#   2. Configure the Nextdoc_Connection__c custom setting
#      (PostInstall.NextdocConnectionBuilder)
#
# Prerequisites: the Nextdoc package must already be installed (run setup-org.sh
# first). Run this from the project directory it lives in.
#
# Usage: ./script/setup-connection.sh [client-id]
# Nextdoc provides the OAuth client ID and secret. Pass the client ID as the
# first argument or set NEXTDOC_CLIENT_ID. Set NEXTDOC_CLIENT_SECRET for the
# secret, or you will be prompted for it.

set -euo pipefail

ORG_ALIAS="${ORG_ALIAS:?Set ORG_ALIAS to the sf alias of your scratch org}"
CLIENT_ID="${1:-${NEXTDOC_CLIENT_ID:-}}"
if [[ -z "${CLIENT_ID}" ]]; then
  echo "Provide the client ID as the first argument or set NEXTDOC_CLIENT_ID." >&2
  exit 1
fi

# --- Values templated at scaffold time -------------------------------------
CREDENTIAL_NAME="nxd__Nextdoc"
API_SERVER="https://au.nextdoc.io/app"
SETUP_SERVER="https://sfdc01.nextdoc.io/app"
STREAM_POD="ap01"
# ---------------------------------------------------------------------------

if [[ -z "${NEXTDOC_CLIENT_SECRET:-}" ]]; then
  read -rs -p "Nextdoc OAuth client secret: " NEXTDOC_CLIENT_SECRET
  echo
fi

# Escape for an Apex single-quoted string literal: backslash first, then quote.
# Secrets can contain base64 chars (/ + =) and sometimes \ or ', which would
# otherwise corrupt the literal, silently mangling the stored secret with no
# compile error.
APEX_CLIENT_SECRET="${NEXTDOC_CLIENT_SECRET//\\/\\\\}"
APEX_CLIENT_SECRET="${APEX_CLIENT_SECRET//\'/\\\'}"

# Extract one scalar field from `sf ... --json` output. Dependency-free (sed,
# no jq/python) to match setup-org.sh. Handles both quoted strings
# ("compileProblem": "...") and bare booleans ("compiled": true).
json_field() {
  # $1 = field name, $2 = json
  sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/p' <<<"$2" | head -1
}

run_apex() {
  # Run anonymous Apex (read on stdin) against the target org.
  # Process substitution gives `sf apex run --file` a /dev/fd path while the
  # Apex only ever streams through memory — the client secret never lands on
  # disk. `cat` runs in the foreground of the substituted process so it keeps
  # this function's inherited stdin (the here-doc).
  #
  # `--json` is deliberate: the default text output echoes the executed source
  # (which contains the client secret) to the terminal. With --json we capture
  # the result and print only status fields, so the secret never reaches stdout.
  local out
  out="$(sf apex run --file <(cat) --target-org "${ORG_ALIAS}" --json)"

  if [[ "$(json_field compiled "$out")" != "true" ]]; then
    echo "  Apex failed to compile: $(json_field compileProblem "$out")" >&2
    return 1
  fi
  if [[ "$(json_field success "$out")" != "true" ]]; then
    echo "  Apex execution failed: $(json_field exceptionMessage "$out")" >&2
    return 1
  fi
  echo "  Apex executed successfully."
}

echo "==> 1/2 Creating External Credential '${CREDENTIAL_NAME}'..."
run_apex <<APEX
ConnectApi.Credential createdCredential = new nxd.PostInstall.ApiCredentials('${CREDENTIAL_NAME}')
    .clientId('${CLIENT_ID}')
    .clientSecret('${APEX_CLIENT_SECRET}')
    .configure();
System.debug('Configured credential: ' + createdCredential.principalName);
System.debug('External Credential: ' + createdCredential.externalCredential);
APEX

echo "==> 2/2 Configuring Nextdoc_Connection__c custom setting (ORG level)..."
run_apex <<APEX
nxd__Nextdoc_Connection__c connection = new nxd.PostInstall.NextdocConnectionBuilder(nxd.PostInstall.SettingLevel.ORG)
    .apiServer('${API_SERVER}')
    .setupServer('${SETUP_SERVER}')
    .streamPod('${STREAM_POD}')
    .configure();
System.debug('Configured nxd__Nextdoc_Connection__c');
System.debug('API Server: ' + connection.nxd__API_Server__c);
System.debug('Setup Server: ' + connection.nxd__Setup_Server__c);
System.debug('Stream Pod: ' + connection.nxd__Stream_Pod__c);
APEX

echo "Done. Nextdoc connection configured for org '${ORG_ALIAS}'."
