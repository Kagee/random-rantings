#! /bin/bash
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
