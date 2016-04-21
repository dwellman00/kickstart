#!/bin/sh
#
# *** MANAGED BY PUPPET - DO NOT EDIT DIRECTLY! ***
#

rsync="/usr/bin/rsync -avHz --delete --delay-updates --exclude=i386 --exclude=drpms"
mirror=rsync://mirrors.kernel.org/centos

verlist="6.7"
archlist="x86_64"
baselist="os updates extras"
local=/data/www/html/CentOS

for ver in $verlist
do
  for arch in $archlist
  do
    for base in $baselist
    do
        remote=$mirror/$ver/$base/$arch/
        $rsync $remote $local/$ver/$base/$arch/
    done
  done
done

$rsync $mirror/RPM-GPG-KEY-CentOS-6 $local/RPM-GPG-KEY-CentOS-6
