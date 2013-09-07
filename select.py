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
    global dis;
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
        elif event.type == X.ButtonRelease:
            debug(event)
            endx = event.root_x;
            endy = event.root_y;
            done = True;
        elif event.type == X.MotionNotify:
            draw_rectangle();
    debug("Finished listening for events");
    
def grabby():
    debug("Starting grab");
    root_window.grab_pointer ( True, (X.ButtonPressMask | X.ButtonMotionMask | X.ButtonReleaseMask), X.GrabModeAsync, X.GrabModeAsync, 0, 0, X.CurrentTime );
    root_window.grab_keyboard(True, X.GrabModeAsync, X.GrabModeAsync,X.CurrentTime);
    debug("Finished grab");

def ungrabby():
    debug("Starting ungrab");
    dis.ungrab_pointer ( X.CurrentTime );
    dis.ungrab_keyboard ( X.CurrentTime );
    debug("Finished ungrab");    
    
def draw_rectangle():
    global startx, starty, endx, endy,  rcx, rcy, rcw,  rch;
    #print "x(%d,%d), y(%d,%d)" % (min(startx,  endx), max(startx,  endx), min(starty, endy), max(starty, endy) );
    gc = root_window.create_gc(
        function = X.GXor, 
        foreground = screen.black_pixel,
        background = screen.white_pixel,
        line_width = 4,
        line_style = X.LineSolid, 
        cap_style = X.CapButt, 
        join_style         = X.JoinMiter, 
        plane_mask         = X.AllPlanes, 
        fill_style         = FillOpaqueStippled,
        fill_rule          = WindingRule,
        graphics_exposures = False,
        clip_x_origin      = 0,
        clip_y_origin      = 0,
        clip_mask          = X.NONE,
        subwindow_mode     = X.IncludeInferiors
    )
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
