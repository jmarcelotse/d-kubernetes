# O que é um DaemonSet?

## Conceito

Um **DaemonSet** é um objeto do Kubernetes que garante que uma cópia de um Pod seja executada em **todos** (ou alguns) nós do cluster. Quando novos nós são adicionados ao cluster, o DaemonSet automaticamente cria Pods neles. Quando nós são removidos, os Pods são automaticamente deletados.

## Diferença entre ReplicaSet e DaemonSet

| Característica | ReplicaSet | DaemonSet |
|----------------|-----------|-----------|
| Número de réplicas | Fixo (ex: 3 réplicas) | 1 por nó |
| Distribuição | Kubernetes decide onde | 1 Pod em cada nó |
| Escalabilidade | Manual (alterar replicas) | Automática (segue nós) |
| Uso típico | Aplicações stateless | Serviços de infraestrutura |

## Visualização

```
REPLICASET (3 réplicas):
┌──────────┐  ┌──────────┐  ┌──────────┐
│  Node 1  │  │  Node 2  │  │  Node 3  │
│          │  │          │  │          │
│  Pod     │  │  Pod     │  │          │
│  Pod     │  │          │  │  Pod     │
└──────────┘  └──────────┘  └──────────┘
   (2 Pods)     (1 Pod)      (1 Pod)


DAEMONSET:
┌──────────┐  ┌──────────┐  ┌──────────┐
│  Node 1  │  │  Node 2  │  │  Node 3  │
│          │  │          │  │          │
│  Pod     │  │  Pod     │  │  Pod     │
│          │  │          │  │          │
└──────────┘  └──────────┘  └──────────┘
   (1 Pod)      (1 Pod)      (1 Pod)
```

## Casos de Uso Comuns

DaemonSets são ideais para serviços que precisam rodar em todos os nós:

1. **Monitoramento e Logs**
   - Coletores de logs (Fluentd, Filebeat, Logstash)
   - Agentes de monitoramento (Prometheus Node Exporter, Datadog Agent)
   - Métricas de sistema (cAdvisor)

2. **Rede**
   - CNI plugins (Calico, Weave, Flannel)
   - Proxies de rede (kube-proxy)
   - Service mesh data plane (Istio, Linkerd)

3. **Armazenamento**
   - Drivers de storage (Ceph, GlusterFS)
   - Agentes de backup

4. **Segurança**
   - Scanners de vulnerabilidade
   - Agentes de segurança
   - Auditoria de nós

## Estrutura de um DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nome-daemonset
  labels:
    chave: valor
spec:
  selector:
    matchLabels:
      chave: valor
  template:
    metadata:
      labels:
        chave: valor
    spec:
      containers:
      - name: nome-container
        image: imagem:tag
```

**Diferença do ReplicaSet**: Não há campo `replicas` - o número de Pods é determinado pelo número de nós.

## Exemplo Prático 1: DaemonSet Básico de Monitoramento

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
  labels:
    app: monitoring
spec:
  selector:
    matchLabels:
      app: node-monitor
  template:
    metadata:
      labels:
        app: node-monitor
    spec:
      containers:
      - name: monitor
        image: busybox:1.36
        command: ['sh', '-c', 'while true; do echo "Monitoring node $(hostname) at $(date)"; sleep 30; done']
        resources:
          requests:
            memory: "32Mi"
            cpu: "100m"
          limits:
            memory: "64Mi"
            cpu: "200m"
```

Salve como `node-monitor-daemonset.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f node-monitor-daemonset.yaml

# Ver o DaemonSet
kubectl get daemonset

# Saída:
# NAME           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
# node-monitor   3         3         3       3            3           <none>          10s

# Ver os Pods criados (1 por nó)
kubectl get pods -o wide

# Saída:
# NAME                 READY   STATUS    RESTARTS   AGE   NODE
# node-monitor-abc12   1/1     Running   0          20s   node1
# node-monitor-def34   1/1     Running   0          20s   node2
# node-monitor-ghi56   1/1     Running   0          20s   node3

# Ver logs de um Pod
kubectl logs node-monitor-abc12
```

## Exemplo Prático 2: DaemonSet com Node Selector

Executar o DaemonSet apenas em nós específicos:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssd-monitor
  labels:
    app: storage-monitor
spec:
  selector:
    matchLabels:
      app: ssd-monitor
  template:
    metadata:
      labels:
        app: ssd-monitor
    spec:
      nodeSelector:
        disk: ssd  # Apenas em nós com label disk=ssd
      containers:
      - name: monitor
        image: busybox:1.36
        command: ['sh', '-c', 'echo "Monitoring SSD on $(hostname)"; sleep infinity']
```

Salve como `ssd-monitor-daemonset.yaml`

```bash
# Primeiro, adicionar label a um nó
kubectl label nodes node1 disk=ssd

# Criar o DaemonSet
kubectl apply -f ssd-monitor-daemonset.yaml

# Ver onde os Pods foram criados
kubectl get pods -o wide

# Saída: Pod criado apenas no node1
# NAME                 READY   STATUS    RESTARTS   AGE   NODE
# ssd-monitor-abc12    1/1     Running   0          10s   node1

# Adicionar label a outro nó
kubectl label nodes node2 disk=ssd

# Verificar - um novo Pod será criado automaticamente no node2
kubectl get pods -o wide

# Remover label
kubectl label nodes node2 disk-

# O Pod no node2 será removido automaticamente
```

## Exemplo Prático 3: DaemonSet de Coleta de Logs

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  namespace: kube-system
  labels:
    app: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:v1.16
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

Salve como `log-collector-daemonset.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f log-collector-daemonset.yaml

# Ver DaemonSets no namespace kube-system
kubectl get daemonset -n kube-system

# Ver Pods criados
kubectl get pods -n kube-system -l app=log-collector -o wide

# Ver detalhes
kubectl describe daemonset log-collector -n kube-system
```

## Exemplo Prático 4: DaemonSet com Tolerations

Para executar em nós master/control-plane (que normalmente têm taints):

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: system-monitor
  labels:
    app: system-monitor
spec:
  selector:
    matchLabels:
      app: system-monitor
  template:
    metadata:
      labels:
        app: system-monitor
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: monitor
        image: busybox:1.36
        command: ['sh', '-c', 'echo "Monitoring $(hostname)"; sleep infinity']
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
```

Salve como `system-monitor-daemonset.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f system-monitor-daemonset.yaml

# Ver Pods em todos os nós (incluindo control-plane)
kubectl get pods -o wide

# Ver taints dos nós
kubectl describe nodes | grep -i taint
```

## Exemplo Prático 5: DaemonSet com HostNetwork

Para serviços que precisam acessar a rede do host:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: network-monitor
  labels:
    app: network-monitor
spec:
  selector:
    matchLabels:
      app: network-monitor
  template:
    metadata:
      labels:
        app: network-monitor
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: monitor
        image: nicolaka/netshoot:latest
        command: ['sh', '-c', 'while true; do echo "Network info for $(hostname):"; ip addr show | grep inet; sleep 60; done']
        securityContext:
          privileged: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

Salve como `network-monitor-daemonset.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f network-monitor-daemonset.yaml

# Ver logs (mostrará informações de rede do host)
kubectl logs network-monitor-abc12

# Executar comandos de rede no host
kubectl exec -it network-monitor-abc12 -- ip addr show
```

## Exemplo Prático 6: DaemonSet com UpdateStrategy

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: app-agent
  labels:
    app: agent
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Atualizar 1 nó por vez
  selector:
    matchLabels:
      app: agent
  template:
    metadata:
      labels:
        app: agent
    spec:
      containers:
      - name: agent
        image: nginx:1.26
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

Salve como `app-agent-daemonset.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f app-agent-daemonset.yaml

# Ver o DaemonSet
kubectl get daemonset app-agent

# Atualizar a imagem
kubectl set image daemonset/app-agent agent=nginx:1.27

# Observar a atualização rolling
kubectl rollout status daemonset/app-agent

# Ver histórico
kubectl rollout history daemonset/app-agent

# Fazer rollback se necessário
kubectl rollout undo daemonset/app-agent
```

## Fluxo de Funcionamento do DaemonSet

```
1. DaemonSet é criado
   └─> DaemonSet Controller é notificado

2. Controller lista todos os nós do cluster
   └─> Verifica nodeSelector e tolerations

3. Para cada nó elegível:
   └─> Cria 1 Pod naquele nó

4. Novo nó é adicionado ao cluster
   └─> DaemonSet Controller detecta
   └─> Cria Pod automaticamente no novo nó

5. Nó é removido do cluster
   └─> Pod é automaticamente deletado

6. Pod falha ou é deletado
   └─> DaemonSet Controller recria o Pod no mesmo nó
```

## Comandos Úteis para DaemonSets

```bash
# Listar DaemonSets
kubectl get daemonset
kubectl get ds  # forma abreviada

# Ver DaemonSets em todos os namespaces
kubectl get daemonset --all-namespaces

# Ver detalhes de um DaemonSet
kubectl describe daemonset <nome>

# Ver Pods de um DaemonSet
kubectl get pods -l app=<label>

# Ver em quais nós os Pods estão rodando
kubectl get pods -o wide -l app=<label>

# Atualizar imagem do DaemonSet
kubectl set image daemonset/<nome> <container>=<nova-imagem>

# Ver status da atualização
kubectl rollout status daemonset/<nome>

# Ver histórico de revisões
kubectl rollout history daemonset/<nome>

# Fazer rollback
kubectl rollout undo daemonset/<nome>

# Deletar DaemonSet
kubectl delete daemonset <nome>

# Deletar mantendo os Pods
kubectl delete daemonset <nome> --cascade=orphan
```

## Estratégias de Atualização

### 1. RollingUpdate (Padrão)

Atualiza Pods gradualmente, um nó por vez:

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Número máximo de Pods indisponíveis durante atualização
```

```bash
# Atualizar com RollingUpdate
kubectl set image daemonset/app-agent agent=nginx:1.27

# Observar a atualização
kubectl get pods -l app=agent --watch
```

### 2. OnDelete

Pods são atualizados apenas quando deletados manualmente:

```yaml
spec:
  updateStrategy:
    type: OnDelete
```

```bash
# Atualizar o DaemonSet (Pods não são atualizados automaticamente)
kubectl set image daemonset/app-agent agent=nginx:1.27

# Deletar Pods manualmente para forçar atualização
kubectl delete pod app-agent-abc12

# O novo Pod será criado com a nova imagem
```

## Exemplo Prático 7: DaemonSet com Affinity

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gpu-monitor
  labels:
    app: gpu-monitor
spec:
  selector:
    matchLabels:
      app: gpu-monitor
  template:
    metadata:
      labels:
        app: gpu-monitor
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: gpu
                operator: In
                values:
                - nvidia
                - amd
      containers:
      - name: monitor
        image: busybox:1.36
        command: ['sh', '-c', 'echo "Monitoring GPU on $(hostname)"; sleep infinity']
```

```bash
# Adicionar label a nós com GPU
kubectl label nodes node1 gpu=nvidia
kubectl label nodes node2 gpu=amd

# Criar o DaemonSet
kubectl apply -f gpu-monitor-daemonset.yaml

# Verificar onde os Pods foram criados
kubectl get pods -o wide -l app=gpu-monitor
```

## Monitorando DaemonSets

```bash
# Ver status detalhado
kubectl describe daemonset <nome>

# Campos importantes na saída:
# - Desired Number of Nodes Scheduled: quantos nós devem ter o Pod
# - Current Number of Nodes Scheduled: quantos nós têm o Pod
# - Number of Nodes Scheduled with Up-to-date Pods: quantos estão atualizados
# - Number of Nodes Scheduled with Available Pods: quantos estão disponíveis

# Ver eventos
kubectl get events --sort-by=.metadata.creationTimestamp

# Monitorar em tempo real
kubectl get daemonset --watch

# Ver métricas dos Pods
kubectl top pods -l app=<label>
```

## Troubleshooting

### Problema: DaemonSet não cria Pods em alguns nós

```bash
# Verificar taints dos nós
kubectl describe nodes | grep -A 5 Taints

# Verificar se o DaemonSet tem tolerations adequadas
kubectl describe daemonset <nome> | grep -A 10 Tolerations

# Verificar nodeSelector
kubectl describe daemonset <nome> | grep -A 5 "Node-Selectors"

# Ver eventos
kubectl describe daemonset <nome> | grep -A 20 Events
```

### Problema: Pods do DaemonSet ficam em Pending

```bash
# Ver por que o Pod está pending
kubectl describe pod <nome-pod>

# Verificar recursos disponíveis no nó
kubectl describe node <nome-node>

# Verificar se há recursos suficientes
kubectl top nodes
```

### Problema: Atualização não acontece

```bash
# Verificar estratégia de atualização
kubectl get daemonset <nome> -o yaml | grep -A 5 updateStrategy

# Se for OnDelete, deletar Pods manualmente
kubectl delete pods -l app=<label>

# Ver status da atualização
kubectl rollout status daemonset/<nome>
```

## Comparação: DaemonSet vs Deployment vs StatefulSet

| Característica | DaemonSet | Deployment | StatefulSet |
|----------------|-----------|------------|-------------|
| Réplicas | 1 por nó | Número fixo | Número fixo |
| Identidade | Por nó | Aleatória | Persistente |
| Distribuição | Todos os nós | Kubernetes decide | Ordenada |
| Escalabilidade | Automática (segue nós) | Manual | Manual |
| Uso típico | Infraestrutura | Apps stateless | Apps stateful |

## Limpeza

```bash
# Deletar DaemonSets criados
kubectl delete daemonset node-monitor ssd-monitor system-monitor network-monitor app-agent gpu-monitor

# Deletar do namespace kube-system
kubectl delete daemonset log-collector -n kube-system

# Remover labels dos nós
kubectl label nodes node1 disk-
kubectl label nodes node1 gpu-

# Verificar que tudo foi removido
kubectl get daemonset --all-namespaces
kubectl get pods --all-namespaces
```

## Resumo

- **DaemonSet** garante que 1 Pod rode em cada nó do cluster
- Ideal para serviços de infraestrutura (logs, monitoramento, rede)
- Não tem campo `replicas` - o número de Pods segue o número de nós
- Usa **nodeSelector** e **tolerations** para controlar em quais nós rodar
- Suporta **RollingUpdate** e **OnDelete** como estratégias de atualização
- Automaticamente cria Pods em novos nós e remove de nós deletados
- Pode usar **hostNetwork**, **hostPID** e **privileged** para acesso ao host
- Comum em namespaces de sistema como `kube-system`
