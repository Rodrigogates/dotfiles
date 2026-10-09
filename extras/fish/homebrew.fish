# Homebrew: carga su entorno (PATH, etc.) si está instalado en esta máquina
if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end
