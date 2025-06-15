#!/bin/bash

set -euo pipefail

RED='\033[31m'
GREEN='\033[32m'
BOLD='\033[1m'
RESET='\033[0m'

if [ ! -t 1 ]; then RED=''; GREEN=''; BOLD=''; RESET=''; fi

error_exit() {
  printf "${RED}Error: %b${RESET}\n" "$1" >&2
  exit 1
}

print_usage() {
  echo "Usage: gitswitch [--single] [--hostname <host>] [--email <email>] <username>"
  echo "    or gitswitch --unset-single"
  echo "Switches GitHub account using gh CLI and configures git user settings."
  echo "  <username>        The account to switch to"
  echo "  --single          Configure git user settings locally for current repository only (Note: gh auth user still changes globally)"
  echo "  --unset-single    Remove local user.name and user.email to use global settings"
  echo "  --hostname        The hostname of the GitHub instance (default: github.com)"
  echo "  --email           Custom email address to use instead of the default noreply email"
  echo "  -h, --help        Display this help message"
}

username=""
single_flag=false
unset_single_flag=false
hostname="github.com"
custom_email=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --single)
      single_flag=true
      shift
      ;;
    --unset-single)
      unset_single_flag=true
      shift
      ;;
    --hostname)
      if [ -n "$2" ]; then
        hostname="$2"
        shift 2
      else
        error_exit "Missing hostname value\n$(print_usage)"
      fi
      ;;
    --email)
      if [ -n "$2" ]; then
        custom_email="$2"
        shift 2
      else
        error_exit "Missing email value\n$(print_usage)"
      fi
      ;;
    *)
      if [ -z "$username" ]; then
        username="$1"
      else
        error_exit "Only one username can be provided\n$(print_usage)"
      fi
      shift
      ;;
  esac
done

command -v git >/dev/null 2>&1 || error_exit "git is not installed"
command -v gh >/dev/null 2>&1 || error_exit "gh CLI is not installed"
command -v jq >/dev/null 2>&1 || error_exit "jq is not installed"

if [ "$unset_single_flag" = true ]; then
  if [ -n "$username" ] || [ "$single_flag" = true ]; then
    error_exit "--unset-single cannot be combined with username or --single\n$(print_usage)"
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    error_exit "Not inside a git repository. Use --unset-single within a git repository."
  fi

  git config --unset user.name 2>/dev/null || true
  git config --unset user.email 2>/dev/null || true

  printf "${GREEN}✓${RESET} Removed local user.name and user.email. Using global Git settings.\n"
  exit 0
fi

if [ -z "$username" ]; then
  error_exit "No username provided\n$(print_usage)"
fi

if [ "$single_flag" = true ]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    error_exit "Not inside a git repository. Use --single within a git repository."
  fi
fi

logged_in_users=$(gh auth status -t 2>/dev/null | grep "Logged in to $hostname account" | awk '{print $7}' || true)
if echo "$logged_in_users" | grep -Fix "$username" >/dev/null; then
  if ! gh auth switch -u "$username" -h "$hostname" >/dev/null 2>&1; then
    error_exit "Failed to switch to user $username on $hostname"
  fi
else
  error_exit "Account $username is not logged in to $hostname.\nPlease log in first using:\n  gh auth login -u $username -h $hostname\nThen run 'gitswitch [--single] [--hostname $hostname] $username' again."
fi

max_attempts=3
attempt=1
while [ $attempt -le $max_attempts ]; do
  user_data=$(GH_CONFIG_DIR="${GH_CONFIG_DIR:-$HOME/.config/gh}" gh api --cache 5m -H "Accept: application/vnd.github+json" user 2>/dev/null)
  if [ $? -eq 0 ]; then
    break
  fi

  if [ $attempt -eq $max_attempts ]; then
    error_exit "Failed to fetch user data from GitHub API after $max_attempts attempts"
  fi

  sleep 2
  attempt=$((attempt + 1))
done

login=$(echo "$user_data" | jq -r .login)
id=$(echo "$user_data" | jq -r .id)
if [ -z "$login" ] || [ -z "$id" ]; then
  error_exit "Could not retrieve authentication data for login or ID"
fi

if [ "$single_flag" = true ]; then
  git config user.name "$login"
  git config user.email "${custom_email:-$id+$login@users.noreply.$hostname}"
  printf "${GREEN}✓${RESET} Successfully switched active account for ${BOLD}%s${RESET} to ${BOLD}%s${RESET} (local repository settings applied)\n" "$hostname" "$login"
  printf "${BOLD}Note:${RESET} Local git user.name and user.email set for this repository only.\n"
  printf "      Ensure your authenticated GitHub user matches this repository's user before push/pull.\n"
  printf "      If not, run 'gitswitch %s' to switch.\n" "$username"
else
  git config --global user.name "$login"
  git config --global user.email "${custom_email:-$id+$login@users.noreply.$hostname}"
  printf "${GREEN}✓${RESET} Successfully switched active account for ${BOLD}%s${RESET} to ${BOLD}%s${RESET}\n" "$hostname" "$login"
fi
