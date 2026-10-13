"""Read connected alpha silhouettes into static engine UV strips. PNG is unchanged."""
from collections import deque
from pathlib import Path
import json, sys
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'art/western'
name = sys.argv[1] if len(sys.argv)>1 else 'monsters-v2.png'
rows = 3 if name=='props.png' else 4
output_name = 'prop_regions.json' if rows==3 else 'monster_regions.json'
im = Image.open(root/name)
w,h = im.size
mask = np.asarray(im.getchannel('A')) > 46
seen = np.zeros((h,w),dtype=bool)
components = []
for yy,xx in zip(*np.nonzero(mask)):
    if seen[yy,xx]: continue
    seen[yy,xx] = True
    pending = deque([(int(xx),int(yy))])
    points = []
    while pending:
        x,y = pending.popleft()
        points.append((x,y))
        for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if 0<=nx<w and 0<=ny<h and mask[ny,nx] and not seen[ny,nx]:
                seen[ny,nx] = True
                pending.append((nx,ny))
    if len(points)>2000: components.append(np.array(points))
assert len(components)==rows*4, f'Expected {rows*4} distinct silhouettes, found {len(components)}'
components.sort(key=lambda p: float(p[:,1].mean()))
frames = []
for row in range(rows):
    for pts in sorted(components[row*4:row*4+4],key=lambda p: float(p[:,0].mean())):
        left,top=pts.min(axis=0); right,bottom=pts.max(axis=0)+1
        feet=pts[pts[:,1]>=bottom-12,0]
        bands=[]
        for by in range(int(top),int(bottom),2):
            xs=pts[(pts[:,1]>=by)&(pts[:,1]<by+2),0]
            if xs.size: bands.append([max(0,int(xs.min())-1),by,min(w,int(xs.max())+2),min(int(bottom),by+2)])
        frames.append({'rect':[int(left),int(top),int(right-left),int(bottom-top)],'anchor':[round(float(feet.mean()),2),int(bottom)-1],'bands':bands})
(root/output_name).write_text(json.dumps({name:{'height':126,'frames':frames}},separators=(',',':')),encoding='utf-8')
print(name+': '+str(len(frames))+' isolated silhouettes; original alpha and pixels preserved')
