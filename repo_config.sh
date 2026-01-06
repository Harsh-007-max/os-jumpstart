#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

STATE_DIR="$SCRIPT_DIR/state_dir"

mkdir -p "$STATE_DIR"

declare -A REPO_MAP

REPO_MAP['base-utils']='sudo dnf install -y dnf-plugins-core'

REPO_MAP['rpm-fusion']="sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

REPO_MAP['brave-browser']="sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo --overwrite"

REPO_MAP['vscode']="sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc && echo -e \"[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null"

REPO_MAP['spotify']="sudo dnf config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-spotify.repo --overwrite"

REPO_MAP['docker']="sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo --overwrite"

REPO_MAP['lazygit']="sudo dnf copr enable -y dejan/lazygit"

REPO_MAP['google-chrome']="echo -e \"[google-chrome]\nname=google-chrome\nbaseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64\nenabled=1\ngpgcheck=1\ngpgkey=https://dl.google.com/linux/linux_signing_key.pub\" | sudo tee /etc/yum.repos.d/google-chrome.repo > /dev/null"

REPO_MAP['neovim']="sudo dnf copr enable -y agriffis/neovim-nightly"
REPO_MAP['flathub']="flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"


run_import() {
  local key="$1"
  local command="${REPO_MAP[$key]}"
  local marker_file="$STATE_DIR/${key}.installed"

  if [[ -f "$marker_file" ]]; then
    info "[Skip]:  $key is already added (found marker file $marker_file). Skipping."
    return 0
  fi

  if [ -z "$command" ]; then
    error "[Error]: Key $key not found in REPO_MAP."
    return 1
  fi

  info "[Info]:  Executing installation for $key"
  if eval "$command"; then
    echo "[Importing]: $key added succeeded."
    touch "$marker_file"
  else
    error "[Failed]: $key installation failed."
    return 1
  fi
}
