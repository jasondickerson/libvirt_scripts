#!/bin/bash
qemu-img resize ${1} ${2}
echo 'Boot and run the following for RHEL <=9 :'
echo growpart /dev/vda 4
echo xfs_growfs /dev/vda4
echo
echo 'Boot and run the following for RHEL 10 :'
echo growpart /dev/vda 3
echo xfs_growfs /dev/vda3
echo
