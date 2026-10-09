#!/usr/bin/env bash
# Comparte configuración de ESTA máquina con el repo de dotfiles.
# Te pregunta qué quieres compartir, lo copia a la carpeta del repo (sin borrar lo
# que ya hubiera) y te enseña los cambios. Nada se sube hasta que hagas commit y push.
# Uso: bash export.sh
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTS"

# Qué se puede compartir: nombre | ruta en esta máquina | ruta en el repo
ITEMS=(
  "nvim|$HOME/.config/nvim|config/nvim"
  "fish|$HOME/.config/fish|config/fish"
  "omf|$HOME/.config/omf|config/omf"
  "htop|$HOME/.config/htop|config/htop"
  "tmux|$HOME/.config/tmux|config/tmux"
  "btop|$HOME/.config/btop|config/btop"
  "lazygit|$HOME/.config/lazygit|config/lazygit"
  "starship|$HOME/.config/starship.toml|config/starship.toml"
  "gitconfig|$HOME/.gitconfig|home/.gitconfig"
  "tmux.conf|$HOME/.tmux.conf|home/.tmux.conf"
)

# Trae lo último del repo antes de nada, para comparar contra la versión actual
if git rev-parse --git-dir >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
  git pull --ff-only -q || echo "!! No se pudo hacer git pull; sigue con la versión local del repo"
fi

# Menú solo con lo que existe en esta máquina
args=()
for it in "${ITEMS[@]}"; do
  IFS='|' read -r name src dst <<<"$it"
  [[ -e $src ]] || continue
  if [[ -e $dst ]]; then estado="ya está en el repo"; else estado="nuevo"; fi
  args+=("$name" "$estado" OFF)
done
((${#args[@]})) || { echo "No hay nada que exportar."; exit 0; }

elegidos=$(whiptail --title "Exportar al repo" --separate-output --checklist \
  "¿Qué quieres compartir con las demás VMs? (Espacio marca, Enter acepta)" \
  20 70 12 "${args[@]}" 3>&1 1>&2 2>&3) || { echo "Cancelado."; exit 0; }
[[ -n $elegidos ]] || { echo "No has elegido nada."; exit 0; }

echo "==> Copiando al repo"
for it in "${ITEMS[@]}"; do
  IFS='|' read -r name src dst <<<"$it"
  grep -qxF "$name" <<<"$elegidos" || continue
  mkdir -p "$(dirname "$dst")"
  if [[ -d $src ]]; then
    # Copia encima sin borrar: lo que solo esté en el repo (p. ej. el logo) se conserva
    mkdir -p "$dst"
    cp -a "$src/." "$dst/"
    rm -rf "$dst/.git"
  else
    cp -a "$src" "$dst"
  fi
  echo "   $name"
done

echo "==> Paquetes"
if [[ -f packages/apt.txt ]]; then
  echo "   packages/apt.txt no se toca (edítalo a mano para añadir o quitar paquetes)"
else
  mkdir -p packages
  if [[ -f /var/log/installer/initial-status.gz ]]; then
    comm -23 \
      <(apt-mark showmanual | sort -u) \
      <(gzip -dc /var/log/installer/initial-status.gz | sed -n 's/^Package: //p' | sort -u) \
      > packages/apt.txt
  else
    apt-mark showmanual | sort -u > packages/apt.txt
  fi
  echo "   $(wc -l < packages/apt.txt) paquetes en packages/apt.txt (revísalo y borra lo que sobre)"
fi

echo
echo "==> Cambios respecto al repo"
git status --short
echo
cat <<'EOF'
Revisa los cambios antes de subirlos:
   git diff                      -> ver qué ha cambiado línea a línea
   git restore <archivo>         -> descartar un cambio que NO quieras compartir
   rm <archivo>                  -> quitar un archivo nuevo (??) que NO quieras compartir
   git add . && git commit -m "..." && git push   -> compartir el resto
EOF
