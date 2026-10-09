# Prompt "pez": ><> usuario@ip:ruta (rama git) ❯
# Lo instala install.sh (módulo fish) en /etc/fish/conf.d/ si eliges este prompt.
# El nombre del enlace empieza por zz- para cargarse después de Oh My Fish.

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
