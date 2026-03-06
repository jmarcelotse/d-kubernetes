# Visualizando Mais Informações sobre os Nodes

Este guia mostra como obter informações detalhadas sobre os nodes do cluster Kubernetes usando diversos comandos e ferramentas.

## 1. Comandos Básicos

### kubectl get nodes

```bash
# Listar todos os nodes
kubectl get nodes

# Saída:
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master-1   Ready    control-plane   1h    v1.28.0
# k8s-worker-1   Ready    <none>          45m   v1.28.0
# k8s-worker-2   Ready    <none>          45m   v1.28.0
# k8s-worker-3   Ready    <none>          45m   v1.28.0

# Com mais informações
kubectl get nodes -o wide

# Saída:
# NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
# k8s-master-1   Ready    control-plane   1h    v1.28.0   10.0.1.10     <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.8
# k8s-worker-1   Ready    <none>          45m   v1.28.0   10.0.1.20     <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.8
# k8s-worker-2   Ready    <none>          45m   v1.28.0   10.0.1.21     <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.8
# k8s-worker-3   Ready    <none>          45m   v1.28.0   10.0.1.22     <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.8

# Mostrar labels
kubectl get nodes --show-labels

# Filtrar por label
kubectl get nodes -l node-role.kubernetes.io/control-plane

# Ordenar por nome
kubectl get nodes --sort-by=.metadata.name

# Ordenar por idade
kubectl get nodes --sort-by=.metadata.creationTimestamp
```

### kubectl describe node

```bash
# Ver detalhes completos de um node
kubectl describe node k8s-worker-1

# Saída (resumida):
# Name:               k8s-worker-1
# Roles:              <none>
# Labels:             beta.kubernetes.io/arch=amd64
#                     beta.kubernetes.io/os=linux
#                     kubernetes.io/arch=amd64
#                     kubernetes.io/hostname=k8s-worker-1
#                     kubernetes.io/os=linux
# Annotations:        kubeadm.alpha.kubernetes.io/cri-socket: unix:///var/run/containerd/containerd.sock
#                     node.alpha.kubernetes.io/ttl: 0
# CreationTimestamp:  Wed, 04 Mar 2026 10:15:00 -0300
# Taints:             <none>
# Unschedulable:      false
# Conditions:
#   Type             Status  LastHeartbeatTime                 LastTransitionTime                Reason                       Message
#   ----             ------  -----------------                 ------------------                ------                       -------
#   MemoryPressure   False   Wed, 04 Mar 2026 11:00:00 -0300   Wed, 04 Mar 2026 10:15:00 -0300   KubeletHasSufficientMemory   kubelet has sufficient memory available
#   DiskPressure     False   Wed, 04 Mar 2026 11:00:00 -0300   Wed, 04 Mar 2026 10:15:00 -0300   KubeletHasNoDiskPressure     kubelet has no disk pressure
#   PIDPressure      False   Wed, 04 Mar 2026 11:00:00 -0300   Wed, 04 Mar 2026 10:15:00 -0300   KubeletHasSufficientPID      kubelet has sufficient PID available
#   Ready            True    Wed, 04 Mar 2026 11:00:00 -0300   Wed, 04 Mar 2026 10:20:00 -0300   KubeletReady                 kubelet is posting ready status
# Addresses:
#   InternalIP:  10.0.1.20
#   Hostname:    k8s-worker-1
# Capacity:
#   cpu:                2
#   ephemeral-storage:  51175Mi
#   hugepages-1Gi:      0
#   hugepages-2Mi:      0
#   memory:             4027584Ki
#   pods:               110
# Allocatable:
#   cpu:                2
#   ephemeral-storage:  47162Mi
#   hugepages-1Gi:      0
#   hugepages-2Mi:      0
#   memory:             3925184Ki
#   pods:               110
# System Info:
#   Machine ID:                 ec2xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#   System UUID:                ec2xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#   Boot ID:                    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   Kernel Version:             5.15.0-91-generic
#   OS Image:                   Ubuntu 22.04.3 LTS
#   Operating System:           linux
#   Architecture:               amd64
#   Container Runtime Version:  containerd://1.7.8
#   Kubelet Version:            v1.28.0
#   Kube-Proxy Version:         v1.28.0
# Non-terminated Pods:          (3 in total)
#   Namespace                   Name                          CPU Requests  CPU Limits  Memory Requests  Memory Limits  Age
#   ---------                   ----                          ------------  ----------  ---------------  -------------  ---
#   kube-system                 calico-node-xxxxx             250m (12%)    0 (0%)      0 (0%)           0 (0%)         45m
#   kube-system                 kube-proxy-xxxxx              0 (0%)        0 (0%)      0 (0%)           0 (0%)         45m
#   default                     nginx-7854ff8877-abc12        0 (0%)        0 (0%)      0 (0%)           0 (0%)         10m
# Allocated resources:
#   (Total limits may be over 100 percent, i.e., overcommitted.)
#   Resource           Requests    Limits
#   --------           --------    ------
#   cpu                250m (12%)  0 (0%)
#   memory             0 (0%)      0 (0%)
#   ephemeral-storage  0 (0%)      0 (0%)
#   hugepages-1Gi      0 (0%)      0 (0%)
#   hugepages-2Mi      0 (0%)      0 (0%)
# Events:
#   Type    Reason                   Age   From     Message
#   ----    ------                   ----  ----     -------
#   Normal  Starting                 45m   kubelet  Starting kubelet.
#   Normal  NodeHasSufficientMemory  45m   kubelet  Node k8s-worker-1 status is now: NodeHasSufficientMemory
#   Normal  NodeHasNoDiskPressure    45m   kubelet  Node k8s-worker-1 status is now: NodeHasNoDiskPressure
#   Normal  NodeHasSufficientPID     45m   kubelet  Node k8s-worker-1 status is now: NodeHasSufficientPID
#   Normal  NodeReady                45m   kubelet  Node k8s-worker-1 status is now: NodeReady

# Ver apenas seções específicas
kubectl describe node k8s-worker-1 | grep -A 10 "Capacity:"
kubectl describe node k8s-worker-1 | grep -A 10 "Allocated resources:"
kubectl describe node k8s-worker-1 | grep -A 20 "Events:"
```

## 2. Formatos de Saída

### JSON

```bash
# Saída em JSON
kubectl get nodes -o json

# JSON de um node específico
kubectl get node k8s-worker-1 -o json

# Extrair campo específico com jq
kubectl get node k8s-worker-1 -o json | jq '.status.capacity'

# Saída:
# {
#   "cpu": "2",
#   "ephemeral-storage": "51175Mi",
#   "hugepages-1Gi": "0",
#   "hugepages-2Mi": "0",
#   "memory": "4027584Ki",
#   "pods": "110"
# }

# Ver apenas IPs
kubectl get nodes -o json | jq '.items[].status.addresses'

# Ver versões
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, version: .status.nodeInfo.kubeletVersion}'
```

### YAML

```bash
# Saída em YAML
kubectl get node k8s-worker-1 -o yaml

# Salvar em arquivo
kubectl get node k8s-worker-1 -o yaml > k8s-worker-1.yaml

# Ver apenas metadata
kubectl get node k8s-worker-1 -o yaml | grep -A 20 "metadata:"
```

### JSONPath

```bash
# Nome dos nodes
kubectl get nodes -o jsonpath='{.items[*].metadata.name}'

# IPs internos
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# Capacidade de CPU
kubectl get nodes -o jsonpath='{.items[*].status.capacity.cpu}'

# Tabela customizada
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.cpu}{"\t"}{.status.capacity.memory}{"\n"}{end}'

# Com cabeçalho
kubectl get nodes -o jsonpath='{"NAME\tCPU\tMEMORY\n"}{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.cpu}{"\t"}{.status.capacity.memory}{"\n"}{end}'

# Saída:
# NAME            CPU     MEMORY
# k8s-master-1    2       4027584Ki
# k8s-worker-1    2       4027584Ki
# k8s-worker-2    2       4027584Ki
# k8s-worker-3    2       4027584Ki
```

### Custom Columns

```bash
# Colunas customizadas
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory,OS:.status.nodeInfo.osImage

# Saída:
# NAME           CPU   MEMORY       OS
# k8s-master-1   2     4027584Ki    Ubuntu 22.04.3 LTS
# k8s-worker-1   2     4027584Ki    Ubuntu 22.04.3 LTS
# k8s-worker-2   2     4027584Ki    Ubuntu 22.04.3 LTS
# k8s-worker-3   2     4027584Ki    Ubuntu 22.04.3 LTS

# Mais informações
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[-1].type,\
ROLE:.metadata.labels.node-role\.kubernetes\.io/control-plane,\
AGE:.metadata.creationTimestamp,\
VERSION:.status.nodeInfo.kubeletVersion,\
INTERNAL-IP:.status.addresses[0].address,\
OS:.status.nodeInfo.osImage,\
KERNEL:.status.nodeInfo.kernelVersion,\
CONTAINER-RUNTIME:.status.nodeInfo.containerRuntimeVersion
```

## 3. Informações de Recursos

### Capacidade e Alocação

```bash
# Ver capacidade de todos os nodes
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU-CAPACITY:.status.capacity.cpu,\
MEMORY-CAPACITY:.status.capacity.memory,\
PODS-CAPACITY:.status.capacity.pods

# Ver recursos alocáveis
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU-ALLOCATABLE:.status.allocatable.cpu,\
MEMORY-ALLOCATABLE:.status.allocatable.memory,\
PODS-ALLOCATABLE:.status.allocatable.pods

# Comparar capacidade vs alocável
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name)\tCPU: \(.status.capacity.cpu) / \(.status.allocatable.cpu)\tMemory: \(.status.capacity.memory) / \(.status.allocatable.memory)"'
```

### kubectl top nodes

```bash
# Ver uso de recursos (requer metrics-server)
kubectl top nodes

# Saída:
# NAME           CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# k8s-master-1   156m         7%     1234Mi          31%
# k8s-worker-1   89m          4%     987Mi           25%
# k8s-worker-2   92m          4%     1023Mi          26%
# k8s-worker-3   85m          4%     945Mi           24%

# Ordenar por CPU
kubectl top nodes --sort-by=cpu

# Ordenar por memória
kubectl top nodes --sort-by=memory
```

### Instalar Metrics Server

```bash
# Instalar metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Para ambientes de teste (sem TLS)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Verificar
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

## 4. Condições dos Nodes

### Ver Condições

```bash
# Ver condições de um node
kubectl get node k8s-worker-1 -o jsonpath='{.status.conditions[*].type}' | tr ' ' '\n'

# Saída:
# MemoryPressure
# DiskPressure
# PIDPressure
# Ready

# Ver status de cada condição
kubectl get node k8s-worker-1 -o json | jq '.status.conditions[] | {type: .type, status: .status, reason: .reason}'

# Saída:
# {
#   "type": "MemoryPressure",
#   "status": "False",
#   "reason": "KubeletHasSufficientMemory"
# }
# {
#   "type": "DiskPressure",
#   "status": "False",
#   "reason": "KubeletHasNoDiskPressure"
# }
# {
#   "type": "PIDPressure",
#   "status": "False",
#   "reason": "KubeletHasSufficientPID"
# }
# {
#   "type": "Ready",
#   "status": "True",
#   "reason": "KubeletReady"
# }

# Ver apenas nodes Ready
kubectl get nodes -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True")) | .metadata.name'

# Ver nodes com problemas
kubectl get nodes -o json | jq -r '.items[] | select(.status.conditions[] | select(.type!="Ready" and .status!="False")) | .metadata.name'
```

### Tipos de Condições

| Condição | Descrição |
|----------|-----------|
| **Ready** | Node está saudável e pronto para aceitar pods |
| **MemoryPressure** | Node está com pouca memória |
| **DiskPressure** | Node está com pouco espaço em disco |
| **PIDPressure** | Node está com poucos PIDs disponíveis |
| **NetworkUnavailable** | Rede do node não está configurada corretamente |

## 5. Labels e Annotations

### Ver Labels

```bash
# Ver labels de um node
kubectl get node k8s-worker-1 --show-labels

# Ver labels formatado
kubectl get node k8s-worker-1 -o json | jq '.metadata.labels'

# Saída:
# {
#   "beta.kubernetes.io/arch": "amd64",
#   "beta.kubernetes.io/os": "linux",
#   "kubernetes.io/arch": "amd64",
#   "kubernetes.io/hostname": "k8s-worker-1",
#   "kubernetes.io/os": "linux"
# }

# Adicionar label
kubectl label node k8s-worker-1 environment=production

# Adicionar múltiplos labels
kubectl label node k8s-worker-1 tier=backend region=us-east-1

# Remover label
kubectl label node k8s-worker-1 environment-

# Atualizar label existente
kubectl label node k8s-worker-1 environment=staging --overwrite

# Ver nodes por label
kubectl get nodes -l environment=production
kubectl get nodes -l tier=backend
```

### Ver Annotations

```bash
# Ver annotations
kubectl get node k8s-worker-1 -o json | jq '.metadata.annotations'

# Saída:
# {
#   "kubeadm.alpha.kubernetes.io/cri-socket": "unix:///var/run/containerd/containerd.sock",
#   "node.alpha.kubernetes.io/ttl": "0",
#   "volumes.kubernetes.io/controller-managed-attach-detach": "true"
# }

# Adicionar annotation
kubectl annotate node k8s-worker-1 description="Worker node for production workloads"

# Remover annotation
kubectl annotate node k8s-worker-1 description-
```

## 6. Taints e Tolerations

### Ver Taints

```bash
# Ver taints de um node
kubectl describe node k8s-master-1 | grep Taints

# Saída:
# Taints:  node-role.kubernetes.io/control-plane:NoSchedule

# Ver taints formatado
kubectl get node k8s-master-1 -o json | jq '.spec.taints'

# Saída:
# [
#   {
#     "effect": "NoSchedule",
#     "key": "node-role.kubernetes.io/control-plane"
#   }
# ]

# Adicionar taint
kubectl taint node k8s-worker-3 dedicated=special-workload:NoSchedule

# Remover taint
kubectl taint node k8s-worker-3 dedicated=special-workload:NoSchedule-

# Tipos de efeitos
# NoSchedule: Não agenda novos pods
# PreferNoSchedule: Tenta não agendar, mas não garante
# NoExecute: Não agenda e remove pods existentes
```

## 7. Pods em Cada Node

### Listar Pods por Node

```bash
# Ver pods em um node específico
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=k8s-worker-1

# Contar pods por node
kubectl get pods --all-namespaces -o json | jq -r '.items[] | .spec.nodeName' | sort | uniq -c

# Saída:
#   8 k8s-master-1
#   5 k8s-worker-1
#   6 k8s-worker-2
#   4 k8s-worker-3

# Ver distribuição de pods
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "Node: $node"
    kubectl get pods --all-namespaces --field-selector spec.nodeName=$node --no-headers | wc -l
done

# Script mais detalhado
kubectl get nodes -o json | jq -r '.items[] | .metadata.name' | while read node; do
    pod_count=$(kubectl get pods --all-namespaces --field-selector spec.nodeName=$node --no-headers 2>/dev/null | wc -l)
    echo "$node: $pod_count pods"
done
```

### Ver Recursos Usados por Pods

```bash
# Ver requests e limits dos pods em um node
kubectl describe node k8s-worker-1 | grep -A 20 "Non-terminated Pods:"

# Ver uso real de recursos dos pods
kubectl top pods --all-namespaces --field-selector spec.nodeName=k8s-worker-1
```

## 8. Eventos do Node

### Ver Eventos

```bash
# Ver eventos de um node
kubectl get events --field-selector involvedObject.name=k8s-worker-1

# Ver eventos recentes
kubectl get events --field-selector involvedObject.name=k8s-worker-1 --sort-by='.lastTimestamp'

# Ver apenas últimos 10 eventos
kubectl get events --field-selector involvedObject.name=k8s-worker-1 --sort-by='.lastTimestamp' | tail -10

# Ver eventos de todos os nodes
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep Node

# Ver eventos de warning
kubectl get events --field-selector type=Warning
```

## 9. Informações do Sistema

### System Info

```bash
# Ver informações do sistema
kubectl get node k8s-worker-1 -o json | jq '.status.nodeInfo'

# Saída:
# {
#   "architecture": "amd64",
#   "bootID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "containerRuntimeVersion": "containerd://1.7.8",
#   "kernelVersion": "5.15.0-91-generic",
#   "kubeProxyVersion": "v1.28.0",
#   "kubeletVersion": "v1.28.0",
#   "machineID": "ec2xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
#   "operatingSystem": "linux",
#   "osImage": "Ubuntu 22.04.3 LTS",
#   "systemUUID": "ec2xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
# }

# Ver versões de todos os nodes
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
KUBELET:.status.nodeInfo.kubeletVersion,\
KUBE-PROXY:.status.nodeInfo.kubeProxyVersion,\
CONTAINER-RUNTIME:.status.nodeInfo.containerRuntimeVersion

# Ver sistema operacional
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
OS:.status.nodeInfo.osImage,\
KERNEL:.status.nodeInfo.kernelVersion,\
ARCH:.status.nodeInfo.architecture
```

## 10. Scripts Úteis

### Script: Resumo Completo dos Nodes

```bash
#!/bin/bash
# node-summary.sh - Resumo completo dos nodes

echo "=== KUBERNETES NODES SUMMARY ==="
echo ""

# Total de nodes
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
READY_NODES=$(kubectl get nodes --no-headers | grep -c " Ready ")
echo "Total Nodes: $TOTAL_NODES"
echo "Ready Nodes: $READY_NODES"
echo ""

# Informações por node
kubectl get nodes -o json | jq -r '.items[] | .metadata.name' | while read node; do
    echo "=== Node: $node ==="
    
    # Status
    STATUS=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    echo "Status: $STATUS"
    
    # Recursos
    CPU_CAPACITY=$(kubectl get node $node -o jsonpath='{.status.capacity.cpu}')
    MEMORY_CAPACITY=$(kubectl get node $node -o jsonpath='{.status.capacity.memory}')
    PODS_CAPACITY=$(kubectl get node $node -o jsonpath='{.status.capacity.pods}')
    
    echo "Capacity: CPU=$CPU_CAPACITY, Memory=$MEMORY_CAPACITY, Pods=$PODS_CAPACITY"
    
    # Pods
    POD_COUNT=$(kubectl get pods --all-namespaces --field-selector spec.nodeName=$node --no-headers 2>/dev/null | wc -l)
    echo "Running Pods: $POD_COUNT"
    
    # Sistema
    OS=$(kubectl get node $node -o jsonpath='{.status.nodeInfo.osImage}')
    KERNEL=$(kubectl get node $node -o jsonpath='{.status.nodeInfo.kernelVersion}')
    RUNTIME=$(kubectl get node $node -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}')
    
    echo "OS: $OS"
    echo "Kernel: $KERNEL"
    echo "Runtime: $RUNTIME"
    echo ""
done
```

### Script: Monitorar Recursos dos Nodes

```bash
#!/bin/bash
# node-monitor.sh - Monitorar recursos em tempo real

watch -n 5 'kubectl top nodes && echo "" && kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,PODS:.status.capacity.pods'
```

### Script: Verificar Saúde dos Nodes

```bash
#!/bin/bash
# node-health-check.sh - Verificar saúde dos nodes

echo "=== NODE HEALTH CHECK ==="
echo ""

kubectl get nodes -o json | jq -r '.items[] | .metadata.name' | while read node; do
    echo "Checking $node..."
    
    # Verificar condições
    READY=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    MEMORY_PRESSURE=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="MemoryPressure")].status}')
    DISK_PRESSURE=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="DiskPressure")].status}')
    PID_PRESSURE=$(kubectl get node $node -o jsonpath='{.status.conditions[?(@.type=="PIDPressure")].status}')
    
    if [ "$READY" == "True" ] && [ "$MEMORY_PRESSURE" == "False" ] && [ "$DISK_PRESSURE" == "False" ] && [ "$PID_PRESSURE" == "False" ]; then
        echo "✅ $node is healthy"
    else
        echo "❌ $node has issues:"
        [ "$READY" != "True" ] && echo "  - Not Ready"
        [ "$MEMORY_PRESSURE" == "True" ] && echo "  - Memory Pressure"
        [ "$DISK_PRESSURE" == "True" ] && echo "  - Disk Pressure"
        [ "$PID_PRESSURE" == "True" ] && echo "  - PID Pressure"
    fi
    echo ""
done
```

## 11. Ferramentas Externas

### k9s (Terminal UI)

```bash
# Instalar k9s
wget https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/

# Executar
k9s

# Navegar para nodes: digite :nodes
# Teclas úteis:
# d - describe
# y - yaml
# l - logs
# ? - ajuda
```

### kubectl-node-shell

```bash
# Instalar plugin
curl -LO https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell
chmod +x kubectl-node_shell
sudo mv kubectl-node_shell /usr/local/bin/kubectl-node_shell

# Usar
kubectl node-shell k8s-worker-1

# Agora você está em um shell no node
```

## Resumo de Comandos

```bash
# Básico
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node <node-name>

# Recursos
kubectl top nodes
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory

# Condições
kubectl get node <node-name> -o json | jq '.status.conditions'

# Labels
kubectl get nodes --show-labels
kubectl label node <node-name> key=value

# Pods no node
kubectl get pods --all-namespaces --field-selector spec.nodeName=<node-name>

# Eventos
kubectl get events --field-selector involvedObject.name=<node-name>

# System Info
kubectl get node <node-name> -o json | jq '.status.nodeInfo'
```

Agora você tem visibilidade completa dos seus nodes! 🚀
