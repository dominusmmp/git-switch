# GitSwitch

A tiny tool to switch between GitHub accounts using the `gh` CLI and configure Git user settings.

## Features

- Switch GitHub accounts with `gh auth switch`.
- Set global or local (`--single`) Git user.name and user.email.
- Support for custom email (`--email`) and hostname (`--hostname`).
- Unset local Git settings with `--unset-single`.

## Installation

### Automatic Installation/Update

Run one of the following commands to download and execute the installer:

Using `curl`:

```bash
/bin/bash -c "$(curl -fsSL https://github.com/dominusmmp/git-switch/raw/master/install.sh)"
```

Using `wget`:

```bash
/bin/bash -c "$(wget -qO- https://github.com/dominusmmp/git-switch/raw/master/install.sh)"
```

This installs `gitswitch` to `/usr/local/bin` or `$HOME/.local/bin` and sets up dependencies (`gh`, `jq`).

### Manual Installation

In case the automatic installer fails:

1. **Download the script**:

   ```bash
   curl -fsSL "https://github.com/dominusmmp/git-switch/raw/master/gitswitch.sh" -o gitswitch.sh
   ```

   or

   ```bash
   wget -qO gitswitch.sh "https://github.com/dominusmmp/git-switch/raw/master/gitswitch.sh"
   ```

2. **Make it executable**:

   ```bash
   chmod +x gitswitch.sh
   ```

3. **Move to a bin directory**:

   ```bash
   sudo mv gitswitch.sh /usr/local/bin/gitswitch
   ```

   or

   ```bash
   mv gitswitch.sh $HOME/.local/bin/gitswitch
   ```

4. **Ensure dependencies**: Install `git`, `gh`, and `jq` using your package manager (e.g., `apt`, `dnf`, `brew`).

5. **Add to PATH** (if using `$HOME/.local/bin`):

   ```bash
   echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

## Usage

```bash
gitswitch [--single] [--hostname <host>] [--email <email>] <username>
gitswitch --unset-single
gitswitch -h | --help
```

- `<username>`: GitHub username to switch to.
- `--single`: Apply settings to the current repository only.
- `--unset-single`: Remove local Git settings.
- `--hostname`: Specify GitHub instance (default: github.com).
- `--email`: Use a custom email instead of the default noreply email.

## Examples

Switch to a global GitHub account:

```bash
gitswitch myusername
```

Switch for the current repository only:

```bash
gitswitch --single myusername
```

Use a custom email and hostname:

```bash
gitswitch --hostname github.company.com --email user@company.com myusername
```

Unset local repository settings:

```bash
gitswitch --unset-single
```

## Notes

- Ensure you are logged in with `gh auth login -u <username> -h <hostname>` before switching.
- Local option (`--single`) only affects the current repository's git user settings; Still the `gh` user change applies globally (even if `--single` is used).

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.
