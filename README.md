# op-ssh-load

Load SSH keys from 1Password into your ssh-agent on headless Linux servers.

Private keys are piped directly from 1Password to `ssh-add` and never touch the filesystem.

## Prerequisites

- A 1Password account with SSH keys stored in a vault
- A [1Password Service Account](https://developer.1password.com/docs/service-accounts/get-started/) with read access to that vault

## Install

### 1. Install the 1Password CLI

If you have root access:

```sh
sudo apt update && sudo apt install -y 1password-cli
```

Without root (download to your home directory):

```sh
mkdir -p ~/bin
OP_VERSION="2.33.1"
curl -sSfL "https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_VERSION}/op_linux_amd64_v${OP_VERSION}.zip" -o /tmp/op.zip
python3 -c "import zipfile; zipfile.ZipFile('/tmp/op.zip').extractall('/tmp/op_extract')"
mv /tmp/op_extract/op ~/bin/op
chmod +x ~/bin/op
rm -rf /tmp/op.zip /tmp/op_extract
```

Verify it works:

```sh
op --version
```

### 2. Install op-ssh-load

```sh
mkdir -p ~/bin
curl -sSfL https://raw.githubusercontent.com/narasaka/op-ssh-load/main/op-ssh-load -o ~/bin/op-ssh-load
chmod +x ~/bin/op-ssh-load
```

Make sure `~/bin` is in your PATH. Add this to your `~/.bashrc` if it is not:

```sh
export PATH="$HOME/bin:$PATH"
```

### 3. Configure your service account token

Create the token file:

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

### 4. Set up ssh-agent auto-start (optional)

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
