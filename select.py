#!/usr/bin/python
import sys
import os
# Based on http://digitalfoo.net/posts/drawing-rectangles-on-the-screen-with-xlib-c-library
from Xlib import X, display, Xutil, Xatom
from Xlib.protocol import event

DEBUG = False;
output = "x(%d,%d), y(%d,%d)"

startx = -1;
starty = -1;
endx = -1;
endy = -1;
rcx = rcy = rcw = rch = 0;
def debug(msg):
    global DEBUG;
    if DEBUG:
        print msg;
        
def main():
    global startx, starty, endx, endy, rcx, rcy, rcw,  rch, output,  DEBUG;
    if (len(sys.argv) >= 2):
        if (sys.argv[1] != "DEBUG"):
            output = sys.argv[1];
        else: 
            DEBUG = True;
            if len(sys.argv) >= 3:
                output = sys.argv[2];
    init();
    grabby();
    event_parser();
    ungrabby();
    final();
    
def init():
    debug("Starting init");
    global dis,  gc;
    debug("Remove stdout to fix python-xlib bug")
    sys.stdout.flush()
    sys.stdout = NullDevice()
    # For some reason, this prints Xlib.protocol.request.QueryExtension
    dis = display.Display(); 
    sys.stdout = sys.__stdout__; # This is provided by python
    sys.stdout.flush()
    debug("Returned stdout")
    debug("display is %s" % dis.__class__);
    global screen;
    screen = dis.screen();
    global root_window;
    root_window = screen.root;
    debug("root is %s" % root_window.__class__ );
#(r,g,b) blue = (0,0,65535)
    colormap = screen.default_colormap;
    color = colormap.alloc_color(0, 0, 65535)
# Xor it because we'll draw with X.GXxor function 
    xor_color = color.pixel ^ 0xffffff 
    gc = root_window.create_gc(
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
    debug("Finished init")
    
def event_parser():
    global startx, starty, endx, endy,  rcx, rcy, rcw,  rch;
    debug("Staring listening for events");
    done = False;
    while not done:
        event = dis.next_event()
        if event.type == X.KeyPress:
            done = True;
        if event.type == X.ButtonPress:
            debug(event)
            startx = event.root_x;
            starty = event.root_y;
            draw_rectangle();
            rcx = rcy = rcw = rch;
            rcx = event.root_x;
            rcy = event.root_y;
        elif event.type == X.ButtonRelease:
            debug(event)
            endx = event.root_x;
            endy = event.root_y;
            done = True;
        elif event.type == X.MotionNotify:
            draw_rectangle();
            rcw = abs(rcx - event.root_x);
            rch = abs(rcy - event.root_y);
            if (rcx > event.root_x):
                rcx = event.root_x;
            if (rcy > event.root_y):
                rcy = event.root_y;
            draw_rectangle();

    debug("Finished listening for events");
    
def grabby():
    debug("Starting grab");
    root_window.grab_pointer ( True, (X.ButtonPressMask | X.ButtonMotionMask | X.ButtonReleaseMask), X.GrabModeAsync, X.GrabModeAsync, X.NONE, X.NONE, X.CurrentTime );
    root_window.grab_keyboard(True, X.GrabModeAsync, X.GrabModeAsync,X.CurrentTime);
    debug("Finished grab");

def ungrabby():
    debug("Starting ungrab");
    dis.ungrab_pointer ( X.CurrentTime );
    dis.ungrab_keyboard ( X.CurrentTime );
    debug("Finished ungrab");    
    
def draw_rectangle():
    global startx, starty, endx, endy,  rcx, rcy, rcw,  rch,  gc;
    #print "x(%d,%d), y(%d,%d)" % (min(startx,  endx), max(startx,  endx), min(starty, endy), max(starty, endy) );
            
    width = endx - startx;
    height = endy - starty;
    root_window.rectangle( gc, rcx, rcy, rcw, rch);
#    /* create a graphics context with a line on it */
#    gc = XCreateGC(display, root_window,
#                   GCFunction    | GCPlaneMask   | GCForeground |
#                   GCBackground  | GCLineWidth   | GCLineStyle  |
#                   GCCapStyle    | GCJoinStyle   | GCFillStyle  |
#                   GCFillRule    | GCGraphicsExposures          |
#                   GCClipXOrigin | GCClipYOrigin |  GCClipMask  |
#                   GCSubwindowMode,
#                   &gc_val);

def final():
    global startx, starty, endx, endy,  rcx, rcy, rcw,  rch,  output;
    debug("Starting cleanup");
    draw_rectangle();
    dis.flush();
    dis.close();
    debug("Finised cleanup");
    print output % (min(startx,  endx), max(startx,  endx), min(starty, endy), max(starty, endy) );

class NullDevice():
     def write(self, s):
        pass

if __name__ == "__main__":
    main()
