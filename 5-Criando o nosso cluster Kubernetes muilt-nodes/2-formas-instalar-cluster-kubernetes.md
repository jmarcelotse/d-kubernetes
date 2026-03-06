# Diferentes Formas de Instalar um Cluster Kubernetes

Existem diversas formas de criar um cluster Kubernetes, cada uma adequada para diferentes cenários: desenvolvimento local, produção, aprendizado ou ambientes específicos.

## Categorias de Instalação

### 1. Clusters Locais (Desenvolvimento/Aprendizado)
### 2. Clusters Gerenciados (Cloud Providers)
### 3. Clusters On-Premises (Bare Metal/VMs)
### 4. Clusters Especializados

---

## 1. Clusters Locais

### Kind (Kubernetes in Docker)

**Melhor para:** Desenvolvimento, CI/CD, testes rápidos

**Características:**
- Roda clusters dentro de containers Docker
- Muito rápido para criar/destruir
- Suporta múltiplos nós
- Ideal para testes de configurações

**Instalação:**

```bash
# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verificar instalação
kind version
```

**Exemplo Prático:**

```bash
# Cluster simples (1 nó)
kind create cluster --name dev

# Cluster multi-nó
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF

kind create cluster --name producao --config kind-config.yaml

# Listar clusters
kind get clusters

# Usar cluster específico
kubectl cluster-info --context kind-producao

# Deletar cluster
kind delete cluster --name dev
```

**Vantagens:**
- ✅ Extremamente rápido
- ✅ Não consome muitos recursos
- ✅ Suporta múltiplos clusters simultâneos
- ✅ Ideal para CI/CD

**Desvantagens:**
- ❌ Não é para produção
- ❌ Limitado ao Docker

---

### Minikube

**Melhor para:** Aprendizado, desenvolvimento local, testes de features

**Características:**
- Cluster de nó único (pode ser multi-nó)
- Suporta múltiplos drivers (Docker, VirtualBox, KVM, etc)
- Addons integrados (dashboard, ingress, metrics-server)
- Interface gráfica disponível

**Instalação:**

```bash
# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verificar
minikube version
```

**Exemplo Prático:**

```bash
# Iniciar cluster com Docker
minikube start --driver=docker

# Cluster com recursos customizados
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=20g \
  --kubernetes-version=v1.28.0

# Cluster multi-nó
minikube start --nodes=3

# Ver status
minikube status

# Habilitar addons
minikube addons enable dashboard
minikube addons enable ingress
minikube addons enable metrics-server

# Listar addons
minikube addons list

# Acessar dashboard
minikube dashboard

# SSH no nó
minikube ssh

# Ver IP do cluster
minikube ip

# Parar cluster (mantém estado)
minikube stop

# Deletar cluster
minikube delete
```

**Exemplo com Aplicação:**

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx

# Expor como NodePort
kubectl expose deployment nginx --type=NodePort --port=80

# Acessar via Minikube
minikube service nginx

# Ou obter URL
minikube service nginx --url
```

**Vantagens:**
- ✅ Fácil de usar
- ✅ Muitos addons prontos
- ✅ Dashboard integrado
- ✅ Suporta LoadBalancer local

**Desvantagens:**
- ❌ Mais pesado que Kind
- ❌ Mais lento para iniciar
- ❌ Cluster de nó único por padrão

---

### k3d (k3s in Docker)

**Melhor para:** Desenvolvimento leve, IoT, Edge Computing

**Características:**
- Baseado em k3s (Kubernetes leve da Rancher)
- Muito rápido e leve
- Suporta múltiplos nós
- Load balancer integrado

**Instalação:**

```bash
# Linux
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Verificar
k3d version
```

**Exemplo Prático:**

```bash
# Cluster simples
k3d cluster create meucluster

# Cluster com 3 workers e load balancer
k3d cluster create producao \
  --agents 3 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer"

# Listar clusters
k3d cluster list

# Parar cluster
k3d cluster stop producao

# Iniciar cluster
k3d cluster start producao

# Deletar cluster
k3d cluster delete producao
```

**Vantagens:**
- ✅ Muito leve (k3s)
- ✅ Rápido
- ✅ Load balancer integrado
- ✅ Ideal para Edge/IoT

**Desvantagens:**
- ❌ k3s não é Kubernetes completo
- ❌ Algumas features removidas

---

### MicroK8s

**Melhor para:** Ubuntu, desenvolvimento local, produção leve

**Características:**
- Desenvolvido pela Canonical (Ubuntu)
- Instalação via snap
- Cluster de nó único ou multi-nó
- Addons integrados

**Instalação:**

```bash
# Ubuntu/Linux com snap
sudo snap install microk8s --classic

# Adicionar usuário ao grupo
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s

# Verificar status
microk8s status --wait-ready
```

**Exemplo Prático:**

```bash
# Ver status
microk8s status

# Habilitar addons
microk8s enable dashboard
microk8s enable dns
microk8s enable registry
microk8s enable istio

# Usar kubectl
microk8s kubectl get nodes

# Criar alias
alias kubectl='microk8s kubectl'

# Exportar kubeconfig
microk8s config > ~/.kube/config

# Adicionar nós (cluster multi-nó)
microk8s add-node
# Copiar comando gerado e executar em outro servidor

# Parar
microk8s stop

# Iniciar
microk8s start
```

**Vantagens:**
- ✅ Fácil instalação no Ubuntu
- ✅ Baixo consumo de recursos
- ✅ Suporta produção leve
- ✅ Atualizações automáticas

**Desvantagens:**
- ❌ Específico para sistemas com snap
- ❌ Comandos diferentes (microk8s kubectl)

---

## 2. Clusters Gerenciados (Cloud)

### Amazon EKS (Elastic Kubernetes Service)

**Melhor para:** Produção na AWS, integração com serviços AWS

**Instalação via eksctl:**

```bash
# Instalar eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Criar cluster
eksctl create cluster \
  --name meu-cluster \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# Ver clusters
eksctl get cluster

# Atualizar kubeconfig
aws eks update-kubeconfig --name meu-cluster --region us-east-1

# Escalar nodegroup
eksctl scale nodegroup \
  --cluster=meu-cluster \
  --name=workers \
  --nodes=5

# Deletar cluster
eksctl delete cluster --name meu-cluster
```

**Via AWS CLI:**

```bash
# Criar cluster (apenas control plane)
aws eks create-cluster \
  --name meu-cluster \
  --role-arn arn:aws:iam::123456789012:role/eks-service-role \
  --resources-vpc-config subnetIds=subnet-xxx,subnet-yyy,securityGroupIds=sg-xxx

# Criar node group
aws eks create-nodegroup \
  --cluster-name meu-cluster \
  --nodegroup-name workers \
  --subnets subnet-xxx subnet-yyy \
  --node-role arn:aws:iam::123456789012:role/eks-node-role \
  --scaling-config minSize=1,maxSize=4,desiredSize=3 \
  --instance-types t3.medium
```

**Vantagens:**
- ✅ Gerenciado pela AWS
- ✅ Integração com serviços AWS
- ✅ Alta disponibilidade
- ✅ Atualizações gerenciadas

**Desvantagens:**
- ❌ Custo do control plane
- ❌ Complexidade inicial
- ❌ Vendor lock-in

---

### Google GKE (Google Kubernetes Engine)

**Melhor para:** Produção no GCP, melhor integração Kubernetes

**Instalação via gcloud:**

```bash
# Instalar gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Criar cluster
gcloud container clusters create meu-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 5

# Cluster com autopilot (totalmente gerenciado)
gcloud container clusters create-auto meu-cluster-auto \
  --region us-central1

# Obter credenciais
gcloud container clusters get-credentials meu-cluster --zone us-central1-a

# Escalar cluster
gcloud container clusters resize meu-cluster \
  --num-nodes 5 \
  --zone us-central1-a

# Deletar cluster
gcloud container clusters delete meu-cluster --zone us-central1-a
```

**Vantagens:**
- ✅ Melhor implementação de Kubernetes
- ✅ Autopilot mode (zero ops)
- ✅ Integração com GCP
- ✅ Atualizações automáticas

**Desvantagens:**
- ❌ Custo
- ❌ Vendor lock-in

---

### Azure AKS (Azure Kubernetes Service)

**Melhor para:** Produção no Azure, integração com serviços Microsoft

**Instalação via Azure CLI:**

```bash
# Instalar Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Criar resource group
az group create --name meu-rg --location eastus

# Criar cluster
az aks create \
  --resource-group meu-rg \
  --name meu-cluster \
  --node-count 3 \
  --node-vm-size Standard_DS2_v2 \
  --enable-addons monitoring \
  --generate-ssh-keys

# Obter credenciais
az aks get-credentials --resource-group meu-rg --name meu-cluster

# Escalar cluster
az aks scale \
  --resource-group meu-rg \
  --name meu-cluster \
  --node-count 5

# Deletar cluster
az aks delete --resource-group meu-rg --name meu-cluster
```

**Vantagens:**
- ✅ Integração com Azure
- ✅ Control plane gratuito
- ✅ Bom para ambientes Windows
- ✅ Azure AD integration

**Desvantagens:**
- ❌ Vendor lock-in
- ❌ Menos features que GKE

---

## 3. Clusters On-Premises

### kubeadm (Ferramenta Oficial)

**Melhor para:** Produção on-premises, controle total

**Pré-requisitos:**
- Máquinas Linux (Ubuntu/CentOS/Debian)
- 2 GB RAM mínimo
- 2 CPUs mínimo
- Conectividade de rede entre máquinas

**Instalação Completa:**

```bash
# ===== EM TODOS OS NÓS =====

# 1. Desabilitar swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 2. Configurar módulos do kernel
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 3. Configurar sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 4. Instalar containerd
sudo apt-get update
sudo apt-get install -y containerd

# Configurar containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 5. Instalar kubeadm, kubelet, kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# ===== APENAS NO NÓ CONTROL PLANE =====

# 6. Inicializar cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 7. Configurar kubectl para usuário
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 8. Instalar CNI (Calico)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Ou Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 9. Verificar nós
kubectl get nodes

# 10. Gerar comando para adicionar workers
kubeadm token create --print-join-command

# ===== NOS NÓS WORKERS =====

# 11. Executar comando gerado (exemplo)
sudo kubeadm join 192.168.1.100:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:xxxxxxxxxxxxx

# ===== VERIFICAR NO CONTROL PLANE =====

# 12. Ver todos os nós
kubectl get nodes

# Saída esperada:
# NAME           STATUS   ROLES           AGE   VERSION
# control-plane  Ready    control-plane   5m    v1.28.0
# worker-1       Ready    <none>          2m    v1.28.0
# worker-2       Ready    <none>          2m    v1.28.0
```

**Comandos de Gerenciamento:**

```bash
# Ver certificados
kubeadm certs check-expiration

# Renovar certificados
sudo kubeadm certs renew all

# Atualizar cluster
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.28.1

# Remover nó
kubectl drain worker-1 --ignore-daemonsets
kubectl delete node worker-1

# No worker-1
sudo kubeadm reset
```

**Vantagens:**
- ✅ Controle total
- ✅ Kubernetes completo
- ✅ Ferramenta oficial
- ✅ Flexível

**Desvantagens:**
- ❌ Complexo
- ❌ Manutenção manual
- ❌ Requer conhecimento avançado

---

### Rancher

**Melhor para:** Gerenciar múltiplos clusters, interface gráfica

**Instalação:**

```bash
# Instalar Rancher via Docker
docker run -d --restart=unless-stopped \
  -p 80:80 -p 443:443 \
  --privileged \
  rancher/rancher:latest

# Acessar interface
# https://localhost

# Ou instalar em cluster Kubernetes existente
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.example.com
```

**Criar cluster via Rancher:**

1. Acessar interface web
2. Cluster Management → Create
3. Escolher provider (Custom, AWS, GCP, Azure, etc)
4. Configurar nós
5. Rancher gera comandos para executar nos nós

**Vantagens:**
- ✅ Interface gráfica
- ✅ Gerencia múltiplos clusters
- ✅ Marketplace de apps
- ✅ Monitoramento integrado

**Desvantagens:**
- ❌ Camada adicional
- ❌ Complexidade extra

---

### k0s

**Melhor para:** Produção simples, instalação rápida

**Instalação:**

```bash
# Download
curl -sSLf https://get.k0s.sh | sudo sh

# Instalar como control plane
sudo k0s install controller --single

# Iniciar
sudo k0s start

# Obter kubeconfig
sudo k0s kubeconfig admin > ~/.kube/config

# Ver status
sudo k0s status

# Adicionar worker
sudo k0s token create --role=worker
# Executar no worker:
sudo k0s install worker --token-file /path/to/token
sudo k0s start
```

**Vantagens:**
- ✅ Instalação simples
- ✅ Binário único
- ✅ Leve
- ✅ Produção-ready

**Desvantagens:**
- ❌ Menos maduro
- ❌ Comunidade menor

---

## 4. Clusters Especializados

### OpenShift (Red Hat)

**Melhor para:** Empresas, suporte comercial, segurança

```bash
# Instalar OpenShift Local (antigo CodeReady Containers)
# Download de https://developers.redhat.com/products/openshift-local

crc setup
crc start

# Obter credenciais
crc console --credentials
```

**Vantagens:**
- ✅ Suporte comercial Red Hat
- ✅ Segurança avançada
- ✅ CI/CD integrado
- ✅ Developer tools

**Desvantagens:**
- ❌ Custo
- ❌ Mais complexo
- ❌ Vendor lock-in

---

## Comparação Rápida

| Ferramenta | Uso | Velocidade | Recursos | Produção |
|------------|-----|------------|----------|----------|
| **Kind** | Dev/CI | ⚡⚡⚡ | 💾 | ❌ |
| **Minikube** | Dev/Learn | ⚡⚡ | 💾💾 | ❌ |
| **k3d** | Dev/Edge | ⚡⚡⚡ | 💾 | ⚠️ |
| **MicroK8s** | Dev/Prod | ⚡⚡ | 💾 | ✅ |
| **EKS** | Prod AWS | ⚡ | 💾💾💾 | ✅ |
| **GKE** | Prod GCP | ⚡ | 💾💾💾 | ✅ |
| **AKS** | Prod Azure | ⚡ | 💾💾💾 | ✅ |
| **kubeadm** | Prod On-Prem | ⚡ | 💾💾 | ✅ |
| **Rancher** | Multi-cluster | ⚡ | 💾💾 | ✅ |
| **k0s** | Prod Simple | ⚡⚡ | 💾 | ✅ |

---

## Fluxo de Decisão

```
┌─────────────────────────────────────┐
│   Qual tipo de cluster preciso?    │
└──────────────┬──────────────────────┘
               │
       ┌───────┴────────┐
       │                │
   Produção?         Desenvolvimento?
       │                │
       │                ├─> Rápido/CI? ──> Kind
       │                ├─> Aprendizado? ──> Minikube
       │                ├─> Leve? ──> k3d
       │                └─> Ubuntu? ──> MicroK8s
       │
   ┌───┴────┐
   │        │
 Cloud?   On-Prem?
   │        │
   │        ├─> Simples? ──> k0s
   │        ├─> Controle total? ──> kubeadm
   │        └─> Multi-cluster? ──> Rancher
   │
   ├─> AWS? ──> EKS
   ├─> GCP? ──> GKE
   ├─> Azure? ──> AKS
   └─> Multi-cloud? ──> Rancher
```

---

## Exemplo Prático: Migração entre Ambientes

### 1. Desenvolvimento Local (Kind)

```bash
# Criar cluster local
kind create cluster --name dev

# Deploy aplicação
kubectl create deployment app --image=myapp:v1
kubectl expose deployment app --port=80 --type=NodePort
```

### 2. Staging (Minikube)

```bash
# Criar cluster staging
minikube start --profile staging

# Exportar manifests do dev
kubectl get deployment app -o yaml > deployment.yaml
kubectl get service app -o yaml > service.yaml

# Aplicar no staging
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

### 3. Produção (EKS)

```bash
# Criar cluster produção
eksctl create cluster --name prod --region us-east-1

# Aplicar mesmos manifests
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Ajustar para produção
kubectl scale deployment app --replicas=10
kubectl patch service app -p '{"spec":{"type":"LoadBalancer"}}'
```

---

## Resumo

**Para Desenvolvimento:**
- Kind (mais rápido)
- Minikube (mais features)
- k3d (mais leve)

**Para Produção Cloud:**
- EKS (AWS)
- GKE (GCP) - melhor Kubernetes
- AKS (Azure)

**Para Produção On-Premises:**
- kubeadm (controle total)
- k0s (simplicidade)
- Rancher (gerenciamento)

**Para Aprendizado:**
- Minikube (melhor para iniciantes)
- Kind (melhor para prática)
