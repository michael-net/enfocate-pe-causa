# Experimento: corta las conexiones de los navegadores.
U=$(id -u)
pgrep -lf 'network.mojom.NetworkService' | cut -c1-120
pkill -U "$U" -f 'network.mojom.NetworkService' && echo "red de Chromium reiniciada"
pgrep -l -x com.apple.WebKit.Networking
pkill -U "$U" -x com.apple.WebKit.Networking && echo "red de WebKit reiniciada"
