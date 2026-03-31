#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/op"
TOKEN_FILE="${CONFIG_DIR}/service-account-token"
SCRIPT_URL="https://raw.githubusercontent.com/narasaka/op-ssh-load/main/op-ssh-load"

# --- Colors ---
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' YELLOW='' RED='' BOLD='' RESET=''
fi

info()  { echo -e "${GREEN}[+]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $*"; }
error() { echo -e "${RED}[x]${RESET} $*" >&2; }
die()   { error "$@"; exit 1; }

# --- Check dependencies ---
command -v curl &>/dev/null || die "curl is required but not installed."
command -v op &>/dev/null || {
  warn "1Password CLI (op) is not installed."
  echo "    Install it first: https://developer.1password.com/docs/cli/get-started/"
  exit 1
}

# --- Install op-ssh-load ---
info "Installing op-ssh-load to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
curl -sSfL "$SCRIPT_URL" -o "${INSTALL_DIR}/op-ssh-load"
chmod +x "${INSTALL_DIR}/op-ssh-load"
info "Installed."

# --- Check PATH ---
if ! echo "$PATH" | tr ':' '\n' | grep -q "^${INSTALL_DIR}$"; then
  warn "${INSTALL_DIR} is not in your PATH."
  echo "    Add this to your ~/.bashrc or ~/.profile:"
  echo ""
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
fi

# --- Configure service account token ---
if [[ -f "$TOKEN_FILE" && -s "$TOKEN_FILE" ]]; then
  info "Service account token already configured at ${TOKEN_FILE}."
  echo ""
  read -rp "Overwrite it? [y/N] " overwrite
  if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
    info "Keeping existing token."
    echo ""
    info "Done. Run 'op-ssh-load' to load your SSH keys."
    exit 0
  fi
fi

echo ""
echo -e "${BOLD}Paste your 1Password service account token below.${RESET}"
echo "It starts with ops_ and you can create one at:"
echo "https://developer.1password.com/docs/service-accounts/get-started/"
echo ""
read -rsp "Token (input is hidden): " token
echo ""

if [[ -z "$token" ]]; then
  die "No token provided."
fi

if [[ ! "$token" =~ ^ops_ ]]; then
  warn "Token does not start with 'ops_'. Saving it anyway."
fi

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
echo "$token" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
info "Token saved to ${TOKEN_FILE}."

# --- Verify token works ---
info "Verifying token..."
if OP_SERVICE_ACCOUNT_TOKEN="$token" op whoami &>/dev/null; then
  info "Authenticated successfully."
else
  warn "Could not authenticate. Check that your token is correct."
  echo "    You can replace it later by editing: ${TOKEN_FILE}"
fi

echo ""
info "Done. Run 'op-ssh-load' to load your SSH keys."
