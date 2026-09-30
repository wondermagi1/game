from PIL import Image
from pathlib import Path
import numpy as np,json
from collections import deque
r=Path(__file__).resolve().parents[1]/'art/v6';out={}
for role,name in enumerate(['sword','gunner','ranger']):
    im=Image.open(r/(name+'-integrated.png'));w,h=im.size
    a=np.array(im.getchannel('A'))>96
    # Connected regions locate complete sprites despite their irregular grid spacing.
    # This script writes metadata only and never writes or modifies image pixels.
    all_cells=[]
    for row in range(1):
        y0=0;y1=h;seen=np.zeros((h,w),dtype=bool);mask=a;comps=[]
        for yy,xx in zip(*np.nonzero(mask)):
            if seen[yy,xx]:continue
            q=deque([(int(xx),int(yy))]);seen[yy,xx]=True;pts=[]
            while q:
                x,y=q.popleft();pts.append((x,y))
                for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                    if 0<=nx<w and 0<=ny<y1-y0 and mask[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;q.append((nx,ny))
            if len(pts)>8000:
                px=[p[0] for p in pts];py=[p[1] for p in pts]
                left,top,right,bottom=min(px),min(py),max(px)+1,max(py)+1
                feet=[x for x,y in pts if y>bottom-28]
                bands=[]
                for by in range(top,bottom,4):
                    xs=[x for x,y in pts if by<=y<by+4]
                    if xs:bands.append([max(0,min(xs)-2)-left,by-top,min(w,max(xs)+3)-left,min(h,by+5)-top])
                comps.append(dict(rect=[left,top,right-left,bottom-top],anchor=[sum(feet)/len(feet)-left,bottom-top-1],bands=bands))
        comps.sort(key=lambda b:b['rect'][1]+b['rect'][3]*.5)
        assert len(comps)==32,(name,len(comps))
        for row in range(4):
            cells=sorted(comps[row*8:row*8+8],key=lambda b:b['rect'][0])
            all_cells+=cells
        print(name,len(comps),[c['rect'] for c in all_cells[:8]],flush=True)
    out[str(role)]=all_cells
(r/'integrated_regions.json').write_text(json.dumps(out,separators=(',',':')),encoding='utf-8')
