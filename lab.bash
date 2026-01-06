#!/bin/bash

# Command to access qemu domain
VIRSH_CMD="virsh -c qemu:///system"

# Get List of VMs
VM_LIST=$(${VIRSH_CMD} list --all --name)

# Infrastructure List
VM_INFRA_LIST=("sat6.example.com" "aap26")

# Do Not Start List 
VM_NO_START_LIST=("captest.test.org" "rhde" "rhdeserial" "sattest.test.org" "uefi")

start_lab () {
  # Start Server Infrastructure If Needed
  for VM_HOST in ${VM_INFRA_LIST[@]} ; do
    ${VIRSH_CMD} domstate ${VM_HOST} | grep running &> /dev/null
    if [ ${?} -ne 0 ] ; then
      ${VIRSH_CMD} start ${VM_HOST}
    fi
  done

  # Start Miscellaneous Clients to manage with AAP If needed
  for VM_HOST in ${VM_LIST} ; do 
    START="true"
    for NO_START_HOST in ${VM_NO_START_LIST[@]} ; do
      if [[ ${VM_HOST} == ${NO_START_HOST} ]] ; then
        START="false"
      fi
    done
    for NO_START_HOST in ${VM_INFRA_LIST[@]} ; do
      if [[ ${VM_HOST} == ${NO_START_HOST} ]] ; then
        START="false"
      fi
    done
    if [[ ${START} == "true" ]] ; then
      ${VIRSH_CMD} domstate ${VM_HOST} | grep running &> /dev/null
      if [ ${?} -ne 0 ] ; then
        ${VIRSH_CMD} start ${VM_HOST}
      fi
    fi
  done
}

stop_lab () {
  for VM_HOST in ${VM_LIST} ; do 
    STOP="true"
    for NO_STOP_HOST in ${VM_INFRA_LIST[@]} ; do
      if [[ ${VM_HOST} == ${NO_STOP_HOST} ]] ; then
        STOP="false"
      fi
    done
    if [[ ${STOP} == "true" ]] ; then
      ${VIRSH_CMD} domstate ${VM_HOST} | grep "shut off" &> /dev/null
      if [ ${?} -ne 0 ] ; then
        ${VIRSH_CMD} shutdown ${VM_HOST}
      fi
    fi
  done

  ${VIRSH_CMD} domstate aap26 | grep running &> /dev/null
  if [ ${?} -eq 0 ] ; then
    ssh ansible@aap26 << '___EOF___'
podman ps --format '{{.Names}}' | sort | xargs -i systemctl --user stop {}
sudo systemctl poweroff
___EOF___
  fi

  ${VIRSH_CMD} domstate sat6.example.com | grep running &> /dev/null
  if [ ${?} -eq 0 ] ; then
    ssh root@sat6 'satellite-maintain service stop && systemctl poweroff'
  fi

}

case ${1} in
  start)
    start_lab
    ;;
  stop)
    stop_lab
    ;;
  *)
    echo "Usage: ${0} [start|stop]"
    ;;
esac

