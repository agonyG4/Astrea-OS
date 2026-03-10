#!/bin/bash
IMAGE="$1"
if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
    echo "255 255 255"
    exit 0
fi

python3 << EOF
from PIL import Image
import colorsys

img = Image.open("$IMAGE").convert("RGB").resize((100, 100))
pixels = list(img.getdata())

best_score = -1
best_color = (255, 255, 255)

# Agrupa em buckets de 24 pra reduzir ruído
buckets = {}
for r, g, b in pixels:
    key = (r // 24, g // 24, b // 24)
    buckets[key] = buckets.get(key, 0) + 1

for (rk, gk, bk), count in buckets.items():
    r, g, b = rk * 24 + 12, gk * 24 + 12, bk * 24 + 12
    h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
    
    # Descarta apenas o que for excessivamente escuro (quase preto)
    if v < 0.15:
        continue
        
    # Aceita cores com pouca saturação (brancos e cinzas)
    # mas ainda dá uma leve preferência para cores vibrantes se estiverem presentes
    score = count * (s + 0.15) * v
    
    if score > best_score:
        best_score = score
        best_color = (r, g, b)

print(f"{best_color[0]} {best_color[1]} {best_color[2]}")
EOF