# dotfiles

Configuración de mi VM Ubuntu 24.04 (nvim, fish, paquetes...) para replicarla en VMs nuevas.

## Instalar (en una VM nueva)

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/Rodrigogates/dotfiles.git ~/dotfiles
cd ~/dotfiles && bash install.sh        # menú para elegir qué instalar
# bash install.sh --all                  # todo sin preguntar
```

Ejecutar como usuario normal, sin `sudo`. En el menú: flechas para moverse, **Espacio** para marcar, **Enter** para aceptar.
Se puede volver a ejecutar cuando quieras para añadir módulos. Al terminar comprueba que no falte ningún programa.

## Módulos

| Módulo | Qué instala | Qué configura |
|---|---|---|
| **base** | git, curl, wget, unzip, build-essential, ripgrep, fd, fzf, bat, tree, htop, btop, jq, xclip, tmux | Alias `fd` y `bat` en `~/.local/bin` |
| **paquetes** | Los de `packages/apt.txt`, eligiendo uno a uno | — |
| **redes** | Wireshark, tshark, tcpdump, nmap, traceroute, mtr, dig, netcat, iperf3, ipcalc, arp-scan, net-tools, openssh-server... | Wireshark sin root (grupo `wireshark`), SSH activo |
| **fish** | fish, Oh My Fish | `~/.config/fish`, `~/.config/omf`, fish como shell por defecto |
| **nvim** | Neovim (última estable), tree-sitter CLI, lazygit, chafa, ripgrep, fd, node, gcc | `~/.config/nvim` (LazyVim) y sus plugins según `lazy-lock.json` |
| **dotfiles** | — | `~/.config/htop`, `~/.gitconfig` y demás ficheros de `config/` y `home/` |

Las configuraciones se **enlazan** (no se copian): lo que cambies en la VM queda en `~/dotfiles` y se sube con `git push`.
Si ya existía algo en el destino, se mueve a `~/.dotfiles-backup/<fecha>/`.

Después de instalar nvim, ábrelo una vez y espera a que Mason termine de descargar sus herramientas.

## Dependencias de las configuraciones

Si añades a una config algo que llama a un programa externo, añádelo también al módulo correspondiente de `install.sh` (función `mod_...` y lista `NECESITA`):

- **nvim**: `chafa` (logo del dashboard, `config/nvim/LogoCanal.png`), `lazygit` (atajo `<leader>gg`), `tree-sitter` (nvim-treesitter).

## Exportar (en la VM principal)

```bash
cd ~/dotfiles && git pull && bash export.sh
git status                     # revisar qué cambia
git add . && git commit -m "Actualizar dotfiles" && git push
```

`packages/apt.txt` solo se genera la primera vez; después se edita a mano.
