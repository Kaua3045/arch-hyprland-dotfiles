#!/usr/bin/env bash
set -euo pipefail

#######################################
# CONFIG
#######################################
DOTFILES_REPO="https://github.com/Kaua3045/arch-hyprland-dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

CONFIG_DIRS=(
  "waybar"
  "wlogout"
  "rofi"
  "swaync"
  "hypr"
  "flameshot"
)

SDDM_BACKGROUND_RELATIVE_PATH="sddm/background.jpg"

PACMAN_PACKAGES=(
  unzip
  zip
  gvfs
  tracker3
  discord
  noto-fonts
  hyprland
  kitty
  nano
  git
  base-devel
  flameshot
  grim
  nautilus
  eog
  mpv
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
  qt6ct
  qt5ct
  kvantum
  breeze-icons
  gsimplecal
  sddm
  xorg-xsetroot
  zsh
  starship
  zsh-autosuggestions
  zsh-syntax-highlighting
  fzf
  go
  blueman
  bluez
  bluez-utils
  docker
  docker-compose
  fastfetch
  xdg-user-dirs
)

AUR_PACKAGES=(
  google-chrome
  noto-fonts-emoji
  ffmpeg
  libreoffice-fresh
  libreoffice-fresh-pt-br
  ttf-font-awesome
  waybar
  rofi-wayland
  swww
  hyprlock
  wlogout
  swaync
  playerctl
  curl
  jq
  ttf-jetbrains-mono-nerd
  pavucontrol
  visual-studio-code-bin
  spotify
  sddm-sugar-candy-git
  insomnia-bin
  jetbrains-toolbox
)

#######################################
# HELPERS
#######################################
log() { printf "\n[INFO] %s\n" "$1"; }
warn() { printf "\n[WARN] %s\n" "$1"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

append_if_missing() {
  local file="$1"
  local text="$2"
  touch "$file"
  grep -Fq "$text" "$file" || printf "\n%s\n" "$text" >> "$file"
}

#######################################
# CORE
#######################################
install_yay() {
  if need_cmd yay; then return; fi
  log "Installing yay..."
  tmp_dir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
  pushd "$tmp_dir/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null
  rm -rf "$tmp_dir"
}

clone_or_update_dotfiles() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" pull --ff-only
  else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
}

copy_dotfiles() {
  mkdir -p "$HOME/.config"
  [[ -f "$DOTFILES_DIR/.zshrc" ]] && cp -f "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

  for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -d "$DOTFILES_DIR/$dir" ]]; then
      rm -rf "$HOME/.config/$dir"
      cp -r "$DOTFILES_DIR/$dir" "$HOME/.config/$dir"
    elif [[ -d "$DOTFILES_DIR/.config/$dir" ]]; then
      rm -rf "$HOME/.config/$dir"
      cp -r "$DOTFILES_DIR/.config/$dir" "$HOME/.config/$dir"
    fi
  done
}

chmod_scripts() {
  find "$DOTFILES_DIR" -type f -name "*.sh" -exec chmod +x {} \; || true
}

#######################################
# SYSTEM SETUP
#######################################
setup_user_dirs() {
  log "Creating default user directories"
  xdg-user-dirs-update
}

setup_nautilus_bookmarks() {
  log "Setting up Nautilus bookmarks"

  mkdir -p "$HOME/.config/gtk-3.0"

  cat > "$HOME/.config/gtk-3.0/bookmarks" <<EOF
file://$HOME/Desktop Desktop
file://$HOME/Documents Documents
file://$HOME/Downloads Downloads
file://$HOME/Music Music
file://$HOME/Pictures Pictures
file://$HOME/Videos Videos
file://$HOME/Public Public
file://$HOME/Templates Templates
EOF
}

setup_wallpapers_dir() {
  log "Setting up wallpapers"

  local SRC="$DOTFILES_DIR/wallpapers"
  local DEST="$HOME/Pictures/wallpapers"

  mkdir -p "$DEST"

  if [[ -d "$SRC" ]]; then
    cp -rf "$SRC/." "$DEST/"
  else
    warn "Wallpapers folder not found in repo: $SRC"
  fi
}

# setup_wallpapers_dir() {
#   mkdir -p "$HOME/Pictures/wallpapers"
# }

setup_sddm_theme() {
  log "Setting up custom SDDM theme"

  local ORIG="/usr/share/sddm/themes/sugar-candy"
  local CUSTOM="/usr/share/sddm/themes/sugar-candy-custom"
  local BG_SRC="$DOTFILES_DIR/$SDDM_BACKGROUND_RELATIVE_PATH"
  local BG_NAME="background-custom.jpg"

  [[ -d "$ORIG" ]] || { warn "Sugar-candy not found"; return; }

  sudo rm -rf "$CUSTOM"
  sudo cp -r "$ORIG" "$CUSTOM"

  if [[ -f "$BG_SRC" ]]; then
    sudo cp "$BG_SRC" "$CUSTOM/$BG_NAME"
  fi

  sudo sed -i 's|^Background=.*|Background="background-custom.jpg"|' "$CUSTOM/theme.conf" || true

  sudo mkdir -p /etc/sddm.conf.d
  echo -e "[Theme]\nCurrent=sugar-candy-custom" | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null
}

#######################################
# SYSTEM INSTALL
#######################################
install_pacman_packages() {
  log "Updating system"
  sudo pacman -Syyuu --noconfirm

  log "Installing packages"
  sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
}

install_aur_packages() {
  yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

#######################################
# SERVICES
#######################################
enable_services() {
  sudo systemctl enable sddm
  sudo systemctl enable bluetooth
  sudo systemctl start bluetooth

  sudo systemctl enable docker
  sudo systemctl start docker
}

setup_docker_user() {
  sudo usermod -aG docker "$USER"
}

#######################################
# DEV
#######################################
setup_zsh() {
  [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]] && chsh -s /usr/bin/zsh
}

install_nvm_and_pnpm() {
  log "Installing NVM and pnpm"

  if [[ ! -d "$HOME/.nvm" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  fi

  append_if_missing "$HOME/.zshrc" 'export NVM_DIR="$HOME/.nvm"'
  append_if_missing "$HOME/.zshrc" '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
  append_if_missing "$HOME/.zshrc" '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'

  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

  set +u

  nvm install --lts
  nvm alias default lts/*
  nvm use --lts

  set -u

  npm install -g pnpm
  hash -r
}

install_sdkman() {
  log "Installing SDKMAN"

  if [[ ! -d "$HOME/.sdkman" ]]; then
    curl -fsSL "https://get.sdkman.io" | bash
  fi

  append_if_missing "$HOME/.zshrc" 'export SDKMAN_DIR="$HOME/.sdkman"'
  append_if_missing "$HOME/.zshrc" '[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"'

  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

  if [[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    warn "SDKMAN installation failed"
    return 1
  fi

  if ! command -v sdk >/dev/null 2>&1; then
    warn "sdk command not available after installation"
    return 1
  fi
}

# install_sdkman() {
#   log "Installing SDKMAN"
#   [[ -d "$HOME/.sdkman" ]] || curl -s "https://get.sdkman.io" | bash

#   # append_if_missing "$HOME/.zshrc" 'export SDKMAN_DIR="$HOME/.sdkman"'
#   # append_if_missing "$HOME/.zshrc" '[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"'
# }

# install_pnpm() {
#   log "Installing pnpm"
#   if need_cmd pnpm; then return; fi
#   curl -fsSL https://get.pnpm.io/install.sh | sh -

#   # append_if_missing "$HOME/.zshrc" 'export PNPM_HOME="$HOME/.local/share/pnpm"'
#   # append_if_missing "$HOME/.zshrc" 'case ":$PATH:" in'
#   # append_if_missing "$HOME/.zshrc" '  *":$PNPM_HOME:"*) ;;'
#   # append_if_missing "$HOME/.zshrc" '  *) export PATH="$PNPM_HOME:$PATH" ;;'
#   # append_if_missing "$HOME/.zshrc" 'esac'
# }

#######################################
# MAIN
#######################################
main() {
  log "Starting setup"

  install_pacman_packages
  install_yay
  install_aur_packages

  setup_user_dirs
  setup_nautilus_bookmarks

  clone_or_update_dotfiles
  copy_dotfiles
  chmod_scripts

  setup_wallpapers_dir
  setup_sddm_theme

  enable_services
  setup_docker_user

  setup_zsh
  # install_nvm
  install_nvm_and_pnpm
  install_sdkman
  # install_pnpm

    log "Validating installations"

  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

  echo "nvm: $(command -v nvm || echo not-found)"
  echo "node: $(command -v node || echo not-found)"
  echo "npm: $(command -v npm || echo not-found)"
  echo "pnpm: $(command -v pnpm || echo not-found)"
  echo "sdk: $(command -v sdk || echo not-found)"

  log "Setup finished 🚀"

  fastfetch || true

  echo "Reboot or relogin is recommended."
}

main "$@"
