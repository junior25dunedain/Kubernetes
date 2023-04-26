# Instalação do Kubernetes 
<< EOF
Você pode utilizar o kubeadm em qualquer abordagem on-premisse de uso do Kubernetes, seja máquinas virtuais, máquinas baremetal e até mesmo Raspberry Pi.

Além da conexão de rede entre as máquinas, é importante garantir que as portas utilizadas pelo Kubernetes estejam abertas. Segue abaixo a tabela com as portas para as máquinas que atuam como control plane e as máquinas que atuam como worker node:

**Portas para o control plane**

| Protocolo | Range de Porta | Uso | Quem consome |
| --- | --- | --- | --- |
| TCP | 6443 | Kubernetes API server | Todos |
| TCP | 2379-2380 | etcd server client API | kube-apiserver, etcd |
| TCP | 10250 | Kubelet API | Self, Control plane |
| TCP | 10259 | kube-scheduler | Self |
| TCP | 10257 | kube-controller-manager | Self |

**Portas para o worker node**

| Protocolo | Range de Porta | Uso | Quem consome |
| --- | --- | --- | --- |
| TCP | 10250 | Kubernetes API server | Self, Control plane |
| TCP | 30000-32767 | NodePort Services | Todos |
EOF

# Instalação

#!/usr/bin/env bash

# **Desabilitar o swap**
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# **Container Runtime (Containerd)**
<< EOF
Antes de instalar o Containerd, é preciso habilitar alguns módulos do kernel e configurar os parâmetros do sysctl 

**Instalação dos módulos do kernel**
EOF

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter


#Configuração dos parâmetros do sysctl

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Aplica as definições do sysctl sem reiniciar a máquina
sudo sysctl --system

# Instalação de pré requisitos

sudo apt update && \
sudo apt install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -y

# Adicionando a chave GPG

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
	sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Configurando o repositório

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualizando o repositório

sudo apt-get update
sudo apt install -y containerd.io -y

#Configuração padrão do Containerd

sudo mkdir -p /etc/containerd && containerd config default | sudo tee /etc/containerd/config.toml 
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd

# Instalação do kubeadm, kubelet and kubectl
<< EOF
Agora que eu tenho o container runtime instalado em todas as máquinas, chegou a hora de instalar o kubeadm, o kubelet e o kubectl. Então vamos seguir as etapas e executar esses passos em TODAS AS MÁQUINAS.
EOF

sudo apt-get update && \
sudo apt-get install -y apt-transport-https ca-certificates curl

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
					https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update && \
sudo apt-get install -y kubelet kubeadm kubectl 


#Agora eu garanto que eles não sejam atualizados automaticamente. 
sudo apt-mark hold kubelet kubeadm kubectl 

# Habilitando o serviço do kubelet
sudo systemctl restart containerd
sudo systemctl enable kubelet


