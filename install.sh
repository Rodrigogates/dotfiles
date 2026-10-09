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

# Copia una config del repo a esta máquina. Cada VM queda con su propia copia:
# lo que cambies aquí no afecta al repo ni a otras VMs (para compartir: export.sh).
# Si ya había algo, lo mueve a la carpeta de backup; si era un enlace antiguo, lo quita.
put() {
  local src="$1" dst="$2"
  [[ -e $src ]] || return 0
  if [[ -L $dst ]]; then
    rm "$dst"
  elif [[ -e $dst ]]; then
    mkdir -p "$BACKUP"; mv "$dst" "$BACKUP/"
  fi
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  echo "   $dst"
}

# Extras locales de fish: copia en la carpeta conf.d "de sistema" del fish instalado
# (/etc/fish/conf.d con el fish de apt, .../linuxbrew/etc/fish/conf.d con el de Homebrew).
# Solo afecta a esta máquina, no a ~/.config/fish.
fish_confd() {
  local d=""
  command -v fish >/dev/null && d=$(fish -c 'echo $__fish_sysconf_dir' 2>/dev/null)
  echo "${d:-/etc/fish}/conf.d"
}
# sudo solo si la carpeta no es nuestra (la de Homebrew sí lo es)
como_dueno() {
  local d; d=$(fish_confd)
  if [[ -w $d || ( ! -e $d && -w $(dirname "$d") ) ]]; then "$@"; else sudo "$@"; fi
}
fish_extra_on() {
  local d; d=$(fish_confd)
  como_dueno mkdir -p "$d"
  como_dueno rm -f "$d/zz-$1"
  como_dueno cp "$DOTS/extras/fish/$1" "$d/zz-$1"
  echo "   $d/zz-$1"
}
fish_extra_off() { como_dueno rm -f "$(fish_confd)/zz-$1"; }

# Extras locales de bash: copia en ~/.bashrc.d y una línea en ~/.bashrc que la carga
bash_extra_on() {
  mkdir -p "$HOME/.bashrc.d"
  cp "$DOTS/extras/bash/$1" "$HOME/.bashrc.d/$1"
  # Quita la línea de versiones anteriores (que cargaban el archivo directamente del repo)
  sed -i "\|# dotfiles:$1\$|d" "$HOME/.bashrc"
  echo "[ -f ~/.bashrc.d/$1 ] && . ~/.bashrc.d/$1  # dotfiles:$1" >> "$HOME/.bashrc"
  echo "   ~/.bashrc.d/$1"
}
bash_extra_off() {
  rm -f "$HOME/.bashrc.d/$1"
  sed -i "\|# dotfiles:$1\$|d" "$HOME/.bashrc"
}

# ¿Está este extra instalado en esta máquina? (tipo = fish | bash)
extra_instalado() {
  if [[ $1 == fish ]]; then [[ -e $(fish_confd)/zz-$2 ]]
  else grep -qF "# dotfiles:$2" "$HOME/.bashrc" 2>/dev/null
  fi
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
    tree htop btop jq xclip tmux eza
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
  echo "   Los alias de red y los prompts están en el módulo extras."
}

mod_fish() {
  echo "==> Fish"
  apt_install fish
  put "$DOTS/config/fish" "$HOME/.config/fish"
  [[ -f $DOTS/config/starship.toml ]] && {
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    put "$DOTS/config/starship.toml" "$HOME/.config/starship.toml"
  }
  # Oh My Fish: instala el framework y luego el tema y paquetes de config/omf
  if [[ -f $DOTS/config/fish/conf.d/omf.fish ]]; then
    if [[ ! -d $HOME/.local/share/omf ]]; then
      local omf_tmp; omf_tmp=$(mktemp)
      curl -fsSL https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install -o "$omf_tmp"
      fish "$omf_tmp" --noninteractive --yes || true
      rm -f "$omf_tmp"
    fi
    put "$DOTS/config/omf" "$HOME/.config/omf"
    [[ -d $DOTS/config/omf ]] && fish -c 'omf install' || true
  fi
  # Plugins de Fisher (lee ~/.config/fish/fish_plugins)
  if [[ -f $HOME/.config/fish/fish_plugins ]]; then
    fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update'
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
  put "$DOTS/config/nvim" "$HOME/.config/nvim"
  # Instala los plugins con las versiones exactas de lazy-lock.json
  if [[ -f $HOME/.config/nvim/lazy-lock.json ]]; then
    nvim --headless "+Lazy! restore" +qa || true
  fi
  echo "   Abre nvim una vez y espera a que Mason termine de instalar sus herramientas."
}

# ---------------------------------------------------------------- comprobación

# Programas que cada módulo debe dejar instalados (los que usan tus configs)
declare -A NECESITA=(
  [base]="git curl rg fd fzf bat tree htop btop jq xclip tmux eza"
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

mod_extras() {
  echo "==> Extras de esta VM"
  # Versión antigua del prompt del pez hecha a mano; ahora es el extra prompt-pez.fish
  if [[ -e $(fish_confd)/zz-prompt-redes.fish ]]; then
    fish_extra_off prompt-redes.fish
    extra_instalado fish prompt-pez.fish || fish_extra_on prompt-pez.fish
  fi
  # Avisa si la config local de fish aún trae cosas que ahora son extras (versiones antiguas)
  if grep -qsE 'brew shellenv|__cursor_barra|fix_cursor' "$HOME/.config/fish/config.fish" \
     || [[ -e $HOME/.config/fish/functions/cls.fish ]]; then
    echo "   Aviso: tu ~/.config/fish aún tiene cursor/Homebrew/cls de antes. No pasa nada si también"
    echo "   marcas los extras, pero para dejarlo limpio reinstala el módulo fish."
  fi

  # Lista todos los extras del repo; los ya instalados aquí salen marcados
  local args=() f tipo base desc estado
  for f in "$DOTS"/extras/fish/*.fish "$DOTS"/extras/bash/*.bash; do
    [[ -e $f ]] || continue
    tipo=$(basename "$(dirname "$f")"); base=$(basename "$f")
    desc=$(head -1 "$f" | sed 's/^#\s*//' | cut -c1-55)
    if extra_instalado "$tipo" "$base"; then estado=ON; else estado=OFF; fi
    args+=("$tipo/$base" "$desc" "$estado")
  done
  ((${#args[@]})) || { echo "   No hay extras en el repo"; return 0; }

  local elegidos=""
  if $ALL; then
    elegidos=""   # con --all no se instala ningún extra: son cosas de cada VM
  else
    elegidos=$(whiptail --title "Extras de esta VM" --separate-output --checklist \
      "Marca los que quieras en ESTA VM; desmarcar uno lo quita (Espacio marca, Enter acepta)" \
      20 78 10 "${args[@]}" 3>&1 1>&2 2>&3) || { echo "   Sin cambios"; return 0; }
  fi

  local i tag
  for ((i = 0; i < ${#args[@]}; i += 3)); do
    tag=${args[i]}; tipo=${tag%%/*}; base=${tag#*/}
    if grep -qxF "$tag" <<<"$elegidos"; then
      if extra_instalado "$tipo" "$base"; then
        # No se pisa la versión de esta VM (puede que la hayas retocado)
        echo "   $tag ya estaba, se mantiene tu versión"
      else
        "${tipo}_extra_on" "$base"
      fi
    elif extra_instalado "$tipo" "$base"; then
      "${tipo}_extra_off" "$base"; echo "   quitado $tag"
    fi
  done
  return 0
}

mod_dotfiles() {
  echo "==> Resto de configuraciones"
  for d in "$DOTS"/config/*; do
    name=$(basename "$d")
    case $name in nvim|fish|omf|starship.toml) continue ;; esac
    put "$d" "$HOME/.config/$name"
  done
  for f in "$DOTS"/home/.[!.]*; do
    [[ -e $f ]] && put "$f" "$HOME/$(basename "$f")"
  done
  return 0
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
    "Elige qué instalar (Espacio marca, Enter acepta)" 19 72 7 \
    base     "Básicos: git, curl, ripgrep, fzf, tmux..."      ON  \
    paquetes "Paquetes exportados (eliges uno a uno)"         OFF \
    redes    "Herramientas de Redes (Wireshark, nmap...)"     OFF \
    fish     "Fish + Oh My Fish + shell por defecto"          ON  \
    nvim     "Neovim + LazyVim + lazygit, chafa, tree-sitter" ON  \
    dotfiles "Resto de configs (git, htop...)"                ON  \
    extras   "Extras de esta VM: prompts, alias (eliges)"     OFF \
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
