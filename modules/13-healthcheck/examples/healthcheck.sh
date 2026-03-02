#!/usr/bin/env bash
# ============================================================
# healthcheck.sh — OpenTofu project healthcheck
#
# Usage:
#   ./healthcheck.sh [TARGET_DIR]
#
# Arguments:
#   TARGET_DIR  Path to the OpenTofu configuration directory to check.
#               Defaults to the current working directory.
#
# Exit codes:
#   0  All checks passed (warnings are allowed)
#   1  One or more checks FAILED
#
# Requires: tofu, jq (optional for state checks), grep, awk
# ============================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────
PASS=0
WARN=0
FAIL=0

# ── Helpers ───────────────────────────────────────────────────────────────
pass()  { echo -e "${GREEN}[PASS]${RESET} $*"; PASS=$((PASS + 1)); }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; WARN=$((WARN + 1)); }
fail()  { echo -e "${RED}[FAIL]${RESET} $*"; FAIL=$((FAIL + 1)); }
info()  { echo -e "${CYAN}[INFO]${RESET} $*"; }
title() { echo -e "${BOLD}$*${RESET}"; }

# ── Argument parsing ──────────────────────────────────────────────────────
TARGET_DIR="${1:-$(pwd)}"
TARGET_DIR="$(realpath "$TARGET_DIR")"

if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: directory not found: $TARGET_DIR" >&2
  exit 1
fi

# ── Header ────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
title "  OpenTofu Healthcheck"
info  "  Directory : $TARGET_DIR"
info  "  Date      : $(date '+%Y-%m-%d %H:%M:%S')"
echo "══════════════════════════════════════════"
echo ""

# ── Check 1: tofu binary ──────────────────────────────────────────────────
title "── 1. Binary"
if command -v tofu &>/dev/null; then
  TOFU_VER="$(tofu version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || tofu version | head -1)"
  pass "tofu found: $TOFU_VER"
else
  fail "tofu binary not found in PATH"
  echo ""
  echo "══════════════════════════════════════════"
  echo -e "  ${RED}Healthcheck aborted: tofu not found${RESET}"
  echo "══════════════════════════════════════════"
  exit 1
fi
echo ""

# ── Check 2: .tf files present ────────────────────────────────────────────
title "── 2. Files"
TF_FILES="$(find "$TARGET_DIR" -maxdepth 1 -name "*.tf" | wc -l | tr -d ' ')"
if [ "$TF_FILES" -gt 0 ]; then
  pass ".tf files found: $TF_FILES"
else
  fail "no .tf files found in $TARGET_DIR"
fi

# Check for versions.tf
if [ -f "$TARGET_DIR/versions.tf" ]; then
  pass "versions.tf present"
else
  warn "versions.tf not found — provider versions may be unconstrained"
fi

# Check for .terraform.lock.hcl
if [ -f "$TARGET_DIR/.terraform.lock.hcl" ]; then
  pass ".terraform.lock.hcl present (provider checksums locked)"
else
  warn ".terraform.lock.hcl not found — run 'tofu init' to generate it"
fi
echo ""

# ── Check 3: fmt ──────────────────────────────────────────────────────────
title "── 3. Format (tofu fmt -check)"
if tofu fmt -check -recursive "$TARGET_DIR" &>/dev/null; then
  pass "fmt: all files are correctly formatted"
else
  UNFORMATTED="$(tofu fmt -check -recursive "$TARGET_DIR" 2>&1 || true)"
  fail "fmt: the following files need formatting:\n${UNFORMATTED}"
  info "  Fix with: tofu fmt -recursive $TARGET_DIR"
fi
echo ""

# ── Check 4: validate ─────────────────────────────────────────────────────
title "── 4. Validate (tofu validate)"
cd "$TARGET_DIR"

INIT_OUT="$(tofu init -backend=false -no-color 2>&1)"
if [ $? -ne 0 ]; then
  fail "init failed (required for validate):\n$INIT_OUT"
else
  VALIDATE_OUT="$(tofu validate -no-color 2>&1)"
  if echo "$VALIDATE_OUT" | grep -q "Success"; then
    pass "validate: configuration is valid"
  else
    fail "validate: errors found:\n$VALIDATE_OUT"
  fi
fi
echo ""

# ── Check 5: required_version ─────────────────────────────────────────────
title "── 5. Version Constraints"
if grep -qr 'required_version' "$TARGET_DIR"/*.tf 2>/dev/null; then
  REQ_VER="$(grep -h 'required_version' "$TARGET_DIR"/*.tf | head -1 | tr -d ' ')"
  pass "required_version constraint found: $REQ_VER"
else
  warn "required_version not found — add to versions.tf to pin OpenTofu version"
fi

# Check for unconstrained provider versions
if grep -qrE 'version\s*=\s*"\*"' "$TARGET_DIR"/*.tf 2>/dev/null; then
  fail "security: found unconstrained provider version (version = \"*\") — pin with ~>"
else
  pass "provider versions: no wildcard constraints found"
fi
echo ""

# ── Check 6: outputs documentation ────────────────────────────────────────
title "── 6. Output Documentation"
if [ -f "$TARGET_DIR/outputs.tf" ]; then
  # Count output blocks missing a description
  OUTPUT_COUNT="$(grep -c '^output ' "$TARGET_DIR/outputs.tf" || true)"
  DESC_COUNT="$(grep -c 'description' "$TARGET_DIR/outputs.tf" || true)"

  if [ "$OUTPUT_COUNT" -eq 0 ]; then
    info "outputs.tf has no output blocks"
  elif [ "$DESC_COUNT" -ge "$OUTPUT_COUNT" ]; then
    pass "outputs: all $OUTPUT_COUNT output(s) have descriptions"
  else
    MISSING=$((OUTPUT_COUNT - DESC_COUNT))
    warn "outputs: $MISSING of $OUTPUT_COUNT output(s) missing a description"
  fi
else
  info "outputs.tf not found — skipping output documentation check"
fi
echo ""

# ── Check 7: security smells ──────────────────────────────────────────────
title "── 7. Security Smells"

# Check for sensitive outputs set to false
if grep -rn 'sensitive\s*=\s*false' "$TARGET_DIR"/*.tf 2>/dev/null; then
  warn "security: found 'sensitive = false' — review if outputs contain secrets"
else
  pass "security: no 'sensitive = false' overrides found"
fi

# Check for hardcoded secrets in variable defaults
SECRET_PATTERN='default\s*=\s*"[^"]{8,}"'
SECRET_NAMES='password|secret|token|key|credential|passphrase'
HARDCODED="$(grep -rnEi "($SECRET_NAMES).*$SECRET_PATTERN|$SECRET_PATTERN.*($SECRET_NAMES)" \
  "$TARGET_DIR"/*.tf 2>/dev/null || true)"
if [ -n "$HARDCODED" ]; then
  fail "security: possible hardcoded secret in variable default:\n$HARDCODED"
else
  pass "security: no obvious hardcoded secrets in variable defaults"
fi

# Check for backend credentials in .tf files
BACKEND_CREDS="$(grep -rniE '(password|token|secret)\s*=' "$TARGET_DIR"/*.tf 2>/dev/null \
  | grep -i 'backend\|http\|s3\|gcs\|azurerm' || true)"
if [ -n "$BACKEND_CREDS" ]; then
  warn "security: possible credentials in backend config — use env vars instead:\n$BACKEND_CREDS"
else
  pass "security: no inline backend credentials detected"
fi
echo ""

# ── Check 8: plan (drift detection) ──────────────────────────────────────
title "── 8. Plan / Drift Detection"
if [ -f "$TARGET_DIR/.terraform/terraform.tfstate" ] || [ -f "$TARGET_DIR/terraform.tfstate" ]; then
  PLAN_OUT="$(tofu plan -no-color -detailed-exitcode 2>&1)"
  PLAN_EXIT=$?
  case $PLAN_EXIT in
    0) pass "plan: no changes — infrastructure matches state" ;;
    1) fail "plan: errors detected:\n$PLAN_OUT" ;;
    2) warn "plan: $(echo "$PLAN_OUT" | grep -c 'will be') resource change(s) pending" ;;
  esac
else
  info "plan: skipped (no state file found — run 'tofu apply' first for drift detection)"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════"
title "  Results"
echo -e "  ${GREEN}${PASS} passed${RESET}   ${YELLOW}${WARN} warned${RESET}   ${RED}${FAIL} failed${RESET}"
echo "══════════════════════════════════════════"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
