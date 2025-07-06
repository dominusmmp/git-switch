#!/bin/bash

set -euo pipefail

SCRIPT_NAME="gitswitch"
REPO_URL="https://github.com/dominusmmp/git-switch/raw/master/gitswitch.sh"
INSTALL_DIR="/usr/local/bin"
FALLBACK_INSTALL_DIR="$HOME/.local/bin"

RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
BOLD='\033[1m'
RESET='\033[0m'

if [ ! -t 1 ]; then RED=''; YELLOW=''; GREEN=''; BOLD=''; RESET=''; fi

error_exit() {
  printf "${RED}Error: %b${RESET}\n" "$1" >&2
  exit 1
}

warn() {
  printf "${YELLOW}${BOLD}⚠️${RESET} %b\n" "$1" >&2
}

info() {
  printf "${GREEN}${BOLD}✓${RESET} %b\n" "$1"
}

check_downloader() {
  if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl -fsSL"
  elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget -qO-"
  else
    error_exit "Neither curl nor wget is installed. Please install one to proceed."
  fi
}

detect_os() {
  case "$(uname -s)" in
    Darwin)
      OS="macOS"
      PKG_MANAGER="brew"
      PKG_INSTALL="brew install"
      ;;
    Linux)
      OS="Linux"
      if command -v apt >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt-get install -y"
      elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="sudo dnf install -y"
      elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_INSTALL="sudo yum install -y"
      else
        PKG_MANAGER="none"
      fi
      ;;
    *)
      error_exit "Unsupported operating system."
      ;;
  esac
}

install_binary() {
  local tool="$1"
  local repo="$2"
  local bin_dir="$3"
  local os_type="$4"
  local arch_type
  local version

  case "$(uname -m)" in
    x86_64) arch_type="amd64" ;;
    aarch64|arm64) arch_type="arm64" ;;
    *) error_exit "Unsupported architecture for $1 binary installation."
  esac

  info "Fetching latest $tool release..."
  version=$($DOWNLOADER https://api.github.com/repos/$repo/releases/latest | jq -r .tag_name | sed 's/^v//') || error_exit "Failed to fetch latest $tool version."
  local file_name="${tool}_${version}_${os_type}_${arch_type}.tar.gz"
  local download_url="https://github.com/$repo/releases/download/v${version}/${file_name}"

  info "Downloading $tool $version to $bin_dir..."
  mkdir -p "$bin_dir" || error_exit "Failed to create $bin_dir."
  $DOWNLOADER "$download_url" | tar -xz -C "$bin_dir" --strip-components=1 "bin/$tool" 2>/dev/null || error_exit "Failed to download or extract $tool binary."
  chmod +x "$bin_dir/$tool" || error_exit "Failed to make $tool executable."
}

check_install_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    if [ -t 0 ]; then
      printf "gh CLI is not installed. Install it now? (Y/n): "
      read -r response
    else
      response="Y"
    fi

    if [[ "$response" =~ ^[Nn]$ ]]; then
      error_exit "gh CLI is required. Please install it manually from https://github.com/cli/cli/releases and rerun the script."
    else
      info "Installing gh CLI..."

      if [ "$PKG_MANAGER" = "brew" ]; then
        $PKG_INSTALL gh || error_exit "Failed to install gh CLI."
      elif [ "$PKG_MANAGER" = "none" ] || ! sudo -n true 2>/dev/null; then
        install_binary "gh" "cli/cli" "$FALLBACK_INSTALL_DIR" "linux"
      else
        if [ "$PKG_MANAGER" = "apt" ]; then
          sudo mkdir -p /usr/share/keyrings || error_exit "Failed to create /usr/share/keyrings."
          $DOWNLOADER https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null || error_exit "Failed to download GPG key."
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null || error_exit "Failed to add gh repository."
          sudo apt-get update >/dev/null 2>&1 || error_exit "Failed to update apt repository."
          $PKG_INSTALL gh || error_exit "Failed to install gh CLI. Check GPG signature issues at https://github.com/cli/cli/issues/9569."
        elif [ "$PKG_MANAGER" = "dnf" ]; then
          if command -v dnf5 >/dev/null 2>&1; then
            sudo dnf install -y dnf5-plugins || error_exit "Failed to install dnf5-plugins."
            sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo || error_exit "Failed to add gh repository."
            sudo dnf install -y gh --repo gh-cli || error_exit "Failed to install gh CLI. Check GPG signature issues at https://github.com/cli/cli/issues/9569."
          else
            sudo dnf install -y 'dnf-command(config-manager)' || error_exit "Failed to install dnf config-manager."
            sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo || error_exit "Failed to add gh repository."
            sudo dnf install -y gh --repo gh-cli || error_exit "Failed to install gh CLI. Check GPG signature issues at https://github.com/cli/cli/issues/9569."
          fi
        elif [ "$PKG_MANAGER" = "yum" ]; then
          sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo >/dev/null 2>&1 || error_exit "Failed to add gh repository."
          $PKG_INSTALL gh || error_exit "Failed to install gh CLI. Check GPG signature issues at https://github.com/cli/cli/issues/9569."
        fi
      fi

      info "gh CLI installed successfully."
    fi
  fi
}

check_install_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    if [ -t 0 ]; then
      printf "jq is not installed. Install it now? (Y/n): "
      read -r response
    else
      response="Y"
    fi

    if [[ "$response" =~ ^[Nn]$ ]]; then
      error_exit "jq is required. Please install it manually and rerun the script."
    else
      info "Installing jq..."

      if [ "$PKG_MANAGER" = "brew" ]; then
        $PKG_INSTALL jq || error_exit "Failed to install jq."
      elif [ "$PKG_MANAGER" = "none" ] || ! sudo -n true 2>/dev/null; then
        install_binary "jq" "jqlang/jq" "$FALLBACK_INSTALL_DIR" "linux"
      else
        $PKG_INSTALL jq || error_exit "Failed to install jq."
      fi

      info "jq installed successfully."
    fi
  fi
}

configure_git_credential() {
  local gh_path
  gh_path=$(command -v gh)
  if [ -z "$gh_path" ]; then
    error_exit "gh CLI not found after installation."
  fi

  local current_helper
  current_helper=$(git config --global credential.helper || true)
  if [[ "$current_helper" != *"gh auth git-credential"* ]]; then
    if [ -n "$current_helper" ]; then
      if [ -t 0 ]; then
        printf "Existing Git credential helper detected: %s\n" "$current_helper"
        printf "Add gh 'as an additional' credential helper (Y) or overwrite the existing credential helpers with gh 'as the only one' (n)?: "
        read -r response
      else
        response="Y"
      fi

      if [[ "$response" =~ ^[Nn]$ ]]; then
        info "Configuring gh as Git credential helper..."
        git config --global credential.helper "!$gh_path auth git-credential" || error_exit "Failed to configure Git credential helper."
      else
        info "Adding gh as Git credential helper..."
        git config --global --add credential.helper "!$gh_path auth git-credential" || error_exit "Failed to add Git credential helper."
      fi
    else
      info "Configuring gh as Git credential helper..."
      git config --global credential.helper "!$gh_path auth git-credential" || error_exit "Failed to configure Git credential helper."
    fi
  fi
}

install_script() {
  sudo -v 2>/dev/null || true

  if [ -w "$INSTALL_DIR" ] || sudo -n true 2>/dev/null; then
    DEST_PATH="$INSTALL_DIR/$SCRIPT_NAME"
    info "Installing $SCRIPT_NAME to $DEST_PATH..."
    $DOWNLOADER "$REPO_URL" | sudo tee "$DEST_PATH" >/dev/null || error_exit "Failed to download or install $SCRIPT_NAME."
    sudo chmod +x "$DEST_PATH" || error_exit "Failed to make $SCRIPT_NAME executable."
  else
    DEST_PATH="$FALLBACK_INSTALL_DIR/$SCRIPT_NAME"
    info "Installing $SCRIPT_NAME to $DEST_PATH (user directory)..."
    mkdir -p "$FALLBACK_INSTALL_DIR" || error_exit "Failed to create $FALLBACK_INSTALL_DIR."
    $DOWNLOADER "$REPO_URL" > "$DEST_PATH" || error_exit "Failed to download $SCRIPT_NAME."
    chmod +x "$DEST_PATH" || error_exit "Failed to make $SCRIPT_NAME executable."

    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
      if [ -f "$rc_file" ] && ! grep -Fx "export PATH=\"\$PATH:$FALLBACK_INSTALL_DIR\"" "$rc_file" >/dev/null 2>&1; then
        echo "export PATH=\"\$PATH:$FALLBACK_INSTALL_DIR\"" >> "$rc_file"
      fi
    done

    if [[ ":$PATH:" != *":$FALLBACK_INSTALL_DIR:"* ]]; then
      export PATH="$PATH:$FALLBACK_INSTALL_DIR"
    fi
  fi
}

source_shell_config() {
  local shell_cmd
  local shell_rc

  if [ -z "$SHELL" ] || ! command -v "$(basename "$SHELL")" >/dev/null 2>&1; then
    shell_cmd="bash"
  else
    shell_cmd="$(basename "$SHELL")"
  fi

  case "$shell_cmd" in
    zsh)
      shell_rc="$HOME/.zshrc"
      ;;
    bash)
      if [ -f "$HOME/.bash_profile" ]; then
        shell_rc="$HOME/.bash_profile"
      else
        shell_rc="$HOME/.bashrc"
      fi
      ;;
    *)
      shell_rc="$HOME/.bashrc"
      ;;
  esac

  if [ -f "$shell_rc" ]; then
      info "Sourcing $shell_rc..."
      if ! $shell_cmd -c "source $shell_rc"; then
        warn "Failed to source $shell_rc. Open a new terminal or source it manually to use gitswitch."
      fi
  else
    info "Open a new terminal to use gitswitch."
  fi
}

main() {
  info "Starting gitswitch installation..."
  check_downloader
  detect_os
  check_install_gh
  check_install_jq
  configure_git_credential
  install_script
  source_shell_config
  info "Installation complete! You can now use 'gitswitch <username>'."
}

main
