# Workers e Control Plane do Kubernetes

O Kubernetes utiliza uma arquitetura distribuída dividida em dois componentes principais: **Control Plane** (plano de controle) e **Worker Nodes** (nós de trabalho). Essa separação permite escalabilidade, alta disponibilidade e gerenciamento eficiente de containers.

## Visão Geral da Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                      CONTROL PLANE                          │
│              (Cérebro do Cluster)                           │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │              │  │              │  │              │     │
│  │  API Server  │  │  Scheduler   │  │ Controller   │     │
│  │              │  │              │  │   Manager    │     │
│  │              │  │              │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │                                                   │     │
│  │         etcd (Banco de Dados do Cluster)         │     │
│  │                                                   │     │
│  └───────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Comunicação via API
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌──────▼─────────┐
│ WORKER NODE 1  │  │ WORKER NODE 2  │  │ WORKER NODE 3  │
│                │  │                │  │                │
│ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │
│ │  Kubelet   │ │  │ │  Kubelet   │ │  │ │  Kubelet   │ │
│ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │
│ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │
│ │ Kube-proxy │ │  │ │ Kube-proxy │ │  │ │ Kube-proxy │ │
│ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │
│ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │
│ │ Container  │ │  │ │ Container  │ │  │ │ Container  │ │
│ │  Runtime   │ │  │ │  Runtime   │ │  │ │  Runtime   │ │
│ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │
│                │  │                │  │                │
│  ┌──────────┐  │  │  ┌──────────┐  │  │  ┌──────────┐  │
│  │   Pod    │  │  │  │   Pod    │  │  │  │   Pod    │  │
│  │ ┌──────┐ │  │  │  │ ┌──────┐ │  │  │  │ ┌──────┐ │  │
│  │ │ App  │ │  │  │  │ │ App  │ │  │  │  │ │ App  │ │  │
│  │ └──────┘ │  │  │  │ └──────┘ │  │  │  │ └──────┘ │  │
│  └──────────┘  │  │  └──────────┘  │  │  └──────────┘  │
└────────────────┘  └────────────────┘  └────────────────┘
```

## Control Plane (Plano de Controle)

O Control Plane é o **cérebro do cluster Kubernetes**. Ele toma decisões globais sobre o cluster e detecta/responde a eventos (como iniciar um novo pod quando um deployment precisa de mais réplicas).

### Responsabilidades

- Gerenciar o estado desejado do cluster
- Agendar pods em nodes
- Detectar e responder a eventos do cluster
- Expor a API do Kubernetes
- Armazenar configuração e estado

### Componentes do Control Plane

#### 1. API Server (kube-apiserver)

**Função**: Front-end do Control Plane e ponto de entrada único para o cluster.

**Responsabilidades:**
- Expõe a API REST do Kubernetes
- Valida e processa requisições
- Atualiza objetos no etcd
- Autentica e autoriza requisições
- Ponto de comunicação entre todos os componentes

**Características:**
- Stateless (sem estado)
- Pode ser escalado horizontalmente
- Único componente que fala diretamente com o etcd

**Exemplo de interação:**
```bash
# kubectl se comunica com o API Server
kubectl get pods
# → API Server valida → busca dados no etcd → retorna resposta
```

#### 2. etcd

**Função**: Banco de dados key-value distribuído que armazena todo o estado do cluster.

**O que armazena:**
- Configuração do cluster
- Estado de todos os objetos (pods, services, deployments)
- Secrets e ConfigMaps
- Informações de nodes
- Metadados

**Características:**
- Consistência forte (usa algoritmo Raft)
- Altamente disponível
- Backup crítico para recuperação de desastres
- Apenas o API Server acessa diretamente

**Exemplo de dados:**
```
/registry/pods/default/nginx-pod
/registry/services/default/nginx-service
/registry/deployments/default/nginx-deployment
```

#### 3. Scheduler (kube-scheduler)

**Função**: Decide em qual node cada pod será executado.

**Processo de decisão:**
1. **Filtering**: Elimina nodes que não atendem requisitos
   - Recursos insuficientes (CPU, memória)
   - Node selectors não correspondem
   - Taints/tolerations
   
2. **Scoring**: Classifica nodes viáveis
   - Distribuição de carga
   - Afinidade/anti-afinidade
   - Localidade de dados

3. **Binding**: Atribui pod ao node com maior score

**Fatores considerados:**
- Recursos disponíveis (CPU, memória, storage)
- Constraints de hardware/software
- Políticas de afinidade e anti-afinidade
- Data locality
- Taints e tolerations

**Exemplo:**
```yaml
# Pod com requisitos específicos
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
  nodeSelector:
    disktype: ssd
```

#### 4. Controller Manager (kube-controller-manager)

**Função**: Executa controllers que regulam o estado do cluster.

**Controllers principais:**

**Node Controller**
- Monitora saúde dos nodes
- Responde quando nodes ficam indisponíveis

**Replication Controller**
- Mantém número correto de pods para cada ReplicaSet
- Cria/deleta pods conforme necessário

**Endpoints Controller**
- Popula objetos Endpoints (conecta Services e Pods)

**Service Account & Token Controllers**
- Cria contas e tokens de API para novos namespaces

**Deployment Controller**
- Gerencia rollouts e rollbacks

**Job Controller**
- Executa pods para jobs únicos

**Funcionamento:**
```
Loop de reconciliação:
1. Observa estado atual
2. Compara com estado desejado
3. Toma ações para convergir
4. Repete continuamente
```

#### 5. Cloud Controller Manager

**Função**: Integra Kubernetes com APIs de cloud providers.

**Controllers específicos de cloud:**

**Node Controller**
- Verifica se nodes deletados foram removidos da cloud

**Route Controller**
- Configura rotas na infraestrutura cloud

**Service Controller**
- Cria/atualiza/deleta load balancers cloud

**Volume Controller**
- Cria/anexa/monta volumes cloud

**Exemplos por provider:**
- AWS: Integra com ELB, EBS, VPC
- Azure: Integra com Azure Load Balancer, Azure Disk
- GCP: Integra com Cloud Load Balancing, Persistent Disk

### Alta Disponibilidade do Control Plane

Para produção, recomenda-se múltiplas réplicas:

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Control     │  │ Control     │  │ Control     │
│ Plane 1     │  │ Plane 2     │  │ Plane 3     │
│             │  │             │  │             │
│ API Server  │  │ API Server  │  │ API Server  │
│ Scheduler   │  │ Scheduler   │  │ Scheduler   │
│ Controller  │  │ Controller  │  │ Controller  │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
              ┌─────────▼─────────┐
              │  etcd cluster     │
              │  (3 ou 5 nodes)   │
              └───────────────────┘
```

## Worker Nodes (Nós de Trabalho)

Worker Nodes são as **máquinas que executam as aplicações containerizadas**. Cada node pode ser uma máquina física ou virtual.

### Responsabilidades

- Executar pods
- Manter containers rodando
- Reportar status ao Control Plane
- Implementar regras de rede
- Gerenciar volumes locais

### Componentes dos Worker Nodes

#### 1. Kubelet

**Função**: Agente principal que roda em cada node.

**Responsabilidades:**
- Registra o node no cluster
- Recebe PodSpecs do API Server
- Garante que containers descritos estejam rodando e saudáveis
- Reporta status de pods e node ao Control Plane
- Executa probes (liveness, readiness, startup)
- Gerencia volumes de pods

**Funcionamento:**
```
1. Kubelet monitora API Server para novos pods
2. Baixa imagens de container necessárias
3. Instrui container runtime a iniciar containers
4. Monitora saúde dos containers
5. Reporta status de volta ao API Server
```

**Health Checks:**
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

#### 2. Kube-proxy

**Função**: Proxy de rede que mantém regras de rede nos nodes.

**Responsabilidades:**
- Implementa Services do Kubernetes
- Mantém regras de rede (iptables, IPVS ou userspace)
- Faz load balancing de tráfego para pods
- Permite comunicação entre pods e com o mundo externo

**Modos de operação:**

**iptables (padrão)**
- Usa regras iptables do Linux
- Baixo overhead
- Seleção aleatória de backend

**IPVS**
- Usa Linux IPVS (IP Virtual Server)
- Melhor performance em clusters grandes
- Algoritmos de load balancing avançados

**userspace**
- Modo legado
- Maior overhead
- Raramente usado

**Exemplo de fluxo:**
```
Cliente → Service IP (virtual) → kube-proxy 
→ seleciona Pod → encaminha tráfego
```

#### 3. Container Runtime

**Função**: Software que executa containers.

**Runtimes suportados:**
- **containerd**: Mais comum, usado por Docker e K8s
- **CRI-O**: Otimizado para Kubernetes
- **Docker Engine**: Via containerd (deprecated como runtime direto)

**Interface CRI (Container Runtime Interface):**
```
Kubelet → CRI API → Container Runtime → runc → Container
```

**Responsabilidades:**
- Baixar imagens de container
- Executar containers
- Parar containers
- Gerenciar recursos de containers

### Recursos do Node

Cada node tem capacidade limitada:

```bash
# Ver recursos de nodes
kubectl describe node node-name

# Exemplo de output:
Capacity:
  cpu:                4
  memory:             16Gi
  pods:               110

Allocatable:
  cpu:                3800m
  memory:             15Gi
  pods:               110
```

### Node Labels e Selectors

Nodes podem ter labels para scheduling direcionado:

```bash
# Adicionar label a node
kubectl label nodes node-1 disktype=ssd

# Pod com nodeSelector
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: nginx
    image: nginx
```

### Taints e Tolerations

Impedem pods de serem agendados em nodes específicos:

```bash
# Adicionar taint a node
kubectl taint nodes node-1 key=value:NoSchedule

# Pod com toleration
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
  containers:
  - name: nginx
    image: nginx
```

## Comunicação entre Control Plane e Workers

### Fluxo de Comunicação

```
1. kubectl apply -f deployment.yaml
   ↓
2. API Server valida e armazena no etcd
   ↓
3. Controller Manager detecta novo Deployment
   ↓
4. Controller cria ReplicaSet
   ↓
5. ReplicaSet cria Pods
   ↓
6. Scheduler atribui Pods a Nodes
   ↓
7. Kubelet no Node detecta novo Pod
   ↓
8. Kubelet instrui Container Runtime
   ↓
9. Container Runtime inicia containers
   ↓
10. Kubelet reporta status ao API Server
```

### Segurança da Comunicação

**TLS/SSL:**
- Toda comunicação é criptografada
- Certificados para autenticação mútua

**RBAC (Role-Based Access Control):**
- Controla quem pode fazer o quê
- Kubelet tem permissões limitadas

**Service Accounts:**
- Identidade para processos em pods
- Tokens para autenticação

## Comandos Úteis

```bash
# Ver componentes do Control Plane
kubectl get componentstatuses

# Listar nodes
kubectl get nodes

# Detalhes de um node
kubectl describe node node-name

# Ver pods do sistema (Control Plane)
kubectl get pods -n kube-system

# Ver logs do kubelet
journalctl -u kubelet

# Marcar node como não-agendável
kubectl cordon node-name

# Drenar pods de um node
kubectl drain node-name --ignore-daemonsets

# Remover node do cluster
kubectl delete node node-name
```

## Comparação: Control Plane vs Workers

| Aspecto | Control Plane | Worker Nodes |
|---------|---------------|--------------|
| Função | Gerencia o cluster | Executa aplicações |
| Componentes | API Server, etcd, Scheduler, Controllers | Kubelet, kube-proxy, runtime |
| Executa pods? | Geralmente não (pode com taints) | Sim |
| Quantidade | 1, 3 ou 5 (HA) | Muitos (escalável) |
| Recursos | Menos intensivo | Mais intensivo |
| Crítico? | Sim (sem ele, cluster para) | Parcial (outros nodes compensam) |

## Topologias de Cluster

### Single-Node (Desenvolvimento)
```
┌─────────────────────┐
│  Control Plane +    │
│  Worker (mesmo node)│
└─────────────────────┘
```

### Stacked etcd (Comum)
```
┌─────────────────────┐
│  Control Plane      │
│  + etcd (co-located)│
└─────────────────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼────┐
│Worker │ │Worker │
└───────┘ └───────┘
```

### External etcd (Produção)
```
┌─────────┐  ┌─────────┐  ┌─────────┐
│  etcd   │  │  etcd   │  │  etcd   │
└────┬────┘  └────┬────┘  └────┬────┘
     └───────────┬─────────────┘
                 │
     ┌───────────┴─────────────┐
     │                         │
┌────▼─────┐            ┌──────▼───┐
│ Control  │            │ Control  │
│  Plane   │            │  Plane   │
└────┬─────┘            └──────┬───┘
     │                         │
     └────────────┬────────────┘
                  │
         ┌────────┼────────┐
         │        │        │
     ┌───▼──┐ ┌───▼──┐ ┌──▼───┐
     │Worker│ │Worker│ │Worker│
     └──────┘ └──────┘ └──────┘
```

## Boas Práticas

### Control Plane
- Use número ímpar de nodes (3 ou 5) para HA
- Separe etcd em nodes dedicados em produção
- Faça backup regular do etcd
- Monitore saúde dos componentes
- Use load balancer para API Server

### Worker Nodes
- Dimensione adequadamente (CPU, memória)
- Use node pools para diferentes workloads
- Configure resource requests e limits
- Implemente node auto-scaling
- Monitore utilização de recursos
- Mantenha nodes atualizados

### Segurança
- Isole Control Plane em rede privada
- Use RBAC rigorosamente
- Habilite audit logging
- Criptografe etcd em repouso
- Rotacione certificados regularmente

---

## Exemplos Práticos

### Exemplo 1: Verificar Componentes do Cluster

```bash
# Ver status dos componentes
kubectl get componentstatuses
kubectl get cs

# Ver nodes do cluster
kubectl get nodes

# Ver detalhes de um node
kubectl describe node <node-name>

# Ver pods do control plane
kubectl get pods -n kube-system

# Ver quais componentes estão rodando
kubectl get pods -n kube-system -o wide
```

### Exemplo 2: Inspecionar Control Plane

```bash
# Ver API Server
kubectl get pods -n kube-system | grep apiserver

# Ver Scheduler
kubectl get pods -n kube-system | grep scheduler

# Ver Controller Manager
kubectl get pods -n kube-system | grep controller

# Ver etcd
kubectl get pods -n kube-system | grep etcd

# Logs do API Server
kubectl logs -n kube-system kube-apiserver-<node-name>

# Logs do Scheduler
kubectl logs -n kube-system kube-scheduler-<node-name>
```

### Exemplo 3: Gerenciar Worker Nodes

```bash
# Listar nodes com detalhes
kubectl get nodes -o wide

# Ver recursos de um node
kubectl describe node <node-name> | grep -A 5 "Allocated resources"

# Ver pods rodando em um node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>

# Marcar node como não-agendável (manutenção)
kubectl cordon <node-name>

# Drenar pods do node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Reabilitar node
kubectl uncordon <node-name>
```

### Exemplo 4: Labels e Selectors em Nodes

```bash
# Ver labels dos nodes
kubectl get nodes --show-labels

# Adicionar label a node
kubectl label nodes <node-name> environment=production
kubectl label nodes <node-name> disktype=ssd

# Remover label
kubectl label nodes <node-name> disktype-

# Criar pod com nodeSelector
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-ssd
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: nginx
    image: nginx
EOF

# Verificar em qual node o pod foi agendado
kubectl get pod nginx-ssd -o wide
```

### Exemplo 5: Taints e Tolerations

```bash
# Adicionar taint a node (impede scheduling)
kubectl taint nodes <node-name> dedicated=gpu:NoSchedule

# Ver taints de um node
kubectl describe node <node-name> | grep Taints

# Criar pod com toleration
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
  containers:
  - name: cuda-app
    image: nvidia/cuda:11.0-base
EOF

# Remover taint
kubectl taint nodes <node-name> dedicated:NoSchedule-
```

### Exemplo 6: Monitorar Saúde do Cluster

```bash
# Ver eventos do cluster
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Ver uso de recursos dos nodes
kubectl top nodes

# Ver uso de recursos dos pods
kubectl top pods --all-namespaces

# Ver capacidade e alocação de nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Verificar se há pods pending
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
```

---

## Fluxo Completo: Deploy de Aplicação

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE DEPLOY NO KUBERNETES                   │
└─────────────────────────────────────────────────────────┘

1. USUÁRIO
   └─> kubectl apply -f deployment.yaml

2. API SERVER (Control Plane)
   ├─> Autentica requisição
   ├─> Valida YAML
   ├─> Persiste no etcd
   └─> Retorna confirmação

3. CONTROLLER MANAGER (Control Plane)
   ├─> Deployment Controller detecta novo Deployment
   ├─> Cria ReplicaSet
   └─> ReplicaSet Controller cria Pods (estado desejado)

4. SCHEDULER (Control Plane)
   ├─> Detecta Pods sem node atribuído
   ├─> Filtra nodes elegíveis:
   │   ├─> Recursos suficientes?
   │   ├─> NodeSelector match?
   │   └─> Taints/Tolerations ok?
   ├─> Pontua nodes restantes
   └─> Atribui Pod ao melhor node

5. KUBELET (Worker Node)
   ├─> Detecta novo Pod atribuído ao seu node
   ├─> Verifica se imagem existe localmente
   ├─> Se não, puxa imagem do registry
   ├─> Chama Container Runtime (containerd/CRI-O)
   └─> Container Runtime cria containers

6. CONTAINER RUNTIME (Worker Node)
   ├─> Cria namespaces (PID, NET, MNT, etc)
   ├─> Configura cgroups (CPU, memória)
   ├─> Monta volumes
   └─> Inicia processo do container

7. KUBELET (Worker Node)
   ├─> Monitora saúde do container
   ├─> Executa probes (liveness, readiness)
   ├─> Reporta status ao API Server
   └─> Loop contínuo de monitoramento

8. KUBE-PROXY (Worker Node)
   ├─> Detecta novo Service (se houver)
   ├─> Configura regras iptables/IPVS
   └─> Habilita load balancing para o Pod

9. APLICAÇÃO RODANDO
   └─> Pod recebe tráfego via Service
```

---

## Exemplo Prático Completo

### Cenário: Deploy de Aplicação Web

```bash
# 1. Verificar cluster
kubectl cluster-info
kubectl get nodes

# 2. Criar namespace
kubectl create namespace webapp

# 3. Criar deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF

# 4. Ver o que aconteceu no Control Plane
kubectl get deployments -n webapp
kubectl get replicasets -n webapp
kubectl get pods -n webapp

# 5. Ver em quais nodes os pods foram agendados
kubectl get pods -n webapp -o wide

# 6. Ver eventos do scheduling
kubectl get events -n webapp --sort-by='.lastTimestamp'

# 7. Criar service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: webapp
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF

# 8. Ver service e endpoints
kubectl get service -n webapp
kubectl get endpoints -n webapp

# 9. Testar aplicação
kubectl port-forward -n webapp service/nginx-service 8080:80
# Acessar: http://localhost:8080

# 10. Ver logs do kubelet (em um node)
# SSH no node ou:
kubectl logs -n kube-system -l component=kubelet

# 11. Escalar aplicação
kubectl scale deployment nginx-deployment -n webapp --replicas=5

# 12. Ver scheduler em ação
kubectl get pods -n webapp -w

# 13. Limpar
kubectl delete namespace webapp
```

---

## Troubleshooting

### Control Plane com Problemas

```bash
# Verificar componentes
kubectl get componentstatuses

# Ver logs do API Server
kubectl logs -n kube-system kube-apiserver-<node>

# Ver logs do Scheduler
kubectl logs -n kube-system kube-scheduler-<node>

# Ver logs do Controller Manager
kubectl logs -n kube-system kube-controller-manager-<node>

# Verificar etcd
kubectl exec -n kube-system etcd-<node> -- etcdctl member list
```

### Worker Node com Problemas

```bash
# Ver status do node
kubectl describe node <node-name>

# Ver eventos do node
kubectl get events --field-selector involvedObject.name=<node-name>

# Ver pods que não conseguem agendar
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Logs do kubelet (no próprio node)
journalctl -u kubelet -f

# Verificar container runtime
systemctl status containerd
# ou
systemctl status crio
```

### Pod não Agenda

```bash
# Ver por que pod está pending
kubectl describe pod <pod-name>

# Verificar recursos disponíveis nos nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Ver eventos de scheduling
kubectl get events --sort-by='.lastTimestamp' | grep <pod-name>

# Verificar taints nos nodes
kubectl describe nodes | grep Taints
```
