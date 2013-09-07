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
  zenity --info --title "Instructions" --text "Click and draw a rectangle over the area of the screen you want top record. When you release the mouse button, the recording will start."
  SELECTDATA=$(grep -A 14 __BASE64_GZIP_PYTHON_SELECT_PROGRAM_BELOW__ ${0} | tail -14 | base64 -d | zcat | python)
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
# Use 
# grep -A 14 __BASE64_GZIP_PYTHON_SELECT_PROGRAM_BELOW__ screencast.sh | tail -14 | \
# base64 -d | zcat > code.py
# to read the code
__BASE64_GZIP_PYTHON_SELECT_PROGRAM_BELOW__
H4sIAKugK1IAA4VUbY/UNhD+nl+Rgk6bCJM71F4/7NVILRQE6h0VIHUl1EZeZ5KY89rGL5dY0P/e
cbJZbuGg+2Ezz+PxzOPxjO//cBqcPd0KdWqi77XKxM5o63MXHdEua63e5Rsptvme35BGOCNZJJvg
hSQb5vXus1tlrPaaa7n4ww0oP697sYOFdhLAZDp4Ezy9d1I4z6wfy6Y6KUA1szFxceFmYxCN7yer
B9H1vmzu5aLNJagCFVfMdjflL/RRDtJBvjDvHv2dJdv5BjNWrQyuL8qMS+ZcfhWkfAo3gkNRrrO8
gTYfrPBQOJAtcYnLDTreikBv78kauq9I9XT+InfLN5l1PYO6vkuHo03luAU8Q5kNgrrKau0zvkML
5bAgfY0V1XbHTMYp31VMSs1nrjgjZ+Tn8/Mfz8tsxMXKiBHkP2djO/3yrKODqDA681B3vJBCQT1V
kf5EJuB8lEA31R8I3mgpGtIKKQ/0MwSvDPsQ4I0XxkjYr9swLf8lVCNU9xoR4cwctj1h5rfgPXmv
hTqQLxFcYm0tabWFzuqgGjpysmX8eo9ctZWI6ukYpA2Ke6EV7n2+GbUlnWWmF9zVMBrtggVHnzG8
a+LCdkApeqh3ukm5XiguQwMvVAtWaOtIqm2F+7e1QRkoonhrA5BiUyWhWv2Jwdwlc9efFuZSp9xH
1GuQwBwkriQoCsNdYr5fXVT8Dnz16ur3z58nwVqchrc4B+XFQc01xK1mtpnl/H/M4yiNVjCXACP2
QkKutM8Ti40L2FkKRl9PU4jdlWYFKh8NUHp07tTlI410oD09u0CA6ixwz1QnoejISCIZSF9eTH4w
dWg9JhQXFBGBvCPBvmYpxaQ2nfNr37nYV/jfxvX3BQyUbV0xPlxkTGQ/kXEh40SKthgfH9xS2C/U
o0N8fNgyORwd6Nsymiqoo2766mYWh8MF39EB34q9fxuSyaV2kExjMVE+v5knH1fzk7laj2Q242od
ySq9nsg9GCYzcQ96spoGfrVGcn42V+v+3+w/VrpZcvwFAAA=
