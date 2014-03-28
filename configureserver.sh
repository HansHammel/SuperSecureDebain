#!/bin/bash
# Thanks go to a guy called 'Croydon' for thr base script

#sudo su

# Binaries
MAIL=$(which mail)
TELNET=$(which telnet)
DIG=$(which dig)

egrep -c -q ' lm ' /proc/cpuinfo && PLATFORM=64 || PLATFORM=32

# Function calculates number of bit in a netmask
#
#usage
#MASK=255.255.254.0
#numbits=$(mask2cidr $MASK)
#echo "/$numbits"
mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) echo "Error: $dec is not recognised"; exit 1
        esac
    done
    echo "$nbits"
}

cidr2mask() {
  local i mask=""
  local full_octets=$(($1/8))
  local partial_octet=$(($1%8))

  for ((i=0;i<4;i+=1)); do
    if [ $i -lt $full_octets ]; then
      mask+=255
    elif [ $i -eq $full_octets ]; then
      mask+=$((256 - 2**(8-$partial_octet)))
    else
      mask+=0
    fi  
    test $i -lt 3 && mask+=.
  done

  echo $mask
}

function networkip ()
{
	IFS=. read -r i1 i2 i3 i4 <<< "$SERVERIP"
	IFS=. read -r m1 m2 m3 m4 <<< "$NMASKIP"
	printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$(($i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
}

secureapacherestart ()
{
	a2enmod $1 && service apache2 restart | grep failed || a2dismod $1 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#a2dismod $1 && a2enmod $1 && service apache2 restart | grep failed || a2dismod $1 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
}

progressfilt ()
{
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%c' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}

#usage download "url"
download()
{
     local url=$1
     echo -n "    "
     wget --progress=dot $url 2>&1 | grep --line-buffered "%" | \
         sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
     echo -ne "\b\b\b\b"
     echo " DONE"
}

function sethtmlfolderpermissions() {
	_dir="${1:-.}"
	_fperm="0444"
	_dperm="0445"
	_ugperm="root:root"
	_chmod="/bin/chmod"
	_chown="/bin/chown"
	_find="/usr/bin/find"
	_xargs="/usr/bin/xargs"
	 
	echo "I will change the file permission for webserver dir and files to restrctive read-only mode for \"$_dir\""
	read -p "Your current dir is ${PWD}. Are you sure (y / n) ?" ans
	if [ "$ans" == "y" ]
	then
		echo "Changing file onwership to $_ugperm for $_dir..."
		$_chown -R "${_ugperm}" "$_dir"
	 
		echo "Setting $_fperm permission for $_dir directory...."
		$_chmod -R "${_fperm}" "$_dir"
	 
		echo "Setting $_dperm permission for $_dir directory...."
		$_find "$_dir" -type d -print0 | $_xargs -0 -I {} $_chmod $_dperm {}
	fi
}

function colorerrors () {
$@ 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
}

function _configure_locale() { # [profile]
    local profile=${1:-EN}
    case ${profile} in
      DE|DE_DE|de_DE)
          LC_ALL="de_DE.UTF-8"
          LANG="de_DE.UTF-8"
          LANGUAGE="de_DE:de:en_US:en"
          ;;
      EN|EN_US|en|en_US)
          LC_ALL="en_US.UTF-8"
          LANG="en_US.UTF-8"
          LANGUAGE="en_US:en"
          ;;
      *)
          echo "ALERT" "${FUNCNAME}: unknown profile '${profile}'"
          ;;
      esac
      LC_PAPER="de_DE.UTF-8"; # independent from locale
      LESSCHARSET="utf-8";    # independent from locale
      MM_CHARSET="utf-8"      # independent from locale
      echo "locale settings" "${LANG}";
      export LC_ALL LANG LANGUAGE LC_PAPER LESSCHARSET MM_CHARSET
}

function pause(){
   echo 'Press Enter to continue...'
   read -p "$*"
}

function yecho(){
	#red='\e[0;31m'
	yellow='\e[1;33m'
	#black='\e[0;30m'
	#green='\e[0;32m'
	#white='\e[1;37m'
	#gray='\e[1;30m'Flo
	#blue='\e[0;34m'
	NC='\e[0m' # No Color
	echo -e "${yellow}$1${NC}"
}

function gecho(){
	green='\e[0;32m'
	NC='\e[0m' # No Color
	echo -e "${green}$1${NC}"
}

function recho(){
	red='\e[0;31m'
	NC='\e[0m' # No Color
	echo -e "${red}$1${NC}"
}

function wecho(){
	white='\e[1;37m'
	NC='\e[0m' # No Color
	echo -e "${white}$1${NC}"
}

#unescapeandenable "UseIPv6" "/etc/proftpd/proftpd.conf" "\"on\" \"off\""
# comments or uncomments, enables or disables by user interaction 
function unescapeandenable {
#FNAME="/etc/proftpd/proftpd.conf";
FNAME=$2
#LINE="UseIPv6";
LINE=$1;
#remark double escaped string
OPTIONS=$3
#OPTIONS="\"on\" \"off\"";
#OPTIONS="\"true\" \"false\"";
#OPTIONS="\"1\" \"0\"";
# comment or uncomment line
read -p "Uncomment ${LINE} in ${FNAME} (y/n)?" UNCOMMENT
# remark ( ) | not possible in normal regex
CHECKISUC=`grep -e "^ *\t*${LINE}" ${FNAME}` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
CHECKISC=`grep -e "^ *\t*# *\t*${LINE}" ${FNAME}` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
if [[ $UNCOMMENT =~ ^[YyJj]$ ]] ; then
if [[ "$CHECKISC" != "" ]] ; then
	#uncomment:
	sed -i "/${LINE}/ s/ *\t*# *\t*//" $FNAME 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi
# enable or disable feature
#read -p "Enable ${line} in ${FNAME} (y/n)?" ENABLE
#echo OPTIONS $OPTIONS
PS3="Set to: "
eval set $OPTIONS
select OPT in "$@"
do
# remark ( ) | not in enhanced regex (-E)
sed -i -r "/${LINE}/ s/( |\t)+((off)|(on)|0|1|(true)|(false))( |\t)*$/ ${OPT}/" $FNAME 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
break;
done
else
if [[ "$CHECKISUC" != "" ]] ; then
	#to comment it out:
	sed -i "/${LINE}/ s/^/# /" $FNAME 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi
fi
}

echo '
Did you setup your DNS for the doamin?
(1) Setup the "A" record type for your mian domain, e.g. "*.MYDOMAIN.COM", and point it to your servers public ip address
(2) Setup the "CNAME" record type like "*.MYDOMAIN.COM" for all other 
(3) Setup the "MX" record type, e.g. "MYDOMAIN.COM", for the mail agent and set as "MX Value" "10"

Did you configure your router and firewall to forward important ports like 25, 80, 143, 443, 991, 587

While Bind9 is setup now, there is one last thing to do. On your router you have to change the nameserver resolution order. The first nameserer must now be your "mail server" with the according static local ip. Otherwise the whole bind9 setup was for nothing. As the second nameserver enter the value of what was aleady in there as first one. Depending on your router it can be a bit trickier.
'
pause

#disable aptitude to avoid confusions
chmod 0 /usr/bin/aptitude

if [[ $(id -u) -ne 0 ]] ; then
recho "Please run this script with root privilegues!" ;
exit 2 ;
fi

DEBIAN_OK=`cat /etc/debian_version`

if [[ "$DEBIAN_OK" = "" ]] ; then
recho "This is not a debian server..." ;
exit;
fi

dpkg-reconfigure locales 
dpkg-reconfigure tzdata

LOCALES_OK=`locale -a | grep 'en_US.utf8'` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

if [[ "$LOCALES_OK" = "" ]] ; then
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
locale-gen 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

yecho "switching to english to make shell commands work" ;
_configure_locale EN

read -p "Please enter the server hostname (e.g. server123)?" HOSTNAME
CHECK=`echo $HOSTNAME | grep -E "[^[:alnum:]\-]"` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
if [[ "$CHECK" != "" ]] ; then
recho "$HOSTNAME is not a valid hostname!" ;
exit 2;
fi

read -p "Please enter the server domain name (mydomain.com)?" DNNAME
CHECK=`echo $DNNAME | grep -E "[^[:alnum:]\-\.-]"` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
if [[ "$CHECK" != "" ]] ; then
recho "$DNNAME is no valid domain name!" ;
exit 2;
fi

FQDNNAME="$HOSTNAME.$DNNAME" ;

read -p "So the server name should be ($FQDNNAME) (y/n)?" DOIT
if [[ ! $DOIT =~ ^[YyJj]$ ]] ; then
recho "aborted!" ;
exit 0 ;
fi

#yecho "installing bridge-utils"
#apt-get -q -y install bridge-utils
#/etc/network/interfaces 
##Bridge setup
#auto br0
#  iface br0 inet static
#  bridge_ports eth0
#  bridge_fd 0
#  address 192.168.2.121
#  netmask ${NMASKIP}
#  gateway 192.168.2.1
#  dns-nameservers 8.8.8.8

#install resolvconf (not necessary - links /etc/resolv.conf to /etc/resolvconf/run/resolv.conf)
#yecho "installing resolvconf"
#apt-get -q -y install resolvconf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#vlan support
#yecho "installing module-init-tools"
#apt-get -q -y install module-init-tools 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#yecho "installing vlan"
#apt-get -q -y install vlan 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#If you are using a brigded VLAN setup, which is probably useful for networking in virtualization environments, take care to only attach either a bridge device or VLAN devices to an underlying physical device - like shown above. Attaching the physical interface (eth0) to a bridge (eg. bri1) while using the same physical interface on apparently different VLANs will result in all packets to remain tagged. (Kernel newer than 2.6.37 and older than 3.2). 
#grep -q -e '^8021q' /etc/modules || 
#echo '8021q' >> /etc/modules 
#grep -q -e 'vlan-raw-device eth0' /etc/modules || 
#echo "
#auto eth0.20
#iface eth0.20 inet dhcp
#        vlan-raw-device eth0
#	iface eth0.20 inet static
#	        address ${SERVERIP}
#	        netmask ${NAMSKIP}
#	        network ${NETWORKIP}
#	        broadcast ${BCASTIP}
#	        vlan-raw-device eth0
#	#alternative ip
#	#do not configute gateway and dns-nameservers for alternative ips        
#	auto eth0:0
#	allow-hotplug eth0:0
#	iface eth0:0 inet static
#	    address ${SERVERIP}
#	    netmask ${NMASKIP}
#" >> /etc/network/interfaces 

#NIC-Teaming/ Bonding
#yecho "installing ifenslave-2.6"
#apt-get install ifenslave-2.6 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#/etc/network/interfaces 
#auto lo bond0
#iface bond0 inet static
#	 address ${SERVERIP}
#	 netmask ${NAMSKIP}
#	 network ${NETWORKIP}
#	 broadcast ${BCASTIP}
#  gateway 10.10.10.1
#  slaves eth0 eth1
#  bond_mode 802.3ad
#mode=0 (balance-rr) 
#mode=1 (active-backup) 
#mode=2 (balance-xor) 
#mode=3 (broadcast) 
#mode=4 (802.3ad) (siehe dazu Link Aggregation und LACP Grundlagen) 
#mode=5 (balance-tlb) 
#mode=6 (balance-alb) 

#network bonding
#yecho "installing ifenslave-2.6"
#apt-get install ifenslave-2.6 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#configure network
#/etc/network/interfaces 
#iface eth0 inet dhcp
#iface eth0 inet static 
#        address ${SERVERIP} 
#        netmask ${NMASKIP}
#        gateway 192.168.0.1
#        dns-search somedomain.org
#        dns-nameservers 192.168.0.1

#set dns on static configurations
grep -q -e '8.8.8.8' /etc/resolv.conf ||
echo "
#IPv4 addresses
nameserver         192.168.0.1
nameserver         8.8.8.8
nameserver         4.2.2.1
#IPv6 addresses
nameserver         ::1
nameserver         2001:4860:4860::8888
nameserver         2001:4860:4860::8844
" >> /etc/resolv.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#set dns if using dhcp
grep -q -e '^prepend domain-name-servers' /etc/dhcp/dhclient.conf ||
echo '
#prepend domain-name-servers 127.0.0.1;
prepend domain-name-servers 127.0.0.1, 8.8.8.8, 8.8.4.4, 192.168.0.1;
prepend domain-name-servers ::1, 2001:4860:4860::8888, 2001:4860:4860::8844;
' >> /etc/dhcp/dhclient.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#if you run a server with dhcp configuration it is important to gain a new ip regularly to detect errors and missconfiguration
#grep -q -e '^send dhcp-lease-time' /etc/dhcp/dhclient.conf ||
#echo '
#send dhcp-lease-time 3600;
#' >> /etc/dhcp/dhclient.conf



read -p "Do you want to use the <stable> or <testing> distribution? [stable]" DISTRIB

if [[ "$DISTRIB" = "" ]] ; then
DISTRIB="stable" ;
fi

if [[ "$DISTRIB" != "testing" && "$DISTRIB" != "stable" ]] ; then
recho "aborted!" ;
exit 0 ;
fi

read -p "We will install lots of packages now! Shall we start (y/n)?" DOIT

if [[ ! $DOIT =~ ^[YyJj]$ ]] ; then
recho "aborted!" ;
exit 0 ;
fi

yecho "hosts, hostname and mailname setup"
SERVERIP=`ifconfig | grep -i 'inet addr:' | sed -r "s/.*inet\s+addr:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\s*.*/\1.\2.\3.\4/" | grep -v 'addr:127.0.' | head -n 1` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
BCASTIP=`ifconfig | grep -i 'Bcast:' | sed -r "s/.*Bcast:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\s*.*/\1.\2.\3.\4/" | grep -v 'addr:127.0.' | head -n 1` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
NMASKIP=`ifconfig | grep -i 'Mask:' | sed -r "s/.*Mask:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\s*.*/\1.\2.\3.\4/" | grep -v 'addr:127.0.' | head -n 1` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
SERVERIPv6=`echo "${SERVERIP}" | sed -r 's/\./ /' | printf "2002:%02x%02x:%02x%02x::1"`


OK="no"
while [[ "$OK" = "no" ]] ; do
read -p "Main-IP of the server (has to be set up in ifconfig already) [$SERVERIP]: " SETSERVERIP ;
if [[ "$SETSERVERIP" = "" ]] ; then
SETSERVERIP="$SERVERIP" ;
fi
CHECK=`ifconfig | grep ":$SETSERVERIP"`;
if [[ "$CHECK" = "" ]] ; then
recho "IP not found in ifconfig" ;
else
OK="yes" ;
fi
done
SERVERIP="$SETSERVERIP" ;

OK="no"
while [[ "$OK" = "no" ]] ; do
read -p "Broadcast IP of the server (has to be set up in ifconfig already) [$BCASTIP]: " SETBCASTIP ;
if [[ "$SETBCASTIP" = "" ]] ; then
SETBCASTIP="$BCASTIP" ;
fi
CHECK=`ifconfig | grep ":$SETBCASTIP"`;
if [[ "$CHECK" = "" ]] ; then
recho "IP not found in ifconfig" ;
else
OK="yes" ;
fi
done
BCASTIP="$SETBCASTIP" ;

OK="no"
while [[ "$OK" = "no" ]] ; do
read -p "Netmask of the server (has to be set up in ifconfig already) [$NMASKIP]: " SETNMASKIP ;
if [[ "$SETNMASKIP" = "" ]] ; then
SETNMASKIP="$NMASKIP" ;
fi
CHECK=`ifconfig | grep ":$SETNMASKIP"`;
if [[ "$CHECK" = "" ]] ; then
recho "IP not found in ifconfig" ;
else
OK="yes" ;
fi
done
NMASKIP="$SETNMASKIP" ;
NMASKCIDR=$(mask2cidr $NMASKIP);

NETWORKIP=$(networkip);
read -p "Network IP [$NETWORKIP]: " SETNETWORKIP ;
if [[ ! "$SETNETWORKIP" = "" ]] ; then
NETWORKIP="$SETNETWORKIP" ;
fi

GATEWAYIP=`route -n | grep 'UG[ \t]' | awk '{print $2}'`;
read -p "Gateway IP [$GATEWAYIP]: " SETGATEWAYIP ;
if [[ ! "$SETGATEWAYIP" = "" ]] ; then
GATEWAYIP="$SETGATEWAYIP" ;
fi

VLANID="";
read -p "Type a VLAN ID or leave blank for none [$VLANID]: " SETVLANID ;
if [[ ! "$SETNAMESERVERIP" = "" ]] ; then
VLANID="$SETVLANID" ;
fi

NAMESERVERIP="${SERVERIP}";
read -p "Type a Nameserver IP or setup a new nameserver [$NAMESERVERIP]: " SETNAMESERVERIP ;
if [[ ! "$SETNAMESERVERIP" = "" ]] ; then
NAMESERVERIP="$SETNAMESERVERIP" ;
fi

## set hostname
cp /etc/hosts /etc/hosts.save 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cp /etc/hostname /etc/hostname.save 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
if [[ -e /etc/mailname ]] ; then
cp /etc/mailname /etc/mailname.save 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

CHECK=`grep "$SERVERIP" /etc/hosts` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
if [[ "$CHECK" = "" ]] ; then
echo "$SERVERIP $FQDNNAME $HOSTNAME" >> /etc/hosts  2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
else
sed -i -r "s/^[^0-9]*$SERVERIP\s+.*$/$SERVERIP $FQDNNAME $HOSTNAME/" /etc/hosts  2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

echo "$HOSTNAME" > /etc/hostname 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
echo "$FQDNNAME" > /etc/mailname 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
hostname $HOSTNAME 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#/etc/init.d/hostname.sh start
# or better
hostname -F /etc/hostname 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "solving possibly corrupted dependencies"
# solve install problems e.g. messed up dependencies, etc.
apt-get -f -y clean 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
apt-get -f -y install 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

## create apt sources
#cp /etc/apt/sources.list /etc/apt/sources.list.save ;

#echo "deb http://ftp.de.debian.org/debian $DISTRIB main contrib non-free" > /etc/apt/sources.list ;
#echo "#deb-src http://ftp.de.debian.org/debian $DISTRIB main contrib non-free" >> /etc/apt/sources.list ;

#echo "deb http://security.debian.org/ $DISTRIB/updates main contrib non-free" >> /etc/apt/sources.list ;
#echo "#deb-src http://security.debian.org/ $DISTRIB/updates main contrib non-free" >> /etc/apt/sources.list ;

#echo "deb http://ftp.de.debian.org/debian/ squeeze-updates main" >> /etc/apt/sources.list ;

#if [[ "$DISTRIB" = "stable" ]] ; then
# echo "deb http://volatile.debian.org/debian-volatile squeeze/volatile main contrib non-free" >> /etc/apt/sources.list ;
#fi

yecho "updating apt packages and keys..."
# archive keys
yecho "installing debian-archive-keyring"
apt-get -q -y --force-yes install debian-archive-keyring 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done) 
# developer keys
#yecho "installing debian-keyring"
#apt-get -q -y --force-yes install debian-keyring 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
apt-key update 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

DONE="no" ;
STEP=0 ;
while [[ "$DONE" = "no" && "$STEP" -lt "7" ]] ; do
STEP=$[STEP + 1];
echo "STEP: $STEP";
## update apt
CHECK=`apt-get update -qq 2>&1 | grep -E "^W:" | grep 'NO_PUBKEY'` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
echo "CHECK: $CHECK";
if [[ "$CHECK" != "" ]] ; then
PUBKEY=`echo "$CHECK" | sed -r "s/.*(NO_PUBKEY)\s+([0-9a-zA-Z]+)(\s+|$).*/\2/" | head -n 1` ;
echo "PUBKEY: $PUBKEY";
CHECK=`echo "$PUBKEY" | grep -E "[^A-Za-z0-9]"`
echo "CHECK2: $CHECK";
if [[ "$CHECK" = "" ]] ; then
echo "Import Public key $PUBKEY." ;
#gpg --keyserver pgp.mit.edu --recv "$PUBKEY";
gpg --keyserver keyring.debian.org --recv "$PUBKEY" 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
gpg --export --armor "$PUBKEY" | apt-key add -  2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi
else
DONE="yes" ;
fi
done

apt-key update 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
apt-get -q -y update 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "searchin fastest mirror..."
# choose fastest mirror
yecho "installing netselect-apt"
apt-get -q -y install netselect-apt 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
wget --no-cookies http://www.debian.org/mirror/mirrors_full -N /tmp/mirrors_full -q 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
netselect-apt -c DE -i /tmp/mirrors_full -o ~/sources.list stable 2>&1 | grep -A1 "Of the hosts tested we choose the fastest valid for"
mv /etc/apt/sources.list /etc/apt/sources.list.save 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cp  ~/sources.list /etc/apt/ 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^deb http://security.debian.org' /etc/apt/sources.list ||
echo 'deb http://security.debian.org/ stable/updates main contrib' >> /etc/apt/sources.list
grep 'deb-src http://security.debian.org' /etc/apt/sources.list ||
echo '#deb-src http://security.debian.org/ stable/updates main contrib' >> /etc/apt/sources.list

SOURCES_OK=`cat /etc/apt/sources.list | grep '^deb http://security.debian.org/ stable/updates main contrib'` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
if [[ "$SOURCES_OK" = "" ]] ; then
echo '
# Security updates for stable
deb http://security.debian.org/ stable/updates main contrib' >> /etc/apt/sources.list 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

yecho "upgrading system..."
# upgrade apt
apt-get -q -y update 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# upgrade packages
apt-get -q -y upgrade -y -V 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# upgrade system
apt-get -q -y dist-upgrade 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# update files database
updatedb

#pause 'Press [Enter] key to continue...'


yecho "installing openssh-client openssh-server"
apt-get -q -y install openssh-client openssh-server 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "ssh setup"
## check for ssh option
CHECK=`grep -e '^SSHD_OOM_ADJUST=-17' /etc/default/ssh` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
if [[ "$CHECK" != "" ]] ; then
sed -i s/SSHD_OOM_ADJUST=-17/#SSHD_OOM_ADJUST=-17/ /etc/default/ssh 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
echo "unset SSHD_OOM_ADJUST" >> /etc/default/ssh 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi
#cat /etc/services | grep ssh
#nano /etc/ssh/sshd_config
# change Port
sed -i -r "s/^Port .*/Port 22/g" /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/^Protocol .*/Protocol 2/g" /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/^DebianBanner .*/DebianBanner no/g" /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

addgroup --system sshusers 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# no root login CAUTION!
PS3="Allow ssh root login (CAUTION!): "
OPTIONS="yes no";
eval set $OPTIONS
select OPT in "$@"
do
# remark ( ) | not in enhanced regex (-E)
sed -i -r "s/^PermitRootLogin .*/PermitRootLogin ${OPT}/g" /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
adduser root sshusers 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
break;
done
USERLIST=`cat /etc/passwd | cut -d: -f1` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
OPTIONS=`sed "s/\n/ /g" <<< "$USERLIST Done"`
PS3="Add users to sshusers group: "
eval set $OPTIONS
select OPT in "$@"
do
if [ "$OPT" = "Done" ]; then
break;
else
adduser $OPT sshusers 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi
done
grep -q -E '^AllowGroups .*sshusers.*$' /etc/ssh/sshd_config ||
sed -i -r "s/^AllowGroups .*/AllowGroups sshusers/g" /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep -q -E '^AllowGroups .*sshusers.*$' /etc/ssh/sshd_config ||
echo 'AllowGroups sshusers' >> /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# add at least the current user 
USER = `id -u -n`
grep -q -E "^AllowUsers .*${USER}.*$" /etc/ssh/sshd_config ||
sed -i -r "s/^AllowUsers .*/AllowUsers ${USER}/g" /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep -q -E "^AllowUsers .*${USER}.*$" /etc/ssh/sshd_config ||
echo "AllowUsers ${USER}" >> /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep -q -E '^ *#? *X11Forwarding .*no.*$' /etc/ssh/sshd_config ||
sed -i -r "s/^ *#? *X11Forwarding .*/X11Forwarding no/g" /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep -q -E '^ *#? *X11Forwarding .*no.*$' /etc/ssh/sshd_config ||
echo 'X11Forwarding no' >> /etc/ssh/sshd_config 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#systemctl restart ssh.service


# setup notification on ssh login
grep -q -e '^Login auf ' /opt/shell-login.sh ||
echo '
#!/bin/bash
echo "Login auf $(hostname) am $(date +%Y-%m-%d) um $(date +%H:%M)"
echo "Benutzer: $USER"
echo
' >> /opt/shell-login.sh &&
chmod 755 /opt/shell-login.sh 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

read -p "Please enter an e-mail for ssh login and update notifications? " SSHMAIL
SSHMAIL=${SSHMAIL:-mail@specialsolutions}
#replace a line
#sed -i 's/^\/opt\/shell-login\.sh.*$/another string/' /etc/profile

grep -e '^/opt/shell-login.sh' /etc/profile ||
echo "
/opt/shell-login.sh | mailx -s \"SSH Login auf $FQDNNAME\" $SSHMAIL
" >> /etc/profile 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#some aliases and root mail forwarding
grep -E 'll: "ls' /etc/aliases || echo "ls: \"ls ${LS_OPTIONS}\"
ll: \"ls ${LS_OPTIONS} -l\"
l: \"ls ${LS_OPTIONS} -lA\"
l: \"ls ${LS_OPTIONS} -lA\"
watch --color
egrep: \"egrep --color=tty\"
fgrep: \"fgrep --color=tty\"
grep: \"grep --color=tty\"
root:${SSHMAIL}
" >> /etc/aliases 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#generate aliases
newaliases 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "installing packages..."


read -p "Install vim (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
yecho "installing vim vim-nox"
apt-get -q -y install vim vim-nox 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

apt-get -q -y install binutils 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

read -p "Install sudo (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	apt-get -q -y install sudo 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	USERLIST=`cat /etc/passwd | cut -d: -f1` 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	OPTIONS=`sed "s/\n/ /g" <<< "$USERLIST Done"`
	PS3='Add users to /etc/sudoers: '
	eval set $OPTIONS
	select OPT in "$@"
	do
	if [ "$OPT" = "Done" ]; then
	break;
	else
	grep "${OPT}" /etc/sudoers ||
	echo "${OPT}   ALL=(ALL:ALL) ALL" >> /etc/sudoers 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	fi
	done
fi

#protect su
#groupadd admin
#usermod -a -G admin <YOUR ADMIN USERNAME>
#dpkg-statoverride --update --add <YOUR ADMIN USERNAME> admin 4750 /bin/su
#dpkg-statoverride --update --add root admin 4750 /bin/su


yecho "installing ntp ntpdate"
apt-get -q -y install ntp ntpdate 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

read -p "Install user quota (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	yecho "installing quota quotatool"
	apt-get -q -y install quota quotatool 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	
	cp /etc/fstab /etc/fstab.save 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	
	CHECK=`grep -E "^[^[:space:]]+[[:space:]]+\/[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+" /etc/fstab | grep 'usrquota'`
	if [[ "$CHECK" = "" ]] ; then
	sed -i -r "s/(\S+\s+\/\s+\S+\s+)(\S+)(\s+)/\1\2,usrquota\3/" /etc/fstab ;
	fi
	
	CHECK=`grep -E "^[^[:space:]]+[[:space:]]+\/[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+" /etc/fstab | grep 'grpquota'`
	if [[ "$CHECK" = "" ]] ; then
	sed -i -r "s/(\S+\s+\/\s+\S+\s+)(\S+)(\s+)/\1\2,grpquota\3/" /etc/fstab ;
	fi
	
	#nano /etc/fstab
	#ad usrjquota=quota.user,grpjquota=quota.group,jqfmt=vfsv0 to mount point /
	# or UUID=[...]  /  ext3  errors=remount-ro,grpjquota=aquota.group,jqfmt=vfsv0  0  1
	
	touch /quota.user /quota.group 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	chmod 600 /quota.* 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	mount -vo remount / 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	quotacheck -avugm 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	quotaon -avug 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

# commercial
#read -p "Install LiveConfig Hosting Control Panel (y/n) [no]? " -n 1 REPLY
#if [[ $REPLY =~ ^[YyjJ]$ ]]
#then
#	#Install LiveConfig Hosting Control Panel
#	wget -O - https://www.liveconfig.com/liveconfig.key | apt-key add -
#	cd /etc/apt/sources.list.d
#	wget http://repo.liveconfig.com/debian/liveconfig.list
#	apt-get -y -q update
#	#Typischer Webserver mit liveconfig-meta  (mit Apache httpd, MySQL-Datenbank, PHP und Postfix/Dovecot) 
#	apt-get -y -q install liveconfig-meta
#	#Installation von LiveConfig
#	apt-get -y -q install liveconfig
#	#manuel
#	# Install Apache PHP ProFTPd MySQL Postfix Dovecot ClamAV-Milter Bind 9
#	#Laden Sie die neueste Version von LiveConfig herunter:
#	#wget --trust-server-names http://download.liveconfig.com/latest?liveconfig_amd64.deb
#	#Installieren Sie anschlie�end das heruntergeladene Paket via dpkg:
#	#dpkg -i liveconfig_1.5.0-r1687_amd64.deb
#	 LCINITPW=password /usr/sbin/liveconfig --init
#	 #login admin 
#	 #pw password
#fi



# install postresql
# apt-get install postgresql libdbd-pgsql postgresql-client

#	20
#http://www.customvms.de/allgemein/install-mysql-community-database-server-on-debian-wheezy
# install mysql and set root password
yecho "installing mysql-client mysql-server libmysqlclient18 libdbd-mysql"
apt-get -q -y install mysql-client mysql-server libmysqlclient18 libdbd-mysql 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# set bind-address=localhost in /etc/mysql/my.cnf
# read -p "Please enter the root password for mysql server?" MYSQLPW 
# not workin /usr/bin/mysqladmin -u root -h 127.0.0.1 password \'$MYSQLPW\'

#secure mysql
mysql_secure_installation

#mysql configuration
#nano /etc/mysql/my.cnf
#config sample
#/usr/share/doc/mysql-server/examples 

service mysql restart
#systemctl restart mysql.service

read -p "Install nginx (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#install nginx
	yecho "installing nginx php5-fpm php5-cgi php5-cli php5-common"
	apt-get -q -y install nginx php5-fpm php5-cgi php5-cli php5-common
	
	useradd www-data
	groupadd www-data 
	usermod -g www-data www-data 
	
	sed -i -r 's/^\t* *#?\t* *user .*$/user www-data www-data;/g' /etc/nginx/nginx.conf 
	sed -i -r 's/^\t* *#?\t* *worker_processes .*$/worker_processes 4;/g' /etc/nginx/nginx.conf  
	sed -i -r 's/^\t* *#?\t* *gzip .*$/gzip on;/g' /etc/nginx/nginx.conf 
	sed -i -r 's/^\t* *#?\t* *gzip_disable .*$/gzip_disable \"msie6\";/g' /etc/nginx/nginx.conf  
	sed -i -r 's/^\t* *#?\t* *gzip_min_length .*$/gzip_min_length 1100;/g' /etc/nginx/nginx.conf  
	sed -i -r 's/^\t* *#?\t* *gzip_vary .*$/gzip_vary on;/g' /etc/nginx/nginx.conf  
	sed -i -r 's/^\t* *#?\t* *gzip_proxied .*$/gzip_proxied any;/g' /etc/nginx/nginx.conf 
	sed -i -r 's/^\t* *#?\t* *gzip_buffers .*$/gzip_buffers 16 8k;/g' /etc/nginx/nginx.conf 
	sed -i -r 's/^\t* *#?\t* *gzip_vary .*$/user www-data www-data/g' /etc/nginx/nginx.conf 
	sed -i -r 's/^\t* *#?\t* *gzip_types .*$/gzip_types text\/plain text\/css application\/json application\/x-javascript text\/xml application\/xml application\/rss\+xml text\/javascript image\/svg\+xml application\/x-font-ttf font\/opentype application\/vnd\.ms-fontobject;/g' /etc/nginx/nginx.conf 
				
	# change nginx to use default /var/www (may conflict with apache)
	#mkdir /var/www 
	#chmod 775 /var/www -R 
	#chown www-data:www-data /var/www
	# now copy to /var/www
	
	cp /etc/nginx/sites-available/default /etc/nginx/sites-available/www
	rm /etc/nginx/sites-enabled/default
	
	#listen   80; ## listen for ipv4; this line is default and implied
	#listen   [::]:80 default_server ipv6only=on; ## listen for ipv6

	sed -i -r "s/^\t* *#?\t* *listen\t* *[[:digit:]].*$/listen 8888;/g" /etc/nginx/sites-available/www
	sed -i -r "s/^\t* *#?\t* *listen\t* *\[.*$/listen \[::\]:8888 default_server ipv6only=on; #ipv6/g" /etc/nginx/sites-available/www	
	#sed -i -t "s/^\t* *#?\t* *server_name *\[.*$/server_name $[DNNAME}/g" /etc/nginx/sites-available/www	
	sed -i -r "s/^\t* *#?\t* *index index\.html index\.htm.*$/index index\.html index\.htm index\.php;/g" /etc/nginx/sites-available/www	

	#echo '
  #  server {
	#		#disbaleipv6
	#    #listen   [::]:80 default ipv6only=on; ## listen for ipv6
	#		#set server name
	#    server_name www.mysite.com;
	#		# or set root to /var/www
	#		# root /var/www;
  #      root /usr/share/nginx/www;
  #      index index.html index.htm index.php;

  #      server_name localhost;

  #      location / {
  #          try_files $uri $uri/ /index.html;
  #      }
  #      #uncomment this section
  #      #location /doc/ {
  #      #    alias /usr/share/doc/;
  #      #    autoindex on;
  #      #   allow 127.0.0.1;
  #      #    allow ::1;
  #      #    deny all;
  #      #}
  #  }
	#' >> /etc/nginx/sites-available/www
	
	# link the site to activate
	ln -s /etc/nginx/sites-available/www /etc/nginx/sites-enabled/www
	
	#	default: #listen = /var/run/php5-fpm.sock
	sed -i -r "s/^\t* *;?\t* *listen = \/var\/run\/php5-fpm\.sock/listen = 127\.0\.0\.1:9000/g" /etc/php5/fpm/pool.d/www.conf 
	sed -i -r "s/^\t* *;?\t* *user =.*/user = www-data/g" /etc/php5/fpm/pool.d/www.conf
	sed -i -r "s/^\t* *;?\t* *group =.*/group = www-data/g" /etc/php5/fpm/pool.d/www.conf
		#/etc/php5/fpm/php-fpm.conf

	#restart
	service php5-fpm restart 
	service nginx restart
	#/etc/init.d/nginx restart
	
fi

#install apache
yecho "installing apache2 apache2.2-common apache2-doc apache2-mpm-prefork apache2-utils libexpat1 ssl-cert"
apt-get -q -y install apache2 apache2.2-common apache2-doc apache2-mpm-prefork apache2-utils libexpat1 ssl-cert 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

read -p "Install libapache-mod-security (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#configure libapache-mod-security
	apt-get -q -y install libapache-mod-security
	cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
	sed -i -r "s/^\t* *#?\t* *SecRequestBodyLimit\t* *.*/SecRequestBodyLimit 67108864/g" /etc/modsecurity/modsecurity.conf
	sed -i -r "s/^\t* *#?\t* *SecRequestBodyInMemoryLimit\t* *.*/SecRequestBodyInMemoryLimit 67108864/g" /etc/modsecurity/modsecurity.conf
	sed -i -r "s/^\t* *#?\t* *SecRuleEngine\t* *.*/SecRuleEngine On/g" /etc/modsecurity/modsecurity.conf
	
	#install the latest OWASP Core Rule Set
	cd /tmp
	wget -O SpiderLabs-owasp-modsecurity-crs.tar.gz https://github.com/SpiderLabs/owasp-modsecurity-crs/tarball/master
	tar -zxvf SpiderLabs-owasp-modsecurity-crs.tar.gz
	cp -R SpiderLabs-owasp-modsecurity-crs-*/* /etc/modsecurity/
	rm SpiderLabs-owasp-modsecurity-crs.tar.gz
	rm -R SpiderLabs-owasp-modsecurity-crs-*
	mv /etc/modsecurity/modsecurity_crs_10_setup.conf.example /etc/modsecurity/modsecurity_crs_10_setup.conf
	#create symlink to activate
	cd /etc/modsecurity/base_rules
	for f in * ; do sudo ln -s /etc/modsecurity/base_rules/$f /etc/modsecurity/activated_rules/$f ; done
	cd /etc/modsecurity/optional_rules
	for f in * ; do sudo ln -s /etc/modsecurity/optional_rules/$f /etc/modsecurity/activated_rules/$f ; done 
	
	grep -q '^Include \"/etc/modsecurity/activated_rules/*.conf\"' /etc/apache2/mods-available/mod-security.conf ||
	echo 'Include "/etc/modsecurity/activated_rules/*.conf"' >> /etc/apache2/mods-available/mod-security.conf
	secureapacherestart headers
	secureapacherestart mod-security
fi

read -p "Install libapache2-mod-evasive (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#configure libapache2-mod-evasive
	apt-get -q -y install libapache2-mod-evasive 
	mkdir /var/log/mod_evasive
	chown www-data:www-data /var/log/mod_evasive/
	echo "<ifmodule mod_evasive20.c>
	   DOSHashTableSize 3097
	   DOSPageCount  2
	   DOSSiteCount  50
	   DOSPageInterval 1
	   DOSSiteInterval  1
	   DOSBlockingPeriod  10
	   DOSLogDir   /var/log/mod_evasive
	   DOSEmailNotify  ${SSHMAIL}
	   DOSWhitelist   127.0.0.1
	</ifmodule>
	" > /etc/apache2/mods-available/mod-evasive.conf
	secureapacherestart mod-evasive
fi

read -p "Install cache (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
:
#http://httpd.apache.org/docs/2.2/caching.html
fi

#configure apache2
grep -q '^ServerTokens Prod' /etc/apache2/conf.d/security ||
sed -i -r "s/ *\t*#? *\t*ServerTokens *\t*.*/ServerTokens Prod/g" /etc/apache2/conf.d/security
grep -q '^ServerTokens Prod' /etc/apache2/conf.d/security ||
echo 'ServerTokens Prod' >> /etc/apache2/conf.d/security

grep -q '^ServerSignature Off' /etc/apache2/conf.d/security ||
sed -i -r "s/ *\t*#? *\t*ServerSignature *\t*.*/ServerSignature Off/g" /etc/apache2/conf.d/security
grep -q '^ServerSignature Off' /etc/apache2/conf.d/security ||
echo 'ServerSignature Off' >> /etc/apache2/conf.d/security

grep -q '^TraceEnable Off' /etc/apache2/conf.d/security ||
sed -i -r "s/ *\t*#? *\t*TraceEnable *\t*.*/TraceEnable Off/g" /etc/apache2/conf.d/security
grep -q '^TraceEnable Off' /etc/apache2/conf.d/security ||
echo 'TraceEnable Off' >> /etc/apache2/conf.d/security

#grep -q '^Header unset ETag' /etc/apache2/conf.d/security ||
#sed -i -r "s/ *\t*#? *\t*Header *\t*unset *\t*ETag.*/Header unset ETag/g" /etc/apache2/conf.d/security
#grep -q '^Header unset ETag' /etc/apache2/conf.d/security ||
#echo 'Header unset ETag' >> /etc/apache2/conf.d/security

#grep -q '^FileETag None' /etc/apache2/conf.d/security ||
#sed -i -r "s/ *\t*#? *\t*FileETag *\t*.*/FileETag None/g" /etc/apache2/conf.d/security
#grep -q '^FileETag None' /etc/apache2/conf.d/security ||
#echo 'FileETag None' >> /etc/apache2/conf.d/security

# share group with apache
chgrp -R www-data /etc/apache2/sites-available/
chgrp -R www-data /etc/apache2/sites-enabled/
chgrp -R www-data /var/www/
chown -R www-data:www-data /etc/apache2/sites-available/
chown -R www-data:www-data /etc/apache2/sites-enabled/
chown -R www-data:www-data /var/www/
chmod -R 755 /etc/apache2/sites-available/
chmod -R 755 /etc/apache2/sites-enabled/
chmod -R 755 /var/www/

#/etc/init.d/apache2 restart
service apache2 restart

#install php
yecho "installing imagemagick php5-imagick php5-gd php5-imap php5-intl php5-ldap php5-mcrypt mcrypt php-auth php-pear php5 php5-adodb php5-cgi php5-cli php5-common php5-curl php5-ming php5-ps php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl"
apt-get -q -y install imagemagick php5-imagick php5-gd php5-imap php5-intl php5-ldap php5-mcrypt mcrypt php-auth php-pear php5 php5-adodb php5-cgi php5-cli php5-common php5-curl php5-ming php5-ps php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

read -p "Install a PHP opcode Cache (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#opcode caches 

	#php accelerator is depricated
	
	# APC best choice
	read -p "Install Alternative PHP Cache (APC) (y/n) [no]? " -n 1 REPLY
	if [[ $REPLY =~ ^[YyjJ]$ ]]
	then
		#Install Alternative PHP Cache (APC)
		apt-get -y -q install php-apc
		#or
		#apt-get -y -q install php-pear
		#pecl install apc

		#echo '
		#extension                 = apc.so
		#apc.enabled               = 1
		#apc.shm_size              = 48
		#' >> /etc/php5/conf.d/apc.ini
		
		grep -q -E "^extension=apc.so" /etc/php5/conf.d/20-apc.ini ||
		sed -i -r "s/ *\t*\;? *\t*extension *\t*=.*/extension=apc\.so/g" /etc/php5/conf.d/20-apc.ini
	
		grep -q -E "^extension=apc.so" /etc/php5/mods-available/apc.ini ||
		sed -i -r "s/ *\t*\;? *\t*extension *\t*=.*/extension=apc\.so/g" /etc/php5/mods-available/apc.ini
	
		grep -q -E "^extension=apc.so" /etc/php5/cgi/php.ini ||
		sed -i -r "s/ *\t*\;? *\t*extension *\t*=.*/extension=apc\.so/g" /etc/php5/cgi/php.ini
		
		grep -q -E "^extension=apc.so" /etc/php5/apache2/php.ini ||
		sed -i -r "s/ *\t*\;? *\t*extension *\t*=.*/extension=apc\.so/g" /etc/php5/apache2/php.ini
		
		grep -q -E "^extension=apc.so" /etc/php5/cli/php.ini ||
		sed -i -r "s/ *\t*\;? *\t*extension *\t*=.*/\;extension=apc\.so/g" /etc/php5/cli/php.ini
		
		grep -q "^apc.enabled=1" /etc/php5/apache2/php.ini || 
		echo '
		apc.enabled=1
		apc.shm_segements=1
		apc.optimization=0
		apc.num_files_hint=2048
		apc.shm_size=128M
		apc.ttl=3600
		apc.user_ttl=7200
		apc.gc_ttl=3600
		apc.enable_cli=0
		apc.max_file_size=64M
		## Normally set ##
		#apc.stat=1
		## Or if you know what you are doing then set ##
		apc.stat=0
		#disable on every path with wp-cache-config in it - for some plugins compatibility
		apc.filters=wp-cache-config
		' >> /etc/php5/apache2/php.ini
	
		#systemctl restart apache2.service
		service apache2 restart
	fi
	
	#xcache
	#maybe unstable -> segmentation fault
	read -p "Install Xcache (y/n) [no]? " -n 1 REPLY
	if [[ $REPLY =~ ^[YyjJ]$ ]]
	then
	# use Xcache
		yecho "installing php5-xcache"
		apt-get -q -y install php5-xcache 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		echo '[xcache]
		xcache.shm_scheme =        "mmap"
		xcache.size  =                48M
		xcache.count =                 2
		xcache.slots =                8K
		xcache.ttl   =                 0
		xcache.gc_interval =           0
		xcache.readonly_protection = Off
		xcache.mmap_path =           "/var/cache/xcache.mmap"
		xcache.coredump_directory =  ""
		xcache.cacher =              On
		xcache.stat   =              On
		xcache.optimizer =           Off
		xcache.var_size  =            0M
		xcache.var_count =             1
		xcache.var_slots =            8K
		xcache.var_ttl   =             0
		xcache.var_maxttl   =          0
		xcache.var_gc_interval =     300
		xcache.test =                Off 
		' >> /etc/php5/conf.d/xcache.ini
	fi
	
	#eaccelerator
	#maybe unstable -> segmentation fault	
	read -p "Install eaccelerator (y/n) [no]? " -n 1 REPLY
	if [[ $REPLY =~ ^[YyjJ]$ ]]
	then	
		#build from source
		#phpize
		#./configure
		#make
		#make install 
		echo ' 
		zend_extension                  = /usr/lib/php5/20060613/eaccelerator.so
		eaccelerator.shm_size           = 48
		eaccelerator.cache_dir          = /var/cache/eaccelerator
		eaccelerator.enable             = 1
		eaccelerator.optimizer          = 1
		eaccelerator.check_mtime        = 0
		eaccelerator.debug              = 0
		eaccelerator.filter             = ""
		eaccelerator.shm_max            = 0
		eaccelerator.shm_ttl            = 0
		eaccelerator.shm_prune_period   = 0
		eaccelerator.shm_only           = 1
		eaccelerator.compress           = 1
		eaccelerator.compress_level     = 9  
		' >> /etc/php5/conf.d/eaccelerator.ini
	fi

fi

read -p "Install memcached - distributed memory object caching system (if you need to keep multiple servers in sync for php and mysql) (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#install memcached
	apt-get -q -y install php5-memcached memcached
	#prefere memcached (newer) over php-memcache
	#alternative
	#install memcache
	#apt-get -q -y install php5-memcache 
	
	grep '^extension=memcached.so' /etc/php5/conf.d/memcached.ini ||
	sed -i -r "s/ *\t*;? *\t*extension *\t*= *\t*memcached\.so/extension=memcached\.so/g" /etc/php5/conf.d/memcached.ini
	
	#Install phpMemcachedAdmin (optional)
	mkdir /var/www/phpMemcachedAdmin
	cd /var/www/phpMemcachedAdmin
	wget http://phpmemcacheadmin.googlecode.com/files/phpMemcachedAdmin-1.2.2-r262.tar.gz
	tar -xvzf phpMemcachedAdmin-1.2.2-r262.tar.gz
	chmod +r *
	chmod 0777 Config/Memcache.php
	#You may want to restrict access to this directory using .htaccess
	
	#test if memcached is running
	#ps -eaf | grep memcached
	#or 
	#netstat -tap | grep memcached
	
	#inspectconfig
	#echo "stats settings" | nc localhost 11211
	
	#edit configuration
	#nano /etc/memcached.conf
	# modify -m 64 to -m 128
	
	#php test file
	echo '<?php
	$mc = new Memcached();
	$mc->addServer("127.0.0.1", 11211);
	
	$result = $mc->get("test_key");
	
	if($result) {
	  echo $result;
	} else {
	  echo "No data on Cache. Please refresh page pressing F5";
	  $mc->set("test_key", "test data pulled from Cache!") or die ("Failed to save data at Memcached server");
	}
	?>
	' >> /var/www/phpMemcachedAdmin/test.php
	
	systemctl restart memcached.service 
	systemctl restart apache2.service
fi

read -p "Install php-cache-lite - File Cach (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#File Caching
	apt-get install -q -y php-cache-lite 
fi

yecho "php setup" 
yecho "installing php5-cli php5-curl php5-gd php5-imagick php5-imap php5-mcrypt php5-mhash php5-mysql php5-sqlite"
apt-get -q -y install php5-cli php5-curl php5-gd php5-imagick php5-imap php5-mcrypt php5-mhash php5-mysql php5-sqlite 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done) 
#php5-suhosin #not in wheezy yet
yecho "installing php5-mysqlnd"
#prefering php5-mysqlnd over php5-mysql
apt-get -q -y install php5-mysqlnd 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
yecho "installing libapache2-mod-fcgid libapache2-mod-php5 apache2-suexec libapache2-mod-suphp"
apt-get -q -y install libapache2-mod-fcgid libapache2-mod-php5 apache2-suexec libapache2-mod-suphp 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)



#problems with
#apache2-suexec libapache2-mod-suphp 

# use PHP-FPM
#yecho "installing libapache2-mod-fastcgi php5-fpm"
#apt-get -q -y install libapache2-mod-fastcgi php5-fpm 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#nano /etc/php5/apache2/php.ini
grep '^disable_functions = exec,system,shell_exec,passthru' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?disable_functions *=.*/disable_functions = exec,system,shell_exec,passthru/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^disable_functions = exec,system,shell_exec,passthru' /etc/php5/apache2/php.ini ||
echo 'disable_functions = exec,system,shell_exec,passthru' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)


#	extension=mysql.so 
grep '^extension = mysql.so' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?extension *=.*/extension = mysql\.so/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^extension = mysql.so' /etc/php5/apache2/php.ini ||
echo 'extension = mysql.so' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^default_charset = "UTF-8"' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?default_charset *=.*/default_charset = \"UTF-8\"/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^default_charset = "UTF-8"' /etc/php5/apache2/php.ini ||
echo 'default_charset = "UTF-8"' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# Disable allow_url_include for security reasons
grep '^allow_url_fopen = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?allow_url_fopen *=.*/allow_url_fopen = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^allow_url_fopen = Off' /etc/php5/apache2/php.ini ||
echo 'allow_url_fopen = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^allow_url_include = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?allow_url_include *=.*/allow_url_include = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^allow_url_include = Off' /etc/php5/apache2/php.ini ||
echo 'allow_url_include = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^expose_php = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?expose_php *=.*/expose_php = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^expose_php = Off' /etc/php5/apache2/php.ini ||
echo 'expose_php = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# is tuned on by using any output handler 
grep '^output_buffering = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?output_buffering *=.*/output_buffering = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^output_buffering = Off' /etc/php5/apache2/php.ini ||
echo 'output_buffering = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^implicit_flush = On' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?implicit_flush *=.*/implicit_flush = On/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^implicit_flush = On' /etc/php5/apache2/php.ini ||
echo 'implicit_flush = On' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# Note: You cannot use both "mb_output_handler" with "ob_iconv_handler"
#   and you cannot use both "ob_gzhandler" and "zlib.output_compression".
# Note: output_handler must be empty if this is set 'On' !!!!
#   Instead you must use zlib.output_handler.
# prefere ob_gzhandler over zlib.output_compression
grep '^zlib.output_compression = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?zlib.output_compression *=.*/zlib.output_compression = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^zlib.output_compression = Off' /etc/php5/apache2/php.ini ||
echo 'zlib.output_compression = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^zlib.output_compression_level = -1' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?zlib.output_compression_level *=.*/zlib.output_compression_level = -1/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^zlib.output_compression_level = -1' /etc/php5/apache2/php.ini ||
echo 'zlib.output_compression_level = -1' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# ob_gzhandler allows aditional output handler
grep '^output_handler = "ob_gzhandler"' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?output_handler *=.*/output_handler = \"ob_gzhandler\"/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^output_handler = "ob_gzhandler"' /etc/php5/apache2/php.ini ||
echo 'output_handler = "ob_gzhandler"' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^memory_limit = 128M' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?memory_limit *=.*/memory_limit = 128M/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^memory_limit = 128M' /etc/php5/apache2/php.ini ||
echo 'memory_limit = 128M' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^upload_max_filesize = 64M' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?upload_max_filesize *=.*/upload_max_filesize = 64M/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^upload_max_filesize = 64M' /etc/php5/apache2/php.ini ||
echo 'upload_max_filesize = 64M' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^max_execution_time = 120' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?max_execution_time *=.*/max_execution_time = 120/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^max_execution_time = 120' /etc/php5/apache2/php.ini ||
echo 'max_execution_time = 120' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^max_input_time = 120' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?max_input_time *=.*/max_input_time = 120/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^max_input_time = 120' /etc/php5/apache2/php.ini ||
echo 'max_input_time = 120' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^post_max_size = 64M' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?post_max_size *=.*/post_max_size = 64M/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^post_max_size = 64M' /etc/php5/apache2/php.ini ||
echo 'post_max_size = 64M' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^session.gc_maxlifetime = 1440' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?session.gc_maxlifetime *=.*/session.gc_maxlifetime = 1440/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^session.gc_maxlifetime = 1440' /etc/php5/apache2/php.ini ||
echo 'session.gc_maxlifetime = 1440' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^session.cache_expire = 180' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?session.cache_expire *=.*/session.cache_expire = 180/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^session.cache_expire = 180' /etc/php5/apache2/php.ini ||
echo 'session.cache_expire = 180' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# Development Value: E_ALL
# Production Value: E_ALL & ~E_DEPRECATED & ~E_STRICT
grep '^error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_NOTICE' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?error_reporting *=.*/error_reporting = E_ALL \& \~E_DEPRECATED \& \~E_STRICT \& \~E_NOTICE/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_NOTICE' /etc/php5/apache2/php.ini ||
echo 'error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_NOTICE' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^display_errors = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?display_errors *=.*/display_errors = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^display_errors = Off' /etc/php5/apache2/php.ini ||
echo 'display_errors = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^track_errors = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?track_errors *=.*/track_errors = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^track_errors = Off' /etc/php5/apache2/php.ini ||
echo 'track_errors = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^html_errors = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?html_errors *=.*/html_errors = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^html_errors = Off' /etc/php5/apache2/php.ini ||
echo 'html_errors = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^log_errors = On' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?log_errors *=.*/log_errors = On/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^log_errors = On' /etc/php5/apache2/php.ini ||
echo 'log_errors = On' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# disable cache when testing soap
#soap.wsdl_cache_enabled = 0
#soap.wsdl_cache_ttl = 0
# enable cache on production
grep '^soap.wsdl_cache_enabled = 1' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?soap.wsdl_cache_enabled *=.*/soap.wsdl_cache_enabled = 1/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^soap.wsdl_cache_enabled = 1' /etc/php5/apache2/php.ini ||
echo 'soap.wsdl_cache_enabled = 1' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^soap.wsdl_cache_ttl = 86400' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?soap.wsdl_cache_ttl *=.*/soap.wsdl_cache_ttl = 86400/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^soap.wsdl_cache_ttl = 86400' /etc/php5/apache2/php.ini ||
echo 'soap.wsdl_cache_ttl = 86400' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^file_uploads = On' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?file_uploads *=.*/file_uploads = On/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^file_uploads = On' /etc/php5/apache2/php.ini ||
echo 'file_uploads = On' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^session.cache_expire = 180' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?session.cache_expire *=.*/session.cache_expire = 180/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^session.cache_expire = 180' /etc/php5/apache2/php.ini ||
echo 'session.cache_expire = 180' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^session.gc_maxlifetime = 1440' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?session.gc_maxlifetime *=.*/session.gc_maxlifetime = 1440/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^session.gc_maxlifetime = 1440' /etc/php5/apache2/php.ini ||
echo 'session.gc_maxlifetime = 1440' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# Magic quotes for incoming GET/POST/Cookie data.
grep '^magic_quotes_gpc = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?magic_quotes_gpc *=.*/magic_quotes_gpc = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^magic_quotes_gpc = Off' /etc/php5/apache2/php.ini ||
echo 'magic_quotes_gpc = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# Magic quotes for runtime-generated data, e.g. data from SQL, from exec(), etc.
grep '^magic_quotes_runtime = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?magic_quotes_runtime *=.*/magic_quotes_runtime = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^magic_quotes_runtime = Off' /etc/php5/apache2/php.ini ||
echo 'magic_quotes_runtime = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# Use Sybase-style magic quotes (escape ' with '' instead of \').
grep '^magic_quotes_sybase = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?magic_quotes_sybase *=.*/magic_quotes_sybase = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^magic_quotes_sybase = Off' /etc/php5/apache2/php.ini ||
echo 'magic_quotes_sybase = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#include_path = ".:/usr/local/lib/php" 

grep '^safe_mode = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?safe_mode *=.*/safe_mode = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^safe_mode = Off' /etc/php5/apache2/php.ini ||
echo 'safe_mode = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^magic_quotes_gpc = On' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?magic_quotes_gpc *=.*/magic_quotes_gpc = On/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^magic_quotes_gpc = On' /etc/php5/apache2/php.ini ||
echo 'magic_quotes_gpc = On' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^register_globals = Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?register_globals *=.*/register_globals = Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^register_globals = Off' /etc/php5/apache2/php.ini ||
echo 'register_globals = Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '^zend.ze1_compatibility_mode Off' /etc/php5/apache2/php.ini ||
sed -i -r "s/^;? ?zend.ze1_compatibility_mode *=.*/zend.ze1_compatibility_mode Off/g" /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep '^zend.ze1_compatibility_mode Off' /etc/php5/apache2/php.ini ||
echo 'zend.ze1_compatibility_mode Off' >> /etc/php5/apache2/php.ini 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)



#mybe some of these  


#nano /etc/apache2/mods-enabled/userdir.conf 
#	<IfModule mod_userdir.c>
#	        UserDir public_html
#	        UserDir disabled root
#	
#	        <Directory /home/*/public_html>
#	                AllowOverride All
#	                Options MultiViews Indexes SymLinksIfOwnerMatch
#	                <Limit GET POST OPTIONS>
#	                        Order allow,deny
#	                        Allow from all
#	                </Limit>
#	                <LimitExcept GET POST OPTIONS>
#	                        Order deny,allow
#	                        Deny from all
#	                </LimitExcept>
#	        </Directory>
#	</IfModule>
# Create directory as user (not as root): 
#mkdir /home/$USER/public_html
# Change group as root (substitute your username) and restart web server: 
#chgrp www-data /home/<username>/public_html
#set file permissions to 755
#find /home/<username>/demo -type f -perm 777 -print -exec chmod 755 {} \;
#find /home/<username>/public_html -type f -print -exec chmod 755 {} \;
#set file folder to 755
#find /var/www/html -type d -perm 777 -print -exec chmod 755 {} \;
#find /home/<username>/public_html -type d -print -exec chmod 755 {} \;
#sethtmlfolderpermissions /home/<username>/public_html
#chmod 755 -R /home/<username>
#service apache2 restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#!/bin/bash
PS3='Install (multiple): '
OPTIONS="Perl Ruby Python Done"
eval set $OPTIONS
select OPT in "$@"
do
case $OPT in
  "Perl")
		#install perl
		yecho "installing perl libapache2-mod-perl"
		apt-get -q -y install perl libapache2-mod-perl 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		yecho "installing libnet-ldap-perl libauthen-sasl-perl daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl"
		apt-get -q -y install libnet-ldap-perl libauthen-sasl-perl daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done);
  ;;
  "Python")
		#install python
		yecho "installing python libapache2-mod-python"
		#websockets for python
		#apt-get -q -y install python-django-websocket python-mod-pywebsocket
		#apt-get -q -y install python-mysqldb
		apt-get -q -y install python libapache2-mod-python 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	;;      
  "Ruby")
		#apt-get install mysql-client libmysqlclient
		#install ruby
		#maybe libmysqlclient-dev is needed
		yecho "installing librmagick-ruby rubygems rails ruby libruby ruby-passenger libapache2-mod-passenger libapache2-mod-ruby"	
		apt-get -q -y install librmagick-ruby rubygems rails ruby libruby libapache2-mod-passenger libapache2-mod-ruby
		yecho "installing ruby gems rake rack i18n bundler mysql2 rmagick rails"	
		#maybe ruby1.9.1-dev is needed if not possible to build gem extensions
		gem install -q rake rack i18n bundler mysql2 rmagick rails
		# mysql2 or pg or sqlite3-ruby
  ;;
  "Done")
      break
      ;;
  *) echo invalid option;;
esac
done

PS3='Choose a MTA: '
OPTIONS=''
select OPT in Postfix exim Courier Done
#SendMail QMail Done
do
case $OPT in
  "Postfix")
		yecho "installing postfix postfix-mysql postfix-doc"
	apt-get -q -y install postfix postfix-mysql postfix-doc 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#nano /etc/postfix/main.cf 
	#virtual_alias_maps = hash:/etc/postfix/virtual
	dpkg-reconfigure postfix 
	
	#General type of mail configuration: <-- Select "Internet Site"
	#System mail name: <-- Enter: "MYDOMAIN.COM"
	#Root and postmaster mail recipient: <-- Leave blank
	#Other destinations to accept mail for (blank for none): <-- Enter: "MYDOMAIN.COM, localhost.MYDOMAIN.COM, localhost.localdomain, localhost"
	#Force synchronous updates on mail queue? <-- Select "No"
	#Local networks: <-- Leave as default
	#Use procmail for local delivery? <-- Select "Yes"
	#Mailbox size limit (bytes): <-- Enter "0"
	#Local address extension character: <-- Enter "+"
	#Internet protocols to use: <-- Select "all"

	yecho "postfix setup" 
	postconf -e "myhostname = $FQDNNAME"
	postconf -e "smtpd_sasl_local_domain = $DNNAME"
	#postconf -e 'smtpd_sasl_local_domain ='	
	postconf -e 'broken_sasl_auth_clients = yes'
	postconf -e 'home_mailbox = Maildir/'
	postconf -e 'inet_interfaces = all'
	postconf -e 'mailbox_command = /usr/bin/procmail -a "$EXTENSION" DEFAULT=$HOME/Maildir/ MAILDIR=$HOME/Maildir'
	postconf -e 'smtp_tls_note_starttls_offer = yes'
	postconf -e 'smtp_use_tls = yes'
	postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject _unauth_destination, reject_non_fqdn_recipient, reject_invalid_hostname, reject_non_fqdn_hostname, reject_rbl_client zen.spamhaus.org, reject_rbl_client bl.spamcop.net'
	postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination'
	postconf -e 'smtpd_sasl_auth_enable = yes'
	postconf -e 'smtpd_sasl_authenticated_header = yes'
	postconf -e 'smtpd_sasl_security_options = noanonymous'
	postconf -e 'smtpd_tls_CAfile = /etc/postfix/ssl/cacert.pem'
	postconf -e 'smtpd_tls_auth_only = no'
	postconf -e 'smtpd_tls_cert_file = /etc/postfix/ssl/smtpd.crt'
	postconf -e 'smtpd_tls_key_file = /etc/postfix/ssl/smtpd.key'
	postconf -e 'smtpd_tls_loglevel = 1'
	postconf -e 'smtpd_tls_received_header = yes'
	postconf -e 'smtpd_tls_session_cache_timeout = 3600s'
	postconf -e 'smtpd_use_tls = yes'
	postconf -e 'tls_random_source = dev:/dev/urandom'
	postconf -e 'virtual_maps = hash:/etc/postfix/virtual'
	grep 'pwcheck_method: saslauthd' /etc/postfix/sasl/smtpd.conf ||
	echo 'pwcheck_method: saslauthd' >> /etc/postfix/sasl/smtpd.conf
	grep 'mech_list: plain login' /etc/postfix/sasl/smtpd.conf ||
	echo 'mech_list: plain login' >> /etc/postfix/sasl/smtpd.conf 
	
	#enable saslauthd
	# needs more configuration https://wiki.debian.org/PostfixAndSASL
	sed -i -r "s/^START=.*/START=yes/" /etc/default/saslauthd 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	adduser postfix sasl 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	
	#/etc/init.d/postfix restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	service postfix restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	
	#Install ClamAV-Milter for postfix (check for biruses and trojans)
	yecho "installing clamav-milter"
	apt-get -y -q install clamav-milter
	break
	;;
  "exim")
    yecho "installing exim4"
	  ISINST = `dpkg -s exim4 | grep "install ok installed"`
	  if [ "$ISINST"="" ]; then
	  apt-get -q -y install exim4
	  else
	  dpkg-reconfigure exim4-config
	  fi
	  chmod -R u+rw /var/log/exim4
		chown -R Debian-exim /var/log/exim4
	  service exim4 restart
	  #send testmail
	  echo "exim installation testmail from ${FQDNNAME}" | mail -s "exim testmail" $SSHMAIL
	  break
	;;  
  "Courier")
		yecho "installing courier-authdaemon courier-authlib-mysql courier-pop courier-pop-ssl courier-imap courier-imap-ssl courier-maildrop"
		apt-get -q -y install courier-authdaemon courier-authlib-mysql courier-pop courier-pop-ssl courier-imap courier-imap-ssl courier-maildrop 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		yecho "installing libsasl2-2 libsasl2-modules libsasl2-modules-sql sasl2-bin libpam-mysql"
		apt-get -q -y install libsasl2-2 libsasl2-modules libsasl2-modules-sql sasl2-bin libpam-mysql 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		yecho "installing openssl"
		apt-get -q -y install openssl 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		yecho "installing getmail4"
		apt-get -q -y install getmail4 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	  echo "testmail from courier setup" | /usr/bin/mail -s "test mail from courier" "${SSHMAIL}"

		yecho "courier setup" 
		cd /etc/courier
		rm -f /etc/courier/imapd.pem
		rm -f /etc/courier/pop3d.pem
		
		sed -i -r "s/CN=.*/CN=${FQDNNAME}/" /etc/courier/imapd.cnf
		sed -i -r "s/CN=.*/CN=${FQDNNAME}/" /etc/courier/pop3d.cnf
		
		mkimapdcert
		mkpop3dcert
		#/etc/init.d/courier-imap-ssl restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		service courier-imap-ssl restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		#/etc/init.d/courier-pop-ssl restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		service courier-pop-ssl restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

	  break
  ;;	    
  "Done")
      break
      ;;
  *) echo invalid option;;
esac
done

echo "For imap Support choose Courier or Dovecot"
PS3='Choose a MDA: '
select OPT in Courier Dovecot Done
do
case $OPT in
  "Dovecot")
    yecho "installing dovecot-imapd dovecot-pop3d"
	  apt-get -q -y install dovecot-imapd dovecot-pop3d
	  break
  ;;
  "Courier")
		yecho "installing courier-authdaemon courier-authlib-mysql courier-pop courier-pop-ssl courier-imap courier-imap-ssl courier-maildrop"
		apt-get -q -y install courier-authdaemon courier-authlib-mysql courier-pop courier-pop-ssl courier-imap courier-imap-ssl courier-maildrop 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		yecho "installing libsasl2-2 libsasl2-modules libsasl2-modules-sql sasl2-bin libpam-mysql"
		apt-get -q -y install libsasl2-2 libsasl2-modules libsasl2-modules-sql sasl2-bin libpam-mysql 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		yecho "installing openssl"
		apt-get -q -y install openssl 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
		yecho "installing getmail4"
		apt-get -q -y install getmail4 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	  break
  ;;
  "Done")
      break
      ;;
  *) echo invalid option;;
esac
done

#av
yecho "installing clamav clamav-daemon clamav-docs"
apt-get -q -y install clamav clamav-daemon clamav-docs 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
chown -R clamav:clamav /var/log/clamav 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "installing amavisd-new"
apt-get -q -y install amavisd-new 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
yecho "installing spamassassin"
apt-get -q -y install spamassassin 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
yecho "installing zip zoo unzip bzip2 arj nomarch lzop cabextract"
apt-get -q -y install zip zoo unzip bzip2 arj nomarch lzop cabextract 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
yecho "installing apt-listchanges"
apt-get -q -y install apt-listchanges 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)






# 50
# install phpmyadmin or adminer
packages="\"phpmyadmin\" \"adminer\" \"quit\""
echo packages $packages
PS3="Choose which to install: "
eval set $packages
select OPT in "$@"
do
if [ "$OPT" = "quit" ]; then
break;
else
yecho "installing $OPT"
apt-get install -y -q $OPT 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
break;
fi
done

#60
# install ftp server
packages="\"pure-ftpd-common pure-ftpd-mysql\" \"proftpd\" \"quit\""
echo packages $packages
PS3="Choose which to install: "
eval set $packages
select opt in "$@"
do
if [ "$opt" = "quit" ]; then
break;
fi
if [ "$opt" = "pure-ftpd-common pure-ftpd-mysql" ]; then
	yecho "installing $opt"
	apt-get install -y -q $opt 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
break;
fi
if [ "$opt" = "proftpd" ]; then
	yecho "installing $opt"
	apt-get install -y -q $opt 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#/etc/proftpd/proftpd.conf
	#UseIPv6 off
	unescapeandenable "UseIPv6" "/etc/proftpd/proftpd.conf" "\"on\" \"off\"" 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	echo '
	<Global>
	    RequireValidShell off
	</Global>
	
	DefaultRoot ~ ftpusers
	
	<Limit LOGIN>
	    DenyGroup !ftpusers
	</Limit>
	' >> /etc/proftpd/proftpd.conf
	addgroup ftpusers 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	adduser ftpuser -shell /bin/false -home /var/www 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	adduser ftpuser ftpusers 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#/etc/init.d/proftpd restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	service proftpd restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
break;
fi
done

read -p "Install OpenVPN (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#Install OpenVPN 
	apt-get -y -q install openvpn 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

yecho "mysqlsetup"
## check for mysql bind option
CHECK=`grep -e '^bind-address ' /etc/mysql/my.cnf`
if [[ "$CHECK" != "" ]] ; then
sed -i s/^bind-address /#bind-address / /etc/mysql/my.cnf;
fi

#/etc/init.d/mysql restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
service mysql restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#systemctl restart mysql.service




echo '
[mbstring]
mbstring.language = English
mbstring.internal_encoding = UTF-8
mbstring.encoding_translation = On
mbstring.http_input = UTF-8,SJIS,EUC-JP
mbstring.http_output = UTF-8
mbstring.detect_order = UTF-8,ASCII,JIS,SJIS,EUC-JP
mbstring.substitute_character = none
mbstring.func_overload = 0
' >> /etc/php5/conf.d/mbstring-settings.ini

echo '
allow_url_include = Off
allow_url_fopen = Off
session.use_only_cookies = 1
session.cookie_httponly = 1
expose_php = Off
display_errors = Off
register_globals = Off
disable_functions = escapeshellarg, escapeshellcmd, passthru, proc_close, proc_get_status, proc_nice, proc_open,proc_terminate
' >> /etc/php5/conf.d/security.ini

yecho "logrotate setup"
echo '
/var/log/php/php_errors.log {
  weekly
  missingok
  rotate 4
  notifempty
  create
}
' >> /etc/logrotate.d/php



yecho "apache setup (1)"
secureapacherestart actions
secureapacherestart alias
secureapacherestart auth_basic
secureapacherestart auth_digest
secureapacherestart authn_alias
#secureapacherestart authn_anon
#secureapacherestart authn_dbd
#secureapacherestart authn_dbm
#secureapacherestart authn_default
#secureapacherestart authn_file
#secureapacherestart authnz_ldap
#secureapacherestart authz_dbm
#secureapacherestart authz_default
#secureapacherestart authz_groupfile
#secureapacherestart authz_host
#secureapacherestart authz_owner
#secureapacherestart authz_svn
#secureapacherestart authz_user
#secureapacherestart autoindex
#secureapacherestart cache
#secureapacherestart cern_meta
secureapacherestart cgi
secureapacherestart cgid
#secureapacherestart charset_lite
secureapacherestart dav
secureapacherestart dav_fs
#secureapacherestart dav_lock
secureapacherestart dav_svn
#secureapacherestart dbd
secureapacherestart deflate
#secureapacherestart dir
#secureapacherestart disk_cache
#secureapacherestart dump_io
#secureapacherestart env
#secureapacherestart expire
#secureapacherestart expires
#secureapacherestart ext_filter
secureapacherestart fastcgi
secureapacherestart fcgid
#secureapacherestart file_cache
#secureapacherestart filter
secureapacherestart headers
#secureapacherestart ident
#secureapacherestart imagemap
#secureapacherestart include
#secureapacherestart info
#secureapacherestart ldap
#secureapacherestart log_forensic
secureapacherestart mem_cache
secureapacherestart mime
#secureapacherestart mime_magic
#secureapacherestart mod-evasive
#secureapacherestart mod-security
#secureapacherestart mod_mono
#secureapacherestart mod_mono_auto
#secureapacherestart negotiation
secureapacherestart passenger
secureapacherestart perl
secureapacherestart php5
secureapacherestart php5_cgi
#secureapacherestart proxy
#secureapacherestart proxy_ajp
#secureapacherestart proxy_balancer
#secureapacherestart proxy_connect
#secureapacherestart proxy_ftp
#secureapacherestart proxy_http
#secureapacherestart proxy_scgi
secureapacherestart python
#secureapacherestart reqtimeout
secureapacherestart rewrite
secureapacherestart ruby
#secureapacherestart setenvif
#secureapacherestart speling
secureapacherestart ssl
#secureapacherestart status
#secureapacherestart substitute
#secureapacherestart suexec
#secureapacherestart suphp
#secureapacherestart unique_id
#secureapacherestart userdir
#secureapacherestart usertrack
#secureapacherestart vhost_alias

 
#chmod -R 755 /var/www/bla
#chown -R www-data:www-data /var/www/bla
#chown -R www-data:root /var/www/bla
#/etc/suphp/suphp.conf


#/etc/init.d/apache2 restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# better
# systemctl restart apache2.service 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# best
service apache2 restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)


yecho "pure-ftpd setup"
sed -i -r "s/STANDALONE_OR_INETD=.*/STANDALONE_OR_INETD=standalone/" /etc/default/pure-ftpd-common 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/VIRTUALCHROOT=.*/VIRTUALCHROOT=true/" /etc/default/pure-ftpd-common 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

update-rc.d -f exim remove 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
update-inetd --remove daytime 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
update-inetd --remove telnet 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
update-inetd --remove time 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
update-inetd --remove finger 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
update-inetd --remove talk 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
update-inetd --remove ntalk 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
update-inetd --remove ftp 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
update-inetd --remove discard 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#/etc/init.d/openbsd-inetd reload
service openbsd-inetd reload 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

echo 1 > /etc/pure-ftpd/conf/TLS 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
mkdir -p /etc/ssl/private/ 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /etc/ssl/private/pure-ftpd.pem -out /etc/ssl/private/pure-ftpd.pem
chmod 600 /etc/ssl/private/pure-ftpd.pem 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#/etc/init.d/pure-ftpd-mysql restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
service pure-ftpd-mysql restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)



#http://www.howtoforge.com/how-to-run-your-own-dns-servers-primary-and-secondary-with-ispconfig-3-debian-squeeze
#http://www.customvms.de/allgemein/install-bind-9-dns-server-on-debian-wheezy
yecho "installing bind9 dnsutils"
apt-get -q -y install bind9 dnsutils 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep 'version "none";' /etc/bind/named.conf.options ||
sed -i -r "s/^ *\t*options *\t*\{/options \{\nversion \"none\";/g" /etc/bind/named.conf.options
#maybe add recursion no;

grep "${DNNAME}" /etc/bind/named.conf.local || 
echo "zone \"${DNNAME}\" IN {
        type master;
        file \"/etc/bind/zones/${DNNAME}.db\";
        allow-update { none; };
};
" >> /etc/bind/named.conf.local 

mkdir /etc/bind/zones
touch /etc/bind/zones/$DNNAME.db
chown -R bind:bind /etc/bind/zones/$DNNAME.db 

grep "${DNNAME}" /etc/bind/zones/$DNNAME.db ||
echo "$TTL    86400
@               IN SOA  @ ${DNNAME}. (
                                        1              ; serial
                                        2600              ; refresh
                                        15M             ; retry
                                        3600              ; expiry
                                        360 )            ; minimum
@               IN NS           ns.${DNNAME}.
ns              IN A            LOCALIP
www             IN A            LOCALIP
${DNNAME}.             IN A            LOCALIP
${DNNAME}.     IN MX   10      LOCALIP
" > /etc/bind/zones/$DNNAME.db 

#grep '^include "/etc/bind/named.conf.default-zones";' /etc/bind/named.conf ||
#sed -i -r "s/^include \"\/etc\/bind\/named\.conf\.default-zones\";/# include \"\/etc\/bind\/named\.conf\.default-zones\";/g" /etc/bind/named.conf 

#grep '^include "/etc/bind/named.conf.internal-zones";' /etc/bind/named.conf ||
#echo '
#include "/etc/bind/named.conf.internal-zones";
#include "/etc/bind/named.conf.external-zones";
#' >> /etc/bind/named.conf

echo "
    # define for internal section
        view \"internal\" {
                match-clients {
                        localhost;
                        ${NETWORKIP}/${NMASKCIDR};
                };
    # set zone for internal
            zone \"server.world\" {
                    type master;
                    file \"/etc/bind/server.world.lan\";
                    allow-update { none; };
            };
    # set zone for internal *note
            zone \"0.0.10.in-addr.arpa\" {
                    type master;
                    file \"/etc/bind/0.0.10.db\";
                    allow-update { none; };
            };
            include \"/etc/bind/named.conf.default-zones\";
    };
" >  /etc/bind/named.conf.internal-zones 
echo '
    # define for external section
     view "external" {
    # define for external section
            match-clients { any; };
    # allo any query
            allow-query { any; };
    # prohibit recursion
            recursion no;
    # set zone for external

            zone "server.world" {
                    type master;
                    file "/etc/bind/server.world.wan";
                    allow-update { none; };
            };
    # set zone for external *note
            zone "80.0.16.172.in-addr.arpa" {
                    type master;
                    file "/etc/bind/80.0.16.172.db";
                    allow-update { none; };
            };
    };
' > /etc/bind/named.conf.external-zones
sed -i "0,/\/\/=====/i\
# query range you permit \n\
allow-query \{ localhost; ${SERVERIP}\/${NMASKCIDR}; \}; \n\
# the range to transfer zone files \n\
allow-transfer \{ localhost; ${SERVERIP}\/${NMASKCIDR}; \}; \n\
# recursion range you allow \n\
allow-recursion \{ localhost; ${SERVERIP}\/${NMASKCIDR}; \}; \n\
" /etc/bind/named.conf.options 

grep 'allow-recursion' /etc/bind/named.conf.options || 
sed -i "/dnssec-validation auto;/i \
# query range you permit \n\
allow-query \{ localhost; ${SERVERIP}\/${NMASKCIDR}; \}; \n\
# the range to transfer zone files \n\
allow-transfer \{ localhost; ${SERVERIP}\/${NMASKCIDR}; \}; \n\
# recursion range you allow \n\
allow-recursion \{ localhost; ${SERVERIP}\/${NMASKCIDR}; \}; \n\
" /etc/bind/named.conf.options

#/etc/init.d/bind9 restart
service bind9 restart
#bind9-doc

# i considre this no good practice
#Prevent IP Spoofing (adding bad sites to hosts file becomes useless)
#grep 'order bind,hosts' /etc/host.conf || echo 'order bind,hosts' >> /etc/host.conf
#grep 'nospoof on' /etc/host.conf || echo 'nospoof on' >> /etc/host.conf

#Installing Awstats log analyzer
yecho "installing vlogger webalizer awstats"
apt-get -q -y install vlogger webalizer awstats 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)



yecho "jailkit setup"

yecho "installing build-essential autoconf automake1.9 libtool flex bison debhelper"
apt-get -q -y install build-essential autoconf automake1.9 libtool flex bison debhelper 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

cd /tmp 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
wget --no-cookies http://olivier.sessink.nl/jailkit/jailkit-2.16.tar.gz 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
tar xvfz jailkit-2.16.tar.gz 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd jailkit-2.16 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
./debian/rules binary 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
cd .. 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
dpkg -i jailkit_2.16-1_*.deb 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
rm -rf jailkit-2.16* 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "fail2ban setup"
#anti brute force
yecho "installing fail2ban"
apt-get -q -y install fail2ban 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#Do not use /etc/fail2ban/jail.conf, create /etc/fail2ban/jail.local instead
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/ignoreip *=.*/ignoreip = 127\.0\.0\.1 192\.168\.0\.0\/${NMASKCIDR}/g" /etc/fail2ban/jail.local 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/bantime *=.*/bantime  = 600/g" /etc/fail2ban/jail.local 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/maxretry *=.*/maxretry = 3/g" /etc/fail2ban/jail.local 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/destemail *=.*/destemail = ${SSHMAIL}/g" /etc/fail2ban/jail.local 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/enabled *=.*/enabled = true/g" /etc/fail2ban/jail.local 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/action = \%\(action_\)s/action = \%\(action_mwl\)s/g" /etc/fail2ban/jail.local 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep '[courierpop3]' /etc/fail2ban/jail.local ||
echo '
[courierpop3]
enabled = true
port = pop3
filter = courierpop3
logpath = /var/log/mail.log
maxretry = 5

[courierpop3s]
enabled = true
port = pop3s
filter = courierpop3s
logpath = /var/log/mail.log
maxretry = 5

[courierimap]
enabled = true
port = imap2
filter = courierimap
logpath = /var/log/mail.log
maxretry = 5

[courierimaps]
enabled = true
port = imaps
filter = courierimaps
logpath = /var/log/mail.log
maxretry = 5

[webmin]
enabled   = true
port  = 10000,20000
filter= webmin-auth
banaction = iptables-multiport
action= %(action_mwl)s
logpath   = /var/log/auth.log
maxretry  = 5

[apache-badbots]
enabled   = true
port  = http,https
filter= apache-badbots
banaction = iptables-allports
action= %(action_mwl)s
logpath   = /var/log/apache*/*access.log
maxretry  = 5

[apache-nohome]
enabled   = true
port  = http,https
filter= apache-nohome
banaction = iptables-multiport
action= %(action_mwl)s
logpath   = /var/log/apache*/*access.log
maxretry  = 5

[php-url-fopen]
enabled   = true
port  = http,https
filter= php-url-fopen
logpath   = /var/log/apache*/*access.log
maxretry  = 5

[exim]
enabled  = true
filter   = exim
port = smtp,ssmtp
logpath  = /var/log/exim*/rejectlog
maxretry = 5

[apache-w00tw00t]
enabled   = true
port  = http,https
filter= apache-w00tw00t
banaction = iptables-allports
action= %(action_mwl)s
logpath   = /var/log/apache*/*error.log
maxretry  = 5

[apache-myadmin]
enabled   = true
port  = http,https
filter= apache-myadmin
banaction = iptables-allports
action= %(action_mwl)s
logpath   = /var/log/apache*/*error.log
maxretry  = 5

[apache-modsec]
enabled   = true
port      = http,https
filter    = apache-modsec
banaction = iptables-multiport
action    = %(action_mwl)s
logpath   = /var/log/modsecurity/audit.log
maxretry  = 5

[apache-modevasive]
enabled   = true
port      = http,https
filter    = apache-modevasive
banaction = iptables-allports
action    = %(action_mwl)s
logpath   = /var/log/apache*/*error.log
bantime   = 600
maxretry  = 3

[http-get-dos]
enabled = true   
port = http,https
filter = http-get-dos
logpath = /var/log/apache*/*access.log
maxretry = 50    
findtime = 300   
bantime = 6000
action = iptables[name=HTTP, port=http, protocol=tcp]  
         iptables[name=HTTPS, port=https, protocol=tcp]
         sendmail-whois-withline[name=httpd-get-dos, dest=${SSHMAIL}, logpath=/var/log/apache*/*access.log]
         
' >> /etc/fail2ban/jail.local 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

cp /etc/fail2ban/sendmail-whois.conf /etc/fail2ban/sendmail-whois-withlines.conf 
echo'
    actionban = printf %%b "Subject: [Fail2Ban] <name>: banned <ip>
            From: Fail2Ban <<sender>>
            To: <dest>\n
            Hi,\n
            The IP <ip> has just been banned by Fail2Ban after
            <failures> attempts against <name>.\n\n
        Lines containing IP:<ip> in <logpath>\n
            `grep '\<<ip>\>' <logpath>`\n\n
            Here are more information about <ip>:\n
            `/usr/bin/whois <ip>`\n
            Regards,\n
            Fail2Ban" | /usr/sbin/sendmail -f <sender> <dest>
' >> /etc/fail2ban/sendmail-whois-withlines.conf

echo '# Fail2Ban configuration file
#
# $Revision: 100 $
#

[Definition]

# Option: failregex
# Notes.: regex to match the password failures messages in the logfile. The
# host must be matched by a group named "host". The tag "<HOST>" can
# be used for standard IP/hostname matching and is only an alias for
# (?:::f{4,6}:)?(?P<host>\S+)
# Values: TEXT
#
failregex = pop3d: LOGIN FAILED.*ip=\[.*:<HOST>\]

# Option: ignoreregex
# Notes.: regex to ignore. If this regex matches, the line is ignored.
# Values: TEXT
#
ignoreregex =' > /etc/fail2ban/filter.d/courierpop3.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)


echo '# Fail2Ban configuration file
#
# $Revision: 100 $
#

[Definition]

# Option: failregex
# Notes.: regex to match the password failures messages in the logfile. The
# host must be matched by a group named "host". The tag "<HOST>" can
# be used for standard IP/hostname matching and is only an alias for
# (?:::f{4,6}:)?(?P<host>\S+)
# Values: TEXT
#
failregex = pop3d-ssl: LOGIN FAILED.*ip=\[.*:<HOST>\]

# Option: ignoreregex
# Notes.: regex to ignore. If this regex matches, the line is ignored.
# Values: TEXT
#
ignoreregex =' > /etc/fail2ban/filter.d/courierpop3s.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)


echo '# Fail2Ban configuration file
#
# $Revision: 100 $
#

[Definition]

# Option: failregex
# Notes.: regex to match the password failures messages in the logfile. The
# host must be matched by a group named "host". The tag "<HOST>" can
# be used for standard IP/hostname matching and is only an alias for
# (?:::f{4,6}:)?(?P<host>\S+)
# Values: TEXT
#
failregex = imapd: LOGIN FAILED.*ip=\[.*:<HOST>\]

# Option: ignoreregex
# Notes.: regex to ignore. If this regex matches, the line is ignored.
# Values: TEXT
#
ignoreregex =' > /etc/fail2ban/filter.d/courierimap.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)


echo '# Fail2Ban configuration file
#
# $Revision: 100 $
#

[Definition]

# Option: failregex
# Notes.: regex to match the password failures messages in the logfile. The
# host must be matched by a group named "host". The tag "<HOST>" can
# be used for standard IP/hostname matching and is only an alias for
# (?:::f{4,6}:)?(?P<host>\S+)
# Values: TEXT
#
failregex = imapd-ssl: LOGIN FAILED.*ip=\[.*:<HOST>\]

# Option: ignoreregex
# Notes.: regex to ignore. If this regex matches, the line is ignored.
# Values: TEXT
#
ignoreregex =' > /etc/fail2ban/filter.d/courierimaps.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

echo'# Fail2Ban configuration file
#
# Author: Florian Roth

[Definition]
failregex = \[.*?\]\s[\w-]*\s<HOST>\s
ignoreregex =
' > /etc/fail2ban/filter.d/apache-modsec.conf




echo'# Fail2Ban configuration file
#
# Author: Xela
#
# $Revision: 728 $
#

[Definition]

# Option:  failregex
# Notes.:  regex to match the Forbidden log entrys in apache error.log
#  maybe (but not only) provided by mod_evasive
#
# Values:  TEXT
#
failregex = ^\[[^\]]*\]\s+\[error\]\s+\[client <HOST>\] client denied by server configuration:\s

# Option:  ignoreregex
# Notes.:  regex to ignore. If this regex matches, the line is ignored.
# Values:  TEXT
#
ignoreregex =
' > /etc/fail2ban/filter.d/apache-modevasive.conf


echo '# Fail2Ban configuration file
#
# Author: http://www.go2linux.org
#
[Definition]

# Option: failregex
# Note: This regex will match any GET entry in your logs, so basically all valid and not valid entries are a match.
# You should set up in the jail.conf file, the maxretry and findtime carefully in order to avoid false positives.

failregex = ^<HOST> -.*\"(GET|POST).*

# Option: ignoreregex
# Notes.: regex to ignore. If this regex matches, the line is ignored.
# Values: TEXT
#
ignoreregex = ^<HOST> -.*\"(GET|POST).*Googlebot
' > /etc/fail2ban/filter.d/http-get-dos.conf

echo'[Definition]
# Option:  failregex
# Notes.:  regex to match the w00tw00t scan messages in the logfile.
# Values:  TEXT
failregex = ^.*\[client <HOST>\].*w00tw00t\.at\.ISC\.SANS\.DFind.*
# Option: ignoreregex
# Notes.: regex to ignore. If this regex matches, the line is ignored.
# Values: TEXT
ignoreregex =
' > /etc/fail2ban/filter.d/apache-w00tw00t.conf

echo '[Definition]
failregex = ^[[]client <HOST>[]] File does not exist: *myadmin* *\s*$
^[[]client <HOST>[]] File does not exist: *MyAdmin* *\s*$
^[[]client <HOST>[]] File does not exist: *mysqlmanager* *\s*$
^[[]client <HOST>[]] File does not exist: *setup.php* *\s*$
^[[]client <HOST>[]] File does not exist: *mysql* *\s*$
^[[]client <HOST>[]] File does not exist: *phpmanager* *\s*$
^[[]client <HOST>[]] File does not exist: *phpadmin* *\s*$
^[[]client <HOST>[]] File does not exist: *sqlmanager* *\s*$
^[[]client <HOST>[]] File does not exist: *sqlweb* *\s*$
^[[]client <HOST>[]] File does not exist: *webdb* *\s*
ignoreregex =
' > /etc/fail2ban/filter.d/apache-myadmin.conf

#Fail2ban will probably not start after system crash or power loss. In this case:
rm /var/run/fail2ban/fail2ban.sock

#Recommended permanent solution
#-x forces sock deletion, if it exists after abnormal system shutdown.
sed -i -r "s/^ *#? *FAIL2BAN_OPTS *=.*/FAIL2BAN_OPTS=\"-x\"/g" /etc/default/fail2ban 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#/etc/init.d/fail2ban restart  2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
service fail2ban restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#systemctl restart fail2ban.service

#Logs
#/var/log/fail2ban.log 

#Check status:
fail2ban-client status 

#Check status of certain service:
fail2ban-client status ssh 

#Check regex results:
fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf 

#Unblock IP
#using iptables:
#iptables -D fail2ban-<CHAIN_NAME> -s <IP> -j DROP 
#using tcp-wrappers: remove IP from
#nano /etc/hosts.deny 



yecho "apache setup (2)"
echo "AddDefaultCharset off" > /etc/apache2/conf.d/charset 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

grep -i -E 'Listen[[:space:]]+443' /etc/apache2/ports.conf ||
echo "Listen 443" >> /etc/apache2/ports.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#/etc/init.d/apache2 restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
service apache2 restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "setup apticron for autoupdates and notification (${SSHMAIL})"
# autoupdate
yecho "installing apticron"
apt-get -y -q install apticron 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# set notification mail
sed -i -r "s/EMAIL=.*/EMAIL=\"root ${SSHMAIL}\"/g" /etc/apticron/apticron.conf

yecho "setup rkhunter and chkrootkit for rootkit detection and notification (${SSHMAIL})"
# detect rootkits
yecho "installing rkhunter chkrootkit"
apt-get -q -y install rkhunter chkrootkit 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# set notification mail
#nano /etc/rkhunter.conf
sed -i -r "s/MAIL-ON-WARNING=.*/MAIL-ON-WARNING=\"${SSHMAIL}\"/g" /etc/apticron/apticron.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
yecho "checkingfor rootkits..."
chkrootkit
rkhunter --update --quiet --nosummary --lang de 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
rkhunter --propupd --quiet --nosummary --lang de 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
rkhunter --check --quiet --nosummary --lang de 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# whitelist 
#nano /etc/rkhunter.conf
#	ALLOWHIDDENDIR=/dev/.mdadm
#	RTKT_FILE_WHITELIST=/etc/init.d/.depend.boot
#	SCRIPTWHITELIST=/etc/init.d/hdparm
# results
#nano /var/log/rkhunter.log

read -p "Install mono (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	yecho "install mono"
	yecho "uninstalling mono-xsp2 mono-xsp2-base"
	apt-get  -y -q --purge autoremove mono-xsp2 mono-xsp2-base 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	yecho "installing mono-complete mono-apache-server libapache2-mod-mono mono-fastcgi-server"
	apt-get -y -q install mono-complete mono-apache-server libapache2-mod-mono mono-fastcgi-server 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

read -p "Install FreeSWITCH (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	yecho "install FreeSWITCH"
	echo 'deb http://files.freeswitch.org/repo/deb/debian/ wheezy main' >> /etc/apt/sources.list.d/freeswitch.list
	cd /tmp
	curl http://files.freeswitch.org/repo/deb/debian/freeswitch_archive_g0.pub | apt-key add -
	#or
	#gpg --keyserver pool.sks-keyservers.net --recv-key D76EDC7725E010CF
	#gpg -a --export D76EDC7725E010CF | sudo apt-key add -
	apt-cache search freeswitch
	yecho "installing freeswitch-meta-vanilla"
	apt-get install freeswitch-meta-vanilla
	cp -a /usr/share/freeswitch/conf/vanilla /etc/freeswitch
fi

read -p "Install webfonts (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
cd /tmp
wget --no-cookies -O metalmania.woff http://themes.googleusercontent.com/static/fonts/metalmania/v2/_MPduYXiaptg6GQ2M6AHtIbN6UDyHWBl620a-IRfuBk.woff
wget --no-cookies -O lora.woff http://themes.googleusercontent.com/static/fonts/lora/v5/5-AYViExptypIdFoLKAxTA.woff
wget --no-cookies -O opensans.woff http://themes.googleusercontent.com/static/fonts/opensans/v6/cJZKeOuBrn4kERxqtaUH3T8E0i7KZn-EPnyo3HZu7kw.woff
wget --no-cookies -O abrilfatface.woff http://themes.googleusercontent.com/static/fonts/abrilfatface/v5/X1g_KwGeBV3ajZIXQ9VnDvn8qdNnd5eCmWXua5W-n7c.woff
wget --no-cookies -O ubuntu.woff http://themes.googleusercontent.com/static/fonts/ubuntu/v4/_xyN3apAT_yRRDeqB3sPRg.woff
wget --no-cookies -O gabriela.woff http://themes.googleusercontent.com/static/fonts/gabriela/v1/fLaucCvjCt_Hmc9smyo_rPesZW2xOQ-xsNqO47m55DA.woff
wget --no-cookies -O fondamento.woff http://themes.googleusercontent.com/static/fonts/fondamento/v2/bHQyc5zrMLI5-R-me5j-ehsxEYwM7FgeyaSgU71cLG0.woff
wget --no-cookies -O cevicheone.woff http://themes.googleusercontent.com/static/fonts/cevicheone/v3/BQRygZwg3wyGCQXvKfUbSYbN6UDyHWBl620a-IRfuBk.woff
wget --no-cookies -O daysone.woff http://themes.googleusercontent.com/static/fonts/daysone/v3/yfpXiXt9Xp5H97keqlB0t_esZW2xOQ-xsNqO47m55DA.woff

# download the converter
wget --no-cookies https://raw.github.com/hanikesn/woff2otf/master/woff2otf.py

#convert the files
python woff2otf.py metalmania.woff metalmania.ttf
python woff2otf.py lora.woff lora.ttf
python woff2otf.py opensans.woff opensans.ttf
python woff2otf.py abrilfatface.woff abrilfatface.ttf
python woff2otf.py ubuntu.woff ubuntu.ttf
python woff2otf.py gabriela.woff gabriela.ttf
python woff2otf.py fondamento.woff fondamento.ttf
python woff2otf.py cevicheone.woff cevicheone.ttf
python woff2otf.py daysone.woff daysone.ttf
rm *.woff
rm woff2otf.py

# install the fonts
mv ./*.ttf /usr/share/fonts/

# clear the cache
fc-cache -f -v

fi


read -p "Install munin - a server monitoring tool (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	yecho "setup munin munin-node munin-plugins-extra"
	apt-get -q -y install munin munin-node munin-plugins-extra

	# enable some plugins
	cd /etc/munin/plugins
	ln -s /usr/share/munin/plugins/mysql_ mysql_
	ln -s /usr/share/munin/plugins/mysql_bytes mysql_bytes
	ln -s /usr/share/munin/plugins/mysql_innodb mysql_innodb
	ln -s /usr/share/munin/plugins/mysql_isam_space_ mysql_isam_space_
	ln -s /usr/share/munin/plugins/mysql_queries mysql_queries
	ln -s /usr/share/munin/plugins/mysql_slowqueries mysql_slowqueries
	ln -s /usr/share/munin/plugins/mysql_threads mysql_threads 

	yecho "setup munin"
	#nano /etc/munin/munin.conf
	#uncomment the following
	#change domain name
	echo '
	dbdir   /var/lib/munin
	htmldir /var/www/munin
	logdir  /var/log/munin
	rundir  /var/run/munin
	
	tmpldir /etc/munin/templates
	includedir /etc/munin/munin-conf.d

	[munin.customvms.de]
	address 127.0.0.1
	use_node_name yes
	' >> /etc/munin/munin.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	mkdir -p /var/www/munin 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	chown munin:munin /var/www/munin 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	/etc/init.d/munin-node restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#service munin-node restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#config /etc/apache2/conf.d/munin or /etc/munin/apache.conf
	#  Alias /munin /var/cache/munin/www
  #  <Directory /var/cache/munin/www>
  #          Order allow,deny
  #          #Allow from localhost 127.0.0.0/8 ::1
  #          Allow from 192.168.0.0/${NMASKCIDR}
  #          Options None
  #      <IfModule mod_expires.c>
  #          ExpiresActive On
  #          ExpiresDefault M310
  #      </IfModule>
  #
  #  </Directory>
	/etc/init.d/apache2 restart 
	/etc/init.d/munin-node restart

fi

read -p "Install monit (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#http://www.customvms.de/allgemein/install-munin-on-debian-wheezy
	yecho "setup monit for monitoring and restarting services and notification (${SSHMAIL})"
	# autoupdate
	yecho "installing monit"
	apt-get -y -q install monit 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#nano /etc/default/monit
	# set autostart
	sed -i -r "s/startup=.*/startup=1\"/g" /etc/default/monit 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#nano /etc/monit/monitrc
	#Die Datei k�nnte z.B. so aussehen (die // Kommentare sind nur zur Erkl�rung und d�rfen in der Konfigurationsdatei nicht angegeben werden) 
	# set daemon 180                                                 // Monit �berpr�ft all 2 Minuten
	# set logfile syslog facility log_daemon                         // Wo wird die Logdatei hingeschrieben
	# set mailserver localhost                                       // Mailserver �ber den die Mails verschickt werden
	# set mail-format { from: user@domain.tld }                      // Mailadresse Absender
	# set alert user@domain.tld                                      // Empf�nger der Mails
	# 
	# check system localhost                                         // Lokalen Server �berwachen
	#    if loadavg (5min) > 1 then alert                            // Wenn Loadaverage �ber 5 Minuten gr��er 1 ist, Alarm versenden
	#    if memory usage > 75% then alert                            // Wenn mehr als 75% des Speichers ben�tigt werden, Alarm versenden
	#    if cpu usage (user) > 70% then alert                        // Wenn mehr als 70% CPU Leistung ben�tigt wird, Alarm versenden (User)
	#    if cpu usage (system) > 30% then alert                      // Wenn mehr als 30% CPU Leistung ben�tigt wird, Alarm versenden (System)
	#    if cpu usage (wait) > 20% then alert                        // Wenn mehr als 20% CPU Leistung ben�tigt wird, Alarm versenden (Wait)
	# 
	# check process sshd with pidfile /var/run/sshd.pid              // Dienst Mysql durch PID File �berwachen
	#    start program  "/etc/init.d/ssh start"                      // Wie kann SSH im Fehlerfall gestartet werden
	#    stop program  "/etc/init.d/ssh stop"                        // Wie kann SSH im Fehlerfall beendet werden
	#    if failed port 22 protocol ssh then restart                 // Wenn der SSH Dienst nicht l�uft, neu starten
	#    if 5 restarts within 5 cycles then timeout                  // Wenn nach 5 Versuchen der Dienst nicht gestartet werden kann, mit Timeout beenden
	# 
	# check process mysql with pidfile /var/run/mysqld/mysqld.pid    // Dienst Mysql durch PID File �berwachen
	#    group database                                              // Gruppe definieren
	#    start program = "/etc/init.d/mysql start"                   // Wie kann der MySQL Server im Fehlerfall gestartet werden
	#    stop program = "/etc/init.d/mysql stop"                     // Wie kann der MySQL Server im Fehlerfall gestopt werden
	#    if failed host 127.0.0.1 port 3306 then restart             // Wenn Port 3306 (MySql) auf dem Lokalen Server nicht l�uft, neu starten
	#    if 5 restarts within 5 cycles then timeout                  // Wenn nach 5 Versuchen der Dienst nicht gestartet werden kann, mit Timeout beenden
fi

read -p "Install smartmontools (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	 
	echo ''
	#yecho "setup smartmontools for monitoring hdd health status"
	# autoupdate
	#yecho "installing smartmontools"
	#apt-get -y -q install smartmontools 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	# autostart
	#sed -i -r "s/start_smartd=.*/start_smartd=yes\"/g" /etc/default/smartmontools
	#nano /etc/smartd.conf
	#	#uncomment
	#	DEVICESCAN -d removable -n standby -m root -M exec /usr/share/smartmontools/smartd-runner
	#	#add
	#	/dev/sda -n standby -a -I 194 -W 6,50,55 -R 5 -M daily -M test -m user@domain.tld
	#	/dev/sda -n standby -a -I 194 -W 6,50,55 -R 5 -M daily -M test -m user@domain.tld
fi

read -p "Install SELinux (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	apt-get -y -q install selinux-basics selinux-policy-default
	selinux-activate
	#http://debian-handbook.info/browse/wheezy/sect.selinux.html
fi

read -p "Install ddclient - a dyndns client (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	#dyndns client setup
	yecho "installing ddclient"
	apt-get -q -y install ddclient 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	if [[ ! -e /etc/default/ddclient ]]; then
	echo '# Configuration file for ddclient generated by debconf
	#
	# /etc/ddclient.conf
	daemon=60
	pid=/var/run/ddclient.pid
	ssl=yes
	use=web
	protocol=dyndns2
	server=dyndns.strato.com
	login=customvms.de
	password=
	customvms.de
	' > /etc/ddclient.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	fi
	grep 'run_daemon=' /etc/default/ddclient ||
	sed -i -r "s/.*run_daemon=.*/run_daemon=\"true\"/" /etc/default/ddclient 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	grep 'daemon_interval=' /etc/default/ddclient ||
	sed -i -r "s/.*daemon_interval=.*/daemon_interval=\"300\" #5 Minuten/" /etc/default/ddclient 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#check
	ddclient -daemon=0 -debug -verbose -noquiet
fi

read -p "Install java (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	#apt-get install openjdk-6-jdk
	#apt-get install openjdk-7-jdk
	mkdir /opt/java-oracle 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	cd /tmp 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	wget --progress=bar:force --no-cookies --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com" "http://download.oracle.com/otn-pub/java/jdk/7u25-b15/server-jre-7u25-linux-x64.tar.gz" -O "/tmp/server-jre-7u25-linux-x64.tar.gz" 2>&1 | progressfilt
	tar -zxf "/tmp/server-jre-7u25-linux-x64.tar.gz" -C "/opt/java-oracle" 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	# or use /usr/lib/jvm/
	JHome=/opt/java-oracle/jdk1.7.0_25
	update-alternatives --install /usr/bin/java java ${JHome%*/}/bin/java 20000 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	update-alternatives --install /usr/bin/javac javac ${JHome%*/}/bin/javac 20000 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	update-alternatives --config java 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	java -version 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

read -p "Install mailman (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	yecho "installing mailman"
	apt-get -y -q install mailman 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#nano /etc/mailman/mm_cfg.py
	#DEFAULT_MSG_FOOTER for an example."""
	#DEFAULT_URL_PATTERN = 'http://%s/cgi-bin/mailman/'
	#DEFAULT_EMAIL_HOST = 'lists.wefi.net'
	#DEFAULT_URL_HOST   = 'lists.wefi.net'
	#add_virtualhost(DEFAULT_URL_HOST, DEFAULT_EMAIL_HOST)
	#DEFAULT_SERVER_LANGUAGE = 'en'
	#DEFAULT_SEND_REMINDERS = 0
grep -q -e '^mailman:' /etc/aliases || echo '
mailman:              "|/var/lib/mailman/mail/mailman post mailman"
mailman-admin:        "|/var/lib/mailman/mail/mailman admin mailman"
mailman-bounces:      "|/var/lib/mailman/mail/mailman bounces mailman"
mailman-confirm:      "|/var/lib/mailman/mail/mailman confirm mailman"
mailman-join:         "|/var/lib/mailman/mail/mailman join mailman"
mailman-leave:        "|/var/lib/mailman/mail/mailman leave mailman"
mailman-owner:        "|/var/lib/mailman/mail/mailman owner mailman"
mailman-request:      "|/var/lib/mailman/mail/mailman request mailman"
mailman-subscribe:    "|/var/lib/mailman/mail/mailman subscribe mailman"
mailman-unsubscribe:  "|/var/lib/mailman/mail/mailman unsubscribe mailman"
' >> /etc/aliases 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#/etc/init.d/mailman restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

# set some environment variables
yecho "installing bash-completion"
apt-get -q -y install bash-completion 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#uncomment autocomplete section
#nano /etc/bash.bashrc
#interactive login shell configuration
#syste wide /etc/profile - only stuff that should be executed once on login (calls /etc/bash.bashrc)
#per user ~/.bash_profile 
#per user on logout ~/.bash_logout
#interactive non login shell configuration (e.g. bash started in bash, xterm, etc.)
#syste wide /etc/bashrc - for environment varaibles, etc. (called from /etc/profile)
#system wide aliases /etc/aliases
#per user ~/.bashrc 
grep -q '^LANG=' /etc/default/locale || echo 'LANG=de_DE.UTF-8
export LANG' >> /etc/default/locale 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep -q '^LANGUAGE=' /etc/default/locale || echo 'LANGUAGE=de_DE.UTF-8
export LANGUAGE' >> /etc/default/locale 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep -q '^LC_ALL=' /etc/default/locale || echo 'LC_ALL=de_DE.UTF-8
export LC_ALL' >> /etc/default/locale 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
grep -q '^HISTSIZE=' /etc/default/locale || echo 'HISTSIZE=800
export HISTSIZE' >> /etc/default/locale 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/.*force_color_prompt=.*/force_color_prompt=yes/g" /etc/profile || echo 'force_color_prompt=yes' >> /etc/profile 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
sed -i -r "s/.*export LS_OPTIONS=.*/export LS_OPTIONS=\'--color=tty\'/g" /etc/profile || echo 'export LS_OPTIONS="'"--color=tty"'"' >> /etc/profile 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# Add environment variables
grep -q '. /etc/defaul/locale' /etc/profile || # enable it for every user
cat <<EOF >> /etc/profile
if [[ -e /etc/default/locale ]]; then
. /etc/default/locale
fi
EOF

# Add bash auto-completion

# automatically called from /etc/profile.d/bash_completion.sh

# or use

# enable bash completion in interactive login shells
#grep -e '^. /etc/bash_completion' /etc/profile || # enable it for every user
#cat <<EOF >> /etc/profile
## enable bash completion in interactive login shells
#if ! shopt -oq posix; then
#	if [[ -e /etc/bash_completion ]]; then
#	. /etc/bash_completion
#	fi
#fi
#EOF

#add some paths
grep -q '^pathappend' /etc/profile.d/extrapaths.sh ||
cat > /etc/profile.d/extrapaths.sh << "EOF"
pathappend () {
  # First remove the directory
  local IFS=':'
  local NEWPATH
  for DIR in $PATH; do
     if [ "$DIR" != "$1" ]; then
       NEWPATH=${NEWPATH:+$NEWPATH:}$DIR
     fi
  done

  # Then append the directory
  export PATH=$NEWPATH:$1
}
pathprepend () {
  # First remove the directory
  local IFS=':'
  local NEWPATH
  for DIR in $PATH; do
     if [ "$DIR" != "$1" ]; then
       NEWPATH=${NEWPATH:+$NEWPATH:}$DIR
     fi
  done

  # Then append the directory
  export PATH=$1:$NEWPATH
}

if [ -d /usr/local/lib/pkgconfig ] ; then
        pathappend /usr/local/lib/pkgconfig PKG_CONFIG_PATH
fi
if [ -d /usr/local/bin ]; then
        pathprepend /usr/local/bin
fi
if [ -d /usr/local/sbin -a $EUID -eq 0 ]; then
        pathprepend /usr/local/sbin
fi

if [ -d ~/bin ]; then
        pathprepend ~/bin
fi
#if [ $EUID -gt 99 ]; then
#        pathappend .
#fi

#jre
#export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
#jdk
export JAVA_HOME=$(readlink -f /usr/bin/javac | sed "s:/bin/javac::")
export PATH=${PATH}:${JAVA_HOME}/bin
export CLASSPATH=${JAVA_HOME}:${JAVA_HOME}/lib
export ANT_HOME=/path/to/ant/dir
export PATH=${PATH}:${ANT_HOME}/bin:${JAVA_HOME}/bin
export PATH=${PATH}:${HOME}/bin

EOF

# 
grep -q '^export INPUTRC' /etc/profile.d/readline.sh ||
cat > /etc/profile.d/readline.sh << "EOF"
# Setup the INPUTRC environment variable.
if [ -z "$INPUTRC" -a ! -e "$HOME/.inputrc" ] ; then
        INPUTRC=/etc/inputrc
fi
export INPUTRC
EOF

# color for interactive non-login shells
grep -q '${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ ' /etc/bash.bashrc || # enable it for every user
sed -i "s/^PS1=/# PS1=/" /etc/bash.bashrc &&
cat <<EOF >> /etc/bash.bashrc
# color for interactive non-login shells
PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#PAGER=less
PAGER=more
#EDITOR=vi
#EDITOR=emacs
EDITOR=nano
#VISUAL=mg
#VISUAL=vi
VISUAL=nano
EOF

#add dircolors
grep -q -e 'dircolors' /etc/profile.d/dircolors.sh ||
cat > /etc/profile.d/dircolors.sh << "EOF"
# Setup for /bin/ls to support color, the alias is in /etc/bashrc.
if [ ! -e "/etc/dircolors" ] ; then
        eval $(dircolors -b /etc/dircolors)

        if [[ -e "$HOME/.dircolors" ]] ; then
                eval $(dircolors -b $HOME/.dircolors)
        fi
fi
# Color for ls
#export LS_OPTIONS='--color=auto'
export LS_OPTIONS='--color=tty'

EOF
dircolors -p > /etc/dircolors

grep -q -e 'dircolors' /etc/profile.d/umask.sh ||
cat > /etc/profile.d/umask.sh << "EOF"
# By default, the umask should be set.
if [ "$(id -gn)" = "$(id -un)" -a $EUID -gt 99 ] ; then
  umask 002
else
  umask 022
fi
EOF

#nano settings
grep -q -E '^set const' /etc/nanorc  ||
sed -i -r 's/ *\t*#? *\t*set *\t*const.*/set const/g' /etc/nanorc 
#grep -q -E '^set mouse' /etc/nanorc  ||
#sed -i -r 's/ *\t*#? *\t*set *\t*mouse.*/set mouse/g' /etc/nanorc 

# grep -q -e 'dircolors' /etc/profile.d/i18n.sh ||
# cat > /etc/profile.d/i18n.sh << "EOF"
# # Set up i18n variables
# export LANG=<ll>_<CC>.<charmap><@modifiers>
# EOF

#reload profile
. /etc/profile 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
. /etc/bash.bashrc 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

#yecho "setup cpan"
#echo "type exit on success"
#cpan

read -p "Install denyhosts (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
	#ban ssh attackers
	apt-get -q -y install denyhosts
	
	#banned hosts are put here:
	#nano /etc/hosts.deny
	
	#whitelist resides here
	#nano /etc/hosts.allow
	grep -q '^ALL: 192.168.0.' /etc/hosts.allow ||
	echo 'ALL: 192.168.0. #allow local subnet' >> /etc/hosts.allow
	grep -q '^ALL: 127.0.0.1' /etc/hosts.allow ||
	echo 'ALL: 127.0.0.1 #allow localhost' >> /etc/hosts.allow

	#edit config
	#nano /etc/denyhosts.conf
	grep -q "^ADMIN_EMAIL = ${SSHMAIL}" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*ADMIN_EMAIL *\t*=.*/ADMIN_EMAIL = ${SSHMAIL}/g" /etc/denyhosts.conf
	grep -q "^ADMIN_EMAIL = ${SSHMAIL}" /etc/denyhosts.conf ||
	echo "ADMIN_EMAIL = ${SSHMAIL}" >> /etc/denyhosts.conf
	grep -q "^BLOCK_SERVICE = ALL" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*BLOCK_SERVICE *\t*=.*/BLOCK_SERVICE = ALL/g" /etc/denyhosts.conf
	grep -q "^BLOCK_SERVICE = ALL" /etc/denyhosts.conf ||
	echo "BLOCK_SERVICE = ALL" >> /etc/denyhosts.conf
	grep -q "^DENY_THRESHOLD_INVALID = 5" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*DENY_THRESHOLD_INVALID *\t*=.*/DENY_THRESHOLD_INVALID = 5/g" /etc/denyhosts.conf
	grep -q "^DENY_THRESHOLD_INVALID = 5" /etc/denyhosts.conf ||
	echo "DENY_THRESHOLD_INVALID = 5" >> /etc/denyhosts.conf
	grep -q "^DENY_THRESHOLD_RESTRICTED = 1" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*DENY_THRESHOLD_RESTRICTED *\t*=.*/DENY_THRESHOLD_RESTRICTED = 1/g" /etc/denyhosts.conf
	grep -q "^DENY_THRESHOLD_RESTRICTED = 5" /etc/denyhosts.conf ||
	echo "DENY_THRESHOLD_RESTRICTED = 5" >> /etc/denyhosts.conf
	grep -q "^DENY_THRESHOLD_ROOT = 1" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*DENY_THRESHOLD_ROOT *\t*=.*/DENY_THRESHOLD_ROOT = 1/g" /etc/denyhosts.conf
	grep -q "^DENY_THRESHOLD_ROOT = 5" /etc/denyhosts.conf ||
	echo "DENY_THRESHOLD_ROOT = 5" >> /etc/denyhosts.conf
	grep -q "^DENY_THRESHOLD_VALID = 10" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*DENY_THRESHOLD_VALID *\t*=.*/DENY_THRESHOLD_VALID = 10/g" /etc/denyhosts.conf
	grep -q "^DENY_THRESHOLD_VALID = 10" /etc/denyhosts.conf ||
	echo "DENY_THRESHOLD_VALID = 10" >> /etc/denyhosts.conf
	grep -q "^HOSTNAME_LOOKUP = YES" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*HOSTNAME_LOOKUP *\t*=.*/HOSTNAME_LOOKUP = YES/g" /etc/denyhosts.conf
	grep -q "^HOSTNAME_LOOKUP = YES" /etc/denyhosts.conf ||
	echo "HOSTNAME_LOOKUP = YES" >> /etc/denyhosts.conf
	grep -q "^SMTP_FROM = DenyHosts nobody@localhost" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*SMTP_FROM *\t*=.*/SMTP_FROM = DenyHosts nobody@localhost/g" /etc/denyhosts.conf
	grep -q "^SMTP_FROM = DenyHosts nobody@localhost" /etc/denyhosts.conf ||
	echo "SMTP_FROM = DenyHosts nobody@localhost" >> /etc/denyhosts.conf
	grep -q "^SMTP_HOST = localhost" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*SMTP_HOST *\t*=.*/SMTP_HOST = localhost/g" /etc/denyhosts.conf
	grep -q "^SMTP_HOST = localhost" /etc/denyhosts.conf ||
	echo "SMTP_HOST = localhost" >> /etc/denyhosts.conf
	grep -q "^SMTP_PORT = 25" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*SMTP_PORT *\t*=.*/SMTP_PORT = 25/g" /etc/denyhosts.conf
	grep -q "^SMTP_PORT = 25" /etc/denyhosts.conf ||
	echo "SMTP_PORT = 25" >> /etc/denyhosts.conf
	grep -q "^SMTP_SUBJECT = DenyHosts Report from ${FQDNNAME}" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*#? *\t*SMTP_SUBJECT *\t*=.*/SMTP_SUBJECT = DenyHosts Report from ${FQDNNAME}/g" /etc/denyhosts.conf
	grep -q "^SMTP_SUBJECT = DenyHosts Report from ${FQDNNAME}" /etc/denyhosts.conf ||
	echo "SMTP_SUBJECT = DenyHosts Report from ${FQDNNAME}" >> /etc/denyhosts.conf
	grep -q "^# SMTP_PASSWORD =" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*# *\t*SMTP_PASSWORD *\t*=.*/# SMTP_PASSWORD =/g" /etc/denyhosts.conf
	grep -q "^# SMTP_PASSWORD =" /etc/denyhosts.conf ||
	echo "# SMTP_PASSWORD =" >> /etc/denyhosts.conf
	grep -q "^# SMTP_USERNAME =" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*# *\t*SMTP_USERNAME *\t*=.*/# SMTP_USERNAME =/g" /etc/denyhosts.conf
	grep -q "^# SMTP_USERNAME =" /etc/denyhosts.conf ||
	echo "# SMTP_USERNAME =" >> /etc/denyhosts.conf
	grep -q "^# SYSLOG_REPORT = YES" /etc/denyhosts.conf ||
	sed -i -r "s/ *\t*# *\t*SYSLOG_REPORT *\t*=.*/# SYSLOG_REPORT = YES/g" /etc/denyhosts.conf
	grep -q "^# SYSLOG_REPORT = YES" /etc/denyhosts.conf ||
	echo "# SYSLOG_REPORT = YES" >> /etc/denyhosts.conf
	
	#restart
	#/etc/init.d/denyhosts restart
	service denyhosts restart
fi

read -p "Install virtualbox (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
	#install virtualbox needs X11
	#https://wiki.debian.org/VirtualBox#Debian_7_.22Wheezy.22
	#yecho "installing linux-headers virtualbox"
	#apt-get -q -y install linux-headers-$(uname -r|sed 's,[^-]*-[^-]*-,,') virtualbox
	# do not load on startup
	#sed -i -r "s/^LOAD_VBOXDRV_MODULE=.*/LOAD_VBOXDRV_MODULE=0/" /etc/default/virtualbox
	# or add 
	#deb http://download.virtualbox.org/virtualbox/debian wheezy contrib
	#cd /tmp
	#wget --no-cookies -q http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc -O- | sudo apt-key add -
	#apt-get update
	#apt-get -q -y install virtualbox-4.2
	#ensure updating on kernel update
	# apt-get -q -y install dkms
fi

read -p "Install lxc (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
	#yecho "installing lxc"
	#apt-get install lxc
	#mkdir /cgroup
	#echo 'cgroup /cgroup cgroup defaults 0 0' >> /etc/fstab
	#mount -a
	#lxc-checkconfig
	#echo 1 > /proc/sys/net/ipv4/ip_forward
	#sed -i -r "s/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/" /etc/sysctl.conf
	#sysctl -p /etc/sysctl.conf
	#use debootstrap, lcx-create etc to create containers
	#http://www.buildcube.com/tech_blog/2013/05/06/wheezy-is-out-so-is-openvz-but-lxc-seems-to-be-in/
fi

read -p "Install apt-cacher - a repository cache (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
	# install apt-cacher (repository cache)
	#yecho "installing apt-cacher"
	#apt-get -q -y install apt-cacher
	#/etc/init.d/apache restart
	# http://cacheserver/apt-cacher
	#add cache server url on clients like
	#deb http://cacheserver/apt-cacher/ftp.de.debian.org/debian stable main contrib non-free
fi

read -p "Install samba (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
	#samba
	#http://www.thomas-krenn.com/de/wiki/Einfache_Samba_Freigabe_unter_Debian
	#http://www.howtoforge.com/setting-up-a-standalone-storage-server-with-glusterfs-and-samba-on-debian-squeeze-p3
	#http://www.howtoforge.com/setting-up-a-linux-file-server-using-samba
fi

read -p "Install subversion (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
	#subversion
	#http://www.thomas-krenn.com/de/wiki/Subversion_unter_Debian_mit_Webaccess
fi

read -p "Install puppet (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
	#puppet
	#https://library.linode.com/application-stacks/puppet/installation
fi

read -p "Install node.js and npm (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	apt-get -y -q install python g++ make checkinstall
	#mkdir ~/src && cd $_
	cd /tmp
	wget -N http://nodejs.org/dist/node-latest.tar.gz
	tar xzvf node-latest.tar.gz 
	#removes the "v" in front of the version number in the dialog
	rename 's/node-v/node-/g' node-v*   
	cd node-*
	./configure
	checkinstall
	dpkg -i node_*
	
	#In case you get a permission denied on the node executable, an alternative path might be:
	#umask 0022
	#./configure
	#make
	#checkinstall -D --umask 0022 --reset-uids --install=no
	#dpkg -i node_*.deb
	
	#Uninstall:
	#dpkg -r node
fi


read -p "Install logwatch - a log analysis system (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	#logwatch
	yecho "installing logwatch libdate-manip-perl"
	apt-get -q -y install logwatch 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	mkdir /var/cache/logwatch 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	cp /usr/share/logwatch/default.conf/logwatch.conf /etc/logwatch/conf/
	#nano /usr/share/logwatch/default.conf/logwatch.conf
	sed -i -r "s/^Output =.*$/Output = mail/" /etc/logwatch/conf/logwatch.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	sed -i -r "s/^Format =.*$/Format = text/" /etc/logwatch/conf/logwatch.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	sed -i -r "s/^MailTo =.*$/MailTo = ${SSHMAIL}/" /etc/logwatch/conf/logwatch.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	sed -i -r "s/^Detail =.*$/Detail = High/" /etc/logwatch/conf/logwatch.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	sed -i -r "s/^Service =.*$/Service = All/" /etc/logwatch/conf/logwatch.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	# default: /usr/sbin/logwatch --output mail
	sed -i -r "s/^\/usr\/sbin\/logwatch .*$/\/usr\/sbin\/logwatch --mailto ${SSHMAIL} --format html/g" /etc/cron.daily/00logwatch 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

read -p "Install Ajenti (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	yecho "installing python-requests"
	apt-get -q -y install python-requests 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	yecho "adding key and http://repo.ajenti.org/ng/debian repository"
	wget --no-cookies http://repo.ajenti.org/debian/key -O- | apt-key add -
	grep 'http://repo.ajenti.org/ng/debian' /etc/apt/sources.list ||
	echo 'deb http://repo.ajenti.org/ng/debian main main debian' >> /etc/apt/sources.list
	apt-get -q -y update  2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	yecho "installing ajenti"
	apt-get -q -y install ajenti 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	service ajenti restart
fi

read -p "Install Zpanel (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
fi

read -p "Install libvirt + kvm (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	echo ''
	#todo
	#http://virtuallyhyper.com/2012/07/installing-kvm-as-a-virtual-machine-on-esxi5-with-bridged-networking/
	#libvirt + kvm
	#for libvirt + xen read
	#https://wiki.debian.org/libvirt/xen
	#test if available
	egrep -c -q '(vmx|svm)' /proc/cpuinfo &&
	yecho "installing logwatch qemu-kvm libvirt-bin qemu bridge-utils virt-viewer virt-manager virtinst virt-top" &&
	apt-get -y -q install qemu-kvm libvirt-bin qemu bridge-utils virt-viewer virt-manager virtinst virt-top &&
	#add non root user to use kvm
	#usermod -a -G kvm `id -un` &&	
	#add current user to libvirtd group
	#groupadd libvirtd
	#usermod -a -G libvirtd `id -un` &&
	#usermod -a -G kvm `id -un` &&
	#check
	virsh -c qemu:///system list | grep -v error && 
	#virsh -c qemu:///system sysinfo |head -n 1
	#kvm
	#add network bridge
	echo 'auto br0
	iface br0 inet static
	        address ${SERVERIP}
	        netmask ${NMASKIP}
	        network 192.168.0.0
	        broadcast ${BCASTIP}
	        gateway 192.168.0.1
	        bridge_ports eth0
	        bridge_stp off
	        bridge_fd 0
	        bridge_maxwait 0
	' >> /etc/network/interfaces &&
	service networking restart
	
	#enale KVM on ESXi 5.0
	#ssh into esxi
	#echo 'vhv.allow = "TRUE"' >> /etc/vmware/config
	#echo 'monitor.virtual_mmu = "hardware"
	#monitor.virtual_exec = "hardware"
	#hypervisor.cpuid.v0 = "FALSE"
	#cpuid.1.ecx = "----:----:----:----:----:----:--h-:----"
	#cpuid.80000001.ecx.amd = "----:----:----:----:----:----:----:-h--"
	#cpuid.8000000a.eax.amd = "hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh"
	#cpuid.8000000a.ebx.amd = "hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh"
	#cpuid.8000000a.edx.amd = "hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh"
	#vcpu.hotadd = "FALSE"
	#vhv.enable = "TRUE" 
	#hypervisor.cpuid.v0 = "FALSE"' >> "/vmfs/volumes/datastore1/Some VM/Some VM.vmx"

fi

#Supervisor

#Squid 3

#lm-sensors 

#Firewall (Linux Firewall, BSD Firewall, IPFilter) 

#CTDB

#Netatalk
#http://netatalk.sourceforge.net/wiki/index.php/Install_Netatalk_3.0.5_on_Debian_7_Wheezy

#PostgreSQL

#Sendmail

# Install git (and ssh)
#http://www.customvms.de/test-configuration-debian/install-git-and-ssh-on-debian-wheezy

#Install psad (iptables log analyze based security tool)
read -p "Install psad (iptables log analyze based security tool) (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	#manual
	#mkdir /tmp/.psad
	#cd /tmp/.psad
	#wget http://cipherdyne.org/psad/download/psad-2.2.tar.gz
	#tar -zxvf psad-2.2.tar.gz
	#cd psad-2.2
	#./install.pl 
	#cd /tmp
	#rm -R .psad
	#exit

	#Install psad (iptables log analyze based security tool)
	#http://www.customvms.de/allgemein/install-psad-iptables-log-analyze-based-security-tool-on-debian-wheezy
	#psad analyze iptables log messages to detect port scans and other suspicious traffic.
	apt-get -y -q install psad
	sed -i -r "s/^ *\t*#? *\t*EMAIL_ADDRESSES .*/EMAIL_ADDRESSES ${SSHMAIL}\;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*HOSTNAME .*/HOSTNAME ${DNNAME}\;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*HOME_NET .*/HOME_NET NOT_USED;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*IPT_SYSLOG_FILE .*/IPT_SYSLOG_FILE \/var\/log\/kern\.log\;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*EMAIL_LIMIT_STATUS_MSG .*/EMAIL_LIMIT_STATUS_MSG N\;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*ENABLE_AUTO_IDS .*/ENABLE_AUTO_IDS Y\;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*AUTO_IDS_DANGER_LEVEL .*/AUTO_IDS_DANGER_LEVEL 3\;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*AUTO_BLOCK_TIMEOUT .*/AUTO_BLOCK_TIMEOUT 86400\;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*ENABLE_AUTO_IDS_EMAILS .*/ENABLE_AUTO_IDS_EMAILS N\;/g" /etc/psad/psad.conf 
	sed -i -r "s/^ *\t*#? *\t*mailCmd .*/mailCmd \/usr\/bin\/mail\;/g" /etc/psad/psad.conf  
	#systemctl restart psad.service
	grep "${SERVERIP}" /etc/psad/auto_dl ||
	echo "
    127.0.0.1       0;          # Server IP.
    ${SERVERIP}       0;          # Server IP.
    192.168.0.0/${NMASKCIDR}    0;
	" >> /etc/psad/auto_dl
	cd /tmp
	#write out current crontab
	crontab -l > mycron
	#echo new cron into cron file
	A='@weekly /usr/sbin/psad --sig-update && /usr/sbin/psad -H | mail -s \"psad signatures updated on'
	B='# Weekly update of psad signatures' 
	grep -q 'weekly /usr/sbin/psad' mycron ||
	echo "${A} ${FQDNNAME}\" ${SSHMAIL} ${B}"  >> mycron
	#install new cron file
	crontab mycron
	rm mycron
	
	#check if rule exists before adding
  iptables -C INPUT -j LOG | grep -q 'Bad rule\|No chain/target/match by that name' ||
	iptables -A INPUT -j LOG
  iptables -C FORWARD -j LOG | grep -q 'Bad rule\|No chain/target/match by that name' ||	
	iptables -A FORWARD -j LOG
  ip6tables -C INPUT -j LOG | grep -q 'Bad rule\|No chain/target/match by that name' ||	
	ip6tables -A INPUT -j LOG
  ip6tables -C FORWARD -j LOG | grep -q 'Bad rule\|No chain/target/match by that name' ||	
	ip6tables -A FORWARD -j LOG

	psad -R
	psad --sig-update
	psad -H

	service psad resart
	
	psad --Status
	
	#some commands
	# psad output:
	#psad -S 
	# remove automatically blocked ip:
	#psad --fw-rm-block-ip <ip> 
	# remove automatically blocked ips:
	#psad -F 
	# update signatures:
	#psad --sig-update && psad -H 
	# test psad from another machine
	#nmap -sX <serverip>
fi

#Install Asterisk and FreePBX 
#http://www.customvms.de/test-configuration-debian/install-asterisk-and-freepbx-on-debian-wheezy

#!/bin/bash
read -p "Install PHP Tools (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	apt-get -y -q install php-pear php5-intl 
	#php5-dev libpcre3-dev 
	pear channel-update pear.php.net
	pear upgrade PEAR	
	
	#apt-get -y -q install apache2-prefork
	

	#pecl channel-update pecl.php.net
	
	apt-get -y -q install curl
	curl -s https://getcomposer.org/installer | php -d allow_url_fopen=On
	mv composer.phar /usr/local/bin/composer
	
	pecl install xdebug
	#zend_extension=xdebug.so
fi

read -p "Install NFSD (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
#Install NFSD 
	apt-get -q -y install nfs-kernel-server 

	grep -E "^Domain *= *${DNNAME}" /etc/idmapd.conf ||
	sed -i -r "s/^ *#? *Domain *=.*/Domain = ${DNNAME}/g" /etc/idmapd.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	grep -E "^Domain = ${DNNAME}" /etc/idmapd.conf ||
	echo "Domain = ${DNNAME}" >> /etc/idmapd.conf 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

	grep -E "^\/home ${SERVERIP}\/${NMASKCIDR}\(rw,sync,fsid=0,no_root_squash,no_subtree_check\)" /etc/exports ||
	sed -i -r "s/^ *#? *\/home ${SERVERIP}.*/\/home ${SERVERIP}\/${NMASKCIDR}\(rw,sync,fsid=0,no_root_squash,no_subtree_check\)/g" /etc/exports 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	grep -E "^\/home ${SERVERIP}\/${NMASKCIDR}\(rw,sync,fsid=0,no_root_squash,no_subtree_check\)" /etc/exports ||
	echo "/home ${SERVERIP}/${NMASKCIDR}(rw,sync,fsid=0,no_root_squash,no_subtree_check)" >> /etc/exports 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

	#/home = shared directory
	#${NETWORKIP}/${NMASKCIDR} = range of networks NFS permits accesses
	#rw = possible to read and write
	#sync = synchronize
	#no_root_squash = enable root privilege
	#no_subtree_check = disable subtree check
	
	#/etc/init.d/nfs-kernel-server restart 
	service nfs-kernel-server restart
fi

read -p "Install update-manager-core (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	#updatemanager
	yecho "installing update-manager-core"
	apt-get -y -q install update-manager-core
	do-release-upgrade
fi

read -p "Install unattended-upgrades (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	#autoupdate
	yecho "installing unattended-upgrades"
	apt-get -y -q install unattended-upgrades
	#/etc/apt/apt.conf.d/50unattended-upgrades
	#log
	#add logrotate /var/log/unattended-upgrades
	#add crone job /usr/bin/unattended-upgrade
fi

read -p "force strong passwords (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then	
	#force strong passwords
	yecho "installing libpam-cracklib"
	apt-get -y -q install libpam-cracklib
	/usr/share/pam/common-password
	#add dictionaries
	/etc/cracklib/cracklib.conf
	/etc/pam.d/common-password
	password        required                        pam_permit.so
	#require the user to select a password with a minimum length of 10 and with at least 1 digit numbers, 1 upper case letter, and 1 other character, at least 3 charactes must be different from the last password. The user is only given 2 opportunities to enter a strong password and the password can't contain the user name
	# may needs to be iserted before password requisite pam_deny.so
	grep 'pam_cracklib.so' /etc/pam.d/common-password || echo '
	password requisite pam_cracklib.so retry=3 difok=3 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=0 minlen=10 reject_username
	' >> /etc/pam.d/common-password
fi

#todo
#http://www.thefanclub.co.za/how-to/how-secure-ubuntu-1204-lts-server-part-1-basics

http://openbook.galileocomputing.de/shell_programmierung/shell_007_007.htm

#http://www.customvms.de/apache-configuration/htaccess-backup-version-please-review
#http://www.customvms.de/apache-configuration/htaccess
#http://www.customvms.de/test-configuration-debian/install-andconfigure-iptables-firewall-on-debian-wheezy
#php

#http://www.howtoforge.com/setting-up-a-spam-proof-home-email-server-the-somewhat-alternate-way-debian-squeeze-p2
#http://www.howtoforge.com/setting-up-a-spam-proof-home-email-server-the-somewhat-alternate-way-debian-squeeze-p3
#http://www.howtoforge.com/setting-up-a-spam-proof-home-email-server-the-somewhat-alternate-way-debian-squeeze-p4

#https://speakerdeck.com/futureshocked/a-linux-server-administration-tutorial-for-beginners
#page 17

#http://www.debian.org/doc/manuals/debian-reference/ch04.en.html
#http://www.debian.org/doc/manuals/securing-debian-howto/ch4.en.html
#disable user
#passwd -l username
#enable user
#passwd -u username
#add user
#adduser username
#delete user 
#deluser username usergroup
#addgroup usergroup
#delgrou usergroup

read -p "Install icinga-web (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#install icinga system monitoring
	yecho "installing icinga-web"
	apt-get -y -q install icinga icinga-cgi icinga-core icinga-doc icinga-idoutils
	apt-get -y -q install nagios-plugins
	#Enable ido2db Daemon

	grep -q -E '^check_external_commands=1' /etc/default/icinga ||
	sed -i -r "s/ *\t*#? *\t*IDO2DB *\t*=.*/IDO2DB=yes/g" /etc/default/icinga
 
	# service ido2db restart

	#In order to check the enabled status on ido2db startup, use
	# sh -x /etc/init.d/ido2db start | grep IDO2DB

  if [ ! -e /etc/icinga/modules/idoutils.cfg ]
	then
		cp /usr/share/doc/icinga-idoutils/examples/idoutils.cfg-sample /etc/icinga/modules/idoutils.cfg
	fi
	#service icinga restart

	#Enable external commands
	grep -q -E '^check_external_commands=1' /etc/icinga/icinga.cfg ||
	sed -i -r "s/ *\t*#? *\t*check_external_commands *\t*=.*/check_external_commands=1/g" /etc/icinga/icinga.cfg
 
	service icinga stop
	dpkg-statoverride --update --add nagios www-data 2710 /var/lib/icinga/rw
	dpkg-statoverride --update --add nagios nagios 751 /var/lib/icinga
	service icinga restart

	# The authorization is stored within  /etc/icinga/htpasswd.users  
	# new users can be added with the following command
	#htpasswd /etc/icinga/htpasswd.users youradmin
fi

read -p "Install l7-protocols (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	echo ''
	#modprobe ip_conntrack_netlink
	#modprobe nf_conntrack_ipv4
	#apt-get -y -q install l7-filter-userspace l7-protocols
	#cp /usr/share/doc/l7-filter-userspace/examples/sample-l7-filter.conf /etc/l7-filter.conf
	#l7-filter -f /etc/l7-filter.conf -q 2 -v
	#iptables -t mangle -A PREROUTING -j NFQUEUE --queue-num 2
	#iptables -t mangle -A OUTPUT -j NFQUEUE --queue-num 2
	#http://l7-filter.sourceforge.net/protocols
fi

read -p "Install shorewall (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	#Shorewall(+Webmin)
	apt-get -y -q install shorewall
	grep -q -E '^startup = 1' /etc/default/shorewall ||
	sed -i -r "s/ *\t*#? *\t*startup *\t*=.*/startup = 1/g" /etc/default/shorewall
	if [ ! -e /etc/shorewall ]
	then
		cp /usr/share/doc/shorewall/default-config /etc/shorewall 
	fi
	#https://wiki.debian.org/HowTo/shorewall
fi

read -p "Install fwbuilder (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	apt-get -q -y install fwbuilder fwbuilder-ipt
fi

#ARP NDP setup
#echo '#!/bin/sh
#arp -i eth0 -s 192.0.2.1 00:XX:0C:XX:DD:C1
#' > /etc/network/if-up.d/add-my-static-arp
#chmod +x /etc/network/if-up.d/add-my-static-arp



### Changes to Grub and Kernel

#Install ExecShield
#read -p "Install ExecShield (y/n) [no]? " -n 1 REPLY
#if [[ $REPLY =~ ^[YyjJ]$ ]]
#then
#Enable ExecShield
#sysctl -w kernel.exec-shield=1 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#enabled by default in wheezy
#fi

#apt-get -y -q install secure-delete 
#sfill -l -l -v / 
#sfill -v /
#srm (deleting a file), 
#smem (erasing the memory), 
#sswap (erasing the swap file).

read -p "Install webmin (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	apt-get -y -q install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl
	yecho 'adding key and dependencies'
	grep 'http://download.webmin.com/download/repository' /etc/apt/sources.list ||
	echo '
	deb http://download.webmin.com/download/repository sarge contrib
	deb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib
	' >> /etc/apt/sources.list
	cd ~/
	wget --no-cookies -q http://www.webmin.com/jcameron-key.asc -O- |	apt-key add -
	apt-get -q -y update 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	apt-get -q -y upgrade 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	yecho "installing webmin"
	apt-get -q -y install webmin 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

	#or for the latest use
	# Install dependencies
	#apt-get -q -y install libapt-pkg-perl perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python
	#wget --no-cookies -q http://prdownloads.sourceforge.net/webadmin/webmin_1.650_all.deb
	#dpkg -i webmin_1.650_all.deb
	#apt-get -q -y install -f
	#The install will be done automatically to /usr/share/webmin, the administration username set to root and the password to your current root password. You should now be able to login to Webmin at the URL http://localhost:10000/. Or if accessing it remotely, replace localhost with your system's IP address. 

	#check if rule exists before adding
	iptables -C INPUT -p tcp -m tcp --dport 10000 -j ACCEPT | grep -q 'Bad rule\|No chain/target/match by that name' || 
  iptables -A INPUT -p tcp -m tcp --dport 10000 -j ACCEPT -m comment --comment "firewall rule for webmin"
	

	
	#install module virtualmin
	cd /tmp
	wget http://software.virtualmin.com/gpl/scripts/install.sh
	chmod +x install.sh
  ./install.sh
  #or
  #cd /tmp
  #wget http://download.webmin.com/download/virtualmin/webmin-virtual-server_4.02.gpl_all.deb
  #wget http://download.webmin.com/download/virtualmin/webmin-virtual-server-theme_8.8_all.deb
  #dpkg --install webmin-virtual-server_4.02.gpl_all.deb
  #dpkg --install webmin-virtual-server-theme_8.8_all.deb
  
  #install usermin
  grep -q 'http://download.webmin.com/download/repository' /etc/apt/sources.list ||
  echo 'deb http://download.webmin.com/download/repository sarge contribYou will now be able to install with the command : apt-get update' >> /etc/apt/sources.list
	apt-get update
	apt-get -q -y install usermin
	#or
  #cd /tmp
  #wget http://prdownloads.sourceforge.net/webadmin/usermin_1.560_all.deb
  #dpkg --install usermin_1.560_all.deb
  #The install will be done automatically to /usr/share/usermin. You should now be able to login at http://localhost:20000 as any user on your system.

	#install cloudmin for xen
	#cd /tmp
	#wget http://cloudmin.virtualmin.com/gpl/scripts/cloudmin-gpl-debian-install.sh
	#chmod +x cloudmin-gpl-debian-install.sh
	#./cloudmin-gpl-debian-install.sh
	#install cloudmin for kvm
	cd /tmp
	wget http://cloudmin.virtualmin.com/gpl/scripts/cloudmin-kvm-debian-install.sh
	chmod +x cloudmin-kvm-debian-install.sh
	./cloudmin-kvm-debian-install.sh
	
	#http://www.niemueller.de/webmin/modules/iptables/iptables-0.85.1-ALPHA.wbm.gz
	#http://www.webmin.com/webmin/download/modules/iscsi-client.wbm.gz
	#http://www.webmin.com/webmin/download/modules/iscsi-server.wbm.gz
	#http://update.intellique.com/pub/iscsitarget-0.9.5.wbm
	#http://www.webmin.com/webmin/download/modules/krb5.wbm.gz
	#http://www.webmin.com/webmin/download/modules/ldap-client.wbm.gz
	#http://www.webmin.com/webmin/download/modules/ldap-server.wbm.gz
	#http://download.sourceforge.net/ldap-users/ldap-users-0-0-2pre.wbm
	#http://www.webmin.com/webmin/download/modules/ldap-useradmin.wbm.gz
	#http://prdownloads.sourceforge.net/ldap-browser/ldap_browser_0.0.2.wbm?download
	#http://www.webmin.com/webmin/download/modules/firewall.wbm.gz
	#http://prdownloads.sourceforge.net/mailman-mod/mailman-module.wbm?download
	#http://download.webmin.com/download/modules/memcached.wbm.gz
	#http://www.tslab.ssvl.kth.se/csd/projects/0821116/sites/default/files/NagiosModule.wbm
	#http://opensource.digisec.de/webmin/nessus.wbm
	#http://www.justindhoffman.com/sites/justindhoffman.com/files/nginx-0.06.wbm_.gz
	#http://gaia.anet.fr/webmin/openldap/openldap-0_6.wbm
	#http://www.algonet.se/~beutner/apps/openldap2-0_4_3.wbm
	#http://www.openit.it/downloads/OpenVPNadmin/openvpn-2.6.wbm.gz
	#http://www.webmin.com/webmin/download/modules/pam.wbm.gz
	#http://www.webmin.com/webmin/download/modules/cpan.wbm.gz
	#http://www.webmin.com/webmin/download/modules/phpini.wbm.gz
	#http://www.webmin.com/download/modules/php-pear.wbm.gz
	#http://www.nltechno.com/files/phpmyadmin-1.1.wbm
	#http://www.webmin.com/webmin/download/modules/postfix.wbm.gz
	#http://www.webmin.com/webmin/download/modules/procmail.wbm.gz
	#http://www.webmin.com/webmin/download/modules/proftpd.wbm.gz
	#http://www.lashampoo.com/unix/pureftpd.wbm
	#http://www.webmin.com/webmin/download/contrib/qmail.wbm
	#http://www.webmin.com/webmin/download/modules/qmailadmin.wbm.gz
	#http://sourceforge.net/projects/qmailwebmin
	#http://www.webmin.com/webmin/download/modules/samba.wbm.gz
	#http://www.webmin.com/webmin/download/modules/cron.wbm.gz
	#http://www.webmin.com/webmin/download/modules/sendmail.wbm.gz
	#http://www.webmin.com/webmin/download/modules/shorewall.wbm.gz
	#http://www.webmin.com/webmin/download/modules/shorewall6.wbm.gz
	#https://sourceforge.net/project/showfiles.php?group_id=56757
	#http://www.webmin.com/webmin/download/modules/spam.wbm.gz
	#http://sourceforge.net/projects/webmin/files/SVN_Admin/V1.3.2/svnadmin.wbm.gz
	#http://perso.nintendojo.fr/~mortal/virt-manager.tar.gz
	#http://virt-manager.googlecode.com/files/virt-manager-02SB.tar.gz
	#http://sourceforge.net/projects/webmin/files/VboxCtrl/V4.0.5.1/vboxmanager_4051.wbm.gz
	#http://provider4u.de/downloads.html
	#http://labs.libre-entreprise.org/frs/download.php/892/wbmclamav-0.15.wbm.gz
	#http://www.webmin.com/webmin/download/modules/webalizer.wbm.gz
	#http://downloads.sourceforge.net/project/awstats/AWStats%20Webmin%20module/1.9/awstats-1.9.wbm
	#ftp://download.thirdlane.com/pbxmanager/asteriskm.wbm.gz
	#http://download.softagency.net/BitDefender/linux/RemoteAdmin/webmin/BitDefender.wbm.gz
	#http://www.tecchio.net/webmin/cyrus/cyrus-imapd-mod.wbm.gz
	#http://www.webmin.com/webmin/download/modules/dovecot.wbm.gz
	#http://www.webmin.com/download/modules/dynbind.wbm.gz
	#http://www.tbits.org/download/ddnsupdate-b02.wbm
	#http://www.elet.polimi.it/upload/beltrame/webmin/dyndns-0.4.wbm
	#http://mtlx.free.fr/webmin/exim/exim-0.2.6.wbm.gz
	#http://www.webmin.com/webmin/download/modules/heartbeat.wbm.gz
	
	service apache2 restart
fi


read -p "Install apparmor (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	yecho "installing apparmor apparmor-profiles apparmor-utils"
	apt-get -q -y install apparmor apparmor-profiles apparmor-utils 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	perl -pi -e 's,GRUB_CMDLINE_LINUX="(.*)"$,GRUB_CMDLINE_LINUX="$1 apparmor=1 security=apparmor",' /etc/default/grub
	update-grub 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	apparmor_status 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
fi

#Install systemd
read -p "Install systemd (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	yecho "installing systemd"
	apt-get -q -y install systemd 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#default: GRUB_CMDLINE_LINUX_DEFAULT="quiet"
	sed -i -r "s/^ *#? *GRUB_CMDLINE_LINUX_DEFAULT *=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"noplymouth init=\/lib\/systemd\/systemd\"/g" /etc/default/grub 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	update-grub
fi

###

yecho "harden kernel"
if [ ! -e /etc/sysctl.d/local.conf ]
then
cp /etc/sysctl.conf /etc/sysctl.d/local.conf
fi
grep -q  '^net.ipv4.conf.all.rp_filter' /etc/sysctl.d/local.conf ||
sed -i -r "s/ *\t*\#? *\t*net\.ipv4\.conf\.all\.rp_filter *\t*=.*/net\.ipv4\.conf\.all\.rp_filter=1/g" /etc/sysctl.d/local.conf
grep -q  '^net.ipv4.tcp_syncookies' /etc/sysctl.d/local.conf ||
sed -i -r "s/ *\t*\#? *\t*net\.ipv4\.tcp_syncookies *\t*=.*/net\.ipv4\.tcp_syncookies=1/g" /etc/sysctl.d/local.conf
grep -q  '^net.ipv6.conf.default.autoconf' /etc/sysctl.d/local.conf ||



echo '
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0 
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0 
net.ipv6.conf.default.accept_redirects = 0

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_all = 1


# ipv6 settings (no autoconfiguration)
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.default.accept_dad=0
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.default.accept_ra_defrtr=0
net.ipv6.conf.default.accept_ra_rtr_pref=0
net.ipv6.conf.default.accept_ra_pinfo=0
net.ipv6.conf.default.accept_source_route=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.default.forwarding=0
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.all.accept_dad=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.all.accept_ra_defrtr=0
net.ipv6.conf.all.accept_ra_rtr_pref=0
net.ipv6.conf.all.accept_ra_pinfo=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.all.forwarding=0
' >> /etc/sysctl.d/local.conf

#check for dumps
(cat /boot/config-$(uname -r) |grep DUMP)| grep '=y' ||
# don't know how do disable? recompile kernel?

sysctl -p

# configure and persist firewall rules
apt-get -y -q install iptables-persistent 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)	
iptables-save > /etc/iptables/rules.v4 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
ip6tables-save > /etc/iptables/rules.v6 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
# restart iptables
#/etc/init.d/iptables restart 
service iptables-persistent restart 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

# standard way 
#iptables-save > /etc/iptables.up.rules
#echo '#!/bin/bash
#/sbin/iptables-restore < /etc/iptables.up.rules
#' >> /etc/network/if-pre-up.d/iptables
#chmod +x /etc/network/if-pre-up.d/iptables
#iptables -L

read -p "Install Nmap and scan for open ports (y/n) [no]? " -n 1 REPLY
if [[ $REPLY =~ ^[YyjJ]$ ]]
then
	apt-get -q -y install nmap 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	nmap -v -sT localhost 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	pause
	nmap -v -sS localhost 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	psuse
fi

yecho "hardening system"
apt-get -y -q autoremove --purge nmap g++ make checkinstall tofrodos build-essential bc netselect-apt 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
apt-get -y -q -f install 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
apt-get -y -q autoclean 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
apt-get -y -q clean 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "switching back to german"
_configure_locale DE 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho "restarting cron"
#systemctl restart cron.service 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
service cron restart

#read -p "Install Lynis - a system security audit tool (y/n) [no]? " -n 1 REPLY
#if [[ $REPLY =~ ^[YyjJ]$ ]]
#then	
	#Install lynis (Security and system auditing tool) 
	apt-get -y -q install lynis 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	lynis --check-all --quiet 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	apt-get -y -q update  2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	apt-get -y -q -V upgrade  2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	apt-get -y -q dist-upgrade  2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	updatedb 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#fi

#read -p "Install tiger - a system security audit tool (y/n) [no]? " -n 1 REPLY
#if [[ $REPLY =~ ^[YyjJ]$ ]]
#then	
	#Install tiger (Security and system auditing tool) 
	apt-get -y -q install tiger 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	tiger 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
	#output
	#/var/log/tiger
	#reports
	#less /var/log/tiger/security.report.*
#fi

#generate aliases
newaliases 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)

yecho 'cleaning /tmp'
rm -R /tmp/*
rm -R /tmp/*.*

egrep 'Mem|Cache|Swap' /proc/meminfo
iostat

yecho "finished all actions" ;
yecho "reboot to check everything is working" ;
wecho "lsmod to show modules loaded"
wecho "ifconfig to show network setup"
wecho "cpan to enter cpan setup"
wecho "ifconfig eth0.20 down && vconfig rem eth0.20 to delete vlan interface"
wecho "for icinga visit http://${SERVERIP}/icinga-web user: root, password: password and change password"
wecho "for ajenti visit https://${SERVERIP}:8000 OR https://${SERVERIP}:8000 default username \"admin\" or \"root\" and password is \"admin\"."
wecho "for webmin visit http://${SERVERIP}:10000 and login with root and your password"
wecho "for LiveConfig visit https://${SERVERIP}:8443/"
#dos not work
#yecho "installing bootlogd"
#apt-get isntall bootlogd
#sed -i -r s/^.*BOOTLOGD_ENABLE=.*$/BOOTLOGD_ENABLE=yes/ /etc/default/bootlogd;
#sed $'s/\^\[/\E/g' /var/log/boot | less -R

#useradd: Create a new user or update default new user information 
#usermod: Modify a user account 
#userdel: Delete a user account and related files 
#chage: change user password expiry information 
#pwconv: convert to and from shadow pass- words and groups. 
#pwunconv: convert to and from shadow pass- words and groups. 
#grpconv: creates gshadow from group and an optionally existing gshadow 
#grpunconv: creates group from group and gshadow and then removes gshadow 
 
#new in wheezy
#systemd: with journald
#Xen Cloud Platform (XCP) 
#Openstack 

#perl cpan, php pear PECL, python egg easy_install, ruby gem, TeX CTAN, R CRAN 

#no longer supported in wheezy
#Linux-Vserver 
#OpenVZ (alternative LXC + AppArmor [maybe depricated], Kernel-based Virtual Machine (KVM) + openQRM (optional)) http://www.howtoforge.com/virtualization-with-kvm-and-openqrm-5.1-on-debian-wheezy
#php5-suhosin 



#inst sudo edit  /etc/sudoers 
#http://www.server-world.info/en/note?os=Debian_7.0&p=initial_conf&f=7


#iscsi
#https://wiki.debian.org/SAN/iSCSI/open-iscsi



#xen install (unfinished)
#http://www.howtoforge.com/paravirtualization-with-xen-4.0-on-debian-squeeze-amd64
#yecho "installing xen-hypervisor xen-linux-system xen-utils xenstore-utils xenwatch xen-tools"
#apt-get install xen-hypervisor xen-linux-system xen-utils xenstore-utils xenwatch xen-tools
#sed -i "s/^loop max_loop.*/loop max_loop=64/g" /etc/modules
#/etc/xen/xend-config.sxp
#	(network-script 'network-bridge antispoof=yes')
#	(vif-script vif-bridge)
#	comment out all other (network-script ...)

#add more choices to apt
## basic mirror
#deb http://http.debian.net/debian stable main
##deb-src http://http.debian.net/debian stable main
## stable-updates as alternative to testing
##deb http://http.debian.net/debian stable-updates main
##deb-src http://http.debian.net/debian stable-updates main
## security updates (recommanded)
#deb http://security.debian.org/ wheezy/updates main
##deb-src http://security.debian.org/ wheezy/updates main
## backports for wheezy
## usage: apt-get -t wheezy-backports install PAKETNAME
##deb http://ftp.de.debian.org/debian/ wheezy-backports main

#backup
#bacula

#configuration management
#http://fai-project.org/
#https://access.redhat.com/site/documentation/en-US/Red_Hat_Enterprise_Linux/5/html/Installation_Guide/ch-kickstart2.html
#https://fedorahosted.org/cobbler/
#http://spacewalk.redhat.com/
#http://www.openqrm-enterprise.com/community/
#http://www.ispconfig.de/
#http://www.webmin.com/index.html
#Puppet � Open source data centre automation and configuration management framework
#ERB � Powerful templating system for Ruby
#Puppet Recipes � Recipes for configuring Puppet
#Puppet Dashboard � Web interface and reporting tool for Puppet
#http://forge.puppetlabs.com/
#http://puppetlabs.com/puppet/related-projects/dashboard

#http://de.wikipedia.org/wiki/Filesystem_Hierarchy_Standard

#http://cowthink.net/linux-lemp-server-auf-debian-squeeze-wheezy-teil-2-php-fpm/

#lsof -i :portNumber
#lsof -i tcp:portNumber
#lsof -i udp:portNumber
#lsof -i :80
#lsof -i :80 | grep LISTEN
#
#ps aux | grep $spec | grep -v grep | awk '{print $2}' | xargs kill
#lsof -Pnl +M -i4
#lsof -Pnl +M -i6
#
#netstat -tulpn
#-t : TCP port
#-u : UDP port
#-l : Show only listening sockets.
#-p : Show the PID and name of the program to which each socket / port belongs
#-n : No DNS lookup (speed up operation)
#
#port tcp udp
#42 Ja Ja Nameserver, ARPA Host Name Server Protocol 
#53 Ja Ja Domain Name System (DNS), meist �ber UDP 
#80 Ja Nein Hypertext Transfer Protocol (HTTP) 
#110 Ja Nein Post Office Protocol v3 (POP3) 
#115 Ja Nein Simple File Transfer Protocol (SFTP) 
#123 Nein Ja Network Time Protocol (NTP) zur (hoch)genauen Zeitsynchronisierung zwischen mehreren Computern 
#143 Ja Ja Internet Message Access Protocol (IMAP) � Mail-Management 
#161 Nein Ja Simple Network Management Protocol (SNMP) offiziell 
#162 Ja Ja Simple Network Management Protocol Trap (SNMPTRAP)[13] 
#220 Ja Ja Internet Message Access Protocol (IMAP), version 3 
#443 Ja Nein HTTPS (Hypertext Transfer Protocol over SSL/TLS) 
#465 Ja Nein SMTP over SSL 
#587 Ja Nein e-mail message submission[16] (SMTP) 
#953 Ja Ja Domain Name System (DNS) RNDC Service 
#989 Ja Ja FTPS Protocol (data): FTP over TLS/SSL offiziell 
#990 Ja Ja FTPS Protocol (control): FTP over TLS/SSL 
#991 Ja Ja NAS (Netnews Administration System) 
#993 Ja Nein Internet Message Access Protocol over SSL (IMAPS) offiziell 
#995 Ja Nein Post Office Protocol 3 over TLS/SSL (POP3S) 
#1194 Ja Ja OpenVPN 
#1293 Ja Ja IPSec (Internet Protocol Security) 
#1723 Ja Ja Microsoft Point-to-Point Tunneling Protocol (PPTP) 
#1883 Ja Ja MQ Telemetry Transport (MQTT), auch bekannt als MQIsdp (MQSeries SCADA protocol) 
#3306 Ja Ja MySQL database system 
#3389 Ja Ja Microsoft Terminal Server (RDP) offiziell registriert als Windows Based Terminal (WBT) � Link 
#3690 Ja Ja Subversion 
#5000 Ja Nein UPnP 
#5353 Nein Ja Multicast DNS (mDNS) 
#5666 Ja Nein NRPE (Nagios) inoffiziell 
#5667 Ja Nein NSCA (Nagios) 
#5938 Ja Ja TeamViewer[49] RDP inoffiziell 
#5984 Ja Ja CouchDB/Server 
#8010 Ja Nein XMPP Datei�bertragungen 
#8080 Ja Nein HTTP alternativ (http_alt) oft genutztf�r Web proxy und caching server, oder um einen Webserver ohne root -Rechte zu nutzen Offiziell 
#8883 Ja Ja Secure MQ Telemetry Transport (MQTT over SSL) 
#9110 Nein Ja SSMP Message protocol 
#9418 Ja Ja git, Git pack transfer service 
#9800 Ja Ja WebDAV Source 
#10000 Nein Nein Webmin 
#11211 Nein Nein memcached 
#11371 Nein Nein OpenPGP HTTP Key Server 
#25565 Nein Nein MySQL Standard MySQL port 
#27017 Nein Nein mongoDB server port 



grep -q 'This hosts file is brought to you by Dan Pollock' /etc/hosts ||
echo '
# This hosts file is brought to you by Dan Pollock and can be found at
# http://someonewhocares.org/hosts/
# You are free to copy and distribute this file, as long the original 
# URL is included. See below for acknowledgements.

# Please forward any additions, corrections or comments by email to
# hosts [at] someonewhocares [dot] org

# Last updated: May 9th, 2013 at 13:23

# Use this file to prevent your computer from connecting to selected
# internet hosts. This is an easy and effective way to protect you from 
# many types of spyware, reduces bandwidth use, blocks certain pop-up 
# traps, prevents user tracking by way of &quot;web bugs&quot; embedded in spam,
# provides partial protection to IE from certain web-based exploits and
# blocks most advertising you would otherwise be subjected to on the 
# internet. 

# There is a version of this file that uses 0.0.0.0 instead of 127.0.0.1 
# available at http://someonewhocares.org/hosts/zero/.
# On some machines this may run minutely faster, however the zero version
# may not be compatible with all systems. 

# This file must be saved as a text file with no extension. (This means it
# that the file name should be exactly as below, without a &quot;.txt&quot; appended.)

# Let me repeat, the file should be named &quot;hosts&quot; NOT &quot;hosts.txt&quot;.

# For Windows 9x and ME place this file at &quot;C:\Windows\hosts&quot;
# For NT, Win2K and XP use &quot;C:\windows\system32\drivers\etc\hosts&quot;
#                       or &quot;C:\winnt\system32\drivers\etc\hosts&quot;
# For Windows 7 and Vista use &quot;C:\windows\system32\drivers\etc\hosts&quot;
#           or &quot;%systemroot%\system32\drivers\etc\hosts&quot;
# You may have to use Notepad and &quot;Run as Administrator&quot;
# For Linux, Unix, or OS X place this file at &quot;/etc/hosts&quot;. You will 
#    require root access to do this. Saving this file to &quot;~/hosts&quot; will
#    allow you to run something like &quot;sudo cp ~/hosts /etc/hosts&quot;.
# Ubuntu users who experience trouble with apt-get should consult
#    http://ubuntuforums.org/archive/index.php/t-613521.html
# For OS/2 copy the file to &quot;%ETC%\HOSTS&quot; and in the CONFIG.SYS file,
#    ensure that the line &quot;SET USE_HOSTS_FIRST=1&quot; is included.
# For BeOS place it at &quot;/boot/beos/etc/hosts&quot;
# On a Netware system, the location is System\etc\hosts&quot;
# For Macintosh (pre OS X) place it in the Mac System Folder or Preferences
#    folder and reboot. (something like HD:System Folder:Preferences:Hosts)
#    Alternatively you can save it elsewhere on your machine, then go to the 
#    TCP/IP control panel and click on &quot;Select hosts file&quot; to read it in.
#    ------------------
#    | As well, note that the format is different on old macs, so
#    | please visit http://someonewhocares.org/hosts/mac/ for mac format
#    ------------------
# To convert the hosts file to a set of Cisco IOS commands for Cisco routers
#   use this script by Jesse Baird:
#   http://jebaird.com/blog/hosts-ip-host-generating-blocked-hosts-host-file-cisco-router

# If there is a domain name you would rather never see, simply add a line
# that reads &quot;127.0.0.1 machine.domain.tld&quot;. This will have the effect of
# redirecting any requests to that host to your own computer. For example
# this will prevent your browser from downloading banner ads, or sending
# your information back to a company.

#<shock-sites>
# For example, to block unpleasant pages, try:
127.0.0.1 goatse.cx       # More information on sites such as 
127.0.0.1 www.goatse.cx   # these can be found in this article
127.0.0.1 oralse.cx       # en.wikipedia.org/wiki/List_of_shock_sites
127.0.0.1 www.oralse.cx
127.0.0.1 goatse.ca
127.0.0.1 www.goatse.ca
127.0.0.1 oralse.ca
127.0.0.1 www.oralse.ca
127.0.0.1 goat.cx
127.0.0.1 www.goat.cx
127.0.0.1 goatse.ru
127.0.0.1 www.goatse.ru

127.0.0.1 1girl1pitcher.org
127.0.0.1 1guy1cock.com
127.0.0.1 1man1jar.org
127.0.0.1 1man2needles.com
127.0.0.1 1priest1nun.com
127.0.0.1 2girls1cup-free.com
127.0.0.1 2girls1cup.nl
127.0.0.1 2girls1cup.ws
127.0.0.1 2girls1finger.org
127.0.0.1 2guys1stump.org
127.0.0.1 3guys1hammer.ws
127.0.0.1 4girlsfingerpaint.org
127.0.0.1 bagslap.com
127.0.0.1 ballsack.org
127.0.0.1 bluewaffle.biz
127.0.0.1 bottleguy.com
127.0.0.1 bowlgirl.com
127.0.0.1 cadaver.org
127.0.0.1 clownsong.com
127.0.0.1 copyright-reform.info
127.0.0.1 cshacks.partycat.us
127.0.0.1 cyberscat.com
127.0.0.1 dadparty.com
127.0.0.1 detroithardcore.com
127.0.0.1 donotwatch.org
127.0.0.1 dontwatch.us
127.0.0.1 eelsoup.net
127.0.0.1 fruitlauncher.com
127.0.0.1 fuck.org
127.0.0.1 funnelchair.com
127.0.0.1 goatse.bz
127.0.0.1 goatsegirl.org
127.0.0.1 hai2u.com
127.0.0.1 homewares.org
127.0.0.1 howtotroll.org
127.0.0.1 japscat.org
127.0.0.1 jiztini.com
127.0.0.1 junecleeland.com
127.0.0.1 kids-in-sandbox.com
127.0.0.1 kidsinsandbox.info
127.0.0.1 lemonparty.biz
127.0.0.1 lemonparty.org
127.0.0.1 lolhello.com
127.0.0.1 loltrain.com
127.0.0.1 meatspin.biz
127.0.0.1 meatspin.com
127.0.0.1 merryholidays.org
127.0.0.1 milkfountain.com
127.0.0.1 mudfall.com
127.0.0.1 mudmonster.org
127.0.0.1 nimp.org
127.0.0.1 nutabuse.com
127.0.0.1 octopusgirl.com
127.0.0.1 on.nimp.org
127.0.0.1 painolympics.info
127.0.0.1 phonejapan.com
127.0.0.1 pressurespot.com
127.0.0.1 prolapseman.com
127.0.0.1 scrollbelow.com
127.0.0.1 selfpwn.org
127.0.0.1 sexitnow.com
127.0.0.1 sourmath.com
127.0.0.1 suckdude.com
127.0.0.1 thatsjustgay.com
127.0.0.1 thatsphucked.com
127.0.0.1 thehomo.org
127.0.0.1 themacuser.org
127.0.0.1 thepounder.com
127.0.0.1 tubgirl.me
127.0.0.1 tubgirl.org
127.0.0.1 turdgasm.com
127.0.0.1 vomitgirl.org
127.0.0.1 walkthedinosaur.com
127.0.0.1 whipcrack.org
127.0.0.1 wormgush.com
127.0.0.1 www.1girl1pitcher.org
127.0.0.1 www.1guy1cock.com
127.0.0.1 www.1man1jar.org
127.0.0.1 www.1man2needles.com
127.0.0.1 www.1priest1nun.com
127.0.0.1 www.2girls1cup-free.com
127.0.0.1 www.2girls1cup.nl
127.0.0.1 www.2girls1cup.ws
127.0.0.1 www.2girls1finger.org
127.0.0.1 www.2guys1stump.org
127.0.0.1 www.3guys1hammer.ws
127.0.0.1 www.4girlsfingerpaint.org
127.0.0.1 www.bagslap.com
127.0.0.1 www.ballsack.org
127.0.0.1 www.bluewaffle.biz
127.0.0.1 www.bottleguy.com
127.0.0.1 www.bowlgirl.com
127.0.0.1 www.cadaver.org
127.0.0.1 www.clownsong.com
127.0.0.1 www.copyright-reform.info
127.0.0.1 www.cshacks.partycat.us
127.0.0.1 www.cyberscat.com
127.0.0.1 www.dadparty.com
127.0.0.1 www.detroithardcore.com
127.0.0.1 www.donotwatch.org
127.0.0.1 www.dontwatch.us
127.0.0.1 www.eelsoup.net
127.0.0.1 www.fruitlauncher.com
127.0.0.1 www.fuck.org
127.0.0.1 www.funnelchair.com
127.0.0.1 www.goatse.bz
127.0.0.1 www.goatsegirl.org
127.0.0.1 www.hai2u.com
127.0.0.1 www.homewares.org
127.0.0.1 www.howtotroll.org
127.0.0.1 www.japscat.org
127.0.0.1 www.jiztini.com
127.0.0.1 www.junecleeland.com
127.0.0.1 www.kids-in-sandbox.com
127.0.0.1 www.kidsinsandbox.info
127.0.0.1 www.lemonparty.biz
127.0.0.1 www.lemonparty.org
127.0.0.1 www.lolhello.com
127.0.0.1 www.loltrain.com
127.0.0.1 www.meatspin.biz
127.0.0.1 www.meatspin.com
127.0.0.1 www.merryholidays.org
127.0.0.1 www.milkfountain.com
127.0.0.1 www.mudfall.com
127.0.0.1 www.mudmonster.org
127.0.0.1 www.nimp.org
127.0.0.1 www.nutabuse.com
127.0.0.1 www.octopusgirl.com
127.0.0.1 www.on.nimp.org
127.0.0.1 www.painolympics.info
127.0.0.1 www.phonejapan.com
127.0.0.1 www.pressurespot.com
127.0.0.1 www.prolapseman.com
127.0.0.1 www.punishtube.com
127.0.0.1 www.scrollbelow.com
127.0.0.1 www.selfpwn.org
127.0.0.1 www.sourmath.com
127.0.0.1 www.suckdude.com
127.0.0.1 www.thatsjustgay.com
127.0.0.1 www.thatsphucked.com
127.0.0.1 www.theexgirlfriends.com
127.0.0.1 www.thehomo.org
127.0.0.1 www.themacuser.org
127.0.0.1 www.thepounder.com
127.0.0.1 www.tubgirl.me
127.0.0.1 www.tubgirl.org
127.0.0.1 www.turdgasm.com
127.0.0.1 www.vomitgirl.org
127.0.0.1 www.walkthedinosaur.com
127.0.0.1 www.whipcrack.org
127.0.0.1 www.wormgush.com
127.0.0.1 www.xvideoslive.com
127.0.0.1 www.y8.com
127.0.0.1 www.youaresogay.com
127.0.0.1 www.ypmate.com
127.0.0.1 youaresogay.com
#</shock-sites>

#<shortcut-examples>
# As well by specifying the ipaddress of a server, you can gain access
#   to some of your favourite sites with a single letter, instead of
#   using the whole domain name
# It is perhaps a better solution to use Favourites/Bookmarks instead.
#216.34.181.45   s        # slashdot.org
#74.125.127.105 g        # google.com
#</shortcut-examples>

#<hijack-sites>
# The sites ads234.com and ads345.com -- These sites hijack internet explorer 
# and redirect all requests through their servers. You may need to use spyware 
# removal programs such as SpyBotS&amp;D, AdAware or HijackThis to remove this 
# nasty parasite. It is possible that blocking these sites using a hosts file 
# may not work, in which case you should remove the following lines from this
# file and try the tools listed above immediately. Do not forget to reboot 
# after a scan.
127.0.0.1 ads234.com
127.0.0.1 ads345.com
127.0.0.1 www.ads234.com
127.0.0.1 www.ads345.com
#</hijack-sites>


#<spyware-sites>
# Spyware and user tracking
# By entering domains here, it will prevent certain companies from
# gathering information on your surfing habits. These servers do not
# necessarily serve ads, instead some are used by certain products to
# &quot;phone home&quot;. Others use web cookies to gather statistics on surfing 
# habits. Among other uses, this is a common tactic by spammers, to 
# let them know that you have read your mail. 
# Uncomment (remove the #) the lines that you wish to block, as some
# may provide you with services you like.

#<maybe-spy>
#127.0.0.1 auto.search.msn.com  # Microsoft uses this server to redirect
                                # mistyped URLs to search engines. They
                                # log all such errors.
#127.0.0.1 sitefinder.verisign.com  # Verisign has joined the game 
#127.0.0.1 sitefinder-idn.verisign.com  # of trying to hijack mistyped
                    # URLs to their site. 
                    # May break iOS Game Center.

#127.0.0.1 s0.2mdn.net      # This may interfere with some streaming 
                # video on sites such as cbc.ca
#127.0.0.1 ad.doubleclick.net   # This may interefere with www.sears.com
                # and potentially other sites. 
127.0.0.1 media.fastclick.net   # Likewise, this may interfere with some
127.0.0.1 cdn.fastclick.net # sites. 
#127.0.0.1 ebay.doubleclick.net     # may interfere with ebay
#127.0.0.1 google-analytics.com         # breaks some sites
#127.0.0.1 ssl.google-analytics.com
#127.0.0.1 stat.livejournal.com     # There are reports that this may mess 
                    # up CSS on livejournal
#127.0.0.1 stats.surfaid.ihost.com  # This has been known cause 
                    # problems with NPR.org
#127.0.0.1 www.google-analytics.com     # breaks some sites
#127.0.0.1 ads.imeem.com        # Seems to interfere with the functioning of imeem.com
#</maybe-spy>

127.0.0.1 006.free-counter.co.uk
127.0.0.1 006.freecounters.co.uk
127.0.0.1 06272002-dbase.hitcountz.net # Web bugs in spam
127.0.0.1 0stats.com
127.0.0.1 123counter.mycomputer.com
127.0.0.1 123counter.superstats.com
127.0.0.1 1ca.cqcounter.com
127.0.0.1 1uk.cqcounter.com
127.0.0.1 1us.cqcounter.com
127.0.0.1 1xxx.cqcounter.com
127.0.0.1 2001-007.com
127.0.0.1 3bc3fd26-91cf-46b2-8ec6-b1559ada0079.statcamp.net
127.0.0.1 3ps.go.com
127.0.0.1 4-counter.com
127.0.0.1 a.visualrevenue.com
127.0.0.1 a796faee-7163-4757-a34f-e5b48cada4cb.statcamp.net
127.0.0.1 abscbn.spinbox.net
127.0.0.1 activity.serving-sys.com  #eyeblaster.com
127.0.0.1 ad-logics.com
127.0.0.1 adadvisor.net
127.0.0.1 adclient.rottentomatoes.com
127.0.0.1 adcodes.aim4media.com
127.0.0.1 adcounter.globeandmail.com
127.0.0.1 adcounter.theglobeandmail.com
127.0.0.1 addfreestats.com
127.0.0.1 ademails.com
127.0.0.1 adlog.com.com # Used by Ziff Davis to serve 
  # ads and track users across 
  # the com.com family of sites
127.0.0.1 admanmail.com
127.0.0.1 adopt.specificclick.net
127.0.0.1 ads.tiscali.com
127.0.0.1 ads.tiscali.it
127.0.0.1 adult.foxcounter.com
127.0.0.1 affiliate.ab1trk.com
127.0.0.1 affiliate.irotracker.com
127.0.0.1 ai062.insightexpress.com
127.0.0.1 ai078.insightexpressai.com
127.0.0.1 ai087.insightexpress.com
127.0.0.1 ai113.insightexpressai.com
127.0.0.1 ai125.insightexpressai.com
127.0.0.1 alpha.easy-hit-counters.com
127.0.0.1 amateur.xxxcounter.com
127.0.0.1 amer.hops.glbdns.microsoft.com
127.0.0.1 amer.rel.msn.com
127.0.0.1 analytics.msnbc.msn.com
127.0.0.1 analytics.prx.org
127.0.0.1 anm.intelli-direct.com
127.0.0.1 ant.conversive.nl
127.0.0.1 apac.rel.msn.com
127.0.0.1 api.bizographics.com
127.0.0.1 app.yesware.com
127.0.0.1 apprep.smartscreen.microsoft.com
127.0.0.1 arbo.hit.gemius.pl
127.0.0.1 au.track.decideinteractive.com
127.0.0.1 au052.insightexpress.com
127.0.0.1 b.stats.paypal.com
127.0.0.1 banner.0catch.com
127.0.0.1 banners.webcounter.com
127.0.0.1 be.sitestat.com
127.0.0.1 beacon-1.newrelic.com
127.0.0.1 beacon.scorecardresearch.com
127.0.0.1 beacons.hottraffic.nl
127.0.0.1 best-search.cc    #spyware
127.0.0.1 beta.easy-hit-counter.com
127.0.0.1 beta.easy-hit-counters.com
127.0.0.1 beta.easyhitcounters.com
127.0.0.1 bilbo.counted.com
127.0.0.1 bin.clearspring.com
127.0.0.1 birta.stats.is
127.0.0.1 bluekai.com
127.0.0.1 bluestreak.com
127.0.0.1 bookproplus.com
127.0.0.1 broadcastpc.tv 
127.0.0.1 report.broadcastpc.tv 
127.0.0.1 www.broadcastpc.tv
127.0.0.1 bserver.blick.com
127.0.0.1 bstats.adbrite.com
127.0.0.1 by.optimost.com
127.0.0.1 c.statcounter.com
127.0.0.1 c.thecounter.de
127.0.0.1 c1.statcounter.com
127.0.0.1 c1.thecounter.com
127.0.0.1 c1.thecounter.de
127.0.0.1 c1.xxxcounter.com
127.0.0.1 c10.statcounter.com
127.0.0.1 c11.statcounter.com
127.0.0.1 c12.statcounter.com
127.0.0.1 c13.statcounter.com
127.0.0.1 c14.statcounter.com
127.0.0.1 c15.statcounter.com
127.0.0.1 c16.statcounter.com
127.0.0.1 c17.statcounter.com
127.0.0.1 c2.gostats.com
127.0.0.1 c2.thecounter.com
127.0.0.1 c2.thecounter.de
127.0.0.1 c2.xxxcounter.com
127.0.0.1 c3.gostats.com
127.0.0.1 c3.statcounter.com
127.0.0.1 c3.thecounter.com
127.0.0.1 c3.xxxcounter.com
127.0.0.1 c4.myway.com
127.0.0.1 c4.statcounter.com
127.0.0.1 c5.statcounter.com
127.0.0.1 c6.statcounter.com
127.0.0.1 c7.statcounter.com
127.0.0.1 c8.statcounter.com
127.0.0.1 c9.statcounter.com
127.0.0.1 ca.cqcounter.com
127.0.0.1 cashcounter.com
127.0.0.1 cb1.counterbot.com
127.0.0.1 cdn.krxd.net
127.0.0.1 cdn.oggifinogi.com
127.0.0.1 cdn.taboolasyndication.com
127.0.0.1 cdxbin.vulnerap.com
127.0.0.1 cf.addthis.com
127.0.0.1 cgi.hotstat.nl
127.0.0.1 cgi.sexlist.com
127.0.0.1 cgicounter.onlinehome.de
127.0.0.1 cgicounter.puretec.de
127.0.0.1 ci-mpsnare.iovation.com   # See http://www.codingthewheel.com/archives/online-gambling-privacy-iesnare
127.0.0.1 citrix.tradedoubler.com
127.0.0.1 cjt1.net
127.0.0.1 click.atdmt.com
127.0.0.1 click.fivemtn.com
127.0.0.1 click.investopedia.com
127.0.0.1 click.jve.net
127.0.0.1 click.payserve.com
127.0.0.1 click.silvercash.com
127.0.0.1 clickauditor.net
127.0.0.1 clickmeter.com
127.0.0.1 clicks.emarketmakers.com
127.0.0.1 clicks.m4n.nl
127.0.0.1 clicks.natwest.com
127.0.0.1 clicks.rbs.co.uk
127.0.0.1 clicks.toteme.com
127.0.0.1 clickspring.net   #used by a spyware product called PurityScan
127.0.0.1 clicktrack.onlineemailmarketing.com
127.0.0.1 clicktracks.webmetro.com
127.0.0.1 clit10.sextracker.com
127.0.0.1 clit13.sextracker.com
127.0.0.1 clit15.sextracker.com
127.0.0.1 clit2.sextracker.com
127.0.0.1 clit4.sextracker.com
127.0.0.1 clit6.sextracker.com
127.0.0.1 clit7.sextracker.com
127.0.0.1 clit8.sextracker.com
127.0.0.1 clit9.sextracker.com
127.0.0.1 clk.aboxdeal.com
127.0.0.1 clk.relestar.com
127.0.0.1 cnn.entertainment.printthis.clickability.com
127.0.0.1 cnt.xcounter.com
127.0.0.1 collector.deepmetrix.com
127.0.0.1 collector.newsx.cc
127.0.0.1 connectionlead.com
127.0.0.1 connexity.net
127.0.0.1 cookies.cmpnet.com
127.0.0.1 count.channeladvisor.com
127.0.0.1 count.paycounter.com
127.0.0.1 count.xhit.com
127.0.0.1 counter.123counts.com
127.0.0.1 counter.1stblaze.com
127.0.0.1 counter.aaddzz.com
127.0.0.1 counter.adultcheck.com
127.0.0.1 counter.adultrevenueservice.com
127.0.0.1 counter.advancewebhosting.com
127.0.0.1 counter.aport.ru
127.0.0.1 counter.asexhound.com
127.0.0.1 counter.avp2000.com
127.0.0.1 counter.bizland.com
127.0.0.1 counter.bloke.com
127.0.0.1 counter.clubnet.ro
127.0.0.1 counter.cnw.cz
127.0.0.1 counter.credo.ru
127.0.0.1 counter.cz
127.0.0.1 counter.digits.com
127.0.0.1 counter.dreamhost.com
127.0.0.1 counter.e-audit.it
127.0.0.1 counter.execpc.com
127.0.0.1 counter.fateback.com
127.0.0.1 counter.gamespy.com
127.0.0.1 counter.hitslink.com
127.0.0.1 counter.hitslinks.com
127.0.0.1 counter.htmlvalidator.com
127.0.0.1 counter.impressur.com
127.0.0.1 counter.inetusa.com
127.0.0.1 counter.inti.fr
127.0.0.1 counter.kaspersky.com
127.0.0.1 counter.letssingit.com
127.0.0.1 counter.mtree.com
127.0.0.1 counter.mycomputer.com
127.0.0.1 counter.netmore.net
127.0.0.1 counter.nope.dk
127.0.0.1 counter.nowlinux.com
127.0.0.1 counter.pcgames.de
127.0.0.1 counter.rambler.ru
127.0.0.1 counter.search.bg
127.0.0.1 counter.sexhound.nl
127.0.0.1 counter.sparklit.com
127.0.0.1 counter.superstats.com
127.0.0.1 counter.surfcounters.com
127.0.0.1 counter.times.lv
127.0.0.1 counter.topping.com.ua
127.0.0.1 counter.tripod.com
127.0.0.1 counter.uq.edu.au
127.0.0.1 counter.w3open.com
127.0.0.1 counter.webcom.com
127.0.0.1 counter.webmedia.pl
127.0.0.1 counter.webtrends.com
127.0.0.1 counter.webtrends.net
127.0.0.1 counter.xxxcool.com
127.0.0.1 counter.yadro.ru
127.0.0.1 counter1.bravenet.com
127.0.0.1 counter1.sextracker.be
127.0.0.1 counter1.sextracker.com
127.0.0.1 counter10.bravenet.com
127.0.0.1 counter10.sextracker.be
127.0.0.1 counter10.sextracker.com
127.0.0.1 counter11.bravenet.com
127.0.0.1 counter11.sextracker.be
127.0.0.1 counter11.sextracker.com
127.0.0.1 counter12.bravenet.com
127.0.0.1 counter12.sextracker.be
127.0.0.1 counter12.sextracker.com
127.0.0.1 counter13.bravenet.com
127.0.0.1 counter13.sextracker.be
127.0.0.1 counter13.sextracker.com
127.0.0.1 counter14.bravenet.com
127.0.0.1 counter14.sextracker.be
127.0.0.1 counter14.sextracker.com
127.0.0.1 counter15.bravenet.com
127.0.0.1 counter15.sextracker.be
127.0.0.1 counter15.sextracker.com
127.0.0.1 counter16.bravenet.com
127.0.0.1 counter16.sextracker.be
127.0.0.1 counter16.sextracker.com
127.0.0.1 counter17.bravenet.com
127.0.0.1 counter18.bravenet.com
127.0.0.1 counter19.bravenet.com
127.0.0.1 counter2.bravenet.com
127.0.0.1 counter2.freeware.de
127.0.0.1 counter2.hitslink.com
127.0.0.1 counter2.sextracker.be
127.0.0.1 counter2.sextracker.com
127.0.0.1 counter20.bravenet.com
127.0.0.1 counter21.bravenet.com
127.0.0.1 counter22.bravenet.com
127.0.0.1 counter23.bravenet.com
127.0.0.1 counter24.bravenet.com
127.0.0.1 counter25.bravenet.com
127.0.0.1 counter26.bravenet.com
127.0.0.1 counter27.bravenet.com
127.0.0.1 counter28.bravenet.com
127.0.0.1 counter29.bravenet.com
127.0.0.1 counter3.bravenet.com
127.0.0.1 counter3.sextracker.be
127.0.0.1 counter3.sextracker.com
127.0.0.1 counter30.bravenet.com
127.0.0.1 counter31.bravenet.com
127.0.0.1 counter32.bravenet.com
127.0.0.1 counter33.bravenet.com
127.0.0.1 counter34.bravenet.com
127.0.0.1 counter35.bravenet.com
127.0.0.1 counter36.bravenet.com
127.0.0.1 counter37.bravenet.com
127.0.0.1 counter38.bravenet.com
127.0.0.1 counter39.bravenet.com
127.0.0.1 counter4.bravenet.com
127.0.0.1 counter4.sextracker.be
127.0.0.1 counter4.sextracker.com
127.0.0.1 counter40.bravenet.com
127.0.0.1 counter41.bravenet.com
127.0.0.1 counter42.bravenet.com
127.0.0.1 counter43.bravenet.com
127.0.0.1 counter44.bravenet.com
127.0.0.1 counter45.bravenet.com
127.0.0.1 counter46.bravenet.com
127.0.0.1 counter47.bravenet.com
127.0.0.1 counter48.bravenet.com
127.0.0.1 counter49.bravenet.com
127.0.0.1 counter4all.dk
127.0.0.1 counter4u.de
127.0.0.1 counter5.bravenet.com
127.0.0.1 counter5.sextracker.be
127.0.0.1 counter5.sextracker.com
127.0.0.1 counter50.bravenet.com
127.0.0.1 counter6.bravenet.com
127.0.0.1 counter6.sextracker.be
127.0.0.1 counter6.sextracker.com
127.0.0.1 counter7.bravenet.com
127.0.0.1 counter7.sextracker.be
127.0.0.1 counter7.sextracker.com
127.0.0.1 counter8.bravenet.com
127.0.0.1 counter8.sextracker.be
127.0.0.1 counter8.sextracker.com
127.0.0.1 counter9.bravenet.com
127.0.0.1 counter9.sextracker.be
127.0.0.1 counter9.sextracker.com
127.0.0.1 counterad.de
127.0.0.1 counteraport.spylog.com
127.0.0.1 counterbot.com
127.0.0.1 countercrazy.com
127.0.0.1 counters.auctionhelper.com        # comment these 
127.0.0.1 counters.auctionwatch.com     # out to allow 
127.0.0.1 counters.auctiva.com          # tracking by
127.0.0.1 counters.honesty.com          # ebay users
127.0.0.1 counters.gigya.com
127.0.0.1 counters.xaraonline.com
127.0.0.1 cs.sexcounter.com
127.0.0.1 cw.nu
127.0.0.1 cyseal.cyveillance.com
127.0.0.1 cz3.clickzs.com
127.0.0.1 cz6.clickzs.com
127.0.0.1 da.ce.bd.a9.top.list.ru
127.0.0.1 da.newstogram.com
127.0.0.1 data.coremetrics.com
127.0.0.1 data.webads.co.nz
127.0.0.1 data2.perf.overture.com
127.0.0.1 dclk.haaretz.co.il
127.0.0.1 dclk.themarker.com
127.0.0.1 dclk.themarketer.com
127.0.0.1 de.sitestat.com
127.0.0.1 delivery.loopingclick.com
127.0.0.1 didtheyreadit.com     # email bugs
127.0.0.1 digistats.westjet.com
127.0.0.1 dimeprice.com     # &quot;spam bugs&quot;
127.0.0.1 directads.mcafee.com
127.0.0.1 dotcomsecrets.com
127.0.0.1 dpbolvw.net
127.0.0.1 ds.247realmedia.com
127.0.0.1 ds.amateurmatch.com
127.0.0.1 dwclick.com
127.0.0.1 e-2dj6wfk4ehd5afq.stats.esomniture.com
127.0.0.1 e-2dj6wfk4ggdzkbo.stats.esomniture.com
127.0.0.1 e-2dj6wfk4gkcpiep.stats.esomniture.com
127.0.0.1 e-2dj6wfk4skdpogo.stats.esomniture.com
127.0.0.1 e-2dj6wfkiakdjgcp.stats.esomniture.com
127.0.0.1 e-2dj6wfkiepczoeo.stats.esomniture.com
127.0.0.1 e-2dj6wfkikjd5glq.stats.esomniture.com
127.0.0.1 e-2dj6wfkiokc5odp.stats.esomniture.com
127.0.0.1 e-2dj6wfkiqjcpifp.stats.esomniture.com
127.0.0.1 e-2dj6wfkocjczedo.stats.esomniture.com
127.0.0.1 e-2dj6wfkokjajseq.stats.esomniture.com
127.0.0.1 e-2dj6wfkowkdjokp.stats.esomniture.com
127.0.0.1 e-2dj6wfkykpazskq.stats.esomniture.com
127.0.0.1 e-2dj6wflicocjklo.stats.esomniture.com
127.0.0.1 e-2dj6wfligpd5iap.stats.esomniture.com
127.0.0.1 e-2dj6wflikgdpodo.stats.esomniture.com
127.0.0.1 e-2dj6wflikiajslo.stats.esomniture.com
127.0.0.1 e-2dj6wflioldzoco.stats.esomniture.com
127.0.0.1 e-2dj6wfliwpczolp.stats.esomniture.com
127.0.0.1 e-2dj6wfloenczmkq.stats.esomniture.com
127.0.0.1 e-2dj6wflokmajedo.stats.esomniture.com
127.0.0.1 e-2dj6wfloqgc5mho.stats.esomniture.com
127.0.0.1 e-2dj6wfmysgdzobo.stats.esomniture.com
127.0.0.1 e-2dj6wgkigpcjedo.stats.esomniture.com
127.0.0.1 e-2dj6wgkisnd5abo.stats.esomniture.com
127.0.0.1 e-2dj6wgkoandzieq.stats.esomniture.com
127.0.0.1 e-2dj6wgkycpcpsgq.stats.esomniture.com
127.0.0.1 e-2dj6wgkyepajmeo.stats.esomniture.com
127.0.0.1 e-2dj6wgkyknd5sko.stats.esomniture.com
127.0.0.1 e-2dj6wgkyomdpalp.stats.esomniture.com
127.0.0.1 e-2dj6whkiandzkko.stats.esomniture.com
127.0.0.1 e-2dj6whkiepd5iho.stats.esomniture.com
127.0.0.1 e-2dj6whkiwjdjwhq.stats.esomniture.com
127.0.0.1 e-2dj6wjk4amd5mfp.stats.esomniture.com
127.0.0.1 e-2dj6wjk4kkcjalp.stats.esomniture.com
127.0.0.1 e-2dj6wjk4ukazebo.stats.esomniture.com
127.0.0.1 e-2dj6wjkosodpmaq.stats.esomniture.com
127.0.0.1 e-2dj6wjkouhd5eao.stats.esomniture.com
127.0.0.1 e-2dj6wjkowhd5ggo.stats.esomniture.com
127.0.0.1 e-2dj6wjkowjajcbo.stats.esomniture.com
127.0.0.1 e-2dj6wjkyandpogq.stats.esomniture.com
127.0.0.1 e-2dj6wjkycpdzckp.stats.esomniture.com
127.0.0.1 e-2dj6wjkyqmdzcgo.stats.esomniture.com
127.0.0.1 e-2dj6wjkysndzigp.stats.esomniture.com
127.0.0.1 e-2dj6wjl4qhd5kdo.stats.esomniture.com
127.0.0.1 e-2dj6wjlichdjoep.stats.esomniture.com
127.0.0.1 e-2dj6wjliehcjglp.stats.esomniture.com
127.0.0.1 e-2dj6wjlignajgaq.stats.esomniture.com
127.0.0.1 e-2dj6wjloagc5oco.stats.esomniture.com
127.0.0.1 e-2dj6wjlougazmao.stats.esomniture.com
127.0.0.1 e-2dj6wjlyamdpogo.stats.esomniture.com
127.0.0.1 e-2dj6wjlyckcpelq.stats.esomniture.com
127.0.0.1 e-2dj6wjlyeodjkcq.stats.esomniture.com
127.0.0.1 e-2dj6wjlygkd5ecq.stats.esomniture.com
127.0.0.1 e-2dj6wjmiekc5olo.stats.esomniture.com
127.0.0.1 e-2dj6wjmyehd5mfo.stats.esomniture.com
127.0.0.1 e-2dj6wjmyooczoeo.stats.esomniture.com
127.0.0.1 e-2dj6wjny-1idzkh.stats.esomniture.com
127.0.0.1 e-2dj6wjnyagcpkko.stats.esomniture.com
127.0.0.1 e-2dj6wjnyeocpcdo.stats.esomniture.com
127.0.0.1 e-2dj6wjnygidjskq.stats.esomniture.com
127.0.0.1 e-2dj6wjnyqkajabp.stats.esomniture.com
127.0.0.1 e-n.y-1shz2prbmdj6wvny-1sez2pra2dj6wjmyepdzadpwudj6x9ny-1seq-2-2.stats.esomniture.com
127.0.0.1 e-ny.a-1shz2prbmdj6wvny-1sez2pra2dj6wjny-1jcpgbowsdj6x9ny-1seq-2-2.stats.esomniture.com
127.0.0.1 easy-web-stats.com
127.0.0.1 ecestats.theglobeandmail.com
127.0.0.1 economisttestcollect.insightfirst.com
127.0.0.1 ehg.fedex.com
127.0.0.1 eitbglobal.ojdinteractiva.com
127.0.0.1 emea.rel.msn.com
127.0.0.1 engine.cmmeglobal.com
127.0.0.1 enoratraffic.com
127.0.0.1 entry-stats.huffingtonpost.com
127.0.0.1 environmentalgraffiti.uk.intellitxt.com
127.0.0.1 es.optimost.com
127.0.0.1 fastcounter.bcentral.com
127.0.0.1 fastcounter.com
127.0.0.1 fastcounter.linkexchange.com
127.0.0.1 fastcounter.linkexchange.net
127.0.0.1 fastcounter.linkexchange.nl
127.0.0.1 fastcounter.onlinehoster.net
127.0.0.1 fastwebcounter.com
127.0.0.1 fcstats.bcentral.com
127.0.0.1 fi.sitestat.com
127.0.0.1 fl01.ct2.comclick.com
127.0.0.1 flycast.com
127.0.0.1 forbescollect.247realmedia.com
127.0.0.1 foxcounter.com
127.0.0.1 free-counter.5u.com
127.0.0.1 free.xxxcounter.com
127.0.0.1 freeinvisiblecounters.com
127.0.0.1 freestats.com
127.0.0.1 freewebcounter.com
127.0.0.1 fs10.fusestats.com
127.0.0.1 ft2.autonomycloud.com
127.0.0.1 g-wizzads.net
127.0.0.1 gapl.hit.gemius.pl
127.0.0.1 gator.com
127.0.0.1 gcounter.hosting4u.net
127.0.0.1 gd.mlb.com
127.0.0.1 gemius.pl
127.0.0.1 geocounter.net
127.0.0.1 gkkzngresullts.com
127.0.0.1 go-in-search.net
127.0.0.1 goldstats.com
127.0.0.1 googfle.com
127.0.0.1 googletagservices.com
127.0.0.1 gostats.com
127.0.0.1 grafix.xxxcounter.com
127.0.0.1 gtcc1.acecounter.com
127.0.0.1 hc2.humanclick.com
127.0.0.1 hit-counter.5u.com
127.0.0.1 hit-counter.udub.com
127.0.0.1 hit.clickaider.com
127.0.0.1 hit10.hotlog.ru
127.0.0.1 hit2.hotlog.ru
127.0.0.1 hit37.chark.dk
127.0.0.1 hit37.chart.dk
127.0.0.1 hit39.chart.dk
127.0.0.1 hit5.hotlog.ru
127.0.0.1 hit8.hotlog.ru
127.0.0.1 hits.guardian.co.uk
127.0.0.1 hits.gureport.co.uk
127.0.0.1 hits.nextstat.com
127.0.0.1 hits.webstat.com
127.0.0.1 hitx.statistics.ro
127.0.0.1 hst.tradedoubler.com
127.0.0.1 htm.freelogs.com
127.0.0.1 http300.edge.ru4.com
127.0.0.1 i.kissmetrics.com # http://www.wired.com/epicenter/2011/07/undeletable-cookie/
127.0.0.1 iccee.com
127.0.0.1 idm.hit.gemius.pl
127.0.0.1 ieplugin.com
127.0.0.1 iesnare.com       # See http://www.codingthewheel.com/archives/online-gambling-privacy-iesnare
127.0.0.1 ig.insightgrit.com
127.0.0.1 ih.constantcontacts.com
127.0.0.1 ilead.itrack.it
127.0.0.1 image.masterstats.com
127.0.0.1 images-aud.freshmeat.net
127.0.0.1 images-aud.slashdot.org
127.0.0.1 images-aud.sourceforge.net
127.0.0.1 images.dailydiscounts.com # &quot;spam bugs&quot;
127.0.0.1 images.itchydawg.com
127.0.0.1 images1.paycounter.com
127.0.0.1 imp.clickability.com
127.0.0.1 impacts.alliancehub.com # &quot;spam bugs&quot;
127.0.0.1 impch.tradedoubler.com
127.0.0.1 impde.tradedoubler.com
127.0.0.1 impdk.tradedoubler.com
127.0.0.1 impes.tradedoubler.com
127.0.0.1 impfr.tradedoubler.com
127.0.0.1 impgb.tradedoubler.com
127.0.0.1 impie.tradedoubler.com
127.0.0.1 impit.tradedouble.com
127.0.0.1 impit.tradedoubler.com
127.0.0.1 impnl.tradedoubler.com
127.0.0.1 impno.tradedoubler.com
127.0.0.1 impse.tradedoubler.com
127.0.0.1 in.paycounter.com
127.0.0.1 in.webcounter.cc
127.0.0.1 insightfirst.com
127.0.0.1 insightxe.looksmart.com
127.0.0.1 int.sitestat.com
127.0.0.1 iprocollect.realmedia.com
127.0.0.1 izitracking.izimailing.com
127.0.0.1 jgoyk.cjt1.net
127.0.0.1 jkearns.freestats.com
127.0.0.1 journalism.uk.smarttargetting.com
127.0.0.1 js.cybermonitor.com
127.0.0.1 js.revsci.net
127.0.0.1 jsonlinecollect.247realmedia.com
127.0.0.1 kissmetrics.com
127.0.0.1 kqzyfj.com
127.0.0.1 kt4.kliptracker.com
127.0.0.1 leadpub.com
127.0.0.1 liapentruromania.ro
127.0.0.1 lin31.metriweb.be
127.0.0.1 link.masterstats.com
127.0.0.1 linkcounter.com
127.0.0.1 linkcounter.pornosite.com
127.0.0.1 linktrack.bravenet.com
127.0.0.1 livestats.atlanta-airport.com
127.0.0.1 ll.a.hulu.com
127.0.0.1 loading321.com
127.0.0.1 loc1.hitsprocessor.com
127.0.0.1 log.btopenworld.com
127.0.0.1 log.clickstream.co.za
127.0.0.1 log.hankooki.com
127.0.0.1 log.statistici.ro
127.0.0.1 log1.countomat.com
127.0.0.1 log4.quintelligence.com
127.0.0.1 log999.goo.ne.jp
127.0.0.1 loga.xiti.com
127.0.0.1 logc1.xiti.com
127.0.0.1 logc146.xiti.com
127.0.0.1 logc22.xiti.com
127.0.0.1 logc25.xiti.com
127.0.0.1 logc31.xiti.com
127.0.0.1 logi6.xiti.com
127.0.0.1 logi7.xiti.com
127.0.0.1 logi8.xiti.com
127.0.0.1 logp3.xiti.com
127.0.0.1 logs.comics.com
127.0.0.1 logs.eresmas.com
127.0.0.1 logs.eresmas.net
127.0.0.1 logv.xiti.com
127.0.0.1 logv14.xiti.com
127.0.0.1 logv17.xiti.com
127.0.0.1 logv18.xiti.com
127.0.0.1 logv21.xiti.com
127.0.0.1 logv25.xiti.com
127.0.0.1 logv27.xiti.com
127.0.0.1 logv29.xiti.com
127.0.0.1 logv32.xiti.com
127.0.0.1 logv4.xiti.com
127.0.0.1 luycos.com
127.0.0.1 lycoscollect.247realmedia.com
127.0.0.1 lycoscollect.realmedia.com
127.0.0.1 m1.nedstatbasic.net
127.0.0.1 m1.webstats4u.com
127.0.0.1 mailcheckisp.biz  # &quot;spam bugs&quot;
127.0.0.1 mama128.valuehost.ru
127.0.0.1 marketscore.com
127.0.0.1 mature.xxxcounter.com
127.0.0.1 mbox5.offermatica.com
127.0.0.1 media.superstats.com
127.0.0.1 media101.sitebrand.com
127.0.0.1 mediatrack.revenue.net
127.0.0.1 metric.10best.com
127.0.0.1 metric.infoworld.com
127.0.0.1 metric.nationalgeographic.com
127.0.0.1 metric.nwsource.com
127.0.0.1 metric.olivegarden.com
127.0.0.1 metric.starz.com
127.0.0.1 metric.thenation.com
127.0.0.1 metrics.accuweather.com
127.0.0.1 metrics.al.com
127.0.0.1 metrics.boston.com
127.0.0.1 metrics.cbc.ca
127.0.0.1 metrics.cleveland.com
127.0.0.1 metrics.cnn.com
127.0.0.1 metrics.csmonitor.com
127.0.0.1 metrics.ctv.ca
127.0.0.1 metrics.dallasnews.com
127.0.0.1 metrics.elle.com
127.0.0.1 metrics.experts-exchange.com
127.0.0.1 metrics.fandome.com
127.0.0.1 metrics.foxnews.com
127.0.0.1 metrics.gap.com
127.0.0.1 metrics.health.com
127.0.0.1 metrics.hrblock.com
127.0.0.1 metrics.ioffer.com
127.0.0.1 metrics.ireport.com
127.0.0.1 metrics.kgw.com
127.0.0.1 metrics.ksl.com
127.0.0.1 metrics.ktvb.com
127.0.0.1 metrics.landolakes.com
127.0.0.1 metrics.lhj.com
127.0.0.1 metrics.maxim.com
127.0.0.1 metrics.mlive.com
127.0.0.1 metrics.mms.mavenapps.net
127.0.0.1 metrics.mpora.com
127.0.0.1 metrics.mysanantonio.com
127.0.0.1 metrics.nba.com
127.0.0.1 metrics.nextgov.com
127.0.0.1 metrics.nfl.com
127.0.0.1 metrics.npr.org
127.0.0.1 metrics.oclc.org
127.0.0.1 metrics.olivegarden.com
127.0.0.1 metrics.oregonlive.com
127.0.0.1 metrics.parallels.com
127.0.0.1 metrics.performancing.com
127.0.0.1 metrics.philly.com
127.0.0.1 metrics.post-gazette.com
127.0.0.1 metrics.premiere.com
127.0.0.1 metrics.rottentomatoes.com
127.0.0.1 metrics.sephora.com
127.0.0.1 metrics.soundandvision.com
127.0.0.1 metrics.soundandvisionmag.com
127.0.0.1 metrics.sun.com
127.0.0.1 metrics.technologyreview.com
127.0.0.1 metrics.theatlantic.com
127.0.0.1 metrics.thedailybeast.com
127.0.0.1 metrics.thefa.com
127.0.0.1 metrics.thefrisky.com
127.0.0.1 metrics.thenation.com
127.0.0.1 metrics.theweathernetwork.com
127.0.0.1 metrics.ticketmaster.com
127.0.0.1 metrics.tmz.com
127.0.0.1 metrics.toyota.com
127.0.0.1 metrics.tulsaworld.com
127.0.0.1 metrics.washingtonpost.com
127.0.0.1 metrics.whitepages.com
127.0.0.1 metrics.womansday.com
127.0.0.1 metrics.yellowpages.com
127.0.0.1 metrics.yousendit.com
127.0.0.1 metrics2.pricegrabber.com
127.0.0.1 mng1.clickalyzer.com
127.0.0.1 monster.gostats.com
127.0.0.1 mpsnare.iesnare.com   # See http://www.codingthewheel.com/archives/online-gambling-privacy-iesnare
127.0.0.1 msn1.com
127.0.0.1 msnm.com
127.0.0.1 mt122.mtree.com
127.0.0.1 mtcount.channeladvisor.com
127.0.0.1 mtrcs.popcap.com
127.0.0.1 mtv.247realmedia.com
127.0.0.1 multi1.rmuk.co.uk
127.0.0.1 mvs.mediavantage.de
127.0.0.1 mvtracker.com
127.0.0.1 mystats.com
127.0.0.1 nedstat.s0.nl
127.0.0.1 net-radar.com
127.0.0.1 nethit-free.nl
127.0.0.1 network.leadpub.com
127.0.0.1 nextgenstats.com
127.0.0.1 nht-2.extreme-dm.com
127.0.0.1 nl.nedstatbasic.net
127.0.0.1 nl.sitestat.com
127.0.0.1 o.addthis.com
127.0.0.1 oasc03049.247realmedia.com
127.0.0.1 objects.tremormedia.com
127.0.0.1 okcounter.com
127.0.0.1 omniture.theglobeandmail.com
127.0.0.1 one.123counters.com
127.0.0.1 oss-crules.marketscore.com
127.0.0.1 oss-survey.marketscore.com
127.0.0.1 ostats.mozilla.com
127.0.0.1 other.xxxcounter.com
127.0.0.1 out.true-counter.com
127.0.0.1 p.addthis.com
127.0.0.1 p.reuters.com
127.0.0.1 partner.alerts.aol.com
127.0.0.1 partners.pantheranetwork.com
127.0.0.1 passpport.com
127.0.0.1 paxito.sitetracker.com
127.0.0.1 paycounter.com
127.0.0.1 pei-ads.thesmokingjacket.com
127.0.0.1 perso.estat.com
127.0.0.1 pf.tradedoubler.com
127.0.0.1 pings.blip.tv
127.0.0.1 pix02.revsci.net
127.0.0.1 pix03.revsci.net
127.0.0.1 pix04.revsci.net
127.0.0.1 pixel.invitemedia.com
127.0.0.1 pmg.ad-logics.com
127.0.0.1 pn2.adserver.yahoo.com
127.0.0.1 pointclicktrack.com
127.0.0.1 pong.qubitproducts.com
127.0.0.1 postclick.adcentriconline.com
127.0.0.1 postgazettecollect.247realmedia.com
127.0.0.1 precisioncounter.com
127.0.0.1 printmail.biz
127.0.0.1 pro.hit.gemius.pl
127.0.0.1 prof.estat.com
127.0.0.1 proxy.ia2.marketscore.com
127.0.0.1 proxy.ia3.marketscore.com
127.0.0.1 proxy.ia4.marketscore.com
127.0.0.1 proxy.or3.marketscore.com
127.0.0.1 proxy.or4.marketscore.com
127.0.0.1 proxy.sj3.marketscore.com
127.0.0.1 proxy.sj4.marketscore.com
127.0.0.1 proxycfg.marketscore.com
127.0.0.1 quantserve.com #: Ad Tracking, JavaScript, etc.
127.0.0.1 quareclk.com
127.0.0.1 r.clickdensity.com
127.0.0.1 raw.oggifinogi.com
127.0.0.1 remotrk.com
127.0.0.1 rightmedia.net
127.0.0.1 rightstats.com
127.0.0.1 roskatrack.roskadirect.com
127.0.0.1 rr1.xxxcounter.com
127.0.0.1 rr2.xxxcounter.com
127.0.0.1 rr3.xxxcounter.com
127.0.0.1 rr4.xxxcounter.com
127.0.0.1 rr5.xxxcounter.com
127.0.0.1 rr7.xxxcounter.com
127.0.0.1 rts.pgmediaserve.com
127.0.0.1 rts.phn.doublepimp.com
127.0.0.1 s.clickability.com
127.0.0.1 s.statistici.ro
127.0.0.1 s.stats.wordpress.com
127.0.0.1 s.youtube.com
127.0.0.1 s1.shinystat.it
127.0.0.1 s1.thecounter.com
127.0.0.1 s10.histats.com
127.0.0.1 s10.sitemeter.com
127.0.0.1 s11.sitemeter.com
127.0.0.1 s12.sitemeter.com
127.0.0.1 s13.sitemeter.com
127.0.0.1 s14.sitemeter.com
127.0.0.1 s15.sitemeter.com
127.0.0.1 s16.sitemeter.com
127.0.0.1 s17.sitemeter.com
127.0.0.1 s18.sitemeter.com
127.0.0.1 s19.sitemeter.com
127.0.0.1 s2.statcounter.com
127.0.0.1 s2.youtube.com
127.0.0.1 s20.sitemeter.com
127.0.0.1 s21.sitemeter.com
127.0.0.1 s22.sitemeter.com
127.0.0.1 s23.sitemeter.com
127.0.0.1 s24.sitemeter.com
127.0.0.1 s25.sitemeter.com
127.0.0.1 s26.sitemeter.com
127.0.0.1 s27.sitemeter.com
127.0.0.1 s28.sitemeter.com
127.0.0.1 s29.sitemeter.com
127.0.0.1 s3.hit.stat.pl
127.0.0.1 s30.sitemeter.com
127.0.0.1 s31.sitemeter.com
127.0.0.1 s32.sitemeter.com
127.0.0.1 s33.sitemeter.com
127.0.0.1 s34.sitemeter.com
127.0.0.1 s35.sitemeter.com
127.0.0.1 s36.sitemeter.com
127.0.0.1 s37.sitemeter.com
127.0.0.1 s38.sitemeter.com
127.0.0.1 s39.sitemeter.com
127.0.0.1 s4.histats.com
127.0.0.1 s4.shinystat.com
127.0.0.1 s41.sitemeter.com
127.0.0.1 s42.sitemeter.com
127.0.0.1 s43.sitemeter.com
127.0.0.1 s44.sitemeter.com
127.0.0.1 s45.sitemeter.com
127.0.0.1 s46.sitemeter.com
127.0.0.1 s47.sitemeter.com
127.0.0.1 s48.sitemeter.com
127.0.0.1 scorecardresearch.com
127.0.0.1 scribe.twitter.com
127.0.0.1 scrooge.channelcincinnati.com
127.0.0.1 scrooge.channeloklahoma.com
127.0.0.1 scrooge.click10.com
127.0.0.1 scrooge.clickondetroit.com
127.0.0.1 scrooge.nbc11.com
127.0.0.1 scrooge.nbc4.com
127.0.0.1 scrooge.nbc4columbus.com
127.0.0.1 scrooge.nbcsandiego.com
127.0.0.1 scrooge.newsnet5.com
127.0.0.1 scrooge.thebostonchannel.com
127.0.0.1 scrooge.thedenverchannel.com
127.0.0.1 scrooge.theindychannel.com
127.0.0.1 scrooge.thekansascitychannel.com
127.0.0.1 scrooge.themilwaukeechannel.com
127.0.0.1 scrooge.theomahachannel.com
127.0.0.1 scrooge.wesh.com
127.0.0.1 scrooge.wftv.com
127.0.0.1 scrooge.wnbc.com
127.0.0.1 scrooge.wsoctv.com
127.0.0.1 scrooge.wtov9.com
127.0.0.1 sdc.rbistats.com
127.0.0.1 se.sitestat.com
127.0.0.1 searchadv.com
127.0.0.1 sekel.ch
127.0.0.1 servedby.valuead.com
127.0.0.1 server1.opentracker.net
127.0.0.1 server10.opentracker.net
127.0.0.1 server11.opentracker.net
127.0.0.1 server12.opentracker.net
127.0.0.1 server13.opentracker.net
127.0.0.1 server14.opentracker.net
127.0.0.1 server15.opentracker.net
127.0.0.1 server16.opentracker.net
127.0.0.1 server17.opentracker.net
127.0.0.1 server18.opentracker.net
127.0.0.1 server2.opentracker.net
127.0.0.1 server3.opentracker.net
127.0.0.1 server3.web-stat.com
127.0.0.1 server4.opentracker.net
127.0.0.1 server5.opentracker.net
127.0.0.1 server6.opentracker.net
127.0.0.1 server7.opentracker.net
127.0.0.1 server8.opentracker.net
127.0.0.1 server9.opentracker.net
127.0.0.1 service.bfast.com
127.0.0.1 services.krxd.net
127.0.0.1 sexcounter.com
127.0.0.1 seznam.hit.gemius.pl
127.0.0.1 showads.pubmatic.com
127.0.0.1 showcount.honest.com
127.0.0.1 sideshow.directtrack.com
127.0.0.1 sitestat.com
127.0.0.1 sitestats.tiscali.co.uk
127.0.0.1 sm1.sitemeter.com
127.0.0.1 sm2.sitemeter.com
127.0.0.1 sm3.sitemeter.com
127.0.0.1 sm4.sitemeter.com
127.0.0.1 sm5.sitemeter.com
127.0.0.1 sm6.sitemeter.com
127.0.0.1 sm7.sitemeter.com
127.0.0.1 sm8.sitemeter.com
127.0.0.1 sm9.sitemeter.com
127.0.0.1 smartstats.com
127.0.0.1 softcore.xxxcounter.com
127.0.0.1 sostats.mozilla.com
127.0.0.1 sovereign.sitetracker.com
127.0.0.1 spinbox.maccentral.com
127.0.0.1 spinbox.versiontracker.com
127.0.0.1 spklds.com
127.0.0.1 ss.tiscali.com
127.0.0.1 ss.tiscali.it
127.0.0.1 st.sageanalyst.net
127.0.0.1 st1.hit.gemius.pl
127.0.0.1 stags.peer39.net
127.0.0.1 stast2.gq.com
127.0.0.1 stat-counter.tass-online.ru
127.0.0.1 stat.4u.pl
127.0.0.1 stat.alibaba.com
127.0.0.1 stat.discogs.com
127.0.0.1 stat.netmonitor.fi
127.0.0.1 stat.onestat.com
127.0.0.1 stat.webmedia.pl
127.0.0.1 stat.www.fi
127.0.0.1 stat.yellowtracker.com
127.0.0.1 stat.youku.com
127.0.0.1 stat1.z-stat.com
127.0.0.1 stat3.cybermonitor.com
127.0.0.1 statcounter.com
127.0.0.1 static.kibboko.com
127.0.0.1 static.smni.com       # Santa Monica - popunders
127.0.0.1 statik.topica.com
127.0.0.1 statistics.dynamicsitestats.com
127.0.0.1 statistics.elsevier.nl
127.0.0.1 statistics.reedbusiness.nl
127.0.0.1 statistics.theonion.com
127.0.0.1 statistik-gallup.net
127.0.0.1 stats.24ways.org
127.0.0.1 stats.absol.co.za
127.0.0.1 stats.adbrite.com
127.0.0.1 stats.adotube.com
127.0.0.1 stats.adultswim.com
127.0.0.1 stats.airfarewatchdog.com
127.0.0.1 stats.allliquid.com
127.0.0.1 stats.askmen.com
127.0.0.1 stats.bbc.co.uk
127.0.0.1 stats.becu.org
127.0.0.1 stats.big-boards.com
127.0.0.1 stats.blogoscoop.net
127.0.0.1 stats.bonzaii.no
127.0.0.1 stats.break.com
127.0.0.1 stats.brides.com
127.0.0.1 stats.buysellads.com
127.0.0.1 stats.cafepress.com
127.0.0.1 stats.canalblog.com
127.0.0.1 stats.cartoonnetwork.com
127.0.0.1 stats.channel4.com
127.0.0.1 stats.clickability.com
127.0.0.1 stats.concierge.com
127.0.0.1 stats.cts-bv.nl
127.0.0.1 stats.darkbluesea.com
127.0.0.1 stats.datahjaelp.net
127.0.0.1 stats.directnic.com
127.0.0.1 stats.dziennik.pl
127.0.0.1 stats.economist.com
127.0.0.1 stats.epicurious.com
127.0.0.1 stats.examiner.com
127.0.0.1 stats.f-secure.com
127.0.0.1 stats.fairmont.com
127.0.0.1 stats.fastcompany.com
127.0.0.1 stats.foxcounter.com
127.0.0.1 stats.free-rein.net
127.0.0.1 stats.ft.com
127.0.0.1 stats.gamestop.com
127.0.0.1 stats.globesports.com
127.0.0.1 stats.groupninetyfour.com
127.0.0.1 stats.idsoft.com
127.0.0.1 stats.ign.com
127.0.0.1 stats.ilsemedia.nl
127.0.0.1 stats.independent.co.uk
127.0.0.1 stats.indexstats.com
127.0.0.1 stats.indextools.com
127.0.0.1 stats.investors.com
127.0.0.1 stats.iwebtrack.com
127.0.0.1 stats.jippii.com
127.0.0.1 stats.klsoft.com
127.0.0.1 stats.ladotstats.nl
127.0.0.1 stats.macworld.com
127.0.0.1 stats.magnify.net
127.0.0.1 stats.manticoretechnology.com
127.0.0.1 stats.mbamupdates.com
127.0.0.1 stats.millanusa.com
127.0.0.1 stats.nowpublic.com
127.0.0.1 stats.paycounter.com
127.0.0.1 stats.platinumbucks.com
127.0.0.1 stats.popscreen.com
127.0.0.1 stats.reinvigorate.net
127.0.0.1 stats.resellerratings.com
127.0.0.1 stats.revenue.net
127.0.0.1 stats.searchles.com
127.0.0.1 stats.ssa.gov
127.0.0.1 stats.superstats.com
127.0.0.1 stats.telegraph.co.uk
127.0.0.1 stats.thoughtcatalog.com
127.0.0.1 stats.townnews.com
127.0.0.1 stats.ultimate-webservices.com
127.0.0.1 stats.unionleader.com
127.0.0.1 stats.video.search.yahoo.com
127.0.0.1 stats.vodpod.com
127.0.0.1 stats.wordpress.com
127.0.0.1 stats.www.ibm.com
127.0.0.1 stats.yourminis.com
127.0.0.1 stats1.clicktracks.com
127.0.0.1 stats1.corusradio.com
127.0.0.1 stats1.in
127.0.0.1 stats2.clicktracks.com
127.0.0.1 stats2.gourmet.com
127.0.0.1 stats2.newyorker.com
127.0.0.1 stats2.rte.ie
127.0.0.1 stats2.unrulymedia.com
127.0.0.1 stats2.vanityfair.com
127.0.0.1 stats4all.com
127.0.0.1 stats5.lightningcast.com
127.0.0.1 stats6.lightningcast.net
127.0.0.1 statse.webtrendslive.com  # Fortune.com among others
127.0.0.1 stl.p.a1.traceworks.com
127.0.0.1 straighttangerine.cz.cc
127.0.0.1 sugoicounter.com
127.0.0.1 superstats.com
127.0.0.1 t2.hulu.com
127.0.0.1 tagging.outrider.com
127.0.0.1 talkcity.realtracker.com
127.0.0.1 targetnet.com
127.0.0.1 tates.freestats.com
127.0.0.1 tcookie.usatoday.com
127.0.0.1 tcr.tynt.com      # See http://daringfireball.net/2010/05/tynt_copy_paste_jerks
127.0.0.1 tgpcounter.freethumbnailgalleries.com
127.0.0.1 the-counter.net
127.0.0.1 the.sextracker.com
127.0.0.1 thecounter.com
127.0.0.1 themecounter.com
127.0.0.1 tipsurf.com
127.0.0.1 toolbarpartner.com
127.0.0.1 tools.spylog.ru
127.0.0.1 top.mail.ru
127.0.0.1 topstats.com
127.0.0.1 topstats.net
127.0.0.1 torstarcollect.247realmedia.com
127.0.0.1 tr.adinterax.com
127.0.0.1 track.adform.com
127.0.0.1 track.adform.net
127.0.0.1 track.did-it.com
127.0.0.1 track.directleads.com
127.0.0.1 track.domainsponsor.com
127.0.0.1 track.effiliation.com
127.0.0.1 track.exclusivecpa.com
127.0.0.1 track.ft.com
127.0.0.1 track.gawker.com
127.0.0.1 track.homestead.com
127.0.0.1 track.hulu.com
127.0.0.1 track.lfstmedia.com
127.0.0.1 track.mybloglog.com
127.0.0.1 track.omg2.com
127.0.0.1 track.roiservice.com
127.0.0.1 track.searchignite.com
127.0.0.1 track.webgains.com
127.0.0.1 track2.mybloglog.com
127.0.0.1 tracker.bonnint.net
127.0.0.1 tracker.clicktrade.com
127.0.0.1 tracker.idg.co.uk
127.0.0.1 tracker.mattel.com
127.0.0.1 tracker.netklix.com
127.0.0.1 tracker.tradedoubler.com
127.0.0.1 tracking.10e20.com
127.0.0.1 tracking.adjug.com
127.0.0.1 tracking.allposters.com
127.0.0.1 tracking.foxnews.com
127.0.0.1 tracking.iol.co.za
127.0.0.1 tracking.msadcenter.msn.com
127.0.0.1 tracking.oggifinogi.com
127.0.0.1 tracking.percentmobile.com
127.0.0.1 tracking.publicidees.com
127.0.0.1 tracking.quisma.com
127.0.0.1 tracking.rangeonlinemedia.com
127.0.0.1 tracking.searchmarketing.com
127.0.0.1 tracking.summitmedia.co.uk
127.0.0.1 tracking.trafficjunky.net
127.0.0.1 tracking.trutv.com
127.0.0.1 tracking.vindicosuite.com
127.0.0.1 tracksurf.daooda.com
127.0.0.1 tradedoubler.com
127.0.0.1 tradedoubler.sonvideopro.com
127.0.0.1 traffic-stats.streamsolutions.co.uk
127.0.0.1 trax.gamespot.com
127.0.0.1 trc.taboolasyndication.com
127.0.0.1 trk.kissmetrics.com
127.0.0.1 trk.tidaltv.com
127.0.0.1 true-counter.com
127.0.0.1 truehits1.gits.net.th
127.0.0.1 tu.connect.wunderloop.net
127.0.0.1 tynt.com
127.0.0.1 u1817.16.spylog.com
127.0.0.1 u3102.47.spylog.com
127.0.0.1 u3305.71.spylog.com
127.0.0.1 u3608.20.spylog.com
127.0.0.1 u4056.56.spylog.com
127.0.0.1 u432.77.spylog.com
127.0.0.1 u4396.79.spylog.com
127.0.0.1 u4443.84.spylog.com
127.0.0.1 u4556.11.spylog.com
127.0.0.1 u5234.87.spylog.com
127.0.0.1 u5234.98.spylog.com
127.0.0.1 u5687.48.spylog.com
127.0.0.1 u574.07.spylog.com
127.0.0.1 u604.41.spylog.com
127.0.0.1 u6762.46.spylog.com
127.0.0.1 u6905.71.spylog.com
127.0.0.1 u7748.16.spylog.com
127.0.0.1 u810.15.spylog.com
127.0.0.1 u920.31.spylog.com
127.0.0.1 u977.40.spylog.com
127.0.0.1 udc.msn.com
127.0.0.1 uk.cqcounter.com
127.0.0.1 uk.sitestat.com
127.0.0.1 ultimatecounter.com
127.0.0.1 us.2.cqcounter.com
127.0.0.1 us.cqcounter.com
127.0.0.1 usa.nedstat.net
127.0.0.1 v1.nedstatbasic.net
127.0.0.1 v7.stats.load.com
127.0.0.1 valueclick.com
127.0.0.1 valueclick.net
127.0.0.1 vertical-stats.huffpost.com
127.0.0.1 video-stats.video.google.com
127.0.0.1 vip.clickzs.com
127.0.0.1 virtualbartendertrack.beer.com
127.0.0.1 vis.sexlist.com
127.0.0.1 visit.theglobeandmail.com # Visits to theglobeandmail.com
127.0.0.1 voken.eyereturn.com
127.0.0.1 vs.dmtracker.com
127.0.0.1 vsii.spinbox.net
127.0.0.1 vsii.spindox.net
127.0.0.1 w1.tcr112.tynt.com
127.0.0.1 warlog.info
127.0.0.1 wau.tynt.com
127.0.0.1 web-counter.5u.com
127.0.0.1 web1.realtracker.com
127.0.0.1 web2.realtracker.com
127.0.0.1 web3.realtracker.com
127.0.0.1 web4.realtracker.com
127.0.0.1 webanalytics.globalthoughtz.com
127.0.0.1 webbug.seatreport.com # web bugs
127.0.0.1 webcounter.com
127.0.0.1 webcounter.goweb.de
127.0.0.1 webcounter.together.net
127.0.0.1 webhit.aftenposten.no
127.0.0.1 webhit.afterposten.no
127.0.0.1 webmasterkai.sitetracker.com
127.0.0.1 webpdp.gator.com  
127.0.0.1 webstat.channel4.com
127.0.0.1 webtrends.telenet.be
127.0.0.1 webtrends.thisis.co.uk
127.0.0.1 webtrends.townhall.com
127.0.0.1 wtnj.worldnow.com
127.0.0.1 www.0stats.com
127.0.0.1 www.123count.com
127.0.0.1 www.123counter.superstats.com
127.0.0.1 www.123stat.com
127.0.0.1 www.1quickclickrx.com
127.0.0.1 www.2001-007.com
127.0.0.1 www.3dstats.com
127.0.0.1 www.addfreecounter.com
127.0.0.1 www.addfreestats.com
127.0.0.1 www.ademails.com
127.0.0.1 www.affiliatesuccess.net
127.0.0.1 www.bar.ry2002.02-ry014.snpr.hotmx.hair.zaam.net # In spam
127.0.0.1 www.belstat.nl
127.0.0.1 www.betcounter.com
127.0.0.1 www.bigbadted.com
127.0.0.1 www.bluestreak.com
127.0.0.1 www.c.thecounter.de
127.0.0.1 www.c1.thecounter.de
127.0.0.1 www.c2.thecounter.de
127.0.0.1 www.clickclick.com
127.0.0.1 www.clickspring.net   #used by a spyware product called PurityScan
127.0.0.1 www.clixgalore.com
127.0.0.1 www.connectionlead.com
127.0.0.1 www.counter.bloke.com
127.0.0.1 www.counter.sexhound.nl
127.0.0.1 www.counter.superstats.com
127.0.0.1 www.counter1.sextracker.be
127.0.0.1 www.counter10.sextracker.be
127.0.0.1 www.counter11.sextracker.be
127.0.0.1 www.counter12.sextracker.be
127.0.0.1 www.counter13.sextracker.be
127.0.0.1 www.counter14.sextracker.be
127.0.0.1 www.counter15.sextracker.be
127.0.0.1 www.counter16.sextracker.be
127.0.0.1 www.counter2.sextracker.be
127.0.0.1 www.counter3.sextracker.be
127.0.0.1 www.counter4.sextracker.be
127.0.0.1 www.counter4all.com
127.0.0.1 www.counter4all.de
127.0.0.1 www.counter5.sextracker.be
127.0.0.1 www.counter6.sextracker.be
127.0.0.1 www.counter7.sextracker.be
127.0.0.1 www.counter8.sextracker.be
127.0.0.1 www.counter9.sextracker.be
127.0.0.1 www.counterguide.com
127.0.0.1 www.cw.nu
127.0.0.1 www.directgrowthhormone.com
127.0.0.1 www.dpbolvw.net
127.0.0.1 www.dwclick.com
127.0.0.1 www.easycounter.com
127.0.0.1 www.emaildeals.biz
127.0.0.1 www.estats4all.com
127.0.0.1 www.fastcounter.linkexchange.nl
127.0.0.1 www.foxcounter.com
127.0.0.1 www.freestats.com
127.0.0.1 www.fxcounters.com
127.0.0.1 www.gator.com
127.0.0.1 www.googkle.com
127.0.0.1 www.googletagservices.com
127.0.0.1 www.hitstats.co.uk
127.0.0.1 www.iccee.com
127.0.0.1 www.iesnare.com   # See http://www.codingthewheel.com/archives/online-gambling-privacy-iesnare
127.0.0.1 www.jellycounter.com
127.0.0.1 www.kqzyfj.com
127.0.0.1 www.leadpub.com
127.0.0.1 www.linkcounter.com
127.0.0.1 www.marketscore.com
127.0.0.1 www.megacounter.de
127.0.0.1 www.metareward.com        # web bugs in spam
127.0.0.1 www.naturalgrowthstore.biz
127.0.0.1 www.nedstat.com
127.0.0.1 www.nextgenstats.com
127.0.0.1 www.ntsearch.com
127.0.0.1 www.onestat.com
127.0.0.1 www.originalicons.com # installs IE extension
127.0.0.1 www.paycounter.com
127.0.0.1 www.pointclicktrack.com
127.0.0.1 www.popuptrafic.com
127.0.0.1 www.precisioncounter.com
127.0.0.1 www.premiumsmail.net
127.0.0.1 www.printmail.biz
127.0.0.1 www.quantserve.com #: Ad Tracking, JavaScript, etc.
127.0.0.1 www.quareclk.com
127.0.0.1 www.remotrk.com
127.0.0.1 www.rightmedia.net
127.0.0.1 www.rightstats.com
127.0.0.1 www.searchadv.com
127.0.0.1 www.sekel.ch
127.0.0.1 www.shockcounter.com
127.0.0.1 www.simplecounter.net
127.0.0.1 www.specificclick.com
127.0.0.1 www.specificpop.com
127.0.0.1 www.spklds.com
127.0.0.1 www.statcount.com
127.0.0.1 www.statcounter.com
127.0.0.1 www.statsession.com
127.0.0.1 www.stattrax.com
127.0.0.1 www.stiffnetwork.com
127.0.0.1 www.testracking.com
127.0.0.1 www.the-counter.net
127.0.0.1 www.thecounter.com
127.0.0.1 www.toolbarcounter.com
127.0.0.1 www.tradedoubler.com
127.0.0.1 www.tradedoubler.com.ar
127.0.0.1 www.trafficmagnet.net # web bugs in spam
127.0.0.1 www.trafic.ro
127.0.0.1 www.trendcounter.com
127.0.0.1 www.true-counter.com
127.0.0.1 www.tynt.com
127.0.0.1 www.ultimatecounter.com
127.0.0.1 www.v61.com
127.0.0.1 www.web-stat.com
127.0.0.1 www.webcounter.com
127.0.0.1 www.webstat.com
127.0.0.1 www.whereugetxxx.com
127.0.0.1 www.xxxcounter.com
127.0.0.1 www1.addfreestats.com
127.0.0.1 www1.counter.bloke.com
127.0.0.1 www1.tynt.com
127.0.0.1 www101.coolsavings.com
127.0.0.1 www2.addfreestats.com
127.0.0.1 www2.counter.bloke.com
127.0.0.1 www2.pagecount.com
127.0.0.1 www3.addfreestats.com
127.0.0.1 www3.click-fr.com
127.0.0.1 www3.counter.bloke.com
127.0.0.1 www4.addfreestats.com
127.0.0.1 www4.counter.bloke.com
127.0.0.1 www5.addfreestats.com
127.0.0.1 www5.counter.bloke.com
127.0.0.1 www6.addfreestats.com
127.0.0.1 www6.click-fr.com
127.0.0.1 www6.counter.bloke.com
127.0.0.1 www60.valueclick.com
127.0.0.1 www7.addfreestats.com
127.0.0.1 www7.counter.bloke.com
127.0.0.1 www8.addfreestats.com
127.0.0.1 www8.counter.bloke.com
127.0.0.1 www9.counter.bloke.com
127.0.0.1 x.cb.kount.com
127.0.0.1 xcnn.com
127.0.0.1 xxxcounter.com
127.0.0.1 xyz.freelogs.com
127.0.0.1 zz.cqcounter.com
#</spyware-sites>
#<malware-sites>

# sites with known trojans, phishing, or other malware
127.0.0.1 05tz2e9.com
127.0.0.1 09killspyware.com
127.0.0.1 11398.onceedge.ru
127.0.0.1 20-yrs-1.info
127.0.0.1 2006mindfreaklike.blogspot.com    # Facebook trojan
127.0.0.1 59-106-20-39.r-bl100.sakura.ne.jp
127.0.0.1 662bd114b7c9.onceedge.ru
127.0.0.1 BonusCashh.com
127.0.0.1 Iframecash.biz
127.0.0.1 TheBizMeet.com
127.0.0.1 a.oix.com
127.0.0.1 a.oix.net
127.0.0.1 a.webwise.com
127.0.0.1 a.webwise.net
127.0.0.1 a.webwise.org
127.0.0.1 a15172379.alturo-server.de
127.0.0.1 abetterinternet.com
127.0.0.1 abruzzoinitaly.co.uk
127.0.0.1 acglgoa.com
127.0.0.1 acim.moqhixoz.cn
127.0.0.1 adexprts.com
127.0.0.1 adshufffle.com
127.0.0.1 adwitty.com
127.0.0.1 adwords.google.lloymlincs.com
127.0.0.1 afantispy.com
127.0.0.1 afdbande.cn
127.0.0.1 allhqpics.com             # Facebook trojan
127.0.0.1 alphabirdnetwork.com
127.0.0.1 antispywareexpert.com
127.0.0.1 antitero.tk
127.0.0.1 antivirus-online-scan5.com
127.0.0.1 antivirus-scanner.com
127.0.0.1 antivirus-scanner8.com
127.0.0.1 armsart.com
127.0.0.1 articlefuns.cn
127.0.0.1 articleidea.cn
127.0.0.1 asianread.com
127.0.0.1 autohipnose.com
127.0.0.1 b.oix.com
127.0.0.1 b.oix.net
127.0.0.1 b.webwise.com
127.0.0.1 b.webwise.net
127.0.0.1 b.webwise.org
127.0.0.1 binsservicesonline.info
127.0.0.1 blackhat.be
127.0.0.1 blenz-me.net
127.0.0.1 bnvxcfhdgf.blogspot.com.es
127.0.0.1 brunga.at # Facebook phishing attempt
127.0.0.1 bt.webwise.com
127.0.0.1 bt.webwise.net
127.0.0.1 bt.webwise.org
127.0.0.1 c.oix.com
127.0.0.1 c.oix.net
127.0.0.1 c.webwise.com
127.0.0.1 c.webwise.net
127.0.0.1 c.webwise.org
127.0.0.1 callawaypos.com
127.0.0.1 callbling.com
127.0.0.1 cambonanza.com
127.0.0.1 ccudl.com
127.0.0.1 changduk26.com            # Facebook trojan
127.0.0.1 chelick.net               # Facebook trojan
127.0.0.1 cira.login.cqr.ssl.igotmyloverback.com
127.0.0.1 cleanchain.net
127.0.0.1 click.get-answers-fast.com
127.0.0.1 clien.net
127.0.0.1 clk.relestar.com
127.0.0.1 cnbc.com-article906773.us
127.0.0.1 co8vd.cn
127.0.0.1 cra-arc-gc-ca.noads.biz
127.0.0.1 custom3hurricanedigitalmedia.com
127.0.0.1 dbios.org
127.0.0.1 dhauzja511.co.cc
127.0.0.1 dietpharmacyrx.net
127.0.0.1 download.abetterinternet.com
127.0.0.1 drc-group.net
127.0.0.1 dubstep.onedumb.com
127.0.0.1 e-kasa.w8w.pl
127.0.0.1 east.05tz2e9.com
127.0.0.1 en.likefever.org          # Facebook trojan
127.0.0.1 enteryouremail.net
127.0.0.1 eviboli576.o-f.com
127.0.0.1 facebook-repto1040s2.ahlamountada.com
127.0.0.1 faceboook-replyei0ki.montadalitihad.com
127.0.0.1 facemail.com
127.0.0.1 faggotry.com
127.0.0.1 familyupport1.com
127.0.0.1 feaecebook.com
127.0.0.1 fengyixin.com
127.0.0.1 filosvybfimpsv.ru.gg
127.0.0.1 froling.bee.pl
127.0.0.1 fromru.su
127.0.0.1 ftdownload.com
127.0.0.1 fu.golikeus.net           # Facebook trojan
127.0.0.1 gamelights.ru
127.0.0.1 gasasthe.freehostia.com
127.0.0.1 get-answers-fast.com
127.0.0.1 gglcash4u.info    # twitter worm
127.0.0.1 girlownedbypolicelike.blogspot.com    # Facebook trojan
127.0.0.1 goggle.com
127.0.0.1 gyros.es
127.0.0.1 h1317070.stratoserver.net
127.0.0.1 hackerz.ir
127.0.0.1 hakerzy.net
127.0.0.1 hatrecord.ru              # Facebook trojan
127.0.0.1 hellwert.biz
127.0.0.1 hotchix.servepics.com
127.0.0.1 hsb-canada.com    # phishing site for hsbc.ca
127.0.0.1 hsbconline.ca     # phishing site for hsbc.ca
127.0.0.1 icecars.com
127.0.0.1 idea21.org
127.0.0.1 infopaypal.com
127.0.0.1 ipadzu.net
127.0.0.1 ircleaner.com
127.0.0.1 itwititer.com
127.0.0.1 ity.elusmedic.ru
127.0.0.1 jajajaj-thats-you-really.com
127.0.0.1 janezk.50webs.co
127.0.0.1 jujitsu-ostrava.info
127.0.0.1 jump.ewoss.net
127.0.0.1 juste.ru  # Twitter trojan
127.0.0.1 kczambians.com
127.0.0.1 kirgo.at  # Facebook phishing attempt
127.0.0.1 klowns4phun.com
127.0.0.1 konflow.com               # Facebook trojan
127.0.0.1 kplusd.far.ru
127.0.0.1 kpremium.com
127.0.0.1 lank.ru
127.0.0.1 lighthouse2k.com
127.0.0.1 like.likewut.net
127.0.0.1 likeportal.com            # Facebook trojan
127.0.0.1 likespike.com             # Facebook trojan
127.0.0.1 likethis.mbosoft.com          # Facebook trojan
127.0.0.1 likethislist.biz          # Facebook trojan
127.0.0.1 loseweight.asdjiiw.com
127.0.0.1 lucibad.home.ro
127.0.0.1 luxcart.ro
127.0.0.1 m01.oix.com
127.0.0.1 m01.oix.net
127.0.0.1 m01.webwise.com
127.0.0.1 m01.webwise.net
127.0.0.1 m01.webwise.org
127.0.0.1 m02.oix.com
127.0.0.1 m02.oix.net
127.0.0.1 m02.webwise.com
127.0.0.1 m02.webwise.net
127.0.0.1 m02.webwise.org
127.0.0.1 mail.cyberh.fr
127.0.0.1 malware-live-pro-scanv1.com
127.0.0.1 maxi4.firstvds.ru
127.0.0.1 monkeyball.osa.pl
127.0.0.1 movies.701pages.com
127.0.0.1 mplayerdownloader.com
127.0.0.1 murcia-ban.es
127.0.0.1 mylike.co.uk              # Facebook trojan
127.0.0.1 nactx.com
127.0.0.1 natashyabaydesign.com
127.0.0.1 new-dating-2012.info
127.0.0.1 new-vid-zone-1.blogspot.com.au
127.0.0.1 newwayscanner.info
127.0.0.1 novemberrainx.com
127.0.0.1 ns1.oix.com
127.0.0.1 ns1.oix.net
127.0.0.1 ns1.webwise.com
127.0.0.1 ns1.webwise.net
127.0.0.1 ns1.webwise.org
127.0.0.1 ns2.oix.com
127.0.0.1 ns2.oix.net
127.0.0.1 ns2.webwise.com
127.0.0.1 ns2.webwise.net
127.0.0.1 ns2.webwise.org
127.0.0.1 nufindings.info
127.0.0.1 office.officenet.co.kr
127.0.0.1 oix.com
127.0.0.1 oix.net
127.0.0.1 oj.likewut.net
127.0.0.1 online-antispym4.com
127.0.0.1 oo-na-na-pics.com
127.0.0.1 ordersildenafil.com
127.0.0.1 otsserver.com
127.0.0.1 outerinfo.com
127.0.0.1 paincake.yoll.net
127.0.0.1 pc-scanner16.com
127.0.0.1 personalantispy.com
127.0.0.1 phatthalung.go.th
127.0.0.1 picture-uploads.com
127.0.0.1 pilltabletsrxbargain.net
127.0.0.1 powabcyfqe.com
127.0.0.1 premium-live-scan.com
127.0.0.1 privitize.com
127.0.0.1 products-gold.net
127.0.0.1 proflashdata.com          # Facebook trojan
127.0.0.1 protectionupdatecenter.com
127.0.0.1 pv.wantsfly.com
127.0.0.1 qip.ru
127.0.0.1 qy.corrmedic.ru
127.0.0.1 rd.alphabirdnetwork.com
127.0.0.1 rickrolling.com
127.0.0.1 roifmd.info
127.0.0.1 russian-sex.com
127.0.0.1 s4d.in
127.0.0.1 sc-spyware.com
127.0.0.1 scan.antispyware-free-scanner.com
127.0.0.1 scanner.best-click-av1.info
127.0.0.1 scanner.best-protect.info
127.0.0.1 scottishstuff-online.com  # Canadian bank phishing site
127.0.0.1 securedliveuploads.com
127.0.0.1 securityandroidupdate.dinamikaprinting.com
127.0.0.1 securityscan.us
127.0.0.1 sexymarissa.net
127.0.0.1 shell.xhhow4.com
127.0.0.1 shop.skin-safety.com
127.0.0.1 signin-ebay-com-ws-ebayisapi-dll-signin-webscr.ocom.pl
127.0.0.1 sinera.org
127.0.0.1 smile-angel.com
127.0.0.1 software-wenc.co.cc
127.0.0.1 someonewhocares.com
127.0.0.1 sousay.info
127.0.0.1 start.qip.ru
127.0.0.1 superegler.net
127.0.0.1 supernaturalart.com
127.0.0.1 superprotection10.com
127.0.0.1 sverd.net
127.0.0.1 tattooshaha.info          # Facebook trojan
127.0.0.1 test.ishvara-yoga.com
127.0.0.1 thedatesafe.com           # Facebook trojan
127.0.0.1 themoneyclippodcast.com
127.0.0.1 themusicnetwork.co.uk
127.0.0.1 thinstall.abetterinternet.com
127.0.0.1 tivvitter.com
127.0.0.1 tomorrownewstoday.com # I am not sure what it does, but it seems to be associated with a phishing attempt on Facebook
127.0.0.1 toolbarbest.biz
127.0.0.1 toolbarbucks.biz
127.0.0.1 toolbarcool.biz
127.0.0.1 toolbardollars.biz
127.0.0.1 toolbarmoney.biz
127.0.0.1 toolbarnew.biz
127.0.0.1 toolbarsale.biz
127.0.0.1 toolbarweb.biz
127.0.0.1 traffic.adwitty.com
127.0.0.1 trafsearchonline.com
127.0.0.1 trialreg.com
127.0.0.1 tvshowslist.com
127.0.0.1 twitter.login.kevanshome.org
127.0.0.1 twitter.secure.bzpharma.net
127.0.0.1 uawj.moqhixoz.cn
127.0.0.1 ughmvqf.spitt.ru
127.0.0.1 uqz.com
127.0.0.1 utenti.lycos.it
127.0.0.1 vcipo.info
127.0.0.1 videos.dskjkiuw.com
127.0.0.1 videos.twitter.secure-logins01.com # twitter worm (http://mashable.com/2009/09/23/twitter-worm-dms/)
127.0.0.1 vxiframe.biz
127.0.0.1 weblover.info
127.0.0.1 webpaypal.com
127.0.0.1 webwise.com
127.0.0.1 webwise.net
127.0.0.1 webwise.org
127.0.0.1 west.05tz2e9.com
127.0.0.1 wewillrocknow.com
127.0.0.1 willysy.com
127.0.0.1 wm.maxysearch.info
127.0.0.1 womo.corrmedic.ru
127.0.0.1 www.abetterinternet.com
127.0.0.1 www.adshufffle.com
127.0.0.1 www.adwords.google.lloymlincs.com
127.0.0.1 www.afantispy.com
127.0.0.1 www.akoneplatit.sk
127.0.0.1 www.allhqpics.com         # Facebook trojan
127.0.0.1 www.antitero.tk
127.0.0.1 www.articlefuns.cn
127.0.0.1 www.articleidea.cn
127.0.0.1 www.asianread.com
127.0.0.1 www.backsim.ru
127.0.0.1 www.bankofamerica.com.ok.am
127.0.0.1 www.be4life.ru
127.0.0.1 www.blenz-me.net
127.0.0.1 www.cambonanza.com
127.0.0.1 www.chelick.net           # Facebook trojan
127.0.0.1 www.didata.bw
127.0.0.1 www.dietsecret.ru
127.0.0.1 www.eroyear.ru
127.0.0.1 www.exbays.com
127.0.0.1 www.faggotry.com
127.0.0.1 www.feaecebook.com
127.0.0.1 www.fictioncinema.com
127.0.0.1 www.fischereszter.hu
127.0.0.1 www.froling.bee.pl
127.0.0.1 www.gns-consola.com
127.0.0.1 www.goggle.com
127.0.0.1 www.grouphappy.com
127.0.0.1 www.hakerzy.net
127.0.0.1 www.haoyunlaid.com
127.0.0.1 www.icecars.com
127.0.0.1 www.indesignstudioinfo.com
127.0.0.1 www.infopaypal.com
127.0.0.1 www.kinomarathon.ru
127.0.0.1 www.kpremium.com
127.0.0.1 www.likeportal.com            # Facebook trojan
127.0.0.1 www.likespike.com         # Facebook trojan
127.0.0.1 www.likethis.mbosoft.com      # Facebook trojan
127.0.0.1 www.likethislist.biz          # Facebook trojan
127.0.0.1 www.lomalindasda.org          # Facebook trojan
127.0.0.1 www.lovecouple.ru
127.0.0.1 www.lovetrust.ru
127.0.0.1 www.mikras.nl
127.0.0.1 www.monkeyball.osa.pl
127.0.0.1 www.monsonis.net
127.0.0.1 www.movie-port.ru
127.0.0.1 www.mplayerdownloader.com
127.0.0.1 www.mylike.co.uk          # Facebook trojan
127.0.0.1 www.mylovecards.com
127.0.0.1 www.nine2rack.in
127.0.0.1 www.novemberrainx.com
127.0.0.1 www.nu26.com
127.0.0.1 www.oix.com
127.0.0.1 www.oix.net
127.0.0.1 www.onlyfreeoffersonline.com
127.0.0.1 www.otsserver.com
127.0.0.1 www.pay-pal.com-cgibin-canada.4mcmeta4v.cn
127.0.0.1 www.picture-uploads.com
127.0.0.1 www.portaldimensional.com
127.0.0.1 www.poxudeli.ru
127.0.0.1 www.proflashdata.com          # Facebook trojan
127.0.0.1 www.rickrolling.com
127.0.0.1 www.russian-sex.com
127.0.0.1 www.scotiaonline.scotiabank.salferreras.com
127.0.0.1 www.sdlpgift.com
127.0.0.1 www.securityscan.us
127.0.0.1 www.servertasarimbu.com
127.0.0.1 www.sexytiger.ru
127.0.0.1 www.shinilchurch.net  # domain was hacked and had a trojan installed
127.0.0.1 www.sinera.org
127.0.0.1 www.someonewhocares.com
127.0.0.1 www.tanger.com.br
127.0.0.1 www.tattooshaha.info          # Facebook trojan
127.0.0.1 www.te81.net
127.0.0.1 www.thedatesafe.com           # Facebook trojan
127.0.0.1 www.trafsearchonline.com
127.0.0.1 www.trucktirehotline.com
127.0.0.1 www.tvshowslist.com
127.0.0.1 www.upi6.pillsstore-c.com     # Facebook trojan
127.0.0.1 www.uqz.com
127.0.0.1 www.via99.org
127.0.0.1 www.videolove.clanteam.com
127.0.0.1 www.videostan.ru
127.0.0.1 www.vippotexa.ru
127.0.0.1 www.wantsfly.com
127.0.0.1 www.webpaypal.com
127.0.0.1 www.webwise.com
127.0.0.1 www.webwise.net
127.0.0.1 www.webwise.org
127.0.0.1 www.wewillrocknow.com
127.0.0.1 www.willysy.com
127.0.0.1 www1.firesavez5.com
127.0.0.1 www1.firesavez6.com
127.0.0.1 www1.realsoft34.com
127.0.0.1 www4.gy7k.net
127.0.0.1 xfotosx01.fromru.su
127.0.0.1 xponlinescanner.com
127.0.0.1 xvrxyzba253.hotmail.ru
127.0.0.1 yrwap.cn
127.0.0.1 zarozinski.info
127.0.0.1 zettapetta.com
127.0.0.1 zfotos.fromru.su
127.0.0.1 zip.er.cz
127.0.0.1 ztrf.net
127.0.0.1 zviframe.biz
#</malware-sites>

#<doubleclick-sites>

127.0.0.1 3ad.doubleclick.net
127.0.0.1 ad-emea.doubleclick.net
127.0.0.1 ad-g.doubleclick.net
127.0.0.1 ad-yt-bfp.doubleclick.net
127.0.0.1 ad.3au.doubleclick.net
127.0.0.1 ad.ae.doubleclick.net
127.0.0.1 ad.au.doubleclick.net
127.0.0.1 ad.be.doubleclick.net
127.0.0.1 ad.br.doubleclick.net
127.0.0.1 ad.de.doubleclick.net
127.0.0.1 ad.dk.doubleclick.net
127.0.0.1 ad.es.doubleclick.net
127.0.0.1 ad.fi.doubleclick.net
127.0.0.1 ad.fr.doubleclick.net
127.0.0.1 ad.it.doubleclick.net
127.0.0.1 ad.jp.doubleclick.net
127.0.0.1 ad.mo.doubleclick.net
127.0.0.1 ad.n2434.doubleclick.net
127.0.0.1 ad.nl.doubleclick.net
127.0.0.1 ad.no.doubleclick.net
127.0.0.1 ad.nz.doubleclick.net
127.0.0.1 ad.pl.doubleclick.net
127.0.0.1 ad.se.doubleclick.net
127.0.0.1 ad.sg.doubleclick.net
127.0.0.1 ad.uk.doubleclick.net
127.0.0.1 ad.ve.doubleclick.net
127.0.0.1 ad.za.doubleclick.net
127.0.0.1 ad2.doubleclick.net
127.0.0.1 amn.doubleclick.net
127.0.0.1 creative.cc-dt.com
127.0.0.1 doubleclick.com
127.0.0.1 doubleclick.de
127.0.0.1 doubleclick.net
127.0.0.1 ebaycn.doubleclick.net
127.0.0.1 ebaytw.doubleclick.net
127.0.0.1 exnjadgda1.doubleclick.net
127.0.0.1 exnjadgda2.doubleclick.net
127.0.0.1 exnjadgds1.doubleclick.net
127.0.0.1 exnjmdgda1.doubleclick.net
127.0.0.1 exnjmdgds1.doubleclick.net
127.0.0.1 feedads.g.doubleclick.net
127.0.0.1 fls.doubleclick.net
127.0.0.1 gd1.doubleclick.net
127.0.0.1 gd10.doubleclick.net
127.0.0.1 gd11.doubleclick.net
127.0.0.1 gd12.doubleclick.net
127.0.0.1 gd13.doubleclick.net
127.0.0.1 gd14.doubleclick.net
127.0.0.1 gd15.doubleclick.net
127.0.0.1 gd16.doubleclick.net
127.0.0.1 gd17.doubleclick.net
127.0.0.1 gd18.doubleclick.net
127.0.0.1 gd19.doubleclick.net
127.0.0.1 gd2.doubleclick.net
127.0.0.1 gd20.doubleclick.net
127.0.0.1 gd21.doubleclick.net
127.0.0.1 gd22.doubleclick.net
127.0.0.1 gd23.doubleclick.net
127.0.0.1 gd24.doubleclick.net
127.0.0.1 gd25.doubleclick.net
127.0.0.1 gd26.doubleclick.net
127.0.0.1 gd27.doubleclick.net
127.0.0.1 gd28.doubleclick.net
127.0.0.1 gd29.doubleclick.net
127.0.0.1 gd3.doubleclick.net
127.0.0.1 gd30.doubleclick.net
127.0.0.1 gd31.doubleclick.net
127.0.0.1 gd4.doubleclick.net
127.0.0.1 gd5.doubleclick.net
127.0.0.1 gd7.doubleclick.net
127.0.0.1 gd8.doubleclick.net
127.0.0.1 gd9.doubleclick.net
127.0.0.1 googleads.g.doubleclick.net
127.0.0.1 iv.doubleclick.net
127.0.0.1 ln.doubleclick.net
127.0.0.1 m.2mdn.net
127.0.0.1 m.de.2mdn.net
127.0.0.1 m.doubleclick.net
127.0.0.1 m1.2mdn.net
127.0.0.1 m1.ae.2mdn.net
127.0.0.1 m1.au.2mdn.net
127.0.0.1 m1.be.2mdn.net
127.0.0.1 m1.br.2mdn.net
127.0.0.1 m1.ca.2mdn.net
127.0.0.1 m1.cn.2mdn.net
127.0.0.1 m1.de.2mdn.net
127.0.0.1 m1.dk.2mdn.net
127.0.0.1 m1.doubleclick.net
127.0.0.1 m1.es.2mdn.net
127.0.0.1 m1.fi.2mdn.net
127.0.0.1 m1.fr.2mdn.net
127.0.0.1 m1.it.2mdn.net
127.0.0.1 m1.jp.2mdn.net
127.0.0.1 m1.nl.2mdn.net
127.0.0.1 m1.no.2mdn.net
127.0.0.1 m1.nz.2mdn.net
127.0.0.1 m1.pl.2mdn.net
127.0.0.1 m1.se.2mdn.net
127.0.0.1 m1.sg.2mdn.net
127.0.0.1 m1.uk.2mdn.net
127.0.0.1 m1.ve.2mdn.net
127.0.0.1 m1.za.2mdn.net
127.0.0.1 m2.ae.2mdn.net
127.0.0.1 m2.au.2mdn.net
127.0.0.1 m2.be.2mdn.net
127.0.0.1 m2.br.2mdn.net
127.0.0.1 m2.ca.2mdn.net
127.0.0.1 m2.cn.2mdn.net
127.0.0.1 m2.cn.doubleclick.net
127.0.0.1 m2.de.2mdn.net
127.0.0.1 m2.dk.2mdn.net
127.0.0.1 m2.doubleclick.net
127.0.0.1 m2.es.2mdn.net
127.0.0.1 m2.fi.2mdn.net
127.0.0.1 m2.fr.2mdn.net
127.0.0.1 m2.it.2mdn.net
127.0.0.1 m2.jp.2mdn.net
127.0.0.1 m2.nl.2mdn.net
127.0.0.1 m2.no.2mdn.net
127.0.0.1 m2.nz.2mdn.net
127.0.0.1 m2.pl.2mdn.net
127.0.0.1 m2.se.2mdn.net
127.0.0.1 m2.sg.2mdn.net
127.0.0.1 m2.uk.2mdn.net
127.0.0.1 m2.ve.2mdn.net
127.0.0.1 m2.za.2mdn.net
127.0.0.1 m3.ae.2mdn.net
127.0.0.1 m3.au.2mdn.net
127.0.0.1 m3.be.2mdn.net
127.0.0.1 m3.br.2mdn.net
127.0.0.1 m3.ca.2mdn.net
127.0.0.1 m3.cn.2mdn.net
127.0.0.1 m3.de.2mdn.net
127.0.0.1 m3.dk.2mdn.net
127.0.0.1 m3.doubleclick.net
127.0.0.1 m3.es.2mdn.net
127.0.0.1 m3.fi.2mdn.net
127.0.0.1 m3.fr.2mdn.net
127.0.0.1 m3.it.2mdn.net
127.0.0.1 m3.jp.2mdn.net
127.0.0.1 m3.nl.2mdn.net
127.0.0.1 m3.no.2mdn.net
127.0.0.1 m3.nz.2mdn.net
127.0.0.1 m3.pl.2mdn.net
127.0.0.1 m3.se.2mdn.net
127.0.0.1 m3.sg.2mdn.net
127.0.0.1 m3.uk.2mdn.net
127.0.0.1 m3.ve.2mdn.net
127.0.0.1 m3.za.2mdn.net
127.0.0.1 m4.ae.2mdn.net
127.0.0.1 m4.au.2mdn.net
127.0.0.1 m4.be.2mdn.net
127.0.0.1 m4.br.2mdn.net
127.0.0.1 m4.ca.2mdn.net
127.0.0.1 m4.cn.2mdn.net
127.0.0.1 m4.de.2mdn.net
127.0.0.1 m4.dk.2mdn.net
127.0.0.1 m4.doubleclick.net
127.0.0.1 m4.es.2mdn.net
127.0.0.1 m4.fi.2mdn.net
127.0.0.1 m4.fr.2mdn.net
127.0.0.1 m4.it.2mdn.net
127.0.0.1 m4.jp.2mdn.net
127.0.0.1 m4.nl.2mdn.net
127.0.0.1 m4.no.2mdn.net
127.0.0.1 m4.nz.2mdn.net
127.0.0.1 m4.pl.2mdn.net
127.0.0.1 m4.se.2mdn.net
127.0.0.1 m4.sg.2mdn.net
127.0.0.1 m4.uk.2mdn.net
127.0.0.1 m4.ve.2mdn.net
127.0.0.1 m4.za.2mdn.net
127.0.0.1 m5.ae.2mdn.net
127.0.0.1 m5.au.2mdn.net
127.0.0.1 m5.be.2mdn.net
127.0.0.1 m5.br.2mdn.net
127.0.0.1 m5.ca.2mdn.net
127.0.0.1 m5.cn.2mdn.net
127.0.0.1 m5.de.2mdn.net
127.0.0.1 m5.dk.2mdn.net
127.0.0.1 m5.doubleclick.net
127.0.0.1 m5.es.2mdn.net
127.0.0.1 m5.fi.2mdn.net
127.0.0.1 m5.fr.2mdn.net
127.0.0.1 m5.it.2mdn.net
127.0.0.1 m5.jp.2mdn.net
127.0.0.1 m5.nl.2mdn.net
127.0.0.1 m5.no.2mdn.net
127.0.0.1 m5.nz.2mdn.net
127.0.0.1 m5.pl.2mdn.net
127.0.0.1 m5.se.2mdn.net
127.0.0.1 m5.sg.2mdn.net
127.0.0.1 m5.uk.2mdn.net
127.0.0.1 m5.ve.2mdn.net
127.0.0.1 m5.za.2mdn.net
127.0.0.1 m6.ae.2mdn.net
127.0.0.1 m6.au.2mdn.net
127.0.0.1 m6.be.2mdn.net
127.0.0.1 m6.br.2mdn.net
127.0.0.1 m6.ca.2mdn.net
127.0.0.1 m6.cn.2mdn.net
127.0.0.1 m6.de.2mdn.net
127.0.0.1 m6.dk.2mdn.net
127.0.0.1 m6.doubleclick.net
127.0.0.1 m6.es.2mdn.net
127.0.0.1 m6.fi.2mdn.net
127.0.0.1 m6.fr.2mdn.net
127.0.0.1 m6.it.2mdn.net
127.0.0.1 m6.jp.2mdn.net
127.0.0.1 m6.nl.2mdn.net
127.0.0.1 m6.no.2mdn.net
127.0.0.1 m6.nz.2mdn.net
127.0.0.1 m6.pl.2mdn.net
127.0.0.1 m6.se.2mdn.net
127.0.0.1 m6.sg.2mdn.net
127.0.0.1 m6.uk.2mdn.net
127.0.0.1 m6.ve.2mdn.net
127.0.0.1 m6.za.2mdn.net
127.0.0.1 m7.ae.2mdn.net
127.0.0.1 m7.au.2mdn.net
127.0.0.1 m7.be.2mdn.net
127.0.0.1 m7.br.2mdn.net
127.0.0.1 m7.ca.2mdn.net
127.0.0.1 m7.cn.2mdn.net
127.0.0.1 m7.de.2mdn.net
127.0.0.1 m7.dk.2mdn.net
127.0.0.1 m7.doubleclick.net
127.0.0.1 m7.es.2mdn.net
127.0.0.1 m7.fi.2mdn.net
127.0.0.1 m7.fr.2mdn.net
127.0.0.1 m7.it.2mdn.net
127.0.0.1 m7.jp.2mdn.net
127.0.0.1 m7.nl.2mdn.net
127.0.0.1 m7.no.2mdn.net
127.0.0.1 m7.nz.2mdn.net
127.0.0.1 m7.pl.2mdn.net
127.0.0.1 m7.se.2mdn.net
127.0.0.1 m7.sg.2mdn.net
127.0.0.1 m7.uk.2mdn.net
127.0.0.1 m7.ve.2mdn.net
127.0.0.1 m7.za.2mdn.net
127.0.0.1 m8.ae.2mdn.net
127.0.0.1 m8.au.2mdn.net
127.0.0.1 m8.be.2mdn.net
127.0.0.1 m8.br.2mdn.net
127.0.0.1 m8.ca.2mdn.net
127.0.0.1 m8.cn.2mdn.net
127.0.0.1 m8.de.2mdn.net
127.0.0.1 m8.dk.2mdn.net
127.0.0.1 m8.doubleclick.net
127.0.0.1 m8.es.2mdn.net
127.0.0.1 m8.fi.2mdn.net
127.0.0.1 m8.fr.2mdn.net
127.0.0.1 m8.it.2mdn.net
127.0.0.1 m8.jp.2mdn.net
127.0.0.1 m8.nl.2mdn.net
127.0.0.1 m8.no.2mdn.net
127.0.0.1 m8.nz.2mdn.net
127.0.0.1 m8.pl.2mdn.net
127.0.0.1 m8.se.2mdn.net
127.0.0.1 m8.sg.2mdn.net
127.0.0.1 m8.uk.2mdn.net
127.0.0.1 m8.ve.2mdn.net
127.0.0.1 m8.za.2mdn.net
127.0.0.1 m9.ae.2mdn.net
127.0.0.1 m9.au.2mdn.net
127.0.0.1 m9.be.2mdn.net
127.0.0.1 m9.br.2mdn.net
127.0.0.1 m9.ca.2mdn.net
127.0.0.1 m9.cn.2mdn.net
127.0.0.1 m9.de.2mdn.net
127.0.0.1 m9.dk.2mdn.net
127.0.0.1 m9.doubleclick.net
127.0.0.1 m9.es.2mdn.net
127.0.0.1 m9.fi.2mdn.net
127.0.0.1 m9.fr.2mdn.net
127.0.0.1 m9.it.2mdn.net
127.0.0.1 m9.jp.2mdn.net
127.0.0.1 m9.nl.2mdn.net
127.0.0.1 m9.no.2mdn.net
127.0.0.1 m9.nz.2mdn.net
127.0.0.1 m9.pl.2mdn.net
127.0.0.1 m9.se.2mdn.net
127.0.0.1 m9.sg.2mdn.net
127.0.0.1 m9.uk.2mdn.net
127.0.0.1 m9.ve.2mdn.net
127.0.0.1 m9.za.2mdn.net
127.0.0.1 n3302ad.doubleclick.net
127.0.0.1 n3349ad.doubleclick.net
127.0.0.1 n4403ad.doubleclick.net
127.0.0.1 n479ad.doubleclick.net
127.0.0.1 optimize.doubleclick.net
127.0.0.1 pubads.g.doubleclick.net
127.0.0.1 rd.intl.doubleclick.net
127.0.0.1 securepubads.g.doubleclick.net
127.0.0.1 stats.g.doubleclick.net
127.0.0.1 twx.2mdn.net
127.0.0.1 twx.doubleclick.net
127.0.0.1 ukrpts.net
127.0.0.1 uunyadgda1.doubleclick.net
127.0.0.1 uunyadgds1.doubleclick.net
127.0.0.1 www.ukrpts.net
#</doubleclick-sites>

#<intellitxt-sites>

127.0.0.1 1up.us.intellitxt.com
127.0.0.1 5starhiphop.us.intellitxt.com
127.0.0.1 askmen2.us.intellitxt.com
127.0.0.1 bargainpda.us.intellitxt.com
127.0.0.1 businesspundit.us.intellitxt.com
127.0.0.1 canadafreepress.us.intellitxt.com
127.0.0.1 contactmusic.uk.intellitxt.com
127.0.0.1 ctv.us.intellitxt.com
127.0.0.1 designtechnica.us.intellitxt.com
127.0.0.1 devshed.us.intellitxt.com
127.0.0.1 digitaltrends.us.intellitxt.com
127.0.0.1 dnps.us.intellitxt.com
127.0.0.1 doubleviking.us.intellitxt.com
127.0.0.1 drizzydrake.us.intellitxt.com
127.0.0.1 ehow.us.intellitxt.com
127.0.0.1 entertainment.msnbc.us.intellitxt.com
127.0.0.1 examnotes.us.intellitxt.com
127.0.0.1 excite.us.intellitxt.com
127.0.0.1 experts.us.intellitxt.com
127.0.0.1 extremetech.us.intellitxt.com
127.0.0.1 ferrago.uk.intellitxt.com
127.0.0.1 filmschoolrejects.us.intellitxt.com
127.0.0.1 filmwad.us.intellitxt.com
127.0.0.1 firstshowing.us.intellitxt.com
127.0.0.1 flashmagazine.us.intellitxt.com
127.0.0.1 foxnews.us.intellitxt.com
127.0.0.1 foxtv.us.intellitxt.com
127.0.0.1 freedownloadcenter.uk.intellitxt.com
127.0.0.1 gadgets.fosfor.se.intellitxt.com
127.0.0.1 gamesradar.us.intellitxt.com
127.0.0.1 gannettbroadcast.us.intellitxt.com
127.0.0.1 gonintendo.us.intellitxt.com
127.0.0.1 gorillanation.us.intellitxt.com
127.0.0.1 hackedgadgets.us.intellitxt.com
127.0.0.1 hardcoreware.us.intellitxt.com
127.0.0.1 hardocp.us.intellitxt.com
127.0.0.1 hothardware.us.intellitxt.com
127.0.0.1 hotonlinenews.us.intellitxt.com
127.0.0.1 ign.us.intellitxt.com
127.0.0.1 images.intellitxt.com
127.0.0.1 itxt2.us.intellitxt.com
127.0.0.1 joblo.us.intellitxt.com
127.0.0.1 johnchow.us.intellitxt.com
127.0.0.1 laptopmag.us.intellitxt.com
127.0.0.1 linuxforums.us.intellitxt.com
127.0.0.1 maccity.it.intellitxt.com
127.0.0.1 macnn.us.intellitxt.com
127.0.0.1 macuser.uk.intellitxt.com
127.0.0.1 macworld.uk.intellitxt.com
127.0.0.1 metro.uk.intellitxt.com
127.0.0.1 mobile9.us.intellitxt.com
127.0.0.1 monstersandcritics.uk.intellitxt.com
127.0.0.1 moviesonline.ca.intellitxt.com
127.0.0.1 mustangevolution.us.intellitxt.com
127.0.0.1 neowin.us.intellitxt.com
127.0.0.1 newcarnet.uk.intellitxt.com
127.0.0.1 newlaunches.uk.intellitxt.com
127.0.0.1 nexys404.us.intellitxt.com
127.0.0.1 ohgizmo.us.intellitxt.com
127.0.0.1 pcadvisor.uk.intellitxt.com
127.0.0.1 pcgameshardware.de.intellitxt.com
127.0.0.1 pcmag.us.intellitxt.com
127.0.0.1 pcper.us.intellitxt.com
127.0.0.1 penton.us.intellitxt.com
127.0.0.1 physorg.uk.intellitxt.com
127.0.0.1 physorg.us.intellitxt.com
127.0.0.1 playfuls.uk.intellitxt.com
127.0.0.1 pocketlint.uk.intellitxt.com
127.0.0.1 popularmechanics.us.intellitxt.com
127.0.0.1 postchronicle.us.intellitxt.com
127.0.0.1 projectorreviews.us.intellitxt.com
127.0.0.1 psp3d.us.intellitxt.com
127.0.0.1 pspcave.uk.intellitxt.com
127.0.0.1 qj.us.intellitxt.com
127.0.0.1 rasmussenreports.us.intellitxt.com
127.0.0.1 rawstory.us.intellitxt.com
127.0.0.1 savemanny.us.intellitxt.com
127.0.0.1 sc.intellitxt.com
127.0.0.1 siliconera.us.intellitxt.com
127.0.0.1 slashphone.us.intellitxt.com
127.0.0.1 soft32.us.intellitxt.com
127.0.0.1 softpedia.uk.intellitxt.com
127.0.0.1 somethingawful.us.intellitxt.com
127.0.0.1 splashnews.uk.intellitxt.com
127.0.0.1 spymac.us.intellitxt.com
127.0.0.1 techeblog.us.intellitxt.com
127.0.0.1 technewsworld.us.intellitxt.com
127.0.0.1 technologyreview.us.intellitxt.com
127.0.0.1 techspot.us.intellitxt.com
127.0.0.1 tgdaily.us.intellitxt.com
127.0.0.1 the-gadgeteer.us.intellitxt.com
127.0.0.1 thelastboss.us.intellitxt.com
127.0.0.1 thetechzone.us.intellitxt.com
127.0.0.1 thoughtsmedia.us.intellitxt.com
127.0.0.1 tmcnet.us.intellitxt.com
127.0.0.1 toms.us.intellitxt.com
127.0.0.1 tomsnetworking.us.intellitxt.com
127.0.0.1 tribal.us.intellitxt.com  # vibrantmedia.com
127.0.0.1 universetoday.us.intellitxt.com
127.0.0.1 us.intellitxt.com
127.0.0.1 warp2search.us.intellitxt.com
127.0.0.1 wi-fitechnology.uk.intellitxt.com
127.0.0.1 worldnetdaily.us.intellitxt.com
#</intellitxt-sites>

#<red-sheriff-sites>

# Red Sheriff and imrworldwide.com  -- server side tracking
#127.0.0.1 secure-au.imrworldwide.com
127.0.0.1 devfw.imrworldwide.com
127.0.0.1 fe-au.imrworldwide.com
127.0.0.1 fe1-au.imrworldwide.com
127.0.0.1 fe1-fi.imrworldwide.com
127.0.0.1 fe1-it.imrworldwide.com
127.0.0.1 fe2-au.imrworldwide.com
127.0.0.1 fe3-au.imrworldwide.com
127.0.0.1 fe3-gc.imrworldwide.com
127.0.0.1 fe3-uk.imrworldwide.com
127.0.0.1 fe4-uk.imrworldwide.com
127.0.0.1 imrworldwide.com
127.0.0.1 lycos-eu.imrworldwide.com
127.0.0.1 ninemsn.imrworldwide.com
127.0.0.1 rc-au.imrworldwide.com
127.0.0.1 redsheriff.com
127.0.0.1 secure-jp.imrworldwide.com
127.0.0.1 secure-nz.imrworldwide.com
127.0.0.1 secure-uk.imrworldwide.com
127.0.0.1 secure-us.imrworldwide.com
127.0.0.1 secure-za.imrworldwide.com
127.0.0.1 server-au.imrworldwide.com
127.0.0.1 server-br.imrworldwide.com
127.0.0.1 server-by.imrworldwide.com
127.0.0.1 server-ca.imrworldwide.com
127.0.0.1 server-de.imrworldwide.com
127.0.0.1 server-dk.imrworldwide.com
127.0.0.1 server-ee.imrworldwide.com
127.0.0.1 server-fi.imrworldwide.com
127.0.0.1 server-fr.imrworldwide.com
127.0.0.1 server-hk.imrworldwide.com
127.0.0.1 server-it.imrworldwide.com
127.0.0.1 server-jp.imrworldwide.com
127.0.0.1 server-lt.imrworldwide.com
127.0.0.1 server-lv.imrworldwide.com
127.0.0.1 server-no.imrworldwide.com
127.0.0.1 server-nz.imrworldwide.com
127.0.0.1 server-oslo.imrworldwide.com
127.0.0.1 server-pl.imrworldwide.com
127.0.0.1 server-ru.imrworldwide.com
127.0.0.1 server-se.imrworldwide.com
127.0.0.1 server-sg.imrworldwide.com
127.0.0.1 server-stockh.imrworldwide.com
127.0.0.1 server-ua.imrworldwide.com
127.0.0.1 server-uk.imrworldwide.com
127.0.0.1 server-us.imrworldwide.com
127.0.0.1 server-za.imrworldwide.com
127.0.0.1 survey1-au.imrworldwide.com
127.0.0.1 telstra.imrworldwide.com
127.0.0.1 www.imrworldwide.com
127.0.0.1 www.imrworldwide.com.au
127.0.0.1 www.redsheriff.com
#</red-sheriff-sites>

#<cydoor-sites>

# cydoor -- server side tracking
127.0.0.1 cydoor.com
127.0.0.1 j.2004cms.com         # cydoor
127.0.0.1 jbaventures.cjt1.net
127.0.0.1 jbeet.cjt1.net
127.0.0.1 jbit.cjt1.net
127.0.0.1 jcollegehumor.cjt1.net
127.0.0.1 jcontent.bns1.net
127.0.0.1 jdownloadacc.cjt1.net
127.0.0.1 jgen1.cjt1.net
127.0.0.1 jgen10.cjt1.net
127.0.0.1 jgen11.cjt1.net
127.0.0.1 jgen12.cjt1.net
127.0.0.1 jgen13.cjt1.net
127.0.0.1 jgen14.cjt1.net
127.0.0.1 jgen15.cjt1.net
127.0.0.1 jgen16.cjt1.net
127.0.0.1 jgen17.cjt1.net
127.0.0.1 jgen18.cjt1.net
127.0.0.1 jgen19.cjt1.net
127.0.0.1 jgen2.cjt1.net
127.0.0.1 jgen20.cjt1.net
127.0.0.1 jgen21.cjt1.net
127.0.0.1 jgen22.cjt1.net
127.0.0.1 jgen23.cjt1.net
127.0.0.1 jgen24.cjt1.net
127.0.0.1 jgen25.cjt1.net
127.0.0.1 jgen26.cjt1.net
127.0.0.1 jgen27.cjt1.net
127.0.0.1 jgen28.cjt1.net
127.0.0.1 jgen29.cjt1.net
127.0.0.1 jgen3.cjt1.net
127.0.0.1 jgen30.cjt1.net
127.0.0.1 jgen31.cjt1.net
127.0.0.1 jgen32.cjt1.net
127.0.0.1 jgen33.cjt1.net
127.0.0.1 jgen34.cjt1.net
127.0.0.1 jgen35.cjt1.net
127.0.0.1 jgen36.cjt1.net
127.0.0.1 jgen37.cjt1.net
127.0.0.1 jgen38.cjt1.net
127.0.0.1 jgen39.cjt1.net
127.0.0.1 jgen4.cjt1.net
127.0.0.1 jgen40.cjt1.net
127.0.0.1 jgen41.cjt1.net
127.0.0.1 jgen42.cjt1.net
127.0.0.1 jgen43.cjt1.net
127.0.0.1 jgen44.cjt1.net
127.0.0.1 jgen45.cjt1.net
127.0.0.1 jgen46.cjt1.net
127.0.0.1 jgen47.cjt1.net
127.0.0.1 jgen48.cjt1.net
127.0.0.1 jgen49.cjt1.net
127.0.0.1 jgen5.cjt1.net
127.0.0.1 jgen6.cjt1.net
127.0.0.1 jgen7.cjt1.net
127.0.0.1 jgen8.cjt1.net
127.0.0.1 jgen9.cjt1.net
127.0.0.1 jhumour.cjt1.net
127.0.0.1 jmbi58.cjt1.net
127.0.0.1 jnova.cjt1.net
127.0.0.1 jpirate.cjt1.net
127.0.0.1 jsandboxer.cjt1.net
127.0.0.1 jumcna.cjt1.net
127.0.0.1 jwebbsense.cjt1.net
127.0.0.1 www.cydoor.com
#</cydoor-sites>

#<2o7-sites>

# 2o7.net -- server side tracking
#127.0.0.1 appleglobal.112.2o7.net  #breaks apple.com
#127.0.0.1 applestoreus.112.2o7.net #breaks apple.com
127.0.0.1 102.112.2o7.net
127.0.0.1 102.122.2o7.net
127.0.0.1 112.2o7.net
127.0.0.1 122.2o7.net
127.0.0.1 192.168.112.2o7.net
127.0.0.1 2o7.net
127.0.0.1 actforvictory.112.2o7.net
127.0.0.1 adbrite.112.2o7.net
127.0.0.1 adbrite.122.2o7.net
127.0.0.1 aehistory.112.2o7.net
127.0.0.1 aetv.112.2o7.net
127.0.0.1 agamgreetingscom.112.2o7.net
127.0.0.1 allbritton.122.2o7.net
127.0.0.1 americanbaby.112.2o7.net
127.0.0.1 ancestrymsn.112.2o7.net
127.0.0.1 ancestryuki.112.2o7.net
127.0.0.1 angiba.112.2o7.net
127.0.0.1 angmar.112.2o7.net
127.0.0.1 angtr.112.2o7.net
127.0.0.1 angts.112.2o7.net
127.0.0.1 angvac.112.2o7.net
127.0.0.1 anm.112.2o7.net
127.0.0.1 aolcareers.122.2o7.net
127.0.0.1 aoldlama.122.2o7.net
127.0.0.1 aoljournals.122.2o7.net
127.0.0.1 aolnsnews.122.2o7.net
127.0.0.1 aolpf.122.2o7.net
127.0.0.1 aolpolls.112.2o7.net
127.0.0.1 aolpolls.122.2o7.net
127.0.0.1 aolsearch.122.2o7.net
127.0.0.1 aolsvc.122.2o7.net
127.0.0.1 aoltmz.122.2o7.net
127.0.0.1 aolturnercnnmoney.112.2o7.net
127.0.0.1 aolturnercnnmoney.122.2o7.net
127.0.0.1 aolturnersi.122.2o7.net
127.0.0.1 aolukglobal.122.2o7.net
127.0.0.1 aolwinamp.122.2o7.net
127.0.0.1 aolwpaim.112.2o7.net
127.0.0.1 aolwpicq.122.2o7.net
127.0.0.1 aolwpmq.112.2o7.net
127.0.0.1 aolwpmqnoban.112.2o7.net
127.0.0.1 apdigitalorg.112.2o7.net
127.0.0.1 apdigitalorgovn.112.2o7.net
127.0.0.1 apnonline.112.2o7.net
127.0.0.1 atlassian.122.2o7.net
127.0.0.1 autobytel.112.2o7.net
127.0.0.1 autoweb.112.2o7.net
127.0.0.1 bbcnewscouk.112.2o7.net
127.0.0.1 bellca.112.2o7.net
127.0.0.1 bellglobemediapublishing.122.2o7.net
127.0.0.1 bellglovemediapublishing.122.2o7.net
127.0.0.1 bellserviceeng.112.2o7.net
127.0.0.1 betterhg.112.2o7.net
127.0.0.1 bhgmarketing.112.2o7.net
127.0.0.1 bidentonrccom.122.2o7.net
127.0.0.1 biwwltvcom.112.2o7.net
127.0.0.1 biwwltvcom.122.2o7.net
127.0.0.1 blackpress.122.2o7.net
127.0.0.1 bnkr8dev.112.2o7.net
127.0.0.1 bntbcstglobal.112.2o7.net
127.0.0.1 bosecom.112.2o7.net
127.0.0.1 brightcove.112.2o7.net
127.0.0.1 bulldog.122.2o7.net
127.0.0.1 businessweekpoc.112.2o7.net
127.0.0.1 bzresults.122.2o7.net
127.0.0.1 canwest.112.2o7.net
127.0.0.1 canwestcom.112.2o7.net
127.0.0.1 canwestglobal.112.2o7.net
127.0.0.1 capcityadvcom.112.2o7.net
127.0.0.1 capcityadvcom.122.2o7.net
127.0.0.1 careers.112.2o7.net
127.0.0.1 cartoonnetwork.122.2o7.net
127.0.0.1 cbaol.112.2o7.net
127.0.0.1 cbc.122.2o7.net
127.0.0.1 cbcca.112.2o7.net
127.0.0.1 cbcca.122.2o7.net
127.0.0.1 cbcincinnatienquirer.112.2o7.net
127.0.0.1 cbmsn.112.2o7.net
127.0.0.1 cbs.112.2o7.net
127.0.0.1 cbsncaasports.112.2o7.net
127.0.0.1 cbsnfl.112.2o7.net
127.0.0.1 cbspgatour.112.2o7.net
127.0.0.1 cbsspln.112.2o7.net
127.0.0.1 ccrbudgetca.112.2o7.net
127.0.0.1 ccrgaviscom.112.2o7.net
127.0.0.1 cfrfa.112.2o7.net
127.0.0.1 chicagosuntimes.122.2o7.net
127.0.0.1 chumtv.122.2o7.net
127.0.0.1 classifiedscanada.112.2o7.net
127.0.0.1 classmatescom.112.2o7.net
127.0.0.1 cmpglobalvista.112.2o7.net
127.0.0.1 cnetasiapacific.122.2o7.net
127.0.0.1 cnetaustralia.122.2o7.net
127.0.0.1 cneteurope.122.2o7.net
127.0.0.1 cnetnews.112.2o7.net
127.0.0.1 cnetzdnet.112.2o7.net
127.0.0.1 cnhienid.122.2o7.net
127.0.0.1 cnhimcalesternews.122.2o7.net
127.0.0.1 cnhipicayuneitemv.112.2o7.net
127.0.0.1 cnhitribunestar.122.2o7.net
127.0.0.1 cnhitribunestara.122.2o7.net
127.0.0.1 cnhregisterherald.122.2o7.net
127.0.0.1 cnn.122.2o7.net
127.0.0.1 computerworldcom.112.2o7.net
127.0.0.1 coxnetmasterglobal.112.2o7.net
127.0.0.1 coxpalmbeachpost.112.2o7.net
127.0.0.1 csoonlinecom.112.2o7.net
127.0.0.1 ctvcrimelibrary.112.2o7.net
127.0.0.1 ctvsmokinggun.112.2o7.net
127.0.0.1 cxociocom.112.2o7.net
127.0.0.1 denverpost.112.2o7.net
127.0.0.1 diginet.112.2o7.net
127.0.0.1 digitalhomediscountptyltd.122.2o7.net
127.0.0.1 disccglobal.112.2o7.net
127.0.0.1 disccstats.112.2o7.net
127.0.0.1 dischannel.112.2o7.net
127.0.0.1 divx.112.2o7.net
127.0.0.1 dixonslnkcouk.112.2o7.net
127.0.0.1 dogpile.112.2o7.net
127.0.0.1 donval.112.2o7.net
127.0.0.1 dowjones.122.2o7.net
127.0.0.1 dreammates.112.2o7.net
127.0.0.1 eaeacom.112.2o7.net
127.0.0.1 eagamesuk.112.2o7.net
127.0.0.1 earthlnkpsplive.122.2o7.net
127.0.0.1 ebay1.112.2o7.net
127.0.0.1 ebaynonreg.112.2o7.net
127.0.0.1 ebayreg.112.2o7.net
127.0.0.1 ebayus.112.2o7.net
127.0.0.1 ebcom.112.2o7.net
127.0.0.1 ectestlampsplus1.112.2o7.net
127.0.0.1 edietsmain.112.2o7.net
127.0.0.1 edmundsinsideline.112.2o7.net
127.0.0.1 edsa.112.2o7.net
127.0.0.1 ehg-moma.hitbox.com.112.2o7.net
127.0.0.1 emc.122.2o7.net
127.0.0.1 employ22.112.2o7.net
127.0.0.1 employ26.112.2o7.net
127.0.0.1 employment.112.2o7.net
127.0.0.1 enterprisenewsmedia.122.2o7.net
127.0.0.1 epost.122.2o7.net
127.0.0.1 ewsnaples.112.2o7.net
127.0.0.1 ewstcpalm.112.2o7.net
127.0.0.1 examinercom.122.2o7.net
127.0.0.1 execulink.112.2o7.net
127.0.0.1 expedia.ca.112.2o7.net
127.0.0.1 expedia4.112.2o7.net
127.0.0.1 f2ncracker.112.2o7.net
127.0.0.1 f2nsmh.112.2o7.net
127.0.0.1 f2ntheage.112.2o7.net
127.0.0.1 faceoff.112.2o7.net
127.0.0.1 fbkmnr.112.2o7.net
127.0.0.1 forbesattache.112.2o7.net
127.0.0.1 forbesauto.112.2o7.net
127.0.0.1 forbesautos.112.2o7.net
127.0.0.1 forbescom.112.2o7.net
127.0.0.1 ford.112.2o7.net
127.0.0.1 foxcom.112.2o7.net
127.0.0.1 foxsimpsons.112.2o7.net
127.0.0.1 georgewbush.112.2o7.net
127.0.0.1 georgewbushcom.112.2o7.net
127.0.0.1 gettyimages.122.2o7.net
127.0.0.1 gjfastcompanycom.112.2o7.net
127.0.0.1 gmchevyapprentice.112.2o7.net
127.0.0.1 gmhummer.112.2o7.net
127.0.0.1 gntbcstglobal.112.2o7.net
127.0.0.1 gntbcstkxtv.112.2o7.net
127.0.0.1 gntbcstwtsp.112.2o7.net
127.0.0.1 gpaper104.112.2o7.net
127.0.0.1 gpaper105.112.2o7.net
127.0.0.1 gpaper107.112.2o7.net
127.0.0.1 gpaper108.112.2o7.net
127.0.0.1 gpaper109.112.2o7.net
127.0.0.1 gpaper110.112.2o7.net
127.0.0.1 gpaper111.112.2o7.net
127.0.0.1 gpaper112.112.2o7.net
127.0.0.1 gpaper113.112.2o7.net
127.0.0.1 gpaper114.112.2o7.net
127.0.0.1 gpaper115.112.2o7.net
127.0.0.1 gpaper116.112.2o7.net
127.0.0.1 gpaper117.112.2o7.net
127.0.0.1 gpaper118.112.2o7.net
127.0.0.1 gpaper119.112.2o7.net
127.0.0.1 gpaper120.112.2o7.net
127.0.0.1 gpaper121.112.2o7.net
127.0.0.1 gpaper122.112.2o7.net
127.0.0.1 gpaper123.112.2o7.net
127.0.0.1 gpaper124.112.2o7.net
127.0.0.1 gpaper125.112.2o7.net
127.0.0.1 gpaper126.112.2o7.net
127.0.0.1 gpaper127.112.2o7.net
127.0.0.1 gpaper128.112.2o7.net
127.0.0.1 gpaper129.112.2o7.net
127.0.0.1 gpaper131.112.2o7.net
127.0.0.1 gpaper132.112.2o7.net
127.0.0.1 gpaper133.112.2o7.net
127.0.0.1 gpaper138.112.2o7.net
127.0.0.1 gpaper139.112.2o7.net
127.0.0.1 gpaper140.112.2o7.net
127.0.0.1 gpaper141.112.2o7.net
127.0.0.1 gpaper142.112.2o7.net
127.0.0.1 gpaper144.112.2o7.net
127.0.0.1 gpaper145.112.2o7.net
127.0.0.1 gpaper147.112.2o7.net
127.0.0.1 gpaper149.112.2o7.net
127.0.0.1 gpaper151.112.2o7.net
127.0.0.1 gpaper154.112.2o7.net
127.0.0.1 gpaper156.112.2o7.net
127.0.0.1 gpaper157.112.2o7.net
127.0.0.1 gpaper158.112.2o7.net
127.0.0.1 gpaper162.112.2o7.net
127.0.0.1 gpaper164.112.2o7.net
127.0.0.1 gpaper166.112.2o7.net
127.0.0.1 gpaper167.112.2o7.net
127.0.0.1 gpaper169.112.2o7.net
127.0.0.1 gpaper170.112.2o7.net
127.0.0.1 gpaper171.112.2o7.net
127.0.0.1 gpaper172.112.2o7.net
127.0.0.1 gpaper173.112.2o7.net
127.0.0.1 gpaper174.112.2o7.net
127.0.0.1 gpaper176.112.2o7.net
127.0.0.1 gpaper177.112.2o7.net
127.0.0.1 gpaper180.112.2o7.net
127.0.0.1 gpaper183.112.2o7.net
127.0.0.1 gpaper184.112.2o7.net
127.0.0.1 gpaper191.112.2o7.net
127.0.0.1 gpaper192.112.2o7.net
127.0.0.1 gpaper193.112.2o7.net
127.0.0.1 gpaper194.112.2o7.net
127.0.0.1 gpaper195.112.2o7.net
127.0.0.1 gpaper196.112.2o7.net
127.0.0.1 gpaper197.112.2o7.net
127.0.0.1 gpaper198.112.2o7.net
127.0.0.1 gpaper202.112.2o7.net
127.0.0.1 gpaper204.112.2o7.net
127.0.0.1 gpaper205.112.2o7.net
127.0.0.1 gpaper212.112.2o7.net
127.0.0.1 gpaper214.112.2o7.net
127.0.0.1 gpaper219.112.2o7.net
127.0.0.1 gpaper223.112.2o7.net
127.0.0.1 harpo.122.2o7.net
127.0.0.1 hchrmain.112.2o7.net
127.0.0.1 heavycom.112.2o7.net
127.0.0.1 heavycom.122.2o7.net
127.0.0.1 homesclick.112.2o7.net
127.0.0.1 hostdomainpeople.112.2o7.net
127.0.0.1 hostdomainpeopleca.112.2o7.net
127.0.0.1 hostpowermedium.112.2o7.net
127.0.0.1 hpglobal.112.2o7.net
127.0.0.1 hphqglobal.112.2o7.net
127.0.0.1 hphqsearch.112.2o7.net
127.0.0.1 infomart.ca.112.2o7.net
127.0.0.1 infospace.com.112.2o7.net
127.0.0.1 intelcorpcim.112.2o7.net
127.0.0.1 intelglobal.112.2o7.net
127.0.0.1 ivillageglobal.112.2o7.net
127.0.0.1 jijsonline.122.2o7.net
127.0.0.1 jitmj4.122.2o7.net
127.0.0.1 johnlewis.112.2o7.net
127.0.0.1 journalregistercompany.122.2o7.net
127.0.0.1 kddi.122.2o7.net
127.0.0.1 krafteurope.112.2o7.net
127.0.0.1 ktva.112.2o7.net
127.0.0.1 ladieshj.112.2o7.net
127.0.0.1 laptopmag.122.2o7.net
127.0.0.1 laxnws.112.2o7.net
127.0.0.1 laxprs.112.2o7.net
127.0.0.1 laxpsd.112.2o7.net
127.0.0.1 ldsfch.112.2o7.net
127.0.0.1 leeenterprises.112.2o7.net
127.0.0.1 lenovo.112.2o7.net
127.0.0.1 logoworksdev.112.2o7.net
127.0.0.1 losu.112.2o7.net
127.0.0.1 mailtribune.112.2o7.net
127.0.0.1 maxim.122.2o7.net
127.0.0.1 maxvr.112.2o7.net
127.0.0.1 mdamarillo.112.2o7.net
127.0.0.1 mdjacksonville.112.2o7.net
127.0.0.1 mdtopeka.112.2o7.net
127.0.0.1 mdwardmore.112.2o7.net
127.0.0.1 mdwsavannah.112.2o7.net
127.0.0.1 medbroadcast.112.2o7.net
127.0.0.1 mediabistrocom.112.2o7.net
127.0.0.1 mediamatters.112.2o7.net
127.0.0.1 meetupcom.112.2o7.net
127.0.0.1 metacafe.122.2o7.net
127.0.0.1 mgjournalnow.112.2o7.net
127.0.0.1 mgtbo.112.2o7.net
127.0.0.1 mgtimesdispatch.112.2o7.net
127.0.0.1 mgwsls.112.2o7.net
127.0.0.1 mgwspa.112.2o7.net
127.0.0.1 microsoftconsumermarketing.112.2o7.net
127.0.0.1 microsofteup.112.2o7.net
127.0.0.1 microsoftwindows.112.2o7.net
127.0.0.1 midala.112.2o7.net
127.0.0.1 midar.112.2o7.net
127.0.0.1 midsen.112.2o7.net
127.0.0.1 mlbastros.112.2o7.net
127.0.0.1 mlbcolorado.112.2o7.net
127.0.0.1 mlbcom.112.2o7.net
127.0.0.1 mlbglobal.112.2o7.net
127.0.0.1 mlbglobal08.112.2o7.net
127.0.0.1 mlbhouston.112.2o7.net
127.0.0.1 mlbstlouis.112.2o7.net
127.0.0.1 mlbtoronto.112.2o7.net
127.0.0.1 mmsshopcom.112.2o7.net
127.0.0.1 mnfidnahub.112.2o7.net
127.0.0.1 mngidmn.112.2o7.net
127.0.0.1 mngirockymtnnews.112.2o7.net
127.0.0.1 mngislctrib.112.2o7.net
127.0.0.1 mngiyrkdr.112.2o7.net
127.0.0.1 mseuppremain.112.2o7.net
127.0.0.1 msnmercom.112.2o7.net
127.0.0.1 msnportal.112.2o7.net
127.0.0.1 mtvn.112.2o7.net
127.0.0.1 mtvu.112.2o7.net
127.0.0.1 mxmacromedia.112.2o7.net
127.0.0.1 myfamilyancestry.112.2o7.net
127.0.0.1 nasdaq.122.2o7.net
127.0.0.1 natgeoeditco.112.2o7.net
127.0.0.1 natgeoeditcom.112.2o7.net
127.0.0.1 natgeonews.112.2o7.net
127.0.0.1 natgeongmcom.112.2o7.net
127.0.0.1 nationalpost.112.2o7.net
127.0.0.1 nba.112.2o7.net
127.0.0.1 neber.112.2o7.net
127.0.0.1 netrp.112.2o7.net
127.0.0.1 netsdartboards.122.2o7.net
127.0.0.1 newsinteractive.112.2o7.net
127.0.0.1 newstimeslivecom.112.2o7.net
127.0.0.1 nike.112.2o7.net
127.0.0.1 nikeplus.112.2o7.net
127.0.0.1 nmanchorage.112.2o7.net
127.0.0.1 nmbrampton.112.2o7.net
127.0.0.1 nmcommancomedia.112.2o7.net
127.0.0.1 nmfresno.112.2o7.net
127.0.0.1 nmhiltonhead.112.2o7.net
127.0.0.1 nmkawartha.112.2o7.net
127.0.0.1 nmminneapolis.112.2o7.net
127.0.0.1 nmmississauga.112.2o7.net
127.0.0.1 nmnandomedia.112.2o7.net
127.0.0.1 nmraleigh.112.2o7.net
127.0.0.1 nmrockhill.112.2o7.net
127.0.0.1 nmsacramento.112.2o7.net
127.0.0.1 nmtoronto.112.2o7.net
127.0.0.1 nmtricity.112.2o7.net
127.0.0.1 nmyork.112.2o7.net
127.0.0.1 novellcom.112.2o7.net
127.0.0.1 nytbglobe.112.2o7.net
127.0.0.1 nytglobe.112.2o7.net
127.0.0.1 nythglobe.112.2o7.net
127.0.0.1 nytimesglobal.112.2o7.net
127.0.0.1 nytimesnonsampled.112.2o7.net
127.0.0.1 nytimesnoonsampled.112.2o7.net
127.0.0.1 nytmembercenter.112.2o7.net
127.0.0.1 nytrflorence.112.2o7.net
127.0.0.1 nytrgadsden.112.2o7.net
127.0.0.1 nytrgainseville.112.2o7.net
127.0.0.1 nytrhendersonville.112.2o7.net
127.0.0.1 nytrhouma.112.2o7.net
127.0.0.1 nytrlakeland.112.2o7.net
127.0.0.1 nytrsantarosa.112.2o7.net
127.0.0.1 nytrsarasota.112.2o7.net
127.0.0.1 nytrwilmington.112.2o7.net
127.0.0.1 nyttechnology.112.2o7.net
127.0.0.1 omniture.112.2o7.net
127.0.0.1 omnitureglobal.112.2o7.net
127.0.0.1 onlineindigoca.112.2o7.net
127.0.0.1 oraclecom.112.2o7.net
127.0.0.1 overstock.com.112.2o7.net
127.0.0.1 overturecomvista.112.2o7.net
127.0.0.1 paypal.112.2o7.net
127.0.0.1 poacprod.122.2o7.net
127.0.0.1 poconorecordcom.112.2o7.net
127.0.0.1 projectorpeople.112.2o7.net
127.0.0.1 publicationsunbound.112.2o7.net
127.0.0.1 pulharktheherald.112.2o7.net
127.0.0.1 pulpantagraph.112.2o7.net
127.0.0.1 rckymtnnws.112.2o7.net
127.0.0.1 recordnetcom.112.2o7.net
127.0.0.1 recordonlinecom.112.2o7.net
127.0.0.1 rey3935.112.2o7.net
127.0.0.1 rezrezwhistler.112.2o7.net
127.0.0.1 riptownmedia.122.2o7.net
127.0.0.1 rncgopcom.122.2o7.net
127.0.0.1 roxio.112.2o7.net
127.0.0.1 salesforce.122.2o7.net
127.0.0.1 santacruzsentinel.112.2o7.net
127.0.0.1 sciamglobal.112.2o7.net
127.0.0.1 scrippsbathvert.112.2o7.net
127.0.0.1 scrippsfoodnet.112.2o7.net
127.0.0.1 scrippswfts.112.2o7.net
127.0.0.1 scrippswxyz.112.2o7.net
127.0.0.1 seacoastonlinecom.112.2o7.net
127.0.0.1 searscom.112.2o7.net
127.0.0.1 smibs.112.2o7.net
127.0.0.1 smwww.112.2o7.net
127.0.0.1 sonycorporate.122.2o7.net
127.0.0.1 sonyglobal.112.2o7.net
127.0.0.1 southcoasttoday.112.2o7.net
127.0.0.1 spiketv.112.2o7.net
127.0.0.1 stpetersburgtimes.122.2o7.net
127.0.0.1 suncom.112.2o7.net
127.0.0.1 sunglobal.112.2o7.net
127.0.0.1 sunonesearch.112.2o7.net
127.0.0.1 sympmsnsports.112.2o7.net
127.0.0.1 techreview.112.2o7.net
127.0.0.1 thestar.122.2o7.net
127.0.0.1 thestardev.122.2o7.net
127.0.0.1 thinkgeek.112.2o7.net
127.0.0.1 timebus2.112.2o7.net
127.0.0.1 timecom.112.2o7.net
127.0.0.1 timeew.122.2o7.net
127.0.0.1 timefortune.112.2o7.net
127.0.0.1 timehealth.112.2o7.net
127.0.0.1 timeofficepirates.122.2o7.net
127.0.0.1 timepeople.122.2o7.net
127.0.0.1 timepopsci.122.2o7.net
127.0.0.1 timerealsimple.112.2o7.net
127.0.0.1 timewarner.122.2o7.net
127.0.0.1 tmsscion.112.2o7.net
127.0.0.1 tmstoyota.112.2o7.net
127.0.0.1 tnttv.112.2o7.net
127.0.0.1 torstardigital.122.2o7.net
127.0.0.1 travidiathebrick.112.2o7.net
127.0.0.1 tribuneinteractive.122.2o7.net
127.0.0.1 usatoday1.112.2o7.net
127.0.0.1 usnews.122.2o7.net
127.0.0.1 usun.112.2o7.net
127.0.0.1 vanns.112.2o7.net
127.0.0.1 verisignwildcard.112.2o7.net
127.0.0.1 verisonwildcard.112.2o7.net
127.0.0.1 vh1com.112.2o7.net
127.0.0.1 viaatomvideo.112.2o7.net
127.0.0.1 viacomedycentralrl.112.2o7.net
127.0.0.1 viagametrailers.112.2o7.net
127.0.0.1 viamtvcom.112.2o7.net
127.0.0.1 viasyndimedia.112.2o7.net
127.0.0.1 viavh1com.112.2o7.net
127.0.0.1 viay2m.112.2o7.net
127.0.0.1 vintacom.112.2o7.net
127.0.0.1 viralvideo.112.2o7.net
127.0.0.1 walmartcom.112.2o7.net
127.0.0.1 westjet.112.2o7.net
127.0.0.1 wileydumcom.112.2o7.net
127.0.0.1 wmg.112.2o7.net
127.0.0.1 wmgmulti.112.2o7.net
127.0.0.1 workopolis.122.2o7.net
127.0.0.1 wpni.112.2o7.net
127.0.0.1 xhealthmobiletools.112.2o7.net
127.0.0.1 youtube.112.2o7.net
127.0.0.1 yrkeve.112.2o7.net
127.0.0.1 ziffdavisglobal.112.2o7.net
127.0.0.1 ziffdavispennyarcade.112.2o7.net
#</2o7-sites>

#<ad-sites>
#<maybe-ads>
#127.0.0.1 adfarm.mediaplex.com     # may interfere with ebay
#127.0.0.1 ads.msn.com          #This may cause problems with zone.msn.com
#127.0.0.1 ak.imgfarm.com       # may cause problems with iwon.com
#127.0.0.1 click.linksynergy.com
#127.0.0.1 global.msads.net     #This may cause problems with zone.msn.com
#127.0.0.1 lads.myspace.com     # blocks myspace media/video players
#127.0.0.1 refer.ccbill.com     #affiliate program, to add it back, remove the #
#127.0.0.1 rmads.msn.com            #This may cause problems with zone.msn.com
#127.0.0.1 www.apmebf.com       #qksrv
#127.0.0.1 www.tkqlhce.com      #qksrv
#127.0.0.1 ad.ca.doubleclick.net    #intereferes with video on globeandmail.com
#127.0.0.1 transfer.go.com      #may interfere with Disney websites
#</maybe-ads>

# ads
127.0.0.1 0101011.com
127.0.0.1 0d79ed.r.axf8.net
127.0.0.1 0pn.ru
127.0.0.1 1.adbrite.com
127.0.0.1 1.forgetstore.com
127.0.0.1 1.httpads.com
127.0.0.1 1.primaryads.com
127.0.0.1 104231.dtiblog.com
127.0.0.1 123.fluxads.com
127.0.0.1 123specialgifts.com
127.0.0.1 140cc.v.fwmrm.net
127.0.0.1 1und1.ivwbox.de
127.0.0.1 2-art-coliseum.com
127.0.0.1 2.adbrite.com
127.0.0.1 2.marketbanker.com
127.0.0.1 207-87-18-203.wsmg.digex.net
127.0.0.1 247support.adtech.fr
127.0.0.1 247support.adtech.us
127.0.0.1 24ratownik.hit.gemius.pl
127.0.0.1 25184.hittail.com
127.0.0.1 2754.btrll.com
127.0.0.1 2912a.v.fwmrm.net
127.0.0.1 3.adbrite.com
127.0.0.1 3.cennter.com
127.0.0.1 312.1d27c9b8fb.com
127.0.0.1 321cba.com
127.0.0.1 360ads.com
127.0.0.1 3fns.com
127.0.0.1 4.adbrite.com
127.0.0.1 4c28d6.r.axf8.net
127.0.0.1 4qinvite.4q.iperceptions.com
127.0.0.1 7500.com
127.0.0.1 76.a.boom.ro
127.0.0.1 7adpower.com
127.0.0.1 7bpeople.com
127.0.0.1 7bpeople.data.7bpeople.com
127.0.0.1 7cnbcnews.com
127.0.0.1 85103.hittail.com
127.0.0.1 8574dnj3yzjace8c8io6zr9u3n.hop.clickbank.net
127.0.0.1 888casino.com
127.0.0.1 961.com
127.0.0.1 9cf9.v.fwmrm.net
127.0.0.1 a.0day.kiev.ua
127.0.0.1 a.admaxserver.com
127.0.0.1 a.adready.com
127.0.0.1 a.ads1.msn.com
127.0.0.1 a.ads2.msn.com
127.0.0.1 a.adstome.com
127.0.0.1 a.as-eu.falkag.net
127.0.0.1 a.as-us.falkag.net
127.0.0.1 a.boom.ro
127.0.0.1 a.collective-media.net
127.0.0.1 a.kerg.net
127.0.0.1 a.ligatus.com
127.0.0.1 a.ligatus.de
127.0.0.1 a.mktw.net
127.0.0.1 a.prisacom.com
127.0.0.1 a.rad.live.com
127.0.0.1 a.rad.msn.com
127.0.0.1 a.ss34.on9mail.com
127.0.0.1 a.tadd.react2media.com
127.0.0.1 a.total-media.net
127.0.0.1 a.tribalfusion.com
127.0.0.1 a.triggit.com
127.0.0.1 a.websponsors.com
127.0.0.1 a01.gestionpub.com
127.0.0.1 a1.greenadworks.net
127.0.0.1 a1.interclick.com
127.0.0.1 a2.websponsors.com
127.0.0.1 a200.yieldoptimizer.com
127.0.0.1 a3.suntimes.com
127.0.0.1 a3.websponsors.com
127.0.0.1 a4.websponsors.com
127.0.0.1 a5.websponsors.com
127.0.0.1 aa.newsblock.dt00.net
127.0.0.1 aads.treehugger.com
127.0.0.1 aams1.aim4media.com
127.0.0.1 aan.amazon.com
127.0.0.1 aax-us-east.amazon-adsystem.com
127.0.0.1 abcnews.footprint.net
127.0.0.1 abrogatesdv.info
127.0.0.1 abseckw.adtlgc.com
127.0.0.1 ac.rnm.ca
127.0.0.1 ac.tynt.com
127.0.0.1 action.ientry.net
127.0.0.1 action.mathtag.com
127.0.0.1 action.media6degrees.com
127.0.0.1 actiondesk.com
127.0.0.1 actionflash.com
127.0.0.1 actionsplash.com
127.0.0.1 acvs.mediaonenetwork.net
127.0.0.1 acvsrv.mediaonenetwork.net
127.0.0.1 ad-audit.tubemogul.com
127.0.0.1 ad-souk.com
127.0.0.1 ad-uk.tiscali.com
127.0.0.1 ad.360yield.com
127.0.0.1 ad.3dnews.ru
127.0.0.1 ad.71i.de
127.0.0.1 ad.abcnews.com
127.0.0.1 ad.aboutwebservices.com
127.0.0.1 ad.adfunky.com
127.0.0.1 ad.adition.de
127.0.0.1 ad.adition.net
127.0.0.1 ad.adlegend.com
127.0.0.1 ad.admarketplace.net
127.0.0.1 ad.adnet.biz
127.0.0.1 ad.adnetwork.com.br
127.0.0.1 ad.adnetwork.net
127.0.0.1 ad.adorika.com
127.0.0.1 ad.adperium.com
127.0.0.1 ad.adriver.ru
127.0.0.1 ad.adserve.com
127.0.0.1 ad.adserverplus.com
127.0.0.1 ad.adsmart.net
127.0.0.1 ad.adtegrity.net
127.0.0.1 ad.adtoma.com
127.0.0.1 ad.adverticum.net
127.0.0.1 ad.advertstream.com
127.0.0.1 ad.adview.pl
127.0.0.1 ad.afilo.pl
127.0.0.1 ad.aftenposten.no
127.0.0.1 ad.aftonbladet.se
127.0.0.1 ad.afy11.net
127.0.0.1 ad.agava.tbn.ru
127.0.0.1 ad.agkn.com
127.0.0.1 ad.amgdgt.com
127.0.0.1 ad.aquamediadirect.com
127.0.0.1 ad.asv.de
127.0.0.1 ad.auditude.com
127.0.0.1 ad.bannerbank.ru
127.0.0.1 ad.bannerconnect.net
127.0.0.1 ad.bnmla.com
127.0.0.1 ad.cibleclick.com
127.0.0.1 ad.clickdistrict.com
127.0.0.1 ad.clickotmedia.com
127.0.0.1 ad.dc2.adtech.de
127.0.0.1 ad.designtaxi.com
127.0.0.1 ad.deviantart.com
127.0.0.1 ad.doubleclick.net
127.0.0.1 ad.egloos.com
127.0.0.1 ad.espn.starwave.com
127.0.0.1 ad.eurosport.com
127.0.0.1 ad.filmweb.pl
127.0.0.1 ad.firstadsolution.com
127.0.0.1 ad.flux.com
127.0.0.1 ad.funpic.de
127.0.0.1 ad.garantiarkadas.com
127.0.0.1 ad.gazeta.pl
127.0.0.1 ad.goo.ne.jp
127.0.0.1 ad.gr.doubleclick.net
127.0.0.1 ad.gra.pl
127.0.0.1 ad.greenmarquee.com
127.0.0.1 ad.hankooki.com
127.0.0.1 ad.harrenmedianetwork.com
127.0.0.1 ad.horvitznewspapers.net
127.0.0.1 ad.howstuffworks.com
127.0.0.1 ad.hulu.com
127.0.0.1 ad.iconadserver.com
127.0.0.1 ad.insightexpressai.com
127.0.0.1 ad.investopedia.com
127.0.0.1 ad.ir.ru
127.0.0.1 ad.isohunt.com
127.0.0.1 ad.iwin.com
127.0.0.1 ad.jamba.net
127.0.0.1 ad.jamster.ca
127.0.0.1 ad.kat.ph
127.0.0.1 ad.kataweb.it
127.0.0.1 ad.krutilka.ru
127.0.0.1 ad.leadcrunch.com
127.0.0.1 ad.linkexchange.com
127.0.0.1 ad.linksynergy.com
127.0.0.1 ad.mastermedia.ru
127.0.0.1 ad.media-servers.net
127.0.0.1 ad.moscowtimes.ru
127.0.0.1 ad.my.doubleclick.net
127.0.0.1 ad.nate.com
127.0.0.1 ad.network60.com
127.0.0.1 ad.nozonedata.com
127.0.0.1 ad.ohmynews.com
127.0.0.1 ad.parom.hu
127.0.0.1 ad.ph-prt.tbn.ru
127.0.0.1 ad.pravda.ru
127.0.0.1 ad.preferences.com
127.0.0.1 ad.pro-advertising.com
127.0.0.1 ad.propellerads.com
127.0.0.1 ad.prv.pl
127.0.0.1 ad.repubblica.it
127.0.0.1 ad.ru.doubleclick.net
127.0.0.1 ad.sensismediasmart.com.au
127.0.0.1 ad.showbizz.net
127.0.0.1 ad.slashgear.com
127.0.0.1 ad.sma.punto.net
127.0.0.1 ad.smni.com
127.0.0.1 ad.suprnova.org
127.0.0.1 ad.tbn.ru
127.0.0.1 ad.technoramedia.com
127.0.0.1 ad.text.tbn.ru
127.0.0.1 ad.tgdaily.com
127.0.0.1 ad.thehill.com
127.0.0.1 ad.thetyee.ca
127.0.0.1 ad.thewheelof.com
127.0.0.1 ad.tiscali.com
127.0.0.1 ad.tomshardware.com
127.0.0.1 ad.trafficmp.com
127.0.0.1 ad.turn.com
127.0.0.1 ad.tv2.no
127.0.0.1 ad.twitchguru.com
127.0.0.1 ad.ubnm.co.kr
127.0.0.1 ad.uk.tangozebra.com
127.0.0.1 ad.usatoday.com
127.0.0.1 ad.vurts.com
127.0.0.1 ad.webprovider.com
127.0.0.1 ad.wsod.com
127.0.0.1 ad.xtendmedia.com
127.0.0.1 ad.yadro.ru
127.0.0.1 ad.yieldmanager.com
127.0.0.1 ad.zanox.com
127.0.0.1 ad.zodera.hu
127.0.0.1 ad0.haynet.com
127.0.0.1 ad01.adonspot.com
127.0.0.1 ad01.focalink.com
127.0.0.1 ad01.mediacorpsingapore.com
127.0.0.1 ad02.focalink.com
127.0.0.1 ad03.focalink.com
127.0.0.1 ad04.focalink.com
127.0.0.1 ad05.focalink.com
127.0.0.1 ad06.focalink.com
127.0.0.1 ad07.focalink.com
127.0.0.1 ad08.focalink.com
127.0.0.1 ad09.focalink.com
127.0.0.1 ad1.adtitan.net
127.0.0.1 ad1.bannerbank.ru
127.0.0.1 ad1.clickhype.com
127.0.0.1 ad1.emediate.dk
127.0.0.1 ad1.emediate.se
127.0.0.1 ad1.gamezone.com
127.0.0.1 ad1.hotel.com
127.0.0.1 ad1.lbn.ru
127.0.0.1 ad1.peel.com
127.0.0.1 ad1.popcap.com
127.0.0.1 ad1.yomiuri.co.jp
127.0.0.1 ad1.yourmedia.com
127.0.0.1 ad10.bannerbank.ru
127.0.0.1 ad10.focalink.com
127.0.0.1 ad101com.adbureau.net
127.0.0.1 ad11.bannerbank.ru
127.0.0.1 ad11.focalink.com
127.0.0.1 ad12.bannerbank.ru
127.0.0.1 ad12.focalink.com
127.0.0.1 ad13.focalink.com
127.0.0.1 ad14.focalink.com
127.0.0.1 ad15.focalink.com
127.0.0.1 ad16.focalink.com
127.0.0.1 ad17.focalink.com
127.0.0.1 ad18.focalink.com
127.0.0.1 ad19.focalink.com
127.0.0.1 ad2.adecn.com
127.0.0.1 ad2.bannerbank.ru
127.0.0.1 ad2.bannerhost.ru
127.0.0.1 ad2.bbmedia.cz
127.0.0.1 ad2.cooks.com
127.0.0.1 ad2.firehousezone.com
127.0.0.1 ad2.hotel.com
127.0.0.1 ad2.ip.ro
127.0.0.1 ad2.lbn.ru
127.0.0.1 ad2.nationalreview.com
127.0.0.1 ad2.pamedia.com
127.0.0.1 ad2.parom.hu
127.0.0.1 ad2.peel.com
127.0.0.1 ad2.pl
127.0.0.1 ad2.pl.mediainter.net
127.0.0.1 ad2.sbisec.co.jp
127.0.0.1 ad2.smni.com
127.0.0.1 ad234.prbn.ru
127.0.0.1 ad2games.com
127.0.0.1 ad3.adfarm1.adition.com
127.0.0.1 ad3.bannerbank.ru
127.0.0.1 ad3.bb.ru
127.0.0.1 ad3.lbn.ru
127.0.0.1 ad3.nationalreview.com
127.0.0.1 ad3.rambler.ru
127.0.0.1 ad4.adfarm1.adition.com
127.0.0.1 ad4.bannerbank.ru
127.0.0.1 ad4.lbn.ru
127.0.0.1 ad4.liverail.com
127.0.0.1 ad4.speedbit.com
127.0.0.1 ad41.atlas.cz
127.0.0.1 ad5.bannerbank.ru
127.0.0.1 ad5.lbn.ru
127.0.0.1 ad6.bannerbank.ru
127.0.0.1 ad6.horvitznewspapers.net
127.0.0.1 ad7.bannerbank.ru
127.0.0.1 ad8.bannerbank.ru
127.0.0.1 ad9.bannerbank.ru
127.0.0.1 adap.tv
127.0.0.1 adblade.com
127.0.0.1 adbnr.ru
127.0.0.1 adbot.theonion.com
127.0.0.1 adbrite.com
127.0.0.1 adc2.adcentriconline.com
127.0.0.1 adcache.aftenposten.no
127.0.0.1 adcanadian.com
127.0.0.1 adcash.com
127.0.0.1 adcast.deviantart.com
127.0.0.1 adcentric.randomseed.com
127.0.0.1 adcentriconline.com
127.0.0.1 adclick.hit.gemius.pl
127.0.0.1 adclient-af.lp.uol.com.br
127.0.0.1 adclient.uimserv.net
127.0.0.1 adcode.adengage.com
127.0.0.1 adcontent.gamespy.com
127.0.0.1 adcontent.reedbusiness.com
127.0.0.1 adcontroller.unicast.com
127.0.0.1 adcount.ohmynews.com
127.0.0.1 adcreative.tribuneinteractive.com
127.0.0.1 adcycle.footymad.net
127.0.0.1 adcycle.icpeurope.net
127.0.0.1 addelivery.thestreet.com
127.0.0.1 addfreestats.com
127.0.0.1 addthis.com
127.0.0.1 addthiscdn.com
127.0.0.1 adecn.com
127.0.0.1 adexpansion.com
127.0.0.1 adext.inkclub.com
127.0.0.1 adf.ly
127.0.0.1 adfarm.mserve.ca
127.0.0.1 adfarm1.adition.com
127.0.0.1 adfiles.pitchforkmedia.com
127.0.0.1 adforce.ads.imgis.com
127.0.0.1 adforce.adtech.de
127.0.0.1 adforce.adtech.fr
127.0.0.1 adforce.adtech.us
127.0.0.1 adforce.imgis.com
127.0.0.1 adform.com
127.0.0.1 adfu.blockstackers.com
127.0.0.1 adfusion.com
127.0.0.1 adgardener.com
127.0.0.1 adgraphics.theonion.com
127.0.0.1 adgroup.naver.com
127.0.0.1 adhearus.com
127.0.0.1 adhese.be
127.0.0.1 adhese.com
127.0.0.1 adhitzads.com
127.0.0.1 adhref.pl
127.0.0.1 adi.mainichi.co.jp
127.0.0.1 adidm.idmnet.pl
127.0.0.1 adidm.supermedia.pl
127.0.0.1 adimage.asia1.com.sg
127.0.0.1 adimage.asiaone.com
127.0.0.1 adimage.asiaone.com.sg
127.0.0.1 adimage.blm.net
127.0.0.1 adimages.earthweb.com
127.0.0.1 adimages.go.com
127.0.0.1 adimages.mp3.com
127.0.0.1 adimages.watchmygf.net
127.0.0.1 adimg.activeadv.net
127.0.0.1 adimg.com.com
127.0.0.1 adincl.gopher.com
127.0.0.1 adipics.com
127.0.0.1 adireland.com
127.0.0.1 adition.com
127.0.0.1 adj1.thruport.com
127.0.0.1 adj10.thruport.com
127.0.0.1 adj11.thruport.com
127.0.0.1 adj12.thruport.com
127.0.0.1 adj13.thruport.com
127.0.0.1 adj14.thruport.com
127.0.0.1 adj15.thruport.com
127.0.0.1 adj16.thruport.com
127.0.0.1 adj16r1.thruport.com
127.0.0.1 adj17.thruport.com
127.0.0.1 adj18.thruport.com
127.0.0.1 adj19.thruport.com
127.0.0.1 adj2.thruport.com
127.0.0.1 adj22.thruport.com
127.0.0.1 adj23.thruport.com
127.0.0.1 adj24.thruport.com
127.0.0.1 adj25.thruport.com
127.0.0.1 adj26.thruport.com
127.0.0.1 adj27.thruport.com
127.0.0.1 adj28.thruport.com
127.0.0.1 adj29.thruport.com
127.0.0.1 adj3.thruport.com
127.0.0.1 adj30.thruport.com
127.0.0.1 adj31.thruport.com
127.0.0.1 adj32.thruport.com
127.0.0.1 adj33.thruport.com
127.0.0.1 adj34.thruport.com
127.0.0.1 adj35.thruport.com
127.0.0.1 adj36.thruport.com
127.0.0.1 adj37.thruport.com
127.0.0.1 adj38.thruport.com
127.0.0.1 adj39.thruport.com
127.0.0.1 adj4.thruport.com
127.0.0.1 adj40.thruport.com
127.0.0.1 adj41.thruport.com
127.0.0.1 adj43.thruport.com
127.0.0.1 adj44.thruport.com
127.0.0.1 adj45.thruport.com
127.0.0.1 adj46.thruport.com
127.0.0.1 adj47.thruport.com
127.0.0.1 adj48.thruport.com
127.0.0.1 adj49.thruport.com
127.0.0.1 adj5.thruport.com
127.0.0.1 adj50.thruport.com
127.0.0.1 adj51.thruport.com
127.0.0.1 adj52.thruport.com
127.0.0.1 adj53.thruport.com
127.0.0.1 adj54.thruport.com
127.0.0.1 adj55.thruport.com
127.0.0.1 adj56.thruport.com
127.0.0.1 adj6.thruport.com
127.0.0.1 adj7.thruport.com
127.0.0.1 adj8.thruport.com
127.0.0.1 adj9.thruport.com
127.0.0.1 adjmps.com
127.0.0.1 adjuggler.net
127.0.0.1 adjuggler.yourdictionary.com
127.0.0.1 adkontekst.pl
127.0.0.1 adm.shacknews.com
127.0.0.1 adman.freeze.com
127.0.0.1 adman.in.gr
127.0.0.1 admanager.adam4adam.com
127.0.0.1 admanager.beweb.com
127.0.0.1 admanager.btopenworld.com
127.0.0.1 admanager.collegepublisher.com
127.0.0.1 admanager1.collegepublisher.com
127.0.0.1 admanager2.broadbandpublisher.com
127.0.0.1 admanager3.collegepublisher.com
127.0.0.1 admatch-syndication.mochila.com
127.0.0.1 admatcher.videostrip.com #http://admatcher.videostrip.com/?puid=23940627&amp;host=www.dumpert.nl&amp;categories=default
127.0.0.1 admax.quisma.com
127.0.0.1 admedia.xoom.com
127.0.0.1 admeld.com
127.0.0.1 admeta.vo.llnwd.net
127.0.0.1 admin.digitalacre.com
127.0.0.1 admin.hotkeys.com
127.0.0.1 admin.inq.com
127.0.0.1 admonkey.dapper.net
127.0.0.1 adms.physorg.com
127.0.0.1 adn.ebay.com
127.0.0.1 adn.kinkydollars.com
127.0.0.1 adnet.asahi.com
127.0.0.1 adnet.biz
127.0.0.1 adnet.chicago.tribune.com
127.0.0.1 adnet.com
127.0.0.1 adnet.de
127.0.0.1 adnetwork.nextgen.net
127.0.0.1 adnetxchange.com
127.0.0.1 adng.ascii24.com
127.0.0.1 adnxs.com
127.0.0.1 adnxs.revsci.net
127.0.0.1 adobe.tt.omtrdc.net
127.0.0.1 adobee.com
127.0.0.1 adocean.pl
127.0.0.1 adopt.euroclick.com
127.0.0.1 adopt.precisead.com
127.0.0.1 adotube.com
127.0.0.1 adp.gazeta.pl
127.0.0.1 adpepper.dk
127.0.0.1 adpick.switchboard.com
127.0.0.1 adpulse.ads.targetnet.com
127.0.0.1 adpush.dreamscape.com
127.0.0.1 adq.nextag.com
127.0.0.1 adremote.pathfinder.com
127.0.0.1 adremote.timeinc.aol.com
127.0.0.1 adremote.timeinc.net
127.0.0.1 adriver.ru
127.0.0.1 adroll.com
127.0.0.1 ads-de.spray.net
127.0.0.1 ads-dev.youporn.com
127.0.0.1 ads-direct.prodigy.net
127.0.0.1 ads-local.sixapart.com
127.0.0.1 ads-rm.looksmart.com
127.0.0.1 ads-t.ru
127.0.0.1 ads-web.mail.com
127.0.0.1 ads.5ci.lt
127.0.0.1 ads.7days.ae
127.0.0.1 ads.8833.com
127.0.0.1 ads.abs-cbn.com
127.0.0.1 ads.accelerator-media.com
127.0.0.1 ads.aceweb.net
127.0.0.1 ads.active.com
127.0.0.1 ads.activeagent.at
127.0.0.1 ads.ad-flow.com
127.0.0.1 ads.ad4game.com
127.0.0.1 ads.adap.tv
127.0.0.1 ads.adbrite.com
127.0.0.1 ads.adbroker.de
127.0.0.1 ads.adcorps.com
127.0.0.1 ads.addesktop.com
127.0.0.1 ads.addynamix.com
127.0.0.1 ads.adengage.com
127.0.0.1 ads.adfox.ru
127.0.0.1 ads.adgoto.com
127.0.0.1 ads.adhall.com
127.0.0.1 ads.adhearus.com
127.0.0.1 ads.adhostingsolutions.com
127.0.0.1 ads.admarvel.com
127.0.0.1 ads.admaximize.com
127.0.0.1 ads.admonitor.net
127.0.0.1 ads.adn.com
127.0.0.1 ads.adroar.com
127.0.0.1 ads.adsag.com
127.0.0.1 ads.adsbookie.com
127.0.0.1 ads.adshareware.net
127.0.0.1 ads.adsinimages.com
127.0.0.1 ads.adsonar.com
127.0.0.1 ads.adtegrity.net
127.0.0.1 ads.adtiger.de
127.0.0.1 ads.adultfriendfinder.com
127.0.0.1 ads.adultswim.com
127.0.0.1 ads.advance.net
127.0.0.1 ads.adverline.com
127.0.0.1 ads.adviva.net
127.0.0.1 ads.advolume.com
127.0.0.1 ads.adworldnetwork.com
127.0.0.1 ads.adx.nu
127.0.0.1 ads.adxpansion.com
127.0.0.1 ads.adxpose.com
127.0.0.1 ads.adxpose.mpire.akadns.net
127.0.0.1 ads.affiliates.match.com
127.0.0.1 ads.ah-ha.com
127.0.0.1 ads.aintitcool.com
127.0.0.1 ads.airamericaradio.com
127.0.0.1 ads.ak.facebook.com
127.0.0.1 ads.al.com
127.0.0.1 ads.albawaba.com
127.0.0.1 ads.allsites.com
127.0.0.1 ads.allvertical.com
127.0.0.1 ads.amarillo.com
127.0.0.1 ads.amateurmatch.com
127.0.0.1 ads.amazingmedia.com
127.0.0.1 ads.amgdgt.com
127.0.0.1 ads.ami-admin.com
127.0.0.1 ads.anm.co.uk
127.0.0.1 ads.anvato.com
127.0.0.1 ads.aol.com
127.0.0.1 ads.apartmenttherapy.com
127.0.0.1 ads.apn.co.nz
127.0.0.1 ads.apn.co.za
127.0.0.1 ads.appleinsider.com
127.0.0.1 ads.arcadechain.com
127.0.0.1 ads.aroundtherings.com
127.0.0.1 ads.as4x.tmcs.net
127.0.0.1 ads.as4x.tmcs.ticketmaster.ca
127.0.0.1 ads.as4x.tmcs.ticketmaster.com
127.0.0.1 ads.asia1.com
127.0.0.1 ads.asia1.com.sg
127.0.0.1 ads.asp.net
127.0.0.1 ads.aspalliance.com
127.0.0.1 ads.aspentimes.com
127.0.0.1 ads.associatedcontent.com
127.0.0.1 ads.astalavista.us
127.0.0.1 ads.atlantamotorspeedway.com
127.0.0.1 ads.auctionads.com
127.0.0.1 ads.auctioncity.co.nz
127.0.0.1 ads.auctions.yahoo.com
127.0.0.1 ads.augusta.com
127.0.0.1 ads.aversion2.com
127.0.0.1 ads.aws.sitepoint.com
127.0.0.1 ads.azjmp.com
127.0.0.1 ads.baazee.com
127.0.0.1 ads.bangkokpost.co.th
127.0.0.1 ads.banner.t-online.de
127.0.0.1 ads.barnonedrinks.com
127.0.0.1 ads.battle.net
127.0.0.1 ads.bauerpublishing.com
127.0.0.1 ads.baventures.com
127.0.0.1 ads.bbcworld.com
127.0.0.1 ads.bcnewsgroup.com
127.0.0.1 ads.beeb.com
127.0.0.1 ads.beliefnet.com
127.0.0.1 ads.belointeractive.com
127.0.0.1 ads.beta.itravel2000.com
127.0.0.1 ads.betanews.com
127.0.0.1 ads.bfast.com
127.0.0.1 ads.bfm.valueclick.net
127.0.0.1 ads.bianca.com
127.0.0.1 ads.bidclix.com
127.0.0.1 ads.bidvertiser.com
127.0.0.1 ads.bigcitytools.com
127.0.0.1 ads.biggerboat.com
127.0.0.1 ads.bitsonthewire.com
127.0.0.1 ads.bizhut.com
127.0.0.1 ads.blixem.nl
127.0.0.1 ads.blog.com
127.0.0.1 ads.blogherads.com
127.0.0.1 ads.bloomberg.com
127.0.0.1 ads.blp.calueclick.net
127.0.0.1 ads.blp.valueclick.net
127.0.0.1 ads.bluelithium.com
127.0.0.1 ads.bluemountain.com
127.0.0.1 ads.bonnint.net
127.0.0.1 ads.box.sk
127.0.0.1 ads.brabys.com
127.0.0.1 ads.brand.net
127.0.0.1 ads.bridgetrack.com
127.0.0.1 ads.britishexpats.com
127.0.0.1 ads.buscape.com.br
127.0.0.1 ads.businessclick.com
127.0.0.1 ads.businessweek.com
127.0.0.1 ads.calgarysun.com
127.0.0.1 ads.callofdutyblackopsforum.net
127.0.0.1 ads.camrecord.com
127.0.0.1 ads.canoe.ca
127.0.0.1 ads.cardea.se
127.0.0.1 ads.cardplayer.com
127.0.0.1 ads.carltononline.com
127.0.0.1 ads.carocean.co.uk
127.0.0.1 ads.casinocity.com
127.0.0.1 ads.catholic.org
127.0.0.1 ads.cavello.com
127.0.0.1 ads.cbc.ca
127.0.0.1 ads.cdfreaks.com
127.0.0.1 ads.cdnow.com
127.0.0.1 ads.centraliprom.com
127.0.0.1 ads.cgchannel.com
127.0.0.1 ads.chalomumbai.com
127.0.0.1 ads.champs-elysees.com
127.0.0.1 ads.channel4.com
127.0.0.1 ads.checkm8.co.za
127.0.0.1 ads.chipcenter.com
127.0.0.1 ads.chumcity.com
127.0.0.1 ads.cjonline.com
127.0.0.1 ads.clamav.net
127.0.0.1 ads.clara.net
127.0.0.1 ads.clearchannel.com
127.0.0.1 ads.cleveland.com
127.0.0.1 ads.clickability.com
127.0.0.1 ads.clickad.com.pl
127.0.0.1 ads.clickagents.com
127.0.0.1 ads.clickhouse.com
127.0.0.1 ads.clicksor.com
127.0.0.1 ads.clickthru.net
127.0.0.1 ads.clicmanager.fr
127.0.0.1 ads.clubzone.com
127.0.0.1 ads.cluster01.oasis.zmh.zope.net
127.0.0.1 ads.cmediaworld.com
127.0.0.1 ads.cmg.valueclick.net
127.0.0.1 ads.cnn.com
127.0.0.1 ads.cnngo.com
127.0.0.1 ads.cobrad.com
127.0.0.1 ads.collegclub.com
127.0.0.1 ads.collegehumor.com
127.0.0.1 ads.collegemix.com
127.0.0.1 ads.com.com
127.0.0.1 ads.comediagroup.hu
127.0.0.1 ads.comicbookresources.com
127.0.0.1 ads.contactmusic.com
127.0.0.1 ads.contentabc.com
127.0.0.1 ads.coopson.com
127.0.0.1 ads.corusradionetwork.com
127.0.0.1 ads.courierpostonline.com
127.0.0.1 ads.cpsgsoftware.com
127.0.0.1 ads.crakmedia.com
127.0.0.1 ads.crapville.com
127.0.0.1 ads.creative-serving.com
127.0.0.1 ads.crosscut.com
127.0.0.1 ads.ctvdigital.net
127.0.0.1 ads.currantbun.com
127.0.0.1 ads.cyberfight.ru
127.0.0.1 ads.cybersales.cz
127.0.0.1 ads.cybertrader.com
127.0.0.1 ads.dada.it
127.0.0.1 ads.danworld.net
127.0.0.1 ads.dbforums.com
127.0.0.1 ads.ddj.com
127.0.0.1 ads.dealnews.com
127.0.0.1 ads.democratandchronicle.com
127.0.0.1 ads.dennisnet.co.uk
127.0.0.1 ads.designboom.com
127.0.0.1 ads.designtaxi.com
127.0.0.1 ads.desmoinesregister.com
127.0.0.1 ads.detelefoongids.nl
127.0.0.1 ads.developershed.com
127.0.0.1 ads.deviantart.com
127.0.0.1 ads.digital-digest.com
127.0.0.1 ads.digitalacre.com
127.0.0.1 ads.digitalhealthcare.com
127.0.0.1 ads.digitalmedianet.com
127.0.0.1 ads.digitalpoint.com
127.0.0.1 ads.dimcab.com
127.0.0.1 ads.directionsmag.com
127.0.0.1 ads.discovery.com
127.0.0.1 ads.dk
127.0.0.1 ads.doclix.com
127.0.0.1 ads.domeus.com
127.0.0.1 ads.dontpanicmedia.com
127.0.0.1 ads.dothads.com
127.0.0.1 ads.doubleviking.com
127.0.0.1 ads.drf.com
127.0.0.1 ads.drivelinemedia.com
127.0.0.1 ads.drugs.com
127.0.0.1 ads.dumpalink.com
127.0.0.1 ads.ecircles.com
127.0.0.1 ads.economist.com
127.0.0.1 ads.ecosalon.com
127.0.0.1 ads.edirectme.com
127.0.0.1 ads.einmedia.com
127.0.0.1 ads.eircom.net
127.0.0.1 ads.emeraldcoast.com
127.0.0.1 ads.enliven.com
127.0.0.1 ads.erotism.com
127.0.0.1 ads.espn.adsonar.com
127.0.0.1 ads.eu.msn.com
127.0.0.1 ads.eudora.com
127.0.0.1 ads.euniverseads.com
127.0.0.1 ads.examiner.net
127.0.0.1 ads.exhedra.com
127.0.0.1 ads.expedia.com
127.0.0.1 ads.expekt.com
127.0.0.1 ads.ezboard.com
127.0.0.1 ads.fairfax.com.au
127.0.0.1 ads.fark.com
127.0.0.1 ads.fayettevillenc.com
127.0.0.1 ads.filecloud.com
127.0.0.1 ads.fileindexer.com
127.0.0.1 ads.filmup.com
127.0.0.1 ads.first-response.be
127.0.0.1 ads.flabber.nl
127.0.0.1 ads.flashgames247.com
127.0.0.1 ads.fling.com
127.0.0.1 ads.floridatoday.com
127.0.0.1 ads.fool.com
127.0.0.1 ads.forbes.com
127.0.0.1 ads.forbes.net
127.0.0.1 ads.fortunecity.com
127.0.0.1 ads.fredericksburg.com
127.0.0.1 ads.freebannertrade.com
127.0.0.1 ads.freshmeat.net
127.0.0.1 ads.fresnobee.com
127.0.0.1 ads.friendfinder.com
127.0.0.1 ads.ft.com
127.0.0.1 ads.gamblinghit.com
127.0.0.1 ads.game.net
127.0.0.1 ads.gamecity.net
127.0.0.1 ads.gamecopyworld.no
127.0.0.1 ads.gameinformer.com
127.0.0.1 ads.gamershell.com
127.0.0.1 ads.gamespy.com
127.0.0.1 ads.gamespyid.com
127.0.0.1 ads.gateway.com
127.0.0.1 ads.gawker.com
127.0.0.1 ads.gettools.com
127.0.0.1 ads.gigaom.com.php5-12.websitetestlink.com
127.0.0.1 ads.globeandmail.com
127.0.0.1 ads.gmg.valueclick.net
127.0.0.1 ads.gmodules.com
127.0.0.1 ads.god.co.uk
127.0.0.1 ads.gorillanation.com
127.0.0.1 ads.gplusmedia.com
127.0.0.1 ads.granadamedia.com
127.0.0.1 ads.greenbaypressgazette.com
127.0.0.1 ads.greenvilleonline.com
127.0.0.1 ads.guardian.co.uk
127.0.0.1 ads.guardianunlimited.co.uk
127.0.0.1 ads.gunaxin.com
127.0.0.1 ads.halogennetwork.com
127.0.0.1 ads.hamptonroads.com
127.0.0.1 ads.hamtonroads.com
127.0.0.1 ads.hardwarezone.com
127.0.0.1 ads.harpers.org
127.0.0.1 ads.hbv.de
127.0.0.1 ads.he.valueclick.net
127.0.0.1 ads.hearstmags.com
127.0.0.1 ads.heartlight.org
127.0.0.1 ads.herald-mail.com
127.0.0.1 ads.heraldnet.com
127.0.0.1 ads.heraldonline.com
127.0.0.1 ads.heraldsun.com
127.0.0.1 ads.heroldonline.com
127.0.0.1 ads.hitcents.com
127.0.0.1 ads.hlwd.valueclick.net
127.0.0.1 ads.hollandsentinel.com
127.0.0.1 ads.hollywood.com
127.0.0.1 ads.hooqy.com
127.0.0.1 ads.hothardware.com
127.0.0.1 ads.hulu.com
127.0.0.1 ads.hulu.com.edgesuite.net
127.0.0.1 ads.humorbua.no
127.0.0.1 ads.i-am-bored.com
127.0.0.1 ads.i12.de
127.0.0.1 ads.i33.com
127.0.0.1 ads.iafrica.com
127.0.0.1 ads.iboost.com
127.0.0.1 ads.icq.com
127.0.0.1 ads.iforex.com
127.0.0.1 ads.ign.com
127.0.0.1 ads.illuminatednation.com
127.0.0.1 ads.imdb.com
127.0.0.1 ads.imgur.com
127.0.0.1 ads.imposibil.ro
127.0.0.1 ads.indiatimes.com
127.0.0.1 ads.indya.com
127.0.0.1 ads.indystar.com
127.0.0.1 ads.inedomedia.com
127.0.0.1 ads.inetdirectories.com
127.0.0.1 ads.inetinteractive.com
127.0.0.1 ads.infi.net
127.0.0.1 ads.infospace.com
127.0.0.1 ads.injersey.com
127.0.0.1 ads.insidehighered.com
127.0.0.1 ads.intellicast.com
127.0.0.1 ads.internic.co.il
127.0.0.1 ads.inthesidebar.com
127.0.0.1 ads.iol.co.il
127.0.0.1 ads.ipowerweb.com
127.0.0.1 ads.ireport.com
127.0.0.1 ads.isat-tech.com
127.0.0.1 ads.isoftmarketing.com
127.0.0.1 ads.isum.de
127.0.0.1 ads.itv.com
127.0.0.1 ads.iwon.com
127.0.0.1 ads.jacksonville.com
127.0.0.1 ads.jeneauempire.com
127.0.0.1 ads.jetphotos.net
127.0.0.1 ads.jewcy.com
127.0.0.1 ads.jimworld.com
127.0.0.1 ads.joetec.net
127.0.0.1 ads.jokaroo.com
127.0.0.1 ads.jornadavirtual.com.mx
127.0.0.1 ads.jossip.com
127.0.0.1 ads.jpost.com
127.0.0.1 ads.jubii.dk
127.0.0.1 ads.juicyads.com
127.0.0.1 ads.juneauempire.com
127.0.0.1 ads.jwtt3.com
127.0.0.1 ads.kazaa.com
127.0.0.1 ads.keywordblocks.com
127.0.0.1 ads.kleinman.com
127.0.0.1 ads.kmpads.com
127.0.0.1 ads.koreanfriendfinder.com
127.0.0.1 ads.ksl.com
127.0.0.1 ads.leo.org
127.0.0.1 ads.lfstmedia.com
127.0.0.1 ads.lilengine.com
127.0.0.1 ads.link4ads.com
127.0.0.1 ads.linksponsor.com
127.0.0.1 ads.linktracking.net
127.0.0.1 ads.linuxjournal.com
127.0.0.1 ads.linuxsecurity.com
127.0.0.1 ads.list-universe.com
127.0.0.1 ads.live365.com
127.0.0.1 ads.ljworld.com
127.0.0.1 ads.lnkworld.com
127.0.0.1 ads.localnow.com
127.0.0.1 ads.lubbockonline.com
127.0.0.1 ads.lucidmedia.com
127.0.0.1 ads.lucidmedia.com.gslb.com
127.0.0.1 ads.lycos-europe.com
127.0.0.1 ads.lycos.com
127.0.0.1 ads.lzjl.com
127.0.0.1 ads.macnews.de
127.0.0.1 ads.macupdate.com
127.0.0.1 ads.madison.com
127.0.0.1 ads.madisonavenue.com
127.0.0.1 ads.magnetic.is
127.0.0.1 ads.mail.com
127.0.0.1 ads.mambocommunities.com
127.0.0.1 ads.mariuana.it
127.0.0.1 ads.mcafee.com
127.0.0.1 ads.mdchoice.com
127.0.0.1 ads.mediamayhemcorp.com
127.0.0.1 ads.mediaodyssey.com
127.0.0.1 ads.mediaturf.net
127.0.0.1 ads.mefeedia.com
127.0.0.1 ads.megaproxy.com
127.0.0.1 ads.metblogs.com
127.0.0.1 ads.mgnetwork.com
127.0.0.1 ads.mindsetnetwork.com
127.0.0.1 ads.miniclip.com
127.0.0.1 ads.mininova.org
127.0.0.1 ads.mircx.com
127.0.0.1 ads.mixtraffic.com
127.0.0.1 ads.mlive.com
127.0.0.1 ads.mm.ap.org
127.0.0.1 ads.mndaily.com
127.0.0.1 ads.mobiledia.com
127.0.0.1 ads.mobygames.com
127.0.0.1 ads.modbee.com
127.0.0.1 ads.mofos.com
127.0.0.1 ads.money.pl
127.0.0.1 ads.monster.com
127.0.0.1 ads.mouseplanet.com
127.0.0.1 ads.movieweb.com
127.0.0.1 ads.mp3searchy.com
127.0.0.1 ads.mt.valueclick.net
127.0.0.1 ads.mtv.uol.com.br
127.0.0.1 ads.multimania.lycos.fr
127.0.0.1 ads.musiccity.com
127.0.0.1 ads.mustangworks.com
127.0.0.1 ads.mysimon.com
127.0.0.1 ads.mytelus.com
127.0.0.1 ads.nandomedia.com
127.0.0.1 ads.nationalreview.com
127.0.0.1 ads.nativeinstruments.de
127.0.0.1 ads.neoseeker.com
127.0.0.1 ads.neowin.net
127.0.0.1 ads.nerve.com
127.0.0.1 ads.netmechanic.com
127.0.0.1 ads.networkwcs.net
127.0.0.1 ads.networldmedia.net
127.0.0.1 ads.neudesicmediagroup.com
127.0.0.1 ads.newcity.com
127.0.0.1 ads.newcitynet.com
127.0.0.1 ads.newdream.net
127.0.0.1 ads.newgrounds.com
127.0.0.1 ads.newsint.co.uk
127.0.0.1 ads.newsminerextra.com
127.0.0.1 ads.newsobserver.com
127.0.0.1 ads.newsquest.co.uk
127.0.0.1 ads.newtention.net
127.0.0.1 ads.newtimes.com
127.0.0.1 ads.ngenuity.com
127.0.0.1 ads.ninemsn.com.au
127.0.0.1 ads.nola.com
127.0.0.1 ads.northjersey.com
127.0.0.1 ads.novem.pl
127.0.0.1 ads.nowrunning.com
127.0.0.1 ads.npr.valueclick.net
127.0.0.1 ads.ntadvice.com
127.0.0.1 ads.nudecards.com
127.0.0.1 ads.nwsource.com
127.0.0.1 ads.nwsource.com.edgesuite.net
127.0.0.1 ads.nyi.net
127.0.0.1 ads.nyjournalnews.com
127.0.0.1 ads.nypost.com
127.0.0.1 ads.nytimes.com
127.0.0.1 ads.o2.pl
127.0.0.1 ads.ole.com
127.0.0.1 ads.omaha.com
127.0.0.1 ads.online.ie
127.0.0.1 ads.onlineathens.com
127.0.0.1 ads.onvertise.com
127.0.0.1 ads.ookla.com
127.0.0.1 ads.open.pl
127.0.0.1 ads.opensubtitles.org
127.0.0.1 ads.oregonlive.com
127.0.0.1 ads.orsm.net
127.0.0.1 ads.osdn.com
127.0.0.1 ads.parrysound.com
127.0.0.1 ads.partner2profit.com
127.0.0.1 ads.pastemagazine.com
127.0.0.1 ads.paxnet.co.kr
127.0.0.1 ads.pcper.com
127.0.0.1 ads.pdxguide.com
127.0.0.1 ads.peel.com
127.0.0.1 ads.peninsulaclarion.com
127.0.0.1 ads.penny-arcade.com
127.0.0.1 ads.pennyweb.com
127.0.0.1 ads.people.com.cn
127.0.0.1 ads.pg.valueclick.net
127.0.0.1 ads.pheedo.com
127.0.0.1 ads.phillyburbs.com
127.0.0.1 ads.phpclasses.org
127.0.0.1 ads.pilotonline.com
127.0.0.1 ads.pitchforkmedia.com
127.0.0.1 ads.pittsburghlive.com
127.0.0.1 ads.pixiq.com
127.0.0.1 ads.place1.com
127.0.0.1 ads.planet-f1.com
127.0.0.1 ads.plantyours.com
127.0.0.1 ads.pni.com
127.0.0.1 ads.pno.net
127.0.0.1 ads.poconorecord.com
127.0.0.1 ads.pointroll.com
127.0.0.1 ads.portlandmercury.com
127.0.0.1 ads.premiumnetwork.com
127.0.0.1 ads.premiumnetwork.net
127.0.0.1 ads.pressdemo.com
127.0.0.1 ads.pricescan.com
127.0.0.1 ads.primaryclick.com
127.0.0.1 ads.primeinteractive.net
127.0.0.1 ads.prisacom.com
127.0.0.1 ads.pro-market.net
127.0.0.1 ads.pro-market.net.edgesuite.net
127.0.0.1 ads.profitsdeluxe.com
127.0.0.1 ads.profootballtalk.com
127.0.0.1 ads.program3.com
127.0.0.1 ads.prospect.org
127.0.0.1 ads.pubmatic.com
127.0.0.1 ads.queendom.com
127.0.0.1 ads.quicken.com
127.0.0.1 ads.rackshack.net
127.0.0.1 ads.rasmussenreports.com
127.0.0.1 ads.ratemyprofessors.com
127.0.0.1 ads.rcgroups.com
127.0.0.1 ads.rdstore.com
127.0.0.1 ads.realcastmedia.com
127.0.0.1 ads.realcities.com
127.0.0.1 ads.realmedia.de
127.0.0.1 ads.realtechnetwork.net
127.0.0.1 ads.reason.com
127.0.0.1 ads.rediff.com
127.0.0.1 ads.redorbit.com
127.0.0.1 ads.register.com
127.0.0.1 ads.revenews.com
127.0.0.1 ads.revenue.net
127.0.0.1 ads.revsci.net
127.0.0.1 ads.rim.co.uk
127.0.0.1 ads.roanoke.com
127.0.0.1 ads.rockstargames.com
127.0.0.1 ads.rodale.com
127.0.0.1 ads.roiserver.com
127.0.0.1 ads.rondomondo.com
127.0.0.1 ads.rootzoo.com
127.0.0.1 ads.rottentomatoes.com
127.0.0.1 ads.rp-online.de
127.0.0.1 ads.ruralpress.com
127.0.0.1 ads.sacbee.com
127.0.0.1 ads.satyamonline.com
127.0.0.1 ads.savannahnow.com
127.0.0.1 ads.scabee.com
127.0.0.1 ads.schwabtrader.com
127.0.0.1 ads.scifi.com
127.0.0.1 ads.seattletimes.com
127.0.0.1 ads.sfusion.com
127.0.0.1 ads.shizmoo.com
127.0.0.1 ads.shoppingads.com
127.0.0.1 ads.shoutfile.com
127.0.0.1 ads.sify.com
127.0.0.1 ads.simtel.com
127.0.0.1 ads.simtel.net
127.0.0.1 ads.sitemeter.com
127.0.0.1 ads.sixapart.com
127.0.0.1 ads.sl.interpals.net
127.0.0.1 ads.smartclick.com
127.0.0.1 ads.smartclicks.com
127.0.0.1 ads.smartclicks.net
127.0.0.1 ads.snowball.com
127.0.0.1 ads.socialmedia.com
127.0.0.1 ads.sohh.com
127.0.0.1 ads.somethingawful.com
127.0.0.1 ads.space.com
127.0.0.1 ads.specificclick.com
127.0.0.1 ads.specificmedia.com
127.0.0.1 ads.specificpop.com
127.0.0.1 ads.sptimes.com
127.0.0.1 ads.spymac.net
127.0.0.1 ads.stackoverflow.com
127.0.0.1 ads.starbanner.com
127.0.0.1 ads.stephensmedia.com
127.0.0.1 ads.stileproject.com
127.0.0.1 ads.stupid.com
127.0.0.1 ads.sunjournal.com
127.0.0.1 ads.sup.com
127.0.0.1 ads.swiftnews.com
127.0.0.1 ads.switchboard.com
127.0.0.1 ads.teamyehey.com
127.0.0.1 ads.technoratimedia.com
127.0.0.1 ads.techtv.com
127.0.0.1 ads.techvibes.com
127.0.0.1 ads.techweb.com
127.0.0.1 ads.telegraaf.nl
127.0.0.1 ads.telegraph.co.uk
127.0.0.1 ads.the15thinternet.com
127.0.0.1 ads.theawl.com
127.0.0.1 ads.thebugs.ws
127.0.0.1 ads.thecoolhunter.net
127.0.0.1 ads.thecrimson.com
127.0.0.1 ads.thefrisky.com
127.0.0.1 ads.thegauntlet.com
127.0.0.1 ads.theglobeandmail.com   
127.0.0.1 ads.theindependent.com
127.0.0.1 ads.theolympian.com
127.0.0.1 ads.thesmokinggun.com
127.0.0.1 ads.thestar.com       #Toronto Star
127.0.0.1 ads.thestranger.com
127.0.0.1 ads.thewebfreaks.com
127.0.0.1 ads.timesunion.com
127.0.0.1 ads.tiscali.fr
127.0.0.1 ads.tmcs.net
127.0.0.1 ads.tnt.tv
127.0.0.1 ads.top-banners.com
127.0.0.1 ads.top500.org        #TOP500 SuperComputer Site
127.0.0.1 ads.toronto.com
127.0.0.1 ads.townhall.com
127.0.0.1 ads.track.net
127.0.0.1 ads.traderonline.com
127.0.0.1 ads.traffichaus.com
127.0.0.1 ads.trafficjunky.net
127.0.0.1 ads.traffikings.com
127.0.0.1 ads.treehugger.com
127.0.0.1 ads.tricityherald.com
127.0.0.1 ads.trinitymirror.co.uk
127.0.0.1 ads.tripod.com
127.0.0.1 ads.tripod.lycos.co.uk
127.0.0.1 ads.tripod.lycos.de
127.0.0.1 ads.tripod.lycos.es
127.0.0.1 ads.tromaville.com
127.0.0.1 ads.trutv.com
127.0.0.1 ads.tucows.com
127.0.0.1 ads.tw.adsonar.com
127.0.0.1 ads.ucomics.com
127.0.0.1 ads.uigc.net
127.0.0.1 ads.undertone.com
127.0.0.1 ads.unixathome.org
127.0.0.1 ads.update.com
127.0.0.1 ads.uproar.com
127.0.0.1 ads.urbandictionary.com
127.0.0.1 ads.us.e-planning.ne
127.0.0.1 ads.us.e-planning.net
127.0.0.1 ads.usatoday.com
127.0.0.1 ads.userfriendly.org
127.0.0.1 ads.v3.com
127.0.0.1 ads.v3exchange.com
127.0.0.1 ads.vaildaily.com
127.0.0.1 ads.valuead.com
127.0.0.1 ads.vegas.com
127.0.0.1 ads.veloxia.com
127.0.0.1 ads.ventivmedia.com
127.0.0.1 ads.veoh.com
127.0.0.1 ads.verkata.com
127.0.0.1 ads.vesperexchange.com
127.0.0.1 ads.vg.basefarm.net
127.0.0.1 ads.viddler.com
127.0.0.1 ads.videoadvertising.com
127.0.0.1 ads.viewlondon.co.uk
127.0.0.1 ads.virginislandsdailynews.com
127.0.0.1 ads.virtualcountries.com
127.0.0.1 ads.vnuemedia.com
127.0.0.1 ads.wanadooregie.com
127.0.0.1 ads.warcry.com
127.0.0.1 ads.watershed-publishing.com
127.0.0.1 ads.weather.ca
127.0.0.1 ads.weather.com
127.0.0.1 ads.web.alwayson-network.com
127.0.0.1 ads.web.aol.com
127.0.0.1 ads.web.compuserve.com
127.0.0.1 ads.web.cs.com
127.0.0.1 ads.web.de
127.0.0.1 ads.web21.com
127.0.0.1 ads.webattack.com
127.0.0.1 ads.webcoretech.com
127.0.0.1 ads.webfeat.com
127.0.0.1 ads.webheat.com
127.0.0.1 ads.webhosting.info
127.0.0.1 ads.webindia123.com
127.0.0.1 ads.webmd.com
127.0.0.1 ads.webnet.advance.net
127.0.0.1 ads.websponsors.com
127.0.0.1 ads.weissinc.com
127.0.0.1 ads.whaleads.com
127.0.0.1 ads.whi.co.nz
127.0.0.1 ads.winsite.com
127.0.0.1 ads.wnd.com
127.0.0.1 ads.wunderground.com
127.0.0.1 ads.x10.com
127.0.0.1 ads.x10.net
127.0.0.1 ads.x17online.com
127.0.0.1 ads.xbox-scene.com
127.0.0.1 ads.xboxic.com
127.0.0.1 ads.xposed.com
127.0.0.1 ads.xtra.ca
127.0.0.1 ads.xtra.co.nz
127.0.0.1 ads.xtramsn.co.nz
127.0.0.1 ads.yimg.com
127.0.0.1 ads.yimg.com.edgesuite.net
127.0.0.1 ads.yldmgrimg.net
127.0.0.1 ads.youporn.com
127.0.0.1 ads.zap2it.com
127.0.0.1 ads.zdnet.com
127.0.0.1 ads0.okcupid.com
127.0.0.1 ads01.focalink.com
127.0.0.1 ads01.hyperbanner.net
127.0.0.1 ads02.focalink.com
127.0.0.1 ads02.hyperbanner.net
127.0.0.1 ads03.focalink.com
127.0.0.1 ads03.hyperbanner.net
127.0.0.1 ads04.focalink.com
127.0.0.1 ads04.hyperbanner.net
127.0.0.1 ads05.focalink.com
127.0.0.1 ads05.hyperbanner.net
127.0.0.1 ads06.focalink.com
127.0.0.1 ads06.hyperbanner.net
127.0.0.1 ads07.focalink.com
127.0.0.1 ads07.hyperbanner.net
127.0.0.1 ads08.focalink.com
127.0.0.1 ads08.hyperbanner.net
127.0.0.1 ads09.focalink.com
127.0.0.1 ads09.hyperbanner.net
127.0.0.1 ads1.activeagent.at
127.0.0.1 ads1.ad-flow.com
127.0.0.1 ads1.admedia.ro
127.0.0.1 ads1.advance.net
127.0.0.1 ads1.advertwizard.com
127.0.0.1 ads1.ami-admin.com
127.0.0.1 ads1.canoe.ca
127.0.0.1 ads1.destructoid.com
127.0.0.1 ads1.empiretheatres.com
127.0.0.1 ads1.erotism.com
127.0.0.1 ads1.eudora.com
127.0.0.1 ads1.globeandmail.com
127.0.0.1 ads1.itadnetwork.co.uk
127.0.0.1 ads1.jev.co.za
127.0.0.1 ads1.msads.net
127.0.0.1 ads1.msn.com
127.0.0.1 ads1.perfadbrite.com.akadns.net
127.0.0.1 ads1.performancingads.com
127.0.0.1 ads1.realcities.com
127.0.0.1 ads1.revenue.net
127.0.0.1 ads1.sptimes.com
127.0.0.1 ads1.theglobeandmail.com
127.0.0.1 ads1.ucomics.com
127.0.0.1 ads1.udc.advance.net
127.0.0.1 ads1.updated.com
127.0.0.1 ads1.virtumundo.com
127.0.0.1 ads1.zdnet.com
127.0.0.1 ads10.focalink.com
127.0.0.1 ads10.hyperbanner.net
127.0.0.1 ads10.speedbit.com
127.0.0.1 ads10.udc.advance.net
127.0.0.1 ads11.focalink.com
127.0.0.1 ads11.hyperbanner.net
127.0.0.1 ads11.udc.advance.net
127.0.0.1 ads12.focalink.com
127.0.0.1 ads12.hyperbanner.net
127.0.0.1 ads12.udc.advance.net
127.0.0.1 ads13.focalink.com
127.0.0.1 ads13.hyperbanner.net
127.0.0.1 ads13.udc.advance.net
127.0.0.1 ads14.bpath.com
127.0.0.1 ads14.focalink.com
127.0.0.1 ads14.hyperbanner.net
127.0.0.1 ads14.udc.advance.net
127.0.0.1 ads15.bpath.com
127.0.0.1 ads15.focalink.com
127.0.0.1 ads15.hyperbanner.net
127.0.0.1 ads15.udc.advance.net
127.0.0.1 ads16.advance.net
127.0.0.1 ads16.focalink.com
127.0.0.1 ads16.hyperbanner.net
127.0.0.1 ads16.udc.advance.net
127.0.0.1 ads17.focalink.com
127.0.0.1 ads17.hyperbanner.net
127.0.0.1 ads18.focalink.com
127.0.0.1 ads18.hyperbanner.net
127.0.0.1 ads19.focalink.com
127.0.0.1 ads2.ad-flow.com
127.0.0.1 ads2.adbrite.com
127.0.0.1 ads2.advance.net
127.0.0.1 ads2.advertwizard.com
127.0.0.1 ads2.canoe.ca
127.0.0.1 ads2.clearchannel.com
127.0.0.1 ads2.clickad.com
127.0.0.1 ads2.collegclub.com
127.0.0.1 ads2.collegeclub.com
127.0.0.1 ads2.contentabc.com
127.0.0.1 ads2.drivelinemedia.com
127.0.0.1 ads2.emeraldcoast.com
127.0.0.1 ads2.exhedra.com
127.0.0.1 ads2.firingsquad.com
127.0.0.1 ads2.gamecity.net
127.0.0.1 ads2.jubii.dk
127.0.0.1 ads2.ljworld.com
127.0.0.1 ads2.msn.com
127.0.0.1 ads2.newtimes.com
127.0.0.1 ads2.osdn.com
127.0.0.1 ads2.pittsburghlive.com
127.0.0.1 ads2.realcities.com
127.0.0.1 ads2.revenue.net
127.0.0.1 ads2.rp.pl
127.0.0.1 ads2.theglobeandmail.com
127.0.0.1 ads2.udc.advance.net
127.0.0.1 ads2.virtumundo.com
127.0.0.1 ads2.weblogssl.com
127.0.0.1 ads2.zdnet.com
127.0.0.1 ads20.focalink.com
127.0.0.1 ads21.focalink.com
127.0.0.1 ads22.focalink.com
127.0.0.1 ads23.focalink.com
127.0.0.1 ads24.focalink.com
127.0.0.1 ads25.focalink.com
127.0.0.1 ads2srv.com
127.0.0.1 ads3.ad-flow.com
127.0.0.1 ads3.adman.gr
127.0.0.1 ads3.advance.net
127.0.0.1 ads3.advertwizard.com
127.0.0.1 ads3.canoe.ca
127.0.0.1 ads3.freebannertrade.com
127.0.0.1 ads3.gamecity.net
127.0.0.1 ads3.jubii.dk
127.0.0.1 ads3.realcities.com
127.0.0.1 ads3.udc.advance.net
127.0.0.1 ads3.virtumundo.com
127.0.0.1 ads3.zdnet.com
127.0.0.1 ads36.hyperbanner.net
127.0.0.1 ads360.com
127.0.0.1 ads4.ad-flow.com
127.0.0.1 ads4.advance.net
127.0.0.1 ads4.advertwizard.com
127.0.0.1 ads4.canoe.ca
127.0.0.1 ads4.clearchannel.com
127.0.0.1 ads4.gamecity.net
127.0.0.1 ads4.realcities.com
127.0.0.1 ads4.udc.advance.net
127.0.0.1 ads4.virtumundo.com
127.0.0.1 ads4homes.com
127.0.0.1 ads5.ad-flow.com
127.0.0.1 ads5.advance.net
127.0.0.1 ads5.advertwizard.com
127.0.0.1 ads5.canoe.ca
127.0.0.1 ads5.mconetwork.com
127.0.0.1 ads5.udc.advance.net
127.0.0.1 ads5.virtumundo.com
127.0.0.1 ads6.ad-flow.com
127.0.0.1 ads6.advance.net
127.0.0.1 ads6.advertwizard.com
127.0.0.1 ads6.gamecity.net
127.0.0.1 ads6.udc.advance.net
127.0.0.1 ads7.ad-flow.com
127.0.0.1 ads7.advance.net
127.0.0.1 ads7.advertwizard.com
127.0.0.1 ads7.gamecity.net
127.0.0.1 ads7.speedbit.com
127.0.0.1 ads7.udc.advance.net
127.0.0.1 ads8.ad-flow.com
127.0.0.1 ads8.advertwizard.com
127.0.0.1 ads8.com
127.0.0.1 ads8.udc.advance.net
127.0.0.1 ads9.ad-flow.com
127.0.0.1 ads9.advertwizard.com
127.0.0.1 ads9.udc.advance.net
127.0.0.1 adsadmin.aspentimes.com
127.0.0.1 adsadmin.corusradionetwork.com
127.0.0.1 adsadmin.vaildaily.com
127.0.0.1 adsatt.abcnews.starwave.com
127.0.0.1 adsatt.espn.go.com
127.0.0.1 adsatt.espn.starwave.com
127.0.0.1 adscendmedia.com
127.0.0.1 adscholar.com
127.0.0.1 adsdaq.com
127.0.0.1 adsearch.adkontekst.pl
127.0.0.1 adsearch.pl
127.0.0.1 adsearch.wp.pl
127.0.0.1 adsentnetwork.com
127.0.0.1 adserer.ihigh.com
127.0.0.1 adserv.aip.org
127.0.0.1 adserv.bravenet.com
127.0.0.1 adserv.entriq.net
127.0.0.1 adserv.free6.com
127.0.0.1 adserv.geocomm.com
127.0.0.1 adserv.iafrica.com
127.0.0.1 adserv.internetfuel.com
127.0.0.1 adserv.jupiter.com
127.0.0.1 adserv.lwmn.net
127.0.0.1 adserv.maineguide.com
127.0.0.1 adserv.muchosucko.com
127.0.0.1 adserv.mywebtimes.com
127.0.0.1 adserv.pitchforkmedia.com
127.0.0.1 adserv.postbulletin.com
127.0.0.1 adserv.qconline.com
127.0.0.1 adserv.quality-channel.de
127.0.0.1 adserv.usps.com
127.0.0.1 adserv001.adtech.de
127.0.0.1 adserv001.adtech.fr
127.0.0.1 adserv001.adtech.us
127.0.0.1 adserv002.adtech.de
127.0.0.1 adserv002.adtech.fr
127.0.0.1 adserv002.adtech.us
127.0.0.1 adserv003.adtech.de
127.0.0.1 adserv003.adtech.fr
127.0.0.1 adserv003.adtech.us
127.0.0.1 adserv004.adtech.de
127.0.0.1 adserv004.adtech.fr
127.0.0.1 adserv004.adtech.us
127.0.0.1 adserv005.adtech.de
127.0.0.1 adserv005.adtech.fr
127.0.0.1 adserv005.adtech.us
127.0.0.1 adserv006.adtech.de
127.0.0.1 adserv006.adtech.fr
127.0.0.1 adserv006.adtech.us
127.0.0.1 adserv007.adtech.de
127.0.0.1 adserv007.adtech.fr
127.0.0.1 adserv007.adtech.us
127.0.0.1 adserv008.adtech.de
127.0.0.1 adserv008.adtech.fr
127.0.0.1 adserv008.adtech.us
127.0.0.1 adserv2.bravenet.com
127.0.0.1 adservant.guj.de
127.0.0.1 adserve.adtoll.com
127.0.0.1 adserve.canadawidemagazines.com
127.0.0.1 adserve.city-ad.com
127.0.0.1 adserve.ehpub.com
127.0.0.1 adserve.gossipgirls.com
127.0.0.1 adserve.mizzenmedia.com
127.0.0.1 adserve.podaddies.com
127.0.0.1 adserve.profit-smart.com
127.0.0.1 adserve.shopzilla.com
127.0.0.1 adserve.splicetoday.com
127.0.0.1 adserve.viaarena.com
127.0.0.1 adserve5.nikkeibp.co.jp
127.0.0.1 adserver-2.ig.com.br
127.0.0.1 adserver-3.ig.com.br
127.0.0.1 adserver-4.ig.com.br
127.0.0.1 adserver-5.ig.com.br
127.0.0.1 adserver-espnet.sportszone.net
127.0.0.1 adserver.100free.com
127.0.0.1 adserver.163.com
127.0.0.1 adserver.2618.com
127.0.0.1 adserver.3digit.de
127.0.0.1 adserver.71i.de
127.0.0.1 adserver.a.in.monster.com
127.0.0.1 adserver.ad-it.dk
127.0.0.1 adserver.adreactor.com
127.0.0.1 adserver.adremedy.com
127.0.0.1 adserver.ads360.com
127.0.0.1 adserver.adserver.com.pl
127.0.0.1 adserver.adsincontext.com
127.0.0.1 adserver.adtech.de
127.0.0.1 adserver.adtech.fr
127.0.0.1 adserver.adtech.us
127.0.0.1 adserver.adtechus.com
127.0.0.1 adserver.adultfriendfinder.com
127.0.0.1 adserver.advertist.com
127.0.0.1 adserver.affiliatemg.com
127.0.0.1 adserver.affiliation.com
127.0.0.1 adserver.aim4media.com
127.0.0.1 adserver.airmiles.ca
127.0.0.1 adserver.akqa.net
127.0.0.1 adserver.allheadlinenews.com
127.0.0.1 adserver.amnews.com
127.0.0.1 adserver.ancestry.com
127.0.0.1 adserver.anemo.com
127.0.0.1 adserver.anm.co.uk
127.0.0.1 adserver.aol.fr
127.0.0.1 adserver.archant.co.uk
127.0.0.1 adserver.artempireindustries.com
127.0.0.1 adserver.arttoday.com
127.0.0.1 adserver.atari.net
127.0.0.1 adserver.betandwin.de
127.0.0.1 adserver.billiger-surfen.de
127.0.0.1 adserver.billiger-telefonieren.de
127.0.0.1 adserver.bizland-inc.net
127.0.0.1 adserver.bluereactor.com
127.0.0.1 adserver.bluereactor.net
127.0.0.1 adserver.bluewin.ch
127.0.0.1 adserver.buttonware.com
127.0.0.1 adserver.buttonware.net
127.0.0.1 adserver.cams.com
127.0.0.1 adserver.cantv.net
127.0.0.1 adserver.cebu-online.com
127.0.0.1 adserver.cheatplanet.com
127.0.0.1 adserver.chickclick.com
127.0.0.1 adserver.click4cash.de
127.0.0.1 adserver.clubic.com
127.0.0.1 adserver.clundressed.com
127.0.0.1 adserver.co.il
127.0.0.1 adserver.colleges.com
127.0.0.1 adserver.com
127.0.0.1 adserver.com-solutions.com
127.0.0.1 adserver.comparatel.fr
127.0.0.1 adserver.conjelco.com
127.0.0.1 adserver.corusradionetwork.com
127.0.0.1 adserver.creative-asia.com
127.0.0.1 adserver.creativeinspire.com
127.0.0.1 adserver.dayrates.com
127.0.0.1 adserver.dbusiness.com
127.0.0.1 adserver.developersnetwork.com
127.0.0.1 adserver.devx.com
127.0.0.1 adserver.digitalpartners.com
127.0.0.1 adserver.digitoday.com
127.0.0.1 adserver.directforce.com
127.0.0.1 adserver.directforce.net
127.0.0.1 adserver.dnps.com
127.0.0.1 adserver.dotcommedia.de
127.0.0.1 adserver.dotmusic.com
127.0.0.1 adserver.eham.net
127.0.0.1 adserver.emapadserver.com
127.0.0.1 adserver.emporis.com
127.0.0.1 adserver.emulation64.com
127.0.0.1 adserver.eudora.com
127.0.0.1 adserver.eva2000.com
127.0.0.1 adserver.expatica.nxs.nl
127.0.0.1 adserver.ezzhosting.com
127.0.0.1 adserver.filefront.com
127.0.0.1 adserver.fmpub.net
127.0.0.1 adserver.fr.adtech.de
127.0.0.1 adserver.freecity.de
127.0.0.1 adserver.freenet.de
127.0.0.1 adserver.friendfinder.com
127.0.0.1 adserver.gameparty.net
127.0.0.1 adserver.gamesquad.net
127.0.0.1 adserver.garden.com
127.0.0.1 adserver.gorillanation.com
127.0.0.1 adserver.gr
127.0.0.1 adserver.gunaxin.com
127.0.0.1 adserver.hardsextube.com
127.0.0.1 adserver.hardwareanalysis.com
127.0.0.1 adserver.harktheherald.com
127.0.0.1 adserver.harvestadsdepot.com
127.0.0.1 adserver.hellasnet.gr
127.0.0.1 adserver.hg-computer.de
127.0.0.1 adserver.hi-m.de
127.0.0.1 adserver.hispavista.com
127.0.0.1 adserver.hk.outblaze.com
127.0.0.1 adserver.home.pl
127.0.0.1 adserver.hostinteractive.com
127.0.0.1 adserver.humanux.com
127.0.0.1 adserver.ifmagazine.com
127.0.0.1 adserver.ig.com.br
127.0.0.1 adserver.ign.com
127.0.0.1 adserver.ilounge.com
127.0.0.1 adserver.infinit.net
127.0.0.1 adserver.infotiger.com
127.0.0.1 adserver.interfree.it
127.0.0.1 adserver.inwind.it
127.0.0.1 adserver.ision.de
127.0.0.1 adserver.isonews.com
127.0.0.1 adserver.ixm.co.uk
127.0.0.1 adserver.jacotei.com.br
127.0.0.1 adserver.janes.com
127.0.0.1 adserver.janes.net
127.0.0.1 adserver.janes.org
127.0.0.1 adserver.jolt.co.uk
127.0.0.1 adserver.journalinteractive.com
127.0.0.1 adserver.juicyads.com
127.0.0.1 adserver.kcilink.com
127.0.0.1 adserver.killeraces.com
127.0.0.1 adserver.kylemedia.com
127.0.0.1 adserver.lanacion.com.ar
127.0.0.1 adserver.lanepress.com
127.0.0.1 adserver.latimes.com
127.0.0.1 adserver.legacy-network.com
127.0.0.1 adserver.libero.it
127.0.0.1 adserver.linktrader.co.uk
127.0.0.1 adserver.livejournal.com
127.0.0.1 adserver.lostreality.com
127.0.0.1 adserver.lunarpages.com
127.0.0.1 adserver.lycos.co.jp
127.0.0.1 adserver.m2kcore.com
127.0.0.1 adserver.magazyn.pl
127.0.0.1 adserver.matchcraft.com
127.0.0.1 adserver.merc.com
127.0.0.1 adserver.mindshare.de
127.0.0.1 adserver.mobsmith.com
127.0.0.1 adserver.monster.com
127.0.0.1 adserver.monstersandcritics.com
127.0.0.1 adserver.motonews.pl
127.0.0.1 adserver.myownemail.com
127.0.0.1 adserver.netcreators.nl
127.0.0.1 adserver.netshelter.net
127.0.0.1 adserver.newdigitalgroup.com
127.0.0.1 adserver.newmassmedia.net
127.0.0.1 adserver.news-journalonline.com
127.0.0.1 adserver.news.com
127.0.0.1 adserver.news.com.au
127.0.0.1 adserver.newtimes.com
127.0.0.1 adserver.ngz-network.de
127.0.0.1 adserver.nydailynews.com
127.0.0.1 adserver.nzoom.com
127.0.0.1 adserver.o2.pl
127.0.0.1 adserver.onwisconsin.com
127.0.0.1 adserver.passion.com
127.0.0.1 adserver.phatmax.net
127.0.0.1 adserver.phillyburbs.com
127.0.0.1 adserver.pl
127.0.0.1 adserver.planet-multiplayer.de
127.0.0.1 adserver.plhb.com
127.0.0.1 adserver.pollstar.com
127.0.0.1 adserver.portal.pl
127.0.0.1 adserver.portalofevil.com
127.0.0.1 adserver.portugalmail.pt
127.0.0.1 adserver.prodigy.net
127.0.0.1 adserver.proteinos.com
127.0.0.1 adserver.radio-canada.ca
127.0.0.1 adserver.ratestar.net
127.0.0.1 adserver.revver.com
127.0.0.1 adserver.ro
127.0.0.1 adserver.sabc.co.za
127.0.0.1 adserver.sabcnews.co.za
127.0.0.1 adserver.sanomawsoy.fi
127.0.0.1 adserver.scmp.com
127.0.0.1 adserver.securityfocus.com
127.0.0.1 adserver.sextracker.com
127.0.0.1 adserver.sharewareonline.com
127.0.0.1 adserver.singnet.com
127.0.0.1 adserver.sl.kharkov.ua
127.0.0.1 adserver.smashtv.com
127.0.0.1 adserver.snowball.com
127.0.0.1 adserver.softonic.com
127.0.0.1 adserver.soloserver.com
127.0.0.1 adserver.swiatobrazu.pl
127.0.0.1 adserver.synergetic.de
127.0.0.1 adserver.te.pt
127.0.0.1 adserver.telalink.net
127.0.0.1 adserver.teracent.net
127.0.0.1 adserver.terra.com.br
127.0.0.1 adserver.terra.es
127.0.0.1 adserver.theknot.com
127.0.0.1 adserver.theonering.net
127.0.0.1 adserver.thirty4.com
127.0.0.1 adserver.thisislondon.co.uk
127.0.0.1 adserver.tilted.net
127.0.0.1 adserver.tqs.ca
127.0.0.1 adserver.track-star.com
127.0.0.1 adserver.trader.ca
127.0.0.1 adserver.trafficsyndicate.com
127.0.0.1 adserver.trb.com
127.0.0.1 adserver.tribuneinteractive.com
127.0.0.1 adserver.tsgadv.com
127.0.0.1 adserver.tulsaworld.com
127.0.0.1 adserver.tweakers.net
127.0.0.1 adserver.twitpic.com
127.0.0.1 adserver.ugo.com
127.0.0.1 adserver.ugo.nl
127.0.0.1 adserver.ukplus.co.uk
127.0.0.1 adserver.uproxx.com
127.0.0.1 adserver.usermagnet.com
127.0.0.1 adserver.van.net
127.0.0.1 adserver.virgin.net
127.0.0.1 adserver.virginmedia.com
127.0.0.1 adserver.virtualminds.nl
127.0.0.1 adserver.virtuous.co.uk
127.0.0.1 adserver.voir.ca
127.0.0.1 adserver.webads.co.uk
127.0.0.1 adserver.webads.nl
127.0.0.1 adserver.wemnet.nl
127.0.0.1 adserver.x3.hu
127.0.0.1 adserver.ya.com
127.0.0.1 adserver.yahoo.com
127.0.0.1 adserver.zaz.com.br
127.0.0.1 adserver.zeads.com
127.0.0.1 adserver01.ancestry.com
127.0.0.1 adserver1-images.backbeatmedia.com
127.0.0.1 adserver1.adserver.com.pl
127.0.0.1 adserver1.adtech.com.tr
127.0.0.1 adserver1.backbeatmedia.com
127.0.0.1 adserver1.economist.com
127.0.0.1 adserver1.eudora.com
127.0.0.1 adserver1.harvestadsdepot.com
127.0.0.1 adserver1.hookyouup.com
127.0.0.1 adserver1.isohunt.com
127.0.0.1 adserver1.lokitorrent.com
127.0.0.1 adserver1.mediainsight.de
127.0.0.1 adserver1.ogilvy-interactive.de
127.0.0.1 adserver1.realtracker.com
127.0.0.1 adserver1.sonymusiceurope.com
127.0.0.1 adserver1.teracent.net
127.0.0.1 adserver1.wmads.com
127.0.0.1 adserver2.adserver.com.pl
127.0.0.1 adserver2.atman.pl
127.0.0.1 adserver2.christianitytoday.com
127.0.0.1 adserver2.condenast.co.uk
127.0.0.1 adserver2.creative.com
127.0.0.1 adserver2.eudora.com
127.0.0.1 adserver2.mediainsight.de
127.0.0.1 adserver2.news-journalonline.com
127.0.0.1 adserver2.popdata.de
127.0.0.1 adserver2.realtracker.com
127.0.0.1 adserver2.teracent.net
127.0.0.1 adserver3.eudora.com
127.0.0.1 adserver4.eudora.com
127.0.0.1 adserver9.contextad.com
127.0.0.1 adserverb.conjelco.com
127.0.0.1 adserversolutions.com
127.0.0.1 adservices.google.com
127.0.0.1 adservices.picadmedia.com
127.0.0.1 adserving.cpxinteractive.com
127.0.0.1 adservingcentral.com
127.0.0.1 adserwer.o2.pl
127.0.0.1 adseu.novem.pl
127.0.0.1 adsfac.eu
127.0.0.1 adsfac.net
127.0.0.1 adsfac.us
127.0.0.1 adsinimages.com
127.0.0.1 adsintl.starwave.com
127.0.0.1 adsm.soush.com
127.0.0.1 adsmart.co.uk
127.0.0.1 adsmart.com
127.0.0.1 adsmart.net
127.0.0.1 adsnew.userfriendly.org
127.0.0.1 adsoftware.com
127.0.0.1 adsoldier.com
127.0.0.1 adson.awempire.com
127.0.0.1 adsonar.com
127.0.0.1 adspaces.ero-advertising.com
127.0.0.1 adspirit.net
127.0.0.1 adspiro.pl
127.0.0.1 adsr3pg.com.br
127.0.0.1 adsrc.bankrate.com
127.0.0.1 adsremote.scripps.com
127.0.0.1 adsremote.scrippsnetwork.com
127.0.0.1 adsrevenue.net
127.0.0.1 adsrv.bankrate.com
127.0.0.1 adsrv.dispatch.com
127.0.0.1 adsrv.emporis.com
127.0.0.1 adsrv.heraldtribune.com
127.0.0.1 adsrv.hpg.com.br
127.0.0.1 adsrv.iol.co.za
127.0.0.1 adsrv.lua.pl
127.0.0.1 adsrv.news.com.au
127.0.0.1 adsrv.tuscaloosanews.com
127.0.0.1 adsrv.wilmingtonstar.com
127.0.0.1 adsrv2.wilmingtonstar.com
127.0.0.1 adsrvr.com
127.0.0.1 adssl01.adtech.de
127.0.0.1 adssl01.adtech.fr
127.0.0.1 adssl01.adtech.us
127.0.0.1 adssl02.adtech.de
127.0.0.1 adssl02.adtech.fr
127.0.0.1 adssl02.adtech.us
127.0.0.1 adsspace.net
127.0.0.1 adstil.indiatimes.com
127.0.0.1 adstogo.com
127.0.0.1 adstome.com
127.0.0.1 adstream.cardboardfish.com
127.0.0.1 adstreams.org
127.0.0.1 adsvr.adknowledge.com
127.0.0.1 adsweb.tiscali.cz
127.0.0.1 adsyndication.msn.com
127.0.0.1 adsyndication.yelldirect.com
127.0.0.1 adsynergy.com
127.0.0.1 adsys.townnews.com
127.0.0.1 adtag.msn.ca
127.0.0.1 adtag.sympatico.ca
127.0.0.1 adtaily.com
127.0.0.1 adtaily.pl
127.0.0.1 adtcp.ru
127.0.0.1 adtech.de
127.0.0.1 adtech.panthercustomer.com
127.0.0.1 adtechus.com
127.0.0.1 adtegrity.spinbox.net
127.0.0.1 adtext.pl
127.0.0.1 adthru.com
127.0.0.1 adtigerpl.adspirit.net
127.0.0.1 adtlgc.com
127.0.0.1 adtology3.com
127.0.0.1 adtotal.pl
127.0.0.1 adtracking.vinden.nl
127.0.0.1 adtrader.com
127.0.0.1 adtrak.net
127.0.0.1 adultadworld.com
127.0.0.1 adv.440net.com
127.0.0.1 adv.adgates.com
127.0.0.1 adv.adtotal.pl
127.0.0.1 adv.adview.pl
127.0.0.1 adv.bannercity.ru
127.0.0.1 adv.bbanner.it
127.0.0.1 adv.bookclubservices.ca
127.0.0.1 adv.federalpost.ru
127.0.0.1 adv.gazeta.pl
127.0.0.1 adv.lampsplus.com
127.0.0.1 adv.merlin.co.il
127.0.0.1 adv.netshelter.net
127.0.0.1 adv.surinter.net
127.0.0.1 adv.virgilio.it
127.0.0.1 adv.webmd.com
127.0.0.1 adv.wp.pl
127.0.0.1 adv.zapal.ru
127.0.0.1 adv0005.247realmedia.com
127.0.0.1 adv0035.247realmedia.com
127.0.0.1 adveng.hiasys.com
127.0.0.1 adveraction.pl
127.0.0.1 advert.bayarea.com
127.0.0.1 advertise.com
127.0.0.1 advertisers.federatedmedia.net
127.0.0.1 advertising.aol.com
127.0.0.1 advertising.bbcworldwide.com
127.0.0.1 advertising.com
127.0.0.1 advertising.gfxartist.com
127.0.0.1 advertising.hiasys.com
127.0.0.1 advertising.illinimedia.com
127.0.0.1 advertising.online-media24.de
127.0.0.1 advertising.paltalk.com
127.0.0.1 advertising.wellpack.fr
127.0.0.1 advertising.zenit.org
127.0.0.1 advertisingbay.com
127.0.0.1 advertlets.com
127.0.0.1 advertpro.investorvillage.com
127.0.0.1 advertpro.sitepoint.com
127.0.0.1 adverts.digitalspy.co.uk
127.0.0.1 adverts.ecn.co.uk
127.0.0.1 adverts.freeloader.com
127.0.0.1 adverts.im4ges.com
127.0.0.1 advertstream.com
127.0.0.1 advicepl.adocean.pl
127.0.0.1 adview.pl
127.0.0.1 adviva.net
127.0.0.1 advmaker.ru
127.0.0.1 advt.webindia123.com
127.0.0.1 adw.sapo.pt
127.0.0.1 adware.kogaryu.com
127.0.0.1 adweb2.hornymatches.com
127.0.0.1 adx.adrenalinesk.sk
127.0.0.1 adx.gainesvillesun.com
127.0.0.1 adx.gainesvillsun.com
127.0.0.1 adx.groupstate.com
127.0.0.1 adx.hendersonvillenews.com
127.0.0.1 adx.heraldtribune.com
127.0.0.1 adx.starnewsonline.com
127.0.0.1 adx.theledger.com
127.0.0.1 adxpose.com
127.0.0.1 adz.afterdawn.net
127.0.0.1 adzerk.net
127.0.0.1 adzone.ro
127.0.0.1 adzone.stltoday.com
127.0.0.1 adzservice.theday.com
127.0.0.1 afe.specificclick.net
127.0.0.1 afe2.specificclick.net
127.0.0.1 aff.foxtab.com
127.0.0.1 aff.ringtonepartner.com
127.0.0.1 affiliate-fr.com
127.0.0.1 affiliate.a4dtracker.com
127.0.0.1 affiliate.aol.com
127.0.0.1 affiliate.baazee.com
127.0.0.1 affiliate.cfdebt.com
127.0.0.1 affiliate.exabytes.com.my
127.0.0.1 affiliate.fr.espotting.com
127.0.0.1 affiliate.googleusercontent.com
127.0.0.1 affiliate.hbytracker.com
127.0.0.1 affiliate.mlntracker.com
127.0.0.1 affiliates.arvixe.com
127.0.0.1 affiliates.eblastengine.com
127.0.0.1 affiliates.genealogybank.com
127.0.0.1 affiliates.globat.com
127.0.0.1 affiliation-france.com
127.0.0.1 affimg.pop6.com
127.0.0.1 afform.co.uk
127.0.0.1 affpartners.com
127.0.0.1 afi.adocean.pl
127.0.0.1 afilo.pl
127.0.0.1 agkn.com
127.0.0.1 aj.600z.com
127.0.0.1 ajcclassifieds.com
127.0.0.1 ak.buyservices.com
127.0.0.1 ak.maxserving.com
127.0.0.1 ak.p.openx.net
127.0.0.1 aka-cdn-ns.adtechus.com
127.0.0.1 akaads-espn.starwave.com
127.0.0.1 akamai.invitemedia.com
127.0.0.1 ako.cc
127.0.0.1 al1.sharethis.com
127.0.0.1 all.orfr.adgtw.orangeads.fr
127.0.0.1 alliance.adbureau.net
127.0.0.1 altfarm.mediaplex.com
127.0.0.1 amch.questionmarket.com
127.0.0.1 americansingles.click-url.com
127.0.0.1 amscdn.btrll.com
127.0.0.1 an.tacoda.net
127.0.0.1 an.yandex.ru
127.0.0.1 analysis.fc2.com
127.0.0.1 analytics.kwebsoft.com
127.0.0.1 analytics.percentmobile.com
127.0.0.1 analyzer51.fc2.com
127.0.0.1 ankieta-online.pl
127.0.0.1 annuaire-autosurf.com
127.0.0.1 anrtx.tacoda.net
127.0.0.1 answers.us.intellitxt.com
127.0.0.1 ap.read.mediation.pns.ap.orangeads.fr
127.0.0.1 apex-ad.com
127.0.0.1 api-public.addthis.com
127.0.0.1 api.addthis.com
127.0.0.1 api.affinesystems.com
127.0.0.1 apopt.hbmediapro.com
127.0.0.1 app.scanscout.com
127.0.0.1 apparel-offer.com
127.0.0.1 apparelncs.com
127.0.0.1 appdev.addthis.com
127.0.0.1 appnexus.com
127.0.0.1 apps5.oingo.com
127.0.0.1 arbomedia.pl
127.0.0.1 arbopl.bbelements.com
127.0.0.1 arsconsole.global-intermedia.com
127.0.0.1 art-music-rewardpath.com
127.0.0.1 art-offer.com
127.0.0.1 art-offer.net
127.0.0.1 art-photo-music-premiumblvd.com
127.0.0.1 art-photo-music-rewardempire.com
127.0.0.1 art-photo-music-savingblvd.com
127.0.0.1 as.5to1.com
127.0.0.1 as.casalemedia.com
127.0.0.1 as.vs4entertainment.com
127.0.0.1 as.webmd.com
127.0.0.1 as1.falkag.de
127.0.0.1 as1.inoventiv.com
127.0.0.1 as1image1.adshuffle.com
127.0.0.1 as1image2.adshuffle.com
127.0.0.1 as2.falkag.de
127.0.0.1 as3.falkag.de
127.0.0.1 as4.falkag.de
127.0.0.1 asa.tynt.com
127.0.0.1 asb.tynt.com
127.0.0.1 asg01.casalemedia.com
127.0.0.1 asg02.casalemedia.com
127.0.0.1 asg03.casalemedia.com
127.0.0.1 asg04.casalemedia.com
127.0.0.1 asg05.casalemedia.com
127.0.0.1 asg06.casalemedia.com
127.0.0.1 asg07.casalemedia.com
127.0.0.1 asg08.casalemedia.com
127.0.0.1 asg09.casalemedia.com
127.0.0.1 asg10.casalemedia.com
127.0.0.1 asg11.casalemedia.com
127.0.0.1 asg12.casalemedia.com
127.0.0.1 asg13.casalemedia.com
127.0.0.1 ask-gps.ru
127.0.0.1 asklots.com
127.0.0.1 askmen.thruport.com
127.0.0.1 asm2.z1.adserver.com
127.0.0.1 asm3.z1.adserver.com
127.0.0.1 asn.cunda.advolution.biz
127.0.0.1 assets.igapi.com
127.0.0.1 assets.percentmobile.com
127.0.0.1 asv.nuggad.net
127.0.0.1 at-adserver.alltop.com
127.0.0.1 at.campaigns.f2.com.au
127.0.0.1 at.ceofreehost.com
127.0.0.1 at.m1.nedstatbasic.net
127.0.0.1 atdmt.com
127.0.0.1 atemda.com
127.0.0.1 athena-ads.wikia.com
127.0.0.1 au.ads.link4ads.com
127.0.0.1 au.adserver.yahoo.com
127.0.0.1 aud.pubmatic.com
127.0.0.1 aureate.com
127.0.0.1 auslieferung.commindo-media-ressourcen.de
127.0.0.1 austria1.adverserve.net
127.0.0.1 autocontext.begun.ru
127.0.0.1 automotive-offer.com
127.0.0.1 automotive-rewardpath.com
127.0.0.1 avcounter10.com
127.0.0.1 avpa.dzone.com
127.0.0.1 avpa.javalobby.org
127.0.0.1 awesomevipoffers.com
127.0.0.1 awrz.net
127.0.0.1 azcentra.app.ur.gcion.com
127.0.0.1 azoogleads.com
127.0.0.1 b.ads2.msn.com
127.0.0.1 b.as-us.falkag.net
127.0.0.1 b.liquidustv.com
127.0.0.1 b.myspace.com
127.0.0.1 b.rad.live.com
127.0.0.1 b.rad.msn.com
127.0.0.1 b.scorecardresearch.com
127.0.0.1 b1.adbrite.com
127.0.0.1 b1.azjmp.com
127.0.0.1 babycenter.tt.omtrdc.net
127.0.0.1 badservant.guj.de
127.0.0.1 bananacashback.com
127.0.0.1 banery.acr.pl
127.0.0.1 banery.netart.pl
127.0.0.1 banery.onet.pl
127.0.0.1 banki.onet.pl
127.0.0.1 bankofamerica.tt.omtrdc.net
127.0.0.1 banman.nepsecure.co.uk
127.0.0.1 banner.1and1.co.uk
127.0.0.1 banner.affactive.com
127.0.0.1 banner.betroyalaffiliates.com
127.0.0.1 banner.betwwts.com
127.0.0.1 banner.cdpoker.com
127.0.0.1 banner.clubdicecasino.com
127.0.0.1 banner.coza.com
127.0.0.1 banner.diamondclubcasino.com
127.0.0.1 banner.easyspace.com
127.0.0.1 banner.free6.com # www.free6.com
127.0.0.1 banner.joylandcasino.com
127.0.0.1 banner.media-system.de
127.0.0.1 banner.monacogoldcasino.com
127.0.0.1 banner.newyorkcasino.com
127.0.0.1 banner.northsky.com
127.0.0.1 banner.oddcast.com
127.0.0.1 banner.orb.net
127.0.0.1 banner.piratos.de
127.0.0.1 banner.playgatecasino.com
127.0.0.1 banner.prestigecasino.com
127.0.0.1 banner.publisher.to
127.0.0.1 banner.rbc.ru
127.0.0.1 banner.relcom.ru
127.0.0.1 banner.tattomedia.com
127.0.0.1 banner.techarp.com
127.0.0.1 banner.usacasino.com
127.0.0.1 banner1.pornhost.com
127.0.0.1 banner2.inet-traffic.com
127.0.0.1 bannerads.anytimenews.com
127.0.0.1 bannerads.de
127.0.0.1 bannerads.zwire.com
127.0.0.1 bannerconnect.net
127.0.0.1 bannerdriven.ru
127.0.0.1 bannerfarm.ace.advertising.com
127.0.0.1 bannerhost.egamingonline.com
127.0.0.1 bannerimages.0catch.com
127.0.0.1 bannerpower.com
127.0.0.1 banners.adgoto.com
127.0.0.1 banners.adultfriendfinder.com
127.0.0.1 banners.affiliatefuel.com
127.0.0.1 banners.affiliatefuture.com
127.0.0.1 banners.aftrk.com
127.0.0.1 banners.audioholics.com
127.0.0.1 banners.blogads.com
127.0.0.1 banners.bol.se
127.0.0.1 banners.broadwayworld.com
127.0.0.1 banners.celebritybling.com
127.0.0.1 banners.crisscross.com
127.0.0.1 banners.directnic.com
127.0.0.1 banners.dnastudio.com
127.0.0.1 banners.easydns.com
127.0.0.1 banners.easysolutions.be
127.0.0.1 banners.ebay.com
127.0.0.1 banners.expressindia.com
127.0.0.1 banners.flair.be
127.0.0.1 banners.free6.com # www.free6.com
127.0.0.1 banners.fuifbeest.be
127.0.0.1 banners.globovision.com
127.0.0.1 banners.img.uol.com.br
127.0.0.1 banners.ims.nl
127.0.0.1 banners.iop.org
127.0.0.1 banners.ipotd.com
127.0.0.1 banners.japantoday.com
127.0.0.1 banners.kfmb.com
127.0.0.1 banners.ksl.com
127.0.0.1 banners.linkbuddies.com
127.0.0.1 banners.looksmart.com
127.0.0.1 banners.nbcupromotes.com
127.0.0.1 banners.netcraft.com
127.0.0.1 banners.newsru.com
127.0.0.1 banners.nextcard.com
127.0.0.1 banners.passion.com
127.0.0.1 banners.pennyweb.com
127.0.0.1 banners.primaryclick.com
127.0.0.1 banners.resultonline.com
127.0.0.1 banners.rspworldwide.com
127.0.0.1 banners.sextracker.com
127.0.0.1 banners.spiceworks.com
127.0.0.1 banners.thegridwebmaster.com
127.0.0.1 banners.thestranger.com
127.0.0.1 banners.thgimages.co.uk
127.0.0.1 banners.tribute.ca
127.0.0.1 banners.tucson.com
127.0.0.1 banners.valuead.com
127.0.0.1 banners.webmasterplan.com
127.0.0.1 banners.wunderground.com
127.0.0.1 banners.zbs.ru
127.0.0.1 banners1.linkbuddies.com
127.0.0.1 banners2.castles.org
127.0.0.1 banners3.spacash.com
127.0.0.1 bannersurvey.biz
127.0.0.1 bannert.ru
127.0.0.1 bannerus1.axelsfun.com
127.0.0.1 bannerus3.axelsfun.com
127.0.0.1 banniere.reussissonsensemble.fr
127.0.0.1 bans.bride.ru
127.0.0.1 banstex.com
127.0.0.1 bansys.onzin.com
127.0.0.1 bargainbeautybuys.com
127.0.0.1 barnesandnoble.bfast.com
127.0.0.1 bayoubuzz.advertserve.com
127.0.0.1 bb.crwdcntrl.net
127.0.0.1 bbcdn.go.adlt.bbelements.com
127.0.0.1 bbcdn.go.adnet.bbelements.com
127.0.0.1 bbcdn.go.arbo.bbelements.com
127.0.0.1 bbcdn.go.eu.bbelements.com
127.0.0.1 bbcdn.go.ihned.bbelements.com
127.0.0.1 bbcdn.go.pl.bbelements.com
127.0.0.1 bbnaut.bbelements.com
127.0.0.1 bc685d37-266c-488e-824e-dd95d1c0e98b.statcamp.net
127.0.0.1 bcp.crwdcntrl.net
127.0.0.1 bdnad1.bangornews.com
127.0.0.1 bdv.bidvertiser.com
127.0.0.1 beacon-3.newrelic.com
127.0.0.1 beacons.helium.com
127.0.0.1 bell.adcentriconline.com
127.0.0.1 beseenad.looksmart.com
127.0.0.1 bestgift4you.cn
127.0.0.1 bestshopperrewards.com
127.0.0.1 beta.hotkeys.com
127.0.0.1 betterperformance.goldenopps.info
127.0.0.1 bfast.com
127.0.0.1 bid.openx.net
127.0.0.1 bidclix.net
127.0.0.1 bidsystem.com
127.0.0.1 bidtraffic.com
127.0.0.1 bidvertiser.com
127.0.0.1 bigads.guj.de
127.0.0.1 bigbrandpromotions.com
127.0.0.1 bigbrandrewards.com
127.0.0.1 biggestgiftrewards.com
127.0.0.1 bild.ivwbox.de
127.0.0.1 billing.speedboink.com
127.0.0.1 bitburg.adtech.de
127.0.0.1 bitburg.adtech.fr
127.0.0.1 bitburg.adtech.us
127.0.0.1 bitcast-d.bitgravity.com
127.0.0.1 biz-offer.com
127.0.0.1 bizad.nikkeibp.co.jp
127.0.0.1 bizopprewards.com
127.0.0.1 bl.wavecdn.de
127.0.0.1 blabla4u.adserver.co.il
127.0.0.1 blasphemysfhs.info
127.0.0.1 blatant8jh.info
127.0.0.1 blog.addthis.com
127.0.0.1 blogads.com
127.0.0.1 blogads.ebanner.nl
127.0.0.1 blogvertising.pl
127.0.0.1 blu.mobileads.msn.com
127.0.0.1 bluediamondoffers.com
127.0.0.1 bn.bfast.com
127.0.0.1 bnmgr.adinjector.net
127.0.0.1 boksy.dir.onet.pl
127.0.0.1 boksy.onet.pl
127.0.0.1 bookclub-offer.com
127.0.0.1 books-media-edu-premiumblvd.com
127.0.0.1 books-media-edu-rewardempire.com
127.0.0.1 books-media-rewardpath.com
127.0.0.1 bostonsubwayoffer.com
127.0.0.1 bp.specificclick.net
127.0.0.1 br.adserver.yahoo.com
127.0.0.1 br.naked.com
127.0.0.1 brandrewardcentral.com
127.0.0.1 brandsurveypanel.com
127.0.0.1 bravo.israelinfo.ru
127.0.0.1 bravospots.com        
127.0.0.1 broadcast.piximedia.fr
127.0.0.1 broadent.vo.llnwd.net
127.0.0.1 brokertraffic.com
127.0.0.1 bs.israelinfo.ru
127.0.0.1 bs.serving-sys.com    #eyeblaster.com
127.0.0.1 bsads.looksmart.com
127.0.0.1 bt.linkpulse.com
127.0.0.1 burns.adtech.de
127.0.0.1 burns.adtech.fr
127.0.0.1 burns.adtech.us
127.0.0.1 bus-offer.com
127.0.0.1 business-rewardpath.com
127.0.0.1 buttcandy.com
127.0.0.1 buttons.googlesyndication.com
127.0.0.1 buzzbox.buzzfeed.com
127.0.0.1 bwp.lastfm.com.com
127.0.0.1 bwp.news.com
127.0.0.1 c.actiondesk.com
127.0.0.1 c.adroll.com
127.0.0.1 c.ar.msn.com
127.0.0.1 c.as-us.falkag.net
127.0.0.1 c.at.msn.com
127.0.0.1 c.be.msn.com
127.0.0.1 c.blogads.com
127.0.0.1 c.br.msn.com
127.0.0.1 c.ca.msn.com
127.0.0.1 c.casalemedia.com
127.0.0.1 c.cl.msn.com
127.0.0.1 c.de.msn.com
127.0.0.1 c.dk.msn.com
127.0.0.1 c.es.msn.com
127.0.0.1 c.fi.msn.com
127.0.0.1 c.fr.msn.com
127.0.0.1 c.gr.msn.com
127.0.0.1 c.hk.msn.com
127.0.0.1 c.id.msn.com
127.0.0.1 c.ie.msn.com
127.0.0.1 c.il.msn.com
127.0.0.1 c.in.msn.com
127.0.0.1 c.it.msn.com
127.0.0.1 c.jp.msn.com
127.0.0.1 c.latam.msn.com
127.0.0.1 c.lomadee.com
127.0.0.1 c.my.msn.com
127.0.0.1 c.ninemsn.com.au
127.0.0.1 c.nl.msn.com
127.0.0.1 c.no.msn.com
127.0.0.1 c.ph.msn.com
127.0.0.1 c.prodigy.msn.com
127.0.0.1 c.pt.msn.com
127.0.0.1 c.ru.msn.com
127.0.0.1 c.se.msn.com
127.0.0.1 c.sg.msn.com
127.0.0.1 c.th.msn.com
127.0.0.1 c.tr.msn.com
127.0.0.1 c.tw.msn.com
127.0.0.1 c.uk.msn.com
127.0.0.1 c.za.msn.com
127.0.0.1 c1.zedo.com
127.0.0.1 c2.zedo.com
127.0.0.1 c3.zedo.com
127.0.0.1 c4.maxserving.com
127.0.0.1 c4.zedo.com
127.0.0.1 c5.zedo.com
127.0.0.1 c6.zedo.com
127.0.0.1 c7.zedo.com
127.0.0.1 c8.zedo.com
127.0.0.1 ca.adserver.yahoo.com
127.0.0.1 cablevision.112.2o7.net
127.0.0.1 cache-dev.addthis.com
127.0.0.1 cache.addthis.com
127.0.0.1 cache.addthiscdn.com
127.0.0.1 cache.blogads.com
127.0.0.1 cache.unicast.com
127.0.0.1 cacheserve.eurogrand.com
127.0.0.1 cacheserve.prestigecasino.com
127.0.0.1 califia.imaginemedia.com
127.0.0.1 camgeil.com
127.0.0.1 campaign.iitech.dk
127.0.0.1 campaign.indieclick.com
127.0.0.1 campaigns.f2.com.au
127.0.0.1 campaigns.interclick.com
127.0.0.1 capath.com
127.0.0.1 car-truck-boat-bonuspath.com
127.0.0.1 car-truck-boat-premiumblvd.com
127.0.0.1 cardgamespidersolitaire.com
127.0.0.1 cards.virtuagirlhd.com
127.0.0.1 careers-rewardpath.com
127.0.0.1 careers.canwestad.net
127.0.0.1 carrier.bz
127.0.0.1 cas.clickability.com
127.0.0.1 casalemedia.com
127.0.0.1 cashback.co.uk
127.0.0.1 cashbackwow.co.uk
127.0.0.1 cashflowmarketing.com
127.0.0.1 casino770.com
127.0.0.1 catalinkcashback.com
127.0.0.1 catchvid.info
127.0.0.1 cbanners.virtuagirlhd.com
127.0.0.1 ccas.clearchannel.com
127.0.0.1 cdn.adigniter.org
127.0.0.1 cdn.adnxs.com
127.0.0.1 cdn.amateurmatch.com
127.0.0.1 cdn.amgdgt.com
127.0.0.1 cdn.assets.craveonline.com
127.0.0.1 cdn.banners.scubl.com
127.0.0.1 cdn.cpmstar.com
127.0.0.1 cdn.crowdignite.com
127.0.0.1 cdn.eyewonder.com
127.0.0.1 cdn.go.arbo.bbelements.com
127.0.0.1 cdn.go.arbopl.bbelements.com
127.0.0.1 cdn.go.cz.bbelements.com
127.0.0.1 cdn.go.idmnet.bbelements.com
127.0.0.1 cdn.go.pol.bbelements.com
127.0.0.1 cdn.hadj7.adjuggler.net
127.0.0.1 cdn.innovid.com
127.0.0.1 cdn.mediative.ca
127.0.0.1 cdn.merchenta.com
127.0.0.1 cdn.mobicow.com
127.0.0.1 cdn.nearbyad.com
127.0.0.1 cdn.nsimg.net
127.0.0.1 cdn.onescreen.net
127.0.0.1 cdn.stat.easydate.biz
127.0.0.1 cdn.syn.verticalacuity.com
127.0.0.1 cdn.tabnak.ir
127.0.0.1 cdn.udmserve.net
127.0.0.1 cdn.undertone.com
127.0.0.1 cdn.wg.uproxx.com
127.0.0.1 cdn.zeusclicks.com
127.0.0.1 cdn1.ads.mofos.com
127.0.0.1 cdn1.eyewonder.com
127.0.0.1 cdn1.rmgserving.com
127.0.0.1 cdn1.xlightmedia.com
127.0.0.1 cdn2.adsdk.com
127.0.0.1 cdn2.amateurmatch.com
127.0.0.1 cdn3.telemetryverification.net
127.0.0.1 cdn454.telemetryverification.net
127.0.0.1 cdn5.tribalfusion.com
127.0.0.1 cdnads.cam4.com
127.0.0.1 cdns.mydirtyhobby.com
127.0.0.1 cdns.privatamateure.com
127.0.0.1 cdnw.ringtonepartner.com
127.0.0.1 cds.adecn.com
127.0.0.1 cecash.com
127.0.0.1 ced.sascdn.com
127.0.0.1 cell-phone-giveaways.com
127.0.0.1 cellphoneincentives.com
127.0.0.1 cent.adbureau.net
127.0.0.1 cf.kampyle.com
127.0.0.1 cgirm.greatfallstribune.com
127.0.0.1 cgm.adbureau.ne
127.0.0.1 cgm.adbureau.net
127.0.0.1 chainsawoffer.com
127.0.0.1 checkintocash.data.7bpeople.com
127.0.0.1 cherryhi.app.ur.gcion.com
127.0.0.1 chkpt.zdnet.com
127.0.0.1 choicedealz.com
127.0.0.1 choicesurveypanel.com
127.0.0.1 christianbusinessadvertising.com
127.0.0.1 cithingy.info
127.0.0.1 citi.bridgetrack.com
127.0.0.1 citrix.market2lead.com
127.0.0.1 cityads.telus.net
127.0.0.1 citycash2.blogspot.com
127.0.0.1 cl21.v4.adaction.se
127.0.0.1 cl320.v4.adaction.se
127.0.0.1 claimfreerewards.com
127.0.0.1 clashmediausa.com
127.0.0.1 classicjack.com
127.0.0.1 click-find-save.com
127.0.0.1 click-see-save.com
127.0.0.1 click.avenuea.com
127.0.0.1 click.go2net.com
127.0.0.1 click.israelinfo.ru
127.0.0.1 click.pulse360.com
127.0.0.1 click1.mainadv.com
127.0.0.1 click1.rbc.magna.ru
127.0.0.1 click2.rbc.magna.ru
127.0.0.1 click3.rbc.magna.ru
127.0.0.1 click4.rbc.magna.ru
127.0.0.1 clickad.eo.pl
127.0.0.1 clickarrows.com
127.0.0.1 clickbangpop.com
127.0.0.1 clickcash.webpower.com
127.0.0.1 clickit.go2net.com
127.0.0.1 clickmedia.ro
127.0.0.1 clicks.adultplex.com
127.0.0.1 clicks.deskbabes.com
127.0.0.1 clicks.totemcash.com
127.0.0.1 clicks.toteme.com
127.0.0.1 clicks.virtuagirl.com
127.0.0.1 clicks.virtuagirlhd.com
127.0.0.1 clicks.virtuaguyhd.com
127.0.0.1 clicks.walla.co.il
127.0.0.1 clicks2.virtuagirl.com
127.0.0.1 clicksor.com
127.0.0.1 clicksotrk.com
127.0.0.1 clickthru.net
127.0.0.1 clickthrunet.net
127.0.0.1 clickthruserver.com
127.0.0.1 clickthrutraffic.com
127.0.0.1 clicktorrent.info
127.0.0.1 clipserv.adclip.com
127.0.0.1 clk.cloudyisland.com
127.0.0.1 clk.tradedoubler.com
127.0.0.1 clkads.com
127.0.0.1 clkuk.tradedoubler.com
127.0.0.1 closeoutproductsreview.com
127.0.0.1 cluster.adultadworld.com
127.0.0.1 cluster3.adultadworld.com
127.0.0.1 cm.npc-hearst.overture.com
127.0.0.1 cm.the-n.overture.com
127.0.0.1 cm1359.com
127.0.0.1 cmads.sv.publicus.com
127.0.0.1 cmads.us.publicus.com
127.0.0.1 cmap.am.ace.advertising.com
127.0.0.1 cmap.an.ace.advertising.com
127.0.0.1 cmap.at.ace.advertising.com
127.0.0.1 cmap.dc.ace.advertising.com
127.0.0.1 cmap.ox.ace.advertising.com
127.0.0.1 cmap.pub.ace.advertising.com
127.0.0.1 cmap.rm.ace.advertising.com
127.0.0.1 cmap.rub.ace.advertising.com
127.0.0.1 cmhtml.overture.com
127.0.0.1 cmn1lsm2.beliefnet.com
127.0.0.1 cmps.mt50ad.com
127.0.0.1 cn.adserver.yahoo.com
127.0.0.1 cnad.economicoutlook.net
127.0.0.1 cnad1.economicoutlook.net
127.0.0.1 cnad2.economicoutlook.net
127.0.0.1 cnad3.economicoutlook.net
127.0.0.1 cnad4.economicoutlook.net
127.0.0.1 cnad5.economicoutlook.net
127.0.0.1 cnad6.economicoutlook.net
127.0.0.1 cnad7.economicoutlook.net
127.0.0.1 cnad8.economicoutlook.net
127.0.0.1 cnad9.economicoutlook.net
127.0.0.1 cnf.adshuffle.com
127.0.0.1 cnt1.xhamster.com
127.0.0.1 code.adtlgc.com
127.0.0.1 code2.adtlgc.com
127.0.0.1 col.mobileads.msn.com
127.0.0.1 collectiveads.net
127.0.0.1 com.cool-premiums-now.com
127.0.0.1 com.htmlwww.youfck.com
127.0.0.1 com.shc-rebates.com
127.0.0.1 comadverts.bcmpweb.co.nz
127.0.0.1 comcastresidentialservices.tt.omtrdc.net
127.0.0.1 come-see-it-all.com
127.0.0.1 commerce-offer.com
127.0.0.1 commerce-rewardpath.com
127.0.0.1 commerce.www.ibm.com
127.0.0.1 common.ziffdavisinternet.com
127.0.0.1 companion.adap.tv
127.0.0.1 computer-offer.com
127.0.0.1 computer-offer.net
127.0.0.1 computers-electronics-rewardpath.com
127.0.0.1 computersncs.com
127.0.0.1 condenast.112.2o7.net
127.0.0.1 connect.247media.ads.link4ads.com
127.0.0.1 consumer-org.com
127.0.0.1 consumergiftcenter.com
127.0.0.1 consumerincentivenetwork.com
127.0.0.1 consumerinfo.tt.omtrdc.net
127.0.0.1 contaxe.com
127.0.0.1 content.ad-flow.com
127.0.0.1 content.clipster.ws
127.0.0.1 content.codelnet.com
127.0.0.1 content.promoisland.net
127.0.0.1 content.yieldmanager.edgesuite.net
127.0.0.1 contentsearch.de.espotting.com
127.0.0.1 context.adshadow.net
127.0.0.1 context3.kanoodle.com
127.0.0.1 context5.kanoodle.com
127.0.0.1 contextweb.com
127.0.0.1 conv.adengage.com
127.0.0.1 conversion-pixel.invitemedia.com
127.0.0.1 cookie.pebblemedia.be
127.0.0.1 cookiecontainer.blox.pl
127.0.0.1 cookingtiprewards.com
127.0.0.1 cookonsea.com
127.0.0.1 cool-premiums-now.com
127.0.0.1 cool-premiums.com
127.0.0.1 coolpremiumsnow.com
127.0.0.1 coolsavings.com
127.0.0.1 corba.adtech.de
127.0.0.1 corba.adtech.fr
127.0.0.1 corba.adtech.us
127.0.0.1 core.insightexpressai.com
127.0.0.1 core.videoegg.com
127.0.0.1 core0.node12.top.mail.ru
127.0.0.1 core2.adtlgc.com
127.0.0.1 coreg.flashtrack.net
127.0.0.1 coreglead.co.uk
127.0.0.1 cornflakes.pathfinder.com
127.0.0.1 corusads.dserv.ca
127.0.0.1 cosmeticscentre.uk.com
127.0.0.1 count.casino-trade.com
127.0.0.1 count6.51yes.com
127.0.0.1 cover.m2y.siemens.ch
127.0.0.1 cp.promoisland.net
127.0.0.1 cpmadvisors.com
127.0.0.1 cpu.firingsquad.com
127.0.0.1 creatiby1.unicast.com
127.0.0.1 creative.adshuffle.com
127.0.0.1 creative.ak.facebook.com
127.0.0.1 creatives.livejasmin.com
127.0.0.1 creatives.rgadvert.com
127.0.0.1 creatrixads.com
127.0.0.1 crediblegfj.info
127.0.0.1 creditburner.blueadvertise.com
127.0.0.1 creditsoffer.blogspot.com
127.0.0.1 creview.adbureau.net
127.0.0.1 crosspixel.demdex.net
127.0.0.1 crowdgravity.com
127.0.0.1 crowdignite.com
127.0.0.1 crux.songline.com
127.0.0.1 crwdcntrl.net
127.0.0.1 cserver.mii.instacontent.net
127.0.0.1 csh.actiondesk.com
127.0.0.1 csm.rotator.hadj7.adjuggler.net
127.0.0.1 cspix.media6degrees.com
127.0.0.1 csr.onet.pl
127.0.0.1 ctbdev.net
127.0.0.1 cts.channelintelligence.com
127.0.0.1 ctxtad.tribalfusion.com
127.0.0.1 cxoadfarm.dyndns.info
127.0.0.1 cxtad.specificmedia.com
127.0.0.1 cyber-incentives.com
127.0.0.1 cz.bbelements.com
127.0.0.1 cz8.clickzs.com
127.0.0.1 d.101m3.com
127.0.0.1 d.adnetxchange.com
127.0.0.1 d.ads.readwriteweb.com
127.0.0.1 d.adserve.com
127.0.0.1 d.agkn.com
127.0.0.1 d1.openx.org
127.0.0.1 d1.zedo.com
127.0.0.1 d10.zedo.com
127.0.0.1 d11.zedo.com
127.0.0.1 d12.zedo.com
127.0.0.1 d14.zedo.com
127.0.0.1 d1ros97qkrwjf5.cloudfront.net
127.0.0.1 d2.zedo.com
127.0.0.1 d3.zedo.com
127.0.0.1 d4.zedo.com
127.0.0.1 d5.zedo.com
127.0.0.1 d5phz18u4wuww.cloudfront.net
127.0.0.1 d6.c5.b0.a2.top.mail.ru
127.0.0.1 d6.zedo.com
127.0.0.1 d7.zedo.com
127.0.0.1 d8.zedo.com
127.0.0.1 d9.zedo.com
127.0.0.1 da.2000888.com
127.0.0.1 da.feedsportal.com
127.0.0.1 dads.new.digg.com
127.0.0.1 daily-saver.com
127.0.0.1 darmowe-liczniki.info
127.0.0.1 dart.chron.com
127.0.0.1 data.flurry.com
127.0.0.1 date.ventivmedia.com
127.0.0.1 datingadvertising.com
127.0.0.1 db4.net-filter.com
127.0.0.1 dbbsrv.com
127.0.0.1 dc.sabela.com.pl
127.0.0.1 dctracking.com
127.0.0.1 de.adserver.yahoo.com
127.0.0.1 del1.phillyburbs.com
127.0.0.1 delb.mspaceads.com
127.0.0.1 delivery.adyea.com
127.0.0.1 delivery.trafficjunky.net
127.0.0.1 delivery.w00tads.com
127.0.0.1 delivery.way2traffic.com
127.0.0.1 demr.mspaceads.com
127.0.0.1 demr.opt.fimserve.com
127.0.0.1 derkeiler.com
127.0.0.1 desb.mspaceads.com
127.0.0.1 descargas2.tuvideogratis.com
127.0.0.1 designbloxlive.com
127.0.0.1 desk.mspaceads.com
127.0.0.1 desk.opt.fimserve.com
127.0.0.1 dev.adforum.com
127.0.0.1 dev.sfbg.com
127.0.0.1 devart.adbureau.net
127.0.0.1 devlp1.linkpulse.com
127.0.0.1 dg.specificclick.net
127.0.0.1 dgm2.com
127.0.0.1 dgmaustralia.com
127.0.0.1 dietoftoday.ca.pn #security risk/fake news#
127.0.0.1 diff3.smartadserver.com
127.0.0.1 dinoadserver1.roka.net
127.0.0.1 dinoadserver2.roka.net
127.0.0.1 directleads.com
127.0.0.1 directpowerrewards.com
127.0.0.1 dirtyrhino.com
127.0.0.1 discount-savings-more.com
127.0.0.1 discoverecommerce.tt.omtrdc.net
127.0.0.1 display.gestionpub.com
127.0.0.1 dist.belnk.com
127.0.0.1 divx.adbureau.net
127.0.0.1 djbanners.deadjournal.com
127.0.0.1 djugoogs.com
127.0.0.1 dk.adserver.yahoo.com
127.0.0.1 dl-plugin.com
127.0.0.1 dl.ncbuy.com
127.0.0.1 dlvr.readserver.net
127.0.0.1 dnads.directnic.com
127.0.0.1 dnps.com
127.0.0.1 dnse.linkpulse.com
127.0.0.1 do-wn-lo-ad.com
127.0.0.1 dosugcz.biz
127.0.0.1 dot.wp.pl
127.0.0.1 downloadcdn.com
127.0.0.1 downloads.larivieracasino.com
127.0.0.1 downloads.mytvandmovies.com
127.0.0.1 dqs001.adtech.de
127.0.0.1 dqs001.adtech.fr
127.0.0.1 dqs001.adtech.us
127.0.0.1 dra.amazon-adsystem.com
127.0.0.1 drowle.com
127.0.0.1 ds.contextweb.com
127.0.0.1 ds.onet.pl
127.0.0.1 ds.serving-sys.com
127.0.0.1 dt.linkpulse.com
127.0.0.1 dub.mobileads.msn.com
127.0.0.1 e.as-eu.falkag.net
127.0.0.1 e0.extreme-dm.com
127.0.0.1 e1.addthis.com
127.0.0.1 ead.sharethis.com
127.0.0.1 eads-adserving.com
127.0.0.1 earnmygift.com
127.0.0.1 earnpointsandgifts.com
127.0.0.1 easyadservice.com
127.0.0.1 easyweb.tdcanadatrust.secureserver.host1.customer-identification-process.b88600d8.com
127.0.0.1 eatps.web.aol.com
127.0.0.1 eb.adbureau.net
127.0.0.1 eblastengine.upickem.net
127.0.0.1 ecomadserver.com
127.0.0.1 eddamedia.linkpulse.com
127.0.0.1 edge.bnmla.com
127.0.0.1 edge.quantserve.com
127.0.0.1 edirect.hotkeys.com
127.0.0.1 edu-offer.com
127.0.0.1 education-rewardpath.com
127.0.0.1 electronics-bonuspath.com
127.0.0.1 electronics-offer.net
127.0.0.1 electronics-rewardpath.com
127.0.0.1 electronicspresent.com
127.0.0.1 emailadvantagegroup.com
127.0.0.1 emailproductreview.com
127.0.0.1 emapadserver.com
127.0.0.1 emea-bidder.mathtag.com
127.0.0.1 engage.everyone.net
127.0.0.1 engage.speedera.net
127.0.0.1 engine.adland.ru
127.0.0.1 engine.adzerk.net
127.0.0.1 engine.espace.netavenir.com
127.0.0.1 engine.influads.com
127.0.0.1 engine.rorer.ru
127.0.0.1 engine2.adzerk.net
127.0.0.1 enirocode.adtlgc.com
127.0.0.1 enirodk.adtlgc.com
127.0.0.1 enn.advertserve.com
127.0.0.1 entertainment-rewardpath.com
127.0.0.1 entertainment-specials.com
127.0.0.1 erie.smartage.com
127.0.0.1 ero-advertising.com
127.0.0.1 es.adserver.yahoo.com
127.0.0.1 escape.insites.eu
127.0.0.1 espn.footprint.net
127.0.0.1 etad.telegraph.co.uk
127.0.0.1 etrk.asus.com
127.0.0.1 etype.adbureau.net
127.0.0.1 eu-pn4.adserver.yahoo.com
127.0.0.1 eu.xtms.net
127.0.0.1 euniverseads.com
127.0.0.1 europe.adserver.yahoo.com
127.0.0.1 eventtracker.videostrip.com
127.0.0.1 exclusivegiftcards.com
127.0.0.1 exits1.webquest.net
127.0.0.1 exits2.webquest.net
127.0.0.1 exponential.com
127.0.0.1 eyewonder.com
127.0.0.1 ezboard.bigbangmedia.com
127.0.0.1 f.as-eu.falkag.net
127.0.0.1 falkag.net
127.0.0.1 family-offer.com
127.0.0.1 farm.plista.com
127.0.0.1 fatcatrewards.com
127.0.0.1 faz.ivwbox.de
127.0.0.1 fbcdn-creative-a.akamaihd.net
127.0.0.1 fbfreegifts.com
127.0.0.1 fc.webmasterpro.de
127.0.0.1 fcg.casino770.com
127.0.0.1 fdimages.fairfax.com.au
127.0.0.1 fe.lea.lycos.es
127.0.0.1 feedads.googleadservices.com
127.0.0.1 feeds.videosz.com
127.0.0.1 feeds.weselltraffic.com
127.0.0.1 fei.pro-market.net
127.0.0.1 fhm.valueclick.net
127.0.0.1 fif49.info
127.0.0.1 files.adbrite.com
127.0.0.1 fin.adbureau.net
127.0.0.1 finance-offer.com
127.0.0.1 finanzmeldungen.com
127.0.0.1 finder.cox.net
127.0.0.1 floatingads.madisonavenue.com
127.0.0.1 floridat.app.ur.gcion.com
127.0.0.1 flowers-offer.com
127.0.0.1 fls-na.amazon.com
127.0.0.1 flu23.com
127.0.0.1 fmads.osdn.com
127.0.0.1 focusin.ads.targetnet.com
127.0.0.1 folloyu.com
127.0.0.1 food-drink-bonuspath.com
127.0.0.1 food-drink-rewardpath.com
127.0.0.1 food-offer.com
127.0.0.1 foodmixeroffer.com
127.0.0.1 foreignpolicy.advertserve.com
127.0.0.1 fp.uclo.net
127.0.0.1 fp.valueclick.com
127.0.0.1 fr.a2dfp.net
127.0.0.1 fr.adserver.yahoo.com
127.0.0.1 fr.classic.clickintext.net
127.0.0.1 free-gift-cards-now.com
127.0.0.1 free-gifts-comp.com
127.0.0.1 free-laptop-reward.com
127.0.0.1 free-rewards.com-s.tv
127.0.0.1 free.hotsocialz.com
127.0.0.1 free.thesocialsexnetwork.com
127.0.0.1 freebiegb.co.uk
127.0.0.1 freecameraonus.com
127.0.0.1 freecameraprovider.com
127.0.0.1 freecamerasource.com
127.0.0.1 freecamerauk.co.uk
127.0.0.1 freecoolgift.com
127.0.0.1 freedesignerhandbagreviews.com
127.0.0.1 freedinnersource.com
127.0.0.1 freedvddept.com
127.0.0.1 freeelectronicscenter.com
127.0.0.1 freeelectronicsdepot.com
127.0.0.1 freeelectronicsonus.com
127.0.0.1 freeelectronicssource.com
127.0.0.1 freeentertainmentsource.com
127.0.0.1 freefoodprovider.com
127.0.0.1 freefoodsource.com
127.0.0.1 freefuelcard.com
127.0.0.1 freefuelcoupon.com
127.0.0.1 freegasonus.com
127.0.0.1 freegasprovider.com
127.0.0.1 freegiftcardsource.com
127.0.0.1 freegiftreward.com
127.0.0.1 freeipodnanouk.co.uk
127.0.0.1 freeipoduk.co.uk
127.0.0.1 freeipoduk.com
127.0.0.1 freelaptopgift.com
127.0.0.1 freelaptopnation.com
127.0.0.1 freelaptopreward.com
127.0.0.1 freelaptopwebsites.com
127.0.0.1 freenation.com
127.0.0.1 freeoffers-toys.com
127.0.0.1 freepayasyougotopupuk.co.uk
127.0.0.1 freeplasmanation.com
127.0.0.1 freerestaurantprovider.com
127.0.0.1 freerestaurantsource.com
127.0.0.1 freeshoppingprovider.com
127.0.0.1 freeshoppingsource.com
127.0.0.1 frontend-loadbalancer.meteorsolutions.com
127.0.0.1 fwdservice.com
127.0.0.1 fwmrm.net
127.0.0.1 g.thinktarget.com
127.0.0.1 g1.idg.pl
127.0.0.1 g2.gumgum.com
127.0.0.1 g3t4d5.madison.com
127.0.0.1 gadgeteer.pdamart.com
127.0.0.1 gam.adnxs.com
127.0.0.1 gameconsolerewards.com
127.0.0.1 games-toys-bonuspath.com
127.0.0.1 games-toys-free.com
127.0.0.1 games-toys-rewardpath.com
127.0.0.1 gate.hyperpaysys.com
127.0.0.1 gavzad.keenspot.com
127.0.0.1 gazeta.hit.gemius.pl
127.0.0.1 gazetteextra.advertserve.com
127.0.0.1 gbanners.hornymatches.com
127.0.0.1 gc.gcl.ru
127.0.0.1 gcads.osdn.com
127.0.0.1 gcdn.2mdn.net
127.0.0.1 gcir.gannett-tv.com
127.0.0.1 gcirm.argusleader.com
127.0.0.1 gcirm.argusleader.gcion.com
127.0.0.1 gcirm.battlecreekenquirer.com
127.0.0.1 gcirm.burlingtonfreepress.com
127.0.0.1 gcirm.centralohio.com
127.0.0.1 gcirm.centralohio.gcion.com
127.0.0.1 gcirm.cincinnati.com
127.0.0.1 gcirm.citizen-times.com
127.0.0.1 gcirm.clarionledger.com
127.0.0.1 gcirm.coloradoan.com
127.0.0.1 gcirm.courier-journal.com
127.0.0.1 gcirm.courierpostonline.com
127.0.0.1 gcirm.customcoupon.com
127.0.0.1 gcirm.dailyrecord.com
127.0.0.1 gcirm.delawareonline.com
127.0.0.1 gcirm.democratandchronicle.com
127.0.0.1 gcirm.desmoinesregister.com
127.0.0.1 gcirm.detnews.com
127.0.0.1 gcirm.dmp.gcion.com
127.0.0.1 gcirm.dmregister.com
127.0.0.1 gcirm.dnj.com
127.0.0.1 gcirm.flatoday.com
127.0.0.1 gcirm.gannett-tv.com
127.0.0.1 gcirm.gannettnetwork.com
127.0.0.1 gcirm.greatfallstribune.com
127.0.0.1 gcirm.greenvilleonline.com
127.0.0.1 gcirm.greenvilleonline.gcion.com
127.0.0.1 gcirm.honoluluadvertiser.gcion.com
127.0.0.1 gcirm.idahostatesman.com
127.0.0.1 gcirm.idehostatesman.com
127.0.0.1 gcirm.indystar.com
127.0.0.1 gcirm.injersey.com
127.0.0.1 gcirm.jacksonsun.com
127.0.0.1 gcirm.laregionalonline.com
127.0.0.1 gcirm.lsj.com
127.0.0.1 gcirm.montgomeryadvertiser.com
127.0.0.1 gcirm.muskogeephoenix.com
127.0.0.1 gcirm.news-press.com
127.0.0.1 gcirm.newsleader.com
127.0.0.1 gcirm.ozarksnow.com
127.0.0.1 gcirm.pensacolanewsjournal.com
127.0.0.1 gcirm.press-citizen.com
127.0.0.1 gcirm.pressconnects.com
127.0.0.1 gcirm.rgj.com
127.0.0.1 gcirm.sctimes.com
127.0.0.1 gcirm.stargazette.com
127.0.0.1 gcirm.statesmanjournal.com
127.0.0.1 gcirm.tallahassee.com
127.0.0.1 gcirm.tennessean.com
127.0.0.1 gcirm.thedailyjournal.com
127.0.0.1 gcirm.thedesertsun.com
127.0.0.1 gcirm.theithacajournal.com
127.0.0.1 gcirm.thejournalnews.com
127.0.0.1 gcirm.theolympian.com
127.0.0.1 gcirm.thespectrum.com
127.0.0.1 gcirm.tucson.com
127.0.0.1 gcirm.wisinfo.com
127.0.0.1 gcirm2.indystar.com
127.0.0.1 gde.adocean.pl
127.0.0.1 gdeee.hit.gemius.pl
127.0.0.1 gdelt.hit.gemius.pl
127.0.0.1 gdelv.hit.gemius.pl
127.0.0.1 gdyn.cnngo.com
127.0.0.1 gdyn.trutv.com
127.0.0.1 gemius.pl
127.0.0.1 geo.precisionclick.com
127.0.0.1 geoads.osdn.com
127.0.0.1 geoloc11.geovisite.com
127.0.0.1 getacool100.com
127.0.0.1 getacool500.com
127.0.0.1 getacoollaptop.com
127.0.0.1 getacooltv.com
127.0.0.1 getafreeiphone.org
127.0.0.1 getagiftonline.com
127.0.0.1 getmyfreebabystuff.com
127.0.0.1 getmyfreegear.com
127.0.0.1 getmyfreegiftcard.com
127.0.0.1 getmyfreelaptop.com
127.0.0.1 getmyfreelaptophere.com
127.0.0.1 getmyfreeplasma.com
127.0.0.1 getmylaptopfree.com
127.0.0.1 getmyplasmatv.com
127.0.0.1 getspecialgifts.com
127.0.0.1 getyour5kcredits0.blogspot.com
127.0.0.1 getyourfreecomputer.com
127.0.0.1 getyourfreetv.com
127.0.0.1 getyourgiftnow2.blogspot.com
127.0.0.1 getyourgiftnow3.blogspot.com
127.0.0.1 gg.adocean.pl
127.0.0.1 giftcardchallenge.com
127.0.0.1 giftcardsurveys.us.com
127.0.0.1 giftrewardzone.com
127.0.0.1 gifts-flowers-rewardpath.com
127.0.0.1 gimmethatreward.com
127.0.0.1 gingert.net
127.0.0.1 globalwebads.com
127.0.0.1 gm.preferences.com
127.0.0.1 gmads.net
127.0.0.1 go-free-gifts.com
127.0.0.1 go.adee.bbelements.com
127.0.0.1 go.adlt.bbelements.com
127.0.0.1 go.adlv.bbelements.com
127.0.0.1 go.adnet.bbelements.com
127.0.0.1 go.arbo.bbelements.com
127.0.0.1 go.arbopl.bbelements.com
127.0.0.1 go.arboru.bbelements.com
127.0.0.1 go.bb007.bbelements.com
127.0.0.1 go.evolutionmedia.bbelements.com
127.0.0.1 go.ihned.bbelements.com
127.0.0.1 go.intact.bbelements.com
127.0.0.1 go.lfstmedia.com
127.0.0.1 go.lotech.bbelements.com
127.0.0.1 go.pl.bbelements.com
127.0.0.1 go2.hit.gemius.pl
127.0.0.1 gofreegifts.com
127.0.0.1 goody-garage.com
127.0.0.1 got2goshop.com
127.0.0.1 goto.trafficmultiplier.com
127.0.0.1 gozing.directtrack.com
127.0.0.1 grabbit-rabbit.com
127.0.0.1 graphics.adultfriendfinder.com
127.0.0.1 gratkapl.adocean.pl
127.0.0.1 gravitron.chron.com
127.0.0.1 greasypalm.com
127.0.0.1 grfx.mp3.com
127.0.0.1 groupon.pl
127.0.0.1 grz67.com
127.0.0.1 gs1.idsales.co.uk
127.0.0.1 gserv.cneteu.net
127.0.0.1 gspro.hit.gemius.pl
127.0.0.1 guiaconsumidor.com
127.0.0.1 guide2poker.com
127.0.0.1 guptamedianetwork.com
127.0.0.1 guru.sitescout.netdna-cdn.com
127.0.0.1 gwallet.com
127.0.0.1 gx-in-f109.1e100.net
127.0.0.1 h-afnetwww.adshuffle.com
127.0.0.1 halfords.ukrpts.net
127.0.0.1 happydiscountspecials.com
127.0.0.1 harvest.adgardener.com
127.0.0.1 harvest176.adgardener.com
127.0.0.1 harvest284.adgardener.com
127.0.0.1 harvest285.adgardener.com
127.0.0.1 hathor.eztonez.com
127.0.0.1 haynet.adbureau.net
127.0.0.1 hbads.eboz.com
127.0.0.1 hbadz.eboz.com
127.0.0.1 health-beauty-rewardpath.com
127.0.0.1 health-beauty-savingblvd.com
127.0.0.1 healthbeautyncs.com
127.0.0.1 healthclicks.co.uk
127.0.0.1 hebdotop.com
127.0.0.1 help.adtech.de
127.0.0.1 help.adtech.fr
127.0.0.1 help.adtech.us
127.0.0.1 helpint.mywebsearch.com
127.0.0.1 hightrafficads.com
127.0.0.1 himediads.com
127.0.0.1 hit4.hotlog.ru
127.0.0.1 hk.adserver.yahoo.com
127.0.0.1 hlcc.ca
127.0.0.1 holiday-gift-offers.com
127.0.0.1 holidayproductpromo.com
127.0.0.1 holidayshoppingrewards.com
127.0.0.1 home-garden-premiumblvd.com
127.0.0.1 home-garden-rewardempire.com
127.0.0.1 home-garden-rewardpath.com
127.0.0.1 home4bizstart.ru
127.0.0.1 homeelectronicproducts.com
127.0.0.1 homeimprovementonus.com
127.0.0.1 honolulu.app.ur.gcion.com
127.0.0.1 hooqy.com
127.0.0.1 host207.ewtn.com
127.0.0.1 hostedaje14.thruport.com
127.0.0.1 hosting.adjug.com
127.0.0.1 hot-daily-deal.com
127.0.0.1 hot-product-hangout.com
127.0.0.1 hotgiftzone.com
127.0.0.1 hpad.www.infoseek.co.jp
127.0.0.1 html.centralmediaserver.com
127.0.0.1 htmlads.ru
127.0.0.1 htmlwww.youfck.com
127.0.0.1 http300.content.ru4.com
127.0.0.1 httpads.com
127.0.0.1 httpwwwadserver.com
127.0.0.1 hub.com.pl
127.0.0.1 huiwiw.hit.gemius.pl
127.0.0.1 huntingtonbank.tt.omtrdc.net
127.0.0.1 huomdgde.adocean.pl
127.0.0.1 hyperion.adtech.de
127.0.0.1 hyperion.adtech.fr
127.0.0.1 hyperion.adtech.us
127.0.0.1 i.blogads.com
127.0.0.1 i.casalemedia.com
127.0.0.1 i.hotkeys.com
127.0.0.1 i.interia.pl
127.0.0.1 i.laih.com
127.0.0.1 i.pcp001.com
127.0.0.1 i.qitrck.com
127.0.0.1 i.securecontactinfo.com
127.0.0.1 i.simpli.fi
127.0.0.1 i.total-media.net
127.0.0.1 i.trkjmp.com
127.0.0.1 iacas.adbureau.net
127.0.0.1 iad.anm.co.uk
127.0.0.1 ib.adnxs.com
127.0.0.1 icon.clickthru.net
127.0.0.1 id11938.luxup.ru
127.0.0.1 idearc.tt.omtrdc.net
127.0.0.1 idpix.media6degrees.com
127.0.0.1 ieee.adbureau.net
127.0.0.1 if.bbanner.it
127.0.0.1 ih2.gamecopyworld.com
127.0.0.1 ilinks.industrybrains.com
127.0.0.1 im.adtech.de
127.0.0.1 im.of.pl
127.0.0.1 im.xo.pl
127.0.0.1 image.click.livedoor.com
127.0.0.1 image.i1img.com
127.0.0.1 image.linkexchange.com
127.0.0.1 image2.pubmatic.com
127.0.0.1 imageads.canoe.ca
127.0.0.1 imagec08.247realmedia.com
127.0.0.1 imagec12.247realmedia.com
127.0.0.1 imagec14.247realmedia.com
127.0.0.1 imagecache2.allposters.com
127.0.0.1 images-cdn.azoogleads.com
127.0.0.1 images.ads.fairfax.com.au
127.0.0.1 images.blogads.com
127.0.0.1 images.bluetime.com
127.0.0.1 images.clickfinders.com
127.0.0.1 images.conduit-banners.com
127.0.0.1 images.cybereps.com
127.0.0.1 images.directtrack.com
127.0.0.1 images.emapadserver.com
127.0.0.1 images.jambocast.com
127.0.0.1 images.linkwithin.com
127.0.0.1 images.mbuyu.nl
127.0.0.1 images.netcomvad.com
127.0.0.1 images.newsx.cc
127.0.0.1 images.people2people.com
127.0.0.1 images.primaryads.com
127.0.0.1 images.sexlist.com
127.0.0.1 images.steamray.com
127.0.0.1 images.trafficmp.com
127.0.0.1 images2.laih.com
127.0.0.1 images3.linkwithin.com
127.0.0.1 imageserv.adtech.de
127.0.0.1 imageserv.adtech.fr
127.0.0.1 imageserv.adtech.us
127.0.0.1 imageserver1.thruport.com
127.0.0.1 img-a2.ak.imagevz.net
127.0.0.1 img-cdn.mediaplex.com
127.0.0.1 img.blogads.com
127.0.0.1 img.directtrack.com
127.0.0.1 img.layer-ads.de
127.0.0.1 img.sn00.net
127.0.0.1 img.soulmate.com
127.0.0.1 img.xnxx.com
127.0.0.1 img4.cdn.adjuggler.com
127.0.0.1 imgn.dt07.com
127.0.0.1 imgserv.adbutler.com
127.0.0.1 imp.partner2profit.com
127.0.0.1 impact.cossette-webpact.com
127.0.0.1 impbe.tradedoubler.com
127.0.0.1 imppl.tradedoubler.com
127.0.0.1 impressionaffiliate.com
127.0.0.1 impressionaffiliate.mobi
127.0.0.1 impressionlead.com
127.0.0.1 impressionperformance.biz
127.0.0.1 imserv001.adtech.de
127.0.0.1 imserv001.adtech.fr
127.0.0.1 imserv001.adtech.us
127.0.0.1 imserv002.adtech.de
127.0.0.1 imserv002.adtech.fr
127.0.0.1 imserv002.adtech.us
127.0.0.1 imserv003.adtech.de
127.0.0.1 imserv003.adtech.fr
127.0.0.1 imserv003.adtech.us
127.0.0.1 imserv004.adtech.de
127.0.0.1 imserv004.adtech.fr
127.0.0.1 imserv004.adtech.us
127.0.0.1 imserv005.adtech.de
127.0.0.1 imserv005.adtech.fr
127.0.0.1 imserv005.adtech.us
127.0.0.1 imserv006.adtech.de
127.0.0.1 imserv006.adtech.fr
127.0.0.1 imserv006.adtech.us
127.0.0.1 imserv00x.adtech.de
127.0.0.1 imserv00x.adtech.fr
127.0.0.1 imserv00x.adtech.us
127.0.0.1 imssl01.adtech.de
127.0.0.1 imssl01.adtech.fr
127.0.0.1 imssl01.adtech.us
127.0.0.1 in.adserver.yahoo.com
127.0.0.1 incentive-scene.com
127.0.0.1 incentivegateway.com
127.0.0.1 incentiverewardcenter.com
127.0.0.1 indexhu.adocean.pl
127.0.0.1 infinite-ads.com
127.0.0.1 inklineglobal.com
127.0.0.1 inl.adbureau.net
127.0.0.1 input.insights.gravity.com
127.0.0.1 ins-offer.com
127.0.0.1 insightxe.pittsburghlive.com
127.0.0.1 insightxe.vtsgonline.com
127.0.0.1 installer.zutrack.com
127.0.0.1 insurance-rewardpath.com
127.0.0.1 intela.com
127.0.0.1 intelliads.com
127.0.0.1 internet.billboard.cz
127.0.0.1 intnet-offer.com
127.0.0.1 intrack.pl
127.0.0.1 invitefashion.com
127.0.0.1 ipacc1.adtech.de
127.0.0.1 ipacc1.adtech.fr
127.0.0.1 ipacc1.adtech.us
127.0.0.1 ipad2free4u.com
127.0.0.1 ipdata.adtech.de
127.0.0.1 ipdata.adtech.fr
127.0.0.1 ipdata.adtech.us
127.0.0.1 iq001.adtech.de
127.0.0.1 iq001.adtech.fr
127.0.0.1 iq001.adtech.us
127.0.0.1 is.casalemedia.com
127.0.0.1 isg01.casalemedia.com
127.0.0.1 isg02.casalemedia.com
127.0.0.1 isg03.casalemedia.com
127.0.0.1 isg04.casalemedia.com
127.0.0.1 isg05.casalemedia.com
127.0.0.1 isg06.casalemedia.com
127.0.0.1 isg07.casalemedia.com
127.0.0.1 isg08.casalemedia.com
127.0.0.1 isg09.casalemedia.com
127.0.0.1 it.adserver.yahoo.com
127.0.0.1 itrackerpro.com
127.0.0.1 itsfree123.com
127.0.0.1 itxt.vibrantmedia.com
127.0.0.1 ivwbox.de
127.0.0.1 iwantmy-freelaptop.com
127.0.0.1 iwantmyfree-laptop.com
127.0.0.1 iwantmyfreecash.com
127.0.0.1 iwantmyfreelaptop.com
127.0.0.1 iwantmygiftcard.com
127.0.0.1 j.clickdensity.com
127.0.0.1 jambocast.com
127.0.0.1 jcarter.spinbox.net
127.0.0.1 jcrew.tt.omtrdc.net
127.0.0.1 jersey-offer.com
127.0.0.1 jgedads.cjt.net
127.0.0.1 jh.revolvermaps.com
127.0.0.1 jivox.com
127.0.0.1 jl29jd25sm24mc29.com
127.0.0.1 jlinks.industrybrains.com
127.0.0.1 jmn.jangonetwork.com
127.0.0.1 join1.winhundred.com
127.0.0.1 js.adlink.net
127.0.0.1 js.admngr.com
127.0.0.1 js.adscale.de
127.0.0.1 js.adserverpub.com
127.0.0.1 js.adsonar.com
127.0.0.1 js.himediads.com
127.0.0.1 js.hotkeys.com
127.0.0.1 js.selectornews.com
127.0.0.1 js.smi2.ru
127.0.0.1 js.tongji.linezing.com
127.0.0.1 js.zevents.com
127.0.0.1 js1.bloggerads.net
127.0.0.1 js77.neodatagroup.com
127.0.0.1 jsc.dt07.net
127.0.0.1 jsn.dt07.net
127.0.0.1 judo.salon.com
127.0.0.1 juggler.inetinteractive.com
127.0.0.1 justwebads.com
127.0.0.1 jxliu.com
127.0.0.1 k5ads.osdn.com
127.0.0.1 kaartenhuis.nl.site-id.nl
127.0.0.1 kansas.valueclick.com
127.0.0.1 katu.adbureau.net
127.0.0.1 kazaa.adserver.co.il
127.0.0.1 kermit.macnn.com
127.0.0.1 kestrel.ospreymedialp.com
127.0.0.1 keys.dmtracker.com
127.0.0.1 keywordblocks.com
127.0.0.1 keywords.adtlgc.com
127.0.0.1 kicker.ivwbox.de
127.0.0.1 kitaramarketplace.com
127.0.0.1 kitaramedia.com
127.0.0.1 kitaratrk.com
127.0.0.1 kithrup.matchlogic.com
127.0.0.1 klikk.linkpulse.com
127.0.0.1 klikmoney.net
127.0.0.1 kliksaya.com
127.0.0.1 klipads.dvlabs.com
127.0.0.1 klipmart.dvlabs.com
127.0.0.1 klipmart.forbes.com
127.0.0.1 kmdl101.com
127.0.0.1 knc.lv
127.0.0.1 knight.economist.com
127.0.0.1 kona.kontera.com
127.0.0.1 kona2.kontera.com
127.0.0.1 kona3.kontera.com
127.0.0.1 kona4.kontera.com
127.0.0.1 kona5.kontera.com
127.0.0.1 kona6.kontera.com
127.0.0.1 kona7.kontera.com
127.0.0.1 kona8.kontera.com
127.0.0.1 kontera.com
127.0.0.1 kreaffiliation.com
127.0.0.1 kropka.onet.pl
127.0.0.1 kuhdi.com
127.0.0.1 l.5min.com
127.0.0.1 l.linkpulse.com
127.0.0.1 l.yieldmanager.net
127.0.0.1 lanzar.publicidadweb.com
127.0.0.1 laptopreportcard.com
127.0.0.1 laptoprewards.com
127.0.0.1 laptoprewardsgroup.com
127.0.0.1 laptoprewardszone.com
127.0.0.1 larivieracasino.com
127.0.0.1 lasthr.info
127.0.0.1 lastmeasure.zoy.org
127.0.0.1 launch.adserver.yahoo.com
127.0.0.1 layer-ads.de
127.0.0.1 lb-adserver.ig.com.br
127.0.0.1 ld1.criteo.com
127.0.0.1 ld2.criteo.com
127.0.0.1 ldglob01.adtech.de
127.0.0.1 ldglob01.adtech.fr
127.0.0.1 ldglob01.adtech.us
127.0.0.1 ldglob02.adtech.de
127.0.0.1 ldglob02.adtech.fr
127.0.0.1 ldglob02.adtech.us
127.0.0.1 ldimage01.adtech.de
127.0.0.1 ldimage01.adtech.fr
127.0.0.1 ldimage01.adtech.us
127.0.0.1 ldimage02.adtech.de
127.0.0.1 ldimage02.adtech.fr
127.0.0.1 ldimage02.adtech.us
127.0.0.1 ldserv01.adtech.de
127.0.0.1 ldserv01.adtech.fr
127.0.0.1 ldserv01.adtech.us
127.0.0.1 ldserv02.adtech.de
127.0.0.1 ldserv02.adtech.fr
127.0.0.1 ldserv02.adtech.us
127.0.0.1 le1er.net
127.0.0.1 lead.program3.com
127.0.0.1 leadback.advertising.com
127.0.0.1 leader.linkexchange.com
127.0.0.1 leadsynaptic.go2jump.org
127.0.0.1 learning-offer.com
127.0.0.1 legal-rewardpath.com
127.0.0.1 leisure-offer.com
127.0.0.1 lg.brandreachsys.com
127.0.0.1 liberty.gedads.com
127.0.0.1 link2me.ru
127.0.0.1 link4ads.com
127.0.0.1 links.dot.tk
127.0.0.1 linktracker.angelfire.com
127.0.0.1 linuxpark.adtech.de
127.0.0.1 linuxpark.adtech.fr
127.0.0.1 linuxpark.adtech.us
127.0.0.1 liquidad.narrowcastmedia.com
127.0.0.1 live-cams-1.livejasmin.com
127.0.0.1 livingnet.adtech.de
127.0.0.1 ll.atdmt.com
127.0.0.1 lnads.osdn.com
127.0.0.1 load.exelator.com
127.0.0.1 load.focalex.com
127.0.0.1 loading321.com
127.0.0.1 loadm.exelator.com
127.0.0.1 local.promoisland.net
127.0.0.1 log.feedjit.com
127.0.0.1 log.olark.com
127.0.0.1 logc252.xiti.com
127.0.0.1 login.linkpulse.com
127.0.0.1 looksmartcollect.247realmedia.com
127.0.0.1 louisvil.app.ur.gcion.com
127.0.0.1 louisvil.ur.gcion.com
127.0.0.1 lp1.linkpulse.com
127.0.0.1 lp4.linkpulse.com
127.0.0.1 lstats.qip.ru
127.0.0.1 lt.andomedia.com
127.0.0.1 lt.angelfire.com
127.0.0.1 lucky-day-uk.com
127.0.0.1 luxup.ru
127.0.0.1 lw1.gamecopyworld.com
127.0.0.1 lw2.gamecopyworld.com
127.0.0.1 lycos.247realmedia.com
127.0.0.1 m.adbridge.de
127.0.0.1 m.fr.a2dfp.net
127.0.0.1 m.friendlyduck.com
127.0.0.1 m.tribalfusion.com
127.0.0.1 m1.emea.2mdn.net.edgesuite.net
127.0.0.1 m2.sexgarantie.nl
127.0.0.1 m3.2mdn.net
127.0.0.1 macaddictads.snv.futurenet.com
127.0.0.1 macads.net
127.0.0.1 mad2.brandreachsys.com
127.0.0.1 mads.aol.com
127.0.0.1 mads.cnet.com
127.0.0.1 mail.radar.imgsmail.ru
127.0.0.1 manage001.adtech.de
127.0.0.1 manage001.adtech.fr
127.0.0.1 manage001.adtech.us
127.0.0.1 manager.rovion.com
127.0.0.1 manuel.theonion.com
127.0.0.1 marketing-rewardpath.com
127.0.0.1 marketing.888.com
127.0.0.1 marriottinternationa.tt.omtrdc.net
127.0.0.1 mastertracks.be
127.0.0.1 matrix.mediavantage.de
127.0.0.1 maxads.ruralpress.com
127.0.0.1 maxadserver.corusradionetwork.com
127.0.0.1 maxbounty.com
127.0.0.1 maximumpcads.imaginemedia.com
127.0.0.1 maxmedia.sgaonline.com
127.0.0.1 maxserving.com
127.0.0.1 mb01.com
127.0.0.1 mbox2.offermatica.com
127.0.0.1 mbox9.offermatica.com
127.0.0.1 mds.centrport.net
127.0.0.1 media.888.com
127.0.0.1 media.adcentriconline.com
127.0.0.1 media.adrevolver.com
127.0.0.1 media.adrime.com
127.0.0.1 media.adshadow.net
127.0.0.1 media.b.lead.program3.com
127.0.0.1 media.bonnint.net
127.0.0.1 media.contextweb.com
127.0.0.1 media.elb-kind.de
127.0.0.1 media.espace-plus.net
127.0.0.1 media.fairlink.ru
127.0.0.1 media.funpic.de
127.0.0.1 media.markethealth.com
127.0.0.1 media.naked.com
127.0.0.1 media.nk-net.pl
127.0.0.1 media.ontarionorth.com
127.0.0.1 media.popuptraffic.com
127.0.0.1 media.trafficfactory.biz
127.0.0.1 media.trafficjunky.net
127.0.0.1 media.ventivmedia.com
127.0.0.1 media.viwii.net
127.0.0.1 media2.adshuffle.com
127.0.0.1 media2.legacy.com
127.0.0.1 media2.travelzoo.com
127.0.0.1 media2021.videostrip.com
127.0.0.1 media4021.videostrip.com #http://media4021.videostrip.com/dev8/0/000/449/0000449408.mp4
127.0.0.1 media5021.videostrip.com #http://media5021.videostrip.com/dev14/0/000/363/0000363146.mp4
127.0.0.1 media6.sitebrand.com
127.0.0.1 media6021.videostrip.com
127.0.0.1 mediacharger.com
127.0.0.1 mediafr.247realmedia.com
127.0.0.1 medialand.relax.ru
127.0.0.1 mediapst-images.adbureau.net
127.0.0.1 mediapst.adbureau.net
127.0.0.1 mediative.ca
127.0.0.1 mediative.com
127.0.0.1 mediauk.247realmedia.com
127.0.0.1 medical-offer.com
127.0.0.1 medical-rewardpath.com
127.0.0.1 medleyads.com
127.0.0.1 medrx.sensis.com.au
127.0.0.1 megapanel.gem.pl
127.0.0.1 mercury.bravenet.com
127.0.0.1 messagent.duvalguillaume.com
127.0.0.1 messagia.adcentric.proximi-t.com
127.0.0.1 meter-svc.nytimes.com
127.0.0.1 metrics.natmags.co.uk
127.0.0.1 metrics.sfr.fr
127.0.0.1 metrics.target.com
127.0.0.1 mf.sitescout.com
127.0.0.1 mg.dt00.net
127.0.0.1 mgid.com
127.0.0.1 mhlnk.com
127.0.0.1 mi.adinterax.com
127.0.0.1 microsof.wemfbox.ch
127.0.0.1 mightymagoo.com
127.0.0.1 mii-image.adjuggler.com
127.0.0.1 mini.videostrip.com
127.0.0.1 mirror.pointroll.com
127.0.0.1 mjx.ads.nwsource.com
127.0.0.1 mjxads.internet.com
127.0.0.1 mklik.gazeta.pl
127.0.0.1 mktg-offer.com
127.0.0.1 mlntracker.com
127.0.0.1 mm.admob.com
127.0.0.1 mm.chitika.net
127.0.0.1 mob.adwhirl.com
127.0.0.1 mobile.juicyads.com
127.0.0.1 mobileads.msn.com
127.0.0.1 mobularity.com
127.0.0.1 mochibot.com
127.0.0.1 mojofarm.mediaplex.com
127.0.0.1 moneyraid.com
127.0.0.1 monstersandcritics.advertserve.com
127.0.0.1 morefreecamsecrets.com
127.0.0.1 morevisits.info
127.0.0.1 motd.pinion.gg
127.0.0.1 movieads.imgs.sapo.pt
127.0.0.1 mp.tscapeplay.com
127.0.0.1 mp3playersource.com
127.0.0.1 msn-cdn.effectivemeasure.net
127.0.0.1 msn.allyes.com
127.0.0.1 msn.oewabox.at
127.0.0.1 msn.tns-cs.net
127.0.0.1 msn.uvwbox.de
127.0.0.1 msn.wrating.com
127.0.0.1 msnbe-hp.metriweb.be
127.0.0.1 mt58.mtree.com
127.0.0.1 mu-in-f167.1e100.net
127.0.0.1 multi.xnxx.com
127.0.0.1 mvonline.com
127.0.0.1 mx.adserver.yahoo.com
127.0.0.1 my-reward-channel.com
127.0.0.1 my-rewardsvault.com
127.0.0.1 my.blueadvertise.com
127.0.0.1 myao.adocean.pl
127.0.0.1 mycashback.co.uk
127.0.0.1 mycelloffer.com
127.0.0.1 mychoicerewards.com
127.0.0.1 myexclusiverewards.com
127.0.0.1 myfreedinner.com
127.0.0.1 myfreegifts.co.uk
127.0.0.1 myfreemp3player.com
127.0.0.1 mygiftcardcenter.com
127.0.0.1 mygiftresource.com
127.0.0.1 mygreatrewards.com
127.0.0.1 myoffertracking.com
127.0.0.1 myseostats.com
127.0.0.1 myusersonline.com
127.0.0.1 myyearbookdigital.checkm8.com
127.0.0.1 n4061ad.doubleclick.net
127.0.0.1 n4g.us.intellitxt.com
127.0.0.1 nationalissuepanel.com
127.0.0.1 nationalpost.adperfect.com
127.0.0.1 nationalsurveypanel.com
127.0.0.1 nb.netbreak.com.au
127.0.0.1 nbads.com
127.0.0.1 nbc.adbureau.net
127.0.0.1 nbimg.dt00.net
127.0.0.1 nctracking.com
127.0.0.1 nd1.gamecopyworld.com
127.0.0.1 nearbyad.com
127.0.0.1 needadvertising.com
127.0.0.1 netads.hotwired.com
127.0.0.1 netads.sohu.com
127.0.0.1 netadsrv.iworld.com
127.0.0.1 netcomm.spinbox.net
127.0.0.1 netpalnow.com
127.0.0.1 netshelter.adtrix.com
127.0.0.1 netspiderads2.indiatimes.com
127.0.0.1 netsponsors.com
127.0.0.1 network-ca.247realmedia.com
127.0.0.1 network.realmedia.com
127.0.0.1 network.realtechnetwork.net
127.0.0.1 networkads.net
127.0.0.1 netzmarkt.ivwbox.de
127.0.0.1 new-ads.eurogamer.net
127.0.0.1 new.smartcontext.pl
127.0.0.1 newads.cmpnet.com
127.0.0.1 newadserver.interfree.it
127.0.0.1 newbs.hutz.co.il
127.0.0.1 news6health.com
127.0.0.1 newssourceoftoday.com #security risk/fake news#
127.0.0.1 newt1.adultadworld.com
127.0.0.1 newt1.adultworld.com
127.0.0.1 ng3.ads.warnerbros.com
127.0.0.1 ngads.smartage.com
127.0.0.1 nitrous.exitfuel.com
127.0.0.1 nitrous.internetfuel.com
127.0.0.1 nivendas.net
127.0.0.1 nkcache.brandreachsys.com
127.0.0.1 nl.adserver.yahoo.com
127.0.0.1 no.adserver.yahoo.com
127.0.0.1 nospartenaires.com
127.0.0.1 nothing-but-value.com
127.0.0.1 novem.onet.pl
127.0.0.1 nrads.1host.co.il
127.0.0.1 nrkno.linkpulse.com
127.0.0.1 ns-vip1.hitbox.com
127.0.0.1 ns-vip2.hitbox.com
127.0.0.1 ns-vip3.hitbox.com
127.0.0.1 ns1.lalibco.com
127.0.0.1 ns1.primeinteractive.net
127.0.0.1 ns2.hitbox.com
127.0.0.1 ns2.lalibco.com
127.0.0.1 ns2.primeinteractive.net
127.0.0.1 nsads.hotwired.com
127.0.0.1 nsads.us.publicus.com
127.0.0.1 nsads4.us.publicus.com
127.0.0.1 nspmotion.com
127.0.0.1 ntbanner.digitalriver.com
127.0.0.1 ntv.ivwbox.de
127.0.0.1 nx-adv0005.247realmedia.com
127.0.0.1 nxs.kidcolez.cn
127.0.0.1 nxtscrn.adbureau.net
127.0.0.1 nysubwayoffer.com
127.0.0.1 nytadvertising.nytimes.com
127.0.0.1 o0.winfuture.de
127.0.0.1 oads.cracked.com
127.0.0.1 oamsrhads.us.publicus.com
127.0.0.1 oas-1.rmuk.co.uk
127.0.0.1 oas-eu.247realmedia.com
127.0.0.1 oas.dn.se
127.0.0.1 oas.heise.de
127.0.0.1 oasads.whitepages.com
127.0.0.1 oasc02.247realmedia.com
127.0.0.1 oasc02023.247realmedia.com
127.0.0.1 oasc03.247realmedia.com
127.0.0.1 oasc04.247.realmedia.com
127.0.0.1 oasc05.247realmedia.com
127.0.0.1 oasc05050.247realmedia.com
127.0.0.1 oasc16.247realmedia.com
127.0.0.1 oascenral.phoenixnewtimes.com
127.0.0.1 oascentral.videodome.com
127.0.0.1 oasis.411affiliates.ca
127.0.0.1 oasis.nysun.com
127.0.0.1 oasis.promon.cz
127.0.0.1 oasis.realbeer.com
127.0.0.1 oasis.zmh.zope.com
127.0.0.1 oasis.zmh.zope.net
127.0.0.1 oasis2.advfn.com
127.0.0.1 oasn03.247realmedia.com
127.0.0.1 oassis.zmh.zope.com
127.0.0.1 objects.abcvisiteurs.com
127.0.0.1 objects.designbloxlive.com
127.0.0.1 obozua.adocean.pl
127.0.0.1 obs.nnm2.ru
127.0.0.1 observer.advertserve.com
127.0.0.1 offers.impower.com
127.0.0.1 offerx.co.uk
127.0.0.1 oinadserve.com
127.0.0.1 old-darkroast.adknowledge.com
127.0.0.1 ometrics.warnerbros.com
127.0.0.1 online1.webcams.com
127.0.0.1 onlineads.magicvalley.com
127.0.0.1 onlinebestoffers.net
127.0.0.1 onocollect.247realmedia.com
127.0.0.1 onvis.ivwbox.de
127.0.0.1 open.4info.net
127.0.0.1 openad.infobel.com
127.0.0.1 openad.travelnow.com
127.0.0.1 openadext.tf1.fr
127.0.0.1 openads.dimcab.com
127.0.0.1 openads.friendfinder.com
127.0.0.1 openads.nightlifemagazine.ca
127.0.0.1 openads.smithmag.net
127.0.0.1 openads.zeads.com
127.0.0.1 opentable.tt.omtrdc.net
127.0.0.1 openx.adfactor.nl
127.0.0.1 openx.coolconcepts.nl
127.0.0.1 openx.shinyads.com
127.0.0.1 openx2.fotoflexer.com
127.0.0.1 openxxx.viragemedia.com
127.0.0.1 optimize.indieclick.com
127.0.0.1 optimized-by.rubiconproject.com
127.0.0.1 optimized.by.vitalads.net
127.0.0.1 optimzedby.rmxads.com
127.0.0.1 oracle.112.2o7.net
127.0.0.1 orange.weborama.fr
127.0.0.1 ordie.adbureau.net
127.0.0.1 origin.chron.com
127.0.0.1 out.popads.net
127.0.0.1 overflow.adsoftware.com
127.0.0.1 overlay.ringtonematcher.com
127.0.0.1 overstock.tt.omtrdc.net
127.0.0.1 ox-d.hbr.org
127.0.0.1 ox-d.hulkshare.com
127.0.0.1 ox-d.hypeads.org
127.0.0.1 ox-d.zenoviagroup.com
127.0.0.1 ox-i.zenoviagroup.com
127.0.0.1 ox.eurogamer.net
127.0.0.1 oz.valueclick.com
127.0.0.1 oz.valueclick.ne.jp
127.0.0.1 ozonemedia.adbureau.net
127.0.0.1 p.ic.tynt.com
127.0.0.1 p.profistats.net
127.0.0.1 p.publico.es
127.0.0.1 p0rnuha.com
127.0.0.1 p1.adhitzads.com
127.0.0.1 pagead.googlesyndication.com
127.0.0.1 pagead1.googlesyndication.com
127.0.0.1 pagead2.googlesyndication.com
127.0.0.1 pagead3.googlesyndication.com
127.0.0.1 pages.etology.com
127.0.0.1 paime.com
127.0.0.1 paperg.com
127.0.0.1 partner.ah-ha.com
127.0.0.1 partner.ceneo.pl
127.0.0.1 partner.magna.ru
127.0.0.1 partner.pobieraczek.pl
127.0.0.1 partner.wapacz.pl
127.0.0.1 partner.wapster.pl
127.0.0.1 partner01.oingo.com
127.0.0.1 partner02.oingo.com
127.0.0.1 partner03.oingo.com
127.0.0.1 partners.sprintrade.com
127.0.0.1 partners.webmasterplan.com
127.0.0.1 pathforpoints.com
127.0.0.1 paulsnetwork.com
127.0.0.1 pb.tynt.com
127.0.0.1 pbid.pro-market.net
127.0.0.1 pei-ads.playboy.com
127.0.0.1 people-choice-sites.com
127.0.0.1 personalcare-offer.com
127.0.0.1 personalcashbailout.com
127.0.0.1 ph-ad01.focalink.com
127.0.0.1 ph-ad02.focalink.com
127.0.0.1 ph-ad03.focalink.com
127.0.0.1 ph-ad04.focalink.com
127.0.0.1 ph-ad05.focalink.com
127.0.0.1 ph-ad06.focalink.com
127.0.0.1 ph-ad07.focalink.com
127.0.0.1 ph-ad08.focalink.com
127.0.0.1 ph-ad09.focalink.com
127.0.0.1 ph-ad10.focalink.com
127.0.0.1 ph-ad11.focalink.com
127.0.0.1 ph-ad12.focalink.com
127.0.0.1 ph-ad13.focalink.com
127.0.0.1 ph-ad14.focalink.com
127.0.0.1 ph-ad15.focalink.com
127.0.0.1 ph-ad16.focalink.com
127.0.0.1 ph-ad17.focalink.com
127.0.0.1 ph-ad18.focalink.com
127.0.0.1 ph-ad19.focalink.com
127.0.0.1 ph-ad20.focalink.com
127.0.0.1 ph-ad21.focalink.com
127.0.0.1 ph-cdn.effectivemeasure.net
127.0.0.1 phoenixads.co.in
127.0.0.1 photobucket.adnxs.com
127.0.0.1 photos.daily-deals.analoganalytics.com
127.0.0.1 photos.pop6.com
127.0.0.1 photos0.pop6.com
127.0.0.1 photos1.pop6.com
127.0.0.1 photos2.pop6.com
127.0.0.1 photos3.pop6.com
127.0.0.1 photos4.pop6.com
127.0.0.1 photos5.pop6.com
127.0.0.1 photos6.pop6.com
127.0.0.1 photos7.pop6.com
127.0.0.1 photos8.pop6.com
127.0.0.1 php.fark.com
127.0.0.1 phpads.astalavista.us
127.0.0.1 phpads.cnpapers.com
127.0.0.1 phpads.flipcorp.com
127.0.0.1 phpads.foundrymusic.com
127.0.0.1 phpads.i-merge.net
127.0.0.1 phpads.macbidouille.com
127.0.0.1 phpadsnew.gamefolk.de
127.0.0.1 phpadsnew.wn.com
127.0.0.1 pick-savings.com
127.0.0.1 pink.habralab.ru
127.0.0.1 pix01.revsci.net
127.0.0.1 pix521.adtech.de
127.0.0.1 pix521.adtech.fr
127.0.0.1 pix521.adtech.us
127.0.0.1 pix522.adtech.de
127.0.0.1 pix522.adtech.fr
127.0.0.1 pix522.adtech.us
127.0.0.1 pixel.everesttech.net
127.0.0.1 pixel.quantserve.com
127.0.0.1 pixel.sitescout.com
127.0.0.1 pl.bbelements.com
127.0.0.1 plasmatv4free.com
127.0.0.1 plasmatvreward.com
127.0.0.1 playlink.pl
127.0.0.1 playtime.tubemogul.com
127.0.0.1 pmstrk.mercadolivre.com.br
127.0.0.1 pntm-images.adbureau.net
127.0.0.1 pntm.adbureau.net
127.0.0.1 pol.bbelements.com
127.0.0.1 politicalopinionsurvey.com
127.0.0.1 pool.pebblemedia.adhese.com
127.0.0.1 popadscdn.net
127.0.0.1 popclick.net
127.0.0.1 poponclick.com
127.0.0.1 popunder.adsrevenue.net
127.0.0.1 popunder.paypopup.com
127.0.0.1 popup.matchmaker.com
127.0.0.1 popupclick.ru
127.0.0.1 popupdomination.com
127.0.0.1 popups.ad-logics.com
127.0.0.1 popups.infostart.com
127.0.0.1 post.rmbn.ru
127.0.0.1 postmasterdirect.com
127.0.0.1 pp.free.fr
127.0.0.1 premium-reward-club.com
127.0.0.1 premium.ascensionweb.com
127.0.0.1 premiumholidayoffers.com
127.0.0.1 premiumproductsonline.com
127.0.0.1 prexyone.appspot.com
127.0.0.1 primetime.ad.primetime.net
127.0.0.1 prizes.co.uk
127.0.0.1 productopinionpanel.com
127.0.0.1 productresearchpanel.com
127.0.0.1 producttestpanel.com
127.0.0.1 profile.uproxx.com
127.0.0.1 promo.awempire.com
127.0.0.1 promo.easy-dating.org
127.0.0.1 promos.fling.com
127.0.0.1 promote-bz.net
127.0.0.1 promotion.partnercash.com
127.0.0.1 proximityads.flipcorp.com
127.0.0.1 proxy.blogads.com
127.0.0.1 ptrads.mp3.com
127.0.0.1 pub.sapo.pt
127.0.0.1 pubdirecte.com
127.0.0.1 pubimgs.sapo.pt
127.0.0.1 publiads.com
127.0.0.1 publicidades.redtotalonline.com
127.0.0.1 publicis.adcentriconline.com
127.0.0.1 publish.bonzaii.no
127.0.0.1 publishers.adscholar.com
127.0.0.1 publishers.bidtraffic.com
127.0.0.1 publishers.brokertraffic.com
127.0.0.1 publishing.kalooga.com
127.0.0.1 pubshop.img.uol.com.br
127.0.0.1 purgecolon.net
127.0.0.1 q.azcentral.com
127.0.0.1 q.b.h.cltomedia.info
127.0.0.1 qip.magna.ru
127.0.0.1 qitrck.com
127.0.0.1 quickbrowsersearch.com
127.0.0.1 r.ace.advertising.com
127.0.0.1 r.admob.com
127.0.0.1 r.chitika.net
127.0.0.1 r.reklama.biz
127.0.0.1 r.turn.com
127.0.0.1 r1-ads.ace.advertising.com
127.0.0.1 rad.msn.com
127.0.0.1 radaronline.advertserve.com
127.0.0.1 rads.stackoverflow.com
127.0.0.1 ravel-rewardpath.com
127.0.0.1 rb.burstway.com
127.0.0.1 rb.newsru.com
127.0.0.1 rbqip.pochta.ru
127.0.0.1 rc.asci.freenet.de
127.0.0.1 rc.bt.ilsemedia.nl
127.0.0.1 rc.hotkeys.com
127.0.0.1 rc.rlcdn.com
127.0.0.1 rc.wl.webads.nl
127.0.0.1 rccl.bridgetrack.com
127.0.0.1 rcdna.gwallet.com
127.0.0.1 rcm-images.amazon.com
127.0.0.1 rcm-it.amazon.it
127.0.0.1 re.kontera.com
127.0.0.1 realads.realmedia.com
127.0.0.1 realgfsbucks.com
127.0.0.1 realmedia-a800.d4p.net    # Scientific American
127.0.0.1 realmedia.advance.net
127.0.0.1 recreation-leisure-rewardpath.com
127.0.0.1 red.as-eu.falkag.net
127.0.0.1 red.as-us.falkag.net
127.0.0.1 red01.as-eu.falkag.net
127.0.0.1 red01.as-us.falkag.net
127.0.0.1 red02.as-eu.falkag.net
127.0.0.1 red02.as-us.falkag.net
127.0.0.1 red03.as-eu.falkag.net
127.0.0.1 red03.as-us.falkag.net
127.0.0.1 red04.as-eu.falkag.net
127.0.0.1 red04.as-us.falkag.net
127.0.0.1 redherring.ngadcenter.net
127.0.0.1 redirect.click2net.com
127.0.0.1 redirect.hotkeys.com
127.0.0.1 reduxads.valuead.com
127.0.0.1 reg.coolsavings.com
127.0.0.1 regflow.com
127.0.0.1 regie.espace-plus.net
127.0.0.1 regio.adlink.de
127.0.0.1 rek.www.wp.pl
127.0.0.1 reklama.onet.pl
127.0.0.1 reklamy.sfd.pl
127.0.0.1 relestar.com
127.0.0.1 remotead.cnet.com
127.0.0.1 report02.adtech.de
127.0.0.1 report02.adtech.fr
127.0.0.1 report02.adtech.us
127.0.0.1 reporter.adtech.de
127.0.0.1 reporter.adtech.fr
127.0.0.1 reporter.adtech.us
127.0.0.1 reporter001.adtech.de
127.0.0.1 reporter001.adtech.fr
127.0.0.1 reporter001.adtech.us
127.0.0.1 reportimage.adtech.de
127.0.0.1 reportimage.adtech.fr
127.0.0.1 reportimage.adtech.us
127.0.0.1 resolvingserver.com
127.0.0.1 resources.infolinks.com
127.0.0.1 restaurantcom.tt.omtrdc.net
127.0.0.1 reverso.refr.adgtw.orangeads.fr
127.0.0.1 revsci.net
127.0.0.1 rewardblvd.com
127.0.0.1 rewardhotspot.com
127.0.0.1 rewardsflow.com
127.0.0.1 rh.revolvermaps.com
127.0.0.1 rhads.sv.publicus.com
127.0.0.1 richmedia.yimg.com
127.0.0.1 ridepush.com
127.0.0.1 ringtonepartner.com
127.0.0.1 rmbn.ru
127.0.0.1 rmedia.boston.com
127.0.0.1 rmm1u.checkm8.com
127.0.0.1 rms.admeta.com
127.0.0.1 ro.bbelements.com
127.0.0.1 romepartners.com
127.0.0.1 roosevelt.gjbig.com
127.0.0.1 rosettastone.tt.omtrdc.net
127.0.0.1 rotabanner100.utro.ru
127.0.0.1 rotabanner468.utro.ru
127.0.0.1 rotate.infowars.com
127.0.0.1 rotator.adjuggler.com
127.0.0.1 rotator.juggler.inetinteractive.com
127.0.0.1 rotobanner468.utro.ru
127.0.0.1 rovion.com
127.0.0.1 rp.hit.gemius.pl
127.0.0.1 rpc.trafficfactory.biz
127.0.0.1 rscounter10.com
127.0.0.1 rsense-ad.realclick.co.kr
127.0.0.1 rss.buysellads.com
127.0.0.1 rt2.infolinks.com
127.0.0.1 rt3.infolinks.com
127.0.0.1 rtb.pclick.yahoo.com
127.0.0.1 rtb.tubemogul.com
127.0.0.1 rtr.innovid.com
127.0.0.1 rts.sparkstudios.com
127.0.0.1 ru.bbelements.com
127.0.0.1 russ-shalavy.ru
127.0.0.1 rv.adcpx.v1.de.eusem.adaos-ads.net
127.0.0.1 rya.rockyou.com
127.0.0.1 s.amazon-adsystem.com
127.0.0.1 s.as-us.falkag.net
127.0.0.1 s.atemda.com
127.0.0.1 s.boom.ro
127.0.0.1 s.clicktale.net
127.0.0.1 s.di.com.pl
127.0.0.1 s.innovid.com
127.0.0.1 s.media-imdb.com
127.0.0.1 s.megaclick.com
127.0.0.1 s.moatads.com
127.0.0.1 s.skimresources.com
127.0.0.1 s.tcimg.com
127.0.0.1 s0b.bluestreak.com
127.0.0.1 s1.buysellads.com
127.0.0.1 s1.cz.adocean.pl
127.0.0.1 s1.gratkapl.adocean.pl
127.0.0.1 s2.buysellads.com
127.0.0.1 s2.youtube.com
127.0.0.1 s3.buysellads.com
127.0.0.1 s5.addthis.com
127.0.0.1 sad.sharethis.com
127.0.0.1 safe.hyperpaysys.com
127.0.0.1 safenyplanet.in
127.0.0.1 salesforcecom.tt.omtrdc.net
127.0.0.1 sat-city-ads.com
127.0.0.1 saturn.tiser.com.au
127.0.0.1 save-plan.com
127.0.0.1 savings-specials.com
127.0.0.1 savings-time.com
127.0.0.1 schoorsteen.geenstijl.nl
127.0.0.1 schumacher.adtech.de
127.0.0.1 schumacher.adtech.fr
127.0.0.1 schumacher.adtech.us
127.0.0.1 schwab.tt.omtrdc.net
127.0.0.1 scoremygift.com
127.0.0.1 scr.kliksaya.com
127.0.0.1 screen-mates.com
127.0.0.1 script.banstex.com
127.0.0.1 script.crsspxl.com
127.0.0.1 scripts.verticalacuity.com
127.0.0.1 se.adserver.yahoo.com
127.0.0.1 search.addthis.com
127.0.0.1 search.freeonline.com
127.0.0.1 search.keywordblocks.com
127.0.0.1 search.netseer.com
127.0.0.1 searchportal.information.com
127.0.0.1 searchwe.com
127.0.0.1 seasonalsamplerspecials.com
127.0.0.1 sec.hit.gemius.pl
127.0.0.1 secimage.adtech.de
127.0.0.1 secimage.adtech.fr
127.0.0.1 secimage.adtech.us
127.0.0.1 secserv.adtech.de
127.0.0.1 secserv.adtech.fr
127.0.0.1 secserv.adtech.us
127.0.0.1 secure.ace-tag.advertising.com
127.0.0.1 secure.addthis.com
127.0.0.1 secure.bidvertiserr.com
127.0.0.1 secure.eloqua.com
127.0.0.1 secure.gaug.es
127.0.0.1 secure.webconnect.net
127.0.0.1 secureads.ft.com
127.0.0.1 securecontactinfo.com
127.0.0.1 securerunner.com
127.0.0.1 seduction-zone.com
127.0.0.1 sel.as-eu.falkag.net
127.0.0.1 sel.as-us.falkag.net
127.0.0.1 select001.adtech.de
127.0.0.1 select001.adtech.fr
127.0.0.1 select001.adtech.us
127.0.0.1 select002.adtech.de
127.0.0.1 select002.adtech.fr
127.0.0.1 select002.adtech.us
127.0.0.1 select003.adtech.de
127.0.0.1 select003.adtech.fr
127.0.0.1 select003.adtech.us
127.0.0.1 select004.adtech.de
127.0.0.1 select004.adtech.fr
127.0.0.1 select004.adtech.us
127.0.0.1 sergarius.popunder.ru
127.0.0.1 serv.ad-rotator.com
127.0.0.1 serv.adspeed.com
127.0.0.1 serv2.ad-rotator.com
127.0.0.1 servads.aip.org
127.0.0.1 serve.prestigecasino.com
127.0.0.1 servedby.adcombination.com
127.0.0.1 servedby.advertising.com
127.0.0.1 servedby.flashtalking.com
127.0.0.1 servedby.netshelter.net
127.0.0.1 servedby.precisionclick.com
127.0.0.1 servedbyadbutler.com
127.0.0.1 server-ssl.yieldmanaged.com
127.0.0.1 server.as5000.com
127.0.0.1 server.bittads.com
127.0.0.1 server.cpmstar.com
127.0.0.1 server.popads.net
127.0.0.1 server01.popupmoney.com
127.0.0.1 server2.as5000.com
127.0.0.1 server2.mediajmp.com
127.0.0.1 server3.yieldmanaged.com
127.0.0.1 service.adtech.de
127.0.0.1 service.adtech.fr
127.0.0.1 service.adtech.us
127.0.0.1 service001.adtech.de
127.0.0.1 service001.adtech.fr
127.0.0.1 service001.adtech.us
127.0.0.1 service002.adtech.de
127.0.0.1 service002.adtech.fr
127.0.0.1 service002.adtech.us
127.0.0.1 service003.adtech.de
127.0.0.1 service003.adtech.fr
127.0.0.1 service003.adtech.us
127.0.0.1 service004.adtech.fr
127.0.0.1 service004.adtech.us
127.0.0.1 service00x.adtech.de
127.0.0.1 service00x.adtech.fr
127.0.0.1 service00x.adtech.us
127.0.0.1 services.adtech.de
127.0.0.1 services.adtech.fr
127.0.0.1 services.adtech.us
127.0.0.1 services1.adtech.de
127.0.0.1 services1.adtech.fr
127.0.0.1 services1.adtech.us
127.0.0.1 sexpartnerx.com
127.0.0.1 sexsponsors.com
127.0.0.1 sexzavod.com
127.0.0.1 sfads.osdn.com
127.0.0.1 sg.adserver.yahoo.com
127.0.0.1 sgs001.adtech.de
127.0.0.1 sgs001.adtech.fr
127.0.0.1 sgs001.adtech.us
127.0.0.1 sh4sure-images.adbureau.net
127.0.0.1 share-server.com
127.0.0.1 shareasale.com
127.0.0.1 sharebar.addthiscdn.com
127.0.0.1 shc-rebates.com
127.0.0.1 shinystat.shiny.it
127.0.0.1 shopperpromotions.com
127.0.0.1 shopping-offer.com
127.0.0.1 shoppingsiterewards.com
127.0.0.1 shops-malls-rewardpath.com
127.0.0.1 shoptosaveenergy.com
127.0.0.1 showads1000.pubmatic.com
127.0.0.1 showadsak.pubmatic.com
127.0.0.1 sifomedia.citypaketet.se
127.0.0.1 signup.advance.net
127.0.0.1 simg.zedo.com
127.0.0.1 simpleads.net
127.0.0.1 simpli.fi
127.0.0.1 sixapart.adbureau.net
127.0.0.1 sizzle-savings.com
127.0.0.1 skgde.adocean.pl
127.0.0.1 skill.skilljam.com
127.0.0.1 smart-scripts.com
127.0.0.1 smart.besonders.ru
127.0.0.1 smartadserver
127.0.0.1 smartadserver.com
127.0.0.1 smartcontext.pl
127.0.0.1 smartinit.webads.nl
127.0.0.1 smile.modchipstore.com
127.0.0.1 smm.sitescout.com
127.0.0.1 smokersopinionpoll.com
127.0.0.1 smsmovies.net
127.0.0.1 sn.baventures.com
127.0.0.1 snaps.vidiemi.com
127.0.0.1 snip.answers.com
127.0.0.1 snipjs.answcdn.com
127.0.0.1 sochr.com
127.0.0.1 social.bidsystem.com
127.0.0.1 softlinkers.popunder.ru
127.0.0.1 sokrates.adtech.de
127.0.0.1 sokrates.adtech.fr
127.0.0.1 sokrates.adtech.us
127.0.0.1 sol-images.adbureau.net
127.0.0.1 sol.adbureau.net
127.0.0.1 solitairetime.com
127.0.0.1 solution.weborama.fr
127.0.0.1 somethingawful.crwdcntrl.net
127.0.0.1 sonycomputerentertai.tt.omtrdc.net
127.0.0.1 soongu.info
127.0.0.1 spanids.dictionary.com
127.0.0.1 spanids.thesaurus.com
127.0.0.1 spc.cekfmeoejdbfcfichgbfcgjf.vast2as3.glammedia-pubnet.northamerica.telemetryverification.net
127.0.0.1 spe.atdmt.com
127.0.0.1 specialgiftrewards.com
127.0.0.1 specialoffers.aol.com
127.0.0.1 specialonlinegifts.com
127.0.0.1 specials-rewardpath.com
127.0.0.1 speed.pointroll.com # Microsoft
127.0.0.1 speedboink.com
127.0.0.1 speedclicks.ero-advertising.com
127.0.0.1 spiegel.ivwbox.de
127.0.0.1 spin.spinbox.net
127.0.0.1 spinbox.com
127.0.0.1 spinbox.consumerreview.com
127.0.0.1 spinbox.freedom.com
127.0.0.1 spinbox.macworld.com
127.0.0.1 spinbox.techtracker.com
127.0.0.1 sponsor1.com
127.0.0.1 sponsors.behance.com
127.0.0.1 sponsors.ezgreen.com
127.0.0.1 sponsorships.net
127.0.0.1 sports-bonuspath.com
127.0.0.1 sports-fitness-rewardpath.com
127.0.0.1 sports-offer.com
127.0.0.1 sports-offer.net
127.0.0.1 sports-premiumblvd.com
127.0.0.1 sq2trk2.com
127.0.0.1 srs.targetpoint.com
127.0.0.1 ssads.osdn.com
127.0.0.1 sso.canada.com
127.0.0.1 st.blogads.com
127.0.0.1 st.valueclick.com
127.0.0.1 staging.snip.answers.com
127.0.0.1 stampen.adtlgc.com
127.0.0.1 stampen.linkpulse.com
127.0.0.1 stampscom.tt.omtrdc.net
127.0.0.1 stanzapub.advertserve.com
127.0.0.1 star-advertising.com
127.0.0.1 stat.blogads.com
127.0.0.1 stat.dealtime.com
127.0.0.1 stat.ebuzzing.com
127.0.0.1 static.2mdn.net
127.0.0.1 static.admaximize.com
127.0.0.1 static.adsonar.com
127.0.0.1 static.adtaily.pl
127.0.0.1 static.adzerk.net
127.0.0.1 static.aff-landing-tmp.foxtab.com
127.0.0.1 static.clicktorrent.info
127.0.0.1 static.creatives.livejasmin.com
127.0.0.1 static.doubleclick.net
127.0.0.1 static.everyone.net
127.0.0.1 static.fastpic.ru
127.0.0.1 static.firehunt.com
127.0.0.1 static.fmpub.net
127.0.0.1 static.freenet.de
127.0.0.1 static.groupy.co.nz
127.0.0.1 static.hitfarm.com
127.0.0.1 static.ifa.camads.net
127.0.0.1 static.plista.com
127.0.0.1 static.pulse360.com
127.0.0.1 static.scanscout.com
127.0.0.1 static.vpptechnologies.com
127.0.0.1 static.way2traffic.com
127.0.0.1 static1.influads.com
127.0.0.1 staticads.btopenworld.com
127.0.0.1 staticb.mydirtyhobby.com
127.0.0.1 statistik-gallup.dk
127.0.0.1 stats.askmoses.com
127.0.0.1 stats.buzzparadise.com
127.0.0.1 stats.jtvnw.net
127.0.0.1 stats.shopify.com
127.0.0.1 stats2.dooyoo.com
127.0.0.1 status.addthis.com
127.0.0.1 stocker.bonnint.net
127.0.0.1 storage.softure.com
127.0.0.1 storage.trafic.ro
127.0.0.1 streamate.com
127.0.0.1 stts.rbc.ru
127.0.0.1 su.addthis.com
127.0.0.1 subtracts.userplane.com
127.0.0.1 sudokuwhiz.com
127.0.0.1 sunmaker.com
127.0.0.1 superbrewards.com
127.0.0.1 support.sweepstakes.com
127.0.0.1 supremeadsonline.com
127.0.0.1 suresafe1.adsovo.com
127.0.0.1 surplus-suppliers.com
127.0.0.1 survey.112.2o7.net
127.0.0.1 surveycentral.directinsure.info
127.0.0.1 surveygizmo.com
127.0.0.1 surveymonkeycom.tt.omtrdc.net
127.0.0.1 surveypass.com
127.0.0.1 susi.adtech.fr
127.0.0.1 susi.adtech.us
127.0.0.1 svd.adtlgc.com
127.0.0.1 svd2.adtlgc.com
127.0.0.1 sview.avenuea.com
127.0.0.1 sweetsforfree.com
127.0.0.1 symbiosting.com
127.0.0.1 syn.verticalacuity.com
127.0.0.1 synad.nuffnang.com.sg
127.0.0.1 synad2.nuffnang.com.cn
127.0.0.1 sync.mathtag.com
127.0.0.1 syndicated.mondominishows.com
127.0.0.1 syndication.exoclick.com
127.0.0.1 sysadmin.map24.com
127.0.0.1 t-ads.adap.tv
127.0.0.1 t.cpmadvisors.com
127.0.0.1 t1.adserver.com
127.0.0.1 t4.liverail.com
127.0.0.1 tag.admeld.com
127.0.0.1 tag.contextweb.com
127.0.0.1 tag.regieci.com
127.0.0.1 tag.webcompteur.com
127.0.0.1 tag.yieldoptimizer.com
127.0.0.1 tag1.webabacus.com
127.0.0.1 tags.bluekai.com
127.0.0.1 tags.hypeads.org
127.0.0.1 taloussanomat.linkpulse.com
127.0.0.1 tap2-cdn.rubiconproject.com
127.0.0.1 tbtrack.zutrack.com
127.0.0.1 tcimg.com
127.0.0.1 tdameritrade.tt.omtrdc.net
127.0.0.1 tdc.advertorials.dk
127.0.0.1 tdkads.ads.dk
127.0.0.1 te.kontera.com
127.0.0.1 techreview-images.adbureau.net
127.0.0.1 techreview.adbureau.net
127.0.0.1 teeser.ru
127.0.0.1 tel.geenstijl.nl
127.0.0.1 text-link-ads-inventory.com
127.0.0.1 text-link-ads.com
127.0.0.1 text-link-ads.ientry.com
127.0.0.1 textad.traficdublu.ro
127.0.0.1 textads.madisonavenue.com
127.0.0.1 textsrv.com
127.0.0.1 tf.nexac.com
127.0.0.1 tgpmanager.com
127.0.0.1 the-path-gateway.com
127.0.0.1 the-smart-stop.com
127.0.0.1 theuploadbusiness.com
127.0.0.1 theuseful.com
127.0.0.1 theuseful.net
127.0.0.1 thinknyc.eu-adcenter.net
127.0.0.1 thinktarget.com
127.0.0.1 thinlaptoprewards.com
127.0.0.1 this.content.served.by.adshuffle.com
127.0.0.1 thoughtfully-free.com
127.0.0.1 thruport.com
127.0.0.1 tmp3.nexac.com
127.0.0.1 tmsads.tribune.com
127.0.0.1 tmx.technoratimedia.com
127.0.0.1 tn.adserve.com
127.0.0.1 toads.osdn.com
127.0.0.1 tons-to-see.com
127.0.0.1 toolbar.adperium.com
127.0.0.1 top.list.ru
127.0.0.1 top100-images.rambler.ru
127.0.0.1 top1site.3host.com
127.0.0.1 top5.mail.ru
127.0.0.1 topbrandrewards.com
127.0.0.1 topconsumergifts.com
127.0.0.1 topdemaroc.com
127.0.0.1 topica.advertserve.com
127.0.0.1 toplist.throughput.de
127.0.0.1 topmarketcenter.com
127.0.0.1 touche.adcentric.proximi-t.com
127.0.0.1 tower.adexpedia.com
127.0.0.1 toy-offer.com
127.0.0.1 toy-offer.net
127.0.0.1 tpads.ovguide.com
127.0.0.1 tpc.googlesyndication.com
127.0.0.1 tps30.doubleverify.com
127.0.0.1 tps31.doubleverify.com
127.0.0.1 tr.wl.webads.nl
127.0.0.1 track-apmebf.cj.akadns.net
127.0.0.1 track.bigbrandpromotions.com
127.0.0.1 track.e7r.com.br
127.0.0.1 track.omgpl.com
127.0.0.1 track.the-members-section.com
127.0.0.1 track.vscash.com
127.0.0.1 trackadvertising.net
127.0.0.1 trackers.1st-affiliation.fr
127.0.0.1 tracking.craktraffic.com
127.0.0.1 tracking.edvisors.com
127.0.0.1 tracking.eurowebaffiliates.com
127.0.0.1 tracking.joker.com
127.0.0.1 tracking.keywordmax.com
127.0.0.1 tracking.veoxa.com
127.0.0.1 tradearabia.advertserve.com
127.0.0.1 trafficbee.com
127.0.0.1 trafficrevenue.net
127.0.0.1 traffictraders.com
127.0.0.1 traffprofit.com
127.0.0.1 trafsearchonline.com
127.0.0.1 traktum.com
127.0.0.1 travel-leisure-bonuspath.com
127.0.0.1 travel-leisure-premiumblvd.com
127.0.0.1 traveller-offer.com
127.0.0.1 traveller-offer.net
127.0.0.1 travelncs.com
127.0.0.1 trekmedia.net
127.0.0.1 trendnews.com
127.0.0.1 trk.alskeip.com
127.0.0.1 trk.etrigue.com
127.0.0.1 trk.yadomedia.com
127.0.0.1 trustsitesite.com
127.0.0.1 trvlnet-images.adbureau.net
127.0.0.1 trvlnet.adbureau.net
127.0.0.1 tsms-ad.tsms.com
127.0.0.1 tste.ivillage.com
127.0.0.1 tste.mcclatchyinteractive.com
127.0.0.1 tste.startribune.com
127.0.0.1 ttarget.adbureau.net
127.0.0.1 ttuk.offers4u.mobi
127.0.0.1 turnerapac.d1.sc.omtrdc.net
127.0.0.1 tv2no.linkpulse.com
127.0.0.1 tvshowsnow.tvmax.hop.clickbank.net
127.0.0.1 tw.adserver.yahoo.com
127.0.0.1 twnads.weather.ca # Canadian Weather Network
127.0.0.1 u-ads.adap.tv
127.0.0.1 u.openx.net
127.0.0.1 uac.advertising.com
127.0.0.1 uav.tidaltv.com
127.0.0.1 uc.csc.adserver.yahoo.com
127.0.0.1 uedata.amazon.com
127.0.0.1 uf2.svrni.ca
127.0.0.1 ugo.eu-adcenter.net
127.0.0.1 ui.ppjol.com
127.0.0.1 uk.adserver.yahoo.com
127.0.0.1 uleadstrk.com
127.0.0.1 ultimatefashiongifts.com
127.0.0.1 ultrabestportal.com
127.0.0.1 um.simpli.fi
127.0.0.1 undertonenetworks.com
127.0.0.1 uole.ad.uol.com.br
127.0.0.1 upload.adtech.de
127.0.0.1 upload.adtech.fr
127.0.0.1 upload.adtech.us
127.0.0.1 uproar.com
127.0.0.1 uproar.fortunecity.com
127.0.0.1 upsellit.com
127.0.0.1 us-choicevalue.com
127.0.0.1 us-topsites.com
127.0.0.1 us.adserver.yahoo.com
127.0.0.1 usads.vibrantmedia.com
127.0.0.1 usatoday.app.ur.gcion.com
127.0.0.1 usatravel-specials.com
127.0.0.1 usatravel-specials.net
127.0.0.1 usemax.de
127.0.0.1 ut.addthis.com
127.0.0.1 utils.media-general.com
127.0.0.1 utils.mediageneral.com
127.0.0.1 v.fwmrm.net
127.0.0.1 vad.adbasket.net
127.0.0.1 vads.adbrite.com
127.0.0.1 van.ads.link4ads.com
127.0.0.1 vast.bp3845260.btrll.com
127.0.0.1 vast.bp3846806.btrll.com
127.0.0.1 vast.bp3846885.btrll.com
127.0.0.1 vast.tubemogul.com
127.0.0.1 vclick.adbrite.com
127.0.0.1 ve.tscapeplay.com
127.0.0.1 venus.goclick.com
127.0.0.1 vibrantmedia.com
127.0.0.1 video-game-rewards-central.com
127.0.0.1 videocop.com
127.0.0.1 videoegg.adbureau.net
127.0.0.1 videogamerewardscentral.com
127.0.0.1 videos.fleshlight.com
127.0.0.1 videos.video-loader.com
127.0.0.1 videoslots.888.com
127.0.0.1 view.atdmt.com    #This may interfere with downloading from Microsoft, MSDN and TechNet websites.
127.0.0.1 view.avenuea.com
127.0.0.1 view.binlayer.com
127.0.0.1 view.iballs.a1.avenuea.com
127.0.0.1 view.jamba.de
127.0.0.1 view.netrams.com
127.0.0.1 views.m4n.nl
127.0.0.1 viglink.com
127.0.0.1 viglink.pgpartner.com
127.0.0.1 villagevoicecollect.247realmedia.com
127.0.0.1 vip1.tw.adserver.yahoo.com
127.0.0.1 vipfastmoney.com
127.0.0.1 vk.18sexporn.ru
127.0.0.1 vmcsatellite.com
127.0.0.1 vmix.adbureau.net
127.0.0.1 vms.boldchat.com
127.0.0.1 vnu.eu-adcenter.net
127.0.0.1 vp.tscapeplay.com
127.0.0.1 vu.veoxa.com
127.0.0.1 vzarabotke.ru
127.0.0.1 w.ic.tynt.com
127.0.0.1 w1.webcompteur.com
127.0.0.1 w10.centralmediaserver.com
127.0.0.1 w11.centralmediaserver.com
127.0.0.1 wahoha.com
127.0.0.1 warp.crystalad.com
127.0.0.1 wdm29.com
127.0.0.1 web.adblade.com
127.0.0.1 web.nyc.ads.juno.co
127.0.0.1 web1b.netreflector.com
127.0.0.1 webads.bizservers.com
127.0.0.1 webads.nl
127.0.0.1 webcompteur.com
127.0.0.1 webhosting-ads.home.pl
127.0.0.1 webmdcom.tt.omtrdc.net
127.0.0.1 webservices-rewardpath.com
127.0.0.1 websurvey.spa-mr.com
127.0.0.1 wegetpaid.net
127.0.0.1 widget.crowdignite.com
127.0.0.1 widget3.linkwithin.com
127.0.0.1 widget5.linkwithin.com
127.0.0.1 widgets.tcimg.com
127.0.0.1 wigetmedia.com
127.0.0.1 wikiforosh.ir
127.0.0.1 wmedia.rotator.hadj7.adjuggler.net
127.0.0.1 wordplaywhiz.com
127.0.0.1 work-offer.com
127.0.0.1 worry-free-savings.com
127.0.0.1 wppluginspro.com
127.0.0.1 ws.addthis.com
127.0.0.1 wtp101.com
127.0.0.1 ww251.smartadserver.com
127.0.0.1 wwbtads.com
127.0.0.1 www.123specialgifts.com
127.0.0.1 www.2-art-coliseum.com
127.0.0.1 www.247realmedia.com
127.0.0.1 www.321cba.com
127.0.0.1 www.360ads.com
127.0.0.1 www.3qqq.net
127.0.0.1 www.3turtles.com
127.0.0.1 www.404errorpage.com
127.0.0.1 www.5thavenue.com
127.0.0.1 www.7500.com
127.0.0.1 www.7bpeople.com
127.0.0.1 www.7cnbcnews.com
127.0.0.1 www.805m.com
127.0.0.1 www.888casino.com
127.0.0.1 www.888poker.com
127.0.0.1 www.961.com
127.0.0.1 www.a.websponsors.com
127.0.0.1 www.abrogatesdv.info
127.0.0.1 www.action.ientry.net
127.0.0.1 www.actiondesk.com
127.0.0.1 www.ad-souk.com
127.0.0.1 www.ad-up.com
127.0.0.1 www.ad-words.ru
127.0.0.1 www.ad.tgdaily.com
127.0.0.1 www.ad.tomshardware.com
127.0.0.1 www.ad.twitchguru.com
127.0.0.1 www.adbanner.gr
127.0.0.1 www.adbrite.com
127.0.0.1 www.adcanadian.com
127.0.0.1 www.adcash.com
127.0.0.1 www.addthiscdn.com
127.0.0.1 www.adengage.com
127.0.0.1 www.adfunkyserver.com
127.0.0.1 www.adfusion.com
127.0.0.1 www.adimages.beeb.com
127.0.0.1 www.adipics.com
127.0.0.1 www.adireland.com
127.0.0.1 www.adjmps.com
127.0.0.1 www.adjug.com
127.0.0.1 www.adloader.com
127.0.0.1 www.adlogix.com
127.0.0.1 www.admex.com
127.0.0.1 www.adnet.biz
127.0.0.1 www.adnet.com
127.0.0.1 www.adnet.de
127.0.0.1 www.adobee.com
127.0.0.1 www.adocean.pl
127.0.0.1 www.adotube.com
127.0.0.1 www.adpepper.dk
127.0.0.1 www.adpowerzone.com
127.0.0.1 www.adquest3d.com
127.0.0.1 www.adreporting.com
127.0.0.1 www.ads.joetec.net
127.0.0.1 www.ads.revenue.net
127.0.0.1 www.ads2srv.com
127.0.0.1 www.adsentnetwork.com
127.0.0.1 www.adserver-espnet.sportszone.net
127.0.0.1 www.adserver.co.il
127.0.0.1 www.adserver.com
127.0.0.1 www.adserver.com.my
127.0.0.1 www.adserver.com.pl
127.0.0.1 www.adserver.janes.net
127.0.0.1 www.adserver.janes.org
127.0.0.1 www.adserver.jolt.co.uk
127.0.0.1 www.adserver.net
127.0.0.1 www.adserver.ugo.nl
127.0.0.1 www.adservtech.com
127.0.0.1 www.adsinimages.com
127.0.0.1 www.adsoftware.com
127.0.0.1 www.adspics.com
127.0.0.1 www.adstogo.com
127.0.0.1 www.adstreams.org
127.0.0.1 www.adtaily.pl
127.0.0.1 www.adtechus.com
127.0.0.1 www.adtlgc.com
127.0.0.1 www.adtrader.com
127.0.0.1 www.adtrix.com
127.0.0.1 www.advaliant.com
127.0.0.1 www.advertising-department.com
127.0.0.1 www.advertlets.com
127.0.0.1 www.advertpro.com
127.0.0.1 www.adverts.dcthomson.co.uk
127.0.0.1 www.advertyz.com
127.0.0.1 www.afcyhf.com
127.0.0.1 www.affiliate-fr.com
127.0.0.1 www.affiliateclick.com
127.0.0.1 www.affiliation-france.com
127.0.0.1 www.afform.co.uk
127.0.0.1 www.affpartners.com
127.0.0.1 www.afterdownload.com
127.0.0.1 www.agkn.com
127.0.0.1 www.alexxe.com
127.0.0.1 www.allosponsor.com
127.0.0.1 www.annuaire-autosurf.com
127.0.0.1 www.apparel-offer.com
127.0.0.1 www.apparelncs.com
127.0.0.1 www.applelounge.com
127.0.0.1 www.appnexus.com
127.0.0.1 www.art-music-rewardpath.com
127.0.0.1 www.art-offer.com
127.0.0.1 www.art-offer.net
127.0.0.1 www.art-photo-music-premiumblvd.com
127.0.0.1 www.art-photo-music-rewardempire.com
127.0.0.1 www.art-photo-music-savingblvd.com
127.0.0.1 www.auctionshare.net
127.0.0.1 www.aureate.com
127.0.0.1 www.autohipnose.com
127.0.0.1 www.automotive-offer.com
127.0.0.1 www.automotive-rewardpath.com
127.0.0.1 www.avcounter10.com
127.0.0.1 www.avsads.com
127.0.0.1 www.awesomevipoffers.com
127.0.0.1 www.awin1.com
127.0.0.1 www.awltovhc.com  #qksrv
127.0.0.1 www.bananacashback.com
127.0.0.1 www.banner4all.dk
127.0.0.1 www.bannerads.de
127.0.0.1 www.bannerbackup.com
127.0.0.1 www.bannerconnect.net
127.0.0.1 www.banners.paramountzone.com
127.0.0.1 www.bannersurvey.biz
127.0.0.1 www.banstex.com
127.0.0.1 www.bargainbeautybuys.com
127.0.0.1 www.bbelements.com
127.0.0.1 www.bestshopperrewards.com
127.0.0.1 www.bidtraffic.com
127.0.0.1 www.bidvertiser.com
127.0.0.1 www.bigbrandpromotions.com
127.0.0.1 www.bigbrandrewards.com
127.0.0.1 www.biggestgiftrewards.com
127.0.0.1 www.biz-offer.com
127.0.0.1 www.bizopprewards.com
127.0.0.1 www.blasphemysfhs.info
127.0.0.1 www.blatant8jh.info
127.0.0.1 www.bluediamondoffers.com
127.0.0.1 www.bnnr.nl
127.0.0.1 www.bonzi.com
127.0.0.1 www.bookclub-offer.com
127.0.0.1 www.books-media-edu-premiumblvd.com
127.0.0.1 www.books-media-edu-rewardempire.com
127.0.0.1 www.books-media-rewardpath.com
127.0.0.1 www.boonsolutions.com
127.0.0.1 www.bostonsubwayoffer.com
127.0.0.1 www.brandrewardcentral.com
127.0.0.1 www.brandsurveypanel.com
127.0.0.1 www.brokertraffic.com
127.0.0.1 www.budsinc.com
127.0.0.1 www.bugsbanner.it
127.0.0.1 www.bulkclicks.com
127.0.0.1 www.bulletads.com
127.0.0.1 www.burstnet.com
127.0.0.1 www.bus-offer.com
127.0.0.1 www.business-rewardpath.com
127.0.0.1 www.buttcandy.com
127.0.0.1 www.buwobarun.cn
127.0.0.1 www.buycheapadvertising.com
127.0.0.1 www.buyhitscheap.com
127.0.0.1 www.capath.com
127.0.0.1 www.car-truck-boat-bonuspath.com
127.0.0.1 www.car-truck-boat-premiumblvd.com
127.0.0.1 www.careers-rewardpath.com
127.0.0.1 www.cashback.co.uk
127.0.0.1 www.cashbackwow.co.uk
127.0.0.1 www.cashcount.com
127.0.0.1 www.casino770.com
127.0.0.1 www.catalinkcashback.com
127.0.0.1 www.cell-phone-giveaways.com
127.0.0.1 www.cellphoneincentives.com
127.0.0.1 www.chainsawoffer.com
127.0.0.1 www.choicedealz.com
127.0.0.1 www.choicesurveypanel.com
127.0.0.1 www.christianbusinessadvertising.com
127.0.0.1 www.ciqugasox.cn
127.0.0.1 www.claimfreerewards.com
127.0.0.1 www.clashmediausa.com
127.0.0.1 www.click-find-save.com
127.0.0.1 www.click-see-save.com
127.0.0.1 www.click10.com
127.0.0.1 www.click4click.com
127.0.0.1 www.clickbank.com
127.0.0.1 www.clickdensity.com
127.0.0.1 www.clicksor.com
127.0.0.1 www.clicksotrk.com
127.0.0.1 www.clicktale.com
127.0.0.1 www.clicktale.net
127.0.0.1 www.clickthruserver.com
127.0.0.1 www.clickthrutraffic.com
127.0.0.1 www.clicktilluwin.com
127.0.0.1 www.clicktorrent.info
127.0.0.1 www.clickxchange.com
127.0.0.1 www.closeoutproductsreview.com
127.0.0.1 www.cm1359.com
127.0.0.1 www.come-see-it-all.com
127.0.0.1 www.commerce-offer.com
127.0.0.1 www.commerce-rewardpath.com
127.0.0.1 www.computer-offer.com
127.0.0.1 www.computer-offer.net
127.0.0.1 www.computers-electronics-rewardpath.com
127.0.0.1 www.computersncs.com
127.0.0.1 www.consumer-org.com
127.0.0.1 www.consumergiftcenter.com
127.0.0.1 www.consumerincentivenetwork.com
127.0.0.1 www.contaxe.com
127.0.0.1 www.contextuads.com
127.0.0.1 www.contextweb.com
127.0.0.1 www.cookingtiprewards.com
127.0.0.1 www.cool-premiums-now.com
127.0.0.1 www.cool-premiums.com
127.0.0.1 www.coolconcepts.nl
127.0.0.1 www.coolpremiumsnow.com
127.0.0.1 www.coolsavings.com
127.0.0.1 www.coreglead.co.uk
127.0.0.1 www.cosmeticscentre.uk.com
127.0.0.1 www.cpabank.com
127.0.0.1 www.cpmadvisors.com
127.0.0.1 www.crazypopups.com
127.0.0.1 www.crazywinnings.com
127.0.0.1 www.crediblegfj.info
127.0.0.1 www.crispads.com
127.0.0.1 www.crowdgravity.com
127.0.0.1 www.crowdignite.com
127.0.0.1 www.ctbdev.net
127.0.0.1 www.cyber-incentives.com
127.0.0.1 www.d03x2011.com
127.0.0.1 www.da-ads.com
127.0.0.1 www.daily-saver.com
127.0.0.1 www.datatech.es
127.0.0.1 www.datingadvertising.com
127.0.0.1 www.dctracking.com
127.0.0.1 www.depravedwhores.com
127.0.0.1 www.designbloxlive.com
127.0.0.1 www.dgmaustralia.com
127.0.0.1 www.dietoftoday.ca.pn
127.0.0.1 www.digimedia.com
127.0.0.1 www.direc-tory.tk
127.0.0.1 www.directnetadvertising.net
127.0.0.1 www.directpowerrewards.com
127.0.0.1 www.dirtyrhino.com
127.0.0.1 www.discount-savings-more.com
127.0.0.1 www.djugoogs.com
127.0.0.1 www.dl-plugin.com
127.0.0.1 www.drowle.com
127.0.0.1 www.dutchsales.org
127.0.0.1 www.e-bannerx.com
127.0.0.1 www.earnmygift.com
127.0.0.1 www.earnpointsandgifts.com
127.0.0.1 www.easyadservice.com
127.0.0.1 www.ebaybanner.com
127.0.0.1 www.edu-offer.com
127.0.0.1 www.education-rewardpath.com
127.0.0.1 www.electronics-bonuspath.com
127.0.0.1 www.electronics-offer.net
127.0.0.1 www.electronics-rewardpath.com
127.0.0.1 www.electronicspresent.com
127.0.0.1 www.emailadvantagegroup.com
127.0.0.1 www.emailproductreview.com
127.0.0.1 www.emarketmakers.com
127.0.0.1 www.entertainment-rewardpath.com
127.0.0.1 www.entertainment-specials.com
127.0.0.1 www.eshopads2.com
127.0.0.1 www.etoro.com
127.0.0.1 www.euros4click.de
127.0.0.1 www.exclusivegiftcards.com
127.0.0.1 www.eyeblaster-bs.com
127.0.0.1 www.eyewonder.com #: Interactive Digital Advertising, Rich Media Ads, Flash Ads, Online Advertising
127.0.0.1 www.falkag.de
127.0.0.1 www.family-offer.com
127.0.0.1 www.fast-adv.it
127.0.0.1 www.fatcatrewards.com
127.0.0.1 www.feedjit.com
127.0.0.1 www.feedstermedia.com
127.0.0.1 www.fif49.info
127.0.0.1 www.finance-offer.com
127.0.0.1 www.finder.cox.net
127.0.0.1 www.fineclicks.com
127.0.0.1 www.flagcounter.com
127.0.0.1 www.flowers-offer.com
127.0.0.1 www.flu23.com
127.0.0.1 www.focalex.com
127.0.0.1 www.folloyu.com
127.0.0.1 www.food-drink-bonuspath.com
127.0.0.1 www.food-drink-rewardpath.com
127.0.0.1 www.food-offer.com
127.0.0.1 www.foodmixeroffer.com
127.0.0.1 www.fpctraffic2.com
127.0.0.1 www.free-gift-cards-now.com
127.0.0.1 www.free-gifts-comp.com
127.0.0.1 www.free-laptop-reward.com
127.0.0.1 www.freeadguru.com
127.0.0.1 www.freebiegb.co.uk
127.0.0.1 www.freecameraonus.com
127.0.0.1 www.freecameraprovider.com
127.0.0.1 www.freecamerasource.com
127.0.0.1 www.freecamerauk.co.uk
127.0.0.1 www.freecamsecrets.com
127.0.0.1 www.freecoolgift.com
127.0.0.1 www.freedesignerhandbagreviews.com
127.0.0.1 www.freedinnersource.com
127.0.0.1 www.freedvddept.com
127.0.0.1 www.freeelectronicscenter.com
127.0.0.1 www.freeelectronicsdepot.com
127.0.0.1 www.freeelectronicsonus.com
127.0.0.1 www.freeelectronicssource.com
127.0.0.1 www.freeentertainmentsource.com
127.0.0.1 www.freefoodprovider.com
127.0.0.1 www.freefoodsource.com
127.0.0.1 www.freefuelcard.com
127.0.0.1 www.freefuelcoupon.com
127.0.0.1 www.freegasonus.com
127.0.0.1 www.freegasprovider.com
127.0.0.1 www.freegiftcardsource.com
127.0.0.1 www.freegiftreward.com
127.0.0.1 www.freeipodnanouk.co.uk
127.0.0.1 www.freeipoduk.co.uk
127.0.0.1 www.freeipoduk.com
127.0.0.1 www.freelaptopgift.com
127.0.0.1 www.freelaptopnation.com
127.0.0.1 www.freelaptopreward.com
127.0.0.1 www.freelaptopwebsites.com
127.0.0.1 www.freenation.com
127.0.0.1 www.freeoffers-toys.com
127.0.0.1 www.freepayasyougotopupuk.co.uk
127.0.0.1 www.freeplasmanation.com
127.0.0.1 www.freerestaurantprovider.com
127.0.0.1 www.freerestaurantsource.com
127.0.0.1 www.freeshoppingprovider.com
127.0.0.1 www.freeshoppingsource.com
127.0.0.1 www.friendlyduck.com
127.0.0.1 www.frontpagecash.com
127.0.0.1 www.ftjcfx.com    #commission junction
127.0.0.1 www.fusionbanners.com
127.0.0.1 www.gameconsolerewards.com
127.0.0.1 www.games-toys-bonuspath.com
127.0.0.1 www.games-toys-free.com
127.0.0.1 www.games-toys-rewardpath.com
127.0.0.1 www.gatoradvertisinginformationnetwork.com
127.0.0.1 www.getacool100.com
127.0.0.1 www.getacool500.com
127.0.0.1 www.getacoollaptop.com
127.0.0.1 www.getacooltv.com
127.0.0.1 www.getagiftonline.com
127.0.0.1 www.getloan.com
127.0.0.1 www.getmyfreebabystuff.com
127.0.0.1 www.getmyfreegear.com
127.0.0.1 www.getmyfreegiftcard.com
127.0.0.1 www.getmyfreelaptop.com
127.0.0.1 www.getmyfreelaptophere.com
127.0.0.1 www.getmyfreeplasma.com
127.0.0.1 www.getmylaptopfree.com
127.0.0.1 www.getmyplasmatv.com
127.0.0.1 www.getspecialgifts.com
127.0.0.1 www.getyourfreecomputer.com
127.0.0.1 www.getyourfreetv.com
127.0.0.1 www.giftcardchallenge.com
127.0.0.1 www.giftcardsurveys.us.com
127.0.0.1 www.giftrewardzone.com
127.0.0.1 www.gifts-flowers-rewardpath.com
127.0.0.1 www.gimmethatreward.com
127.0.0.1 www.gmads.net
127.0.0.1 www.go-free-gifts.com
127.0.0.1 www.gofreegifts.com
127.0.0.1 www.goody-garage.com
127.0.0.1 www.gopopup.com
127.0.0.1 www.grabbit-rabbit.com
127.0.0.1 www.greasypalm.com
127.0.0.1 www.grz67.com
127.0.0.1 www.guesstheview.com
127.0.0.1 www.guptamedianetwork.com
127.0.0.1 www.happydiscountspecials.com
127.0.0.1 www.health-beauty-rewardpath.com
127.0.0.1 www.health-beauty-savingblvd.com
127.0.0.1 www.healthbeautyncs.com
127.0.0.1 www.healthclicks.co.uk
127.0.0.1 www.hebdotop.com
127.0.0.1 www.hightrafficads.com
127.0.0.1 www.holiday-gift-offers.com
127.0.0.1 www.holidayproductpromo.com
127.0.0.1 www.holidayshoppingrewards.com
127.0.0.1 www.home-garden-premiumblvd.com
127.0.0.1 www.home-garden-rewardempire.com
127.0.0.1 www.home-garden-rewardpath.com
127.0.0.1 www.home4bizstart.ru
127.0.0.1 www.homeelectronicproducts.com
127.0.0.1 www.hooqy.com
127.0.0.1 www.hot-daily-deal.com
127.0.0.1 www.hot-product-hangout.com
127.0.0.1 www.hotgiftzone.com
127.0.0.1 www.hotkeys.com
127.0.0.1 www.idealcasino.net
127.0.0.1 www.idirect.com
127.0.0.1 www.iicdn.com
127.0.0.1 www.ijacko.net
127.0.0.1 www.ilovecheating.com
127.0.0.1 www.impressionaffiliate.com
127.0.0.1 www.impressionaffiliate.mobi
127.0.0.1 www.impressionlead.com
127.0.0.1 www.impressionperformance.biz
127.0.0.1 www.incentive-scene.com
127.0.0.1 www.incentivegateway.com
127.0.0.1 www.incentiverewardcenter.com
127.0.0.1 www.inckamedia.com
127.0.0.1 www.indiads.com
127.0.0.1 www.infinite-ads.com      # www.shareactor.com
127.0.0.1 www.ins-offer.com
127.0.0.1 www.insurance-rewardpath.com
127.0.0.1 www.intela.com
127.0.0.1 www.interstitialzone.com
127.0.0.1 www.intnet-offer.com
127.0.0.1 www.invitefashion.com
127.0.0.1 www.is1.clixgalore.com
127.0.0.1 www.itrackerpro.com
127.0.0.1 www.itsfree123.com
127.0.0.1 www.iwantmy-freelaptop.com
127.0.0.1 www.iwantmyfree-laptop.com
127.0.0.1 www.iwantmyfreecash.com
127.0.0.1 www.iwantmyfreelaptop.com
127.0.0.1 www.iwantmygiftcard.com
127.0.0.1 www.jersey-offer.com
127.0.0.1 www.jetseeker.com
127.0.0.1 www.jivox.com
127.0.0.1 www.jl29jd25sm24mc29.com
127.0.0.1 www.joinfree.ro
127.0.0.1 www.jxliu.com
127.0.0.1 www.keywordblocks.com
127.0.0.1 www.kitaramarketplace.com
127.0.0.1 www.kitaramedia.com
127.0.0.1 www.kitaratrk.com
127.0.0.1 www.kliksaya.com
127.0.0.1 www.kmdl101.com
127.0.0.1 www.kontera.com
127.0.0.1 www.konversation.com
127.0.0.1 www.kreaffiliation.com
127.0.0.1 www.kuhdi.com
127.0.0.1 www.laptopreportcard.com
127.0.0.1 www.laptoprewards.com
127.0.0.1 www.laptoprewardsgroup.com
127.0.0.1 www.laptoprewardszone.com
127.0.0.1 www.larivieracasino.com
127.0.0.1 www.lasthr.info
127.0.0.1 www.lduhtrp.net   #commission junction
127.0.0.1 www.le1er.net
127.0.0.1 www.leadgreed.com
127.0.0.1 www.learning-offer.com
127.0.0.1 www.legal-rewardpath.com
127.0.0.1 www.leisure-offer.com
127.0.0.1 www.linkhut.com
127.0.0.1 www.linkpulse.com
127.0.0.1 www.linkwithin.com
127.0.0.1 www.liveinternet.ru
127.0.0.1 www.lottoforever.com
127.0.0.1 www.lucky-day-uk.com
127.0.0.1 www.macombdisplayads.com
127.0.0.1 www.marketing-rewardpath.com
127.0.0.1 www.mastertracks.be
127.0.0.1 www.maxbounty.com
127.0.0.1 www.mb01.com
127.0.0.1 www.media-motor.com
127.0.0.1 www.media2.travelzoo.com
127.0.0.1 www.medical-offer.com
127.0.0.1 www.medical-rewardpath.com
127.0.0.1 www.merchantapp.com
127.0.0.1 www.merlin.co.il
127.0.0.1 www.mgid.com
127.0.0.1 www.mightymagoo.com
127.0.0.1 www.mktg-offer.com
127.0.0.1 www.mlntracker.com
127.0.0.1 www.mochibot.com
127.0.0.1 www.morefreecamsecrets.com
127.0.0.1 www.morevisits.info
127.0.0.1 www.mp3playersource.com
127.0.0.1 www.mpression.net
127.0.0.1 www.my-reward-channel.com
127.0.0.1 www.my-rewardsvault.com
127.0.0.1 www.my-stats.com
127.0.0.1 www.myadsl.co.za
127.0.0.1 www.myaffiliateprogram.com
127.0.0.1 www.mycashback.co.uk
127.0.0.1 www.mycelloffer.com
127.0.0.1 www.mychoicerewards.com
127.0.0.1 www.myexclusiverewards.com
127.0.0.1 www.myfreedinner.com
127.0.0.1 www.myfreegifts.co.uk
127.0.0.1 www.myfreemp3player.com
127.0.0.1 www.mygiftcardcenter.com
127.0.0.1 www.mygreatrewards.com
127.0.0.1 www.myoffertracking.com
127.0.0.1 www.myseostats.com
127.0.0.1 www.myuitm.com
127.0.0.1 www.myusersonline.com
127.0.0.1 www.na47.com
127.0.0.1 www.nationalissuepanel.com
127.0.0.1 www.nationalsurveypanel.com
127.0.0.1 www.nctracking.com
127.0.0.1 www.nearbyad.com
127.0.0.1 www.needadvertising.com
127.0.0.1 www.neptuneads.com
127.0.0.1 www.netpalnow.com
127.0.0.1 www.netpaloffers.net
127.0.0.1 www.news6health.com
127.0.0.1 www.newssourceoftoday.com
127.0.0.1 www.nospartenaires.com
127.0.0.1 www.nothing-but-value.com
127.0.0.1 www.nysubwayoffer.com
127.0.0.1 www.offerx.co.uk
127.0.0.1 www.oinadserve.com
127.0.0.1 www.onlinebestoffers.net
127.0.0.1 www.ontheweb.com
127.0.0.1 www.opendownload.de
127.0.0.1 www.openload.de
127.0.0.1 www.optiad.net
127.0.0.1 www.paperg.com
127.0.0.1 www.parsads.com
127.0.0.1 www.pathforpoints.com
127.0.0.1 www.paypopup.com
127.0.0.1 www.people-choice-sites.com
127.0.0.1 www.personalcare-offer.com
127.0.0.1 www.personalcashbailout.com
127.0.0.1 www.phoenixads.co.in
127.0.0.1 www.pick-savings.com
127.0.0.1 www.plasmatv4free.com
127.0.0.1 www.plasmatvreward.com
127.0.0.1 www.politicalopinionsurvey.com
127.0.0.1 www.poponclick.com
127.0.0.1 www.popupad.net
127.0.0.1 www.popupdomination.com
127.0.0.1 www.popuptraffic.com
127.0.0.1 www.postmasterbannernet.com
127.0.0.1 www.postmasterdirect.com
127.0.0.1 www.postnewsads.com
127.0.0.1 www.premium-reward-club.com
127.0.0.1 www.premiumholidayoffers.com
127.0.0.1 www.premiumproductsonline.com
127.0.0.1 www.prizes.co.uk
127.0.0.1 www.probabilidades.net
127.0.0.1 www.productopinionpanel.com
127.0.0.1 www.productresearchpanel.com
127.0.0.1 www.producttestpanel.com
127.0.0.1 www.psclicks.com
127.0.0.1 www.pubdirecte.com
127.0.0.1 www.qitrck.com
127.0.0.1 www.quickbrowsersearch.com
127.0.0.1 www.radiate.com
127.0.0.1 www.rankyou.com
127.0.0.1 www.ravel-rewardpath.com
127.0.0.1 www.recreation-leisure-rewardpath.com
127.0.0.1 www.regflow.com
127.0.0.1 www.registrarads.com
127.0.0.1 www.resolvingserver.com
127.0.0.1 www.rewardblvd.com
127.0.0.1 www.rewardhotspot.com
127.0.0.1 www.rewardsflow.com
127.0.0.1 www.ringtonepartner.com
127.0.0.1 www.romepartners.com
127.0.0.1 www.roulettebotplus.com
127.0.0.1 www.rovion.com
127.0.0.1 www.rscounter10.com
127.0.0.1 www.rtcode.com
127.0.0.1 www.sa44.net
127.0.0.1 www.salesonline.ie
127.0.0.1 www.save-plan.com
127.0.0.1 www.savings-specials.com
127.0.0.1 www.savings-time.com
127.0.0.1 www.scoremygift.com
127.0.0.1 www.screen-mates.com
127.0.0.1 www.searchwe.com
127.0.0.1 www.seasonalsamplerspecials.com
127.0.0.1 www.securecontactinfo.com
127.0.0.1 www.securerunner.com
127.0.0.1 www.servedby.advertising.com
127.0.0.1 www.sexpartnerx.com
127.0.0.1 www.sexsponsors.com
127.0.0.1 www.share-server.com
127.0.0.1 www.shareasale.com
127.0.0.1 www.shc-rebates.com
127.0.0.1 www.shopperpromotions.com
127.0.0.1 www.shopping-offer.com
127.0.0.1 www.shoppingjobshere.com
127.0.0.1 www.shoppingsiterewards.com
127.0.0.1 www.shops-malls-rewardpath.com
127.0.0.1 www.shoptosaveenergy.com
127.0.0.1 www.simpli.fi
127.0.0.1 www.sizzle-savings.com
127.0.0.1 www.smart-scripts.com
127.0.0.1 www.smartadserver.com
127.0.0.1 www.smarttargetting.com
127.0.0.1 www.smokersopinionpoll.com
127.0.0.1 www.smspop.com
127.0.0.1 www.sochr.com
127.0.0.1 www.sociallypublish.com
127.0.0.1 www.soongu.info
127.0.0.1 www.specialgiftrewards.com
127.0.0.1 www.specialonlinegifts.com
127.0.0.1 www.specials-rewardpath.com
127.0.0.1 www.speedboink.com
127.0.0.1 www.speedyclick.com
127.0.0.1 www.spinbox.com
127.0.0.1 www.sponsorads.de
127.0.0.1 www.sponsoradulto.com
127.0.0.1 www.sports-bonuspath.com
127.0.0.1 www.sports-fitness-rewardpath.com
127.0.0.1 www.sports-offer.com
127.0.0.1 www.sports-offer.net
127.0.0.1 www.sports-premiumblvd.com
127.0.0.1 www.sq2trk2.com
127.0.0.1 www.star-advertising.com
127.0.0.1 www.subsitesadserver.co.uk
127.0.0.1 www.sudokuwhiz.com
127.0.0.1 www.superbrewards.com
127.0.0.1 www.supremeadsonline.com
127.0.0.1 www.surplus-suppliers.com
127.0.0.1 www.sweetsforfree.com
127.0.0.1 www.symbiosting.com
127.0.0.1 www.tcimg.com
127.0.0.1 www.text-link-ads.com
127.0.0.1 www.textbanners.net
127.0.0.1 www.textsrv.com
127.0.0.1 www.tgpmanager.com
127.0.0.1 www.the-path-gateway.com
127.0.0.1 www.the-smart-stop.com
127.0.0.1 www.theuseful.com
127.0.0.1 www.theuseful.net
127.0.0.1 www.thinktarget.com
127.0.0.1 www.thinlaptoprewards.com
127.0.0.1 www.thoughtfully-free.com
127.0.0.1 www.thruport.com
127.0.0.1 www.tons-to-see.com
127.0.0.1 www.top20free.com
127.0.0.1 www.topbrandrewards.com
127.0.0.1 www.topconsumergifts.com
127.0.0.1 www.topdemaroc.com
127.0.0.1 www.toy-offer.com
127.0.0.1 www.toy-offer.net
127.0.0.1 www.tqlkg.com     #commission junction
127.0.0.1 www.trackadvertising.net
127.0.0.1 www.tracklead.net
127.0.0.1 www.trafficrevenue.net
127.0.0.1 www.traffictrader.net
127.0.0.1 www.traffictraders.com
127.0.0.1 www.trafsearchonline.com
127.0.0.1 www.traktum.com
127.0.0.1 www.travel-leisure-bonuspath.com
127.0.0.1 www.travel-leisure-premiumblvd.com
127.0.0.1 www.traveladvertising.com
127.0.0.1 www.traveller-offer.com
127.0.0.1 www.traveller-offer.net
127.0.0.1 www.travelncs.com
127.0.0.1 www.treeloot.com
127.0.0.1 www.trendnews.com
127.0.0.1 www.tutop.com
127.0.0.1 www.tuttosessogratis.org
127.0.0.1 www.ukbanners.com
127.0.0.1 www.uleadstrk.com
127.0.0.1 www.ultimatefashiongifts.com
127.0.0.1 www.uproar.com
127.0.0.1 www.upsellit.com
127.0.0.1 www.us-choicevalue.com
127.0.0.1 www.us-topsites.com
127.0.0.1 www.usatravel-specials.com
127.0.0.1 www.usatravel-specials.net
127.0.0.1 www.usemax.de
127.0.0.1 www.utarget.co.uk
127.0.0.1 www.valueclick.com
127.0.0.1 www.via22.net
127.0.0.1 www.vibrantmedia.com
127.0.0.1 www.video-game-rewards-central.com
127.0.0.1 www.videogamerewardscentral.com
127.0.0.1 www.view4cash.de
127.0.0.1 www.virtumundo.com
127.0.0.1 www.vmcsatellite.com
127.0.0.1 www.wdm29.com
127.0.0.1 www.webcashvideos.com
127.0.0.1 www.webcompteur.com
127.0.0.1 www.webservices-rewardpath.com
127.0.0.1 www.websponsors.com
127.0.0.1 www.wegetpaid.net
127.0.0.1 www.whatuwhatuwhatuwant.com
127.0.0.1 www.widgetbucks.com
127.0.0.1 www.wigetmedia.com
127.0.0.1 www.windaily.com
127.0.0.1 www.winnerschoiceservices.com
127.0.0.1 www.wordplaywhiz.com
127.0.0.1 www.work-offer.com
127.0.0.1 www.worry-free-savings.com
127.0.0.1 www.wppluginspro.com
127.0.0.1 www.wtp101.com
127.0.0.1 www.xbn.ru        # exclusive banner network (Russian)
127.0.0.1 www.yceml.net
127.0.0.1 www.yibaruxet.cn
127.0.0.1 www.yieldmanager.net
127.0.0.1 www.youfck.com
127.0.0.1 www.your-gift-zone.com
127.0.0.1 www.yourdvdplayer.com
127.0.0.1 www.yourfreegascard.com
127.0.0.1 www.yourgascards.com
127.0.0.1 www.yourgiftrewards.com
127.0.0.1 www.yourgiftzone.com
127.0.0.1 www.yourhandytips.com
127.0.0.1 www.yourhotgiftzone.com
127.0.0.1 www.youripad4free.com
127.0.0.1 www.yourrewardzone.com
127.0.0.1 www.yoursmartrewards.com
127.0.0.1 www.zemgo.com
127.0.0.1 www.zevents.com
127.0.0.1 www1.ad.tomshardware.com
127.0.0.1 www1.adireland.com
127.0.0.1 www1.bannerspace.com
127.0.0.1 www1.belboon.de
127.0.0.1 www1.clicktorrent.info
127.0.0.1 www1.popinads.com
127.0.0.1 www1.safenyplanet.in
127.0.0.1 www10.ad.tomshardware.com
127.0.0.1 www10.glam.com
127.0.0.1 www10.indiads.com
127.0.0.1 www10.paypopup.com
127.0.0.1 www11.ad.tomshardware.com
127.0.0.1 www12.ad.tomshardware.com
127.0.0.1 www12.glam.com
127.0.0.1 www123.glam.com
127.0.0.1 www13.ad.tomshardware.com
127.0.0.1 www13.glam.com
127.0.0.1 www14.ad.tomshardware.com
127.0.0.1 www15.ad.tomshardware.com
127.0.0.1 www17.glam.com
127.0.0.1 www18.glam.com
127.0.0.1 www2.ad.tomshardware.com
127.0.0.1 www2.adireland.com
127.0.0.1 www2.adserverpub.com
127.0.0.1 www2.bannerspace.com
127.0.0.1 www2.glam.com
127.0.0.1 www210.paypopup.com
127.0.0.1 www211.paypopup.com
127.0.0.1 www212.paypopup.com
127.0.0.1 www213.paypopup.com
127.0.0.1 www24.glam.com
127.0.0.1 www24a.glam.com
127.0.0.1 www25.glam.com
127.0.0.1 www25a.glam.com
127.0.0.1 www3.ad.tomshardware.com
127.0.0.1 www3.addthis.com
127.0.0.1 www3.adireland.com
127.0.0.1 www3.bannerspace.com
127.0.0.1 www3.game-advertising-online.com
127.0.0.1 www30.glam.com
127.0.0.1 www30a1-orig.glam.com
127.0.0.1 www30a1.glam.com
127.0.0.1 www30a2-orig.glam.com
127.0.0.1 www30a3-orig.glam.com
127.0.0.1 www30a3.glam.com
127.0.0.1 www30a7.glam.com
127.0.0.1 www30l2.glam.com
127.0.0.1 www30t1-orig.glam.com
127.0.0.1 www35f.glam.com
127.0.0.1 www35jm.glam.com
127.0.0.1 www35t.glam.com
127.0.0.1 www4.ad.tomshardware.com
127.0.0.1 www4.bannerspace.com
127.0.0.1 www4.glam.com
127.0.0.1 www4.smartadserver.com
127.0.0.1 www5.ad.tomshardware.com
127.0.0.1 www5.bannerspace.com
127.0.0.1 www6.ad.tomshardware.com
127.0.0.1 www6.bannerspace.com
127.0.0.1 www7.ad.tomshardware.com
127.0.0.1 www7.bannerspace.com
127.0.0.1 www74.valueclick.com
127.0.0.1 www8.ad.tomshardware.com
127.0.0.1 www8.bannerspace.com
127.0.0.1 www81.valueclick.com
127.0.0.1 www9.ad.tomshardware.com
127.0.0.1 www9.paypopup.com
127.0.0.1 x.azjmp.com
127.0.0.1 x.interia.pl
127.0.0.1 x.mochiads.com
127.0.0.1 x86adserve006.adtech.de
127.0.0.1 xads.zedo.com
127.0.0.1 xlonhcld.xlontech.net
127.0.0.1 xml.adtech.de
127.0.0.1 xml.adtech.fr
127.0.0.1 xml.adtech.us
127.0.0.1 xml.click9.com
127.0.0.1 xpantivirus.com
127.0.0.1 xpcs.ads.yahoo.com
127.0.0.1 xstatic.nk-net.pl
127.0.0.1 y.cdn.adblade.com
127.0.0.1 yieldmanager.net
127.0.0.1 ym.adnxs.com
127.0.0.1 yodleeinc.tt.omtrdc.net
127.0.0.1 youfck.com
127.0.0.1 your-free-iphone.com
127.0.0.1 your-gift-zone.com
127.0.0.1 yourdvdplayer.com
127.0.0.1 yourfreegascard.com
127.0.0.1 yourgascards.com
127.0.0.1 yourgiftrewards.com
127.0.0.1 yourgiftzone.com
127.0.0.1 yourhandytips.com
127.0.0.1 yourhotgiftzone.com
127.0.0.1 youripad4free.com
127.0.0.1 yourrewardzone.com
127.0.0.1 yoursmartrewards.com
127.0.0.1 ypn-js.overture.com
127.0.0.1 ysiu.freenation.com
127.0.0.1 ytaahg.vo.llnwd.net
127.0.0.1 yx-in-f108.1e100.net
127.0.0.1 z.blogads.com
127.0.0.1 z.ceotrk.com
127.0.0.1 z1.adserver.com
127.0.0.1 zads.zedo.com
127.0.0.1 zdads.e-media.com
127.0.0.1 zeevex-online.com
127.0.0.1 zemgo.com
127.0.0.1 zevents.com
127.0.0.1 zuzzer5.com
#</ad-sites>

#<yahoo-ad-sites>

# yahoo banner ads
#127.0.0.1 us.i1.yimg.com   #Uncomment this to block yahoo images
127.0.0.1 eur.a1.yimg.com
127.0.0.1 in.yimg.com
127.0.0.1 sg.yimg.com
127.0.0.1 uk.i1.yimg.com
127.0.0.1 us.a1.yimg.com
127.0.0.1 us.b1.yimg.com
127.0.0.1 us.c1.yimg.com
127.0.0.1 us.d1.yimg.com
127.0.0.1 us.e1.yimg.com
127.0.0.1 us.f1.yimg.com
127.0.0.1 us.g1.yimg.com
127.0.0.1 us.h1.yimg.com
127.0.0.1 us.j1.yimg.com
127.0.0.1 us.k1.yimg.com
127.0.0.1 us.l1.yimg.com
127.0.0.1 us.m1.yimg.com
127.0.0.1 us.n1.yimg.com
127.0.0.1 us.o1.yimg.com
127.0.0.1 us.p1.yimg.com
127.0.0.1 us.q1.yimg.com
127.0.0.1 us.r1.yimg.com
127.0.0.1 us.s1.yimg.com
127.0.0.1 us.t1.yimg.com
127.0.0.1 us.u1.yimg.com
127.0.0.1 us.v1.yimg.com
127.0.0.1 us.w1.yimg.com
127.0.0.1 us.x1.yimg.com
127.0.0.1 us.y1.yimg.com
127.0.0.1 us.z1.yimg.com
#</yahoo-ad-sites>

#<hitbox-sites>

# hitbox.com web bugs
127.0.0.1 1cgi.hitbox.com
127.0.0.1 2cgi.hitbox.com
127.0.0.1 adminec1.hitbox.com
127.0.0.1 ads.hitbox.com
127.0.0.1 ag1.hitbox.com
127.0.0.1 ahbn1.hitbox.com
127.0.0.1 ahbn2.hitbox.com
127.0.0.1 ahbn3.hitbox.com
127.0.0.1 ahbn4.hitbox.com
127.0.0.1 ai.hitbox.com
127.0.0.1 aibg.hitbox.com
127.0.0.1 aibl.hitbox.com
127.0.0.1 aics.hitbox.com
127.0.0.1 aiui.hitbox.com
127.0.0.1 bigip1.hitbox.com
127.0.0.1 bigip2.hitbox.com
127.0.0.1 blowfish.hitbox.com
127.0.0.1 cdb.hitbox.com
127.0.0.1 cgi.hitbox.com
127.0.0.1 counter.hitbox.com
127.0.0.1 counter2.hitbox.com
127.0.0.1 dev.hitbox.com
127.0.0.1 dev101.hitbox.com
127.0.0.1 dev102.hitbox.com
127.0.0.1 dev103.hitbox.com
127.0.0.1 download.hitbox.com
127.0.0.1 ec1.hitbox.com
127.0.0.1 ehg-247internet.hitbox.com
127.0.0.1 ehg-accuweather.hitbox.com
127.0.0.1 ehg-acdsystems.hitbox.com
127.0.0.1 ehg-adeptscience.hitbox.com
127.0.0.1 ehg-affinitynet.hitbox.com
127.0.0.1 ehg-aha.hitbox.com
127.0.0.1 ehg-amerix.hitbox.com
127.0.0.1 ehg-apcc.hitbox.com
127.0.0.1 ehg-associatenewmedia.hitbox.com
127.0.0.1 ehg-ati.hitbox.com
127.0.0.1 ehg-attenza.hitbox.com
127.0.0.1 ehg-autodesk.hitbox.com
127.0.0.1 ehg-baa.hitbox.com
127.0.0.1 ehg-backweb.hitbox.com
127.0.0.1 ehg-bestbuy.hitbox.com
127.0.0.1 ehg-bizjournals.hitbox.com
127.0.0.1 ehg-bmwna.hitbox.com
127.0.0.1 ehg-boschsiemens.hitbox.com
127.0.0.1 ehg-bskyb.hitbox.com
127.0.0.1 ehg-cafepress.hitbox.com
127.0.0.1 ehg-careerbuilder.hitbox.com
127.0.0.1 ehg-cbc.hitbox.com
127.0.0.1 ehg-cbs.hitbox.com
127.0.0.1 ehg-cbsradio.hitbox.com
127.0.0.1 ehg-cedarpoint.hitbox.com
127.0.0.1 ehg-clearchannel.hitbox.com
127.0.0.1 ehg-closetmaid.hitbox.com
127.0.0.1 ehg-commjun.hitbox.com
127.0.0.1 ehg-communityconnect.hitbox.com
127.0.0.1 ehg-communityconnet.hitbox.com
127.0.0.1 ehg-comscore.hitbox.com
127.0.0.1 ehg-corusentertainment.hitbox.com
127.0.0.1 ehg-coverityinc.hitbox.com
127.0.0.1 ehg-crain.hitbox.com
127.0.0.1 ehg-ctv.hitbox.com
127.0.0.1 ehg-cygnusbm.hitbox.com
127.0.0.1 ehg-datamonitor.hitbox.com
127.0.0.1 ehg-dig.hitbox.com
127.0.0.1 ehg-digg.hitbox.com
127.0.0.1 ehg-eckounlimited.hitbox.com
127.0.0.1 ehg-esa.hitbox.com
127.0.0.1 ehg-espn.hitbox.com
127.0.0.1 ehg-fifa.hitbox.com
127.0.0.1 ehg-findlaw.hitbox.com
127.0.0.1 ehg-foundation.hitbox.com
127.0.0.1 ehg-foxsports.hitbox.com
127.0.0.1 ehg-futurepub.hitbox.com
127.0.0.1 ehg-gamedaily.hitbox.com
127.0.0.1 ehg-gamespot.hitbox.com
127.0.0.1 ehg-gatehousemedia.hitbox.com
127.0.0.1 ehg-gatehoussmedia.hitbox.com
127.0.0.1 ehg-glam.hitbox.com
127.0.0.1 ehg-groceryworks.hitbox.com
127.0.0.1 ehg-groupernetworks.hitbox.com
127.0.0.1 ehg-guardian.hitbox.com
127.0.0.1 ehg-hasbro.hitbox.com
127.0.0.1 ehg-hellodirect.hitbox.com
127.0.0.1 ehg-himedia.hitbox.com
127.0.0.1 ehg-hitent.hitbox.com
127.0.0.1 ehg-hollywood.hitbox.com
127.0.0.1 ehg-idg.hitbox.com
127.0.0.1 ehg-idgentertainment.hitbox.com
127.0.0.1 ehg-ifilm.hitbox.com
127.0.0.1 ehg-ignitemedia.hitbox.com
127.0.0.1 ehg-intel.hitbox.com
127.0.0.1 ehg-ittoolbox.hitbox.com
127.0.0.1 ehg-itworldcanada.hitbox.com
127.0.0.1 ehg-kingstontechnology.hitbox.com
127.0.0.1 ehg-knightridder.hitbox.com
127.0.0.1 ehg-learningco.hitbox.com
127.0.0.1 ehg-legonewyorkinc.hitbox.com
127.0.0.1 ehg-liveperson.hitbox.com
127.0.0.1 ehg-macpublishingllc.hitbox.com
127.0.0.1 ehg-macromedia.hitbox.com
127.0.0.1 ehg-magicalia.hitbox.com
127.0.0.1 ehg-maplesoft.hitbox.com
127.0.0.1 ehg-mgnlimited.hitbox.com
127.0.0.1 ehg-mindshare.hitbox.com
127.0.0.1 ehg-mtv.hitbox.com
127.0.0.1 ehg-mybc.hitbox.com
127.0.0.1 ehg-newarkinone.hitbox.com.hitbox.com
127.0.0.1 ehg-newegg.hitbox.com
127.0.0.1 ehg-newscientist.hitbox.com
127.0.0.1 ehg-newsinternational.hitbox.com
127.0.0.1 ehg-nokiafin.hitbox.com
127.0.0.1 ehg-novell.hitbox.com
127.0.0.1 ehg-nvidia.hitbox.com
127.0.0.1 ehg-oreilley.hitbox.com
127.0.0.1 ehg-oreilly.hitbox.com
127.0.0.1 ehg-pacifictheatres.hitbox.com
127.0.0.1 ehg-pennwell.hitbox.com
127.0.0.1 ehg-peoplesoft.hitbox.com
127.0.0.1 ehg-philipsvheusen.hitbox.com
127.0.0.1 ehg-pizzahut.hitbox.com
127.0.0.1 ehg-playboy.hitbox.com
127.0.0.1 ehg-presentigsolutions.hitbox.com
127.0.0.1 ehg-qualcomm.hitbox.com
127.0.0.1 ehg-quantumcorp.hitbox.com
127.0.0.1 ehg-randomhouse.hitbox.com
127.0.0.1 ehg-redherring.hitbox.com
127.0.0.1 ehg-register.hitbox.com
127.0.0.1 ehg-researchinmotion.hitbox.com
127.0.0.1 ehg-rfa.hitbox.com
127.0.0.1 ehg-rodale.hitbox.com
127.0.0.1 ehg-salesforce.hitbox.com
127.0.0.1 ehg-salonmedia.hitbox.com
127.0.0.1 ehg-samsungusa.hitbox.com
127.0.0.1 ehg-seca.hitbox.com
127.0.0.1 ehg-shoppersdrugmart.hitbox.com
127.0.0.1 ehg-sonybssc.hitbox.com
127.0.0.1 ehg-sonycomputer.hitbox.com
127.0.0.1 ehg-sonyelec.hitbox.com
127.0.0.1 ehg-sonymusic.hitbox.com
127.0.0.1 ehg-sonyny.hitbox.com
127.0.0.1 ehg-space.hitbox.com
127.0.0.1 ehg-sportsline.hitbox.com
127.0.0.1 ehg-streamload.hitbox.com
127.0.0.1 ehg-superpages.hitbox.com
127.0.0.1 ehg-techtarget.hitbox.com
127.0.0.1 ehg-tfl.hitbox.com
127.0.0.1 ehg-thefirstchurchchrist.hitbox.com
127.0.0.1 ehg-tigerdirect.hitbox.com
127.0.0.1 ehg-tigerdirect2.hitbox.com
127.0.0.1 ehg-topps.hitbox.com
127.0.0.1 ehg-tribute.hitbox.com
127.0.0.1 ehg-tumbleweed.hitbox.com
127.0.0.1 ehg-ubisoft.hitbox.com
127.0.0.1 ehg-uniontrib.hitbox.com
127.0.0.1 ehg-usnewsworldreport.hitbox.com
127.0.0.1 ehg-verizoncommunications.hitbox.com
127.0.0.1 ehg-viacom.hitbox.com
127.0.0.1 ehg-vmware.hitbox.com
127.0.0.1 ehg-vonage.hitbox.com
127.0.0.1 ehg-wachovia.hitbox.com
127.0.0.1 ehg-wacomtechnology.hitbox.com
127.0.0.1 ehg-warner-brothers.hitbox.com
127.0.0.1 ehg-wizardsofthecoast.hitbox.com.hitbox.com
127.0.0.1 ehg-womanswallstreet.hitbox.com
127.0.0.1 ehg-wss.hitbox.com
127.0.0.1 ehg-xxolympicwintergames.hitbox.com
127.0.0.1 ehg-yellowpages.hitbox.com
127.0.0.1 ehg-youtube.hitbox.com
127.0.0.1 ehg.commjun.hitbox.com
127.0.0.1 ehg.hitbox.com
127.0.0.1 ehg.mindshare.hitbox.com
127.0.0.1 ejs.hitbox.com
127.0.0.1 enterprise-admin.hitbox.com
127.0.0.1 enterprise.hitbox.com
127.0.0.1 esg.hitbox.com
127.0.0.1 evwr.hitbox.com
127.0.0.1 get.hitbox.com
127.0.0.1 hg1.hitbox.com
127.0.0.1 hg10.hitbox.com
127.0.0.1 hg11.hitbox.com
127.0.0.1 hg12.hitbox.com
127.0.0.1 hg13.hitbox.com
127.0.0.1 hg14.hitbox.com
127.0.0.1 hg15.hitbox.com
127.0.0.1 hg16.hitbox.com
127.0.0.1 hg17.hitbox.com
127.0.0.1 hg2.hitbox.com
127.0.0.1 hg3.hitbox.com
127.0.0.1 hg4.hitbox.com
127.0.0.1 hg5.hitbox.com
127.0.0.1 hg6.hitbox.com
127.0.0.1 hg6a.hitbox.com
127.0.0.1 hg7.hitbox.com
127.0.0.1 hg8.hitbox.com
127.0.0.1 hg9.hitbox.com
127.0.0.1 hitbox.com
127.0.0.1 hitboxbenchmarker.com
127.0.0.1 hitboxcentral.com
127.0.0.1 hitboxenterprise.com
127.0.0.1 hitboxwireless.com
127.0.0.1 host6.hitbox.com
127.0.0.1 ias.hitbox.com
127.0.0.1 ias2.hitbox.com
127.0.0.1 ibg.hitbox.com
127.0.0.1 ics.hitbox.com
127.0.0.1 idb.hitbox.com
127.0.0.1 js1.hitbox.com
127.0.0.1 lb.hitbox.com
127.0.0.1 lesbian-erotica.hitbox.com
127.0.0.1 lookup.hitbox.com
127.0.0.1 lookup2.hitbox.com
127.0.0.1 mrtg.hitbox.com
127.0.0.1 myhitbox.com
127.0.0.1 na.hitbox.com
127.0.0.1 narwhal.hitbox.com
127.0.0.1 nei.hitbox.com
127.0.0.1 noc-request.hitbox.com
127.0.0.1 noc.hitbox.com
127.0.0.1 nocboard.hitbox.com
127.0.0.1 ns1.hitbox.com
127.0.0.1 oas.hitbox.com
127.0.0.1 phg.hitbox.com
127.0.0.1 pure.hitbox.com
127.0.0.1 rainbowclub.hitbox.com
127.0.0.1 rd1.hitbox.com
127.0.0.1 reseller.hitbox.com
127.0.0.1 resources.hitbox.com
127.0.0.1 sitesearch.hitbox.com
127.0.0.1 specialtyclub.hitbox.com
127.0.0.1 ss.hitbox.com
127.0.0.1 stage.hitbox.com
127.0.0.1 stage101.hitbox.com
127.0.0.1 stage102.hitbox.com
127.0.0.1 stage103.hitbox.com
127.0.0.1 stage104.hitbox.com
127.0.0.1 stage105.hitbox.com
127.0.0.1 stats.hitbox.com
127.0.0.1 stats2.hitbox.com
127.0.0.1 stats3.hitbox.com
127.0.0.1 switch.hitbox.com
127.0.0.1 switch1.hitbox.com
127.0.0.1 switch10.hitbox.com
127.0.0.1 switch11.hitbox.com
127.0.0.1 switch5.hitbox.com
127.0.0.1 switch6.hitbox.com
127.0.0.1 switch8.hitbox.com
127.0.0.1 switch9.hitbox.com
127.0.0.1 tetra.hitbox.com
127.0.0.1 tools.hitbox.com
127.0.0.1 tools2.hitbox.com
127.0.0.1 toolsa.hitbox.com
127.0.0.1 ts1.hitbox.com
127.0.0.1 ts2.hitbox.com
127.0.0.1 vwr1.hitbox.com
127.0.0.1 vwr2.hitbox.com
127.0.0.1 vwr3.hitbox.com
127.0.0.1 w1.hitbox.com
127.0.0.1 w10.hitbox.com
127.0.0.1 w100.hitbox.com
127.0.0.1 w101.hitbox.com
127.0.0.1 w102.hitbox.com
127.0.0.1 w103.hitbox.com
127.0.0.1 w104.hitbox.com
127.0.0.1 w105.hitbox.com
127.0.0.1 w106.hitbox.com
127.0.0.1 w107.hitbox.com
127.0.0.1 w108.hitbox.com
127.0.0.1 w109.hitbox.com
127.0.0.1 w11.hitbox.com
127.0.0.1 w110.hitbox.com
127.0.0.1 w111.hitbox.com
127.0.0.1 w112.hitbox.com
127.0.0.1 w113.hitbox.com
127.0.0.1 w114.hitbox.com
127.0.0.1 w115.hitbox.com
127.0.0.1 w116.hitbox.com
127.0.0.1 w117.hitbox.com
127.0.0.1 w118.hitbox.com
127.0.0.1 w119.hitbox.com
127.0.0.1 w12.hitbox.com
127.0.0.1 w120.hitbox.com
127.0.0.1 w121.hitbox.com
127.0.0.1 w122.hitbox.com
127.0.0.1 w123.hitbox.com
127.0.0.1 w124.hitbox.com
127.0.0.1 w126.hitbox.com
127.0.0.1 w128.hitbox.com
127.0.0.1 w129.hitbox.com
127.0.0.1 w13.hitbox.com
127.0.0.1 w130.hitbox.com
127.0.0.1 w131.hitbox.com
127.0.0.1 w132.hitbox.com
127.0.0.1 w133.hitbox.com
127.0.0.1 w135.hitbox.com
127.0.0.1 w136.hitbox.com
127.0.0.1 w137.hitbox.com
127.0.0.1 w138.hitbox.com
127.0.0.1 w139.hitbox.com
127.0.0.1 w14.hitbox.com
127.0.0.1 w140.hitbox.com
127.0.0.1 w141.hitbox.com
127.0.0.1 w144.hitbox.com
127.0.0.1 w147.hitbox.com
127.0.0.1 w15.hitbox.com
127.0.0.1 w153.hitbox.com
127.0.0.1 w154.hitbox.com
127.0.0.1 w155.hitbox.com
127.0.0.1 w157.hitbox.com
127.0.0.1 w159.hitbox.com
127.0.0.1 w16.hitbox.com
127.0.0.1 w161.hitbox.com
127.0.0.1 w162.hitbox.com
127.0.0.1 w167.hitbox.com
127.0.0.1 w168.hitbox.com
127.0.0.1 w17.hitbox.com
127.0.0.1 w170.hitbox.com
127.0.0.1 w175.hitbox.com
127.0.0.1 w177.hitbox.com
127.0.0.1 w179.hitbox.com
127.0.0.1 w18.hitbox.com
127.0.0.1 w19.hitbox.com
127.0.0.1 w2.hitbox.com
127.0.0.1 w20.hitbox.com
127.0.0.1 w21.hitbox.com
127.0.0.1 w22.hitbox.com
127.0.0.1 w23.hitbox.com
127.0.0.1 w24.hitbox.com
127.0.0.1 w25.hitbox.com
127.0.0.1 w26.hitbox.com
127.0.0.1 w27.hitbox.com
127.0.0.1 w28.hitbox.com
127.0.0.1 w29.hitbox.com
127.0.0.1 w3.hitbox.com
127.0.0.1 w30.hitbox.com
127.0.0.1 w31.hitbox.com
127.0.0.1 w32.hitbox.com
127.0.0.1 w33.hitbox.com
127.0.0.1 w34.hitbox.com
127.0.0.1 w35.hitbox.com
127.0.0.1 w36.hitbox.com
127.0.0.1 w4.hitbox.com
127.0.0.1 w5.hitbox.com
127.0.0.1 w6.hitbox.com
127.0.0.1 w7.hitbox.com
127.0.0.1 w8.hitbox.com
127.0.0.1 w9.hitbox.com
127.0.0.1 webload101.hitbox.com
127.0.0.1 wss-gw-1.hitbox.com
127.0.0.1 wss-gw-3.hitbox.com
127.0.0.1 wvwr1.hitbox.com
127.0.0.1 ww1.hitbox.com
127.0.0.1 ww2.hitbox.com
127.0.0.1 ww3.hitbox.com
127.0.0.1 wwa.hitbox.com
127.0.0.1 wwb.hitbox.com
127.0.0.1 wwc.hitbox.com
127.0.0.1 wwd.hitbox.com
127.0.0.1 www.ehg-rr.hitbox.com
127.0.0.1 www.hitbox.com
127.0.0.1 www.hitboxwireless.com
127.0.0.1 y2k.hitbox.com
127.0.0.1 yang.hitbox.com
127.0.0.1 ying.hitbox.com
#</hitbox-sites>

#<extreme-dm-sites>

# www.extreme-dm.com tracking
127.0.0.1 extreme-dm.com
127.0.0.1 reports.extreme-dm.com
127.0.0.1 t.extreme-dm.com
127.0.0.1 t0.extreme-dm.com
127.0.0.1 t1.extreme-dm.com
127.0.0.1 u.extreme-dm.com
127.0.0.1 u0.extreme-dm.com
127.0.0.1 u1.extreme-dm.com
127.0.0.1 v.extreme-dm.com
127.0.0.1 v0.extreme-dm.com
127.0.0.1 v1.extreme-dm.com
127.0.0.1 w.extreme-dm.com
127.0.0.1 w0.extreme-dm.com
127.0.0.1 w1.extreme-dm.com
127.0.0.1 w2.extreme-dm.com
127.0.0.1 w3.extreme-dm.com
127.0.0.1 w4.extreme-dm.com
127.0.0.1 w5.extreme-dm.com
127.0.0.1 w6.extreme-dm.com
127.0.0.1 w7.extreme-dm.com
127.0.0.1 w8.extreme-dm.com
127.0.0.1 w9.extreme-dm.com
127.0.0.1 www.extreme-dm.com
127.0.0.1 x3.extreme-dm.com
127.0.0.1 y.extreme-dm.com
127.0.0.1 y0.extreme-dm.com
127.0.0.1 y1.extreme-dm.com
127.0.0.1 z.extreme-dm.com
127.0.0.1 z0.extreme-dm.com
127.0.0.1 z1.extreme-dm.com
#</extreme-dm-sites>

#<realmedia-sites>

# realmedia.com Open Ad Stream
127.0.0.1 ap.oasfile.aftenposten.no
127.0.0.1 imagenen1.247realmedia.com
127.0.0.1 oacentral.cepro.com
127.0.0.1 oas-central.east.realmedia.com
127.0.0.1 oas-central.realmedia.com
127.0.0.1 oas.adx.nu
127.0.0.1 oas.aurasports.com
127.0.0.1 oas.benchmark.fr
127.0.0.1 oas.dispatch.com
127.0.0.1 oas.foxnews.com
127.0.0.1 oas.greensboro.com
127.0.0.1 oas.guardian.co.uk
127.0.0.1 oas.ibnlive.com
127.0.0.1 oas.lee.net
127.0.0.1 oas.nrjlink.fr
127.0.0.1 oas.nzz.ch
127.0.0.1 oas.portland.com
127.0.0.1 oas.publicitas.ch
127.0.0.1 oas.salon.com
127.0.0.1 oas.sciencemag.org
127.0.0.1 oas.signonsandiego.com
127.0.0.1 oas.startribune.com
127.0.0.1 oas.toronto.com
127.0.0.1 oas.uniontrib.com
127.0.0.1 oas.villagevoice.com
127.0.0.1 oas.vtsgonline.com
127.0.0.1 oasc03012.247realmedia.com
127.0.0.1 oasc03049.247realmedia.com
127.0.0.1 oasc06006.247realmedia.com
127.0.0.1 oasc08008.247realmedia.com
127.0.0.1 oasc09.247realmedia.com
127.0.0.1 oascentral.123greetings.com
127.0.0.1 oascentral.abclocal.go.com
127.0.0.1 oascentral.adage.com
127.0.0.1 oascentral.adageglobal.com
127.0.0.1 oascentral.aircanada.com
127.0.0.1 oascentral.alanicnewsnet.ca
127.0.0.1 oascentral.alanticnewsnet.ca
127.0.0.1 oascentral.americanheritage.com
127.0.0.1 oascentral.artistdirect.com
127.0.0.1 oascentral.artistirect.com
127.0.0.1 oascentral.askmen.com
127.0.0.1 oascentral.aviationnow.com
127.0.0.1 oascentral.blackenterprises.com
127.0.0.1 oascentral.blogher.org
127.0.0.1 oascentral.bostonherald.com
127.0.0.1 oascentral.bostonphoenix.com
127.0.0.1 oascentral.businessinsider.com
127.0.0.1 oascentral.businessweek.com
127.0.0.1 oascentral.businessweeks.com
127.0.0.1 oascentral.buy.com
127.0.0.1 oascentral.canadaeast.com
127.0.0.1 oascentral.canadianliving.com
127.0.0.1 oascentral.charleston.net
127.0.0.1 oascentral.chicagobusiness.com
127.0.0.1 oascentral.chron.com
127.0.0.1 oascentral.citypages.com
127.0.0.1 oascentral.clearchannel.com
127.0.0.1 oascentral.comcast.net
127.0.0.1 oascentral.comics.com
127.0.0.1 oascentral.construction.com
127.0.0.1 oascentral.consumerreports.org
127.0.0.1 oascentral.covers.com
127.0.0.1 oascentral.crainsdetroit.com
127.0.0.1 oascentral.crimelibrary.com
127.0.0.1 oascentral.cybereps.com
127.0.0.1 oascentral.dailybreeze.com
127.0.0.1 oascentral.dailyherald.com
127.0.0.1 oascentral.dilbert.com
127.0.0.1 oascentral.discovery.com
127.0.0.1 oascentral.drphil.com
127.0.0.1 oascentral.eastbayexpress.com
127.0.0.1 oascentral.encyclopedia.com
127.0.0.1 oascentral.fashionmagazine.com
127.0.0.1 oascentral.fayettevillenc.com
127.0.0.1 oascentral.feedroom.com
127.0.0.1 oascentral.forsythnews.com
127.0.0.1 oascentral.fortunecity.com
127.0.0.1 oascentral.foxnews.com
127.0.0.1 oascentral.freedom.com
127.0.0.1 oascentral.g4techtv.com
127.0.0.1 oascentral.ggl.com
127.0.0.1 oascentral.gigex.com
127.0.0.1 oascentral.globalpost.com
127.0.0.1 oascentral.hamptonroads.com
127.0.0.1 oascentral.hamptoroads.com
127.0.0.1 oascentral.hamtoroads.com
127.0.0.1 oascentral.herenb.com
127.0.0.1 oascentral.hollywood.com
127.0.0.1 oascentral.houstonpress.com
127.0.0.1 oascentral.inq7.net
127.0.0.1 oascentral.investors.com
127.0.0.1 oascentral.investorwords.com
127.0.0.1 oascentral.itbusiness.ca
127.0.0.1 oascentral.killsometime.com
127.0.0.1 oascentral.laptopmag.com
127.0.0.1 oascentral.law.com
127.0.0.1 oascentral.laweekly.com
127.0.0.1 oascentral.looksmart.com
127.0.0.1 oascentral.lycos.com
127.0.0.1 oascentral.mailtribune.com
127.0.0.1 oascentral.mayoclinic.com
127.0.0.1 oascentral.medbroadcast.com
127.0.0.1 oascentral.metro.us
127.0.0.1 oascentral.minnpost.com
127.0.0.1 oascentral.mochila.com
127.0.0.1 oascentral.motherjones.com
127.0.0.1 oascentral.nerve.com
127.0.0.1 oascentral.newsmax.com
127.0.0.1 oascentral.nowtoronto.com
127.0.0.1 oascentral.onwisconsin.com
127.0.0.1 oascentral.phoenixnewtimes.com
127.0.0.1 oascentral.phoenixvillenews.com
127.0.0.1 oascentral.pitch.com
127.0.0.1 oascentral.poconorecord.com
127.0.0.1 oascentral.politico.com
127.0.0.1 oascentral.post-gazette.com
127.0.0.1 oascentral.pottsmerc.com
127.0.0.1 oascentral.princetonreview.com
127.0.0.1 oascentral.publicradio.org
127.0.0.1 oascentral.radaronline.com
127.0.0.1 oascentral.rcrnews.com
127.0.0.1 oascentral.redherring.com
127.0.0.1 oascentral.redorbit.com
127.0.0.1 oascentral.redstate.com
127.0.0.1 oascentral.reference.com
127.0.0.1 oascentral.regalinterative.com
127.0.0.1 oascentral.register.com
127.0.0.1 oascentral.registerguard.com
127.0.0.1 oascentral.registguard.com
127.0.0.1 oascentral.riverfronttimes.com
127.0.0.1 oascentral.salon.com
127.0.0.1 oascentral.santacruzsentinel.com
127.0.0.1 oascentral.sciam.com
127.0.0.1 oascentral.scientificamerican.com
127.0.0.1 oascentral.seacoastonline.com
127.0.0.1 oascentral.seattleweekly.com
127.0.0.1 oascentral.sfgate.com
127.0.0.1 oascentral.sfweekly.com
127.0.0.1 oascentral.sina.com
127.0.0.1 oascentral.sina.com.hk
127.0.0.1 oascentral.sparknotes.com
127.0.0.1 oascentral.sptimes.com
127.0.0.1 oascentral.starbulletin.com
127.0.0.1 oascentral.suntimes.com
127.0.0.1 oascentral.surfline.com
127.0.0.1 oascentral.thechronicleherald.ca
127.0.0.1 oascentral.thehockeynews.com
127.0.0.1 oascentral.thenation.com
127.0.0.1 oascentral.theonion.com
127.0.0.1 oascentral.theonionavclub.com
127.0.0.1 oascentral.thephoenix.com
127.0.0.1 oascentral.thesmokinggun.com
127.0.0.1 oascentral.thespark.com
127.0.0.1 oascentral.tmcnet.com
127.0.0.1 oascentral.tnr.com
127.0.0.1 oascentral.tourismvancouver.com
127.0.0.1 oascentral.townhall.com
127.0.0.1 oascentral.tribe.net
127.0.0.1 oascentral.trutv.com
127.0.0.1 oascentral.upi.com
127.0.0.1 oascentral.urbanspoon.com
127.0.0.1 oascentral.villagevoice.com
127.0.0.1 oascentral.virtualtourist.com
127.0.0.1 oascentral.warcry.com
127.0.0.1 oascentral.washtimes.com
127.0.0.1 oascentral.wciv.com
127.0.0.1 oascentral.westword.com
127.0.0.1 oascentral.where.ca
127.0.0.1 oascentral.wjla.com
127.0.0.1 oascentral.wkrn.com
127.0.0.1 oascentral.wwe.com
127.0.0.1 oascentral.yellowpages.com
127.0.0.1 oascentral.ywlloewpages.ca
127.0.0.1 oascentral.zwire.com
127.0.0.1 oascentralnx.comcast.net
127.0.0.1 oascentreal.adcritic.com
127.0.0.1 oascetral.laweekly.com
127.0.0.1 oasroanoke.com
#</realmedia-sites>

#<fastclick-sites>

# fastclick banner ads
127.0.0.1 media1.fastclick.net
127.0.0.1 media2.fastclick.net
127.0.0.1 media3.fastclick.net
127.0.0.1 media4.fastclick.net
127.0.0.1 media5.fastclick.net
127.0.0.1 media6.fastclick.net
127.0.0.1 media7.fastclick.net
127.0.0.1 media8.fastclick.net
127.0.0.1 media9.fastclick.net
127.0.0.1 media10.fastclick.net
127.0.0.1 media11.fastclick.net
127.0.0.1 media12.fastclick.net
127.0.0.1 media13.fastclick.net
127.0.0.1 media14.fastclick.net
127.0.0.1 media15.fastclick.net
127.0.0.1 media16.fastclick.net
127.0.0.1 media17.fastclick.net
127.0.0.1 media18.fastclick.net
127.0.0.1 media19.fastclick.net
127.0.0.1 media20.fastclick.net
127.0.0.1 media21.fastclick.net
127.0.0.1 media22.fastclick.net
127.0.0.1 media23.fastclick.net
127.0.0.1 media24.fastclick.net
127.0.0.1 media25.fastclick.net
127.0.0.1 media26.fastclick.net
127.0.0.1 media27.fastclick.net
127.0.0.1 media28.fastclick.net
127.0.0.1 media29.fastclick.net
127.0.0.1 media30.fastclick.net
127.0.0.1 media31.fastclick.net
127.0.0.1 media32.fastclick.net
127.0.0.1 media33.fastclick.net
127.0.0.1 media34.fastclick.net
127.0.0.1 media35.fastclick.net
127.0.0.1 media36.fastclick.net
127.0.0.1 media37.fastclick.net
127.0.0.1 media38.fastclick.net
127.0.0.1 media39.fastclick.net
127.0.0.1 media40.fastclick.net
127.0.0.1 media41.fastclick.net
127.0.0.1 media42.fastclick.net
127.0.0.1 media43.fastclick.net
127.0.0.1 media44.fastclick.net
127.0.0.1 media45.fastclick.net
127.0.0.1 media46.fastclick.net
127.0.0.1 media47.fastclick.net
127.0.0.1 media48.fastclick.net
127.0.0.1 media49.fastclick.net
127.0.0.1 media50.fastclick.net
127.0.0.1 media51.fastclick.net
127.0.0.1 media52.fastclick.net
127.0.0.1 media53.fastclick.net
127.0.0.1 media54.fastclick.net
127.0.0.1 media55.fastclick.net
127.0.0.1 media56.fastclick.net
127.0.0.1 media57.fastclick.net
127.0.0.1 media58.fastclick.net
127.0.0.1 media59.fastclick.net
127.0.0.1 media60.fastclick.net
127.0.0.1 media61.fastclick.net
127.0.0.1 media62.fastclick.net
127.0.0.1 media63.fastclick.net
127.0.0.1 media64.fastclick.net
127.0.0.1 media65.fastclick.net
127.0.0.1 media66.fastclick.net
127.0.0.1 media67.fastclick.net
127.0.0.1 media68.fastclick.net
127.0.0.1 media69.fastclick.net
127.0.0.1 media70.fastclick.net
127.0.0.1 media71.fastclick.net
127.0.0.1 media72.fastclick.net
127.0.0.1 media73.fastclick.net
127.0.0.1 media74.fastclick.net
127.0.0.1 media75.fastclick.net
127.0.0.1 media76.fastclick.net
127.0.0.1 media77.fastclick.net
127.0.0.1 media78.fastclick.net
127.0.0.1 media79.fastclick.net
127.0.0.1 media80.fastclick.net
127.0.0.1 media81.fastclick.net
127.0.0.1 media82.fastclick.net
127.0.0.1 media83.fastclick.net
127.0.0.1 media84.fastclick.net
127.0.0.1 media85.fastclick.net
127.0.0.1 media86.fastclick.net
127.0.0.1 media87.fastclick.net
127.0.0.1 media88.fastclick.net
127.0.0.1 media89.fastclick.net
127.0.0.1 media90.fastclick.net
127.0.0.1 media91.fastclick.net
127.0.0.1 media92.fastclick.net
127.0.0.1 media93.fastclick.net
127.0.0.1 media94.fastclick.net
127.0.0.1 media95.fastclick.net
127.0.0.1 media96.fastclick.net
127.0.0.1 media97.fastclick.net
127.0.0.1 media98.fastclick.net
127.0.0.1 media99.fastclick.net
127.0.0.1 fastclick.net
#</fastclick-sites>

#<belo-interactive-sites>

# belo interactive ads
127.0.0.1 te.about.com
127.0.0.1 te.adlandpro.com
127.0.0.1 te.advance.net
127.0.0.1 te.ap.org
127.0.0.1 te.astrology.com
127.0.0.1 te.audiencematch.net
127.0.0.1 te.belointeractive.com
127.0.0.1 te.boston.com
127.0.0.1 te.businessweek.com
127.0.0.1 te.chicagotribune.com
127.0.0.1 te.chron.com
127.0.0.1 te.cleveland.net
127.0.0.1 te.ctnow.com
127.0.0.1 te.dailycamera.com
127.0.0.1 te.dailypress.com
127.0.0.1 te.dentonrc.com
127.0.0.1 te.greenwichtime.com
127.0.0.1 te.idg.com
127.0.0.1 te.infoworld.com
127.0.0.1 te.ivillage.com
127.0.0.1 te.journalnow.com
127.0.0.1 te.latimes.com
127.0.0.1 te.mcall.com
127.0.0.1 te.mgnetwork.com
127.0.0.1 te.mysanantonio.com
127.0.0.1 te.newsday.com
127.0.0.1 te.nytdigital.com
127.0.0.1 te.orlandosentinel.com
127.0.0.1 te.scripps.com
127.0.0.1 te.scrippsnetworksprivacy.com
127.0.0.1 te.scrippsnewspapersprivacy.com
127.0.0.1 te.sfgate.com
127.0.0.1 te.signonsandiego.com
127.0.0.1 te.stamfordadvocate.com
127.0.0.1 te.sun-sentinel.com
127.0.0.1 te.sunspot.net
127.0.0.1 te.suntimes.com
127.0.0.1 te.tbo.com
127.0.0.1 te.thestar.ca
127.0.0.1 te.thestar.com
127.0.0.1 te.trb.com
127.0.0.1 te.versiontracker.com
127.0.0.1 te.wsls.com
#</belo-interactive-sites>

#<popup-traps>

# popup traps -- sites that bounce you around or would not let you leave
127.0.0.1 24hwebsex.com
127.0.0.1 adultfriendfinder.com
127.0.0.1 all-tgp.org
127.0.0.1 fioe.info
127.0.0.1 incestland.com
127.0.0.1 lesview.com
127.0.0.1 searchforit.com
127.0.0.1 www.asiansforu.com
127.0.0.1 www.bangbuddy.com
127.0.0.1 www.datanotary.com
127.0.0.1 www.entercasino.com
127.0.0.1 www.incestdot.com
127.0.0.1 www.incestgold.com
127.0.0.1 www.justhookup.com
127.0.0.1 www.mangayhentai.com
127.0.0.1 www.myluvcrush.ca
127.0.0.1 www.ourfuckbook.com
127.0.0.1 www.realincestvideos.com
127.0.0.1 www.searchforit.com
127.0.0.1 www.searchv.com
127.0.0.1 www.secretosx.com
127.0.0.1 www.seductiveamateurs.com 
127.0.0.1 www.smsmovies.net
127.0.0.1 www.wowjs.1www.cn
127.0.0.1 www.xxxnations.com
127.0.0.1 www.xxxnightly.com
127.0.0.1 www.xxxtoolbar.com
127.0.0.1 www.yourfuckbook.com
#</popup-traps>

#<ecard-scam-sites>

# malicious e-card -- these sites send out mass quantities of spam 
    # and some distribute adware and spyware
127.0.0.1 123greetings.com  # contains one link to distributor of adware or spyware
127.0.0.1 2000greetings.com
127.0.0.1 celebwelove.com
127.0.0.1 ecard4all.com
127.0.0.1 eforu.com
127.0.0.1 freewebcards.com
127.0.0.1 fukkad.com
127.0.0.1 fun-e-cards.com
127.0.0.1 funnyreign.com    # heavy spam (Site Advisor received 1075 e-mails/week)
127.0.0.1 funsilly.com
127.0.0.1 myfuncards.com
127.0.0.1 www.cool-downloads.com
127.0.0.1 www.cool-downloads.net
127.0.0.1 www.friend-card.com
127.0.0.1 www.friend-cards.com
127.0.0.1 www.friend-cards.net
127.0.0.1 www.friend-greeting.com
127.0.0.1 www.friend-greetings.com
127.0.0.1 www.friend-greetings.net
127.0.0.1 www.friendgreetings.com
127.0.0.1 www.friendgreetings.net
127.0.0.1 www.laugh-mail.com
127.0.0.1 www.laugh-mail.net
#</ecard-scam-sites>

#<IVW-sites>

# European network of tracking sites
127.0.0.1 0ivwbox.de
127.0.0.1 1ivwbox.de
127.0.0.1 2ivwbox.de
127.0.0.1 3ivwbox.de
127.0.0.1 4ivwbox.de
127.0.0.1 5ivwbox.de
127.0.0.1 6ivwbox.de
127.0.0.1 7ivwbox.de
127.0.0.1 8ivwbox.de
127.0.0.1 8vwbox.de
127.0.0.1 9ivwbox.de
127.0.0.1 9vwbox.de
127.0.0.1 aivwbox.de
127.0.0.1 avwbox.de
127.0.0.1 bivwbox.de
127.0.0.1 civwbox.de
127.0.0.1 divwbox.de
127.0.0.1 eevwbox.de
127.0.0.1 eivwbox.de
127.0.0.1 evwbox.de
127.0.0.1 fivwbox.de
127.0.0.1 givwbox.de
127.0.0.1 hivwbox.de
127.0.0.1 i8vwbox.de
127.0.0.1 i9vwbox.de
127.0.0.1 iavwbox.de
127.0.0.1 ibvwbox.de
127.0.0.1 ibwbox.de
127.0.0.1 icvwbox.de
127.0.0.1 icwbox.de
127.0.0.1 ievwbox.de
127.0.0.1 ifvwbox.de
127.0.0.1 ifwbox.de
127.0.0.1 igvwbox.de
127.0.0.1 igwbox.de
127.0.0.1 iivwbox.de
127.0.0.1 ijvwbox.de
127.0.0.1 ikvwbox.de
127.0.0.1 iovwbox.de
127.0.0.1 iuvwbox.de
127.0.0.1 iv2box.de
127.0.0.1 iv2wbox.de
127.0.0.1 iv3box.de
127.0.0.1 iv3wbox.de
127.0.0.1 ivabox.de
127.0.0.1 ivawbox.de
127.0.0.1 ivbox.de
127.0.0.1 ivbwbox.de
127.0.0.1 ivbwox.de
127.0.0.1 ivcwbox.de
127.0.0.1 ivebox.de
127.0.0.1 ivewbox.de
127.0.0.1 ivfwbox.de
127.0.0.1 ivgwbox.de
127.0.0.1 ivqbox.de
127.0.0.1 ivqwbox.de
127.0.0.1 ivsbox.de
127.0.0.1 ivswbox.de
127.0.0.1 ivvbox.de
127.0.0.1 ivvwbox.de
127.0.0.1 ivw2box.de
127.0.0.1 ivw3box.de
127.0.0.1 ivwabox.de
127.0.0.1 ivwb0ox.de
127.0.0.1 ivwb0x.de
127.0.0.1 ivwb9ox.de
127.0.0.1 ivwb9x.de
127.0.0.1 ivwbaox.de
127.0.0.1 ivwbax.de
127.0.0.1 ivwbbox.de
127.0.0.1 ivwbeox.de
127.0.0.1 ivwbex.de
127.0.0.1 ivwbgox.de
127.0.0.1 ivwbhox.de
127.0.0.1 ivwbiox.de
127.0.0.1 ivwbix.de
127.0.0.1 ivwbkox.de
127.0.0.1 ivwbkx.de
127.0.0.1 ivwblox.de
127.0.0.1 ivwblx.de
127.0.0.1 ivwbnox.de
127.0.0.1 ivwbo.de
127.0.0.1 ivwbo0x.de
127.0.0.1 ivwbo9x.de
127.0.0.1 ivwboax.de
127.0.0.1 ivwboc.de
127.0.0.1 ivwbock.de
127.0.0.1 ivwbocx.de
127.0.0.1 ivwbod.de
127.0.0.1 ivwbodx.de
127.0.0.1 ivwboex.de
127.0.0.1 ivwboix.de
127.0.0.1 ivwboks.de
127.0.0.1 ivwbokx.de
127.0.0.1 ivwbolx.de
127.0.0.1 ivwboox.de
127.0.0.1 ivwbopx.de
127.0.0.1 ivwbos.de
127.0.0.1 ivwbosx.de
127.0.0.1 ivwboux.de
127.0.0.1 ivwbox.de
127.0.0.1 ivwbox0.de
127.0.0.1 ivwbox1.de
127.0.0.1 ivwbox2.de
127.0.0.1 ivwbox3.de
127.0.0.1 ivwbox4.de
127.0.0.1 ivwbox5.de
127.0.0.1 ivwbox6.de
127.0.0.1 ivwbox7.de
127.0.0.1 ivwbox8.de
127.0.0.1 ivwbox9.de
127.0.0.1 ivwboxa.de
127.0.0.1 ivwboxb.de
127.0.0.1 ivwboxc.de
127.0.0.1 ivwboxd.de
127.0.0.1 ivwboxe.de
127.0.0.1 ivwboxes.de
127.0.0.1 ivwboxf.de
127.0.0.1 ivwboxg.de
127.0.0.1 ivwboxh.de
127.0.0.1 ivwboxi.de
127.0.0.1 ivwboxj.de
127.0.0.1 ivwboxk.de
127.0.0.1 ivwboxl.de
127.0.0.1 ivwboxm.de
127.0.0.1 ivwboxn.de
127.0.0.1 ivwboxo.de
127.0.0.1 ivwboxp.de
127.0.0.1 ivwboxq.de
127.0.0.1 ivwboxr.de
127.0.0.1 ivwboxs.de
127.0.0.1 ivwboxt.de
127.0.0.1 ivwboxu.de
127.0.0.1 ivwboxv.de
127.0.0.1 ivwboxw.de
127.0.0.1 ivwboxx.de
127.0.0.1 ivwboxy.de
127.0.0.1 ivwboxz.de
127.0.0.1 ivwboyx.de
127.0.0.1 ivwboz.de
127.0.0.1 ivwbozx.de
127.0.0.1 ivwbpox.de
127.0.0.1 ivwbpx.de
127.0.0.1 ivwbuox.de
127.0.0.1 ivwbux.de
127.0.0.1 ivwbvox.de
127.0.0.1 ivwbx.de
127.0.0.1 ivwbxo.de
127.0.0.1 ivwbyox.de
127.0.0.1 ivwbyx.de
127.0.0.1 ivwebox.de
127.0.0.1 ivwgbox.de
127.0.0.1 ivwgox.de
127.0.0.1 ivwhbox.de
127.0.0.1 ivwhox.de
127.0.0.1 ivwnbox.de
127.0.0.1 ivwnox.de
127.0.0.1 ivwobx.de
127.0.0.1 ivwox.de
127.0.0.1 ivwpbox.de
127.0.0.1 ivwpox.de
127.0.0.1 ivwqbox.de
127.0.0.1 ivwsbox.de
127.0.0.1 ivwvbox.de
127.0.0.1 ivwvox.de
127.0.0.1 ivwwbox.de
127.0.0.1 iwbox.de
127.0.0.1 iwvbox.de
127.0.0.1 iwvwbox.de
127.0.0.1 iwwbox.de
127.0.0.1 iyvwbox.de
127.0.0.1 jivwbox.de
127.0.0.1 jvwbox.de
127.0.0.1 kivwbox.de
127.0.0.1 kvwbox.de
127.0.0.1 livwbox.de
127.0.0.1 mivwbox.de
127.0.0.1 nivwbox.de
127.0.0.1 oivwbox.de
127.0.0.1 ovwbox.de
127.0.0.1 pivwbox.de
127.0.0.1 qivwbox.de
127.0.0.1 rivwbox.de
127.0.0.1 sivwbox.de
127.0.0.1 tivwbox.de
127.0.0.1 uivwbox.de
127.0.0.1 uvwbox.de
127.0.0.1 vivwbox.de
127.0.0.1 viwbox.de
127.0.0.1 vwbox.de
127.0.0.1 wivwbox.de
127.0.0.1 wwivwbox.de
127.0.0.1 www.0ivwbox.de
127.0.0.1 www.1ivwbox.de
127.0.0.1 www.2ivwbox.de
127.0.0.1 www.3ivwbox.de
127.0.0.1 www.4ivwbox.de
127.0.0.1 www.5ivwbox.de
127.0.0.1 www.6ivwbox.de
127.0.0.1 www.7ivwbox.de
127.0.0.1 www.8ivwbox.de
127.0.0.1 www.8vwbox.de
127.0.0.1 www.9ivwbox.de
127.0.0.1 www.9vwbox.de
127.0.0.1 www.aivwbox.de
127.0.0.1 www.avwbox.de
127.0.0.1 www.bivwbox.de
127.0.0.1 www.civwbox.de
127.0.0.1 www.divwbox.de
127.0.0.1 www.eevwbox.de
127.0.0.1 www.eivwbox.de
127.0.0.1 www.evwbox.de
127.0.0.1 www.fivwbox.de
127.0.0.1 www.givwbox.de
127.0.0.1 www.hivwbox.de
127.0.0.1 www.i8vwbox.de
127.0.0.1 www.i9vwbox.de
127.0.0.1 www.iavwbox.de
127.0.0.1 www.ibvwbox.de
127.0.0.1 www.ibwbox.de
127.0.0.1 www.icvwbox.de
127.0.0.1 www.icwbox.de
127.0.0.1 www.ievwbox.de
127.0.0.1 www.ifvwbox.de
127.0.0.1 www.ifwbox.de
127.0.0.1 www.igvwbox.de
127.0.0.1 www.igwbox.de
127.0.0.1 www.iivwbox.de
127.0.0.1 www.ijvwbox.de
127.0.0.1 www.ikvwbox.de
127.0.0.1 www.iovwbox.de
127.0.0.1 www.iuvwbox.de
127.0.0.1 www.iv2box.de
127.0.0.1 www.iv2wbox.de
127.0.0.1 www.iv3box.de
127.0.0.1 www.iv3wbox.de
127.0.0.1 www.ivabox.de
127.0.0.1 www.ivawbox.de
127.0.0.1 www.ivbox.de
127.0.0.1 www.ivbwbox.de
127.0.0.1 www.ivbwox.de
127.0.0.1 www.ivcwbox.de
127.0.0.1 www.ivebox.de
127.0.0.1 www.ivewbox.de
127.0.0.1 www.ivfwbox.de
127.0.0.1 www.ivgwbox.de
127.0.0.1 www.ivqbox.de
127.0.0.1 www.ivqwbox.de
127.0.0.1 www.ivsbox.de
127.0.0.1 www.ivswbox.de
127.0.0.1 www.ivvbox.de
127.0.0.1 www.ivvwbox.de
127.0.0.1 www.ivw2box.de
127.0.0.1 www.ivw3box.de
127.0.0.1 www.ivwabox.de
127.0.0.1 www.ivwb0ox.de
127.0.0.1 www.ivwb0x.de
127.0.0.1 www.ivwb9ox.de
127.0.0.1 www.ivwb9x.de
127.0.0.1 www.ivwbaox.de
127.0.0.1 www.ivwbax.de
127.0.0.1 www.ivwbbox.de
127.0.0.1 www.ivwbeox.de
127.0.0.1 www.ivwbex.de
127.0.0.1 www.ivwbgox.de
127.0.0.1 www.ivwbhox.de
127.0.0.1 www.ivwbiox.de
127.0.0.1 www.ivwbix.de
127.0.0.1 www.ivwbkox.de
127.0.0.1 www.ivwbkx.de
127.0.0.1 www.ivwblox.de
127.0.0.1 www.ivwblx.de
127.0.0.1 www.ivwbnox.de
127.0.0.1 www.ivwbo.de
127.0.0.1 www.ivwbo0x.de
127.0.0.1 www.ivwbo9x.de
127.0.0.1 www.ivwboax.de
127.0.0.1 www.ivwboc.de
127.0.0.1 www.ivwbock.de
127.0.0.1 www.ivwbocx.de
127.0.0.1 www.ivwbod.de
127.0.0.1 www.ivwbodx.de
127.0.0.1 www.ivwboex.de
127.0.0.1 www.ivwboix.de
127.0.0.1 www.ivwboks.de
127.0.0.1 www.ivwbokx.de
127.0.0.1 www.ivwbolx.de
127.0.0.1 www.ivwboox.de
127.0.0.1 www.ivwbopx.de
127.0.0.1 www.ivwbos.de
127.0.0.1 www.ivwbosx.de
127.0.0.1 www.ivwboux.de
127.0.0.1 www.ivwbox.de
127.0.0.1 www.ivwbox0.de
127.0.0.1 www.ivwbox1.de
127.0.0.1 www.ivwbox2.de
127.0.0.1 www.ivwbox3.de
127.0.0.1 www.ivwbox4.de
127.0.0.1 www.ivwbox5.de
127.0.0.1 www.ivwbox6.de
127.0.0.1 www.ivwbox7.de
127.0.0.1 www.ivwbox8.de
127.0.0.1 www.ivwbox9.de
127.0.0.1 www.ivwboxa.de
127.0.0.1 www.ivwboxb.de
127.0.0.1 www.ivwboxc.de
127.0.0.1 www.ivwboxd.de
127.0.0.1 www.ivwboxe.de
127.0.0.1 www.ivwboxes.de
127.0.0.1 www.ivwboxf.de
127.0.0.1 www.ivwboxg.de
127.0.0.1 www.ivwboxh.de
127.0.0.1 www.ivwboxi.de
127.0.0.1 www.ivwboxj.de
127.0.0.1 www.ivwboxk.de
127.0.0.1 www.ivwboxl.de
127.0.0.1 www.ivwboxm.de
127.0.0.1 www.ivwboxn.de
127.0.0.1 www.ivwboxo.de
127.0.0.1 www.ivwboxp.de
127.0.0.1 www.ivwboxq.de
127.0.0.1 www.ivwboxr.de
127.0.0.1 www.ivwboxs.de
127.0.0.1 www.ivwboxt.de
127.0.0.1 www.ivwboxu.de
127.0.0.1 www.ivwboxv.de
127.0.0.1 www.ivwboxw.de
127.0.0.1 www.ivwboxx.de
127.0.0.1 www.ivwboxy.de
127.0.0.1 www.ivwboxz.de
127.0.0.1 www.ivwboyx.de
127.0.0.1 www.ivwboz.de
127.0.0.1 www.ivwbozx.de
127.0.0.1 www.ivwbpox.de
127.0.0.1 www.ivwbpx.de
127.0.0.1 www.ivwbuox.de
127.0.0.1 www.ivwbux.de
127.0.0.1 www.ivwbvox.de
127.0.0.1 www.ivwbx.de
127.0.0.1 www.ivwbxo.de
127.0.0.1 www.ivwbyox.de
127.0.0.1 www.ivwbyx.de
127.0.0.1 www.ivwebox.de
127.0.0.1 www.ivwgbox.de
127.0.0.1 www.ivwgox.de
127.0.0.1 www.ivwhbox.de
127.0.0.1 www.ivwhox.de
127.0.0.1 www.ivwnbox.de
127.0.0.1 www.ivwnox.de
127.0.0.1 www.ivwobx.de
127.0.0.1 www.ivwox.de
127.0.0.1 www.ivwpbox.de
127.0.0.1 www.ivwpox.de
127.0.0.1 www.ivwqbox.de
127.0.0.1 www.ivwsbox.de
127.0.0.1 www.ivwvbox.de
127.0.0.1 www.ivwvox.de
127.0.0.1 www.ivwwbox.de
127.0.0.1 www.iwbox.de
127.0.0.1 www.iwvbox.de
127.0.0.1 www.iwvwbox.de
127.0.0.1 www.iwwbox.de
127.0.0.1 www.iyvwbox.de
127.0.0.1 www.jivwbox.de
127.0.0.1 www.jvwbox.de
127.0.0.1 www.kivwbox.de
127.0.0.1 www.kvwbox.de
127.0.0.1 www.livwbox.de
127.0.0.1 www.mivwbox.de
127.0.0.1 www.nivwbox.de
127.0.0.1 www.oivwbox.de
127.0.0.1 www.ovwbox.de
127.0.0.1 www.pivwbox.de
127.0.0.1 www.qivwbox.de
127.0.0.1 www.rivwbox.de
127.0.0.1 www.sivwbox.de
127.0.0.1 www.tivwbox.de
127.0.0.1 www.uivwbox.de
127.0.0.1 www.uvwbox.de
127.0.0.1 www.vivwbox.de
127.0.0.1 www.viwbox.de
127.0.0.1 www.vwbox.de
127.0.0.1 www.wivwbox.de
127.0.0.1 www.wwivwbox.de
127.0.0.1 www.wwwivwbox.de
127.0.0.1 www.xivwbox.de
127.0.0.1 www.yevwbox.de
127.0.0.1 www.yivwbox.de
127.0.0.1 www.yvwbox.de
127.0.0.1 www.zivwbox.de
127.0.0.1 wwwivwbox.de
127.0.0.1 xivwbox.de
127.0.0.1 yevwbox.de
127.0.0.1 yivwbox.de
127.0.0.1 yvwbox.de
127.0.0.1 zivwbox.de
#</IVW-sites>

#<wiki-spam-sites>

# message board and wiki spam -- these sites are linked in 
    # message board spam and are unlikely to be real sites
127.0.0.1 10pg.scl5fyd.info
127.0.0.1 21jewelry.com
127.0.0.1 24x7.soliday.org
127.0.0.1 2site.com
127.0.0.1 33b.b33r.net
127.0.0.1 48.2mydns.net
127.0.0.1 4allfree.com
127.0.0.1 55.2myip.com
127.0.0.1 6165.rapidforum.com
127.0.0.1 6pg.ryf3hgf.info
127.0.0.1 7x.cc
127.0.0.1 7x7.ruwe.net
127.0.0.1 911.x24hr.com
127.0.0.1 ab.5.p2l.info
127.0.0.1 aboutharrypotter.fasthost.tv
127.0.0.1 aciphex.about-tabs.com
127.0.0.1 actonel.about-tabs.com
127.0.0.1 actos.about-tabs.com
127.0.0.1 acyclovir.1.p2l.info
127.0.0.1 adderall.ourtablets.com
127.0.0.1 adderallxr.freespaces.com
127.0.0.1 adipex.1.p2l.info
127.0.0.1 adipex.24sws.ws
127.0.0.1 adipex.3.p2l.info
127.0.0.1 adipex.4.p2l.info
127.0.0.1 adipex.hut1.ru
127.0.0.1 adipex.ourtablets.com
127.0.0.1 adipex.shengen.ru
127.0.0.1 adipex.t-amo.net
127.0.0.1 adipexp.3xforum.ro
127.0.0.1 adsearch.www1.biz
127.0.0.1 adult.shengen.ru
127.0.0.1 aguileranude.1stOK.com
127.0.0.1 ahh-teens.com
127.0.0.1 aid-golf-golfdust-training.tabrays.com
127.0.0.1 air-plane-ticket.beesearch.info
127.0.0.1 airline-ticket.gloses.net
127.0.0.1 ak.5.p2l.info
127.0.0.1 al.5.p2l.info
127.0.0.1 alcohol-treatment.gloses.net
127.0.0.1 all-sex.shengen.ru
127.0.0.1 allegra.1.p2l.info
127.0.0.1 allergy.1.p2l.info
127.0.0.1 alprazolam.ourtablets.com
127.0.0.1 alprazolamonline.findmenow.info
127.0.0.1 alyssamilano.1stOK.com
127.0.0.1 alyssamilano.ca.tt
127.0.0.1 alyssamilano.home.sapo.pt
127.0.0.1 amateur-mature-sex.adaltabaza.net
127.0.0.1 ambien.1.p2l.info
127.0.0.1 ambien.3.p2l.info
127.0.0.1 ambien.4.p2l.info
127.0.0.1 ambien.ourtablets.com
127.0.0.1 amoxicillin.ourtablets.com
127.0.0.1 angelinajolie.1stOK.com
127.0.0.1 angelinajolie.ca.tt
127.0.0.1 anklets.shengen.ru
127.0.0.1 annanicolesannanicolesmith.ca.tt
127.0.0.1 annanicolesmith.1stOK.com
127.0.0.1 antidepressants.1.p2l.info
127.0.0.1 anxiety.1.p2l.info
127.0.0.1 aol.spb.su
127.0.0.1 ar.5.p2l.info
127.0.0.1 arcade.ya.com
127.0.0.1 armanix.white.prohosting.com
127.0.0.1 arthritis.atspace.com
127.0.0.1 as.5.p2l.info
127.0.0.1 aspirin.about-tabs.com
127.0.0.1 ativan.ourtablets.com
127.0.0.1 austria-car-rental.findworm.net
127.0.0.1 auto.allewagen.de
127.0.0.1 az.5.p2l.info
127.0.0.1 azz.badazz.org
127.0.0.1 balab.portx.net
127.0.0.1 balabass.peerserver.com
127.0.0.1 bbs.ws
127.0.0.1 bc.5.p2l.info
127.0.0.1 beauty.finaltips.com
127.0.0.1 berkleynude.ca.tt
127.0.0.1 bestlolaray.com
127.0.0.1 bet-online.petrovka.info
127.0.0.1 betting-online.petrovka.info
127.0.0.1 bextra-store.shengen.ru
127.0.0.1 bextra.ourtablets.com
127.0.0.1 bingo-online.petrovka.info
127.0.0.1 birth-control.1.p2l.info
127.0.0.1 bontril.1.p2l.info
127.0.0.1 bontril.ourtablets.com
127.0.0.1 br.rawcomm.net
127.0.0.1 britneyspears.1stOK.com
127.0.0.1 britneyspears.ca.tt
127.0.0.1 bupropion-hcl.1.p2l.info
127.0.0.1 buspar.1.p2l.info
127.0.0.1 buspirone.1.p2l.info
127.0.0.1 butalbital-apap.1.p2l.info
127.0.0.1 buy-adipex-cheap-adipex-online.com
127.0.0.1 buy-adipex-online.md-online24.de
127.0.0.1 buy-adipex.aca.ru
127.0.0.1 buy-adipex.hut1.ru
127.0.0.1 buy-adipex.i-jogo.net
127.0.0.1 buy-adipex.petrovka.info
127.0.0.1 buy-carisoprodol.polybuild.ru
127.0.0.1 buy-cheap-phentermine.blogspot.com
127.0.0.1 buy-cheap-xanax.all.at
127.0.0.1 buy-cialis-cheap-cialis-online.info
127.0.0.1 buy-cialis-online.iscool.nl
127.0.0.1 buy-cialis-online.meperdoe.net
127.0.0.1 buy-cialis.freewebtools.com
127.0.0.1 buy-cialis.splinder.com
127.0.0.1 buy-diazepam.connect.to
127.0.0.1 buy-fioricet.hut1.ru
127.0.0.1 buy-flower.petrovka.info
127.0.0.1 buy-hydrocodone-cheap-hydrocodone-online.com
127.0.0.1 buy-hydrocodone-online.tche.com
127.0.0.1 buy-hydrocodone.aca.ru
127.0.0.1 buy-hydrocodone.este.ru
127.0.0.1 buy-hydrocodone.petrovka.info
127.0.0.1 buy-hydrocodone.polybuild.ru
127.0.0.1 buy-hydrocodone.quesaudade.net
127.0.0.1 buy-hydrocodone.scromble.com
127.0.0.1 buy-levitra-cheap-levitra-online.info
127.0.0.1 buy-lortab-cheap-lortab-online.com
127.0.0.1 buy-lortab-online.iscool.nl
127.0.0.1 buy-lortab.hut1.ru
127.0.0.1 buy-phentermine-cheap-phentermine-online.com
127.0.0.1 buy-phentermine-online.135.it
127.0.0.1 buy-phentermine-online.i-jogo.net
127.0.0.1 buy-phentermine-online.i-ltda.net
127.0.0.1 buy-phentermine.hautlynx.com
127.0.0.1 buy-phentermine.polybuild.ru
127.0.0.1 buy-phentermine.thepizza.net
127.0.0.1 buy-tamiflu.asian-flu-vaccine.com
127.0.0.1 buy-ultram-online.iscool.nl
127.0.0.1 buy-valium-cheap-valium-online.com
127.0.0.1 buy-valium.este.ru
127.0.0.1 buy-valium.hut1.ru
127.0.0.1 buy-valium.polybuild.ru
127.0.0.1 buy-viagra.aca.ru
127.0.0.1 buy-viagra.go.to
127.0.0.1 buy-viagra.polybuild.ru
127.0.0.1 buy-vicodin-cheap-vicodin-online.com
127.0.0.1 buy-vicodin-online.i-blog.net
127.0.0.1 buy-vicodin-online.seumala.net
127.0.0.1 buy-vicodin-online.supersite.fr
127.0.0.1 buy-vicodin.dd.vu
127.0.0.1 buy-vicodin.hut1.ru
127.0.0.1 buy-vicodin.iscool.nl
127.0.0.1 buy-xanax-cheap-xanax-online.com
127.0.0.1 buy-xanax-online.amovoce.net
127.0.0.1 buy-xanax.aztecaonline.net
127.0.0.1 buy-xanax.hut1.ru
127.0.0.1 buy-zyban.all.at
127.0.0.1 buycialisonline.7h.com
127.0.0.1 buycialisonline.bigsitecity.com
127.0.0.1 buyfioricet.findmenow.info
127.0.0.1 buyfioricetonline.7h.com
127.0.0.1 buyfioricetonline.bigsitecity.com
127.0.0.1 buyfioricetonline.freeservers.com
127.0.0.1 buyhydrocodone.all.at
127.0.0.1 buyhydrocodoneonline.findmenow.info
127.0.0.1 buylevitra.3xforum.ro
127.0.0.1 buylevitraonline.7h.com
127.0.0.1 buylevitraonline.bigsitecity.com
127.0.0.1 buylortabonline.7h.com
127.0.0.1 buylortabonline.bigsitecity.com
127.0.0.1 buypaxilonline.7h.com
127.0.0.1 buypaxilonline.bigsitecity.com
127.0.0.1 buyphentermineonline.7h.com
127.0.0.1 buyphentermineonline.bigsitecity.com
127.0.0.1 buyvalium.polybuild.ru
127.0.0.1 buyviagra.polybuild.ru
127.0.0.1 buyvicodinonline.veryweird.com
127.0.0.1 bx6.blrf.net
127.0.0.1 ca.5.p2l.info
127.0.0.1 camerondiaznude.1stOK.com
127.0.0.1 camerondiaznude.ca.tt
127.0.0.1 car-donation.shengen.ru
127.0.0.1 car-insurance.inshurance-from.com
127.0.0.1 car-loan.shengen.ru
127.0.0.1 carisoprodol.1.p2l.info
127.0.0.1 carisoprodol.hut1.ru
127.0.0.1 carisoprodol.ourtablets.com
127.0.0.1 carisoprodol.polybuild.ru
127.0.0.1 carisoprodol.shengen.ru
127.0.0.1 carmenelectra.1stOK.com
127.0.0.1 cash-advance.now-cash.com
127.0.0.1 casino-gambling-online.searchservice.info
127.0.0.1 casino-online.100gal.net
127.0.0.1 cat.onlinepeople.net
127.0.0.1 cc5f.dnyp.com
127.0.0.1 celebrex.1.p2l.info
127.0.0.1 celexa.1.p2l.info
127.0.0.1 celexa.3.p2l.info
127.0.0.1 celexa.4.p2l.info
127.0.0.1 cephalexin.ourtablets.com
127.0.0.1 charlizetheron.1stOK.com
127.0.0.1 cheap-adipex.hut1.ru
127.0.0.1 cheap-carisoprodol.polybuild.ru
127.0.0.1 cheap-hydrocodone.go.to
127.0.0.1 cheap-hydrocodone.polybuild.ru
127.0.0.1 cheap-phentermine.polybuild.ru
127.0.0.1 cheap-valium.polybuild.ru
127.0.0.1 cheap-viagra.polybuild.ru
127.0.0.1 cheap-web-hosting-here.blogspot.com
127.0.0.1 cheap-xanax-here.blogspot.com
127.0.0.1 cheapxanax.hut1.ru
127.0.0.1 cialis-finder.com
127.0.0.1 cialis-levitra-viagra.com.cn
127.0.0.1 cialis-store.shengen.ru
127.0.0.1 cialis.1.p2l.info
127.0.0.1 cialis.3.p2l.info
127.0.0.1 cialis.4.p2l.info
127.0.0.1 cialis.ourtablets.com
127.0.0.1 co.5.p2l.info
127.0.0.1 co.dcclan.co.uk
127.0.0.1 codeine.ourtablets.com
127.0.0.1 creampie.afdss.info
127.0.0.1 credit-card-application.now-cash.com
127.0.0.1 credit-cards.shengen.ru
127.0.0.1 ct.5.p2l.info
127.0.0.1 cuiland.info
127.0.0.1 cyclobenzaprine.1.p2l.info
127.0.0.1 cyclobenzaprine.ourtablets.com
127.0.0.1 dal.d.la
127.0.0.1 danger-phentermine.allforyourlife.com
127.0.0.1 darvocet.ourtablets.com
127.0.0.1 dc.5.p2l.info
127.0.0.1 de.5.p2l.info
127.0.0.1 debt.shengen.ru
127.0.0.1 def.5.p2l.info
127.0.0.1 demimoorenude.1stOK.com
127.0.0.1 deniserichards.1stOK.com
127.0.0.1 detox-kit.com
127.0.0.1 detox.shengen.ru
127.0.0.1 diazepam.ourtablets.com
127.0.0.1 diazepam.razma.net
127.0.0.1 diazepam.shengen.ru
127.0.0.1 didrex.1.p2l.info
127.0.0.1 diet-pills.hut1.ru
127.0.0.1 digital-cable-descrambler.planet-high-heels.com
127.0.0.1 dir.opank.com
127.0.0.1 dos.velek.com
127.0.0.1 drewbarrymore.ca.tt
127.0.0.1 drug-online.petrovka.info
127.0.0.1 drug-testing.shengen.ru
127.0.0.1 drugdetox.shengen.ru
127.0.0.1 e-dot.hut1.ru
127.0.0.1 e-hosting.hut1.ru
127.0.0.1 eb.dd.bluelinecomputers.be
127.0.0.1 eb.prout.be
127.0.0.1 ed.at.is13.de
127.0.0.1 ed.at.thamaster.de
127.0.0.1 efam4.info
127.0.0.1 effexor-xr.1.p2l.info
127.0.0.1 ei.imbucurator-de-prost.com
127.0.0.1 eminemticket.freespaces.com
127.0.0.1 en.dd.blueline.be
127.0.0.1 en.ultrex.ru
127.0.0.1 enpresse.1.p2l.info
127.0.0.1 epson-printer-ink.beesearch.info
127.0.0.1 erectile.byethost33.com
127.0.0.1 esgic.1.p2l.info
127.0.0.1 fahrrad.bikesshop.de
127.0.0.1 famous-pics.com
127.0.0.1 famvir.1.p2l.info
127.0.0.1 farmius.org
127.0.0.1 fee-hydrocodone.bebto.com
127.0.0.1 female-v.1.p2l.info
127.0.0.1 femaleviagra.findmenow.info
127.0.0.1 fg.softguy.com
127.0.0.1 findmenow.info
127.0.0.1 fioricet-online.blogspot.com
127.0.0.1 fioricet.1.p2l.info
127.0.0.1 fioricet.3.p2l.info
127.0.0.1 fioricet.4.p2l.info
127.0.0.1 firstfinda.info
127.0.0.1 fl.5.p2l.info
127.0.0.1 flexeril.1.p2l.info
127.0.0.1 flextra.1.p2l.info
127.0.0.1 flonase.1.p2l.info
127.0.0.1 flonase.3.p2l.info
127.0.0.1 flonase.4.p2l.info
127.0.0.1 florineff.ql.st
127.0.0.1 flower-online.petrovka.info
127.0.0.1 fluoxetine.1.p2l.info
127.0.0.1 fo4n.com
127.0.0.1 forex-broker.hut1.ru
127.0.0.1 forex-chart.hut1.ru
127.0.0.1 forex-market.hut1.ru
127.0.0.1 forex-news.hut1.ru
127.0.0.1 forex-online.hut1.ru
127.0.0.1 forex-signal.hut1.ru
127.0.0.1 forex-trade.hut1.ru
127.0.0.1 forex-trading-benefits.blogspot.com
127.0.0.1 forextrading.hut1.ru
127.0.0.1 free-money.host.sk
127.0.0.1 free-viagra.polybuild.ru
127.0.0.1 free-virus-scan.100gal.net
127.0.0.1 free.hostdepartment.com
127.0.0.1 freechat.llil.de
127.0.0.1 ga.5.p2l.info
127.0.0.1 game-online-video.petrovka.info
127.0.0.1 gaming-online.petrovka.info
127.0.0.1 gastrointestinal.1.p2l.info
127.0.0.1 gen-hydrocodone.polybuild.ru
127.0.0.1 getcarisoprodol.polybuild.ru
127.0.0.1 gocarisoprodol.polybuild.ru
127.0.0.1 gsm-mobile-phone.beesearch.info
127.0.0.1 gu.5.p2l.info
127.0.0.1 guerria-skateboard-tommy.tabrays.com
127.0.0.1 gwynethpaltrow.ca.tt
127.0.0.1 h1.ripway.com
127.0.0.1 hair-dos.resourcesarchive.com
127.0.0.1 halleberrynude.ca.tt
127.0.0.1 heathergraham.ca.tt
127.0.0.1 herpes.1.p2l.info
127.0.0.1 herpes.3.p2l.info
127.0.0.1 herpes.4.p2l.info
127.0.0.1 hf.themafia.info
127.0.0.1 hi.5.p2l.info
127.0.0.1 hi.pacehillel.org
127.0.0.1 holobumo.info
127.0.0.1 homehre.bravehost.com
127.0.0.1 homehre.ifrance.com
127.0.0.1 homehre.tripod.com
127.0.0.1 hoodia.kogaryu.com
127.0.0.1 hotel-las-vegas.gloses.net
127.0.0.1 hydro.polybuild.ru
127.0.0.1 hydrocodone-buy-online.blogspot.com
127.0.0.1 hydrocodone.irondel.swisshost.by
127.0.0.1 hydrocodone.on.to
127.0.0.1 hydrocodone.shengen.ru
127.0.0.1 hydrocodone.t-amo.net
127.0.0.1 hydrocodone.visa-usa.ru
127.0.0.1 ia.5.p2l.info
127.0.0.1 ia.warnet-thunder.net
127.0.0.1 ibm-notebook-battery.wp-club.net
127.0.0.1 id.5.p2l.info
127.0.0.1 il.5.p2l.info
127.0.0.1 imitrex.1.p2l.info
127.0.0.1 imitrex.3.p2l.info
127.0.0.1 imitrex.4.p2l.info
127.0.0.1 in.5.p2l.info
127.0.0.1 ionamin.1.p2l.info
127.0.0.1 ionamin.t35.com
127.0.0.1 irondel.swisshost.by
127.0.0.1 japanese-girl-xxx.com
127.0.0.1 java-games.bestxs.de
127.0.0.1 jg.hack-inter.net
127.0.0.1 job-online.petrovka.info
127.0.0.1 jobs-online.petrovka.info
127.0.0.1 kitchen-island.mensk.us
127.0.0.1 konstantin.freespaces.com
127.0.0.1 ks.5.p2l.info
127.0.0.1 ky.5.p2l.info
127.0.0.1 la.5.p2l.info
127.0.0.1 lamictal.about-tabs.com
127.0.0.1 lamisil.about-tabs.com
127.0.0.1 levitra.1.p2l.info
127.0.0.1 levitra.3.p2l.info
127.0.0.1 levitra.4.p2l.info
127.0.0.1 lexapro.1.p2l.info
127.0.0.1 lexapro.3.p2l.info
127.0.0.1 lexapro.4.p2l.info
127.0.0.1 lo.ljkeefeco.com
127.0.0.1 loan.aol.msk.su
127.0.0.1 loan.maybachexelero.org
127.0.0.1 loestrin.1.p2l.info
127.0.0.1 lol.to
127.0.0.1 lortab-cod.hut1.ru
127.0.0.1 lortab.hut1.ru
127.0.0.1 ma.5.p2l.info
127.0.0.1 mailforfreedom.com
127.0.0.1 make-money.shengen.ru
127.0.0.1 maps-antivert58.eksuziv.net
127.0.0.1 maps-spyware251-300.eksuziv.net
127.0.0.1 marketing.beesearch.info
127.0.0.1 mb.5.p2l.info
127.0.0.1 mba-online.petrovka.info
127.0.0.1 md.5.p2l.info
127.0.0.1 me.5.p2l.info
127.0.0.1 medical.carway.net
127.0.0.1 mens.1.p2l.info
127.0.0.1 meridia.1.p2l.info
127.0.0.1 meridia.3.p2l.info
127.0.0.1 meridia.4.p2l.info
127.0.0.1 meridiameridia.3xforum.ro
127.0.0.1 mesotherapy.jino-net.ru
127.0.0.1 mi.5.p2l.info
127.0.0.1 micardiss.ql.st
127.0.0.1 microsoft-sql-server.wp-club.net
127.0.0.1 mn.5.p2l.info
127.0.0.1 mo.5.p2l.info
127.0.0.1 moc.silk.com
127.0.0.1 mortgage-memphis.hotmail.ru
127.0.0.1 mortgage-rates.now-cash.com
127.0.0.1 mp.5.p2l.info
127.0.0.1 mrjeweller.us
127.0.0.1 ms.5.p2l.info
127.0.0.1 mt.5.p2l.info
127.0.0.1 multimedia-projector.katrina.ru
127.0.0.1 muscle-relaxers.1.p2l.info
127.0.0.1 music102.awardspace.com
127.0.0.1 mydaddy.b0x.com
127.0.0.1 myphentermine.polybuild.ru
127.0.0.1 nasacort.1.p2l.info
127.0.0.1 nasonex.1.p2l.info
127.0.0.1 nb.5.p2l.info
127.0.0.1 nc.5.p2l.info
127.0.0.1 nd.5.p2l.info
127.0.0.1 ne.5.p2l.info
127.0.0.1 nellyticket.beast-space.com
127.0.0.1 nelsongod.ca
127.0.0.1 nexium.1.p2l.info
127.0.0.1 nextel-ringtone.komi.su
127.0.0.1 nextel-ringtone.spb.su
127.0.0.1 nf.5.p2l.info
127.0.0.1 nh.5.p2l.info
127.0.0.1 nj.5.p2l.info
127.0.0.1 nm.5.p2l.info
127.0.0.1 nordette.1.p2l.info
127.0.0.1 nordette.3.p2l.info
127.0.0.1 nordette.4.p2l.info
127.0.0.1 norton-antivirus-trial.searchservice.info
127.0.0.1 notebook-memory.searchservice.info
127.0.0.1 ns.5.p2l.info
127.0.0.1 nv.5.p2l.info
127.0.0.1 ny.5.p2l.info
127.0.0.1 o8.aus.cc
127.0.0.1 ofni.al0ne.info
127.0.0.1 oh.5.p2l.info
127.0.0.1 ok.5.p2l.info
127.0.0.1 on.5.p2l.info
127.0.0.1 online-auto-insurance.petrovka.info
127.0.0.1 online-bingo.petrovka.info
127.0.0.1 online-broker.petrovka.info
127.0.0.1 online-cash.petrovka.info
127.0.0.1 online-casino.shengen.ru
127.0.0.1 online-casino.webpark.pl
127.0.0.1 online-cigarettes.hitslog.net
127.0.0.1 online-college.petrovka.info
127.0.0.1 online-degree.petrovka.info
127.0.0.1 online-florist.petrovka.info
127.0.0.1 online-forex-trading-systems.blogspot.com
127.0.0.1 online-forex.hut1.ru
127.0.0.1 online-gaming.petrovka.info
127.0.0.1 online-job.petrovka.info
127.0.0.1 online-loan.petrovka.info
127.0.0.1 online-mortgage.petrovka.info
127.0.0.1 online-personal.petrovka.info
127.0.0.1 online-personals.petrovka.info
127.0.0.1 online-pharmacy-online.blogspot.com
127.0.0.1 online-pharmacy.petrovka.info
127.0.0.1 online-phentermine.petrovka.info
127.0.0.1 online-poker-gambling.petrovka.info
127.0.0.1 online-poker-game.petrovka.info
127.0.0.1 online-poker.shengen.ru
127.0.0.1 online-prescription.petrovka.info
127.0.0.1 online-school.petrovka.info
127.0.0.1 online-schools.petrovka.info
127.0.0.1 online-single.petrovka.info
127.0.0.1 online-tarot-reading.beesearch.info
127.0.0.1 online-travel.petrovka.info
127.0.0.1 online-university.petrovka.info
127.0.0.1 online-viagra.petrovka.info
127.0.0.1 online-xanax.petrovka.info
127.0.0.1 only-valium.go.to
127.0.0.1 only-valium.shengen.ru
127.0.0.1 onlypreteens.com
127.0.0.1 or.5.p2l.info
127.0.0.1 oranla.info
127.0.0.1 order-hydrocodone.polybuild.ru
127.0.0.1 order-phentermine.polybuild.ru
127.0.0.1 order-valium.polybuild.ru
127.0.0.1 orderadipex.findmenow.info
127.0.0.1 ortho-tri-cyclen.1.p2l.info
127.0.0.1 pa.5.p2l.info
127.0.0.1 pacific-poker.e-online-poker-4u.net
127.0.0.1 pain-relief.1.p2l.info
127.0.0.1 paintball-gun.tripod.com
127.0.0.1 patio-furniture.dreamhoster.com
127.0.0.1 paxil.1.p2l.info
127.0.0.1 pay-day-loans.beesearch.info
127.0.0.1 payday-loans.now-cash.com
127.0.0.1 pctuzing.php5.cz
127.0.0.1 pd1.funnyhost.com
127.0.0.1 pe.5.p2l.info
127.0.0.1 peter-north-cum-shot.blogspot.com
127.0.0.1 pets.finaltips.com
127.0.0.1 pharmacy-canada.forsearch.net
127.0.0.1 pharmacy-news.blogspot.com
127.0.0.1 pharmacy-online.petrovka.info
127.0.0.1 pharmacy.hut1.ru
127.0.0.1 phendimetrazine.1.p2l.info
127.0.0.1 phentermine-buy-online.hitslog.net
127.0.0.1 phentermine-buy.petrovka.info
127.0.0.1 phentermine-online.iscool.nl
127.0.0.1 phentermine-online.petrovka.info
127.0.0.1 phentermine.1.p2l.info
127.0.0.1 phentermine.3.p2l.info
127.0.0.1 phentermine.4.p2l.info
127.0.0.1 phentermine.aussie7.com
127.0.0.1 phentermine.petrovka.info
127.0.0.1 phentermine.polybuild.ru
127.0.0.1 phentermine.shengen.ru
127.0.0.1 phentermine.t-amo.net
127.0.0.1 phentermine.webpark.pl
127.0.0.1 phone-calling-card.exnet.su
127.0.0.1 plavix.shengen.ru
127.0.0.1 play-poker-free.forsearch.net
127.0.0.1 poker-games.e-online-poker-4u.net
127.0.0.1 pop.egi.biz
127.0.0.1 pr.5.p2l.info
127.0.0.1 prescription-drugs.easy-find.net
127.0.0.1 prescription-drugs.shengen.ru
127.0.0.1 preteenland.com
127.0.0.1 preteensite.com
127.0.0.1 prevacid.1.p2l.info
127.0.0.1 prevent-asian-flu.com
127.0.0.1 prilosec.1.p2l.info
127.0.0.1 propecia.1.p2l.info
127.0.0.1 protonix.shengen.ru
127.0.0.1 psorias.atspace.com
127.0.0.1 purchase.hut1.ru
127.0.0.1 qc.5.p2l.info
127.0.0.1 qz.informs.com
127.0.0.1 re.rutan.org
127.0.0.1 refinance.shengen.ru
127.0.0.1 relenza.asian-flu-vaccine.com
127.0.0.1 renova.1.p2l.info
127.0.0.1 replacement-windows.gloses.net
127.0.0.1 resanium.com
127.0.0.1 retin-a.1.p2l.info
127.0.0.1 ri.5.p2l.info
127.0.0.1 rise-media.ru
127.0.0.1 root.dns.bz
127.0.0.1 roulette-online.petrovka.info
127.0.0.1 router.googlecom.biz
127.0.0.1 s32.bilsay.com
127.0.0.1 samsclub33.pochta.ru
127.0.0.1 sc.5.p2l.info
127.0.0.1 sc10.net
127.0.0.1 sd.5.p2l.info
127.0.0.1 search-phentermine.hpage.net
127.0.0.1 search4you.50webs.com
127.0.0.1 searchpill.boom.ru
127.0.0.1 seasonale.1.p2l.info
127.0.0.1 shop.kauffes.de
127.0.0.1 single-online.petrovka.info
127.0.0.1 sk.5.p2l.info
127.0.0.1 skelaxin.1.p2l.info
127.0.0.1 skelaxin.3.p2l.info
127.0.0.1 skelaxin.4.p2l.info
127.0.0.1 skin-care.1.p2l.info
127.0.0.1 skocz.pl
127.0.0.1 sleep-aids.1.p2l.info
127.0.0.1 sleeper-sofa.dreamhoster.com
127.0.0.1 slf5cyd.info
127.0.0.1 sobolev.net.ru
127.0.0.1 soma-store.visa-usa.ru
127.0.0.1 soma.1.p2l.info
127.0.0.1 soma.3xforum.ro
127.0.0.1 sonata.1.p2l.info
127.0.0.1 sport-betting-online.hitslog.net
127.0.0.1 spyware-removers.shengen.ru
127.0.0.1 spyware-scan.100gal.net
127.0.0.1 spyware.usafreespace.com
127.0.0.1 sq7.co.uk
127.0.0.1 sql-server-driver.beesearch.info
127.0.0.1 starlix.ql.st
127.0.0.1 stop-smoking.1.p2l.info
127.0.0.1 supplements.1.p2l.info
127.0.0.1 sx.nazari.org
127.0.0.1 sx.z0rz.com
127.0.0.1 ta.at.ic5mp.net
127.0.0.1 ta.at.user-mode-linux.net
127.0.0.1 tamiflu-in-canada.asian-flu-vaccine.com
127.0.0.1 tamiflu-no-prescription.asian-flu-vaccine.com
127.0.0.1 tamiflu-purchase.asian-flu-vaccine.com
127.0.0.1 tamiflu-without-prescription.asian-flu-vaccine.com
127.0.0.1 tenuate.1.p2l.info
127.0.0.1 texas-hold-em.e-online-poker-4u.net
127.0.0.1 texas-holdem.shengen.ru
127.0.0.1 ticket20.tripod.com
127.0.0.1 tizanidine.1.p2l.info
127.0.0.1 tn.5.p2l.info
127.0.0.1 top.pcanywhere.net
127.0.0.1 topmeds10.com
127.0.0.1 toyota.cyberealhosting.com
127.0.0.1 tramadol.1.p2l.info
127.0.0.1 tramadol.3.p2l.info
127.0.0.1 tramadol.4.p2l.info
127.0.0.1 tramadol2006.3xforum.ro
127.0.0.1 travel-insurance-quotes.beesearch.info
127.0.0.1 triphasil.1.p2l.info
127.0.0.1 triphasil.3.p2l.info
127.0.0.1 triphasil.4.p2l.info
127.0.0.1 tx.5.p2l.info
127.0.0.1 uf2aasn.111adfueo.us
127.0.0.1 ultracet.1.p2l.info
127.0.0.1 ultram.1.p2l.info
127.0.0.1 united-airline-fare.100pantyhose.com
127.0.0.1 university-online.petrovka.info
127.0.0.1 urlcut.net
127.0.0.1 urshort.net
127.0.0.1 us.kopuz.com
127.0.0.1 ut.5.p2l.info
127.0.0.1 utairway.com
127.0.0.1 va.5.p2l.info
127.0.0.1 vacation.toppick.info
127.0.0.1 valium.este.ru
127.0.0.1 valium.hut1.ru
127.0.0.1 valium.ourtablets.com
127.0.0.1 valium.polybuild.ru
127.0.0.1 valiumvalium.3xforum.ro
127.0.0.1 valtrex.1.p2l.info
127.0.0.1 valtrex.3.p2l.info
127.0.0.1 valtrex.4.p2l.info
127.0.0.1 valtrex.7h.com
127.0.0.1 vaniqa.1.p2l.info
127.0.0.1 vi.5.p2l.info
127.0.0.1 viagra-online.petrovka.info
127.0.0.1 viagra-pill.blogspot.com
127.0.0.1 viagra-soft-tabs.1.p2l.info
127.0.0.1 viagra-store.shengen.ru
127.0.0.1 viagra.1.p2l.info
127.0.0.1 viagra.3.p2l.info
127.0.0.1 viagra.4.p2l.info
127.0.0.1 viagra.polybuild.ru
127.0.0.1 viagraviagra.3xforum.ro
127.0.0.1 vicodin-online.petrovka.info
127.0.0.1 vicodin-store.shengen.ru
127.0.0.1 vicodin.t-amo.net
127.0.0.1 viewtools.com
127.0.0.1 vioxx.1.p2l.info
127.0.0.1 vitalitymax.1.p2l.info
127.0.0.1 vt.5.p2l.info
127.0.0.1 vxv.phre.net
127.0.0.1 w0.drag0n.org
127.0.0.1 wa.5.p2l.info
127.0.0.1 water-bed.8p.org.uk
127.0.0.1 web-hosting.hitslog.net
127.0.0.1 webhosting.hut1.ru
127.0.0.1 weborg.hut1.ru
127.0.0.1 weight-loss.1.p2l.info
127.0.0.1 weight-loss.3.p2l.info
127.0.0.1 weight-loss.4.p2l.info
127.0.0.1 weight-loss.hut1.ru
127.0.0.1 wellbutrin.1.p2l.info
127.0.0.1 wellbutrin.3.p2l.info
127.0.0.1 wellbutrin.4.p2l.info
127.0.0.1 wellnessmonitor.bravehost.com
127.0.0.1 wi.5.p2l.info
127.0.0.1 world-trade-center.hawaiicity.com
127.0.0.1 wp-club.net
127.0.0.1 ws01.do.nu
127.0.0.1 ws02.do.nu
127.0.0.1 ws03.do.nu
127.0.0.1 ws03.home.sapo.pt
127.0.0.1 ws04.do.nu
127.0.0.1 ws04.home.sapo.pt
127.0.0.1 ws05.home.sapo.pt
127.0.0.1 ws06.home.sapo.pt
127.0.0.1 wv.5.p2l.info
127.0.0.1 www.31d.net
127.0.0.1 www.adspoll.com
127.0.0.1 www.adult-top-list.com
127.0.0.1 www.aektschen.de
127.0.0.1 www.aeqs.com
127.0.0.1 www.alladultdirectories.com
127.0.0.1 www.alladultdirectory.net
127.0.0.1 www.arbeitssuche-web.de
127.0.0.1 www.atlantis-asia.com
127.0.0.1 www.bestrxpills.com
127.0.0.1 www.bigsister-puff.cxa.de
127.0.0.1 www.bigsister.cxa.de
127.0.0.1 www.bitlocker.net
127.0.0.1 www.cheap-laptops-notebook-computers.info
127.0.0.1 www.cheap-online-stamp.cast.cc
127.0.0.1 www.codez-knacken.de
127.0.0.1 www.computerxchange.com
127.0.0.1 www.credit-dreams.com
127.0.0.1 www.edle-stuecke.de
127.0.0.1 www.exe-file.de
127.0.0.1 www.exttrem.de
127.0.0.1 www.fetisch-pornos.cxa.de
127.0.0.1 www.ficken-ficken-ficken.cxa.de
127.0.0.1 www.ficken-xxx.cxa.de
127.0.0.1 www.financial-advice-books.com
127.0.0.1 www.finanzmarkt2004.de
127.0.0.1 www.furnitureulimited.com
127.0.0.1 www.gewinnspiele-slotmachine.de
127.0.0.1 www.hardware4freaks.de
127.0.0.1 www.healthyaltprods.com
127.0.0.1 www.heimlich-gefilmt.cxa.de
127.0.0.1 www.huberts-kochseite.de
127.0.0.1 www.huren-verzeichnis.is4all.de
127.0.0.1 www.kaaza-legal.de
127.0.0.1 www.kajahdfssa.net
127.0.0.1 www.keyofhealth.com
127.0.0.1 www.kitchentablegang.org
127.0.0.1 www.km69.de
127.0.0.1 www.koch-backrezepte.de
127.0.0.1 www.kvr-systems.de
127.0.0.1 www.lesben-pornos.cxa.de
127.0.0.1 www.links-private-krankenversicherung.de
127.0.0.1 www.littledevildoubt.com
127.0.0.1 www.mailforfreedom.com
127.0.0.1 www.masterspace.biz
127.0.0.1 www.medical-research-books.com
127.0.0.1 www.microsoft2010.com
127.0.0.1 www.nelsongod.ca
127.0.0.1 www.nextstudent.com
127.0.0.1 www.ntdesk.de
127.0.0.1 www.nutten-verzeichnis.cxa.de
127.0.0.1 www.obesitycheck.com
127.0.0.1 www.pawnauctions.net
127.0.0.1 www.pills-home.com
127.0.0.1 www.poker-new.com
127.0.0.1 www.poker-unique.com
127.0.0.1 www.poker4spain.com
127.0.0.1 www.porno-lesben.cxa.de
127.0.0.1 www.prevent-asian-flu.com
127.0.0.1 www.randppro-cuts.com
127.0.0.1 www.romanticmaui.net
127.0.0.1 www.salldo.de
127.0.0.1 www.samsclub33.pochta.ru
127.0.0.1 www.schwarz-weisses.de
127.0.0.1 www.schwule-boys-nackt.cxa.de
127.0.0.1 www.shopping-artikel.de
127.0.0.1 www.showcaserealestate.net
127.0.0.1 www.skattabrain.com
127.0.0.1 www.softcha.com
127.0.0.1 www.striemline.de
127.0.0.1 www.talentbroker.net
127.0.0.1 www.the-discount-store.com
127.0.0.1 www.topmeds10.com
127.0.0.1 www.uniqueinternettexasholdempoker.com
127.0.0.1 www.viagra-home.com
127.0.0.1 www.vthought.com
127.0.0.1 www.vtoyshop.com
127.0.0.1 www.vulcannonibird.de
127.0.0.1 www.webabrufe.de
127.0.0.1 www.wilddreams.info
127.0.0.1 www.willcommen.de
127.0.0.1 www.xcr-286.com
127.0.0.1 www3.ddns.ms
127.0.0.1 www4.at.debianbase.de
127.0.0.1 www4.epac.to
127.0.0.1 www5.3-a.net
127.0.0.1 www6.ezua.com
127.0.0.1 www6.ns1.name
127.0.0.1 www69.bestdeals.at
127.0.0.1 www69.byinter.net
127.0.0.1 www69.dynu.com
127.0.0.1 www69.findhere.org
127.0.0.1 www69.fw.nu
127.0.0.1 www69.ugly.as
127.0.0.1 www7.ygto.com
127.0.0.1 www8.ns01.us
127.0.0.1 www9.compblue.com
127.0.0.1 www9.servequake.com
127.0.0.1 www9.trickip.org
127.0.0.1 www99.bounceme.net
127.0.0.1 www99.fdns.net
127.0.0.1 www99.zapto.org
127.0.0.1 wy.5.p2l.info
127.0.0.1 x-box.t35.com
127.0.0.1 x-hydrocodone.info
127.0.0.1 x-phentermine.info
127.0.0.1 x25.2mydns.com
127.0.0.1 x25.plorp.com
127.0.0.1 x4.lov3.net
127.0.0.1 x6x.a.la
127.0.0.1 x888x.myserver.org
127.0.0.1 x8x.dyndns.dk
127.0.0.1 x8x.trickip.net
127.0.0.1 xanax-online.dot.de
127.0.0.1 xanax-online.run.to
127.0.0.1 xanax-online.sms2.us
127.0.0.1 xanax-store.shengen.ru
127.0.0.1 xanax.ourtablets.com
127.0.0.1 xanax.t-amo.net
127.0.0.1 xanaxxanax.3xforum.ro
127.0.0.1 xcr-286.com
127.0.0.1 xenical.1.p2l.info
127.0.0.1 xenical.3.p2l.info
127.0.0.1 xenical.4.p2l.info
127.0.0.1 xoomer.alice.it
127.0.0.1 xr.h4ck.la
127.0.0.1 yasmin.1.p2l.info
127.0.0.1 yasmin.3.p2l.info
127.0.0.1 yasmin.4.p2l.info
127.0.0.1 yt.5.p2l.info
127.0.0.1 zanaflex.1.p2l.info
127.0.0.1 zebutal.1.p2l.info
127.0.0.1 zocor.about-tabs.com
127.0.0.1 zoloft.1.p2l.info
127.0.0.1 zoloft.3.p2l.info
127.0.0.1 zoloft.4.p2l.info
127.0.0.1 zoloft.about-tabs.com
127.0.0.1 zyban-store.shengen.ru
127.0.0.1 zyban.1.p2l.info
127.0.0.1 zyban.about-tabs.com
127.0.0.1 zyprexa.about-tabs.com
127.0.0.1 zyrtec.1.p2l.info
127.0.0.1 zyrtec.3.p2l.info
127.0.0.1 zyrtec.4.p2l.info
#</wiki-spam-sites>

# Acknowledgements
# I would like to thank the following people for submitting sites, and
# helping promote the site.

# Bill Allison, Harj Basi, Lance Russhing, Marshall Drew-Brook, 
#  Leigh Brasington, Scott Terbush, Cary Newfeldt, Kaye, Jeff
#  Scrivener, Mark Hudson, Matt Bells, T. Kim Nguyen, Lino Demasi,
#  Marcelo Volmaro, Troy Martin, Donald Kerns, B.Patten-Walsh,
#  bobeangi, Chris Maniscalco, George Gilbert, Kim Nilsson, zeromus,
#  Robert Petty, Rob Morrison, Clive Smith, Cecilia Varni, OleKing 
#  Cole, William Jones, Brian Small, Raj Tailor, Richard Heritage,
#  Alan Harrison, Ordorica, Crimson, Joseph Cianci, sirapacz, 
#  Dvixen, Matthew Craig, Tobias Hessem, Kevin F. Quinn, Thomas 
#  Corthals, Chris McBee, Jaime A. Guerra, Anders Josefson, 
#  Simon Manderson, Spectre Ghost, Darren Tay, Dallas Eschenauer, Cecilia
#  Varni, Adam P. Cole, George Lefkaditis, grzesiek, Adam Howard, Mike 
#  Bizon, Samuel P. Mallare, Leinweber, Walter Novak, Stephen Genus, 
#  Zube, Johny Provoost, Peter Grafton, Johann Burkard, Magus, Ron Karner,
#  Fredrik Dahlman, Michele Cybula, Bernard Conlu, Riku B, Twillers, 
#  Shaika-Dzari, Vartkes Goetcherian, Michael McCown, Garth, Richard Nairn,
#  Exzar Reed, Robert Gauthier, Floyd Wilder, Mark Drissel, Kenny Lyons,
#  Paul Dunne, Tirath Pannu, Mike Lambert, Dan Kolcun, Daniel Aleksandersen,
#  Chris Heegard, Miles Golding, Daniel Bisca, Frederic Begou, Charles 
#  Fordyce, Mark Lehrer, Sebastien Nadeau-Jean, Russell Gordon, Alexey 
#  Gopachenko, Stirling Pearson, Alan Segal, Bobin Joseph, Chris Wall, Sean
#  Flesch, Brent Getz, Jerry Cain, Brian Micek, Lee Hancock, Kay Thiele,
#  Kwan Ting Chan, Wladimir Labeikovsky, Lino Demasi, Bowie Bailey, Andreas 
#  Marschall, Michael Tompkins, Michael ODonnell, and Jos� Lucas Teixeira
#  de Oliveira for helping to build the hosts file.
# Russell OConnor for OS/2 information
# kwadronaut for Windows 7 and Vista information
# John Mueller and Lawrence H Smith for Mac Pre-OSX information
# Jesse Baird for the Cisco IOS script
' >> /etc/hosts

