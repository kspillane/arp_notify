
#!/bin/bash

arpcommand="/opt/vyatta/bin/vyatta-op-cmd-wrapper show arp switch0"
tw_user="<twilio_accountsid>"
tw_key="<twilio_api_key>"
tw_num="<destination_number>"
tw_from="<twilio_from_number>"
logonly=1

if [ ! -f .arptable ]
then
    touch .arptable
fi
$arpcommand > .arptablenew
touch .arplist
echo "New ARP Entries" > .arplist
for newarp in $(diff .arptablenew .arptable | grep + | grep ether | sed 's/^+//g' | awk '{print $1}')
do
    new_entry="$newarp - $(/opt/vyatta/bin/vyatta-op-cmd-wrapper show dhcp leases | grep "$newarp" | awk '{print $6}')"
    logger -t [arp_notify] "New Device Detected -> $new_entry"
    echo $new_entry >> .arplist
done

echo "" >> .arplist
echo "Removed ARP Entries" >> .arplist
for noarp in $(diff .arptablenew .arptable | grep - | grep ether | sed 's/^-//g' | awk '{print $1}')
do
    lost_entry="$noarp - $(/opt/vyatta/bin/vyatta-op-cmd-wrapper show dhcp leases | grep LAN | grep "$noarp" | awk '{print $6}')"
    logger -t [arp_notify] "ARP Entry Removed -> $lost_entry"
    echo $new_entry >> .arplist
done

message=$(cat .arplist)
if [ $(md5sum .arplist | awk '{ print $1 }') == "308be3015f740a9ad40a062a8738fba7" ]
then
    logger -t [arp_notify] "No new ARP entries detected."
else
    if [ -z $logonly ]
    then
        logger -t [arp_notify] "ARP table changes were detected. Sending alert."
        curl -X POST https://api.twilio.com/2010-04-01/Accounts/$tw_user/Messages.json \
        --data-urlencode "From=$tw_from" \
        --data-urlencode "Body=$message" \
        --data-urlencode "To=$tw_num" \
        -u $tw_user:$tw_key
    else
        logger -t [arp_notify] "ARP table changes were detected."
    fi
fi

rm .arplist .arptable
mv .arptablenew .arptable
