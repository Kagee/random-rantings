#!/usr/bin/env bash
cd /home/hildenae/bin/random-rantings
source harden.sh
source dns.he.net.update.config 
IP4=$(ip -4 addr show $INTERFACE | grep global | awk '/inet/{print $2}' | cut -d'/' -f1)
IP6=$(ip -6 addr show $INTERFACE | grep global | awk '/inet6/{print $2}' | cut -d'/' -f1)
OK4=$(curl --silent -k "https://dyn.dns.he.net/nic/update?hostname=$DOMAIN&password=$PASSWORD&myip=$IP4")
OK6=$(curl --silent -k "https://dyn.dns.he.net/nic/update?hostname=$DOMAIN&password=$PASSWORD&myip=$IP6")

if [ "$(echo $OK4 | grep -q -E 'nochg|good'; echo $?)" -ne 0 ]; then
  echo "Failed to update A-record for $DOMAIN: $OK4";
#else
#  echo "Updated A-record for $DOMAIN: $OK4"
fi
if [ "$(echo $OK6 | grep -q -E 'nochg|good'; echo $?)" -ne 0 ]; then
  echo "Failed to update AAAA-record for $DOMAIN: $OK6";
#else
#  echo "Updated AAAA-record for $DOMAIN: $OK6"
fi
