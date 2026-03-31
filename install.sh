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
  # Check if it's already in a shell config but not active in this session
  path_in_config=false
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile" \
            "$HOME/.config/fish/config.fish"; do
    if [[ -f "$rc" ]] && grep -q '\.local/bin' "$rc" 2>/dev/null; then
      path_in_config=true
      break
    fi
  done

  if $path_in_config; then
    info "${INSTALL_DIR} is in your shell config but not active in this session."
    echo "    Start a new shell or source your config to activate it."
  else
    warn "${INSTALL_DIR} is not in your PATH."
    echo "    Add this to your shell config (~/.bashrc, ~/.zshrc, ~/.profile, etc.):"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
  fi
fi

# --- Configure service account token ---
configure_token=true
if [[ -f "$TOKEN_FILE" && -s "$TOKEN_FILE" ]]; then
  info "Service account token already configured at ${TOKEN_FILE}."
  echo ""
  read -rp "Overwrite it? [y/N] " overwrite
  if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
    info "Keeping existing token."
    configure_token=false
  fi
fi

if $configure_token; then
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
fi

# --- Offer ssh-agent auto-start ---
detect_shell_config() {
  case "$(basename "${SHELL:-/bin/bash}")" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) echo "$HOME/.bashrc" ;;
    fish) echo "" ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

agent_already_configured() {
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if grep -q 'SSH_ENV=.*agent-env' "$rc" 2>/dev/null; then
      echo "$rc"
      return 0
    fi
  done
  return 1
}

if existing_rc="$(agent_already_configured)"; then
  info "ssh-agent auto-start already configured in ${existing_rc}."
else
  SHELL_RC="$(detect_shell_config)"
  if [[ -n "$SHELL_RC" ]]; then
    echo ""
    read -rp "Set up ssh-agent to start automatically on login? [y/N] " setup_agent
    if [[ "$setup_agent" =~ ^[Yy]$ ]]; then
      cat >> "$SHELL_RC" << 'AGENT_EOF'

# ssh-agent auto-start (added by op-ssh-load)
SSH_ENV="$HOME/.ssh/agent-env"
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
  if [ -f "$SSH_ENV" ]; then
    . "$SSH_ENV" > /dev/null
    if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
      eval "$(ssh-agent -s)" > /dev/null
      echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK; export SSH_AGENT_PID=$SSH_AGENT_PID" > "$SSH_ENV"
      chmod 600 "$SSH_ENV"
    fi
  else
    mkdir -p "$HOME/.ssh"
    eval "$(ssh-agent -s)" > /dev/null
    echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK; export SSH_AGENT_PID=$SSH_AGENT_PID" > "$SSH_ENV"
    chmod 600 "$SSH_ENV"
  fi
fi
AGENT_EOF
      info "ssh-agent auto-start added to ${SHELL_RC}."
    fi
  else
    warn "Fish shell detected. ssh-agent auto-start requires manual setup."
    echo "    See: https://github.com/narasaka/op-ssh-load#set-up-ssh-agent-auto-start-optional"
  fi
fi

echo ""
info "Done. Run 'op-ssh-load' to load your SSH keys."
