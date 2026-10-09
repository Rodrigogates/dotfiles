#!/usr/bin/env bash
# Instalador interactivo de dotfiles para Ubuntu 24.04.
# Uso:  bash install.sh          -> menú para elegir módulos
#       bash install.sh --all    -> lo instala todo sin preguntar
# Ejecútalo como tu usuario (NO con sudo); pedirá la contraseña cuando haga falta.
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ALL=false; [[ ${1:-} == "--all" ]] && ALL=true

if [[ $EUID -eq 0 ]]; then
  echo "Ejecútalo como usuario normal, no como root." >&2; exit 1
fi

apt_install() { sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }

# Crea un enlace simbólico; si ya había algo, lo mueve a la carpeta de backup
link() {
  local src="$1" dst="$2"
  [[ -e $src ]] || return 0
  if [[ -e $dst || -L $dst ]] && [[ "$(readlink -f "$dst")" != "$(readlink -f "$src")" ]]; then
    mkdir -p "$BACKUP"; mv "$dst" "$BACKUP/"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
  echo "   $dst -> $src"
}

# ---------------------------------------------------------------- módulos

mod_base() {
  echo "==> Básicos"
  apt_install git curl wget unzip build-essential ripgrep fd-find fzf bat \
    tree htop btop jq xclip tmux
  # En Ubuntu fd y bat se llaman fdfind y batcat
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
}

mod_paquetes() {
  echo "==> Paquetes exportados"
  local list="$DOTS/packages/apt.txt"
  [[ -s $list ]] || { echo "   No hay packages/apt.txt"; return; }
  local elegidos
  if $ALL; then
    elegidos=$(grep -v '^\s*$' "$list")
  else
    local args=()
    while read -r p; do [[ -n $p ]] && args+=("$p" "" ON); done < "$list"
    elegidos=$(whiptail --title "Paquetes" --separate-output \
      --checklist "Desmarca los que no quieras (Espacio marca, Enter acepta)" \
      25 70 15 "${args[@]}" 3>&1 1>&2 2>&3) || return 0
  fi
  [[ -n $elegidos ]] || return 0
  # Intenta todos a la vez; si alguno no existe, sigue uno a uno
  # shellcheck disable=SC2086
  apt_install $elegidos || for p in $elegidos; do apt_install "$p" || echo "   !! $p no disponible"; done
}

mod_redes() {
  echo "==> Herramientas de Redes"
  echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
  echo "iperf3 iperf3/start_daemon boolean false" | sudo debconf-set-selections
  apt_install net-tools iproute2 iputils-ping iputils-arping iputils-tracepath \
    traceroute mtr-tiny tcpdump tshark wireshark nmap netcat-openbsd socat telnet \
    whois bind9-dnsutils ethtool iperf3 ipcalc openssh-server bridge-utils vlan arp-scan
  sudo usermod -aG wireshark "$USER"
  sudo systemctl enable --now ssh
}

mod_fish() {
  echo "==> Fish"
  apt_install fish
  link "$DOTS/config/fish" "$HOME/.config/fish"
  [[ -f $DOTS/config/starship.toml ]] && {
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    link "$DOTS/config/starship.toml" "$HOME/.config/starship.toml"
  }
  # Plugins de Fisher (lee ~/.config/fish/fish_plugins)
  if [[ -f $HOME/.config/fish/fish_plugins ]]; then
    fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update'
  fi
  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish)" ]]; then
    chsh -s "$(command -v fish)"
  fi
}

mod_nvim() {
  echo "==> Neovim (última versión estable)"
  # El nvim de apt en 24.04 es la 0.9, demasiado viejo para muchos plugins
  apt_install ripgrep fd-find unzip gcc make xclip nodejs npm python3-venv
  local arch; arch=$(uname -m); [[ $arch == aarch64 ]] && arch=arm64
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch}.tar.gz" -o "$tmp/nvim.tar.gz"
  sudo rm -rf /opt/nvim
  sudo mkdir -p /opt/nvim
  sudo tar -xzf "$tmp/nvim.tar.gz" -C /opt/nvim --strip-components=1
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp"
  link "$DOTS/config/nvim" "$HOME/.config/nvim"
  # Instala los plugins con las versiones exactas de lazy-lock.json
  if [[ -f $HOME/.config/nvim/lazy-lock.json ]]; then
    nvim --headless "+Lazy! restore" +qa || true
  fi
}

mod_dotfiles() {
  echo "==> Resto de configuraciones"
  for d in "$DOTS"/config/*; do
    name=$(basename "$d")
    case $name in nvim|fish|starship.toml) continue ;; esac
    link "$d" "$HOME/.config/$name"
  done
  for f in "$DOTS"/home/.[!.]*; do
    [[ -e $f ]] && link "$f" "$HOME/$(basename "$f")"
  done
}

# ---------------------------------------------------------------- menú

sudo -v
sudo apt-get update
command -v whiptail >/dev/null || apt_install whiptail

if $ALL; then
  MODULOS="base paquetes redes fish nvim dotfiles"
else
  MODULOS=$(whiptail --title "Instalador de la VM" --separate-output --checklist \
    "Elige qué instalar (Espacio marca, Enter acepta)" 18 72 6 \
    base     "Básicos: git, curl, ripgrep, fzf, tmux..."      ON  \
    paquetes "Paquetes exportados (eliges uno a uno)"         OFF \
    redes    "Herramientas de Redes (Wireshark, nmap...)"     OFF \
    fish     "Fish + plugins + shell por defecto"             ON  \
    nvim     "Neovim última versión + tu configuración"       ON  \
    dotfiles "Resto de configs (git, tmux, terminal...)"      ON  \
    3>&1 1>&2 2>&3) || { echo "Cancelado."; exit 0; }
fi

for m in $MODULOS; do "mod_$m"; done

echo
[[ -d $BACKUP ]] && echo "Lo que había antes está en $BACKUP"
echo "Listo. Cierra sesión y vuelve a entrar para aplicar la shell y los grupos."
