# Alias de red para fish. Lo instala install.sh (módulo redes) en /etc/fish/conf.d/.
alias ips 'ip -br -c addr'              # interfaces e IPs, resumido y en color
alias links 'ip -br -c link'            # estado de las interfaces
alias rutas 'ip -c route'               # tabla de rutas
alias vecinos 'ip -c neigh'             # tabla ARP
alias puertos 'sudo ss -tulpn'          # puertos escuchando y proceso
alias conexiones 'ss -tunap'            # conexiones activas
alias dnsinfo 'resolvectl status'       # servidores DNS en uso
alias miip 'curl -s ifconfig.me; echo'  # IP pública
alias captura 'sudo tcpdump -nn -i'     # uso: captura enp0s3
