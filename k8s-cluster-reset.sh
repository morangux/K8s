#!/bin/bash
#This script will reset k8s cluster
NC='\033[0m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'

echo -e "${YELLOW}Would you like to reset k8s cluster (y/n)?${NC}"
read answer
if [ "${answer}" == "y" ]
then 
    echo -e "${YELLOW}Reset k8s...${NC}"
    kubeadm reset
    rm -rf /etc/cni/net.d
    rm -rf .kube
    if [ $? == 0 ]
    then 
        echo -e "${GREEN} OK! ${NC}"
    else
        echo -e "${RED}Something went wrong!${NC}"
    fi
else
    echo -e "${YELLOW}Operation aborted{NC}"
fi

echo -e "${YELLOW}Would you like to remove k8s packages completely?(y/n)?${NC}"
read answer
if [ "${answer}" == "y" ]
then 
    echo -e "${YELLOW}Removing kubeadm kubectl kubelet kubernetes-cni...${NC}"
    sudo apt-get purge kubeadm kubectl kubelet kubernetes-cni kube*
    if [ $? == 0 ]
    then 
        echo -e "${GREEN} OK! ${NC}"
    else
        echo -e "${RED}Something went wrong!${NC}"
    fi
else
    echo -e "${YELLOW}Operation aborted${NC}"
fi
