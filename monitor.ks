install
url --url http://ks1.domain.com/CentOS/6.6/os/x86_64
lang en_US.UTF-8
keyboard us
timezone --utc  America/Los_Angeles
rootpw --iscrypted <encrypted>
selinux --permissive
firewall --service=ssh
authconfig --enableshadow --passalgo=sha512

# Wipe all partitions and build them with the info below
clearpart --all --drives=sda --initlabel

#ignoredisk --only-use=sda

# gets rid of Storage Device Warning error
zerombr yes
 
# Create the bootloader in the MBR with drive sda being the drive to install it on
bootloader --location=mbr --driveorder=sda

part /boot --fstype=ext4 --size=500

part pv.01 --grow --size=1

volgroup vg00 pv.01

logvol / --fstype=ext4 --name=lv00 --vgname=vg00 --size=12288
logvol swap --name=lv01 --vgname=vg00 --size=4096
logvol /var --fstype=ext4 --name=lv02 --vgname=vg00 --size=6144
logvol /export/disk1 --fstype=ext4 --name=lv03 --vgname=vg00 --grow --size=1

reboot


%packages
@base
@console-internet
@core
@debugging
@directory-client
@hardware-monitoring
@java-platform
@large-systems
@network-file-system-client
@performance
@perl-runtime
@server-platform
@server-policy
@workstation-policy
pax
oddjob
sgpio
device-mapper-persistent-data
samba-winbind
certmonger
pam_krb5
krb5-workstation
perl-DBD-SQLite
%end

%post --log=/root/install-post.log
(
PATH=/bin:/sbin:/usr/sbin:/usr/sbin
export PATH

# PLACE YOUR POST DIRECTIVES HERE

# Create partition on second drive
#parted -s -a optimal /dev/sdb mklabel msdos -- mkpart primary ext4 1 -1
#pvcreate /dev/sdb1
#vgcreate vgdata1 /dev/sdb1
#lvcreate --name lvdisk2 --extents 100%FREE vgdata1
#mkfs.ext4 /dev/vgdata1/lvdisk2

# Add partitions to fstab
#cat <<EOF>>/etc/fstab
#/dev/mapper/vgdata1-lvdisk2 /export/disk2           ext4    defaults        1 2
#
# lofs mounts
#
#/export/disk1/home	/home	auto	bind 0 0
#/export/disk2/data	/data	auto	bind 0 0
#EOF

#mkdir /export/disk1 /export/disk2
#mount /export/disk1
#mount /export/disk2
#mkdir -p /export/disk1/home /home /export/disk2/data /data

) 2>&1 >/root/install-post-sh.log
