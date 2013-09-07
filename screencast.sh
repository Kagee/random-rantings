#!/bin/bash

# WARNING: This is a terribly dirty and messy shellscript, written over a
# couple of late nights. There was alcohol …
# You probably need to install all the gstreamer-plugins (at least -ugly
# and -ffmpeg) as well as gstreamer-tools to get this to work. I wanted to
# make mp4 files with x264, I didn't bother with free codecs.
# 
# To use the "Selected area" you will need python and python-xlib
# (and grep and tail and base64 and zcat, but you probably have those)
#
# So this script allows you to create screencasts on Linux, with optional
# sound inputs (both Microphone and system sounds). It stores system sounds
# and microphone in separate audio streams.
#
# You also get to choose to record from the whole screen, a specified window
# or a specified area. It has been tested on Fedora 18, CrunchBang Waldorf
# and Xubuntu/Ubuntu 12.10 & 13.04 (and thus should work on Debian Wheezy 
# as well).
# The code for specified area has only been tested on Xubuntu 12.10
#
# If you're using GStreamer 1.0, please jump to the bottom of the script
# and comment out the gst-launch-0.10 pipeline and uncomment the 1.0 pipeline.
#
# It dumps the recording in your $HOME directory with a filename like
# screencast-YYYY-MM-DD-HH-MM-SS.mp4
#
# Written by Einar Jørgen Haraldseid (http://einar.slaskete.net)
# Extended by Anders Einar Hilden (http://hild1.no)
# License: http://sam.zoy.org/wtfpl/COPYING

# Get device names and pretty names for enumerating playback sinks:
PLAYSINKLIST=$(pacmd list-sinks | \
 grep -e "name: " -e "device.description = " | cut -d " " -f "2-" | \
 sed -e "s/name: \|= //g" -e "s/<\|>\|\x22//g")

# Display playback monitor chooser
PLAYMON=$(echo "${PLAYSINKLIST}
none
Don't capture system sounds" | \
 zenity --list --title "Choose Output Device" \
 --text "Choose a sound device to capture system sound from:" \
 --column "device" --column "Name" --print-column=1 \
 --hide-column=1 2>/dev/null)

# Catch cancel
if [ -z ${PLAYMON} ]; then
  echo "No choice made on output device, assuming cancel."
  exit 1
fi

if [ ${PLAYMON} != "none" ]; then
  # Unmute monitor of the playback sink (if set):
  PLAYMON="${PLAYMON}.monitor"
  pacmd set-source-mute ${PLAYMON} false >/dev/null
  echo "Recording system sounds from ${PLAYMON}"
else
  echo "Not recording system sounds."
fi

# Get device names and pretty names for microphones:
MICLIST=$(pacmd list-sources | \
 grep -e "name: " -e "device.description = " | \
 grep -v -i "monitor" | cut -d " " -f "2-" | \
 sed -e "s/name: \|= //g" -e "s/<\|>\|\x22//g")

# Display device chooser
MIC=$(echo "${MICLIST}
none
Don't use a microphone" | \
 zenity --list --title "Choose Microphone" \
 --text "Choose a microphone to capture voice from:" \
 --column "device" --column "Name" --print-column=1 \
 --hide-column=1 2>/dev/null)

if [ -z ${MIC} ]; then
  echo "No choice made on microphone, assuming cancel."
  exit 1
fi

if [ ${MIC} != "none" ]; then
  echo "Recording voice from ${MIC}"
else
  echo "Not recording voice."
fi

# Get target window for recording:
TARGET=$(echo "root
Whole screen
window
Specific window
area
Selected area" | \
 zenity --list --title "Choose recording mode" \
 --text "Do you want to record the whole screen,\
 or record a specific window?" --column "target" \
 --column "Mode" --print-column=1 --hide-column=1 2>/dev/null)

if [ -z ${TARGET} ]; then
  echo "No choice for recording target, assuming cancel."
  exit 1
fi

SELECTOR="xwininfo"

if [ ${TARGET} = "root" ]; then
  echo "Root window chosen."
  XWININFO=$(xwininfo -root)
elif [ ${TARGET} = "window" ]; then
  echo "Custom window chosen."
  XWININFO=$(xwininfo)
else
  SELECTOR="python"
  echo "Custom area chosen."
  zenity --info --no-wrap --title "Instructions" --text "Click and draw a rectangle over the area of the screen \nyou want top record. When you release the mouse \nbutton, the recording will start."
  SELECTDATA=$(grep -A 46 __PYTHON_SELECT_PROGRAM_BELOW__ screencast.sh | tail -46 | python)
fi

# Get Window ID and dimensions, make sure X and Y dimensions are
# divisible by two, or else the encoder will fail
WID=$(echo "${XWININFO}" | grep "Window id:" | awk '{print $4}')
if [ ${SELECTOR} = "xwininfo" ]; then
    WIDTH=$(echo "${XWININFO}" | grep "Width: " | \
     cut -d ":" -f 2 | awk '{print $1+$1%2}')
    HEIGHT=$(echo "${XWININFO}" | grep "Height: " | \
     cut -d ":" -f 2 | awk '{print $1+$1%2}')
    ximagesrc
    XIMAGESRCPARAMS="xid=\"${WID}\""
else
    STARTX=$(echo "${SELECTDATA}" | cut -d "." -f 1 | awk '{print $1+$1%2}')
    STARTY=$(echo "${SELECTDATA}" | cut -d "." -f 3 | awk '{print $1+$1%2}')
    WIDTH=$(echo "${SELECTDATA}" | cut -d "." -f 5 | awk '{print $1+$1%2}')
    HEIGHT=$(echo "${SELECTDATA}" | cut -d "." -f 6 | awk '{print $1+$1%2}')
    # We don't use end and endy from python, as width/height might be changed
    ENDX=$(echo "${STARTX} ${WIDTH}" | cut -d "." -f 6 | awk '{print $1+$2}')
    ENDY=$(echo "${STARTY} ${HEIGHT}" | cut -d "." -f 6 | awk '{print $1+$2}')
    XIMAGESRCPARAMS="startx=${STARTX} starty=${STARTY} endx=${ENDX} endy=${ENDY}"
fi
# Calculate a suitable bitrate based on window dimensions
BITRATE=$(echo "${WIDTH} * ${HEIGHT} * 0.0075" | bc | cut -d "." -f 1 )

# Set file name.
FILENAME="screencast-$(date +%F-%H-%M-%S).mp4"

# Enable inputs as suitable
if [ ${PLAYMON} != "none" ]; then
  MONITORARG="pulsesrc device=${PLAYMON} slave-method=0 provide-clock=false \
   ! audiorate ! audioconvert ! ffenc_aac bitrate=256000 ! queue2 ! mux."
fi
if [ ${MIC} != "none" ]; then
  MICARG="pulsesrc device=${MIC} slave-method=0 provide-clock=false \
   ! audiorate ! audioconvert ! ffenc_aac bitrate=256000 ! queue2 ! mux."
fi

# Launch gstreamer (Using gstreamer 0.10)
gst-launch-0.10 -q -e ximagesrc ${XIMAGESRCPARAMS} do-timestamp=1 use-damage=0 \
 ! video/x-raw-rgb,framerate=30/1 ! ffmpegcolorspace  ! videoscale method=0 \
 ! video/x-raw-yuv,width=${WIDTH},height=${HEIGHT} \
 ! x264enc speed-preset=veryfast bitrate=${BITRATE} ! queue2 \
 ! mp4mux name="mux" \
 ! filesink location="${HOME}/${FILENAME}" ${MONITORARG} ${MICARG}

# Launch gstreamer (Using gstreamer 1.0)
#gst-launch-1.0 -q -e ximagesrc xid="${WID}" do-timestamp=1 use-damage=0 \
# ! video/x-raw,framerate=30/1 ! videoscale method=0 \
# ! video/x-raw,width=${WIDTH},height=${HEIGHT} ! videoconvert \
# ! x264enc speed-preset=veryfast bitrate=${BITRATE} ! queue2 \
# ! filesink location="${HOME}/${FILENAME}" ${MONITORARG} ${MICARG}

echo "Recording done, file is ${FILENAME}"
exit 0
__PYTHON_SELECT_PROGRAM_BELOW__
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
