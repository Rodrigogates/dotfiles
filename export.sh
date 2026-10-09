#!/usr/bin/env bash
# Exporta la configuración de esta máquina a la carpeta dotfiles.
# Ejecútalo en la VM "buena": bash export.sh
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"

# Carpetas dentro de ~/.config que se guardan si existen (añade las tuyas)
CONFIG_ITEMS=(nvim fish omf starship.toml kitty alacritty wezterm tmux btop htop lazygit yazi bat)
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

echo "==> Paquetes"
LISTA="$DOTS/packages/apt.txt"
if [[ -f $LISTA ]]; then
  # Ya hay una lista revisada a mano: no se toca
  echo "   packages/apt.txt ya existe, no se modifica (edítalo a mano para añadir paquetes)"
else
  if [[ -f /var/log/installer/initial-status.gz ]]; then
    # Paquetes marcados como manuales que NO venían con la instalación de Ubuntu
    comm -23 \
      <(apt-mark showmanual | sort -u) \
      <(gzip -dc /var/log/installer/initial-status.gz | sed -n 's/^Package: //p' | sort -u) \
      > "$LISTA"
  else
    apt-mark showmanual | sort -u > "$LISTA"
  fi
  echo "   $(wc -l < "$LISTA") paquetes en packages/apt.txt (revísalo y borra lo que sobre)"
fi

echo
echo "Listo. Revisa los cambios y súbelos:"
echo "   cd $DOTS && git status && git add . && git commit -m 'Actualizar dotfiles' && git push"
