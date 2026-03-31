# op-ssh-load

Load SSH keys from 1Password into your ssh-agent on headless Linux servers.

Private keys are piped directly from 1Password to `ssh-add` and never touch the filesystem.

## Prerequisites

- A 1Password account with SSH keys stored in a vault
- A [1Password Service Account](https://developer.1password.com/docs/service-accounts/get-started/) with read access to that vault
- The [1Password CLI](https://developer.1password.com/docs/cli/get-started/) installed (`op`)

## Install

There are two ways to install: the install script or manually.

### Option A: Install script

The install script downloads `op-ssh-load`, prompts you for your service account token, and configures everything:

```sh
bash <(curl -sSfL https://raw.githubusercontent.com/narasaka/op-ssh-load/main/install.sh)
```

### Option B: Manual install

1. Download the script:

```sh
mkdir -p ~/.local/bin
curl -sSfL https://raw.githubusercontent.com/narasaka/op-ssh-load/main/op-ssh-load -o ~/.local/bin/op-ssh-load
chmod +x ~/.local/bin/op-ssh-load
```

Most Linux distributions add `~/.local/bin` to your PATH by default. If yours does not, add this to your `~/.bashrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

2. Configure your service account token:

```sh
mkdir -p ~/.config/op
chmod 700 ~/.config/op
echo 'YOUR_SERVICE_ACCOUNT_TOKEN' > ~/.config/op/service-account-token
chmod 600 ~/.config/op/service-account-token
```

Replace `YOUR_SERVICE_ACCOUNT_TOKEN` with your actual token (starts with `ops_`).

Alternatively, export it as an environment variable:

```sh
export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
```

### Set up ssh-agent auto-start (optional)

Add this to your `~/.bashrc` so the agent persists across SSH sessions:

```sh
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
```

Then reload your shell:

```sh
source ~/.bashrc
```

## Usage

Load all SSH keys from 1Password:

```sh
op-ssh-load
```

List available SSH keys without loading them:

```sh
op-ssh-load --list
```

Load a specific key by name:

```sh
op-ssh-load "GitHub"
```

Clear the agent and reload all keys:

```sh
op-ssh-load --clear
```

Verify keys are loaded:

```sh
ssh-add -l
```

## How it works

1. The script reads your service account token from `~/.config/op/service-account-token` (or the `OP_SERVICE_ACCOUNT_TOKEN` environment variable).
2. It queries 1Password for all items with the "SSH Key" category across accessible vaults.
3. For each key, it calls `op read` with the `?ssh-format=openssh` query parameter to get the private key in OpenSSH format.
4. The key is piped directly to `ssh-add /dev/stdin`. The private key is never written to disk.

## Creating a service account

1. Sign in to [1password.com](https://1password.com).
2. Go to Integrations, then Service Accounts.
3. Create a new service account.
4. Grant it read access to the vault(s) containing your SSH keys.
5. Copy the token and store it as described above.

## License

MIT
