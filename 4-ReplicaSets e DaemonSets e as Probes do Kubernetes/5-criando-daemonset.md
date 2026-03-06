# Criando o Nosso DaemonSet

## Introdução

Neste guia prático, vamos criar DaemonSets do zero, explorando diferentes configurações e casos de uso reais. Você aprenderá a criar, configurar e gerenciar DaemonSets em um cluster Kubernetes.

## Preparação do Ambiente

```bash
# Verificar quantos nós temos no cluster
kubectl get nodes

# Saída exemplo:
# NAME     STATUS   ROLES           AGE   VERSION
# node1    Ready    control-plane   10d   v1.28.0
# node2    Ready    <none>          10d   v1.28.0
# node3    Ready    <none>          10d   v1.28.0

# Ver labels dos nós
kubectl get nodes --show-labels

# Ver taints dos nós
kubectl describe nodes | grep -i taint
```

## Exemplo 1: Primeiro DaemonSet - Monitor Simples

### Passo 1: Criar o Manifesto

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: simple-monitor
  labels:
    app: monitor
    type: system
spec:
  selector:
    matchLabels:
      name: simple-monitor
  template:
    metadata:
      labels:
        name: simple-monitor
    spec:
      containers:
      - name: monitor
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          echo "Monitor started on node: $(hostname)"
          while true; do
            echo "[$(date)] Node: $(hostname) - Status: Running"
            sleep 30
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
```

Salve como `simple-monitor-ds.yaml`

### Passo 2: Aplicar o DaemonSet

```bash
# Criar o DaemonSet
kubectl apply -f simple-monitor-ds.yaml

# Saída:
# daemonset.apps/simple-monitor created
```

### Passo 3: Verificar a Criação

```bash
# Ver o DaemonSet
kubectl get daemonset simple-monitor

# Saída:
# NAME             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
# simple-monitor   3         3         3       3            3           <none>          15s

# Ver os Pods criados (1 por nó)
kubectl get pods -l name=simple-monitor -o wide

# Saída:
# NAME                   READY   STATUS    RESTARTS   AGE   NODE
# simple-monitor-abc12   1/1     Running   0          20s   node1
# simple-monitor-def34   1/1     Running   0          20s   node2
# simple-monitor-ghi56   1/1     Running   0          20s   node3
```

### Passo 4: Verificar os Logs

```bash
# Ver logs de um Pod específico
kubectl logs simple-monitor-abc12

# Saída:
# Monitor started on node: simple-monitor-abc12
# [Tue Mar 3 14:43:00 UTC 2026] Node: simple-monitor-abc12 - Status: Running
# [Tue Mar 3 14:43:30 UTC 2026] Node: simple-monitor-abc12 - Status: Running

# Ver logs de todos os Pods do DaemonSet
kubectl logs -l name=simple-monitor --tail=5

# Seguir logs em tempo real
kubectl logs -f simple-monitor-abc12
```

### Passo 5: Inspecionar Detalhes

```bash
# Ver detalhes completos do DaemonSet
kubectl describe daemonset simple-monitor

# Informações importantes na saída:
# - Selector: name=simple-monitor
# - Desired Number of Nodes Scheduled: 3
# - Current Number of Nodes Scheduled: 3
# - Number of Nodes Scheduled with Up-to-date Pods: 3
# - Pods Status: 3 Running / 0 Waiting / 0 Succeeded / 0 Failed
```

## Exemplo 2: DaemonSet com Coleta de Informações do Sistema

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-info-collector
  labels:
    app: node-info
spec:
  selector:
    matchLabels:
      app: node-info
  template:
    metadata:
      labels:
        app: node-info
    spec:
      containers:
      - name: collector
        image: alpine:3.19
        command:
        - sh
        - -c
        - |
          apk add --no-cache curl
          echo "=== Node Information Collector ==="
          echo "Hostname: $(hostname)"
          echo "Starting collection..."
          while true; do
            echo "--- $(date) ---"
            echo "Memory Info:"
            free -h | head -2
            echo ""
            echo "Disk Info:"
            df -h / | tail -1
            echo ""
            sleep 60
          done
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        volumeMounts:
        - name: host-root
          mountPath: /host
          readOnly: true
      volumes:
      - name: host-root
        hostPath:
          path: /
          type: Directory
```

Salve como `node-info-collector-ds.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f node-info-collector-ds.yaml

# Verificar
kubectl get daemonset node-info-collector

# Ver logs com informações do sistema
kubectl logs -l app=node-info --tail=20

# Ver informações de um nó específico
kubectl logs node-info-collector-abc12 --tail=15
```

## Exemplo 3: DaemonSet com NodeSelector

### Passo 1: Adicionar Labels aos Nós

```bash
# Ver labels atuais dos nós
kubectl get nodes --show-labels

# Adicionar label indicando tipo de disco
kubectl label nodes node1 disk-type=ssd
kubectl label nodes node2 disk-type=hdd

# Verificar
kubectl get nodes -L disk-type

# Saída:
# NAME     STATUS   ROLES           AGE   VERSION   DISK-TYPE
# node1    Ready    control-plane   10d   v1.28.0   ssd
# node2    Ready    <none>          10d   v1.28.0   hdd
# node3    Ready    <none>          10d   v1.28.0   
```

### Passo 2: Criar DaemonSet para Nós SSD

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssd-optimizer
  labels:
    app: storage-optimizer
spec:
  selector:
    matchLabels:
      app: ssd-optimizer
  template:
    metadata:
      labels:
        app: ssd-optimizer
    spec:
      nodeSelector:
        disk-type: ssd
      containers:
      - name: optimizer
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          echo "SSD Optimizer running on: $(hostname)"
          echo "Optimizing SSD performance..."
          while true; do
            echo "[$(date)] SSD optimization check completed"
            sleep 60
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
```

Salve como `ssd-optimizer-ds.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f ssd-optimizer-ds.yaml

# Ver onde os Pods foram criados (apenas em nós com disk-type=ssd)
kubectl get pods -l app=ssd-optimizer -o wide

# Saída:
# NAME                   READY   STATUS    RESTARTS   AGE   NODE
# ssd-optimizer-abc12    1/1     Running   0          10s   node1

# Adicionar label a outro nó
kubectl label nodes node3 disk-type=ssd

# Verificar - novo Pod será criado automaticamente
kubectl get pods -l app=ssd-optimizer -o wide

# Saída:
# NAME                   READY   STATUS    RESTARTS   AGE   NODE
# ssd-optimizer-abc12    1/1     Running   0          2m    node1
# ssd-optimizer-xyz78    1/1     Running   0          5s    node3

# Remover label
kubectl label nodes node3 disk-type-

# O Pod no node3 será removido automaticamente
```

## Exemplo 4: DaemonSet de Monitoramento com Prometheus Node Exporter

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.7.0
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
        ports:
        - name: metrics
          containerPort: 9100
          hostPort: 9100
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
```

Salve como `node-exporter-ds.yaml`

```bash
# Criar namespace
kubectl create namespace monitoring

# Criar o DaemonSet
kubectl apply -f node-exporter-ds.yaml

# Verificar
kubectl get daemonset -n monitoring

# Ver Pods
kubectl get pods -n monitoring -o wide

# Testar métricas (de dentro do cluster)
kubectl run test-curl --image=curlimages/curl:8.5.0 --rm -it --restart=Never -- \
  curl http://node1:9100/metrics

# Ver detalhes
kubectl describe daemonset node-exporter -n monitoring
```

## Exemplo 5: DaemonSet com Tolerations para Control Plane

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cluster-monitor
  labels:
    app: cluster-monitor
spec:
  selector:
    matchLabels:
      app: cluster-monitor
  template:
    metadata:
      labels:
        app: cluster-monitor
    spec:
      tolerations:
      # Tolerar taint do control-plane
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      # Tolerar taint do master (versões antigas)
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: monitor
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          echo "Cluster Monitor on: $(hostname)"
          while true; do
            echo "[$(date)] Monitoring all nodes including control-plane"
            sleep 45
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
```

Salve como `cluster-monitor-ds.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f cluster-monitor-ds.yaml

# Ver Pods em TODOS os nós (incluindo control-plane)
kubectl get pods -l app=cluster-monitor -o wide

# Saída: Pods rodando em todos os nós, incluindo control-plane
# NAME                     READY   STATUS    RESTARTS   AGE   NODE
# cluster-monitor-abc12    1/1     Running   0          10s   node1 (control-plane)
# cluster-monitor-def34    1/1     Running   0          10s   node2
# cluster-monitor-ghi56    1/1     Running   0          10s   node3

# Ver taints dos nós
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

## Exemplo 6: DaemonSet com Estratégia de Atualização

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: app-agent
  labels:
    app: agent
    version: v1
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
        version: v1
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
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
```

Salve como `app-agent-ds.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f app-agent-ds.yaml

# Verificar versão inicial
kubectl get pods -l app=agent -o jsonpath='{.items[*].spec.containers[0].image}'

# Saída: nginx:1.26 nginx:1.26 nginx:1.26

# Atualizar a imagem
kubectl set image daemonset/app-agent agent=nginx:1.27

# Observar a atualização em tempo real
kubectl get pods -l app=agent --watch

# Em outro terminal, ver o status da atualização
kubectl rollout status daemonset/app-agent

# Saída:
# Waiting for daemon set "app-agent" rollout to finish: 1 out of 3 new pods have been updated...
# Waiting for daemon set "app-agent" rollout to finish: 2 out of 3 new pods have been updated...
# Waiting for daemon set "app-agent" rollout to finish: 3 out of 3 new pods have been updated...
# daemon set "app-agent" successfully rolled out

# Verificar nova versão
kubectl get pods -l app=agent -o jsonpath='{.items[*].spec.containers[0].image}'

# Saída: nginx:1.27 nginx:1.27 nginx:1.27
```

### Testando Rollback

```bash
# Ver histórico de revisões
kubectl rollout history daemonset/app-agent

# Saída:
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>

# Fazer rollback para versão anterior
kubectl rollout undo daemonset/app-agent

# Verificar o rollback
kubectl rollout status daemonset/app-agent

# Verificar versão após rollback
kubectl get pods -l app=agent -o jsonpath='{.items[*].spec.containers[0].image}'

# Saída: nginx:1.26 nginx:1.26 nginx:1.26
```

## Exemplo 7: DaemonSet com Estratégia OnDelete

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: manual-update-agent
  labels:
    app: manual-agent
spec:
  updateStrategy:
    type: OnDelete  # Pods só são atualizados quando deletados manualmente
  selector:
    matchLabels:
      app: manual-agent
  template:
    metadata:
      labels:
        app: manual-agent
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

Salve como `manual-update-agent-ds.yaml`

```bash
# Criar o DaemonSet
kubectl apply -f manual-update-agent-ds.yaml

# Atualizar a imagem no DaemonSet
kubectl set image daemonset/manual-update-agent agent=nginx:1.27

# Verificar - Pods NÃO são atualizados automaticamente
kubectl get pods -l app=manual-agent -o jsonpath='{.items[*].spec.containers[0].image}'

# Saída: nginx:1.26 nginx:1.26 nginx:1.26 (ainda na versão antiga)

# Deletar um Pod manualmente
kubectl delete pod manual-update-agent-abc12

# Verificar - o novo Pod terá a nova imagem
kubectl get pods -l app=manual-agent -o jsonpath='{.items[*].spec.containers[0].image}'

# Saída: nginx:1.27 nginx:1.26 nginx:1.26 (1 atualizado, 2 ainda antigos)

# Deletar os demais Pods para completar a atualização
kubectl delete pods -l app=manual-agent

# Verificar
kubectl get pods -l app=manual-agent -o jsonpath='{.items[*].spec.containers[0].image}'

# Saída: nginx:1.27 nginx:1.27 nginx:1.27 (todos atualizados)
```

## Exemplo 8: DaemonSet com Prioridade e QoS

```yaml
apiVersion: v1
kind: PriorityClass
metadata:
  name: system-critical
value: 1000000
globalDefault: false
description: "Prioridade para serviços críticos do sistema"
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: critical-monitor
  labels:
    app: critical-monitor
spec:
  selector:
    matchLabels:
      app: critical-monitor
  template:
    metadata:
      labels:
        app: critical-monitor
    spec:
      priorityClassName: system-critical
      containers:
      - name: monitor
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          echo "Critical Monitor on: $(hostname)"
          while true; do
            echo "[$(date)] Critical monitoring active"
            sleep 30
          done
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "64Mi"  # Igual ao request = QoS Guaranteed
            cpu: "100m"
```

Salve como `critical-monitor-ds.yaml`

```bash
# Criar PriorityClass e DaemonSet
kubectl apply -f critical-monitor-ds.yaml

# Verificar a prioridade
kubectl get pods -l app=critical-monitor -o jsonpath='{.items[0].spec.priorityClassName}'

# Saída: system-critical

# Ver QoS class
kubectl get pods -l app=critical-monitor -o jsonpath='{.items[*].status.qosClass}'

# Saída: Guaranteed Guaranteed Guaranteed
```

## Operações Avançadas

### Pausar e Retomar Atualizações

```bash
# Não há comando pause para DaemonSet como há para Deployment
# Mas você pode usar OnDelete para controle manual

# Alterar para OnDelete
kubectl patch daemonset app-agent -p '{"spec":{"updateStrategy":{"type":"OnDelete"}}}'

# Fazer mudanças
kubectl set image daemonset/app-agent agent=nginx:alpine

# Atualizar Pods manualmente, um por vez
kubectl delete pod app-agent-abc12
# Verificar se está OK
kubectl delete pod app-agent-def34
# E assim por diante
```

### Escalar Horizontalmente (Adicionar Nós)

```bash
# DaemonSets escalam automaticamente com os nós
# Simular adição de nó (em ambiente real, adicione um nó ao cluster)

# Ver Pods atuais
kubectl get pods -l app=agent -o wide

# Quando um novo nó é adicionado, o DaemonSet cria automaticamente um Pod nele
# Você pode simular isso adicionando/removendo nodeSelector
```

### Filtrar Nós Dinamicamente

```bash
# Criar DaemonSet que roda apenas em nós com label específica
kubectl label nodes node2 monitoring=enabled

# Atualizar DaemonSet para usar nodeSelector
kubectl patch daemonset simple-monitor -p '{"spec":{"template":{"spec":{"nodeSelector":{"monitoring":"enabled"}}}}}'

# Ver onde os Pods estão rodando agora
kubectl get pods -l name=simple-monitor -o wide

# Adicionar label a mais nós
kubectl label nodes node3 monitoring=enabled

# Novo Pod será criado automaticamente
```

## Monitoramento e Debug

### Ver Status Detalhado

```bash
# Status completo do DaemonSet
kubectl describe daemonset app-agent

# Campos importantes:
# - Desired Number of Nodes Scheduled
# - Current Number of Nodes Scheduled
# - Number of Nodes Scheduled with Up-to-date Pods
# - Number of Nodes Scheduled with Available Pods
# - Number of Nodes Misscheduled

# Ver eventos recentes
kubectl get events --field-selector involvedObject.name=app-agent --sort-by='.lastTimestamp'
```

### Verificar Distribuição dos Pods

```bash
# Ver em quais nós os Pods estão
kubectl get pods -l app=agent -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase

# Ver recursos consumidos por nó
kubectl top pods -l app=agent --sort-by=cpu
```

### Debug de Pods que Não Iniciam

```bash
# Ver por que um Pod não está rodando
kubectl describe pod app-agent-abc12

# Ver logs mesmo se o Pod falhou
kubectl logs app-agent-abc12 --previous

# Ver eventos do Pod
kubectl get events --field-selector involvedObject.name=app-agent-abc12
```

## Limpeza

```bash
# Deletar DaemonSets criados
kubectl delete daemonset simple-monitor node-info-collector ssd-optimizer cluster-monitor app-agent manual-update-agent critical-monitor

# Deletar do namespace monitoring
kubectl delete daemonset node-exporter -n monitoring
kubectl delete namespace monitoring

# Remover labels dos nós
kubectl label nodes node1 disk-type-
kubectl label nodes node2 disk-type-
kubectl label nodes node2 monitoring-

# Deletar PriorityClass
kubectl delete priorityclass system-critical

# Verificar limpeza
kubectl get daemonset --all-namespaces
kubectl get pods --all-namespaces | grep -E "monitor|agent|exporter"
```

## Boas Práticas

1. **Sempre defina recursos (requests e limits)**
   ```yaml
   resources:
     requests:
       memory: "64Mi"
       cpu: "100m"
     limits:
       memory: "128Mi"
       cpu: "200m"
   ```

2. **Use tolerations para nós especiais**
   ```yaml
   tolerations:
   - key: node-role.kubernetes.io/control-plane
     operator: Exists
     effect: NoSchedule
   ```

3. **Configure health checks**
   ```yaml
   livenessProbe:
     httpGet:
       path: /health
       port: 8080
   readinessProbe:
     httpGet:
       path: /ready
       port: 8080
   ```

4. **Use RollingUpdate com maxUnavailable apropriado**
   ```yaml
   updateStrategy:
     type: RollingUpdate
     rollingUpdate:
       maxUnavailable: 1  # Atualizar 1 nó por vez
   ```

5. **Adicione labels descritivas**
   ```yaml
   labels:
     app: nome-app
     component: monitoring
     tier: infrastructure
   ```

6. **Use namespaces para organização**
   - DaemonSets de sistema: `kube-system`
   - Monitoramento: `monitoring`
   - Logs: `logging`

7. **Configure prioridade para DaemonSets críticos**
   ```yaml
   priorityClassName: system-node-critical
   ```

8. **Teste em ambiente de desenvolvimento primeiro**
   ```bash
   kubectl apply -f daemonset.yaml --dry-run=client
   ```

## Resumo

- DaemonSets garantem 1 Pod por nó automaticamente
- Use `nodeSelector` para controlar em quais nós rodar
- Use `tolerations` para rodar em nós com taints (como control-plane)
- `RollingUpdate` atualiza gradualmente, `OnDelete` requer deleção manual
- DaemonSets escalam automaticamente quando nós são adicionados/removidos
- Ideal para serviços de infraestrutura que precisam rodar em todos os nós
- Sempre configure recursos, health checks e estratégia de atualização
