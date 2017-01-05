#! /bin/bash

# 
# This is free and unencumbered software released into the public domain.
# 
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
# 
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
# 
# For more information, please refer to <http://unlicense.org/>
# 

cat <<HEADER
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
HEADER

LONGLATS=""
for IP in $(sudo tcptraceroute -n $1 | tail -n +2 | awk '{print $2}' | grep -E '^([0-9]{1,3}[\.]){3}[0-9]{1,3}$'); do 
#sudo tcptraceroute -n $1 | tail -n +2 | awk '{print $2}' | while read IP; do
       GEOIP=$(geoiplookup -f GeoLiteCity.dat $IP);
       if [ "$(echo "$GEOIP" | grep -q "IP Address not found"; echo $?;)" != "0" ]; then
	   LONG=$(echo "$GEOIP" | cut -d, -f 8)
	   LAT=$(echo "$GEOIP" | cut -d, -f 7)
	   LONGLAT="${LONG},${LAT}"
	   LONGLATS="${LONGLATS}${LONGLAT}\n"
           echo "<Placemark><name>$IP</name><description>GeoIP position for $IP</description><Point><coordinates>$LONGLAT</coordinates></Point></Placemark>";
       fi
done;

echo "<Placemark><name>Path</name><LineString><coordinates>";
#echo -e "${LONGLATS::-2}"
echo -e "$LONGLATS"
echo "</coordinates></LineString></Placemark>";

cat <<FOOTER
  </Document>
</kml>
FOOTER
