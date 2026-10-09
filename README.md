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
| **redes** | Wireshark, tshark, tcpdump, nmap, traceroute, mtr, dig, netcat, iperf3, ipcalc, arp-scan, net-tools, openssh-server... | Wireshark sin root (grupo `wireshark`), SSH activo. **Opcional:** alias de red y prompt de bash `usuario@ip` |
| **fish** | fish, Oh My Fish | `~/.config/fish`, `~/.config/omf`. **Pregunta:** prompt (tema de Oh My Fish o pez con IP y git) y si fish va como shell por defecto |
| **nvim** | Neovim (última estable), tree-sitter CLI, lazygit, chafa, ripgrep, fd, node, gcc | `~/.config/nvim` (LazyVim) y sus plugins según `lazy-lock.json` |
| **dotfiles** | — | `~/.config/htop`, `~/.gitconfig` y demás ficheros de `config/` y `home/` |

Las configuraciones se **copian**: cada VM tiene su propia copia y lo que cambies en una no afecta al repo ni a las demás.
Para compartir algo, usa `export.sh` (abajo). Si ya existía algo en el destino, se mueve a `~/.dotfiles-backup/<fecha>/`.
Después de instalar puedes borrar `~/dotfiles` si quieres: la VM no depende de esa carpeta.

Después de instalar nvim, ábrelo una vez y espera a que Mason termine de descargar sus herramientas.

## Extras por máquina (`extras/`)

Cosas que se eligen al instalar y solo afectan a esa VM, sin tocar la config compartida:

| Archivo | Qué es | Cómo se activa |
|---|---|---|
| `extras/fish/prompt-pez.fish` | Prompt `><°> usuario@ip:ruta (rama) ❯` | Copia en `/etc/fish/conf.d/zz-prompt-pez.fish` |
| `extras/fish/alias-redes.fish` | Alias `ips`, `rutas`, `puertos`, `captura`... | Copia en `/etc/fish/conf.d/zz-alias-redes.fish` |
| `extras/bash/alias-redes.bash` | Los mismos alias para bash | Copia en `~/.bashrc.d/` + línea `# dotfiles:alias-redes.bash` en `~/.bashrc` |
| `extras/bash/prompt-ip.bash` | Prompt de bash `usuario@ip:ruta$` | Copia en `~/.bashrc.d/` + línea `# dotfiles:prompt-ip.bash` en `~/.bashrc` |

Para quitar uno: borra el archivo de `/etc/fish/conf.d/` o la línea de `~/.bashrc`, o vuelve a ejecutar `install.sh` y elige otra opción.

## Dependencias de las configuraciones

Si añades a una config algo que llama a un programa externo, añádelo también al módulo correspondiente de `install.sh` (función `mod_...` y lista `NECESITA`):

- **nvim**: `chafa` (logo del dashboard, `config/nvim/LogoCanal.png`), `lazygit` (atajo `<leader>gg`), `tree-sitter` (nvim-treesitter).

## Compartir cambios (desde cualquier VM)

```bash
cd ~/dotfiles && bash export.sh   # menú: eliges qué compartir (nvim, fish, htop...)
git diff                          # revisa qué cambia
git restore <archivo>             # descarta lo que no quieras compartir
git add . && git commit -m "..." && git push
```

`export.sh` hace `git pull`, copia lo elegido **encima** de lo que hay en el repo (no borra archivos que solo existan en el repo)
y te enseña los cambios. Nada se comparte hasta que haces `git push`.

Para que otra VM reciba lo compartido: `cd ~/dotfiles && git pull && bash install.sh` y marca los módulos que quieras actualizar
(lo que tuviera esa VM se guarda en `~/.dotfiles-backup/`).

`packages/apt.txt` solo se genera la primera vez; después se edita a mano.
