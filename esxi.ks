#
# *** MANAGED BY PUPPET - DO NOT EDIT DIRECTLY! ***
#
# Dale Wellman
# 6/10/2014
#
# Kickstart script to quickly provision ESXi hosts.  Including all vmks, portgroups, iSCSI,
# storage plugins.  This is basically a poor mans host profiles because we did not have the
# required enterprise plus vSphere licenses.
#
# Script modified from:
#
#  https://github.com/dagsonstebo/VMware-ESXi-5.5-zero-touch-build-scripts/blob/master/esxi55-scripts/esxi55ks.cfg
#
vmaccepteula
keyboard 'US Default'
rootpw <changeme123>
reboot

install --disk=mpx.vmhba33:C0:T0:L0 --overwritevmfs
network --bootproto=dhcp

%post --interpreter=busybox

################################################################################
# Firstboot
# All configuration of network is done during firstboot, and depends on the 
# host specific configuration file.  Host configuration file is downloaded and 
# parsed based on argument passed in the KS download URL.  Interpreter is 
# [busybox|python].
%firstboot --interpreter=busybox
 
# Constants
BUILDVERSION="VMware vSphere 6.0 build v1.0"
DOWNLOADURL="http://192.168.1.30"
CONFIGURL="${DOWNLOADURL}/kick"
WAITFORHOSTD=30
WAITFORREMOVAL=15
DELIMITER1="---"
 
#
# Firstboot set to sleep X mins to allow the host daemon to fully start. This 
# is an issue on certain blade server models.
#
sleep ${WAITFORHOSTD}
 
#
# Create a build working folder and initial build logging.
# To prevent any persistency issues the scratch partition is used.
#strScratchfolder=`cat /etc/vmware/locker.conf | cut -d" " -f1`
#
strScratchfolder=/scratch
mkdir ${strScratchfolder}/build
strBuildfolder="${strScratchfolder}/build"
strLogfile="${strBuildfolder}/build.log"
 
#
# Change to the build working folder, all build actions now done from here
#
cd ${strBuildfolder}
echo "INFO:  Build folder: ${strBuildfolder}." >> ${strLogfile}
 
#
# Parse all hardware information and log. This information can be used for 
# customised configuration if required.
#
strManufacturer=`esxcli hardware platform get | grep Vendor\ Name | cut -d":" -f2 | sed -e 's/^\ //'`
strModel=`esxcli hardware platform get | grep Product\ Name | cut -d":" -f2 | sed -e 's/^\ //'`
strSerial=`esxcli hardware platform get | grep Serial\ Number | cut -d":" -f2 | sed -e 's/^\ //'`
strUUID=`smbiosDump | grep -A 5 System\ Info | grep UUID | cut -d":" -f2 | sed -e 's/[ ]*//'`
echo "INFO:  System manufacturer/model: ${strManufacturer} ${strModel}" >> ${strLogfile}
echo "INFO:  System serial: ${strSerial}" >> ${strLogfile}
echo "INFO:  System UUID (from BIOS): ${strUUID}" >> ${strLogfile}

#
# Setup shells
#
echo "INFO:  Configuring SSH and ESXi shell..." >> ${strLogfile}
vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
vim-cmd hostsvc/enable_esx_shell
vim-cmd hostsvc/start_esx_shell
esxcli system settings advanced set -o /UserVars/SuppressShellWarning -i 1

#
# Get mac of vmnic0
#
strMAC=`esxcli network nic list | grep vmnic0 | awk '{print $8}' | sed -e "s/:/-/g"`

#
# Determine ESXi version
#
strESXiversion=`vmware -v`
strESXinoversion=`vmware -v | cut -d" " -f3`
echo "INFO:  VMware ESXi version installed: ${strESXiversion}" >> ${strLogfile}
 
#
# Set IP temporarily for wget
#
#    We are PXE booting off the Arista storage switches using the vMotion network.  
#    Those ports are configured as access ports on vlan 1921.  ks1 sits on the
#    same network at IP 192.168.1.30.
#
esxcli network ip interface ipv4 set -i vmk0 -I 192.168.1.239 -N 255.255.255.0 -t static 
esxcli network vswitch standard portgroup set -p "Management Network" --vlan-id 0
esxcli network ip interface ipv4 get >> ${strLogfile} 2>&1
 
#
# Download static config settings
#
strHostconfigfile="${CONFIGURL}/${strMAC}.cfg"
echo "INFO:  Downloading host config file ${strHostconfigfile}" >> ${strLogfile}
wget ${strHostconfigfile} -O ${strBuildfolder}/${strMAC}.cfg >> ${strLogfile} 2>&1
 
 
#
# Load config data
#
echo "INFO:  Applying host source config file ${strMAC}.cfg" >> ${strLogfile}
source "${strBuildfolder}/${strMAC}.cfg" >> ${strLogfile} 2>&1

#
# Clear temporary build network config
#
echo "INFO:  Removing temporary build networking vmk0" >> ${strLogfile}
esxcli network ip interface remove --interface-name=vmk0 >> ${strLogfile} 2>&1
echo "INFO : Removing temporary build networking vSwitch0" >> ${strLogfile}
esxcli network vswitch standard remove --vswitch-name=vSwitch0 >> ${strLogfile} 2>&1
sleep ${WAITFORREMOVAL};

#
# Build vSwitch0
#
echo "INFO:  Creating vSwitch0..." >> ${strLogfile}
esxcli network vswitch standard add -v vSwitch0
esxcli network vswitch standard uplink add -v vSwitch0 -u vmnic0
esxcli network vswitch standard uplink add -v vSwitch0 -u vmnic4
esxcli network vswitch standard policy failover set -v vSwitch0 --failback yes --failure-detection link --load-balancing iphash --notify-switches yes
esxcli network vswitch standard set -v vSwitch0 --mtu ${MGMTMTU} --cdp-status ${MGMTCDP}

#
# Build vmk0
#
echo "INFO:  Creating vmk0..." >> ${strLogfile}
echo "INFO:      IP:		${IPADDR}" >> ${strLogfile}
echo "INFO:      MASK:		${SUBNETMASK}" >> ${strLogfile}
echo "INFO:      MTU:		${MGMTMTU}" >> ${strLogfile}
echo "INFO:      CDP:		${MGMTCDP}" >> ${strLogfile}
echo "INFO:      VLAN:		${MGMTVLAN}" >> ${strLogfile}
# management pg
esxcli network vswitch standard portgroup add -v vSwitch0 -p "Management Network"
esxcli network vswitch standard portgroup set -p "Management Network" --vlan-id ${MGMTVLAN}
# vmk0
esxcli network ip interface add -p "Management Network" -i vmk0 --mtu ${MGMTMTU}
esxcli network ip interface ipv4 set -i vmk0 -I ${IPADDR} -N ${SUBNETMASK} -t static 
esxcli network ip route ipv4 add --gateway ${GATEWAY} --network default
 
#
# Set hostname
#
echo "INFO:  Configuring hostname: ${HOSTNAME}" >> ${strLogfile}
esxcli system hostname set --fqdn=${HOSTNAME}

# 
# Configure DNS
#
echo "INFO:  Configuring DNS..." >> ${strLogfile}
esxcli network ip dns server add --server=${DNS1}
esxcli network ip dns server add --server=${DNS2}
esxcli network ip dns search add --domain=${DOMAIN}

# 
# Configure NTP
#
cat >/etc/ntp.conf<<END_NTP
restrict default kod nomodify notrap nopeer
restrict 127.0.0.1
server ${TIME1}
server ${TIME2}
driftfile /etc/ntp.drift
END_NTP
/sbin/chkconfig ntpd on


#
# Disable ipv6
#
echo "INFO:  Disabling ipv6..." >> ${strLogfile}
esxcli system module parameters set -m tcpip4 -p ipv6=0 >> ${strLogfile}

#
# Build vSwitch1
#
#  vSwitch1
#   Name: vSwitch1
#   Class: etherswitch
#   Num Ports: 5632
#   Used Ports: 6
#   Configured Ports: 128
#   MTU: 9000
#   CDP Status: listen
#   Beacon Enabled: false
#   Beacon Interval: 1
#   Beacon Threshold: 3
#   Beacon Required By:
#   Uplinks: vmnic2, vmnic1
#   Portgroups: vMotion
#
echo "INFO:  Creating vSwitch1..." >> ${strLogfile}
esxcli network vswitch standard add -v vSwitch1
esxcli network vswitch standard uplink add -v vSwitch1 -u vmnic1
esxcli network vswitch standard uplink add -v vSwitch1 -u vmnic2
esxcli network vswitch standard policy failover set -v vSwitch1 --failback yes --failure-detection link --load-balancing iphash --notify-switches yes
esxcli network vswitch standard set -v vSwitch1 --mtu ${VMOTIONMTU} --cdp-status ${VMOTIONCDP}

#
# Build vmk1
#
echo "INFO:  Creating vmk1..." >> ${strLogfile}
echo "INFO:      IP:		${VMOTIONIP}" >> ${strLogfile}
echo "INFO:      MASK:		${VMOTIONMASK}" >> ${strLogfile}
echo "INFO:      MTU:		${VMOTIONMTU}" >> ${strLogfile}
echo "INFO:      CDP:		${VMOTIONCDP}" >> ${strLogfile}
echo "INFO:      VLAN:		${VMOTIONVLAN}" >> ${strLogfile}
# vmotion pg
esxcli network vswitch standard portgroup add -v vSwitch1 -p "vMotion"
esxcli network vswitch standard portgroup set -p "vMotion" --vlan-id ${VMOTIONVLAN}
# NFS pg
esxcli network vswitch standard portgroup add -v vSwitch1 -p "NFS"
esxcli network vswitch standard portgroup set -p "NFS" --vlan-id ${NFSVLAN}
# vmk1 
esxcli network ip interface add -p "vMotion" -i vmk1 --mtu ${VMOTIONMTU}
esxcli network ip interface ipv4 set -i vmk1 -I ${VMOTIONIP} -N ${VMOTIONMASK} -t static 
# vmk4 - VMs Using NFS to Netapp
esxcli network ip interface add -p "NFS" -i vmk4 --mtu ${NFSMTU}
esxcli network ip interface ipv4 set -i vmk4 -I ${NFSIP} -N ${NFSNETMASK} -t static 

# Set vmk1 for vmotion traffic
vim-cmd hostsvc/vmotion/vnic_set vmk1

#
# Build vSwitch2
#
# vSwitch2
#   Name: vSwitch2
#   Class: etherswitch
#   Num Ports: 5632
#   Used Ports: 4
#   Configured Ports: 128
#   MTU: 9000
#   CDP Status: listen
#   Beacon Enabled: false
#   Beacon Interval: 1
#   Beacon Threshold: 3
#   Beacon Required By:
#   Uplinks: vmnic3
#   Portgroups: iSCSI-1, iSCSI1
#
echo "INFO:  Creating vSwitch2..." >> ${strLogfile}
esxcli network vswitch standard add -v vSwitch2
esxcli network vswitch standard uplink add -v vSwitch2 -u vmnic3
esxcli network vswitch standard policy failover set -v vSwitch2 --failback yes --failure-detection link --load-balancing iphash --notify-switches yes
esxcli network vswitch standard set -v vSwitch2 --mtu ${ISCSI1MTU} --cdp-status ${ISCSI1CDP}

#
# Build vmk2
#
echo "INFO:  Creating vmk2..." >> ${strLogfile}
echo "INFO:      IP:		${ISCSI1IP}" >> ${strLogfile}
echo "INFO:      MASK:		${ISCSI1MASK}" >> ${strLogfile}
echo "INFO:      MTU:		${ISCSI1MTU}" >> ${strLogfile}
echo "INFO:      CDP:		${ISCSI1CDP}" >> ${strLogfile}
echo "INFO:      VLAN:		${ISCSI1VLAN}" >> ${strLogfile}
# iSCSI1 pg
esxcli network vswitch standard portgroup add -v vSwitch2 -p "iSCSI1"
esxcli network vswitch standard portgroup set -p "iSCSI1" --vlan-id ${ISCSI1VLAN}
# iSCSI-1 pg
esxcli network vswitch standard portgroup add -v vSwitch2 -p "iSCSI-1"
esxcli network vswitch standard portgroup set -p "iSCSI1" --vlan-id ${ISCSI1VLAN}
# vmk2
esxcli network ip interface add -p "iSCSI1" -i vmk2 --mtu ${ISCSI1MTU}
esxcli network ip interface ipv4 set -i vmk2 -I ${ISCSI1IP} -N ${ISCSI1MASK} -t static 

#
# Build vSwitch3
#
# vSwitch3
#   Name: vSwitch3
#   Class: etherswitch
#   Num Ports: 5632
#   Used Ports: 4
#   Configured Ports: 128
#   MTU: 9000
#   CDP Status: listen
#   Beacon Enabled: false
#   Beacon Interval: 1
#   Beacon Threshold: 3
#   Beacon Required By:
#   Uplinks: vmnic5
#   Portgroups: iSCSI-2, iSCSI2
#
echo "INFO:  Creating vSwitch3..." >> ${strLogfile}
esxcli network vswitch standard add -v vSwitch3
esxcli network vswitch standard uplink add -v vSwitch3 -u vmnic5
esxcli network vswitch standard policy failover set -v vSwitch3 --failback yes --failure-detection link --load-balancing iphash --notify-switches yes
esxcli network vswitch standard set -v vSwitch3 --mtu ${ISCSI2MTU} --cdp-status ${ISCSI2CDP}

#
# Build vmk3
#
echo "INFO:  Creating vmk3..." >> ${strLogfile}
echo "INFO:      IP:		${ISCSI2IP}" >> ${strLogfile}
echo "INFO:      MASK:		${ISCSI2MASK}" >> ${strLogfile}
echo "INFO:      MTU:		${ISCSI2MTU}" >> ${strLogfile}
echo "INFO:      CDP:		${ISCSI2CDP}" >> ${strLogfile}
echo "INFO:      VLAN:		${ISCSI2VLAN}" >> ${strLogfile}
# iSCSI2 pg
esxcli network vswitch standard portgroup add -v vSwitch3 -p "iSCSI2"
esxcli network vswitch standard portgroup set -p "iSCSI2" --vlan-id ${ISCSI2VLAN}
# iSCSI-2 pg
esxcli network vswitch standard portgroup add -v vSwitch3 -p "iSCSI-2"
esxcli network vswitch standard portgroup set -p "iSCSI2" --vlan-id ${ISCSI2VLAN}
# vmk3
esxcli network ip interface add -p "iSCSI2" -i vmk3 --mtu ${ISCSI2MTU}
esxcli network ip interface ipv4 set -i vmk3 -I ${ISCSI2IP} -N ${ISCSI2MASK} -t static 

#
# Build VM portgroups
#
echo "INFO:  Building VM portgroups..." >> ${strLogfile}
# main server vlan
esxcli network vswitch standard portgroup add -v vSwitch0 -p "VM VLAN 50"
esxcli network vswitch standard portgroup set -p "VM VLAN 50" --vlan-id 50
# oracle test instance network
esxcli network vswitch standard portgroup add -v vSwitch0 -p "VM VLAN 49"
esxcli network vswitch standard portgroup set -p "VM VLAN 49" --vlan-id 49
# IT vlan
esxcli network vswitch standard portgroup add -v vSwitch0 -p "VM VLAN 201"
esxcli network vswitch standard portgroup set -p "VM VLAN 201" --vlan-id 201
# Eng vlan
esxcli network vswitch standard portgroup add -v vSwitch0 -p "VM VLAN 204"
esxcli network vswitch standard portgroup set -p "VM VLAN 204" --vlan-id 204
# wifi mgmt vlan
esxcli network vswitch standard portgroup add -v vSwitch0 -p "VM VLAN 210"
esxcli network vswitch standard portgroup set -p "VM VLAN 210" --vlan-id 210
# test voice vlan
esxcli network vswitch standard portgroup add -v vSwitch0 -p "VM VLAN 151"
esxcli network vswitch standard portgroup set -p "VM VLAN 151" --vlan-id 151
# access to vMotion network
esxcli network vswitch standard portgroup add -v vSwitch1 -p "VM VLAN 1921"
esxcli network vswitch standard portgroup set -p "VM VLAN 1921" --vlan-id 1921

#
# Change uplinks to active
#
echo "INFO:  Changing uplinks to active..." >> ${strLogfile}
esxcli network vswitch standard policy failover set --active-uplinks vmnic0,vmnic4 --vswitch-name vSwitch0
esxcli network vswitch standard policy failover set --active-uplinks vmnic1,vmnic2 --vswitch-name vSwitch1
esxcli network vswitch standard policy failover set --active-uplinks vmnic3 --vswitch-name vSwitch2
esxcli network vswitch standard policy failover set --active-uplinks vmnic5 --vswitch-name vSwitch3

#
# Enable iSCSI
#
echo "INFO:  Enabling iSCSI..." >> ${strLogfile}
esxcli iscsi software set --enabled=true
esxcli iscsi adapter discovery sendtarget add -A ${ISCSIHBA} -a 172.16.1.185:3260

#
# Install Nimble Connection Management (ncm)
#
echo "INFO:  Installing Nimble and Netapp VAAI Plugins..." >> ${strLogfile}
esxcli system maintenanceMode set -e true >> ${strLogfile}
esxcli system maintenanceMode get >> ${strLogfile}
esxcli software vib install -d http://update.nimblestorage.com/esx5/ncm >> ${strLogfile}
esxcli software vib install -d http://ks1.company.com/NetAppNasPlugin.v22.vib >> ${strLogfile}

#
# Advanced settings
#
#  These settings will not work because iscsi volumes are not mapped yet.  They are not
#  mapped because the initiator group on Nimble needs to be updated with newly created
#  iSCSI IQN.  Add IQN and run these from command line.
#
#echo "INFO:  Changing advanced settings..." >> ${strLogfile}
#esxcli system syslog config set --logdir="${SYSLOGDIR}" --logdir-unique=“true" >> ${strLogfile}
#vim-cmd hostsvc/advopt/update ScratchConfig.ConfiguredScratchLocation string ${SCRATCHDIR} >> ${strLogfile}

#
# Firewall
# 
echo "INFO:  Enabling firewall..." >> ${strLogfile}
esxcli network firewall set --enabled true

#
# Add monitoring user
#
echo "INFO:  Adding monitoring user..." >> ${strLogfile}
esxcli system account add -i secret -d "IT Admin" -p "<changeme123>" -c "<changeme123>"
esxcli system permission set --id secret -r Admin

# DO THIS AT THE END
esxcli system maintenanceMode set -e false >> ${strLogfile}
#  if reboot is automatic, can't see build log
#esxcli system shutdown reboot -d 10 -r "finish script done"
