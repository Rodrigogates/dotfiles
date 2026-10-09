if status is-interactive
    # Commands to run in interactive sessions can go here
end

function fix_cursor
    echo -ne '\e[5 q'
end

function postexec_fix_cursor --on-event fish_postexec
    fix_cursor
end

# Cursor en forma de barra cada vez que se pinta el prompt
function __cursor_barra --on-event fish_prompt
    printf '\e[5 q'
end

# Homebrew (solo si existe en esta máquina)
if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end
