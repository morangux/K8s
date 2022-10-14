#/bin/bash
#This script will help to install k8s and gpu operator
#Please make sure to run this script as ROOT or with ROOT permissions
NC='\033[0m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'

group="docker"

if grep -q $group /etc/group
then
    echo "${group} permissions cofigured!"
else
    echo "${group} does not exist"
    echo "configure docker permissions..."
    echo "please re run the script"
    sudo groupadd docker
    sudo usermod -aG docker $USER
    newgrp docker
fi

#*** installing docker
function install-docker {
        if [ -x "$(command -v docker)" ]
        then
                echo "Dockder already installed"
        else
                echo  -e "${GREEN} installing docker ${NC}"
                sudo apt update
                sudo apt install -y ca-certificates curl gnupg lsb-release
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update
                sudo DEBIAN_FRONTEND=noninteractive apt-get -y install docker-ce docker-ce-cli containerd.io > /dev/null
        fi
}

# ***Setup K8s Networking
function network {
	   sudo sh -c 'cat <<EOF >  /etc/sysctl.d/k8s.conf
       net.bridge.bridge-nf-call-ip6tables = 1
       net.bridge.bridge-nf-call-iptables = 1
       net.ipv4.ip_forward = 1
       EOF'
}

# ***Install K8s
function k8s-install {
	    sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl
        sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
	    sudo apt-get update
	    echo -e "${GREEN} installing kubectl kubeadm kubelet...${NC}"
        sudo apt-get install -y kubelet="${k8s_version}-00" kubeadm="${k8s_version}-00" kubectl="${k8s_version}-00"
}

# *** Install K8s
function k8s-init {
	    echo -e "${GREEN} init k8s...${NC}"
        kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v"${k8s_version}" --token-ttl 186h
        export KUBECONFIG=/etc/kubernetes/admin.conf
        echo  -e "${GREEN} Deploying the Flannel Network Overlay...${NC}"
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml # Deploy the Flannel Network Overlay
        kubectl wait pods -n kube-flannel  -l app=flannel --for condition=Ready --timeout=180s
}

# *** Install Helm
function helm-install {
	   if ! type helm > /dev/null; then
			echo -e "${GREEN} Installing Helm ${NC}"

			curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
 			chmod 700 get_helm.sh
 			./get_helm.sh
 			sleep 5
 			helm repo add nvidia https://nvidia.github.io/gpu-operator && helm repo update
		fi
		
}

function gpu-operator {
	   echo  -e "${GREEN} Installing NVIDIA GPU operator...${NC}"
	   helm repo add nvidia https://nvidia.github.io/gpu-operator && helm repo update
       helm install --wait --generate-name -n gpu-operator --create-namespace nvidia/gpu-operator # Deploy the gpu operator
       kubectl wait pods -n gpu-operator  -l app=nvidia-operator-validator --for condition=Ready --timeout=1200s
       echo  -e "${GREEN} NVIDIA GPU deployed ${NC}"

}

###START HERE###

echo -e "${GREEN}Please provide k8s version${NC}"
read k8s_version

install-docker

cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl restart docker

sleep 5

if pgrep -x "dockerd" >/dev/null 
then
  echo "docker is up and running"
else
  echo "docker is not running"
fi

network

k8s-install

k8s-init

helm-install

echo -e "${YELLOW}Do you want to install nvidia gpu-operator?(y/n)${NC}"
read gpu-operator
if [ "${gpu-operator}" == "y" ]
then
    gpu-operator
fi
echo -e "${GREEN}K8s cluster is ready!${NC}"
echo -e "${GREEN}Please procced to install runai system${NC}"