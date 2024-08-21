#!/bin/bash

set -e

# Variables
ip="*.*.*.*"
hostname="server"

# Update and upgrade
apt-get update && apt-get upgrade -y

# Install necessary packages
apt install -y curl apt-transport-https vim git wget software-properties-common lsb-release ca-certificates bash-completion

# Disable swap
swapoff -a
sed -i '/\/swap.img/s/^/#/' /etc/fstab

# Load required kernel modules
modprobe overlay
modprobe br_netfilter

# Configure sysctl settings
cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Add Docker repository and install containerd
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update && apt-get install -y containerd.io

# Configure containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# Add Kubernetes repository and install kubelet, kubeadm, and kubectl
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt update && apt -y install kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Update /etc/hosts
echo "$ip $hostname" >> /etc/hosts

# Create kubeadm configuration file
cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: 1.30.3
controlPlaneEndpoint: "$hostname:6443"
EOF

# Initialize Kubernetes cluster
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.out

# Set up kubectl
export KUBECONFIG=/etc/kubernetes/admin.conf

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Apply Calico network plugin
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Install and configure bash completion
sudo apt-get install bash-completion -y
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> $HOME/.bashrc

# Generate and save tokens and CA cert hash
{
  kubeadm token create
  openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
} > tokens.txt

# Verify cluster status
kubectl get nodes
kubectl get po -A
