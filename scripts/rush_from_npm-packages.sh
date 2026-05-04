#!/usr/bin/env bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# `just` and non-interactive shells often skip nvm's shell hook; align Node with .nvmrc
# so Rush's nodeSupportedVersionRange is satisfied.
_nvm_sh=""
if [[ -n "${NVM_DIR:-}" && -s "$NVM_DIR/nvm.sh" ]]; then
  _nvm_sh="$NVM_DIR/nvm.sh"
elif [[ -s "${XDG_CONFIG_HOME:-$HOME/.config}/nvm/nvm.sh" ]]; then
  NVM_DIR="${NVM_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/nvm}"
  _nvm_sh="$NVM_DIR/nvm.sh"
elif [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  _nvm_sh="$NVM_DIR/nvm.sh"
fi
if [[ -n "$_nvm_sh" ]]; then
  # shellcheck source=/dev/null
  source "$_nvm_sh"
  if [[ -f "$REPO_ROOT/.nvmrc" ]]; then
    pushd "$REPO_ROOT" >/dev/null
    nvm use --silent 2>/dev/null || nvm use
    popd >/dev/null
  fi
fi

RUSH="$SCRIPT_DIR/node_modules/.bin/rush"
NPM_PACKAGES="$( cd "$SCRIPT_DIR/../npm-packages" && pwd )"

if [[ $(pwd) == *"npm-packages"* ]]; then
  $RUSH "$@"
else
  cd "$NPM_PACKAGES"
  $RUSH "$@"
fi
