#!/bin/bash

# Exporta as variáveis de ambiente necessárias para o systemctl --user funcionar no gamemode
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# Arquivo de log para debug
LOG_FILE="/tmp/gamemode_wallpaper.log"
echo "[$(date)] Executando script: $1" >> "$LOG_FILE"
# Caminho para a imagem que você vai gerenciar manualmente
STATIC_BG="$HOME/.config/hypr/wallpaper_cache.png"

case "$1" in
    start)
        echo "active" > /tmp/gamemode_status
        # 1. Inicia o daemon do swww se não estiver rodando
        if ! pgrep -x "swww-daemon" > /dev/null; then
            swww-daemon &
            sleep 0.5
        fi
        
        # 2. Define a imagem estática (se existir)
        if [ -f "$STATIC_BG" ]; then
            swww img "$STATIC_BG" --transition-type none
        else
            # Caso não exista, tenta usar o que estiver configurado no swww ou o static anterior
            swww img "$HOME/.config/hypr/wallpaper_static.png" --transition-type none 2>/dev/null
        fi
        
        # 3. Para o Wallpaper Engine para economizar recursos
        echo "Parando linux-wallpaperengine.service" >> "$LOG_FILE"
        systemctl --user stop linux-wallpaperengine.service >> "$LOG_FILE" 2>&1
        # Caso o stop demore, forçamos o encerramento via systemctl kill (mais seguro que pkill aqui)
        systemctl --user kill -s SIGKILL linux-wallpaperengine.service >> "$LOG_FILE" 2>&1 || true
        ;;
    end)
        # 1. Pequeno delay para evitar corridas (race conditions) se o gamemode alternar rápido
        sleep 2

        # 2. Verifica se ainda há algum jogo rodando
        if gamemoded -s | grep -q "is active"; then
            echo "[$(date)] Gamemode ainda ativo. Abortando restart do wallpaper." >> "$LOG_FILE"
            exit 0
        fi

        # 3. Verifica se o processo do jogo realmente sumiu (opcional, mas seguro)
        # Se houver múltiplos jogos, o grep acima já resolve.

        echo "inactive" > /tmp/gamemode_status

        # 4. Reinicia o Wallpaper Engine apenas se não estivermos mais em gamemode
        echo "Iniciando linux-wallpaperengine.service" >> "$LOG_FILE"
        systemctl --user start linux-wallpaperengine.service >> "$LOG_FILE" 2>&1
        
        # 5. Espera ser carregado para limpar o swww
        (sleep 5 && pkill -x "swww-daemon") &
        ;;
esac
