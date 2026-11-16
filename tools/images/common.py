from PIL import Image, ImageDraw
from txt import text_img
GOLD=(255,209,51); RED=(255,13,13); AMBER=(255,191,77); GREYTXT=(191,191,199)

def col_bg(im,x0,y0,w,h,ref_dy):
    return {x:im.getpixel((x,y0+ref_dy)) for x in range(x0,x0+w)}

def move_name_up(im,box,dy,band,ref_dy,thresh=40,xpad=0,xr=None):
    """box=(x0,y0,w,h) frame; band=(top,bottom) rel rows containing name; move up by dy."""
    x0,y0,w,h=box; b=4*(w//84) if False else None
    bgc=col_bg(im,x0,y0,w,h,ref_dy)
    px=im.load(); moved=[]
    for y in range(y0+band[0],y0+band[1]):
        for x in (range(x0+xr[0],x0+xr[1]) if xr else range(x0+xpad,x0+w-xpad)):
            p=px[x,y]; c=bgc[x]
            if sum(abs(p[i]-c[i]) for i in range(3))>thresh:
                moved.append((x,y,p))
            px[x,y]=c
    for x,y,p in moved: px[x,y-dy]=p

def recolor_hue(im,box,match,newc):
    x0,y0,x1,y1=box; px=im.load()
    for y in range(y0,y1):
        for x in range(x0,x1):
            p=px[x,y]
            if match(p):
                t=max(p)/255
                px[x,y]=tuple(int(c*t) for c in newc)

def is_orange(p): r,g,b=p; return r>40 and r>g*1.25 and g>r*0.3 and b<r*0.35
def is_white(p): return min(p)>200

def border(im,x0,y0,w,h,th,color):
    d=ImageDraw.Draw(im)
    for i in range(th):
        d.rectangle((x0+i,y0+i,x0+w-1-i,y0+h-1-i),outline=color)

def paste_center(im,t,cx,cy):
    im.paste(t,(int(cx-t.width/2),int(cy-t.height/2)),t)
