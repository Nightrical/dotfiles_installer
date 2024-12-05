#!/bin/bash

repourl="https://github.com/Nightrical/dotfiles"
user=${USER:-"root"}
home=${HOME:-"/root"}
sudo=$(command -v sudo >/dev/null 2>&1 && echo "sudo" || echo "")

## 
# docker
# vm
##

environment=${ENVIRONMENT:-"docker"}

## Trying to detect linux distribution
if [[ -r "/etc/os-release" ]]; then
  source "/etc/os-release"
  distro="${ID,,}"
  if [[ -z "$distro" ]]; then
    echo "Failed to determine the distribution name from /etc/os-release."
    exit 1
  fi
else
  echo "Unable to access /etc/os-release. Cannot detect the distribution name."
  exit 1
fi

## Installing required packages
install_packages() {
  local packages=("$@")
  local to_install=""
  
  # Filter optional
  for package in "${packages[@]}"; do
    if [[ $package != \!* ]]; then
      to_install="$to_install $package"
    fi
  done

  # Remove space
  to_install=$(echo "$to_install" | sed 's/^ *//;s/ *$//')
  
  case "$distro" in
  ubuntu | debian)
    (
      $sudo apt update && \
      $sudo apt install --no-install-recommends -y $to_install
    ) || {
      echo "Error: Failed to install packages on $distro"
      exit 1
    }
    ;;
  centos | fedora | rhel)
    # Centos Fix Mirrorlist
    sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
    sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
    sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
    (
      $sudo yum install -y $to_install || \
      $sudo dnf install -y $to_install
    ) || {
      echo "Error: Failed to install packages on CentOS/Fedora/RHEL."
      exit 1
    }
    ;;
  arch)
    echo $to_install
    $sudo pacman -Sy --noconfirm $to_install || {
      echo "Error: Failed to install packages on Arch."
      exit 1
    }
    ;;
  esac
}

packages=("git" "zsh" "curl" "fzf" "xdg-user-dirs" "bat" "ripgrep" "which" "tmux" "neovim" "ranger" "plocate" "httpie" "htop")

case "$distro" in
ubuntu | debian)
  packages+=("exa" "locales" "iputils-ping" "procps" "dnsutils" "tcpdump" "grc")
  ;;
arch)
  packages+=("eza" "glibc-locales" "bind" "tcpdump" "grc")
  ;;
centos)
  # packages+=("eza")
  ;;
  
esac

install_packages "${packages[@]}"

## Setting up dotfiles

# Fix some certificate issues inside a Docker container.
if [[ "$distro" =~ ^(ubuntu|debian)$ ]] && [[ "$environment" == "docker" ]]; then
  $sudo apt-get install -y --reinstall ca-certificates
fi

config() {
  /usr/bin/git --git-dir="$home"/.manager/ --work-tree="$home" $@
}

echo ".manager" > ~/.gitignore

if ! config clone --bare "$repourl" "$home/.manager"; then
  echo "Error: Failed to clone repository from $repourl" >&2
  exit 1
fi

config checkout
config config --local status.showUntrackedFiles no

## Changing the default shell to Zsh
chsh -s "$(which zsh)" "$user"
rm -f "$home/.profile"
rm -f $home/.bash_history
rm -f "$home/.bashrc"

## Installing oh-my-zsh + plugins
source "$home/.config/shell/profile"
mkdir -p "$XDG_CACHE_HOME/zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
git clone https://github.com/joshskidmore/zsh-fzf-history-search "$ZSH_CUSTOM/plugins/zsh-fzf-history-search"

## Tweaks
xdg-user-dirs-update

# Fix command not found
if [[ "$distro" =~ ^(ubuntu|debian)$ ]]; then
  $sudo ln -s /usr/bin/batcat /usr/bin/bat
  $sudo ln -s /usr/bin/exa /usr/bin/eza
fi
bat cache --build

## Plocate
$sudo updatedb

## Locale setup
$sudo echo "LANG=en_US.UTF-8" > /etc/locale.conf
sed -i '/^#.*en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
$sudo locale-gen

## Changing the timezone
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime

# zsh -c "fast-theme XDG:catppuccin-mocha"

exec $(which zsh)