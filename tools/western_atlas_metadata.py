"""Read alpha components into engine UV/foot registration metadata; never edit PNGs."""
from collections import deque
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'art/western'
result = {}
for role in ['sword', 'gunner', 'ranger']:
    for suffix, columns in [('-skills', 4)]:
        name = role + suffix + '.png'
        im = Image.open(ROOT / name)
        w, h = im.size
        mask = np.asarray(im.getchannel('A')) > 46
        seen = np.zeros((h, w), dtype=bool)
        components = []
        for yy, xx in zip(*np.nonzero(mask)):
            if seen[yy, xx]:
                continue
            seen[yy, xx] = True
            pending = deque([(int(xx), int(yy))])
            points = []
            while pending:
                x, y = pending.popleft()
                points.append((x, y))
                for nx, ny in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)]:
                    if 0 <= nx < w and 0 <= ny < h and mask[ny,nx] and not seen[ny,nx]:
                        seen[ny,nx] = True
                        pending.append((nx,ny))
            if len(points) > 2500:
                components.append(np.array(points))
        print(name, 'components:', len(components), flush=True)
        assert len(components) == columns*4, (name, len(components))
        components.sort(key=lambda pts: float(np.mean(pts[:,1])))
        frames = []
        for row in range(4):
            ordered = sorted(components[row*columns:(row+1)*columns], key=lambda pts: float(np.mean(pts[:,0])))
            for pts in ordered:
                left, top = pts.min(axis=0)
                right, bottom = pts.max(axis=0)+1
                feet = pts[pts[:,1] >= bottom-14]
                anchor_x = float(np.mean(feet[:,0]))
                bands = []
                # Each strip follows this figure only, even when a weapon crosses
                # a nominal grid boundary. UV vertices are static, never bent.
                for by in range(int(top), int(bottom), 3):
                    xs = pts[(pts[:,1]>=by) & (pts[:,1]<by+3),0]
                    if xs.size:
                        bands.append([max(0,int(xs.min())-1),by,min(w,int(xs.max())+2),min(int(bottom),by+3)])
                frames.append({'rect':[int(left),int(top),int(right-left),int(bottom-top)],'anchor':[round(anchor_x,2),int(bottom)-1],'bands':bands})
        result[name] = {'height':frames[0]['rect'][3], 'frames':frames}
        print('heights:', [f['rect'][3] for f in frames], flush=True)
    # Four neutral facing poses. The attack art shares the registered skill
    # poses, so crowded unused attack cells never enter the animation.
    name = role+'.png'
    im = Image.open(ROOT/name)
    w,h = im.size
    a = np.asarray(im.getchannel('A')) > 46
    frames = []
    for row in range(4):
        x_end = 281 if role=='sword' and row==0 else 256
        y0,y1 = row*256,(row+1)*256
        ys,xs = np.nonzero(a[y0:y1,:x_end])
        ys = ys+y0
        top,bottom = int(ys.min()),int(ys.max())+1
        left,right = int(xs.min()),int(xs.max())+1
        feet = xs[ys>=bottom-14]
        bands = []
        for by in range(top,bottom,3):
            bx=xs[(ys>=by)&(ys<by+3)]
            if bx.size: bands.append([max(0,int(bx.min())-1),by,min(x_end,int(bx.max())+2),min(bottom,by+3)])
        frames.append({'rect':[left,top,right-left,bottom-top],'anchor':[round(float(feet.mean()),2),bottom-1],'bands':bands})
    result[name] = {'height':frames[0]['rect'][3],'frames':frames}
(ROOT / 'hero_regions.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf-8')
