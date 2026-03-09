#!/bin/bash

echo "Otimizando e reiniciando o Linux Wallpaper Engine..."

# Verifica se o gamemode está ativo, e se estiver, não reinicia o wallpaper engine para não consumir recursos
if gamemoded -s | grep -q "is active"; then
    echo "Gamemode ativo! O Wallpaper Engine não será reiniciado."
    exit 0
fi

# Reinicia usando o serviço do sistema para garantir que as novas otimizações sejam aplicadas
systemctl --user daemon-reload
systemctl --user restart linux-wallpaperengine.service

echo "Reiniciado com sucesso com as novas otimizações!"
