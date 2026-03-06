# Componentes do Control Plane do Kubernetes

O **Control Plane** é o cérebro do cluster Kubernetes, responsável por tomar decisões globais e manter o estado desejado do cluster. É composto por cinco componentes principais que trabalham em conjunto.

## Arquitetura do Control Plane

```
┌─────────────────────────────────────────────────────────┐
│                    CONTROL PLANE                        │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │                                                  │  │
│  │              kube-apiserver                      │  │
│  │         (Front-end do Kubernetes)                │  │
│  │                                                  │  │
│  └────────┬─────────────────────────────┬──────────┘  │
│           │                             │             │
│  ┌────────▼──────────┐        ┌────────▼──────────┐  │
│  │                   │        │                   │  │
│  │  kube-scheduler   │        │ kube-controller-  │  │
│  │                   │        │     manager       │  │
│  │                   │        │                   │  │
│  └───────────────────┘        └───────────────────┘  │
│                                                       │
│  ┌──────────────────────────────────────────────┐    │
│  │                                              │    │
│  │  cloud-controller-manager (opcional)         │    │
│  │                                              │    │
│  └──────────────────────────────────────────────┘    │
│                                                       │
│  ┌──────────────────────────────────────────────┐    │
│  │                                              │    │
│  │              etcd                            │    │
│  │      (Banco de Dados Distribuído)           │    │
│  │                                              │    │
│  └──────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────┘
```

## 1. kube-apiserver

### Descrição
O **API Server** é o componente central do Control Plane e o único ponto de entrada para todas as operações administrativas do cluster.

### Responsabilidades

**Interface REST**
- Expõe a API REST do Kubernetes
- Processa requisições HTTP/HTTPS
- Suporta operações CRUD (Create, Read, Update, Delete)

**Validação e Admissão**
- Valida requisições (sintaxe, semântica)
- Executa admission controllers (mutating e validating)
- Aplica políticas de segurança

**Persistência**
- Único componente que interage diretamente com o etcd
- Lê e escreve estado do cluster
- Mantém consistência dos dados

**Autenticação e Autorização**
- Autentica usuários e service accounts
- Autoriza operações via RBAC
- Gerencia tokens e certificados

**Watch e Notificações**
- Permite que componentes "assistam" mudanças
- Notifica controllers sobre eventos
- Implementa long-polling para eficiência

### Características

- **Stateless**: Não mantém estado próprio
- **Escalável horizontalmente**: Múltiplas réplicas podem rodar simultaneamente
- **Alta disponibilidade**: Load balancer distribui requisições
- **Auditável**: Registra todas as operações (audit logs)

### Fluxo de Requisição

```
1. Cliente (kubectl/app) envia requisição
   ↓
2. Autenticação (quem é você?)
   ↓
3. Autorização (você pode fazer isso?)
   ↓
4. Admission Controllers (validação/mutação)
   ↓
5. Validação de schema
   ↓
6. Persistência no etcd
   ↓
7. Resposta ao cliente
```

### Exemplo de Interação

```bash
# kubectl se comunica com o API Server
kubectl get pods

# Equivalente em API REST
curl https://kubernetes-api:6443/api/v1/namespaces/default/pods \
  --header "Authorization: Bearer $TOKEN" \
  --cacert /path/to/ca.crt
```

### Portas

- **6443**: HTTPS (padrão para API segura)
- **8080**: HTTP (inseguro, geralmente desabilitado)

### Flags Importantes

```bash
--etcd-servers=https://127.0.0.1:2379
--service-cluster-ip-range=10.96.0.0/12
--authorization-mode=Node,RBAC
--enable-admission-plugins=NodeRestriction,PodSecurityPolicy
--audit-log-path=/var/log/kubernetes/audit.log
```

## 2. etcd

### Descrição
**etcd** é um banco de dados key-value distribuído, consistente e altamente disponível que armazena todo o estado e configuração do cluster Kubernetes.

### Responsabilidades

**Armazenamento de Estado**
- Configuração do cluster
- Estado de todos os recursos (pods, services, deployments, etc.)
- Secrets e ConfigMaps
- Informações de nodes
- Metadados e labels

**Consistência**
- Usa algoritmo de consenso Raft
- Garante consistência forte
- Eleição de líder automática

**Watch API**
- Notifica mudanças em tempo real
- Permite que API Server observe alterações
- Base para o modelo event-driven do K8s

### Estrutura de Dados

```
/registry/
├── pods/
│   ├── default/
│   │   ├── nginx-pod
│   │   └── app-pod
│   └── kube-system/
│       └── coredns-pod
├── services/
│   └── default/
│       └── nginx-service
├── deployments/
│   └── default/
│       └── nginx-deployment
├── secrets/
│   └── default/
│       └── db-password
└── configmaps/
    └── default/
        └── app-config
```

### Características

- **Distribuído**: Cluster de 3, 5 ou 7 nodes (número ímpar)
- **Consistente**: Leituras sempre retornam último valor escrito
- **Altamente disponível**: Tolera falhas de nodes
- **Rápido**: Otimizado para leituras
- **Versionado**: Mantém histórico de mudanças

### Quorum

Para cluster de 3 nodes:
- **Tolerância a falhas**: 1 node pode falhar
- **Quorum**: 2 nodes devem estar disponíveis
- **Fórmula**: (N/2) + 1

```
3 nodes → tolera 1 falha
5 nodes → tolera 2 falhas
7 nodes → tolera 3 falhas
```

### Backup e Recuperação

```bash
# Backup do etcd
ETCDCTL_API=3 etcdctl snapshot save snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verificar snapshot
ETCDCTL_API=3 etcdctl snapshot status snapshot.db

# Restaurar do backup
ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --data-dir=/var/lib/etcd-restore
```

### Portas

- **2379**: Cliente API
- **2380**: Peer communication (entre nodes etcd)

### Segurança

- **Criptografia em trânsito**: TLS para todas as comunicações
- **Criptografia em repouso**: Dados criptografados no disco
- **Autenticação**: Certificados cliente
- **Isolamento**: Apenas API Server deve acessar

## 3. kube-scheduler

### Descrição
O **Scheduler** é responsável por decidir em qual node cada pod será executado, considerando recursos disponíveis e restrições definidas.

### Responsabilidades

**Seleção de Node**
- Monitora pods sem node atribuído
- Avalia todos os nodes disponíveis
- Seleciona o melhor node para cada pod
- Atualiza binding do pod no API Server

**Otimização de Recursos**
- Distribui carga entre nodes
- Considera utilização de CPU e memória
- Evita sobrecarga de nodes

**Aplicação de Políticas**
- Respeita node selectors
- Aplica afinidade e anti-afinidade
- Considera taints e tolerations
- Respeita resource requests e limits

### Processo de Scheduling

```
┌─────────────────────────────────────────┐
│  1. WATCH: Novos pods sem node          │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  2. FILTERING: Elimina nodes inviáveis  │
│     - Recursos insuficientes            │
│     - Node selector não corresponde     │
│     - Taints sem tolerations            │
│     - Volumes não disponíveis           │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  3. SCORING: Classifica nodes viáveis   │
│     - Balanceamento de recursos         │
│     - Afinidade/anti-afinidade          │
│     - Localidade de dados               │
│     - Prioridades customizadas          │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  4. BINDING: Atribui pod ao melhor node │
└─────────────────────────────────────────┘
```

### Predicates (Filtros)

**PodFitsResources**
- Verifica se node tem CPU e memória suficientes

**PodFitsHostPorts**
- Verifica se portas do host estão disponíveis

**MatchNodeSelector**
- Verifica se node tem labels requeridos

**NoVolumeZoneConflict**
- Verifica se volumes podem ser montados no node

**CheckNodeMemoryPressure**
- Evita nodes com pressão de memória

### Priorities (Pontuação)

**LeastRequestedPriority**
- Prefere nodes com mais recursos disponíveis

**BalancedResourceAllocation**
- Balanceia uso de CPU e memória

**SelectorSpreadPriority**
- Distribui pods do mesmo service entre nodes

**NodeAffinityPriority**
- Favorece nodes que correspondem a afinidade

### Exemplo de Pod com Constraints

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  # Resource requests (usado pelo scheduler)
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
  
  # Node selector
  nodeSelector:
    disktype: ssd
  
  # Node affinity
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/zone
            operator: In
            values:
            - us-east-1a
            - us-east-1b
    
    # Pod anti-affinity
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - nginx
          topologyKey: kubernetes.io/hostname
  
  # Tolerations
  tolerations:
  - key: "key1"
    operator: "Equal"
    value: "value1"
    effect: "NoSchedule"
```

### Scheduler Customizado

É possível criar schedulers customizados:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  schedulerName: my-custom-scheduler
  containers:
  - name: nginx
    image: nginx
```

## 4. kube-controller-manager

### Descrição
O **Controller Manager** executa múltiplos controllers que regulam o estado do cluster, garantindo que o estado atual corresponda ao estado desejado.

### Responsabilidades

**Loop de Reconciliação**
```
while true:
  1. Observar estado atual
  2. Comparar com estado desejado
  3. Tomar ações para convergir
  4. Aguardar próximo ciclo
```

**Gerenciamento de Recursos**
- Cria, atualiza e deleta recursos
- Monitora saúde de componentes
- Responde a eventos do cluster

### Controllers Principais

#### Node Controller

**Função**: Gerencia ciclo de vida dos nodes

**Responsabilidades:**
- Registra novos nodes
- Monitora saúde dos nodes (heartbeats)
- Marca nodes como NotReady após timeout
- Evict pods de nodes indisponíveis
- Atualiza condições dos nodes

**Timeouts:**
```
--node-monitor-period=5s          # Frequência de verificação
--node-monitor-grace-period=40s   # Tempo antes de marcar NotReady
--pod-eviction-timeout=5m         # Tempo antes de evict pods
```

#### Replication Controller

**Função**: Mantém número correto de réplicas de pods

**Responsabilidades:**
- Monitora ReplicaSets
- Cria pods quando há menos réplicas que o desejado
- Deleta pods quando há mais réplicas que o desejado
- Substitui pods que falham

**Exemplo:**
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 3  # Controller garante 3 pods sempre
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
        image: nginx
```

#### Deployment Controller

**Função**: Gerencia Deployments e rollouts

**Responsabilidades:**
- Cria e gerencia ReplicaSets
- Executa rolling updates
- Mantém histórico de revisões
- Implementa rollbacks
- Pausa e retoma deployments

**Estratégias de atualização:**
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Pods extras durante update
      maxUnavailable: 0  # Pods indisponíveis durante update
```

#### Endpoints Controller

**Função**: Popula objetos Endpoints

**Responsabilidades:**
- Monitora Services e Pods
- Cria/atualiza Endpoints para conectar Services a Pods
- Remove endpoints de pods não-ready

**Exemplo:**
```yaml
# Service
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80

# Endpoints (criado automaticamente)
apiVersion: v1
kind: Endpoints
metadata:
  name: nginx-service
subsets:
- addresses:
  - ip: 10.244.1.5
  - ip: 10.244.2.3
  ports:
  - port: 80
```

#### Service Account Controller

**Função**: Gerencia Service Accounts

**Responsabilidades:**
- Cria Service Account padrão em novos namespaces
- Garante que cada namespace tenha SA default
- Gerencia tokens de autenticação

#### Token Controller

**Função**: Gerencia tokens de Service Accounts

**Responsabilidades:**
- Cria tokens para Service Accounts
- Rotaciona tokens expirados
- Limpa tokens de SAs deletados

#### Namespace Controller

**Função**: Gerencia ciclo de vida de Namespaces

**Responsabilidades:**
- Deleta todos os recursos quando namespace é deletado
- Finaliza namespaces (cleanup)
- Previne criação de recursos em namespaces sendo deletados

#### Job Controller

**Função**: Gerencia Jobs

**Responsabilidades:**
- Cria pods para Jobs
- Monitora conclusão de Jobs
- Gerencia paralelismo
- Implementa retries

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  completions: 5      # 5 execuções bem-sucedidas
  parallelism: 2      # 2 pods em paralelo
  backoffLimit: 4     # 4 tentativas em caso de falha
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
```

#### CronJob Controller

**Função**: Gerencia CronJobs (jobs agendados)

**Responsabilidades:**
- Cria Jobs em horários agendados
- Gerencia histórico de execuções
- Implementa políticas de concorrência

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "0 2 * * *"  # Todo dia às 2h
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup-tool
          restartPolicy: OnFailure
```

#### StatefulSet Controller

**Função**: Gerencia StatefulSets

**Responsabilidades:**
- Mantém identidade estável de pods
- Garante ordem de criação/deleção
- Gerencia persistent volumes por pod

#### DaemonSet Controller

**Função**: Garante que pods rodem em todos (ou alguns) nodes

**Responsabilidades:**
- Cria pod em cada node elegível
- Remove pods de nodes não-elegíveis
- Atualiza pods em todos os nodes

### Outros Controllers

- **ResourceQuota Controller**: Aplica quotas de recursos
- **ServiceAccount Controller**: Gerencia service accounts
- **PersistentVolume Controller**: Gerencia PVs e PVCs
- **Garbage Collector**: Limpa recursos órfãos

## 5. cloud-controller-manager

### Descrição
O **Cloud Controller Manager** separa a lógica específica de cloud providers do core do Kubernetes, permitindo que vendors desenvolvam suas próprias integrações.

### Responsabilidades

**Integração com Cloud**
- Abstrai APIs de cloud providers
- Gerencia recursos cloud (load balancers, volumes, VMs)
- Sincroniza estado entre K8s e cloud

### Controllers Específicos de Cloud

#### Node Controller

**Função**: Gerencia nodes na cloud

**Responsabilidades:**
- Verifica se node deletado foi removido da cloud
- Atualiza informações de node (região, zona, tipo de instância)
- Adiciona labels específicos de cloud
- Monitora status de VMs na cloud

**Labels adicionados:**
```yaml
metadata:
  labels:
    kubernetes.io/hostname: node-1
    topology.kubernetes.io/region: us-east-1
    topology.kubernetes.io/zone: us-east-1a
    node.kubernetes.io/instance-type: t3.medium
    kubernetes.io/os: linux
    kubernetes.io/arch: amd64
```

#### Route Controller

**Função**: Configura rotas na rede cloud

**Responsabilidades:**
- Cria rotas para comunicação entre pods em diferentes nodes
- Configura tabelas de roteamento na VPC/VNet
- Garante conectividade de rede do cluster

**Exemplo (AWS):**
```
Pod CIDR: 10.244.0.0/16
Node 1 (10.244.1.0/24) → ENI 1
Node 2 (10.244.2.0/24) → ENI 2
Node 3 (10.244.3.0/24) → ENI 3
```

#### Service Controller

**Função**: Gerencia load balancers cloud para Services

**Responsabilidades:**
- Cria load balancers para Services tipo LoadBalancer
- Configura health checks
- Atualiza backends quando pods mudam
- Deleta load balancers quando Service é deletado

**Exemplo:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer  # Cloud Controller cria ELB/ALB/NLB
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

**Resultado (AWS):**
- Cria Network Load Balancer
- Configura target group com IPs dos pods
- Retorna DNS do load balancer em `status.loadBalancer.ingress`

#### Volume Controller

**Função**: Gerencia volumes cloud

**Responsabilidades:**
- Cria volumes (EBS, Azure Disk, GCE PD)
- Anexa volumes a nodes
- Desanexa volumes quando pods são deletados
- Gerencia snapshots

**Exemplo (AWS EBS):**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-claim
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi
```

### Providers Suportados

**AWS**
- ELB/ALB/NLB para Services
- EBS para volumes
- VPC routing

**Azure**
- Azure Load Balancer
- Azure Disk
- VNet routing

**GCP**
- Cloud Load Balancing
- Persistent Disk
- VPC routing

**OpenStack**
- Neutron LBaaS
- Cinder volumes

### Quando Não é Necessário

- Clusters on-premises (bare metal)
- Clusters em ambientes sem integração cloud
- Uso de CSI drivers externos

## Comunicação entre Componentes

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  1. kubectl cria Deployment                         │
│     ↓                                               │
│  2. API Server valida e salva no etcd              │
│     ↓                                               │
│  3. Deployment Controller detecta novo Deployment   │
│     ↓                                               │
│  4. Controller cria ReplicaSet                      │
│     ↓                                               │
│  5. ReplicaSet Controller cria Pods                 │
│     ↓                                               │
│  6. Scheduler detecta Pods sem node                 │
│     ↓                                               │
│  7. Scheduler atribui Pods a Nodes                  │
│     ↓                                               │
│  8. Kubelet (worker) detecta novo Pod               │
│     ↓                                               │
│  9. Kubelet inicia containers                       │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Verificando Componentes do Control Plane

```bash
# Ver status dos componentes
kubectl get componentstatuses

# Pods do Control Plane (em clusters kubeadm)
kubectl get pods -n kube-system

# Logs do API Server
kubectl logs -n kube-system kube-apiserver-master

# Logs do Scheduler
kubectl logs -n kube-system kube-scheduler-master

# Logs do Controller Manager
kubectl logs -n kube-system kube-controller-manager-master

# Verificar saúde do etcd
kubectl exec -n kube-system etcd-master -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# Ver métricas do API Server
kubectl get --raw /metrics
```

## Alta Disponibilidade

### Configuração HA

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Master 1    │  │ Master 2    │  │ Master 3    │
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
                        │
              ┌─────────▼─────────┐
              │  Load Balancer    │
              │  (API Server VIP) │
              └───────────────────┘
```

### Componentes em HA

**API Server**
- Múltiplas instâncias ativas (active-active)
- Load balancer distribui requisições
- Todas as instâncias são idênticas

**Scheduler e Controller Manager**
- Apenas uma instância ativa (active-passive)
- Eleição de líder via lease no etcd
- Outras instâncias em standby

**etcd**
- Cluster de 3, 5 ou 7 nodes
- Quorum para operações de escrita
- Tolerância a falhas

## Boas Práticas

### Segurança
- Isole Control Plane em rede privada
- Use TLS para todas as comunicações
- Habilite RBAC e audit logging
- Rotacione certificados regularmente
- Criptografe etcd em repouso

### Performance
- Dimensione adequadamente (CPU, memória)
- Use SSD para etcd
- Monitore latência do etcd
- Configure resource limits

### Backup
- Faça backup regular do etcd
- Teste procedimentos de restore
- Mantenha backups em local seguro
- Automatize backups

### Monitoramento
- Monitore saúde de todos os componentes
- Configure alertas para falhas
- Acompanhe métricas de performance
- Use ferramentas como Prometheus

### Alta Disponibilidade
- Use número ímpar de masters (3 ou 5)
- Distribua em zonas de disponibilidade
- Configure load balancer para API Server
- Teste failover regularmente


---

## Exemplos Práticos

### Exemplo 1: Verificar Componentes do Control Plane

```bash
# Ver pods do control plane
kubectl get pods -n kube-system

# Ver API Server
kubectl get pods -n kube-system -l component=kube-apiserver

# Ver Scheduler
kubectl get pods -n kube-system -l component=kube-scheduler

# Ver Controller Manager
kubectl get pods -n kube-system -l component=kube-controller-manager

# Ver etcd
kubectl get pods -n kube-system -l component=etcd
```

### Exemplo 2: Logs dos Componentes

```bash
# Logs do API Server
kubectl logs -n kube-system kube-apiserver-<node-name>

# Logs do Scheduler
kubectl logs -n kube-system kube-scheduler-<node-name> --tail=50

# Logs do Controller Manager
kubectl logs -n kube-system kube-controller-manager-<node-name> -f

# Logs do etcd
kubectl logs -n kube-system etcd-<node-name>
```

### Exemplo 3: Interagir com etcd

```bash
# Entrar no pod do etcd
kubectl exec -it -n kube-system etcd-<node-name> -- sh

# Dentro do pod, listar keys
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get / --prefix --keys-only

# Ver dados de um pod
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/pods/default/nginx-pod
```

### Exemplo 4: Monitorar API Server

```bash
# Ver métricas do API Server
kubectl get --raw /metrics | grep apiserver

# Ver requisições por segundo
kubectl get --raw /metrics | grep apiserver_request_total

# Ver latência
kubectl get --raw /metrics | grep apiserver_request_duration_seconds
```

### Exemplo 5: Testar Scheduler

```bash
# Criar pod sem node específico
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-scheduler
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
EOF

# Ver eventos de scheduling
kubectl get events --sort-by='.lastTimestamp' | grep test-scheduler

# Ver em qual node foi agendado
kubectl get pod test-scheduler -o wide

# Deletar
kubectl delete pod test-scheduler
```

### Exemplo 6: Backup do etcd

```bash
# Fazer snapshot do etcd
kubectl exec -n kube-system etcd-<node-name> -- sh -c \
  "ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup.db"

# Copiar backup para host
kubectl cp kube-system/etcd-<node-name>:/tmp/etcd-backup.db ./etcd-backup.db

# Verificar backup
ETCDCTL_API=3 etcdctl snapshot status ./etcd-backup.db
```

---

## Fluxo de Comunicação dos Componentes

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE COMUNICAÇÃO CONTROL PLANE              │
└─────────────────────────────────────────────────────────┘

1. KUBECTL → API SERVER
   └─> kubectl apply -f deployment.yaml
   └─> API Server recebe requisição HTTP/HTTPS

2. API SERVER → ETCD
   ├─> Valida requisição
   ├─> Autentica e autoriza
   ├─> Persiste objeto no etcd
   └─> Retorna confirmação

3. API SERVER → CONTROLLER MANAGER
   ├─> Controller Manager assiste mudanças via watch
   ├─> Deployment Controller detecta novo Deployment
   ├─> Cria ReplicaSet
   └─> ReplicaSet Controller cria Pods

4. API SERVER → SCHEDULER
   ├─> Scheduler assiste Pods sem node
   ├─> Filtra e pontua nodes
   ├─> Atribui Pod a node
   └─> Atualiza Pod no API Server

5. API SERVER → KUBELET
   ├─> Kubelet assiste Pods atribuídos ao seu node
   ├─> Kubelet puxa imagem
   ├─> Kubelet inicia container
   └─> Kubelet reporta status ao API Server

6. API SERVER → ETCD
   └─> Atualiza status do Pod no etcd
```
