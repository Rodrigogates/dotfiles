#!/usr/bin/env bash
# Instalador interactivo de dotfiles para Ubuntu 24.04.
# Uso:  bash install.sh          -> menú para elegir módulos
#       bash install.sh --all    -> lo instala todo sin preguntar
# Ejecútalo como tu usuario (NO con sudo); pedirá la contraseña cuando haga falta.
set -Eeuo pipefail

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

# Extras locales de fish: enlace en /etc/fish/conf.d (solo afecta a esta máquina,
# no a ~/.config/fish, que es compartido por todas las VMs)
fish_extra_on()  { sudo mkdir -p /etc/fish/conf.d; sudo ln -sfn "$DOTS/extras/fish/$1" "/etc/fish/conf.d/zz-$1"; echo "   /etc/fish/conf.d/zz-$1"; }
fish_extra_off() { sudo rm -f "/etc/fish/conf.d/zz-$1"; }

# Extras locales de bash: una línea al final de ~/.bashrc que carga el archivo del repo
bash_extra_on() {
  local linea="[ -f \"$DOTS/extras/bash/$1\" ] && . \"$DOTS/extras/bash/$1\"  # dotfiles:$1"
  grep -qF "# dotfiles:$1" "$HOME/.bashrc" 2>/dev/null || echo "$linea" >> "$HOME/.bashrc"
  echo "   ~/.bashrc carga extras/bash/$1"
}

# Pregunta de sí/no con whiptail; en modo --all usa el valor por defecto (1 = sí)
preguntar() {
  local titulo="$1" texto="$2" defecto="$3"
  if $ALL; then [[ $defecto == 1 ]]; return; fi
  if [[ $defecto == 1 ]]; then
    whiptail --title "$titulo" --yesno "$texto" 10 70
  else
    whiptail --title "$titulo" --defaultno --yesno "$texto" 10 70
  fi
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
  apt_install net-tools iproute2 iputils-ping iputils-arping iputils-tracepath \
    traceroute mtr-tiny tcpdump tshark wireshark nmap netcat-openbsd socat telnet \
    whois bind9-dnsutils ethtool iperf3 ipcalc openssh-server bridge-utils vlan arp-scan
  # Si Wireshark ya estaba instalado sin captura para usuarios, se reconfigura
  if ! getent group wireshark >/dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure wireshark-common
  fi
  sudo usermod -aG wireshark "$USER"
  sudo systemctl enable --now ssh

  # Extras opcionales
  local extras=""
  if $ALL; then
    extras="alias"
  else
    extras=$(whiptail --title "Redes: extras" --separate-output --checklist \
      "Extras para esta VM (Espacio marca, Enter acepta)" 12 74 2 \
      alias     "Alias de red: ips, rutas, puertos, captura... (bash y fish)" ON  \
      prompt_ip "Prompt de bash usuario@ip"                                   OFF \
      3>&1 1>&2 2>&3) || extras=""
  fi
  if [[ $extras == *alias* ]]; then
    bash_extra_on alias-redes.bash
    fish_extra_on alias-redes.fish
  fi
  [[ $extras == *prompt_ip* ]] && bash_extra_on prompt-ip.bash
  return 0
}

mod_fish() {
  echo "==> Fish"
  apt_install fish
  link "$DOTS/config/fish" "$HOME/.config/fish"
  [[ -f $DOTS/config/starship.toml ]] && {
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    link "$DOTS/config/starship.toml" "$HOME/.config/starship.toml"
  }
  # Oh My Fish: instala el framework y luego el tema y paquetes de config/omf
  if [[ -f $DOTS/config/fish/conf.d/omf.fish ]]; then
    if [[ ! -d $HOME/.local/share/omf ]]; then
      local omf_tmp; omf_tmp=$(mktemp)
      curl -fsSL https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install -o "$omf_tmp"
      fish "$omf_tmp" --noninteractive --yes || true
      rm -f "$omf_tmp"
    fi
    link "$DOTS/config/omf" "$HOME/.config/omf"
    [[ -d $DOTS/config/omf ]] && fish -c 'omf install' || true
  fi
  # Plugins de Fisher (lee ~/.config/fish/fish_plugins)
  if [[ -f $HOME/.config/fish/fish_plugins ]]; then
    fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update'
  fi
  # Qué prompt usar en esta VM
  local prompt=tema
  if ! $ALL; then
    prompt=$(whiptail --title "Prompt de fish" --radiolist \
      "¿Qué prompt quieres en esta VM? (Espacio elige, Enter acepta)" 12 74 2 \
      tema "Tema de Oh My Fish  ⋊> ~/dotfiles on main ◦"            ON  \
      pez  "Pez con IP y git    ><°> usuario@ip:~/dotfiles (main) ❯" OFF \
      3>&1 1>&2 2>&3) || prompt=tema
  fi
  # Versión antigua hecha a mano en la VM de Redes; la sustituye prompt-pez.fish
  sudo rm -f /etc/fish/conf.d/zz-prompt-redes.fish
  if [[ $prompt == pez ]]; then
    fish_extra_on prompt-pez.fish
  else
    fish_extra_off prompt-pez.fish
  fi

  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish)" ]]; then
    if preguntar "Shell por defecto" "¿Poner fish como shell por defecto? (si dices que no, se abre escribiendo fish)" 1; then
      grep -qxF "$(command -v fish)" /etc/shells || command -v fish | sudo tee -a /etc/shells >/dev/null
      chsh -s "$(command -v fish)"
    fi
  fi
  return 0
}

mod_nvim() {
  echo "==> Neovim (última versión estable)"
  # El nvim de apt en 24.04 es la 0.9, demasiado viejo para muchos plugins
  apt_install ripgrep fd-find unzip gcc make xclip nodejs npm python3-venv chafa
  local arch; arch=$(uname -m); [[ $arch == aarch64 ]] && arch=arm64
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch}.tar.gz" -o "$tmp/nvim.tar.gz"
  sudo rm -rf /opt/nvim
  sudo mkdir -p /opt/nvim
  sudo tar -xzf "$tmp/nvim.tar.gz" -C /opt/nvim --strip-components=1
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  # tree-sitter CLI: lo necesita nvim-treesitter (rama main) para compilar parsers
  local ts_arch=x64; [[ $arch == arm64 ]] && ts_arch=arm64
  curl -fL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-${ts_arch}.gz" \
    | gunzip > "$tmp/tree-sitter"
  sudo install -m 755 "$tmp/tree-sitter" /usr/local/bin/tree-sitter
  # lazygit: lo abre el atajo <leader>gg de la config (no está en apt de 24.04)
  local lg_arch=x86_64; [[ $arch == arm64 ]] && lg_arch=arm64
  local lg_ver
  lg_ver=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
  if [[ -n $lg_ver ]]; then
    curl -fL "https://github.com/jesseduffield/lazygit/releases/download/v${lg_ver}/lazygit_${lg_ver}_Linux_${lg_arch}.tar.gz" \
      | tar -xz -C "$tmp" lazygit
    sudo install -m 755 "$tmp/lazygit" /usr/local/bin/lazygit
  else
    echo "   !! No se pudo averiguar la versión de lazygit; instálalo a mano"
  fi
  rm -rf "$tmp"
  link "$DOTS/config/nvim" "$HOME/.config/nvim"
  # Instala los plugins con las versiones exactas de lazy-lock.json
  if [[ -f $HOME/.config/nvim/lazy-lock.json ]]; then
    nvim --headless "+Lazy! restore" +qa || true
  fi
  echo "   Abre nvim una vez y espera a que Mason termine de instalar sus herramientas."
}

# ---------------------------------------------------------------- comprobación

# Programas que cada módulo debe dejar instalados (los que usan tus configs)
declare -A NECESITA=(
  [base]="git curl rg fd fzf bat tree htop btop jq xclip tmux"
  [redes]="ip ping traceroute mtr tcpdump tshark wireshark nmap nc dig iperf3 ipcalc ifconfig"
  [fish]="fish"
  [nvim]="nvim tree-sitter lazygit chafa rg fd node npm gcc unzip"
)

comprobar() {
  echo
  echo "==> Comprobación"
  local faltan=0 m cmd
  for m in $MODULOS; do
    [[ -n ${NECESITA[$m]:-} ]] || continue
    local ko=()
    for cmd in ${NECESITA[$m]}; do
      command -v "$cmd" >/dev/null || [[ -x $HOME/.local/bin/$cmd ]] || ko+=("$cmd")
    done
    if ((${#ko[@]})); then
      echo "   ✗ $m: falta ${ko[*]}"; faltan=1
    else
      echo "   ✓ $m"
    fi
  done
  ((faltan)) && echo "   Vuelve a ejecutar install.sh con esos módulos o instálalos a mano."
  return 0
}

mod_dotfiles() {
  echo "==> Resto de configuraciones"
  for d in "$DOTS"/config/*; do
    name=$(basename "$d")
    case $name in nvim|fish|omf|starship.toml) continue ;; esac
    link "$d" "$HOME/.config/$name"
  done
  for f in "$DOTS"/home/.[!.]*; do
    [[ -e $f ]] && link "$f" "$HOME/$(basename "$f")"
  done
}

# ---------------------------------------------------------------- menú

sudo -v
# Respuestas por defecto para paquetes que preguntan al instalarse
# (va aquí para que valga en cualquier módulo que instale Wireshark o iperf3)
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
echo "iperf3 iperf3/start_daemon boolean false" | sudo debconf-set-selections
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
    nvim     "Neovim + LazyVim + lazygit, chafa, tree-sitter" ON  \
    dotfiles "Resto de configs (git, tmux, terminal...)"      ON  \
    3>&1 1>&2 2>&3) || { echo "Cancelado."; exit 0; }
fi

for m in $MODULOS; do
  ACTUAL=$m
  trap 'echo; echo "!! Ha fallado el módulo \"$ACTUAL\". Los siguientes no se han ejecutado." >&2' ERR
  "mod_$m"
done
trap - ERR

comprobar

echo
[[ -d $BACKUP ]] && echo "Lo que había antes está en $BACKUP"
echo "Listo. Cierra sesión y vuelve a entrar para aplicar la shell y los grupos."
