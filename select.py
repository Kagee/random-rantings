#!/usr/bin/python
import sys,os
from Xlib import X,display,Xutil,Xatom
from Xlib.protocol import event
from time import sleep
output="%(startx)d.%(endx)d.%(starty)d.%(endy)d.%(width)d.%(height)d" if len(sys.argv)<=1 else sys.argv[1]
sys.stdout.flush()
class NullDevice():
 def write(self,s):
  pass
sys.stdout=NullDevice()
d=display.Display()
sys.stdout=sys.__stdout__
sys.stdout.flush()
s=d.screen()
wi=s.root
cm=s.default_colormap
c=cm.alloc_color(0,0,65535)
xc=c.pixel^0xffffff 
g=wi.create_gc(line_width=4,line_style=X.LineSolid,fill_style=X.FillOpaqueStippled,fill_rule=X.WindingRule,cap_style=X.CapButt,join_style=X.JoinMiter,foreground=xc,background=s.black_pixel,function=X.GXxor,graphics_exposures=False,subwindow_mode=X.IncludeInferiors,)
wi.grab_pointer(True,(X.ButtonPressMask|X.ButtonMotionMask|X.ButtonReleaseMask),X.GrabModeAsync,X.GrabModeAsync,X.NONE,X.NONE,X.CurrentTime);
wi.grab_keyboard(True,X.GrabModeAsync,X.GrabModeAsync,X.CurrentTime);
done=False;
while not done:
 e=d.next_event()
 if e.type==X.ButtonPress:
  x=y=w=h=0;
  wi.rectangle(g,x,y,w,h);
  x=e.root_x;
  y=e.root_y;
 elif e.type==X.ButtonRelease:
  done=True;
 elif e.type==X.MotionNotify:
  wi.rectangle(g,x,y,w,h);
  w=abs(x-e.root_x);
  h=abs(y-e.root_y);
  if(x>e.root_x):
   x=e.root_x;
  if(y>e.root_y):
   y=e.root_y;
  wi.rectangle(g,x,y,w,h);
d.ungrab_pointer(X.CurrentTime);
d.ungrab_keyboard(X.CurrentTime);
wi.rectangle(g,x,y,w,h);
d.flush();
d.close();
print output%{'startx':x,'starty':y,'endx':x+w,'endy':y+h,'width':w,'height':h}
