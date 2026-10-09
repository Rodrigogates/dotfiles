# dotfiles

Configuración de mi VM Ubuntu 24.04 (nvim, fish, paquetes...) para replicarla en VMs nuevas.

## Exportar (en la VM principal)

```bash
git clone https://github.com/Rodrigogates/dotfiles.git ~/dotfiles
cd ~/dotfiles && bash export.sh
git add . && git commit -m "actualizar dotfiles" && git push
```

## Instalar (en una VM nueva)

```bash
git clone https://github.com/Rodrigogates/dotfiles.git ~/dotfiles
cd ~/dotfiles && bash install.sh        # menú para elegir qué instalar
# bash install.sh --all                  # todo sin preguntar
```

Ejecutar como usuario normal, sin `sudo`.
