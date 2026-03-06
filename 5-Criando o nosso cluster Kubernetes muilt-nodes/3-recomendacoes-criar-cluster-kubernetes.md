# Recomendações para Criar um Cluster Kubernetes

Este guia apresenta as melhores práticas e recomendações para criar um cluster Kubernetes robusto, seguro e escalável.

## 1. Planejamento de Infraestrutura

### Dimensionamento de Nós

**Control Plane (Master Nodes):**

```
Ambiente de Desenvolvimento:
- 1 nó control plane
- 2 vCPUs
- 4 GB RAM
- 20 GB disco

Ambiente de Produção (Alta Disponibilidade):
- 3 ou 5 nós control plane (número ímpar)
- 4 vCPUs por nó
- 8 GB RAM por nó
- 50 GB disco SSD por nó
```

**Worker Nodes:**

```
Mínimo por Worker:
- 2 vCPUs
- 4 GB RAM
- 50 GB disco

Recomendado para Produção:
- 4-8 vCPUs
- 16-32 GB RAM
- 100-200 GB disco SSD
- Quantidade: mínimo 3 workers
```

**Exemplo de Cálculo:**

```bash
# Aplicação exemplo:
# - 10 microserviços
# - 3 réplicas cada
# - 500m CPU e 512Mi RAM por pod
# Total: 30 pods

# Recursos necessários:
CPU: 30 pods × 0.5 cores = 15 cores
RAM: 30 pods × 512 MB = 15 GB

# Adicionar overhead (30%):
CPU total: 15 × 1.3 = 19.5 cores
RAM total: 15 × 1.3 = 19.5 GB

# Distribuição em 3 workers:
Por worker: ~7 cores e ~7 GB RAM
Recomendado: 8 vCPUs e 16 GB RAM por worker
```

---

## 2. Requisitos de Sistema

### Sistema Operacional

**Recomendados:**
- Ubuntu 20.04/22.04 LTS
- Debian 11/12
- CentOS Stream 9
- Rocky Linux 9
- RHEL 8/9

**Configurações obrigatórias:**

```bash
# Desabilitar swap (obrigatório)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Verificar
free -h

# Desabilitar SELinux (ou configurar para permissive)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Desabilitar firewall (ou configurar portas)
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# Ou configurar portas necessárias
sudo firewall-cmd --permanent --add-port=6443/tcp  # API Server
sudo firewall-cmd --permanent --add-port=2379-2380/tcp  # etcd
sudo firewall-cmd --permanent --add-port=10250/tcp  # Kubelet
sudo firewall-cmd --permanent --add-port=10251/tcp  # Scheduler
sudo firewall-cmd --permanent --add-port=10252/tcp  # Controller Manager
sudo firewall-cmd --permanent --add-port=10255/tcp  # Read-only Kubelet
sudo firewall-cmd --reload
```

### Módulos do Kernel

```bash
# Carregar módulos necessários
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Verificar
lsmod | grep br_netfilter
lsmod | grep overlay
```

### Parâmetros de Rede

```bash
# Configurar parâmetros sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.forwarding        = 1
EOF

sudo sysctl --system

# Verificar
sudo sysctl net.bridge.bridge-nf-call-iptables
sudo sysctl net.ipv4.ip_forward
```

---

## 3. Escolha do Container Runtime

### Opções Recomendadas

**containerd (Recomendado):**

```bash
# Instalar containerd
sudo apt-get update
sudo apt-get install -y containerd

# Configurar
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Habilitar SystemdCgroup (importante!)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Reiniciar
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verificar
sudo systemctl status containerd
```

**CRI-O (Alternativa):**

```bash
# Adicionar repositório
export OS=xUbuntu_22.04
export VERSION=1.28

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | sudo apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key add -

sudo apt-get update
sudo apt-get install -y cri-o cri-o-runc

sudo systemctl start crio
sudo systemctl enable crio
```

**Comparação:**

| Runtime | Vantagens | Desvantagens |
|---------|-----------|--------------|
| **containerd** | Leve, padrão, bem suportado | - |
| **CRI-O** | Otimizado para K8s, seguro | Menos ferramentas |
| **Docker** | Familiar, muitas ferramentas | Deprecated no K8s |

---

## 4. Versão do Kubernetes

### Estratégia de Versionamento

```bash
# Verificar versões disponíveis
apt-cache madison kubeadm

# Recomendações:
# - Produção: N-1 (uma versão atrás da latest)
# - Desenvolvimento: Latest stable
# - Evitar: Versões beta/alpha

# Instalar versão específica
VERSION=1.28.0-00
sudo apt-get install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION
sudo apt-mark hold kubelet kubeadm kubectl
```

**Política de Atualização:**

```
Kubernetes Release: a cada 4 meses
Suporte: últimas 3 versões (1 ano)

Exemplo (2024):
- v1.28 (atual) ✅
- v1.27 (suportada) ✅
- v1.26 (suportada) ✅
- v1.25 (sem suporte) ❌
```

---

## 5. Rede (CNI - Container Network Interface)

### Escolha do Plugin CNI

**Calico (Recomendado para maioria):**

```bash
# Instalar Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Verificar
kubectl get pods -n kube-system | grep calico
```

**Características:**
- Network Policies avançadas
- BGP support
- Escalável
- Bom para produção

**Flannel (Simples):**

```bash
# Instalar Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

**Características:**
- Simples
- Leve
- Bom para desenvolvimento

**Cilium (Avançado):**

```bash
# Instalar Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz

# Instalar Cilium
cilium install
```

**Características:**
- eBPF-based
- Alta performance
- Observabilidade avançada
- Service Mesh integrado

**Comparação:**

| CNI | Performance | Complexidade | Network Policies | Uso |
|-----|-------------|--------------|------------------|-----|
| **Calico** | ⚡⚡⚡ | Média | ✅ Avançadas | Produção |
| **Flannel** | ⚡⚡ | Baixa | ❌ Básicas | Dev/Simples |
| **Cilium** | ⚡⚡⚡⚡ | Alta | ✅ Avançadas | Produção/Edge |
| **Weave** | ⚡⚡ | Baixa | ✅ Básicas | Dev |

---

## 6. Configuração do Control Plane

### Inicialização com kubeadm

**Configuração Básica:**

```bash
# Inicializar control plane
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --kubernetes-version=v1.28.0
```

**Configuração Avançada (Recomendada):**

```yaml
# kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: "loadbalancer.example.com:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
apiServer:
  certSANs:
  - "loadbalancer.example.com"
  - "192.168.1.100"
  - "192.168.1.101"
  - "192.168.1.102"
  extraArgs:
    audit-log-path: "/var/log/kubernetes/audit.log"
    audit-log-maxage: "30"
    audit-log-maxbackup: "10"
    audit-log-maxsize: "100"
    enable-admission-plugins: "NodeRestriction,PodSecurityPolicy"
etcd:
  local:
    dataDir: "/var/lib/etcd"
    extraArgs:
      quota-backend-bytes: "8589934592"  # 8GB
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
  kubeletExtraArgs:
    max-pods: "110"
```

```bash
# Inicializar com configuração
sudo kubeadm init --config kubeadm-config.yaml

# Configurar kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 7. Alta Disponibilidade (HA)

### Arquitetura HA

```
┌─────────────────────────────────────────────────────┐
│              Load Balancer (HAProxy/Nginx)          │
│                  VIP: 192.168.1.100:6443            │
└──────────────┬──────────────┬──────────────┬────────┘
               │              │              │
       ┌───────▼──────┐ ┌────▼──────┐ ┌────▼──────┐
       │ Control Plane│ │Control Pl.│ │Control Pl.│
       │   Master 1   │ │ Master 2  │ │ Master 3  │
       │ 192.168.1.11 │ │192.168.1.12││192.168.1.13│
       └──────────────┘ └───────────┘ └───────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼────────┐
                    │   etcd cluster  │
                    │  (stacked/ext)  │
                    └─────────────────┘
```

### Configurar Load Balancer (HAProxy)

```bash
# Instalar HAProxy
sudo apt-get install -y haproxy

# Configurar
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend kubernetes-apiserver
    bind *:6443
    mode tcp
    option tcplog
    default_backend kubernetes-master

backend kubernetes-master
    mode tcp
    option tcp-check
    balance roundrobin
    server master1 192.168.1.11:6443 check fall 3 rise 2
    server master2 192.168.1.12:6443 check fall 3 rise 2
    server master3 192.168.1.13:6443 check fall 3 rise 2
EOF

# Reiniciar
sudo systemctl restart haproxy
sudo systemctl enable haproxy
```

### Adicionar Control Planes Adicionais

```bash
# No primeiro master, gerar certificados
sudo kubeadm init phase upload-certs --upload-certs

# Gerar comando de join para control plane
sudo kubeadm token create --print-join-command --certificate-key <cert-key>

# Nos masters adicionais, executar:
sudo kubeadm join loadbalancer.example.com:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <cert-key>
```

---

## 8. Segurança

### RBAC (Role-Based Access Control)

```yaml
# Criar namespace para aplicação
apiVersion: v1
kind: Namespace
metadata:
  name: producao
---
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: producao
---
# Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: producao
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update"]
---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: producao
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: producao
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
```

### Network Policies

```yaml
# Isolar namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: producao
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Permitir tráfego específico
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: producao
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Pod Security Standards

```yaml
# Namespace com Pod Security
apiVersion: v1
kind: Namespace
metadata:
  name: producao
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

## 9. Armazenamento

### StorageClass

```yaml
# Local Path Provisioner (desenvolvimento)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
# NFS (produção simples)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exports/kubernetes
---
# Cloud Provider (produção cloud)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
```

**Recomendações:**

```
Desenvolvimento:
- hostPath ou local-path-provisioner

Produção On-Premises:
- NFS (simples, compartilhado)
- Ceph/Rook (distribuído, escalável)
- Longhorn (simples, cloud-native)

Produção Cloud:
- EBS (AWS)
- Persistent Disk (GCP)
- Azure Disk (Azure)
```

---

## 10. Monitoramento e Observabilidade

### Prometheus + Grafana

```bash
# Instalar kube-prometheus-stack via Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# Acessar Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Credenciais padrão:
# User: admin
# Password: prom-operator
```

### Logs Centralizados (EFK Stack)

```bash
# Instalar Elasticsearch
helm repo add elastic https://helm.elastic.co
helm install elasticsearch elastic/elasticsearch -n logging --create-namespace

# Instalar Fluentd
kubectl apply -f https://raw.githubusercontent.com/fluent/fluentd-kubernetes-daemonset/master/fluentd-daemonset-elasticsearch.yaml

# Instalar Kibana
helm install kibana elastic/kibana -n logging
```

---

## 11. Backup e Disaster Recovery

### Backup do etcd

```bash
# Script de backup
cat <<'EOF' > /usr/local/bin/etcd-backup.sh
#!/bin/bash
BACKUP_DIR="/backup/etcd"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

ETCDCTL_API=3 etcdctl snapshot save $BACKUP_DIR/etcd-snapshot-$DATE.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Manter apenas últimos 7 dias
find $BACKUP_DIR -name "etcd-snapshot-*.db" -mtime +7 -delete

echo "Backup completed: etcd-snapshot-$DATE.db"
EOF

chmod +x /usr/local/bin/etcd-backup.sh

# Agendar backup diário
cat <<EOF | sudo tee /etc/cron.d/etcd-backup
0 2 * * * root /usr/local/bin/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1
EOF
```

### Restaurar etcd

```bash
# Parar kube-apiserver
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Restaurar snapshot
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd/etcd-snapshot-20240101-020000.db \
  --data-dir=/var/lib/etcd-restore \
  --initial-cluster=master1=https://192.168.1.11:2380 \
  --initial-advertise-peer-urls=https://192.168.1.11:2380

# Atualizar etcd para usar novo diretório
sudo vim /etc/kubernetes/manifests/etcd.yaml
# Alterar: --data-dir=/var/lib/etcd-restore

# Reiniciar kube-apiserver
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

### Velero (Backup de Recursos)

```bash
# Instalar Velero CLI
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
tar -xvf velero-v1.12.0-linux-amd64.tar.gz
sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/

# Instalar Velero no cluster (exemplo com MinIO)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket velero \
  --secret-file ./credentials-velero \
  --use-volume-snapshots=false \
  --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.example.com:9000

# Criar backup
velero backup create full-backup --include-namespaces '*'

# Agendar backups diários
velero schedule create daily-backup --schedule="0 2 * * *"

# Restaurar backup
velero restore create --from-backup full-backup
```

---

## 12. Checklist de Produção

### Pré-Deploy

```bash
# ✅ Verificar requisitos de sistema
- [ ] Swap desabilitado
- [ ] Módulos do kernel carregados
- [ ] Parâmetros sysctl configurados
- [ ] Firewall configurado ou desabilitado
- [ ] NTP sincronizado em todos os nós

# ✅ Verificar componentes
- [ ] Container runtime instalado e funcionando
- [ ] kubeadm, kubelet, kubectl instalados
- [ ] Versões compatíveis

# ✅ Verificar rede
- [ ] Conectividade entre nós
- [ ] DNS funcionando
- [ ] Portas necessárias abertas
```

### Pós-Deploy

```bash
# ✅ Verificar cluster
kubectl get nodes
kubectl get pods -A
kubectl cluster-info

# ✅ Testar funcionalidades
kubectl run test --image=nginx --rm -it -- /bin/bash
kubectl create deployment test --image=nginx
kubectl expose deployment test --port=80
kubectl get svc test

# ✅ Configurar addons essenciais
- [ ] CNI instalado e funcionando
- [ ] CoreDNS funcionando
- [ ] Metrics Server instalado
- [ ] Ingress Controller instalado
- [ ] Cert-Manager instalado

# ✅ Configurar segurança
- [ ] RBAC configurado
- [ ] Network Policies aplicadas
- [ ] Pod Security Standards configurados
- [ ] Secrets criptografados

# ✅ Configurar observabilidade
- [ ] Prometheus instalado
- [ ] Grafana configurado
- [ ] Logs centralizados
- [ ] Alertas configurados

# ✅ Configurar backup
- [ ] Backup do etcd agendado
- [ ] Velero configurado
- [ ] Testes de restore realizados
```

---

## 13. Exemplo Completo: Cluster de Produção

### Arquitetura

```
3 Control Planes (HA)
5 Worker Nodes
1 Load Balancer
NFS para storage
Calico para rede
Prometheus + Grafana
Velero para backup
```

### Script de Instalação Automatizada

```bash
#!/bin/bash
# install-k8s-cluster.sh

set -e

# Variáveis
K8S_VERSION="1.28.0-00"
POD_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
CONTROL_PLANE_ENDPOINT="loadbalancer.example.com:6443"

# Função: Preparar sistema
prepare_system() {
    echo "=== Preparando sistema ==="
    
    # Desabilitar swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Carregar módulos
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    # Configurar sysctl
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sudo sysctl --system
}

# Função: Instalar containerd
install_containerd() {
    echo "=== Instalando containerd ==="
    
    sudo apt-get update
    sudo apt-get install -y containerd
    
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    sudo systemctl restart containerd
    sudo systemctl enable containerd
}

# Função: Instalar Kubernetes
install_kubernetes() {
    echo "=== Instalando Kubernetes ==="
    
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl
    
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    sudo apt-get update
    sudo apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION
    sudo apt-mark hold kubelet kubeadm kubectl
}

# Função: Inicializar control plane
init_control_plane() {
    echo "=== Inicializando Control Plane ==="
    
    sudo kubeadm init \
        --pod-network-cidr=$POD_CIDR \
        --service-cidr=$SERVICE_CIDR \
        --control-plane-endpoint=$CONTROL_PLANE_ENDPOINT \
        --upload-certs
    
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

# Função: Instalar CNI
install_cni() {
    echo "=== Instalando Calico ==="
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
}

# Executar
prepare_system
install_containerd
install_kubernetes

# Se for control plane
if [ "$1" == "master" ]; then
    init_control_plane
    install_cni
    echo "=== Control Plane configurado ==="
    echo "Execute nos workers:"
    sudo kubeadm token create --print-join-command
fi

echo "=== Instalação concluída ==="
```

---

## Resumo das Recomendações

**Infraestrutura:**
- ✅ Mínimo 3 control planes para HA
- ✅ Mínimo 3 workers para produção
- ✅ Load balancer para control plane
- ✅ SSD para etcd

**Sistema:**
- ✅ Ubuntu/Debian LTS
- ✅ Swap desabilitado
- ✅ Módulos e sysctl configurados
- ✅ containerd como runtime

**Rede:**
- ✅ Calico para produção
- ✅ Network Policies habilitadas
- ✅ Pod CIDR: 10.244.0.0/16
- ✅ Service CIDR: 10.96.0.0/12

**Segurança:**
- ✅ RBAC configurado
- ✅ Pod Security Standards
- ✅ Network Policies
- ✅ Audit logs habilitados

**Observabilidade:**
- ✅ Prometheus + Grafana
- ✅ Logs centralizados
- ✅ Alertas configurados

**Backup:**
- ✅ etcd backup diário
- ✅ Velero para recursos
- ✅ Testes de restore regulares
