#!/usr/bin/env python3
import sys
import numpy as np
from PIL import Image

def get_vibrant_color(image_path):
    try:
        img = Image.open(image_path).convert("RGB").resize((64, 64), Image.BOX)
        pixels = np.array(img) / 255.0
        pixels = pixels.reshape(-1, 3)

        mx = pixels.max(axis=1)
        mn = pixels.min(axis=1)
        s = np.where(mx == 0, 0, (mx - mn) / mx)
        v = mx

        mask = (v > 0.2) & (s > 0.25) & (v < 0.95)
        vibrant_pixels = pixels[mask]

        if len(vibrant_pixels) == 0:
            return "255 255 255"

        buckets = (vibrant_pixels * 16).astype(int)
        unique_buckets, counts = np.unique(buckets, axis=0, return_counts=True)

        rgb_vals = unique_buckets / 16.0
        mx_b = rgb_vals.max(axis=1)
        mn_b = rgb_vals.min(axis=1)
        bucket_s = np.where(mx_b > 0, 1.0 - (mn_b / mx_b), 0)
        bucket_v = mx_b

        scores = np.log1p(counts) * (bucket_s ** 2.5) * bucket_v

        if scores.max() < 0.05:
            return "255 255 255"

        best = rgb_vals[scores.argmax()]
        rgb = (best * 255).astype(int)
        return f"{rgb[0]} {rgb[1]} {rgb[2]}"

    except Exception:
        return "255 255 255"

if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(get_vibrant_color(sys.argv[1]))