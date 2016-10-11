install
url --url http://ks1.domain.com/CentOS/6.7/os/x86_64
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

part /boot --fstype=ext4 --size=500 --ondisk sda

part pv.01 --grow --size=1 --ondisk sda

volgroup vg00 pv.01

logvol / --fstype=ext4 --name=lv00 --vgname=vg00 --size=10240
logvol swap --name=lv01 --vgname=vg00 --size=2048
logvol /var --fstype=ext4 --name=lv02 --vgname=vg00 --size=3072
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
parted -s -a optimal /dev/sdb mklabel msdos -- mkpart primary ext4 1 -1
#parted -s -a optimal /dev/sdb mklabel gpt
#parted -s /dev/sdb mkpart -- primary ext4 1 -1
pvcreate /dev/sdb1
vgcreate vgdata1 /dev/sdb1
lvcreate --name lvdisk2 --extents 100%FREE vgdata1
mkfs.ext4 /dev/vgdata1/lvdisk2

# Add partitions to fstab
cat <<EOF>>/etc/fstab
/dev/mapper/vgdata1-lvdisk2 /export/disk2           ext4    defaults        1 2
#
# lofs mounts
#
/export/disk1/home	/home	auto	bind 0 0
/export/disk2/data	/data	auto	bind 0 0
EOF

mkdir /export/disk1 /export/disk2
mount /export/disk1
mount /export/disk2
mkdir -p /export/disk1/home /home /export/disk2/data /data

###NEEDS TO BE TESTED
# Cleanup yum repos and update packages
for i in CentOS-Base.repo  CentOS-Debuginfo.repo  CentOS-Media.repo  CentOS-Vault.repo
do
	mv /etc/yum.repos.d/$i /etc/yum.repos.d/$i.dontload
	echo "Moving repo $i"
done
cat <<EOF>/etc/yum.repos.d/Yumlocal-Base.repo
[base]
name=CentOS-\$releasever - Base
baseurl=http://yumrepo.domain.com/CentOS/6.6/os/\$basearch/
gpgcheck=1
gpgkey=http://yumrepo.domain.com/CentOS/RPM-GPG-KEY-CentOS-6
enabled=1

#released updates
[updates]
name=CentOS-\$releasever - Updates
baseurl=http://yumrepo.domain.com/CentOS/6.6/updates/\$basearch/
gpgcheck=0
gpgkey=http://yumrepo.domain.com/CentOS/RPM-GPG-KEY-CentOS-6
enabled=1

#additional packages that may be useful
[extras]
name=CentOS-\$releasever - Extras
baseurl=http://yumrepo.domain.com/CentOS/6.6/extras/\$basearch/
gpgcheck=1
gpgkey=http://yumrepo.domain.com/CentOS/RPM-GPG-KEY-CentOS-6
enabled=1

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-\$releasever - Plus
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=centosplus
baseurl=http://yumrepo.domain.com/CentOS/\$releasever/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=http://yumrepo.domain.com/CentOS/RPM-GPG-KEY-CentOS-6
EOF

# EPEL 6 yum repo
rpm -Uvh http://download-i2.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
# VMWare Tools repo
# *** In Puppet now
#rpm -ivh http://packages.vmware.com/tools/esx/latest/repos/vmware-tools-repo-RHEL6-9.4.6-1.el6.x86_64.rpm

/usr/bin/yum clean all
/usr/bin/yum -y update
# Some update repopulates the default repo files
for i in CentOS-Base.repo  CentOS-Debuginfo.repo  CentOS-Media.repo  CentOS-Vault.repo
do
	rm /etc/yum.repos.d/$i 
	echo "Cleaning repo $i"
done
/usr/bin/yum -y install vmware-tools-esx-nox

# Install puppet
# Puppet repo
rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/puppetlabs.repo
/usr/bin/yum install -y puppet --enablerepo=puppetlabs*

cat <<EOF>>/etc/puppet/puppet.conf
    server = pm1.domain.com
    report = true
    pluginsync = true
    reports = store, https
    reporturl = https://dashboard.pm1.domain.com/reports/upload
EOF

chkconfig puppet on
 
cat <<EOF>/etc/resolv.conf
search domain.com domain.local
nameserver 10.1.10.101
nameserver 10.1.10.102
EOF

service ntpd stop
ntpdate time1.domain.com

) 2>&1 >/root/install-post-sh.log
