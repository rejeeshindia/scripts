# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac
bash /home/gns3/GNS3/scripts-rej/login.sh
alias "ll=ls -ltr"
alias "menu=bash /home/gns3/GNS3/scripts-rej/login.sh"
#/usr/local/bin/gns3welcome.py
echo "If the GNS3 menu is no longer working run sudo gns3restore"
gns3@gns3vm01-slave:~$ cat /home/gns3/GNS3/scripts-rej/login.sh
#!/bin/bash
USERNAME=admin
USERNAME1=root
USERNAME4=nsroot
PASSWORD1="admin"
PASSWORD2="Cisco123"
PASSWORD3="default"
PASSWORD4="nsroot"

IP_JUNOS17=192.168.122.2
IP_IOS15=192.168.122.3
IP_IOS_XR_612=192.168.122.4
IP_JUNOS14=192.168.122.6
IP_JUNOS15=192.168.122.15
IP_NEXUS=192.168.122.7
IP_ALU=192.168.122.8
IP_CSR1k=192.168.122.5
IP_FORTIGATE=192.168.122.9
IP_F5_BIGIP=192.168.122.10
IP_ASA=192.168.122.11
IP_NETSCALAR=192.168.122.13
IP_ALTEON=192.168.122.14
IP_FIREWORKS=192.168.122.17

main_menu () {

HEIGHT=25
WIDTH=60
CHOICE_HEIGHT=16
BACKTITLE="EURO NSO LAB"
TITLE="Multi Vendor Devices List"
MENU="Select options. Use UP/DOWN keys"

OPTIONS=(1 "NSO 4.6"
        2 "Junos 17.1"
        3 "IOS 15.2"
        4 "IOS-XR 6.1.2"
        5 "IOS-XR 6.2.3"
        6 "CSR1kv"
        7 "Junos 14"
        8 "Junos 15"
        9 "Nexus"
        10 "ALU SROS (No License - Reboot if down)"
        11 "Fortigate FortiOS"
        12 "F5-BIGIP"
	13 "Citrix NetScalar"
        14 "Radware Alteon"
	15 "Cisco ASA"
	16 "Cisco Fireworks vFTD 6.4.0"
        17 "Exit"
        18 "Setup")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

}
connect () {
        ip=$1
        uname=$2
        pwd=$3
        echo "Connecting to $ip"
        sleep 1
        exec sshpass -p $pwd ssh -o StrictHostKeyChecking=no $uname@$ip

}

main_menu

while :
do
clear
case $CHOICE in
        1)	exec ncs_cli -u admin
            ;;
        2)      connect  $IP_JUNOS17  $USERNAME  $PASSWORD2
            ;;
        3)      connect  $IP_IOS15  $USERNAME  $PASSWORD1
            ;;
        4)      connect  $IP_IOS_XR_612  $USERNAME  $PASSWORD1
            ;;
        5)      connect  $IP_IOS_XR_623  $USERNAME  $PASSWORD1
            ;;
        6)      connect  $IP_CSR1k  $USERNAME  $PASSWORD1
            ;;
        7)      connect  $IP_JUNOS14  $USERNAME  $PASSWORD2
            ;;
        8)      connect  $IP_JUNOS15  $USERNAME  $PASSWORD2
            ;;
        9)      connect  $IP_NEXUS  $USERNAME  $PASSWORD1
            ;;
        10)     connect  $IP_ALU  $USERNAME  $PASSWORD1
            ;;
        11)     connect  $IP_FORTIGATE  $USERNAME  $PASSWORD1
            ;;
        12)     connect  $IP_F5_BIGIP  $USERNAME1  $PASSWORD3
            ;;
        13)     connect  $IP_NETSCALAR  $USERNAME4  $PASSWORD4
	        ;;
        14)     connect  $IP_ALTEON  $USERNAME  $PASSWORD1
	        ;;
        15)     connect  $IP_ASA  $USERNAME  $PASSWORD1
		;;
	16)	connect $IP_FIREWORKS $USERNAME $PASSWORD2
		;;
	16)     echo "Returning to GNS3 Server Terminal..."
            sleep 1
            break
            ;;
        17)     echo "Calling GNS3 VM Main Menu..."
            sleep 2
            exec /usr/local/bin/gns3welcome.py
            ;;
        *)      echo "Sorry, I don't understand.Exitng menu"
            break
            ;;

esac
done




