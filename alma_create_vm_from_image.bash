#!/bin/bash

## Requires following packages:
# guestfs-tools
# libvirt-client
# virt-install

## Your specific Variables
IMAGE_DIR=${HOME}/VirtualMachines/
ROOT_PASSWORD='changeme'
DOMAIN='client.example.com'
NETWORK='sat6'
ADMIN_USER=${USER}
ADMIN_PUB_KEY_FILE=${HOME}/.ssh/id_ecdsa.pub
# Should be "" if you do not have a DHCP VM
DHCP_VM='sat6.example.com'
# Seems you can run on system or in user space
# To run in user space set to ""
LIBVIRT_CONNECT='--connect qemu:///system'

## Argument Variables
OS_VERSION=${1}
VM_NAME=${2}

## Static or Derived Variables
DEST_IMAGE=${IMAGE_DIR}${VM_NAME}.qcow2
SSH_CMD="ssh -o StrictHostKeyChecking=no root@"
ADMIN_PUB_KEY=$(cat ${ADMIN_PUB_KEY_FILE})

ALMA_IMAGE_REPO="https://repo.almalinux.org/almalinux/${OS_VERSION}/cloud/x86_64/images/"

case ${OS_VERSION} in
  8)
    ALMA_IMAGE="AlmaLinux-8-GenericCloud-8.10-20240530.x86_64.qcow2"
    SOURCE_IMAGE=${IMAGE_DIR}${ALMA_IMAGE}
    OS_INFO="almalinux8"
    ;;
  9)
    ALMA_IMAGE="AlmaLinux-9-GenericCloud-9.4-20240507.x86_64.qcow2"
    SOURCE_IMAGE=${IMAGE_DIR}${ALMA_IMAGE}
    OS_INFO="almalinux9"
    ;;
  *)
    echo Invalid OS Version for first argument.
    exit 1
    ;;
esac

if [ ! -f "${SOURCE_IMAGE}" ] ; then
  curl -o ${SOURCE_IMAGE} ${ALMA_IMAGE_REPO}${ALMA_IMAGE}
  chmod 0660 ${SOURCE_IMAGE}
  sudo chown qemu: ${SOURCE_IMAGE}
fi

if [[ XXX${VM_NAME}XXX == "XXXXXX" ]] ; then
  echo VM Name not specified in second argument.
  exit 2
fi

cp ${SOURCE_IMAGE} ${DEST_IMAGE}

virt-customize ${LIBVIRT_CONNECT} \
               --add ${DEST_IMAGE} \
               --root-password password:${ROOT_PASSWORD} \
               --ssh-inject root:file:${ADMIN_PUB_KEY_FILE} \
               --uninstall cloud-init \
               --hostname ${VM_NAME}.${DOMAIN}

## Make sure your DHCP VM is running if you have one
if [[ XXX${DHCP_VM}XXX != "XXXXXX" ]] ; then
  virsh ${LIBVIRT_CONNECT} domstate ${DHCP_VM} | grep running &> /dev/null
  if [ ${?} -ne 0 ] ; then
    virsh -c qemu:///system start ${DHCP_VM}
  fi
fi

virt-install ${LIBVIRT_CONNECT} \
             --name ${VM_NAME} \
             --memory 3072 \
             --vcpus 2 \
             --disk ${DEST_IMAGE} \
             --import \
             --osinfo ${OS_INFO} \
             --boot uefi \
             --network network=${NETWORK} \
             --noautoconsole

## RHDE Options: Replace import
# --cdrom /home/jdickers/Downloads/iso/rhde_msi_edge-installer-16.iso \
# TPM option, seems to be default now
# --tpm emulator

IP=""
while [[ XXX${IP}XXX == "XXXXXX" ]] ; do
  sleep 5
  IP=$(virsh ${LIBVIRT_CONNECT} domifaddr ${VM_NAME} eth0 --source agent 2> /dev/null | grep ipv4 | tr -s " " | cut -d" " -f5 |cut -d/ -f1)
done

${SSH_CMD}${IP} "useradd ${ADMIN_USER}"
${SSH_CMD}${IP} "mkdir -p ~${ADMIN_USER}/.ssh"
${SSH_CMD}${IP} "chmod 0700 ~${ADMIN_USER}/.ssh"
${SSH_CMD}${IP} "echo "${ADMIN_PUB_KEY}" > ~${ADMIN_USER}/.ssh/authorized_keys"
${SSH_CMD}${IP} "chown -R ${ADMIN_USER}: ~${ADMIN_USER}/.ssh"
${SSH_CMD}${IP} "chmod 0600 ~${ADMIN_USER}/.ssh/authorized_keys"
${SSH_CMD}${IP} "echo ${ADMIN_USER} 'ALL=(ALL)	NOPASSWD: ALL' > /etc/sudoers.d/${ADMIN_USER}"
${SSH_CMD}${IP} "dnf -y --refresh update"
${SSH_CMD}${IP} "systemctl reboot"

echo "${VM_NAME}.${DOMAIN} is listening on ${IP}"

