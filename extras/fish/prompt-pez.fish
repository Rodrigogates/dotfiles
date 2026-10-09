# Prompt "pez": ><> usuario@ip:ruta (rama git) ❯
# Extra de fish: se instala con install.sh -> módulo "extras" en la carpeta conf.d de sistema de fish.
# El archivo instalado empieza por zz- para cargarse después de Oh My Fish y sustituir su prompt.

set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showuntrackedfiles 1
set -g __fish_git_prompt_showupstream informative
set -g __fish_git_prompt_color_branch green --bold

function fish_prompt
    set -l ip (hostname -I | string split -n " ")[1]
    set_color --bold FF8700; printf "><> "
    set_color --bold cyan; printf "%s" $USER
    set_color normal; printf "@"
    set_color --bold magenta; printf "%s" $ip
    set_color normal; printf ":"
    set_color --bold cyan; printf "%s" (string replace -r "^$HOME" "~" $PWD)
    set_color normal; fish_git_prompt " (%s)"
    set_color --bold yellow; printf " ❯ "
    set_color normal
end
