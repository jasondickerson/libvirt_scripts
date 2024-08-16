#!/bin/bash
VM_NAME=${1}
virsh -c qemu:///system console ${VM_NAME} --safe

