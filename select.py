import sys
import os

# Based on http://digitalfoo.net/posts/drawing-rectangles-on-the-screen-with-xlib-c-library
# 
#
#
from Xlib import X, display, Xutil, Xatom
from Xlib.protocol import event

global DEBUG;
DEBUG = True;

startx = -1;
starty = -1;
endx = -1;
endy = -1;

def debug(msg):
    if DEBUG:
        print msg;
        
def main():
    global startx, starty, endx, endy;
    init();
    grabby();
    event_parser();
    ungrabby();
    final();
    
def init():
    debug("Starting init");
    #global mystdout;
    #sys.stdout = mystdout = StringIO()
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
    global startx, starty, endx, endy;
    debug("Staring listening for events");
    done = False;
    while not done:
        event = dis.next_event()
        if event.type == X.ButtonPress:
            debug(event)
            startx = event.root_x;
            starty = event.root_y;
        elif event.type == X.ButtonRelease:
            debug(event)
            endx = event.root_x;
            endy = event.root_y;
            done = True;
        elif event.type == X.MotionNotify:
            #debug(event)
            draw_rectangle(startx, starty, event.root_x,  event.root_y);
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
    
def draw_rectangle(startx,  starty, endx,  endy):
#    print "x(%d,%d), y(%d,%d)" % (min(startx,  endx), max(startx,  endx), min(starty, endy), max(starty, endy) );
    gc = root_window.create_gc(
        foreground = screen.black_pixel,
        background = screen.white_pixel,
    )

def final():
    debug("Starting cleanup");
    dis.flush();
    dis.close();
    debug("Finised cleanup");
    print "x(%d,%d), y(%d,%d)" % (min(startx,  endx), max(startx,  endx), min(starty, endy), max(starty, endy) );

class NullDevice():
     def write(self, s):
        pass

if __name__ == "__main__":
    main()
