# Componentes dos Workers do Kubernetes

Os **Worker Nodes** (ou simplesmente Nodes) são as máquinas que executam as aplicações containerizadas no Kubernetes. Cada worker node contém três componentes principais que trabalham em conjunto para executar e gerenciar pods.

## Arquitetura do Worker Node

```
┌─────────────────────────────────────────────────────┐
│                  WORKER NODE                        │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │                                              │  │
│  │              kubelet                         │  │
│  │        (Agente Principal)                    │  │
│  │                                              │  │
│  └────────┬─────────────────────────────────────┘  │
│           │                                        │
│  ┌────────▼─────────┐      ┌──────────────────┐   │
│  │                  │      │                  │   │
│  │  kube-proxy      │      │  Container       │   │
│  │  (Proxy de Rede) │      │  Runtime         │   │
│  │                  │      │  (containerd)    │   │
│  └──────────────────┘      └────────┬─────────┘   │
│                                     │             │
│  ┌──────────────────────────────────▼──────────┐  │
│  │                                             │  │
│  │              PODS                           │  │
│  │                                             │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐    │  │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │    │  │
│  │  │┌───────┐│  │┌───────┐│  │┌───────┐│    │  │
│  │  ││ App A ││  ││ App B ││  ││ App C ││    │  │
│  │  │└───────┘│  │└───────┘│  │└───────┘│    │  │
│  │  └─────────┘  └─────────┘  └─────────┘    │  │
│  │                                             │  │
│  └─────────────────────────────────────────────┘  │
│                                                   │
└───────────────────────────────────────────────────┘
```

## 1. kubelet

### Descrição
O **kubelet** é o agente principal que roda em cada worker node. É o componente mais importante do node, responsável por garantir que os containers estejam rodando conforme especificado.

### Responsabilidades

**Gerenciamento de Pods**
- Recebe PodSpecs do API Server
- Garante que containers descritos estejam rodando
- Inicia e para containers conforme necessário
- Reporta status de pods ao Control Plane

**Registro do Node**
- Registra o node no cluster
- Envia informações sobre capacidade (CPU, memória, storage)
- Atualiza condições do node (Ready, MemoryPressure, DiskPressure)

**Health Checks**
- Executa probes de liveness (container está vivo?)
- Executa probes de readiness (container está pronto?)
- Executa probes de startup (container iniciou?)
- Reinicia containers que falham em health checks

**Gerenciamento de Volumes**
- Monta volumes especificados nos pods
- Gerencia persistent volumes
- Limpa volumes quando pods são deletados

**Coleta de Métricas**
- Expõe métricas de recursos (CPU, memória)
- Fornece dados para ferramentas de monitoramento
- Integra com cAdvisor para métricas de containers

**Execução de Comandos**
- Permite execução de comandos em containers (kubectl exec)
- Fornece logs de containers (kubectl logs)
- Habilita port-forwarding

### Funcionamento

```
┌─────────────────────────────────────────────────┐
│  1. Kubelet monitora API Server (watch)         │
│     - Busca pods atribuídos ao seu node         │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  2. Sincroniza estado desejado                  │
│     - Compara pods atuais com desejados         │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  3. Instrui Container Runtime                   │
│     - Pull de imagens                           │
│     - Criação de containers                     │
│     - Start/Stop de containers                  │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  4. Monitora saúde dos containers               │
│     - Executa probes                            │
│     - Reinicia containers com falha             │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  5. Reporta status ao API Server                │
│     - Status de pods                            │
│     - Condições do node                         │
│     - Recursos utilizados                       │
└─────────────────────────────────────────────────┘
```

### Health Probes

#### Liveness Probe
Verifica se o container está vivo. Se falhar, kubelet reinicia o container.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
spec:
  containers:
  - name: app
    image: myapp
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 3
      periodSeconds: 3
      timeoutSeconds: 1
      failureThreshold: 3
```

#### Readiness Probe
Verifica se o container está pronto para receber tráfego. Se falhar, remove do Service.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-http
spec:
  containers:
  - name: app
    image: myapp
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 1
      successThreshold: 1
      failureThreshold: 3
```

#### Startup Probe
Verifica se o container iniciou. Útil para aplicações com inicialização lenta.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-http
spec:
  containers:
  - name: app
    image: myapp
    startupProbe:
      httpGet:
        path: /startup
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 10
      timeoutSeconds: 1
      failureThreshold: 30  # 30 * 10 = 300s para iniciar
```

#### Tipos de Probes

**HTTP GET**
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: Awesome
```

**TCP Socket**
```yaml
livenessProbe:
  tcpSocket:
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 20
```

**Exec Command**
```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

**gRPC**
```yaml
livenessProbe:
  grpc:
    port: 9090
  initialDelaySeconds: 5
```

### Condições do Node

O kubelet reporta condições do node:

```bash
kubectl describe node node-1

Conditions:
  Type                 Status  Reason
  ----                 ------  ------
  MemoryPressure       False   KubeletHasSufficientMemory
  DiskPressure         False   KubeletHasNoDiskPressure
  PIDPressure          False   KubeletHasSufficientPID
  Ready                True    KubeletReady
```

**MemoryPressure**: Node está com pouca memória
**DiskPressure**: Node está com pouco espaço em disco
**PIDPressure**: Node está com muitos processos
**Ready**: Node está pronto para aceitar pods

### Configuração do kubelet

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
address: 0.0.0.0
port: 10250
readOnlyPort: 10255
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
- 10.96.0.10
maxPods: 110
podCIDR: 10.244.0.0/24
resolvConf: /etc/resolv.conf
runtimeRequestTimeout: 2m
tlsCertFile: /var/lib/kubelet/pki/kubelet.crt
tlsPrivateKeyFile: /var/lib/kubelet/pki/kubelet.key
```

### Portas do kubelet

- **10250**: API do kubelet (HTTPS)
- **10255**: Read-only API (HTTP, geralmente desabilitado)
- **10248**: Health check endpoint

### Comandos Úteis

```bash
# Ver logs do kubelet
journalctl -u kubelet -f

# Status do kubelet
systemctl status kubelet

# Reiniciar kubelet
systemctl restart kubelet

# Ver configuração do kubelet
kubectl get --raw /api/v1/nodes/node-1/proxy/configz | jq

# Métricas do kubelet
curl -k https://localhost:10250/metrics
```

## 2. kube-proxy

### Descrição
O **kube-proxy** é um proxy de rede que roda em cada node e mantém regras de rede que permitem a comunicação com pods dentro e fora do cluster.

### Responsabilidades

**Implementação de Services**
- Mantém regras de rede para Services
- Faz load balancing entre pods de um Service
- Permite acesso a Services via ClusterIP

**Roteamento de Tráfego**
- Encaminha tráfego para pods corretos
- Implementa políticas de rede
- Gerencia conectividade externa

**Service Discovery**
- Monitora API Server para mudanças em Services e Endpoints
- Atualiza regras de rede automaticamente
- Sincroniza estado de rede

### Modos de Operação

#### 1. iptables (Padrão)

**Características:**
- Usa regras iptables do Linux
- Baixo overhead
- Seleção aleatória de pod backend
- Modo mais comum

**Como funciona:**
```
Cliente → ClusterIP (virtual) → iptables rules 
→ DNAT para IP do Pod → Pod
```

**Exemplo de regras iptables:**
```bash
# Service: nginx-service (ClusterIP: 10.96.100.50)
# Backends: 10.244.1.5:80, 10.244.2.3:80

# Regra principal do Service
-A KUBE-SERVICES -d 10.96.100.50/32 -p tcp -m tcp --dport 80 \
  -j KUBE-SVC-NGINX

# Load balancing entre backends (50% cada)
-A KUBE-SVC-NGINX -m statistic --mode random --probability 0.5 \
  -j KUBE-SEP-BACKEND1
-A KUBE-SVC-NGINX -j KUBE-SEP-BACKEND2

# DNAT para pods
-A KUBE-SEP-BACKEND1 -p tcp -m tcp \
  -j DNAT --to-destination 10.244.1.5:80
-A KUBE-SEP-BACKEND2 -p tcp -m tcp \
  -j DNAT --to-destination 10.244.2.3:80
```

**Vantagens:**
- Simples e confiável
- Baixo consumo de recursos
- Bem testado

**Desvantagens:**
- Performance degrada com muitos Services
- Seleção aleatória apenas
- Difícil de debugar

#### 2. IPVS (IP Virtual Server)

**Características:**
- Usa Linux IPVS (kernel module)
- Melhor performance em clusters grandes
- Algoritmos de load balancing avançados
- Requer kernel com suporte a IPVS

**Algoritmos de load balancing:**
- **rr** (round-robin): Distribui sequencialmente
- **lc** (least connection): Menos conexões ativas
- **dh** (destination hashing): Hash do IP destino
- **sh** (source hashing): Hash do IP origem
- **sed** (shortest expected delay): Menor delay esperado
- **nq** (never queue): Distribui para servidor idle

**Configuração:**
```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  scheduler: "rr"  # round-robin
  syncPeriod: 30s
```

**Como funciona:**
```
Cliente → Virtual IP → IPVS → Real Server (Pod IP) → Pod
```

**Vantagens:**
- Melhor performance (hash tables vs chains)
- Algoritmos de LB avançados
- Suporta milhares de Services
- Menor latência

**Desvantagens:**
- Requer módulos kernel adicionais
- Mais complexo de configurar
- Fallback para iptables se IPVS não disponível

#### 3. userspace (Legado)

**Características:**
- Modo mais antigo
- kube-proxy atua como proxy real
- Maior overhead
- Raramente usado

**Como funciona:**
```
Cliente → iptables → kube-proxy (userspace) → Pod
```

**Desvantagens:**
- Alto overhead (context switching)
- Menor performance
- Deprecated

### Tipos de Services

#### ClusterIP (Padrão)
Expõe Service em IP interno do cluster.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

#### NodePort
Expõe Service em porta estática de cada node.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # 30000-32767
```

**Acesso:**
```
<NodeIP>:30080 → kube-proxy → Pod
```

#### LoadBalancer
Cria load balancer externo (cloud provider).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

#### ExternalName
Mapeia Service para nome DNS externo.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  type: ExternalName
  externalName: api.example.com
```

### Session Affinity

Mantém cliente conectado ao mesmo pod:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 horas
  ports:
  - port: 80
```

### Configuração do kube-proxy

```yaml
# /var/lib/kube-proxy/config.yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
bindAddress: 0.0.0.0
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
clusterCIDR: 10.244.0.0/16
mode: "iptables"  # ou "ipvs" ou "userspace"
iptables:
  masqueradeAll: false
  masqueradeBit: 14
  minSyncPeriod: 0s
  syncPeriod: 30s
```

### Comandos Úteis

```bash
# Ver logs do kube-proxy
kubectl logs -n kube-system kube-proxy-xxxxx

# Ver regras iptables criadas pelo kube-proxy
iptables-save | grep KUBE

# Ver virtual servers IPVS
ipvsadm -Ln

# Ver configuração do kube-proxy
kubectl get configmap -n kube-system kube-proxy -o yaml

# Reiniciar kube-proxy
kubectl delete pod -n kube-system -l k8s-app=kube-proxy
```

## 3. Container Runtime

### Descrição
O **Container Runtime** é o software responsável por executar containers no node. Ele implementa a Container Runtime Interface (CRI) para comunicação com o kubelet.

### Responsabilidades

**Gerenciamento de Containers**
- Baixa imagens de container registries
- Cria containers a partir de imagens
- Inicia e para containers
- Remove containers

**Gerenciamento de Imagens**
- Pull de imagens
- Armazena imagens localmente
- Remove imagens não utilizadas
- Gerencia cache de imagens

**Isolamento e Recursos**
- Configura namespaces do kernel
- Aplica cgroups para limitar recursos
- Monta volumes e filesystems
- Configura rede de containers

### Container Runtime Interface (CRI)

Interface padrão entre kubelet e runtime:

```
┌──────────────┐
│   Kubelet    │
└──────┬───────┘
       │ CRI (gRPC)
       │
┌──────▼────────────────┐
│   CRI Runtime         │
│   (containerd/CRI-O)  │
└──────┬────────────────┘
       │
┌──────▼────────┐
│  OCI Runtime  │
│  (runc/crun)  │
└───────────────┘
```

### Runtimes Suportados

#### containerd

**Características:**
- Runtime mais popular
- Usado por Docker e Kubernetes
- Projeto graduado da CNCF
- Leve e focado em performance

**Instalação:**
```bash
# Instalar containerd
apt-get install containerd

# Configurar
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Habilitar CRI plugin
systemctl enable containerd
systemctl start containerd
```

**Configuração do kubelet:**
```yaml
# /var/lib/kubelet/config.yaml
containerRuntimeEndpoint: unix:///run/containerd/containerd.sock
```

**Comandos (ctr):**
```bash
# Listar containers
ctr -n k8s.io containers list

# Listar imagens
ctr -n k8s.io images list

# Pull de imagem
ctr -n k8s.io images pull docker.io/library/nginx:latest
```

**Comandos (crictl - CRI tool):**
```bash
# Listar pods
crictl pods

# Listar containers
crictl ps

# Logs de container
crictl logs <container-id>

# Executar comando
crictl exec -it <container-id> /bin/sh

# Inspecionar container
crictl inspect <container-id>

# Stats de containers
crictl stats
```

#### CRI-O

**Características:**
- Runtime otimizado para Kubernetes
- Implementa apenas CRI (sem extras)
- Leve e focado
- Usado por OpenShift

**Instalação:**
```bash
# Adicionar repositório
OS=xUbuntu_20.04
VERSION=1.24

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

# Instalar
apt-get update
apt-get install cri-o cri-o-runc

# Iniciar
systemctl enable crio
systemctl start crio
```

**Configuração do kubelet:**
```yaml
# /var/lib/kubelet/config.yaml
containerRuntimeEndpoint: unix:///var/run/crio/crio.sock
```

#### Docker Engine (Deprecated)

**Nota:** Docker como runtime direto foi removido no Kubernetes 1.24. Use containerd ou CRI-O.

**Migração:**
```bash
# Docker usa containerd internamente
# Migrar para containerd direto:

# 1. Instalar containerd
apt-get install containerd

# 2. Atualizar kubelet config
# containerRuntimeEndpoint: unix:///run/containerd/containerd.sock

# 3. Reiniciar kubelet
systemctl restart kubelet
```

### Low-Level Runtimes (OCI)

#### runc
- Implementação de referência OCI
- Usado por containerd e CRI-O
- Padrão da indústria

#### crun
- Alternativa escrita em C
- Mais rápido que runc
- Menor consumo de memória

#### Kata Containers
- Executa containers em VMs leves
- Maior isolamento
- Para workloads sensíveis

#### gVisor (runsc)
- Sandbox de segurança
- Syscalls em user-space
- Desenvolvido pelo Google

### Configuração de Runtime

**containerd:**
```toml
# /etc/containerd/config.toml
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  [plugins."io.containerd.grpc.v1.cri".containerd]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
          SystemdCgroup = true
```

**CRI-O:**
```toml
# /etc/crio/crio.conf
[crio.runtime]
default_runtime = "runc"

[crio.runtime.runtimes.runc]
runtime_path = "/usr/bin/runc"
runtime_type = "oci"
```

### Verificando Runtime

```bash
# Ver runtime configurado
kubectl get nodes -o wide

# Detalhes do runtime
kubectl describe node node-1 | grep "Container Runtime"

# Versão do containerd
containerd --version

# Versão do CRI-O
crio --version

# Testar CRI
crictl version
```

## Comunicação entre Componentes

```
┌─────────────────────────────────────────────────┐
│  Control Plane (API Server)                     │
└──────────────────┬──────────────────────────────┘
                   │
                   │ HTTPS (watch)
                   │
┌──────────────────▼──────────────────────────────┐
│  kubelet                                        │
│  - Recebe PodSpecs                              │
│  - Reporta status                               │
└──────────┬────────────────────┬─────────────────┘
           │                    │
           │ CRI (gRPC)         │ Configura rede
           │                    │
┌──────────▼──────────┐  ┌──────▼────────────────┐
│  Container Runtime  │  │  kube-proxy           │
│  - Executa pods     │  │  - Regras de rede     │
│  - Gerencia imagens │  │  - Load balancing     │
└─────────────────────┘  └───────────────────────┘
```

## Recursos do Node

### Capacidade e Alocável

```bash
kubectl describe node node-1

Capacity:
  cpu:                4
  ephemeral-storage:  100Gi
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             16Gi
  pods:               110

Allocatable:
  cpu:                3800m
  ephemeral-storage:  92Gi
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             15Gi
  pods:               110
```

**Capacity**: Recursos totais do node
**Allocatable**: Recursos disponíveis para pods (após reservas do sistema)

### Resource Requests e Limits

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

**Requests**: Recursos garantidos (usado pelo scheduler)
**Limits**: Máximo que o container pode usar

### QoS Classes

**Guaranteed**: Requests = Limits
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "500m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

**Burstable**: Requests < Limits
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

**BestEffort**: Sem requests/limits
```yaml
# Sem resources definidos
```

## Comandos Úteis

```bash
# Listar nodes
kubectl get nodes

# Detalhes de um node
kubectl describe node node-1

# Ver pods em um node
kubectl get pods --field-selector spec.nodeName=node-1

# Marcar node como não-agendável
kubectl cordon node-1

# Drenar pods de um node
kubectl drain node-1 --ignore-daemonsets --delete-emptydir-data

# Reabilitar node
kubectl uncordon node-1

# Remover node do cluster
kubectl delete node node-1

# Ver uso de recursos
kubectl top node
kubectl top pod

# Labels de um node
kubectl get node node-1 --show-labels

# Adicionar label
kubectl label node node-1 disktype=ssd

# Adicionar taint
kubectl taint node node-1 key=value:NoSchedule

# Remover taint
kubectl taint node node-1 key=value:NoSchedule-
```

## Boas Práticas

### Dimensionamento
- Dimensione nodes adequadamente (CPU, memória, storage)
- Use node pools para diferentes tipos de workload
- Configure resource requests e limits em todos os pods
- Monitore utilização de recursos

### Alta Disponibilidade
- Tenha múltiplos worker nodes
- Distribua pods entre nodes (anti-affinity)
- Use ReplicaSets para redundância
- Configure PodDisruptionBudgets

### Segurança
- Mantenha kubelet, kube-proxy e runtime atualizados
- Use RBAC para limitar acesso ao kubelet
- Habilite TLS para comunicação do kubelet
- Configure Pod Security Standards
- Use runtimes com melhor isolamento (Kata, gVisor) para workloads sensíveis

### Monitoramento
- Monitore saúde dos componentes
- Acompanhe uso de recursos (CPU, memória, disco)
- Configure alertas para condições críticas
- Use ferramentas como Prometheus e Grafana

### Manutenção
- Faça upgrades regulares
- Teste procedimentos de drain/cordon
- Mantenha nodes homogêneos quando possível
- Automatize provisionamento de nodes


---

## Exemplos Práticos

### Exemplo 1: Verificar Componentes do Worker

```bash
# Ver nodes do cluster
kubectl get nodes

# Ver detalhes de um node
kubectl describe node <node-name>

# Ver pods rodando em um node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>

# Ver recursos do node
kubectl top node <node-name>
```

### Exemplo 2: Inspecionar Kubelet

```bash
# Status do kubelet (no próprio node)
systemctl status kubelet

# Logs do kubelet
journalctl -u kubelet -f

# Ver configuração do kubelet
cat /var/lib/kubelet/config.yaml

# Ver certificados do kubelet
ls -la /var/lib/kubelet/pki/
```

### Exemplo 3: Verificar Kube-proxy

```bash
# Ver pods do kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Logs do kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy

# Ver regras iptables (no node)
sudo iptables-save | grep <service-name>

# Ver modo do kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep "Using"
```

### Exemplo 4: Testar Container Runtime

```bash
# Verificar containerd (no node)
systemctl status containerd

# Listar containers com crictl
crictl ps

# Listar imagens
crictl images

# Ver logs de container
crictl logs <container-id>

# Inspecionar container
crictl inspect <container-id>
```

### Exemplo 5: Gerenciar Node

```bash
# Marcar node como não-agendável
kubectl cordon <node-name>

# Verificar
kubectl get nodes

# Drenar pods do node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Ver pods sendo movidos
kubectl get pods --all-namespaces -o wide -w

# Reabilitar node
kubectl uncordon <node-name>
```

### Exemplo 6: Adicionar Labels ao Node

```bash
# Adicionar labels
kubectl label nodes <node-name> disktype=ssd
kubectl label nodes <node-name> environment=production
kubectl label nodes <node-name> gpu=true

# Ver labels
kubectl get nodes --show-labels

# Criar pod que usa nodeSelector
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  nodeSelector:
    gpu: "true"
  containers:
  - name: cuda-app
    image: nvidia/cuda:11.0-base
EOF

# Verificar em qual node foi agendado
kubectl get pod gpu-pod -o wide
```

### Exemplo 7: Monitorar Recursos do Node

```bash
# Ver uso de CPU e memória
kubectl top nodes

# Ver capacidade e alocação
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# Ver pods por consumo de recursos
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu

# Ver eventos do node
kubectl get events --field-selector involvedObject.name=<node-name>
```

---

## Fluxo de Trabalho do Worker Node

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE TRABALHO DO WORKER NODE                │
└─────────────────────────────────────────────────────────┘

1. KUBELET INICIA
   ├─> Registra node no cluster (via API Server)
   ├─> Reporta capacidade (CPU, memória, pods)
   └─> Inicia watch no API Server

2. KUBELET DETECTA NOVO POD
   ├─> API Server notifica: "Pod X atribuído a você"
   ├─> Kubelet lê especificação do Pod
   └─> Verifica se imagens existem localmente

3. KUBELET → CONTAINER RUNTIME
   ├─> Se imagem não existe, puxa do registry
   ├─> Cria sandbox do Pod (pause container)
   ├─> Cria containers do Pod
   └─> Inicia containers

4. CONTAINER RUNTIME → KERNEL
   ├─> Cria namespaces (PID, NET, MNT, UTS, IPC)
   ├─> Configura cgroups (CPU, memória, I/O)
   ├─> Monta volumes
   └─> Executa processo do container

5. KUBELET MONITORA
   ├─> Executa liveness probes
   ├─> Executa readiness probes
   ├─> Coleta métricas
   └─> Reporta status ao API Server

6. KUBE-PROXY CONFIGURA REDE
   ├─> Detecta novo Service
   ├─> Cria regras iptables/IPVS
   └─> Habilita load balancing

7. POD RECEBE TRÁFEGO
   └─> Aplicação rodando e acessível
```

---

## Troubleshooting de Worker Nodes

### Node NotReady

```bash
# Ver status do node
kubectl describe node <node-name>

# Ver eventos
kubectl get events --field-selector involvedObject.name=<node-name>

# Verificar kubelet (no node)
systemctl status kubelet
journalctl -u kubelet -n 50

# Verificar container runtime
systemctl status containerd
# ou
systemctl status crio

# Verificar disco cheio
df -h

# Verificar memória
free -h
```

### Pods não Iniciam

```bash
# Ver status do pod
kubectl describe pod <pod-name>

# Ver eventos
kubectl get events --sort-by='.lastTimestamp' | grep <pod-name>

# Ver logs do kubelet
journalctl -u kubelet | grep <pod-name>

# Verificar imagens (no node)
crictl images | grep <image-name>

# Tentar pull manual
crictl pull <image-name>
```

### Problemas de Rede

```bash
# Verificar kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Ver logs do kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy

# Verificar regras iptables (no node)
sudo iptables-save | grep <service-name>

# Testar conectividade entre pods
kubectl run test --image=busybox -it --rm -- ping <pod-ip>
```
