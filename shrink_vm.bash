#!/bin/bash

cd ${HOME}/VirtualMachines

if [ -f ${1}.qcow2 ] ; then
  virt-sparsify ${1}.qcow2 --convert qcow2 --compress --tmp ${HOME}/tmp ${1}_new.qcow2
  if [ $? -eq 0 ] ; then
    qemu-img amend -o "lazy_refcounts=on" ${1}_new.qcow2
    sudo chown qemu: ${1}_new.qcow2
    sudo chmod 660 ${1}_new.qcow2
    sudo mv ${1}.qcow2 ${1}_old.qcow2
    sudo mv ${1}_new.qcow2 ${1}.qcow2
    qemu-img info ${1}_old.qcow2
    qemu-img info ${1}.qcow2
  fi
else
  echo "File not found: ${1}.qcow2"
fi

