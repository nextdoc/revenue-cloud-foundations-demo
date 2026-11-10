#!/usr/bin/env bash
#
# Install the Nextdoc package into an existing Revenue Cloud Foundations org.
#
# Prerequisites: Salesforce CLI (`sf`) installed, and the org built by
# Revenue Cloud Foundations and authenticated under the alias in the ORG_ALIAS env var.
# Run this script from the project directory it lives in.
#
# Usage: ./script/setup-org.sh [installation-key]
# The package installation key comes from Nextdoc. Pass it as the first
# argument or set NEXTDOC_INSTALLATION_KEY.

set -euo pipefail

ORG_ALIAS="${ORG_ALIAS:?Set ORG_ALIAS to the sf alias of your scratch org}"
INSTALLATION_KEY="${1:-${NEXTDOC_INSTALLATION_KEY:-}}"
if [[ -z "${INSTALLATION_KEY}" ]]; then
  echo "Provide the installation key as the first argument or set NEXTDOC_INSTALLATION_KEY." >&2
  exit 1
fi
PACKAGE_VERSION_ID="04tOm000000tlpVIAQ"
SOURCE_DIR="force-app"
# Permission sets from the INSTALLED PACKAGE, which are not in this project's
# permissionsets/ directory and so cannot be discovered from it.
PACKAGE_PERMSETS=("Nextdoc_Stream_User")

echo "==> 1/4 Installing Nextdoc package ${PACKAGE_VERSION_ID}..."
sf package install \
  --package "${PACKAGE_VERSION_ID}" \
  --installation-key "${INSTALLATION_KEY}" \
  --target-org "${ORG_ALIAS}" \
  --security-type AllUsers \
  --wait 10 \
  --publish-wait 10 \
  --no-prompt

# The deploy runs in three passes because two dependencies point in opposite
# directions and a --source-dir deploy is atomic — one bad component rolls back
# everything in the same pass.
#
#   2a types, 2b records: a formula field over
#   $CustomMetadata.<Type>__mdt.<Record> needs the RECORD to exist before
#   objects/ will validate, which is the opposite of the usual "records follow
#   their type" order. Deploying objects/ whole would fail that field and roll
#   back the mdt type along with it, so the types go first on their own.
#
#   2c: everything else.
#
# Both passes no-op cleanly when a demo has no __mdt types or no metadata.

echo "==> 2a/4 Deploying custom metadata TYPES..."
MDT_TYPE_DIRS=()
for dir in "${SOURCE_DIR}"/main/default/objects/*__mdt/; do
  [[ -d "${dir}" ]] || continue
  MDT_TYPE_DIRS+=(--source-dir "${dir%/}")
done
if [[ ${#MDT_TYPE_DIRS[@]} -gt 0 ]]; then
  sf project deploy start "${MDT_TYPE_DIRS[@]}" --target-org "${ORG_ALIAS}"
else
  echo "  No __mdt types to deploy."
fi

echo "==> 2b/4 Deploying custom metadata RECORDS..."
if [[ -d "${SOURCE_DIR}/main/default/customMetadata" ]]; then
  sf project deploy start \
    --source-dir "${SOURCE_DIR}/main/default/customMetadata" \
    --target-org "${ORG_ALIAS}"
else
  echo "  No custom metadata records to deploy."
fi

echo "==> 2c/4 Deploying remaining demo metadata from '${SOURCE_DIR}'..."
# Directories are globbed rather than listed, so new metadata types are picked
# up without editing this script.
DEPLOY_DIRS=()
for dir in "${SOURCE_DIR}"/main/default/*/; do
  [[ -d "${dir}" ]] || continue
  case "$(basename "${dir}")" in
    customMetadata) continue ;;
  esac
  DEPLOY_DIRS+=(--source-dir "${dir%/}")
done
if [[ ${#DEPLOY_DIRS[@]} -gt 0 ]]; then
  sf project deploy start "${DEPLOY_DIRS[@]}" --target-org "${ORG_ALIAS}"
else
  echo "  Nothing further to deploy."
fi

# The assign list is DERIVED from what was actually deployed, not hand-listed, so
# adding a permission set to permissionsets/ is enough to get it assigned. A
# permission set that is deployed but never assigned fails silently here and
# surfaces much later as a confusing "No such column" error at data load — the
# data API reports a field the running user has no FLS on as nonexistent.
PERMSETS=("${PACKAGE_PERMSETS[@]}")
for permset_file in "${SOURCE_DIR}"/main/default/permissionsets/*.permissionset-meta.xml; do
  [[ -f "${permset_file}" ]] || continue
  PERMSETS+=("$(basename "${permset_file}" .permissionset-meta.xml)")
done

echo "==> 3/4 Assigning permission sets: ${PERMSETS[*]}..."
for permset in "${PERMSETS[@]}"; do
  sf org assign permset --name "${permset}" --target-org "${ORG_ALIAS}"
done

echo "==> 4/4 Opening org..."
sf org open --target-org "${ORG_ALIAS}"

# Pull the org id from the JSON; sed keeps this dependency-free (no jq required).
ORG_ID="$(sf org display --target-org "${ORG_ALIAS}" --json \
  | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
echo "Done. Scratch org '${ORG_ALIAS}' is ready."
echo "Org ID: ${ORG_ID} — provide this to Nextdoc when requesting org activation."
