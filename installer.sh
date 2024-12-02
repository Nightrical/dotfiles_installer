#!/bin/bash

detect_distro() {
  if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo "$ID" | tr '[:upper:]' '[:lower:]'
  else
    echo "Unable to detect the distribution name."
    exit 1
  fi
}

install_packages() {
  local packages="$*"

  case "$DISTRO_NAME" in
    ubuntu|debian)
      sudo apt update && sudo apt install -y "$packages"
      ;;
    arch)
      sudo pacman -Sy --noconfirm "$packages"
      ;;
    centos|fedora|rhel)
      sudo yum install -y "$packages" || sudo dnf install -y "$packages"
      ;;
  esac
}


DISTRO_NAME=$(detect_distro)

install_packages git fzf