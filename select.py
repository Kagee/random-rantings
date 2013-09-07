#!/usr/bin/python
# Reimplementation of http://digitalfoo.net/posts/drawing-rectangles-on-the-screen-with-xlib-c-library
import sys,os
from Xlib import X, display, Xutil, Xatom
from Xlib.protocol import event
output = "x(%d,%d), y(%d,%d)" if len(sys.argv) <= 1 else sys.argv[1]
sys.stdout.flush()
class NullDevice():
 def write(self, s):
    pass
sys.stdout = NullDevice()
# For some reason, this prints Xlib.protocol.request.QueryExtension
dis = display.Display() 
# sys.__stdout__ is provided by python
sys.stdout = sys.__stdout__
sys.stdout.flush()
screen = dis.screen()
window = screen.root
colormap = screen.default_colormap
#(r,g,b) blue = (0,0,65535)
color = colormap.alloc_color(0, 0, 65535)
# Xor it because we'll draw with X.GXxor function 
xor_color = color.pixel ^ 0xffffff 
gc = window.create_gc(
        line_width = 4,
        line_style = X.LineSolid,
        fill_style = X.FillOpaqueStippled,
        fill_rule  = X.WindingRule,
        cap_style  = X.CapButt,
        join_style = X.JoinMiter,
        foreground = xor_color,
        background = screen.black_pixel,
        function = X.GXxor, 
        graphics_exposures = False,
        subwindow_mode = X.IncludeInferiors,
        ) 
window.grab_pointer ( True, (X.ButtonPressMask | X.ButtonMotionMask | X.ButtonReleaseMask), X.GrabModeAsync, X.GrabModeAsync, X.NONE, X.NONE, X.CurrentTime );
window.grab_keyboard( True, X.GrabModeAsync, X.GrabModeAsync,X.CurrentTime);
done = False;
while not done:
    event = dis.next_event()
    if event.type == X.ButtonPress:
        startx = event.root_x;
        starty = event.root_y;
        rcx = rcy = rcw = rch = 0;
        window.rectangle( gc, rcx, rcy, rcw, rch);
        rcx = event.root_x;
        rcy = event.root_y;
    elif event.type == X.ButtonRelease:
        endx = event.root_x;
        endy = event.root_y;
        done = True;
    elif event.type == X.MotionNotify:
        window.rectangle( gc, rcx, rcy, rcw, rch);
        rcw = abs(rcx - event.root_x);
        rch = abs(rcy - event.root_y);
        if (rcx > event.root_x):
            rcx = event.root_x;
        if (rcy > event.root_y):
            rcy = event.root_y;
        window.rectangle( gc, rcx, rcy, rcw, rch);
dis.ungrab_pointer ( X.CurrentTime );
dis.ungrab_keyboard ( X.CurrentTime );
window.rectangle( gc, rcx, rcy, rcw, rch);
dis.flush();
dis.close();
print output % (rcx, rcy, rcw, rch); 
