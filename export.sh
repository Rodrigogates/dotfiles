#!/usr/bin/env bash
# Exporta la configuración de esta máquina a la carpeta dotfiles.
# Ejecútalo en la VM "buena": bash export.sh
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"

# Carpetas dentro de ~/.config que se guardan si existen (añade las tuyas)
CONFIG_ITEMS=(nvim fish starship.toml kitty alacritty wezterm tmux btop htop lazygit yazi bat)
# Ficheros sueltos en ~ que se guardan si existen
HOME_FILES=(.gitconfig .tmux.conf .inputrc .bash_aliases)

mkdir -p "$DOTS/config" "$DOTS/home" "$DOTS/packages"

echo "==> Copiando ~/.config"
for item in "${CONFIG_ITEMS[@]}"; do
  src="$HOME/.config/$item"
  [[ -e $src ]] || continue
  # Si ya es un enlace a esta carpeta dotfiles, no hay nada que copiar
  [[ -L $src && "$(readlink -f "$src")" == "$DOTS"/* ]] && continue
  rm -rf "$DOTS/config/$item"
  cp -a "$src" "$DOTS/config/$item"
  rm -rf "$DOTS/config/$item/.git"
  echo "   $item"
done

echo "==> Copiando ficheros de ~"
for f in "${HOME_FILES[@]}"; do
  src="$HOME/$f"
  [[ -f $src && ! -L $src ]] || continue
  cp -a "$src" "$DOTS/home/$f"
  echo "   $f"
done

echo "==> Guardando la lista de paquetes que instalaste tú"
if [[ -f /var/log/installer/initial-status.gz ]]; then
  # Paquetes marcados como manuales que NO venían con la instalación de Ubuntu
  comm -23 \
    <(apt-mark showmanual | sort -u) \
    <(gzip -dc /var/log/installer/initial-status.gz | sed -n 's/^Package: //p' | sort -u) \
    > "$DOTS/packages/apt.txt"
else
  apt-mark showmanual | sort -u > "$DOTS/packages/apt.txt"
fi
echo "   $(wc -l < "$DOTS/packages/apt.txt") paquetes en packages/apt.txt (revísalo y borra lo que sobre)"

echo
echo "Listo. Sube la carpeta a GitHub:"
echo "   cd $DOTS && git init && git add . && git commit -m 'dotfiles' && git push"
