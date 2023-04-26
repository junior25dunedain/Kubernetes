# Kubernetes
# Instalação do Kubernetes 

>Existem diversas formar de criar o seu cluster Kubernetes, aqui, o objetivo vai ser criar o seu cluster de forma on-premisse utilizando o kubeadm.
>
>Você pode utilizar o kubeadm em qualquer abordagem on-premisse de uso do Kubernetes, seja máquinas virtuais, máquinas baremetal e até mesmo Raspberry Pi.
>Neste projeto você pode realizar a instalação das ferramentas do kubenertes de forma manual, como é descrito abaixo, ou pode utilizar o script bash, chamado `instalacao-kube.sh`, que realiza a instalação do kubernetes de forma automática, mas escolhendo qualquer forma será necessário levantar o cluster seguindo os passos disponíveis no final desse tutorial.    
# Setup do Ambiente

>Aqui eu vou mostrar como criar um cluster Kubernetes utilizando 2 máquinas, uma máquina vai ter o papel de Control Plane e a outra de Worker Nodes. Lembrando que dessa forma eu não estou criando um cluster com alta disponibilidade ou HA. Pois eu tenho apenas um control plane e caso ele fique fora do ar, o cluster vai ficar inoperável. Então utiliza esse setup em ambientes de estudo, teste, desenvolvimento e caso você não preciso de alta disponibilidade, homologação. NUNCA utilize em PRODUÇÃO

# Requisitos da Instalação

Abaixo segue os requisitos mínimos pra cada máquina:

- Máquina Linux (aqui no caso vou utilizar Ubuntu 20.04)
- 2 GB de memória RAM
- 2 CPUs
- Conexão de rede entre as máquinas
- Hostname, endereço MAC e product_uuid únicos pra cada nó.
- Swap desabilitado

>Além da conexão de rede entre as máquinas, é importante garantir que as portas utilizadas pelo Kubernetes estejam abertas. Segue abaixo a tabela com as portas para as máquinas que atuam como control plane e as máquinas que atuam como worker node:

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

## Instalação
>Agora vamos pro passo a passo da instalação. 

### **Desabilitar o swap**
```
sudo swapoff -a 
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```
### **Container Runtime (Containerd)**

>O primeiro passo, é instalar em TODAS as máquinas o container runtime, ou seja, quem vai executar os containers solicitados pelo kubelet. Aqui o container runtime utilizado é o Containerd, mas você também pode usar o [Docker](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker) e o [CRI-O](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cri-o).

Antes de instalar o Containerd, é preciso habilitar alguns módulos do kernel e configurar os parâmetros do sysctl. 

**Instalação dos módulos do kernel**
```
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf 
overlay 
br_netfilter 
EOF

sudo modprobe overlay 
sudo modprobe br_netfilter
```

**Configuração dos parâmetros do sysctl, fica mantido mesmo com reebot da máquina.**
```
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf 
net.bridge.bridge-nf-call-iptables  = 1 
net.ipv4.ip_forward                 = 1 
net.bridge.bridge-nf-call-ip6tables = 1 
EOF

sudo sysctl --system
```
>Agora sim, podemos instalar e configurar o Containerd.

**Instalação de pré requisitos**
```
sudo apt update && sudo apt install ca-certificates curl gnupg lsb-release -y
```
**Adicionando a chave GPG**
```
sudo mkdir -p /etc/apt/keyrings 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```
**Configurando o repositório**
```
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```
**Atualizando o repositório** 
```
sudo apt-get update 
sudo apt install -y containerd.io -y
```
**Configuração padrão do Containerd**
```
sudo mkdir -p /etc/containerd && containerd config default | sudo tee /etc/containerd/config.toml 
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml 
sudo systemctl restart containerd
```
### Instalação do kubeadm, kubelet and kubectl

>Neste momento, eu tenho o container runtime instalado em todas as máquinas, chegou a hora de instalar o kubeadm, o kubelet e o kubectl. Então vamos seguir as etapas e executar esses passos em TODAS AS MÁQUINAS.
```
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
					https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl 
```
Agora eu garanto que eles não sejam atualizados automaticamente: 
```
sudo apt-mark hold kubelet kubeadm kubectl 
```

**Habilitando o serviço do kubelet**
```
sudo systemctl restart containerd 
sudo systemctl enable kubelet
```

## Inicializando um cluster no nó de controle

```
sudo kubeadm init  	(--pod-network-cidr=10.244.0.0/16) -> parâmetro opcional 
```

>Uma vez iniciado o cluster, é preciso copiar as configurações de acesso do cluster para o kubectl:

```
mkdir -p $HOME/.kube 
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Gerando o comando join, que deve ser executado nos nodes de trabalho:
```
kubeadm token create --print-join-command
```

**Agora, se você executar o kubectl get nodes, vai ver que o control plane e os nodes não estão prontos, pra resolver isso, é preciso instalar o Container Network Interface ou CNI, aqui eu vou usar o Weave Net:**
```
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```

>Existe outros Container Network Interface ou CNI, como o Calico e o Flannel network, que podem ser usados para levantar outros clusters. Pode-se usar os seguintes comandos para levantar CNI:
```
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
```
ou
```
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

