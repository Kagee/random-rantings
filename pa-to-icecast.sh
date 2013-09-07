#!/bin/bash
# Stream a pulseaudio monitor device to icecast
# Uses code from http://git.slaskete.net/einar-bin/blob/HEAD:/screencast.sh
# License: http://sam.zoy.org/wtfpl/COPYING

# Get device names and pretty names for enumerating playback sinks:
PLAYSINKLIST=$(pacmd list-sinks | \
 grep -e "name: " -e "device.description = " | cut -d " " -f "2-" | \
  sed -e "s/name: \|= //g" -e "s/<\|>\|\x22//g")

# Display playback monitor chooser
PLAYMON=$(echo "${PLAYSINKLIST}" | \
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


gst-launch-0.10 pulsesrc device=${PLAYMON} ! \
audioconvert ! \
audio/x-raw-int,rate=44100,channels=2 ! \
lamemp3enc bitrate=128 ! \
shout2send \
ip=localhost \
port=8000 \
password=$1 \
mount=stream
