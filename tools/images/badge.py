"""Redraw the version badge on the main picture (images/gramframes-banner.png)
from the ## Version: line in GramFrames/GramFrames.toc. Run from the repo root:
    python3 tools/images/badge.py
Needs Pillow and the Inter Display Bold font (see txt.py)."""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
from txt import text_img

toc = open('GramFrames/GramFrames.toc', encoding='utf-8').read()
version = re.search(r'^## Version:\s*(\S+)', toc, re.M).group(1)
path = 'images/gramframes-banner.png'
im = Image.open(path).convert('RGB')
ImageDraw.Draw(im).rectangle((68, 811, 144, 843), fill=(255, 79, 163))
t = text_img('v' + version, 12.5, (255, 255, 255), 'inter', 0.9, 0)
im.paste(t, (106 - t.width // 2, 827 - t.height // 2), t)
im.save(path)
print('badge ->', 'v' + version)
