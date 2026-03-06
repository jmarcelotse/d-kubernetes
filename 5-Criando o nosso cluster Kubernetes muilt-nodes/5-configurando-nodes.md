# Configurando os Nós do Cluster Kubernetes

Este guia mostra como configurar todos os nós (masters e workers) para instalar o Kubernetes usando kubeadm.

## Visão Geral do Processo

```
1. Preparar Sistema (todos os nós)
   ├─> Desabilitar swap
   ├─> Carregar módulos do kernel
   ├─> Configurar parâmetros de rede
   └─> Atualizar sistema

2. Instalar Container Runtime (todos os nós)
   └─> containerd

3. Instalar Kubernetes (todos os nós)
   ├─> kubeadm
   ├─> kubelet
   └─> kubectl

4. Inicializar Control Plane (master-1)
   └─> kubeadm init

5. Instalar CNI (master-1)
   └─> Calico

6. Adicionar Workers (workers)
   └─> kubeadm join
```

## Pré-requisitos

```bash
# Ter as instâncias criadas na AWS
# Ter acesso SSH às instâncias
# Ter o arquivo inventory.ini gerado

# Verificar conectividade
ssh -i ~/.ssh/id_rsa ubuntu@<IP-MASTER-1>
```

## 1. Preparar Todos os Nós

### Script de Preparação

```bash
#!/bin/bash
# prepare-node.sh - Executar em TODOS os nós

set -e

echo "=== Preparando nó para Kubernetes ==="

# Atualizar sistema
echo "Atualizando sistema..."
sudo apt-get update
sudo apt-get upgrade -y

# Instalar pacotes básicos
echo "Instalando pacotes básicos..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    vim \
    git \
    wget

# Desabilitar swap
echo "Desabilitando swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Verificar swap desabilitado
free -h

# Carregar módulos do kernel
echo "Carregando módulos do kernel..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Verificar módulos
lsmod | grep br_netfilter
lsmod | grep overlay

# Configurar parâmetros sysctl
echo "Configurando parâmetros de rede..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Verificar parâmetros
sudo sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

echo "=== Nó preparado com sucesso! ==="
```

### Executar em Todos os Nós

```bash
# Copiar script para todos os nós
for ip in $(cat inventory.ini | grep ansible_host | awk '{print $2}' | cut -d= -f2); do
    echo "Copiando para $ip..."
    scp -i ~/.ssh/id_rsa prepare-node.sh ubuntu@$ip:/tmp/
done

# Executar em todos os nós
for ip in $(cat inventory.ini | grep ansible_host | awk '{print $2}' | cut -d= -f2); do
    echo "Executando em $ip..."
    ssh -i ~/.ssh/id_rsa ubuntu@$ip "bash /tmp/prepare-node.sh"
done
```

### Ou Manualmente em Cada Nó

```bash
# SSH em cada nó
ssh -i ~/.ssh/id_rsa ubuntu@<IP>

# Executar comandos
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

## 2. Instalar containerd (Todos os Nós)

### Script de Instalação

```bash
#!/bin/bash
# install-containerd.sh - Executar em TODOS os nós

set -e

echo "=== Instalando containerd ==="

# Instalar containerd
sudo apt-get update
sudo apt-get install -y containerd

# Criar diretório de configuração
sudo mkdir -p /etc/containerd

# Gerar configuração padrão
containerd config default | sudo tee /etc/containerd/config.toml

# Configurar SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Reiniciar containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verificar status
sudo systemctl status containerd --no-pager

echo "=== containerd instalado com sucesso! ==="
```

### Executar em Todos os Nós

```bash
# Copiar e executar
for ip in $(cat inventory.ini | grep ansible_host | awk '{print $2}' | cut -d= -f2); do
    echo "Instalando containerd em $ip..."
    scp -i ~/.ssh/id_rsa install-containerd.sh ubuntu@$ip:/tmp/
    ssh -i ~/.ssh/id_rsa ubuntu@$ip "bash /tmp/install-containerd.sh"
done
```

### Verificar Instalação

```bash
# Em cada nó
sudo systemctl status containerd
sudo ctr version
```

## 3. Instalar Kubernetes (Todos os Nós)

### Script de Instalação

```bash
#!/bin/bash
# install-kubernetes.sh - Executar em TODOS os nós

set -e

K8S_VERSION="1.28"

echo "=== Instalando Kubernetes $K8S_VERSION ==="

# Adicionar chave GPG
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Adicionar repositório
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Atualizar e instalar
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Segurar versões (evitar atualizações automáticas)
sudo apt-mark hold kubelet kubeadm kubectl

# Verificar versões
kubelet --version
kubeadm version
kubectl version --client

echo "=== Kubernetes instalado com sucesso! ==="
```

### Executar em Todos os Nós

```bash
# Copiar e executar
for ip in $(cat inventory.ini | grep ansible_host | awk '{print $2}' | cut -d= -f2); do
    echo "Instalando Kubernetes em $ip..."
    scp -i ~/.ssh/id_rsa install-kubernetes.sh ubuntu@$ip:/tmp/
    ssh -i ~/.ssh/id_rsa ubuntu@$ip "bash /tmp/install-kubernetes.sh"
done
```

### Verificar Instalação

```bash
# Em cada nó
kubeadm version
kubelet --version
kubectl version --client
```

## 4. Inicializar Control Plane (Master-1)

### Obter IP Privado do Master-1

```bash
# Obter IP privado
MASTER_IP=$(cat inventory.ini | grep k8s-master-1 | grep -oP 'private_ip=\K[^ ]+')
echo "Master IP: $MASTER_IP"
```

### Inicializar Cluster

```bash
# SSH no master-1
ssh -i ~/.ssh/id_rsa ubuntu@<IP-PUBLICO-MASTER-1>

# Inicializar cluster
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=<IP-PRIVADO-MASTER-1> \
  --control-plane-endpoint=<IP-PRIVADO-MASTER-1>

# Exemplo:
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=10.0.1.10 \
  --control-plane-endpoint=10.0.1.10
```

### Saída Esperada

```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.1.10:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Configurar kubectl

```bash
# No master-1
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verificar
kubectl get nodes

# Saída:
# NAME           STATUS     ROLES           AGE   VERSION
# k8s-master-1   NotReady   control-plane   1m    v1.28.0
```

### Salvar Comando de Join

```bash
# Salvar comando de join para workers
kubeadm token create --print-join-command > /tmp/join-command.sh

# Ver comando
cat /tmp/join-command.sh
```

## 5. Instalar CNI - Calico (Master-1)

```bash
# No master-1
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Aguardar pods do Calico ficarem prontos
kubectl get pods -n kube-system -w

# Verificar nós (agora deve estar Ready)
kubectl get nodes

# Saída:
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master-1   Ready    control-plane   5m    v1.28.0
```

## 6. Adicionar Workers ao Cluster

### Obter Comando de Join

```bash
# No master-1
kubeadm token create --print-join-command
```

### Executar Join nos Workers

```bash
# SSH em cada worker
ssh -i ~/.ssh/id_rsa ubuntu@<IP-WORKER-1>

# Executar comando de join (como root)
sudo kubeadm join 10.0.1.10:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Automatizar Join em Todos os Workers

```bash
# No master-1, gerar comando
JOIN_CMD=$(kubeadm token create --print-join-command)

# Copiar para máquina local
echo "$JOIN_CMD" > join-command.sh

# Na máquina local, executar em todos os workers
for ip in $(cat inventory.ini | grep k8s-worker | awk '{print $2}' | cut -d= -f2); do
    echo "Adicionando worker $ip ao cluster..."
    ssh -i ~/.ssh/id_rsa ubuntu@$ip "sudo $JOIN_CMD"
done
```

### Verificar Workers

```bash
# No master-1
kubectl get nodes

# Saída esperada:
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master-1   Ready    control-plane   10m   v1.28.0
# k8s-worker-1   Ready    <none>          2m    v1.28.0
# k8s-worker-2   Ready    <none>          2m    v1.28.0
# k8s-worker-3   Ready    <none>          2m    v1.28.0
```

## 7. Configurar kubectl Local

### Copiar kubeconfig para Máquina Local

```bash
# Na máquina local
mkdir -p ~/.kube

# Copiar config do master-1
scp -i ~/.ssh/id_rsa ubuntu@<IP-MASTER-1>:~/.kube/config ~/.kube/config

# Ou via Terraform output
MASTER_IP=$(cd terraform && terraform output -raw master_public_ips | jq -r '.[0]')
scp -i ~/.ssh/id_rsa ubuntu@$MASTER_IP:~/.kube/config ~/.kube/config

# Verificar
kubectl get nodes
kubectl get pods -A
```

### Ajustar IP no kubeconfig (se necessário)

```bash
# Editar kubeconfig
vim ~/.kube/config

# Alterar server de IP privado para IP público
# De: server: https://10.0.1.10:6443
# Para: server: https://<IP-PUBLICO-MASTER-1>:6443

# Ou via sed
MASTER_PUBLIC_IP="<IP-PUBLICO>"
sed -i "s|server: https://10.0.1.10:6443|server: https://$MASTER_PUBLIC_IP:6443|" ~/.kube/config
```

## 8. Testar Cluster

### Criar Deployment de Teste

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Verificar pods
kubectl get pods -o wide

# Saída:
# NAME                     READY   STATUS    NODE
# nginx-7854ff8877-abc12   1/1     Running   k8s-worker-1
# nginx-7854ff8877-def34   1/1     Running   k8s-worker-2
# nginx-7854ff8877-ghi56   1/1     Running   k8s-worker-3

# Expor como NodePort
kubectl expose deployment nginx --port=80 --type=NodePort

# Ver service
kubectl get svc nginx

# Testar acesso
curl http://<IP-QUALQUER-WORKER>:<NODEPORT>
```

### Verificar Componentes do Cluster

```bash
# Ver todos os pods do sistema
kubectl get pods -n kube-system

# Ver componentes
kubectl get componentstatuses

# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Ver logs do kubelet (em qualquer nó)
sudo journalctl -u kubelet -f
```

## 9. Script Completo de Automação

```bash
#!/bin/bash
# setup-k8s-cluster.sh - Automatizar toda a configuração

set -e

INVENTORY="inventory.ini"
SSH_KEY="~/.ssh/id_rsa"
K8S_VERSION="1.28"
POD_CIDR="10.244.0.0/16"

echo "=== Configurando Cluster Kubernetes ==="

# Função para executar comando em todos os nós
run_on_all() {
    local cmd=$1
    for ip in $(cat $INVENTORY | grep ansible_host | awk '{print $2}' | cut -d= -f2); do
        echo "Executando em $ip: $cmd"
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$ip "$cmd"
    done
}

# Função para executar comando nos workers
run_on_workers() {
    local cmd=$1
    for ip in $(cat $INVENTORY | grep k8s-worker | awk '{print $2}' | cut -d= -f2); do
        echo "Executando em worker $ip: $cmd"
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$ip "$cmd"
    done
}

# 1. Preparar todos os nós
echo "=== 1. Preparando todos os nós ==="
run_on_all "sudo swapoff -a && sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
run_on_all "sudo modprobe overlay && sudo modprobe br_netfilter"

# 2. Instalar containerd
echo "=== 2. Instalando containerd ==="
run_on_all "sudo apt-get update && sudo apt-get install -y containerd"
run_on_all "sudo mkdir -p /etc/containerd && containerd config default | sudo tee /etc/containerd/config.toml"
run_on_all "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml"
run_on_all "sudo systemctl restart containerd && sudo systemctl enable containerd"

# 3. Instalar Kubernetes
echo "=== 3. Instalando Kubernetes ==="
run_on_all "curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
run_on_all "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
run_on_all "sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl && sudo apt-mark hold kubelet kubeadm kubectl"

# 4. Inicializar control plane
echo "=== 4. Inicializando control plane ==="
MASTER_IP=$(cat $INVENTORY | grep k8s-master-1 | grep -oP 'private_ip=\K[^ ]+')
MASTER_PUBLIC_IP=$(cat $INVENTORY | grep k8s-master-1 | awk '{print $2}' | cut -d= -f2)

ssh -i $SSH_KEY ubuntu@$MASTER_PUBLIC_IP << EOF
sudo kubeadm init --pod-network-cidr=$POD_CIDR --apiserver-advertise-address=$MASTER_IP
mkdir -p \$HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
EOF

# 5. Instalar CNI
echo "=== 5. Instalando Calico ==="
ssh -i $SSH_KEY ubuntu@$MASTER_PUBLIC_IP "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml"

# Aguardar Calico
sleep 30

# 6. Adicionar workers
echo "=== 6. Adicionando workers ==="
JOIN_CMD=$(ssh -i $SSH_KEY ubuntu@$MASTER_PUBLIC_IP "kubeadm token create --print-join-command")
run_on_workers "sudo $JOIN_CMD"

# 7. Copiar kubeconfig
echo "=== 7. Configurando kubectl local ==="
mkdir -p ~/.kube
scp -i $SSH_KEY ubuntu@$MASTER_PUBLIC_IP:~/.kube/config ~/.kube/config
sed -i "s|server: https://$MASTER_IP:6443|server: https://$MASTER_PUBLIC_IP:6443|" ~/.kube/config

echo "=== Cluster configurado com sucesso! ==="
kubectl get nodes
```

## 10. Troubleshooting

### Nó NotReady

```bash
# Verificar logs do kubelet
sudo journalctl -u kubelet -f

# Verificar CNI
kubectl get pods -n kube-system | grep calico

# Reiniciar kubelet
sudo systemctl restart kubelet
```

### Erro ao Fazer Join

```bash
# Resetar nó
sudo kubeadm reset -f

# Limpar iptables
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Tentar join novamente
sudo kubeadm join ...
```

### Token Expirado

```bash
# No master, gerar novo token
kubeadm token create --print-join-command
```

### Pods Pending

```bash
# Verificar eventos
kubectl describe pod <pod-name>

# Verificar recursos
kubectl top nodes

# Verificar taints
kubectl describe nodes | grep -i taint
```

## Resumo dos Comandos

```bash
# Preparar nós
sudo swapoff -a
sudo modprobe overlay br_netfilter

# Instalar containerd
sudo apt-get install -y containerd

# Instalar Kubernetes
sudo apt-get install -y kubelet kubeadm kubectl

# Inicializar master
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Instalar CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Adicionar workers
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Verificar
kubectl get nodes
kubectl get pods -A
```
