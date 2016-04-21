#!/bin/sh
#
# *** MANAGED BY PUPPET - DO NOT EDIT DIRECTLY! ***
#

export REPOSYNC_CONF=/data/tools/reposync.vmware-tools.conf
export YUM_DIR=/data/www/html/vmware

/usr/bin/reposync -q -c $REPOSYNC_CONF -p $YUM_DIR -r esx4.1-5-x86_64 -n
/usr/bin/reposync -q -c $REPOSYNC_CONF -p $YUM_DIR -r esx4.1-6-x86_64 -n
/usr/bin/reposync -q -c $REPOSYNC_CONF -p $YUM_DIR -r esx5.1-5-x86_64 -n
/usr/bin/reposync -q -c $REPOSYNC_CONF -p $YUM_DIR -r esx5.1-6-x86_64 -n
/usr/bin/reposync -q -c $REPOSYNC_CONF -p $YUM_DIR -r esx6.0-5-x86_64 -n
/usr/bin/reposync -q -c $REPOSYNC_CONF -p $YUM_DIR -r esx6.0-6-x86_64 -n

/usr/bin/createrepo -s sha $YUM_DIR/esx4.1-5-x86_64
/usr/bin/createrepo $YUM_DIR/esx4.1-6-x86_64
/usr/bin/createrepo -s sha $YUM_DIR/esx5.1-5-x86_64
/usr/bin/createrepo $YUM_DIR/esx5.1-6-x86_64
/usr/bin/createrepo -s sha $YUM_DIR/esx6.0-5-x86_64
/usr/bin/createrepo $YUM_DIR/esx6.0-6-x86_64

/usr/bin/wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub -O $YUM_DIR/VMWARE-PACKAGING-GPG-RSA-KEY.pub
