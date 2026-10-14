"""Import CC0 originals; PSD layers are exported losslessly as standalone PNGs.
Run with psd-tools available and the downloaded source directory as argument.
No image generation, painting, recoloring or bitmap retouching is performed.
"""
from pathlib import Path
import sys,shutil,json,hashlib
from psd_tools import PSDImage
src=Path(sys.argv[1]); project=Path(__file__).resolve().parents[1]
dest=project/'art/v12';dest.mkdir(parents=True,exist_ok=True)
records=[]
def put(source,relative,pack):
 target=dest/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
 records.append({'file':relative,'pack':pack,'source':str(source.relative_to(src)),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
put(src/'explosion.png','explosion.png','dirkwybe')
for folder,alias in [('Alternative 2/1','sword_slash'),('Alternative 2/2','sword_wave'),('Classic/1','alchemy_slash')]:
 for i,f in enumerate(sorted((src/'slash'/folder).glob('*.png'))):put(f,f'{alias}/{i}.png','Cethiel slash')
for group,alias in [('0','nature_bloom'),('1','nature_leaves'),('3','nature_wreath')]:
 for i,f in enumerate(sorted((src/'nature').glob(group+'-*.png'))):put(f,f'{alias}/{i}.png','Cethiel nature')
for i,f in enumerate(sorted((src/'arcane'/'01').glob('*.png'))):put(f,f'arcane/{i}.png','Cethiel arcane')
psd=PSDImage.open(src/'shooter.psd');layers=list(psd.descendants())
for index,name in [(55,'bullet-trail'),(32,'muzzle-flame'),(33,'impact-flare'),(68,'rune-swirl'),(77,'nature-mist')]:
 layer=layers[index];target=dest/(name+'.png');layer.composite().save(target)
 records.append({'file':name+'.png','pack':'Tatermand','source':'Effects_v05_Publish_0.psd','layer_index':index,'layer_name':layer.name,'bbox':layer.bbox,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
for name in ['bullet-foam-tip-thick.glb','grenade-a.glb']:
 put(src/'blaster'/'Models'/'GLB format'/name,'models/'+name,'Kenney Blaster Kit 2.1')
put(src/'blaster'/'Models'/'GLB format'/'Textures'/'colormap.png','models/Textures/colormap.png','Kenney Blaster Kit 2.1')
put(src/'blaster'/'License.txt','sources/Kenney-License.txt','Kenney Blaster Kit 2.1')
for name in ['shooter','explosion','slash','nature','arcane']:
 put(src/(name+'.html'),'sources/'+name+'.html','License evidence')
put(src/'download-manifest.json','sources/download-manifest.json','Source archive hashes')
(dest/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf8')
print('Imported',len(records),'files')
