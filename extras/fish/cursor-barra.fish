# Cursor en barra parpadeante (lo restaura tras programas como nvim, htop o less)
function __cursor_barra --on-event fish_prompt --on-event fish_postexec
    printf '\e[5 q'
end
