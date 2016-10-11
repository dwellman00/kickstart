install
url --url=http://ks1.domain.com/OracleLinux/5.11/x86_64/iso
lang en_US.UTF-8
keyboard us
timezone --utc  America/Los_Angeles
rootpw --iscrypted <encrypted>
selinux --permissive
firewall --enabled --ssh
authconfig --enableshadow --passalgo=sha512

#ignoredisk --only-use=sda

# Create the bootloader in the MBR with drive sda being the drive to install it on
bootloader --location=mbr --driveorder=sda
# Wipe all partitions and build them with the info below
clearpart --all --drives=sda --initlabel
# gets rid of Storage Device Warning error
zerombr yes

part /boot --fstype=ext3 --size=500 --ondisk sda

part pv.01 --grow --size=1 --ondisk sda

volgroup VolGroup00 pv.01

logvol / --fstype=ext4 --name=LogVol00 --vgname=VolGroup00 --size=8192
logvol swap --name=LogVol01 --vgname=VolGroup00 --size=8192
logvol /var --fstype=ext4 --name=LogVol02 --vgname=VolGroup00 --size=4096
logvol /export/disk1 --fstype=ext4 --name=LogVol03 --vgname=VolGroup00 --grow --size=1

reboot

%packages
@admin-tools
@base
@core
@development-libs
@development-tools
@dialup
@editors
@gnome-desktop
@gnome-software-development
@games
@graphical-internet
@graphics
@java
@legacy-software-support
@office
@printing
@sound-and-video
@text-internet
@x-software-development
@base-x
system-config-kickstart
kexec-tools
iscsi-initiator-utils
fipscheck
squashfs-tools
device-mapper-multipath
sgpio
imake
emacs
libsane-hpaio
mesa-libGLU-devel
xorg-x11-utils
xorg-x11-server-Xnest
xorg-x11-server-Xvfb

%post --log=/root/install-post.log
(
PATH=/bin:/sbin:/usr/sbin:/usr/sbin
export PATH

# PLACE YOUR POST DIRECTIVES HERE

# Create partition on second drive
parted -s /dev/sdb mklabel msdos 
parted -s /dev/sdb rm 1
parted -s /dev/sdb rm 2
parted -s /dev/sdb rm 3
parted -s /dev/sdb rm 4
parted -s /dev/sdb mkpart primary ext3 0 100%
#parted -s -a optimal /dev/sdb mklabel gpt
#parted -s /dev/sdb mkpart -- primary ext4 1 -1
pvcreate /dev/sdb1
vgcreate -s 32M VgOraTest /dev/sdb1
lvcreate -L 155G -n LvOraBin VgOraTest
lvcreate -L 20G -n LvOraData VgOraTest
lvcreate -L 20G -n LvOraLogs VgOraTest
lvcreate -L 355G -n LvOraFlash VgOraTest
mkfs.ext4 -m 1 -T largefile /dev/VgOraTest/LvOraData 
mkfs.ext4 -m 1 -T largefile /dev/VgOraTest/LvOraFlash 
mkfs.ext4 -m 1 /dev/VgOraTest/LvOraBin
mkfs.ext4 -m 1 /dev/VgOraTest/LvOraLogs 

# Add partitions to fstab
cat <<EOF>>/etc/fstab
##
## Loop Back Mounts to aggregate space
##
/export/disk1/home      /home                   auto    bind            0 0
/export/disk1/opt      /opt                   auto    bind            0 0
##
## LVMs
##
/dev/VgOraTest/LvOraBin       /ora/bin        ext4    noatime,nodiratime,rw   1 2
/dev/VgOraTest/LvOraLogs      /ora/logs       ext4    noatime,nodiratime,rw   1 2
/dev/VgOraTest/LvOraData      /ora/data       ext4    noatime,nodiratime,rw   1 2
/dev/VgOraTest/LvOraFlash    /ora/flash      ext4    noatime,nodiratime,rw   1 2
EOF

mkdir /export/disk1 
mount /export/disk1
mkdir -p /export/disk1/home /export/disk1/opt /home /data
mkdir -p /ora/bin /ora/logs /ora/data /ora/flash

cat <<EOF>/etc/yum.repos.d/Yumlocal-Base.repo
[ol5_UEK_base]
name=Unbreakable Enterprise Kernel for Oracle Linux $releasever ($basearch)
baseurl=http://yumrepo.domain.com/OracleLinux/5.11/x86_64/ol5_UEK_latest
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=0
enabled=1
[ol5_u11_base]
name=Oracle Linux $releasever Update 11 installation media copy ($basearch)
baseurl=http://yumrepo.domain.com/OracleLinux/5.11/x86_64/ol5_u11_base
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=0
enabled=1
EOF

mv /etc/yum.repos.d/public-yum-el5.repo /etc/yum.repos.d/public-yum-el5.repo.dontload

/usr/bin/yum clean all
/usr/bin/yum -y update

# Install puppet
# Puppet repo
rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-5.noarch.rpm
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

# Change default run level to no gui
mv /etc/inittab /etc/inittab.kickstart
sed -e 's/^id:5:initdefault:/id:3:initdefault:/' /etc/inittab.kickstart > /etc/inittab

# fix yum
mv /etc/yum.conf /etc/yum.conf.kickstart
sed -e 's/^distroverpkg=redhat-release/distroverpkg=oraclelinux-release/' /etc/yum.conf.kickstart > /etc/yum.conf

# remove sendmail... 
echo "INSTALLING POSTFIX..."
/usr/bin/yum install -y postfix
echo "REMOVING SENDMAIL..."
rpm -e sendmail

echo "TURNING OFF SYSLOG... rsyslog installed by puppet"
chkconfig syslog off

) 2>&1 >/root/install-post-sh.log
%end
