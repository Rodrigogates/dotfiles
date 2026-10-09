# Alias eza: ls, ll, la y lt con colores, carpetas primero y estado de git
# Solo se activan si eza está instalado (módulo base de install.sh)
if type -q eza
    alias ls 'eza --group-directories-first'
    alias ll 'eza -l --git --group-directories-first'
    alias la 'eza -la --git --group-directories-first'
    alias lt 'eza --tree --level=2 --group-directories-first'
    # Para iconos hace falta una Nerd Font en la terminal; si la instalas, añade --icons=auto
end
