#!/bin/sh -e
hostname=$1
device=$2
file=$HOME/scripts/dynv6/.dynv6.addr6
PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin"
[ -e $file ] && old=`cat $file`

if [ -z "$hostname" -o -z "$token" ]; then
  echo "Usage: token=<your-authentication-token> [netmask=64] $0 your-name.dynv6.net [device]"
  exit 1
fi

if [ -z "$netmask" ]; then
  netmask=128
fi

if [ -n "$device" ]; then
  device="dev $device"
fi
address=$(ip -6 addr list scope global $device | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)

if [ -e /usr/bin/curl ]; then
  bin="curl -fsS"
elif [ -e /usr/bin/wget ]; then
  bin="wget -O-"
else
  echo "neither curl nor wget found"
  exit 1
fi

if [ -z "$address" ]; then
  echo "no IPv6 address found"
  exit 1
fi

# address with netmask
current=$address/$netmask

if [ "$old" = "$current" ]; then
  echo "IPv6 address unchanged"
else
  $bin "http://dynv6.com/api/update?hostname=$hostname&ipv6=$current&token=$token"
fi

# send addresses to dynv6
$bin "http://ipv4.dynv6.com/api/update?hostname=$hostname&ipv4=auto&token=$token"

# save current address
echo $current > $file
