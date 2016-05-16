#!/bin/sh -e

# Description:       Script to collect and upload customer Linux configuration info

#Replace the following with valid FTP details
#EMC Employees can use https://ftpaccreq.isus.emc.com/ to request a temporary account
#If no command line options are specified, these details will be used
FTPUSER=username
FTPPASSWORD=password
FTPADDRESS=ftp.emc.com
CUSTOMERNAME=ACME



# Check the system is 64bit
case `uname -m` in
  x86_64|amd64) ;;
  *) echo "We only support 64-bit systems"; exit 1;;
esac

#Check the system has ftp installed
hash ftp 2>/dev/null || { echo >&2 "You need to install ftp before continuing"; exit 1; }


info() {
    echo "usage: $0 [-F <FTP Address>] [-U <FTP Username>] [-P <FTP Password>] [-C <Customer Name>]"
    exit ${1:-1}
}



while [ -n "$1" ]; do
    case "$1" in
      -h) info 0;;
      -F) shift
	  [ -n "$1" ] 
	  FTPADDRESS=$1
	  ;;
      -U) shift
	  [ -n "$1" ] 
	  FTPUSER=$1
	  ;;
	  -P) shift
	  [ -n "$1" ] 
	  FTPPASSWORD=$1
	  ;;
	  -C) shift
	  [ -n "$1" ] 
	  CUSTOMERNAME=$1
	  ;;
      *) echo "Invalid option $1"; echo; info 1;;
    esac
    shift
done

HOST=$(hostname)
LOGFILENAME="$CUSTOMERNAME-$HOST-CloudLink_Info-$(date +"%m_%d_%Y")"

#Remove the old file if found
rm -f $LOGFILENAME* 2> /dev/null


#Create the log file 
echo "###Output of 'ls -l /sys/class/block/' " 1>&2 > $LOGFILENAME 
ls -l /sys/class/block/ 2> /dev/null  >> $LOGFILENAME 

echo "###Output of 'ls -l /dev/mapper/'" 1>&2 >> $LOGFILENAME 
ls -l /dev/mapper/ 2> /dev/null >> $LOGFILENAME 

echo "###Output of 'blkid'" 1>&2 >> $LOGFILENAME 
blkid 2>&1  >> $LOGFILENAME 

echo "###Output of 'blkid -c /dev/null'" 1>&2 >> $LOGFILENAME 
blkid -c /dev/null 2> /dev/null >> $LOGFILENAME 

echo "###Output of 'lsblk -i' " 1>&2 >> $LOGFILENAME 
lsblk -i 2> /dev/null  >> $LOGFILENAME 

echo "###Output of 'dmsetup dep'" 2>&1 >> $LOGFILENAME
dmsetup deps 2> /dev/null  >> $LOGFILENAME 

echo "###Output of 'cat /proc/mounts'" 2>&1 >> $LOGFILENAME 
cat /proc/mounts 2> /dev/null  >> $LOGFILENAME 

echo "###Output of 'ls -l /usr/share/initramfs-tools/hooks/'" 2>&1 >> $LOGFILENAME
ls -l /usr/share/initramfs-tools/hooks/ 2> /dev/null  >> $LOGFILENAME 

echo "###Output of 'ls -l /usr/lib/systemd'" 2>&1 >> $LOGFILENAME 
ls -l /usr/lib/systemd/ 2> /dev/null >> $LOGFILENAME 

echo "###Output of 'ls -l /usr/share/dracut/'" 2>&1 >> $LOGFILENAME 
ls -l /usr/share/dracut/ 2> /dev/null  >> $LOGFILENAME 

echo "###Output of 'ls -l /usr/lib/dracut/'" 2>&1 >> $LOGFILENAME 
ls -l /usr/lib/dracut/ 2> /dev/null  >> $LOGFILENAME 

echo "###Output of 'ls -l /lib/mkinitrd/'" 2>&1 >> $LOGFILENAME
ls -l /lib/mkinitrd/ 2> /dev/null  >> $LOGFILENAME 

echo "###End of logging" >> $LOGFILENAME


#Qucik grub check
if [ -f /boot/grub/grub.cfg  ]; then
	if [[ $(more /etc/grub.conf | grep -e LVM) ]]; then
		echo ""
		echo "$(tput setaf 1)Warning: Possible Grub Configuratoin Issue$(tput sgr 0)"
		echo ""
	fi
fi
		
if [ -f /boot/grub/grub.conf ]; then
	if [[ $(more /etc/grub.conf | grep -e LVM) ]]; then
		echo "$(tput setaf 1)Warning: Possible Grub Configuratoin Issue$(tput sgr 0)"
		echo ""
	fi
fi

#Collect files into tar
tar -cf $LOGFILENAME.tar $LOGFILENAME
tar -rf $LOGFILENAME.tar /etc/*-release /etc/fstab /boot/grub/grub.cfg /boot/grub/grub.conf /boot/grub/menu.lst /boot/grub2/grub.cfg /boot/grub2/grub.conf /boot/grub2/menu.lst 2> /dev/null

#Remove the temp log file
rm -f $LOGFILENAME

echo "The following log file was created:"
echo "$LOGFILENAME.tar"
echo ""
echo "Uploading to FTP..."
echo ""
#Upload to FTP
ftp -n <<EOF
open $FTPADDRESS
user $FTPUSER $FTPPASSWORD
put $LOGFILENAME.tar
EOF

echo "Done"
echo ""
