"""Prepare licensed source audio. Usage: python tools/prepare_western_audio.py SOURCE_DIR.
No network calls. Keeps source hashes and reproducible edit notes in the manifest.
"""
import sys, wave, json, hashlib
from pathlib import Path
import numpy as np

source=Path(sys.argv[1])
out=Path(__file__).resolve().parents[1]/'audio/western'
out.mkdir(parents=True,exist_ok=True)
manifest=[]
def read(path):
    with wave.open(str(path)) as f:
        rate=f.getframerate(); channels=f.getnchannels(); width=f.getsampwidth()
        b=f.readframes(f.getnframes())
    if width==2: x=np.frombuffer(b,dtype='<i2').astype(float)/32768
    elif width==3:
        a=np.frombuffer(b,dtype=np.uint8).reshape(-1,3).astype(np.int32)
        n=a[:,0]|(a[:,1]<<8)|(a[:,2]<<16)
        x=np.where(n&0x800000,n-0x1000000,n)/8388608
    elif width==4: x=np.frombuffer(b,dtype='<i4').astype(float)/2147483648
    else: raise ValueError(width)
    return x.reshape(-1,channels).mean(axis=1),rate
def prepare(relative,name,limit=.6,start=None):
    path=source/relative; x,rate=read(path)
    if start is not None: x=x[int(start*rate):int((start+limit)*rate)]
    else:
        loud=np.flatnonzero(np.abs(x)>max(.005,float(np.max(np.abs(x)))*.018))
        assert loud.size, relative
        x=x[max(0,int(loud[0])-int(rate*.004)):min(len(x),int(loud[-1])+int(rate*.03))][:int(rate*limit)]
    # Mono 44.1 kHz, gentle DC/high-frequency cleanup, 30 ms tail fade.
    x=x-x.mean()
    if rate!=44100:
        # A short anti-alias filter before decimation; no external DSP dependency.
        if rate>44100:
            taps=49; n=np.arange(taps)-(taps-1)/2; cutoff=20000/rate
            filt=2*cutoff*np.sinc(2*cutoff*n)*np.hamming(taps); filt/=filt.sum()
            x=np.convolve(x,filt,mode='same')
        x=np.interp(np.arange(int(len(x)*44100/rate))*rate/44100,np.arange(len(x)),x)
    attack=min(88,len(x)); tail=min(1323,len(x))
    x[:attack]*=np.linspace(0,1,attack); x[-tail:]*=np.linspace(1,0,tail)
    x*=.35/max(float(np.max(np.abs(x))),.0001)
    target=out/(name+'.wav')
    with wave.open(str(target),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(44100)
        f.writeframes((x*32767).astype('<i2').tobytes())
    manifest.append({'file':target.name,'source':relative,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'start_seconds':start,'max_seconds':limit,'seconds':round(len(x)/44100,4),'peak_dbfs':round(20*np.log10(np.max(np.abs(x))),2)})
for i in range(3): prepare(f'battle/battle_sound_effects/swish_{i+2}.wav',f'sword_{i}',.35)
prepare('battle/battle_sound_effects/Bow.wav','bow',.4)
for i,start in enumerate([.13,.83,1.53]): prepare('black-powder.wav',f'gun_{i}',.34,start)
prepare('black-powder.wav','gun_heavy',.56,2.25)
base='rpg/RPG Sound Pack/'
for src,name,limit in [
    ('battle/spell.wav','magic_charge',.75),('battle/magic1.wav','magic_release',.7),
    ('battle/sword-unsheathe3.wav','metal_hit',.3),('inventory/wood-small.wav','body_hit',.2),
    ('inventory/metal-small1.wav','reload_0',.23),('inventory/metal-small2.wav','reload_1',.23),
    ('inventory/coin.wav','coin',.55),('inventory/cloth.wav','dash',.24),
    ('NPC/ogre/ogre2.wav','monster_organic',.5),('NPC/giant/giant1.wav','monster_heavy',.65),
    ('NPC/beetle/bite-small.wav','monster_insect',.28),
    ('inventory/bubble.wav','bubble',.32),('inventory/bubble2.wav','splash',.4),
    ('interface/interface1.wav','ui_click',.1)]: prepare(base+src,name,limit)
(out/'manifest.json').write_text(json.dumps({'processing':'Mono PCM16 44100 Hz; DC removal; resample with anti-alias filter; trim; 2 ms attack/30 ms fade; peak -9.12 dBFS','files':manifest},indent=2),encoding='utf-8')
print('Prepared',len(manifest),'clips; max peak -9.12 dBFS')
