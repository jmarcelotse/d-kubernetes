# Inicializando o Cluster e o admin.conf

Este guia mostra como inicializar o cluster Kubernetes com kubeadm e configurar o arquivo admin.conf para acesso ao cluster.

## O que é o kubeadm init?

O `kubeadm init` é o comando que inicializa o control plane do Kubernetes, criando todos os componentes necessários.

```
┌─────────────────────────────────────────────────────┐
│              kubeadm init (Master Node)             │
└──────────────┬──────────────────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
   Cria Certificados  Inicia Componentes
       │                │
       ├─> CA          ├─> kube-apiserver
       ├─> API Server  ├─> etcd
       ├─> etcd        ├─> kube-scheduler
       ├─> kubelet     ├─> kube-controller-manager
       └─> SA          └─> kubelet
               │
       ┌───────┴────────┐
       │                │
   Gera admin.conf   Gera join command
       │                │
       └────────────────┘
```

## O que é o admin.conf?

O `admin.conf` é o arquivo de configuração do kubectl que contém:

- **Certificados** para autenticação
- **Endpoint** do API Server
- **Contexto** do cluster
- **Credenciais** de administrador

## Pré-requisitos

```bash
# Verificar se containerd está rodando
sudo systemctl status containerd

# Verificar se kubeadm está instalado
kubeadm version

# Verificar se kubelet está instalado
kubelet --version

# Verificar hostname
hostname
hostnamectl

# Verificar IP privado
ip addr show | grep inet
```

## 1. Preparar Inicialização

### Obter Informações Necessárias

```bash
# IP privado do master (usar este no --apiserver-advertise-address)
MASTER_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n1)
echo "Master IP: $MASTER_IP"

# Hostname
HOSTNAME=$(hostname)
echo "Hostname: $HOSTNAME"

# Verificar portas necessárias estão livres
sudo netstat -tulpn | grep -E ':(6443|2379|2380|10250|10251|10252)'
```

### Verificar Requisitos

```bash
# Swap deve estar desabilitado
free -h | grep Swap
# Deve mostrar: Swap: 0B

# Módulos carregados
lsmod | grep br_netfilter
lsmod | grep overlay

# Parâmetros de rede
sudo sysctl net.bridge.bridge-nf-call-iptables
sudo sysctl net.ipv4.ip_forward
# Ambos devem retornar: = 1
```

## 2. Inicializar o Cluster

### Comando Básico

```bash
# Inicialização simples
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

### Comando Recomendado (com parâmetros)

```bash
# Obter IP privado
MASTER_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n1)

# Inicializar cluster
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$MASTER_IP \
  --control-plane-endpoint=$MASTER_IP \
  --kubernetes-version=v1.28.0

# Exemplo com IP fixo:
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=10.0.1.10 \
  --control-plane-endpoint=10.0.1.10
```

### Parâmetros Importantes

| Parâmetro | Descrição | Exemplo |
|-----------|-----------|---------|
| `--pod-network-cidr` | CIDR para pods (depende do CNI) | 10.244.0.0/16 (Flannel/Calico) |
| `--apiserver-advertise-address` | IP que o API Server anuncia | 10.0.1.10 |
| `--control-plane-endpoint` | Endpoint do control plane (HA) | 10.0.1.10 ou loadbalancer.com |
| `--kubernetes-version` | Versão específica do K8s | v1.28.0 |
| `--service-cidr` | CIDR para services | 10.96.0.0/12 (padrão) |

### Inicialização com Arquivo de Configuração

```bash
# Criar arquivo de configuração
cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: "10.0.1.10:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
apiServer:
  certSANs:
  - "10.0.1.10"
  - "k8s-master-1"
  extraArgs:
    authorization-mode: "Node,RBAC"
etcd:
  local:
    dataDir: "/var/lib/etcd"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
  kubeletExtraArgs:
    cgroup-driver: "systemd"
EOF

# Inicializar com arquivo
sudo kubeadm init --config kubeadm-config.yaml
```

## 3. Saída do kubeadm init

### Saída Esperada

```
[init] Using Kubernetes version: v1.28.0
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] Generating "etcd/peer" certificate and key
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file
[kubelet-start] Writing kubelet configuration to file
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane
[apiclient] All control plane components are healthy after 15.003 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config"
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node k8s-master-1 as control-plane
[bootstrap-token] Using token: abcdef.0123456789abcdef
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.1.10:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

### Salvar Informações Importantes

```bash
# Salvar comando de join
sudo kubeadm token create --print-join-command > ~/join-command.sh
chmod +x ~/join-command.sh

# Salvar token
sudo kubeadm token list

# Salvar hash do CA
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^.* //'
```

## 4. Configurar admin.conf

### Estrutura do admin.conf

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <base64-encoded-ca-cert>
    server: https://10.0.1.10:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
users:
- name: kubernetes-admin
  user:
    client-certificate-data: <base64-encoded-client-cert>
    client-key-data: <base64-encoded-client-key>
```

### Configurar para Usuário Regular

```bash
# Criar diretório .kube
mkdir -p $HOME/.kube

# Copiar admin.conf
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# Ajustar permissões
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verificar permissões
ls -l $HOME/.kube/config
# Deve mostrar: -rw------- 1 ubuntu ubuntu

# Verificar conteúdo
cat $HOME/.kube/config
```

### Configurar para Root (alternativa)

```bash
# Exportar variável de ambiente
export KUBECONFIG=/etc/kubernetes/admin.conf

# Adicionar ao .bashrc para persistir
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> ~/.bashrc
source ~/.bashrc
```

## 5. Verificar Cluster

### Comandos Básicos

```bash
# Ver versão do kubectl
kubectl version --short

# Ver informações do cluster
kubectl cluster-info

# Saída esperada:
# Kubernetes control plane is running at https://10.0.1.10:6443
# CoreDNS is running at https://10.0.1.10:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

# Ver nós
kubectl get nodes

# Saída:
# NAME           STATUS     ROLES           AGE   VERSION
# k8s-master-1   NotReady   control-plane   2m    v1.28.0
# (NotReady porque CNI ainda não foi instalado)

# Ver pods do sistema
kubectl get pods -n kube-system

# Ver todos os recursos
kubectl get all -A
```

### Verificar Componentes

```bash
# Ver status dos componentes
kubectl get componentstatuses

# Ver pods do control plane
kubectl get pods -n kube-system -o wide

# Saída esperada:
# NAME                                   READY   STATUS    RESTARTS
# coredns-5d78c9869d-xxxxx              0/1     Pending   0
# coredns-5d78c9869d-yyyyy              0/1     Pending   0
# etcd-k8s-master-1                     1/1     Running   0
# kube-apiserver-k8s-master-1           1/1     Running   0
# kube-controller-manager-k8s-master-1  1/1     Running   0
# kube-proxy-xxxxx                      1/1     Running   0
# kube-scheduler-k8s-master-1           1/1     Running   0

# Ver logs dos componentes
kubectl logs -n kube-system kube-apiserver-k8s-master-1
kubectl logs -n kube-system etcd-k8s-master-1
```

## 6. Arquivos Criados pelo kubeadm init

### Certificados (/etc/kubernetes/pki)

```bash
# Listar certificados
sudo ls -la /etc/kubernetes/pki/

# Estrutura:
/etc/kubernetes/pki/
├── apiserver.crt                    # Certificado do API Server
├── apiserver.key
├── apiserver-etcd-client.crt        # Cliente do API Server para etcd
├── apiserver-etcd-client.key
├── apiserver-kubelet-client.crt     # Cliente do API Server para kubelet
├── apiserver-kubelet-client.key
├── ca.crt                           # CA do cluster
├── ca.key
├── front-proxy-ca.crt               # CA do front proxy
├── front-proxy-ca.key
├── front-proxy-client.crt
├── front-proxy-client.key
├── sa.key                           # Service Account key
├── sa.pub
└── etcd/
    ├── ca.crt                       # CA do etcd
    ├── ca.key
    ├── healthcheck-client.crt
    ├── healthcheck-client.key
    ├── peer.crt                     # Certificado peer do etcd
    ├── peer.key
    ├── server.crt                   # Certificado do servidor etcd
    └── server.key

# Verificar validade dos certificados
sudo kubeadm certs check-expiration

# Saída:
# CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY
# admin.conf                 Dec 31, 2024 12:00 UTC   364d            ca
# apiserver                  Dec 31, 2024 12:00 UTC   364d            ca
# apiserver-etcd-client      Dec 31, 2024 12:00 UTC   364d            etcd-ca
# ...
```

### Kubeconfigs (/etc/kubernetes)

```bash
# Listar kubeconfigs
sudo ls -la /etc/kubernetes/*.conf

# Arquivos:
/etc/kubernetes/
├── admin.conf                # Administrador (full access)
├── controller-manager.conf   # Controller Manager
├── kubelet.conf              # Kubelet
└── scheduler.conf            # Scheduler

# Ver conteúdo
sudo cat /etc/kubernetes/admin.conf
```

### Manifestos (/etc/kubernetes/manifests)

```bash
# Listar manifestos dos componentes estáticos
sudo ls -la /etc/kubernetes/manifests/

# Arquivos:
/etc/kubernetes/manifests/
├── etcd.yaml
├── kube-apiserver.yaml
├── kube-controller-manager.yaml
└── kube-scheduler.yaml

# Ver manifesto do API Server
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

## 7. Copiar admin.conf para Máquina Local

### Via SCP

```bash
# Na máquina local
mkdir -p ~/.kube

# Copiar do master
scp -i ~/.ssh/id_rsa ubuntu@<IP-MASTER>:~/.kube/config ~/.kube/config

# Ou copiar direto do /etc/kubernetes
scp -i ~/.ssh/id_rsa ubuntu@<IP-MASTER>:/etc/kubernetes/admin.conf ~/.kube/config

# Verificar
kubectl get nodes
```

### Ajustar IP no kubeconfig

Se o master usa IP privado, ajustar para IP público:

```bash
# Ver IP atual
grep server ~/.kube/config

# Alterar para IP público
MASTER_PUBLIC_IP="54.xxx.xxx.xxx"
sed -i "s|server: https://10.0.1.10:6443|server: https://$MASTER_PUBLIC_IP:6443|" ~/.kube/config

# Verificar
kubectl cluster-info
```

### Via Terraform Output

```bash
# Se usou Terraform
cd terraform
MASTER_IP=$(terraform output -raw master_public_ips | jq -r '.[0]')

# Copiar config
scp -i ~/.ssh/id_rsa ubuntu@$MASTER_IP:~/.kube/config ~/.kube/config

# Ajustar IP
sed -i "s|server: https://10.0.1.10:6443|server: https://$MASTER_IP:6443|" ~/.kube/config
```

## 8. Múltiplos Contextos

### Adicionar Novo Cluster ao kubeconfig

```bash
# Ver contextos atuais
kubectl config get-contexts

# Adicionar novo cluster
kubectl config set-cluster k8s-aws \
  --server=https://54.xxx.xxx.xxx:6443 \
  --certificate-authority=/path/to/ca.crt

# Adicionar credenciais
kubectl config set-credentials k8s-admin \
  --client-certificate=/path/to/client.crt \
  --client-key=/path/to/client.key

# Criar contexto
kubectl config set-context k8s-aws-context \
  --cluster=k8s-aws \
  --user=k8s-admin

# Usar contexto
kubectl config use-context k8s-aws-context

# Ver contexto atual
kubectl config current-context
```

### Mesclar Múltiplos kubeconfigs

```bash
# Backup do config atual
cp ~/.kube/config ~/.kube/config.bak

# Mesclar configs
KUBECONFIG=~/.kube/config:~/other-cluster-config kubectl config view --flatten > ~/.kube/merged-config

# Substituir
mv ~/.kube/merged-config ~/.kube/config

# Ver todos os contextos
kubectl config get-contexts
```

## 9. Troubleshooting

### kubeadm init falha

```bash
# Ver logs detalhados
sudo kubeadm init --v=5

# Resetar e tentar novamente
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd
sudo kubeadm init ...
```

### Erro: port 6443 already in use

```bash
# Ver o que está usando a porta
sudo netstat -tulpn | grep 6443

# Parar processo
sudo systemctl stop kube-apiserver

# Ou resetar kubeadm
sudo kubeadm reset -f
```

### Erro: connection refused ao usar kubectl

```bash
# Verificar se API Server está rodando
sudo systemctl status kubelet
kubectl get pods -n kube-system | grep apiserver

# Ver logs do kubelet
sudo journalctl -u kubelet -f

# Verificar certificados
sudo kubeadm certs check-expiration
```

### Nó fica NotReady

```bash
# Instalar CNI (Calico)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Aguardar pods do Calico
kubectl get pods -n kube-system -w

# Verificar nó
kubectl get nodes
```

## 10. Script Completo de Inicialização

```bash
#!/bin/bash
# init-cluster.sh - Inicializar cluster Kubernetes

set -e

echo "=== Inicializando Cluster Kubernetes ==="

# Obter IP privado
MASTER_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n1)
echo "Master IP: $MASTER_IP"

# Verificar pré-requisitos
echo "Verificando pré-requisitos..."
if [ $(free | grep Swap | awk '{print $2}') -ne 0 ]; then
    echo "❌ Swap está habilitado!"
    exit 1
fi

if ! lsmod | grep -q br_netfilter; then
    echo "❌ Módulo br_netfilter não carregado!"
    exit 1
fi

echo "✅ Pré-requisitos OK"

# Inicializar cluster
echo "Inicializando cluster..."
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$MASTER_IP \
  --control-plane-endpoint=$MASTER_IP \
  | tee ~/kubeadm-init.log

# Configurar kubectl
echo "Configurando kubectl..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Salvar comando de join
echo "Salvando comando de join..."
kubeadm token create --print-join-command > ~/join-command.sh
chmod +x ~/join-command.sh

# Verificar cluster
echo "Verificando cluster..."
kubectl get nodes
kubectl get pods -n kube-system

echo ""
echo "=== Cluster inicializado com sucesso! ==="
echo ""
echo "Próximos passos:"
echo "1. Instalar CNI: kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml"
echo "2. Adicionar workers: Execute o comando em ~/join-command.sh nos workers"
echo ""
echo "Comando de join salvo em: ~/join-command.sh"
cat ~/join-command.sh
```

## Resumo

**Inicializar cluster:**
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

**Configurar kubectl:**
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**Verificar:**
```bash
kubectl get nodes
kubectl get pods -A
```

**Próximo passo:** Instalar CNI (Calico/Flannel) 🚀
