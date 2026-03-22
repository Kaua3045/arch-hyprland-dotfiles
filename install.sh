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
  curl
  wget
  unzip
  zip
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

append_block_if_missing() {
  local file="$1"
  local marker="$2"
  local block="$3"
  touch "$file"
  if ! grep -Fq "$marker" "$file"; then
    printf "\n%s\n" "$block" >> "$file"
  fi
}

#######################################
# CORE
#######################################
install_yay() {
  if need_cmd yay; then
    return
  fi

  log "Installing yay..."
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
  pushd "$tmp_dir/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null

  rm -rf "$tmp_dir"
}

clone_or_update_dotfiles() {
  log "Cloning/updating dotfiles repository"

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" pull --ff-only
  else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
}

copy_dotfiles() {
  log "Copying dotfiles"

  mkdir -p "$HOME/.config"

  if [[ -f "$DOTFILES_DIR/.zshrc" ]]; then
    cp -f "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
  fi

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
  log "Making shell scripts executable"
  find "$DOTFILES_DIR" -type f -name "*.sh" -exec chmod +x {} \; || true
}

#######################################
# SYSTEM SETUP
#######################################
setup_user_dirs() {
  log "Creating default user directories"
  xdg-user-dirs-update
}

setup_wallpapers_dir() {
  log "Creating wallpapers directory"
  mkdir -p "$HOME/Pictures/wallpapers"
}

setup_sddm_theme() {
  log "Setting up custom SDDM theme"

  local orig="/usr/share/sddm/themes/sugar-candy"
  local custom="/usr/share/sddm/themes/sugar-candy-custom"
  local bg_src="$DOTFILES_DIR/$SDDM_BACKGROUND_RELATIVE_PATH"
  local bg_name="background-custom.jpg"

  if [[ ! -d "$orig" ]]; then
    warn "Sugar Candy theme not found, skipping SDDM theme customization"
    return
  fi

  sudo rm -rf "$custom"
  sudo cp -r "$orig" "$custom"

  if [[ -f "$bg_src" ]]; then
    sudo cp "$bg_src" "$custom/$bg_name"
  else
    warn "Background image not found at $bg_src"
  fi

  if [[ -f "$custom/theme.conf" ]]; then
    sudo sed -i 's|^Background=.*|Background="background-custom.jpg"|' "$custom/theme.conf" || true
  fi

  sudo mkdir -p /etc/sddm.conf.d
  printf "[Theme]\nCurrent=sugar-candy-custom\n" | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null
}

#######################################
# SYSTEM INSTALL
#######################################
install_pacman_packages() {
  log "Updating system"
  sudo pacman -Syyuu --noconfirm

  log "Installing pacman packages"
  sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
}

install_aur_packages() {
  log "Installing AUR packages"
  yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

#######################################
# SERVICES
#######################################
enable_services() {
  log "Enabling services"

  sudo systemctl enable sddm
  sudo systemctl enable bluetooth
  sudo systemctl start bluetooth
  sudo systemctl enable docker
  sudo systemctl start docker
}

setup_docker_user() {
  log "Adding current user to docker group"
  sudo usermod -aG docker "$USER"
}

#######################################
# SHELL
#######################################
setup_zsh() {
  log "Setting zsh as default shell"

  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"

  if [[ "$current_shell" != "/usr/bin/zsh" ]]; then
    chsh -s /usr/bin/zsh
  fi

  touch "$HOME/.zshrc"
}

setup_base_zshrc() {
  log "Ensuring base zsh configuration exists"

  append_if_missing "$HOME/.zshrc" '# --- NVM ---'
  append_if_missing "$HOME/.zshrc" 'export NVM_DIR="$HOME/.nvm"'
  append_if_missing "$HOME/.zshrc" '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'

  append_if_missing "$HOME/.zshrc" '# --- PNPM ---'
  append_if_missing "$HOME/.zshrc" 'export PNPM_HOME="$HOME/.local/share/pnpm"'
  append_if_missing "$HOME/.zshrc" 'case ":$PATH:" in'
  append_if_missing "$HOME/.zshrc" '  *":$PNPM_HOME:"*) ;;'
  append_if_missing "$HOME/.zshrc" '  *) export PATH="$PNPM_HOME:$PATH" ;;'
  append_if_missing "$HOME/.zshrc" 'esac'

  append_if_missing "$HOME/.zshrc" '# --- SDKMAN ---'
  append_if_missing "$HOME/.zshrc" 'export SDKMAN_DIR="$HOME/.sdkman"'
  append_if_missing "$HOME/.zshrc" '[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"'
}

#######################################
# DEV TOOLS
#######################################
install_nvm() {
  log "Installing nvm"

  if [[ ! -d "$HOME/.nvm" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  fi

  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
  fi

  if need_cmd nvm; then
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
  else
    warn "nvm was installed but is not available in the current shell"
  fi
}

install_pnpm() {
  log "Installing pnpm"

  export PNPM_HOME="$HOME/.local/share/pnpm"
  mkdir -p "$PNPM_HOME"

  export PATH="$PNPM_HOME:$PATH"

  if ! need_cmd pnpm; then
    curl -fsSL https://get.pnpm.io/install.sh | env SHELL="$(command -v zsh)" sh -
  fi

  export PATH="$PNPM_HOME:$PATH"
  hash -r

  if need_cmd pnpm; then
    pnpm -v >/dev/null
  else
    warn "pnpm was installed but is not available in the current shell"
  fi
}

install_sdkman() {
  log "Installing SDKMAN"

  if [[ ! -d "$HOME/.sdkman" ]]; then
    curl -s "https://get.sdkman.io" | bash
  fi

  export SDKMAN_DIR="$HOME/.sdkman"
  if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
  fi

  if need_cmd sdk; then
    sdk version >/dev/null || true
  else
    warn "SDKMAN was installed but is not available in the current shell"
  fi
}

#######################################
# SUMMARY
#######################################
print_post_install_notes() {
  echo
  echo "========================================"
  echo "Setup finished successfully"
  echo "========================================"
  echo
  echo "Important:"
  echo "1. Reboot or log out and log back in."
  echo "2. Docker group changes require a new session."
  echo "3. Your default shell may require a new login to fully apply."
  echo
  echo "Validation commands:"
  echo "  zsh --version"
  echo "  node -v"
  echo "  npm -v"
  echo "  pnpm -v"
  echo "  sdk version"
  echo "  docker --version"
  echo "  fastfetch"
  echo
}

#######################################
# MAIN
#######################################
main() {
  log "Starting setup"

  install_pacman_packages
  install_yay
  install_aur_packages

  setup_user_dirs
  setup_wallpapers_dir

  clone_or_update_dotfiles
  copy_dotfiles
  chmod_scripts

  setup_zsh
  setup_base_zshrc

  install_nvm
  install_pnpm
  install_sdkman

  setup_sddm_theme

  enable_services
  setup_docker_user

  log "Running fastfetch"
  fastfetch || true

  print_post_install_notes
}

main "$@"
