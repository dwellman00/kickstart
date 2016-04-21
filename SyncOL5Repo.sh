#!/bin/sh
#
# *** MANAGED BY PUPPET - DO NOT EDIT DIRECTLY! ***
#

verlist="5.11"
archlist="x86_64"
repolist="ol5_UEK_latest ol5_u11_base"
local=/data/www/html/OracleLinux

for ver in $verlist
do
  for arch in $archlist
  do
    for repoid in $repolist
    do
        /usr/bin/reposync -q --repoid=${repoid} --arch=${arch} -p ${local}/${ver}/${arch}
	/usr/bin/createrepo -s sha ${local}/${ver}/${arch}/${repoid}
    done
  done
done

#$rsync $mirror/RPM-GPG-KEY-CentOS-6 $local/RPM-GPG-KEY-CentOS-6
