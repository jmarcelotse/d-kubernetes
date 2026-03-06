# Portas TCP e UDP dos Componentes do Kubernetes

Este documento lista todas as portas de rede utilizadas pelos componentes do Kubernetes, essenciais para configuração de firewalls, security groups e troubleshooting de conectividade.

## Visão Geral

```
┌─────────────────────────────────────────────────────┐
│              CONTROL PLANE                          │
│                                                     │
│  API Server:        6443 (HTTPS)                    │
│  etcd:              2379-2380 (Client/Peer)         │
│  Scheduler:         10259 (HTTPS)                   │
│  Controller Mgr:    10257 (HTTPS)                   │
│  Cloud Controller:  10258 (HTTPS)                   │
└─────────────────────────────────────────────────────┘
                          │
                          │
┌─────────────────────────────────────────────────────┐
│              WORKER NODES                           │
│                                                     │
│  Kubelet:           10250 (HTTPS)                   │
│  Kubelet (read):    10255 (HTTP) - deprecated       │
│  Kube-proxy:        10256 (Health)                  │
│  NodePort Range:    30000-32767                     │
└─────────────────────────────────────────────────────┘
```

## Control Plane - Portas

### kube-apiserver

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 6443 | TCP | Inbound | Todos | API Server (HTTPS) - Principal |
| 8080 | TCP | Inbound | Local | API Server (HTTP) - Inseguro, geralmente desabilitado |

**Detalhes:**
- **6443**: Porta padrão para API HTTPS. Todos os componentes (kubectl, kubelet, scheduler, controllers) se comunicam através desta porta
- **8080**: Porta HTTP sem autenticação. Deprecated e deve estar desabilitada em produção

**Acesso necessário:**
- kubectl (de qualquer lugar que precise gerenciar o cluster)
- Kubelet (de todos os worker nodes)
- Scheduler e Controller Manager (do control plane)
- Load balancer (em configurações HA)

**Exemplo de firewall:**
```bash
# Permitir acesso ao API Server
iptables -A INPUT -p tcp --dport 6443 -j ACCEPT

# AWS Security Group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 6443 \
  --cidr 0.0.0.0/0
```

### etcd

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 2379 | TCP | Inbound | API Server, etcdctl | Cliente API |
| 2380 | TCP | Inbound | Peers etcd | Comunicação entre peers |

**Detalhes:**
- **2379**: Porta para clientes (API Server) se comunicarem com etcd
- **2380**: Porta para comunicação entre nodes do cluster etcd (replicação, eleição de líder)

**Acesso necessário:**
- **2379**: API Server, ferramentas de backup
- **2380**: Outros nodes etcd (em cluster etcd)

**Topologias:**

**Stacked etcd (etcd no mesmo node do control plane):**
```
Control Plane Node 1:
  - API Server → localhost:2379
  - etcd → outros etcd nodes:2380
```

**External etcd (etcd em nodes dedicados):**
```
etcd Node 1, 2, 3:
  - 2379: API Server
  - 2380: Outros etcd nodes
```

**Exemplo de firewall:**
```bash
# Permitir API Server acessar etcd
iptables -A INPUT -p tcp --dport 2379 -s <api-server-ip> -j ACCEPT

# Permitir comunicação entre etcd peers
iptables -A INPUT -p tcp --dport 2380 -s <etcd-peer-ips> -j ACCEPT
```

### kube-scheduler

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 10259 | TCP | Inbound | Monitoramento | HTTPS - Métricas e health |
| 10251 | TCP | Inbound | Monitoramento | HTTP - Deprecated |

**Detalhes:**
- **10259**: Porta segura (HTTPS) para métricas e health checks
- **10251**: Porta insegura (HTTP), deprecated desde Kubernetes 1.13

**Acesso necessário:**
- Ferramentas de monitoramento (Prometheus, etc.)
- Health check systems

**Endpoints:**
```bash
# Health check
curl -k https://localhost:10259/healthz

# Métricas
curl -k https://localhost:10259/metrics
```

### kube-controller-manager

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 10257 | TCP | Inbound | Monitoramento | HTTPS - Métricas e health |
| 10252 | TCP | Inbound | Monitoramento | HTTP - Deprecated |

**Detalhes:**
- **10257**: Porta segura (HTTPS) para métricas e health checks
- **10252**: Porta insegura (HTTP), deprecated desde Kubernetes 1.13

**Acesso necessário:**
- Ferramentas de monitoramento
- Health check systems

**Endpoints:**
```bash
# Health check
curl -k https://localhost:10257/healthz

# Métricas
curl -k https://localhost:10257/metrics
```

### cloud-controller-manager

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 10258 | TCP | Inbound | Monitoramento | HTTPS - Métricas e health |

**Detalhes:**
- **10258**: Porta segura (HTTPS) para métricas e health checks
- Apenas presente quando usando cloud controller manager

**Acesso necessário:**
- Ferramentas de monitoramento

## Worker Nodes - Portas

### kubelet

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 10250 | TCP | Inbound | API Server, kubectl | API do kubelet (HTTPS) |
| 10255 | TCP | Inbound | Monitoramento | Read-only API (HTTP) - Deprecated |
| 10248 | TCP | Inbound | Local | Health check endpoint |

**Detalhes:**
- **10250**: Porta principal do kubelet. API completa com autenticação
- **10255**: Porta read-only sem autenticação. Deprecated e geralmente desabilitada
- **10248**: Porta local para health checks (localhost apenas)

**Acesso necessário:**
- **10250**: API Server (para gerenciar pods), kubectl (para exec, logs, port-forward)
- **10248**: Apenas localhost (health checks)

**Operações via 10250:**
- kubectl exec
- kubectl logs
- kubectl port-forward
- kubectl attach
- Métricas de recursos

**Exemplo de uso:**
```bash
# Logs via kubelet API
curl -k https://node-ip:10250/logs/

# Métricas
curl -k https://node-ip:10250/metrics

# Health check (local)
curl http://localhost:10248/healthz
```

**Exemplo de firewall:**
```bash
# Permitir API Server acessar kubelet
iptables -A INPUT -p tcp --dport 10250 -s <api-server-ip> -j ACCEPT

# Permitir kubectl de admin nodes
iptables -A INPUT -p tcp --dport 10250 -s <admin-network> -j ACCEPT
```

### kube-proxy

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 10256 | TCP | Inbound | Monitoramento | Health check endpoint |

**Detalhes:**
- **10256**: Porta para health checks do kube-proxy
- Não expõe métricas (usa API Server para isso)

**Acesso necessário:**
- Health check systems
- Monitoramento

**Exemplo:**
```bash
# Health check
curl http://localhost:10256/healthz
```

### NodePort Services

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 30000-32767 | TCP/UDP | Inbound | Clientes externos | Range de NodePort Services |

**Detalhes:**
- Range padrão para Services do tipo NodePort
- Pode ser customizado com `--service-node-port-range`
- Cada Service NodePort usa uma porta única neste range

**Exemplo de Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Porta no range 30000-32767
```

**Acesso:**
```bash
# Acessar via qualquer node IP
curl http://<node-ip>:30080
```

**Exemplo de firewall:**
```bash
# Permitir range completo de NodePort
iptables -A INPUT -p tcp --dport 30000:32767 -j ACCEPT
iptables -A INPUT -p udp --dport 30000:32767 -j ACCEPT

# AWS Security Group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 30000-32767 \
  --cidr 0.0.0.0/0
```

## Networking - Portas Adicionais

### CNI Plugins

Diferentes CNI plugins usam portas específicas:

#### Calico

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 179 | TCP | Bidirectional | BGP | BGP para roteamento |
| 4789 | UDP | Bidirectional | VXLAN | VXLAN overlay (se usado) |
| 5473 | TCP | Inbound | Typha | Typha (opcional) |

#### Flannel

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 8285 | UDP | Bidirectional | Flannel | UDP backend |
| 8472 | UDP | Bidirectional | VXLAN | VXLAN overlay |

#### Weave Net

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 6783 | TCP/UDP | Bidirectional | Weave | Control e data |
| 6784 | UDP | Bidirectional | Weave | Fast datapath |

#### Cilium

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 4240 | TCP | Inbound | Health | Health checks |
| 4244 | TCP | Inbound | Hubble | Hubble server |
| 4245 | TCP | Inbound | Hubble | Hubble relay |
| 8472 | UDP | Bidirectional | VXLAN | VXLAN overlay |

### DNS (CoreDNS)

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 53 | TCP/UDP | Inbound | Pods | DNS queries |
| 9153 | TCP | Inbound | Monitoramento | Métricas |

**Detalhes:**
- CoreDNS roda como pods no cluster
- Service ClusterIP: geralmente 10.96.0.10
- Todos os pods usam para resolução DNS

### Ingress Controllers

#### NGINX Ingress

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 80 | TCP | Inbound | Clientes | HTTP |
| 443 | TCP | Inbound | Clientes | HTTPS |
| 8443 | TCP | Inbound | Admission | Webhook |
| 10254 | TCP | Inbound | Monitoramento | Health e métricas |

#### Traefik

| Porta | Protocolo | Direção | Usado Por | Descrição |
|-------|-----------|---------|-----------|-----------|
| 80 | TCP | Inbound | Clientes | HTTP |
| 443 | TCP | Inbound | Clientes | HTTPS |
| 8080 | TCP | Inbound | Dashboard | Web UI |
| 9000 | TCP | Inbound | Monitoramento | Métricas |

## Resumo por Componente

### Control Plane Node

```
Portas Obrigatórias:
├── 6443    (TCP) - API Server
├── 2379    (TCP) - etcd client
├── 2380    (TCP) - etcd peer
├── 10250   (TCP) - kubelet API
├── 10259   (TCP) - kube-scheduler
└── 10257   (TCP) - kube-controller-manager

Portas Opcionais:
├── 10258   (TCP) - cloud-controller-manager
└── 10256   (TCP) - kube-proxy health
```

### Worker Node

```
Portas Obrigatórias:
├── 10250   (TCP) - kubelet API
└── 10256   (TCP) - kube-proxy health

Portas Opcionais:
└── 30000-32767 (TCP/UDP) - NodePort Services

Portas CNI (dependendo do plugin):
├── 179     (TCP) - Calico BGP
├── 4789    (UDP) - VXLAN
└── 8472    (UDP) - Flannel VXLAN
```

## Configuração de Firewall

### Control Plane

```bash
# API Server
iptables -A INPUT -p tcp --dport 6443 -j ACCEPT

# etcd
iptables -A INPUT -p tcp --dport 2379 -j ACCEPT
iptables -A INPUT -p tcp --dport 2380 -j ACCEPT

# Scheduler
iptables -A INPUT -p tcp --dport 10259 -j ACCEPT

# Controller Manager
iptables -A INPUT -p tcp --dport 10257 -j ACCEPT

# Kubelet
iptables -A INPUT -p tcp --dport 10250 -j ACCEPT
```

### Worker Nodes

```bash
# Kubelet
iptables -A INPUT -p tcp --dport 10250 -j ACCEPT

# NodePort Services
iptables -A INPUT -p tcp --dport 30000:32767 -j ACCEPT
iptables -A INPUT -p udp --dport 30000:32767 -j ACCEPT

# CNI (exemplo Calico)
iptables -A INPUT -p tcp --dport 179 -j ACCEPT
iptables -A INPUT -p udp --dport 4789 -j ACCEPT
```

### AWS Security Groups

**Control Plane Security Group:**
```bash
# API Server (de qualquer lugar ou VPN)
aws ec2 authorize-security-group-ingress \
  --group-id sg-control-plane \
  --protocol tcp --port 6443 \
  --cidr 0.0.0.0/0

# etcd (apenas entre control plane nodes)
aws ec2 authorize-security-group-ingress \
  --group-id sg-control-plane \
  --protocol tcp --port 2379-2380 \
  --source-group sg-control-plane

# Kubelet (do API Server)
aws ec2 authorize-security-group-ingress \
  --group-id sg-control-plane \
  --protocol tcp --port 10250 \
  --source-group sg-control-plane
```

**Worker Security Group:**
```bash
# Kubelet (do control plane)
aws ec2 authorize-security-group-ingress \
  --group-id sg-workers \
  --protocol tcp --port 10250 \
  --source-group sg-control-plane

# NodePort (de load balancers ou internet)
aws ec2 authorize-security-group-ingress \
  --group-id sg-workers \
  --protocol tcp --port 30000-32767 \
  --cidr 0.0.0.0/0

# Pod-to-Pod (entre workers)
aws ec2 authorize-security-group-ingress \
  --group-id sg-workers \
  --protocol all \
  --source-group sg-workers
```

### Azure NSG (Network Security Group)

```bash
# API Server
az network nsg rule create \
  --resource-group myResourceGroup \
  --nsg-name control-plane-nsg \
  --name allow-api-server \
  --priority 100 \
  --source-address-prefixes '*' \
  --destination-port-ranges 6443 \
  --protocol Tcp \
  --access Allow

# Kubelet
az network nsg rule create \
  --resource-group myResourceGroup \
  --nsg-name worker-nsg \
  --name allow-kubelet \
  --priority 100 \
  --source-address-prefixes VirtualNetwork \
  --destination-port-ranges 10250 \
  --protocol Tcp \
  --access Allow
```

### GCP Firewall Rules

```bash
# API Server
gcloud compute firewall-rules create allow-api-server \
  --allow tcp:6443 \
  --source-ranges 0.0.0.0/0 \
  --target-tags control-plane

# Kubelet
gcloud compute firewall-rules create allow-kubelet \
  --allow tcp:10250 \
  --source-tags control-plane \
  --target-tags worker

# NodePort
gcloud compute firewall-rules create allow-nodeport \
  --allow tcp:30000-32767,udp:30000-32767 \
  --source-ranges 0.0.0.0/0 \
  --target-tags worker
```

## Troubleshooting de Conectividade

### Verificar Portas Abertas

```bash
# Verificar se porta está escutando
netstat -tlnp | grep <porta>
ss -tlnp | grep <porta>

# Testar conectividade
telnet <host> <porta>
nc -zv <host> <porta>

# Verificar com curl
curl -k https://<host>:<porta>/healthz
```

### Testar Conectividade do API Server

```bash
# De um worker node
curl -k https://<control-plane-ip>:6443/healthz

# Com kubectl
kubectl cluster-info
kubectl get --raw /healthz
```

### Testar Conectividade do kubelet

```bash
# Do control plane
curl -k https://<worker-ip>:10250/healthz

# Verificar certificados
openssl s_client -connect <worker-ip>:10250
```

### Testar Conectividade do etcd

```bash
# Health check
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# Verificar membros
ETCDCTL_API=3 etcdctl member list
```

### Logs de Componentes

```bash
# API Server
kubectl logs -n kube-system kube-apiserver-<node>

# Kubelet
journalctl -u kubelet -f

# Kube-proxy
kubectl logs -n kube-system kube-proxy-<pod>
```

## Customização de Portas

### API Server

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --secure-port=6443        # Customizar porta
    - --bind-address=0.0.0.0
```

### kubelet

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
port: 10250                      # Porta principal
readOnlyPort: 0                  # Desabilitar porta read-only
healthzPort: 10248               # Porta de health
```

### NodePort Range

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --service-node-port-range=30000-32767  # Customizar range
```

## Boas Práticas

### Segurança

1. **Minimize exposição**
   - Exponha apenas portas necessárias
   - Use security groups/firewalls restritivos
   - Limite acesso ao API Server

2. **Use TLS**
   - Sempre use portas HTTPS quando disponível
   - Desabilite portas HTTP inseguras (8080, 10255, 10251, 10252)

3. **Segmente redes**
   - Control plane em subnet privada
   - Workers em subnet separada
   - Use bastion hosts para acesso

4. **Monitore**
   - Configure alertas para portas abertas inesperadas
   - Audite acessos ao API Server
   - Monitore tráfego de rede

### Alta Disponibilidade

1. **Load Balancer para API Server**
   - Distribua tráfego entre múltiplos API Servers
   - Use porta 6443 no load balancer
   - Configure health checks

2. **etcd em cluster**
   - Use número ímpar de nodes (3, 5, 7)
   - Garanta conectividade entre peers (porta 2380)
   - Monitore latência

### Performance

1. **Latência de rede**
   - Minimize latência entre control plane e workers
   - Use redes de alta velocidade
   - Considere proximidade geográfica

2. **Bandwidth**
   - Garanta bandwidth adequado para API Server
   - Monitore saturação de rede
   - Use CNI plugins eficientes

## Referências

- [Kubernetes Ports and Protocols](https://kubernetes.io/docs/reference/networking/ports-and-protocols/)
- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#check-required-ports)
- [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)


---

## Exemplos Práticos

### Exemplo 1: Verificar Portas em Uso

```bash
# Ver portas abertas no control plane node
sudo netstat -tlnp | grep -E "6443|2379|2380|10250|10251|10252"

# Ver portas abertas no worker node
sudo netstat -tlnp | grep -E "10250|30000"

# Verificar se API Server está escutando
curl -k https://localhost:6443/version

# Verificar etcd
sudo netstat -tlnp | grep etcd
```

### Exemplo 2: Testar Conectividade com API Server

```bash
# Testar de fora do cluster
curl -k https://<control-plane-ip>:6443/version

# Testar com kubectl
kubectl cluster-info

# Ver endpoints do API Server
kubectl get endpoints kubernetes

# Testar de dentro de um pod
kubectl run test --image=curlimages/curl -it --rm -- \
  curl -k https://kubernetes.default.svc.cluster.local:443/version
```

### Exemplo 3: Verificar Portas do Kubelet

```bash
# Testar porta do kubelet (no node)
curl -k https://localhost:10250/healthz

# Ver métricas do kubelet
curl -k https://localhost:10250/metrics

# Testar porta read-only (se habilitada)
curl http://localhost:10255/healthz
```

### Exemplo 4: Testar NodePort

```bash
# Criar service NodePort
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=2

# Expor deployment
kubectl expose deployment nginx --port=80 --target-port=80 --type=NodePort

# Ver porta atribuída
kubectl get service nginx

# Testar acesso
curl http://<node-ip>:30080

# Verificar porta no node
sudo netstat -tlnp | grep 30080
```

### Exemplo 5: Verificar Portas do etcd

```bash
# Verificar se etcd está escutando
sudo netstat -tlnp | grep 2379

# Testar conectividade com etcd (de dentro do pod)
kubectl exec -n kube-system etcd-<node-name> -- sh -c \
  "etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health"

# Ver membros do cluster etcd
kubectl exec -n kube-system etcd-<node-name> -- sh -c \
  "etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list"
```

### Exemplo 6: Configurar Firewall

```bash
# Control Plane - permitir portas necessárias
sudo ufw allow 6443/tcp    # API Server
sudo ufw allow 2379:2380/tcp  # etcd
sudo ufw allow 10250/tcp   # Kubelet API
sudo ufw allow 10251/tcp   # kube-scheduler
sudo ufw allow 10252/tcp   # kube-controller-manager

# Worker Nodes - permitir portas necessárias
sudo ufw allow 10250/tcp   # Kubelet API
sudo ufw allow 30000:32767/tcp  # NodePort Services

# Verificar regras
sudo ufw status
```

### Exemplo 7: Monitorar Conexões

```bash
# Ver conexões ativas no API Server
sudo ss -tnp | grep 6443

# Ver conexões do kubelet
sudo ss -tnp | grep 10250

# Ver conexões do etcd
sudo ss -tnp | grep 2379

# Monitorar conexões em tempo real
watch -n 1 'sudo ss -tnp | grep -E "6443|10250|2379"'
```

---

## Fluxo de Comunicação por Portas

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE COMUNICAÇÃO POR PORTAS                 │
└─────────────────────────────────────────────────────────┘

1. USUÁRIO → API SERVER (6443)
   └─> kubectl → https://control-plane:6443

2. API SERVER → ETCD (2379)
   └─> API Server → https://etcd:2379
   └─> Leitura/escrita de dados

3. API SERVER → KUBELET (10250)
   └─> API Server → https://worker:10250
   └─> Comandos: logs, exec, port-forward

4. SCHEDULER → API SERVER (6443)
   └─> Scheduler → https://api-server:6443
   └─> Watch de pods, atribuição de nodes

5. CONTROLLER MANAGER → API SERVER (6443)
   └─> Controller → https://api-server:6443
   └─> Watch de recursos, reconciliação

6. KUBELET → API SERVER (6443)
   └─> Kubelet → https://api-server:6443
   └─> Registro de node, status de pods

7. KUBE-PROXY → API SERVER (6443)
   └─> Kube-proxy → https://api-server:6443
   └─> Watch de services e endpoints

8. ETCD CLUSTER (2380)
   └─> etcd-1 ↔ etcd-2 ↔ etcd-3
   └─> Replicação de dados

9. USUÁRIO → NODEPORT (30000-32767)
   └─> Cliente → http://worker:30080
   └─> Acesso externo a services
```

---

## Troubleshooting de Portas

### Porta Bloqueada

```bash
# Verificar se porta está aberta
telnet <host> <port>
# ou
nc -zv <host> <port>

# Verificar firewall
sudo ufw status
sudo iptables -L -n

# Verificar se processo está escutando
sudo netstat -tlnp | grep <port>
sudo ss -tlnp | grep <port>
```

### API Server Inacessível

```bash
# Verificar se API Server está rodando
kubectl get pods -n kube-system | grep apiserver

# Verificar porta 6443
sudo netstat -tlnp | grep 6443

# Testar conectividade
curl -k https://localhost:6443/version

# Ver logs
kubectl logs -n kube-system kube-apiserver-<node>
```

### NodePort não Funciona

```bash
# Verificar service
kubectl get service <service-name>

# Verificar se porta está no range correto (30000-32767)
kubectl describe service <service-name>

# Verificar se kube-proxy está rodando
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Verificar regras iptables
sudo iptables-save | grep <nodeport>

# Testar de dentro do cluster
kubectl run test --image=curlimages/curl -it --rm -- \
  curl http://<node-ip>:<nodeport>
```
