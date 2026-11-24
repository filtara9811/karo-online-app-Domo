import json,re,os,html
from PIL import Image,ImageDraw,ImageFont,ImageFilter
S=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.join(S,'..','..','docs','s'); os.makedirs(OUT,exist_ok=True)
BASE='https://filtara9811.github.io/karo-online-app-Domo/'
F='/usr/share/fonts/opentype/inter/Inter-'
fb=lambda n:ImageFont.truetype(F+'ExtraBold.otf',n); fs=lambda n:ImageFont.truetype(F+'SemiBold.otf',n); fm=lambda n:ImageFont.truetype(F+'Medium.otf',n)
d=json.load(open(S+'/shops.json')); av=Image.open(S+'/av.jpg').convert('RGB')
def hx(c): c=c.lstrip('#'); return tuple(int(c[i:i+2],16) for i in (0,2,4))
def grad(w,h,a,b):
    im=Image.new('RGB',(w,h)); px=im.load()
    for x in range(w):
        for y in range(0,h):
            t=(x/w*0.6+y/h*0.4); px[x,y]=tuple(int(a[k]+(b[k]-a[k])*t) for k in range(3))
    return im
def wrap(dr,t,f,w):
    ws=t.split(); L=[]; cur=''
    for x in ws:
        n=(cur+' '+x).strip()
        if dr.textlength(n,font=f)<=w: cur=n
        else: L.append(cur); cur=x
    L.append(cur); return L
for o in d:
    i=o['i']; nm,em,cat,km,rt,rv=o['s'][:6]
    g=re.findall(r'#([0-9a-fA-F]{6})',o['s'][6] if len(o['s'])>6 else '') or ['f9d5e5','f4a6c0']
    W,H=1200,630; im=Image.new('RGB',(W,H),(253,250,243)); dr=ImageDraw.Draw(im)
    left=grad(430,H,hx(g[0]),hx(g[-1])); im.paste(left,(0,0))
    # avatar circle
    s=270; a=av.resize((s,s)); m=Image.new('L',(s,s),0); ImageDraw.Draw(m).ellipse((0,0,s,s),fill=255)
    ring=Image.new('L',(s+24,s+24),0); ImageDraw.Draw(ring).ellipse((0,0,s+24,s+24),fill=255)
    im.paste((255,255,255),(215-(s+24)//2,315-(s+24)//2),ring); im.paste(a,(215-s//2,315-s//2),m)
    # brand chip
    dr.rounded_rectangle((470,60,760,112),radius=26,fill=(244,123,32)); dr.text((492,70),'KARO ONLINE',font=fb(30),fill='white')
    y=150
    for ln in wrap(dr,nm,fb(68),680)[:2]: dr.text((470,y),ln,font=fb(68),fill=(29,24,16)); y+=82
    y+=14; dr.text((470,y),f'{cat}  ·  {km}  ·  Sadar Bazar, Delhi',font=fs(32),fill=(110,98,80)); y+=62
    dr.rounded_rectangle((470,y,470+290,y+60),radius=30,fill=(255,241,227)); dr.text((492,y+12),f'★ {rt}  ({rv} reviews)',font=fs(30),fill=(180,98,26))
    dr.rounded_rectangle((470,H-120,1130,H-56),radius=32,fill=(29,24,16)); dr.text((500,H-108),'Dukaan kholein  →  Order · Enquiry',font=fs(30),fill=(245,213,138))
    im.save(f'{OUT}/{i}.jpg',quality=86)
    t=html.escape(f'{nm} — Karo Online'); desc=html.escape(f'{cat} · {km} · ★{rt} ({rv} reviews). Dukaan dekhein, order ya enquiry karein — Karo Online par.')
    page=f'''<!doctype html><html lang="hi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{t}</title><meta name="description" content="{desc}">
<meta property="og:type" content="website"><meta property="og:site_name" content="Karo Online">
<meta property="og:title" content="{t}"><meta property="og:description" content="{desc}">
<meta property="og:image" content="{BASE}s/{i}.jpg"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">
<meta property="og:url" content="{BASE}s/{i}.html"><meta name="twitter:card" content="summary_large_image">
<script>(function(){{var n={i},q=location.search.replace(/^\?/,''),w='../?shop='+n+(q?'&'+q:'')+(location.hash||'');var go=function(){{location.replace(w)}};if(/Android/i.test(navigator.userAgent)&&!window.KaroApp&&!sessionStorage.getItem('ko_ai'+n)){{sessionStorage.setItem('ko_ai'+n,1);var fb=new URL(w,location.href).href;location.href='intent://shop/'+n+(q?'?'+q:'')+'#Intent;scheme=karoonline;package=com.filipra.karoonline;S.browser_fallback_url='+encodeURIComponent(fb)+';end';setTimeout(function(){{if(!document.hidden)go()}},1600);document.addEventListener('visibilitychange',function(){{if(!document.hidden)setTimeout(go,300)}})}}else go()}})();</script>
<style>body{{font-family:system-ui;background:#FDFAF3;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;color:#1d1810}}a{{color:#F47B20;font-weight:800}}</style></head>
<body><p>{t} khul rahi hai… <a href="../?shop={i}">yahan tap karein</a></p></body></html>'''
    open(f'{OUT}/{i}.html','w').write(page)
print('ok',len(d))
