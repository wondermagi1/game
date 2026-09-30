from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]/'art/v6'
result={}
for role,name in enumerate(['sword','gunner','ranger']):
    path=root/(name+'-parts.png')
    if not path.exists():continue
    image=Image.open(path);w,h=image.size
    # Generated atlas uses taller torso rows; source pixels are left untouched.
    fractions=[0,.295,.585,.778,1.0] if name!='ranger' else [0,.28,.558,.758,1.0]
    cells=[]
    for row in range(4):
        for col in range(4):
            x0=round(w*col/4);y0=round(h*fractions[row]);x1=round(w*(col+1)/4);y1=round(h*fractions[row+1])
            alpha=image.getchannel('A').crop((x0,y0,x1,y1))
            mask=alpha.point(lambda a:255 if a>80 else 0)
            b=mask.getbbox()
            if not b:raise ValueError((name,row,col))
            x,y,right,bottom=b
            cell={'rect':[x0+x,y0+y,right-x,bottom-y]}
            if row>=2:
                crop=mask.crop(b);cw,ch=crop.size
                def centroid(frac):
                    yy=int(ch*frac);points=[]
                    for py in range(max(0,yy-3),min(ch,yy+4)):
                        for px in range(cw):
                            if crop.getpixel((px,py)):points.append((px,py))
                    if not points:return [cw/2,yy]
                    return [round(sum(p[i] for p in points)/len(points),2) for i in [0,1]]
                cell['joint_a']=centroid(.12)
                cell['joint_b']=centroid(.84 if row==2 and col>=2 else .88)
            cells.append(cell)
    result[str(role)]=cells
(root/'rig_regions.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print({role:len(cells) for role,cells in result.items()})
