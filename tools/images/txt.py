from PIL import Image, ImageDraw, ImageFont, ImageFilter
FONTS={'heros':'/usr/share/texmf/fonts/opentype/public/tex-gyre/texgyreheroscn-bold.otf',
       'inter':'/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf',
       'interx':'/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf'}
def text_img(s, cap_px, color, font='inter', squash=0.86, outline=3, track=0):
    """Render text with black outline; cap height ~cap_px. Returns RGBA."""
    f=ImageFont.truetype(FONTS[font], 200)
    # measure cap height of 'H'
    bb=f.getbbox('H'); cap=bb[3]-bb[1]
    size=int(200*cap_px/cap)
    f=ImageFont.truetype(FONTS[font], size)
    # draw char by char for tracking
    w=int(f.getlength(s)+len(s)*track+outline*4+10); h=int(size*1.4+outline*4)
    im=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(im)
    x=outline*2
    for ch in s:
        d.text((x,outline*2),ch,font=f,fill=color+(255,),stroke_width=outline,stroke_fill=(0,0,0,255))
        x+=f.getlength(ch)+track
    im=im.crop(im.getbbox())
    if squash!=1: im=im.resize((max(1,int(im.width*squash)),im.height),Image.LANCZOS)
    return im
