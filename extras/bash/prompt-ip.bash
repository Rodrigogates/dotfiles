# Prompt de bash: usuario@ip:ruta$
# install.sh (módulo redes) añade una línea al final de ~/.bashrc que carga este archivo.
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[00m\]@\[\033[01;34m\]$(hostname -I | awk '\''{print $1}'\'')\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
