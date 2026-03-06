# PVC - PersistentVolumeClaim

PersistentVolumeClaim (PVC) é uma requisição de armazenamento feita por um usuário. É a forma como pods solicitam e consomem volumes persistentes no Kubernetes.

## O que é PersistentVolumeClaim?

**PersistentVolumeClaim (PVC)** é uma solicitação de storage que pode ser atendida por um PersistentVolume (PV) existente ou criado dinamicamente via StorageClass.

```
┌─────────────────────────────────────────────────┐
│         Analogia: Pedido de Disco               │
├─────────────────────────────────────────────────┤
│                                                  │
│  PVC = "Eu preciso de 10GB de storage"         │
│         ↓                                        │
│  Kubernetes procura PV disponível               │
│         ↓                                        │
│  PV = "Aqui está um disco de 10GB"             │
│         ↓                                        │
│  Bind: PVC ↔ PV                                 │
│         ↓                                        │
│  Pod usa o PVC                                  │
│                                                  │
└─────────────────────────────────────────────────┘
```

## PVC vs PV

```
┌──────────────────────────────────────────────────────┐
│              PVC (Claim)         PV (Volume)         │
├──────────────────────────────────────────────────────┤
│                                                       │
│  Desenvolvedor cria    ←→    Admin cria              │
│  "Preciso de 5GB"      ←→    "Aqui está 10GB"        │
│  Namespace-scoped      ←→    Cluster-scoped          │
│  Solicita storage      ←→    Fornece storage         │
│  Abstração lógica      ←→    Storage físico          │
│                                                       │
└──────────────────────────────────────────────────────┘
```

## Estrutura de um PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
  selector:
    matchLabels:
      type: ssd
```

### Campos Principais

| Campo | Descrição | Obrigatório |
|-------|-----------|-------------|
| **accessModes** | Modo de acesso desejado | Sim |
| **resources.requests.storage** | Quantidade de storage | Sim |
| **storageClassName** | Classe de storage | Não (usa default) |
| **selector** | Filtrar PVs por labels | Não |
| **volumeMode** | Filesystem ou Block | Não (default: Filesystem) |
| **volumeName** | Bind com PV específico | Não |

## Ciclo de Vida do PVC

```
┌─────────────────────────────────────────────────┐
│         Estados do PVC                          │
├─────────────────────────────────────────────────┤
│                                                  │
│  Pending → Bound → (em uso) → Released          │
│     ↓        ↓                                   │
│  (criado) (vinculado)                           │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Pending (Pendente)

```bash
kubectl get pvc

# NAME      STATUS    VOLUME   CAPACITY   ACCESS MODES
# my-pvc    Pending                       RWO
```

**Motivos:**
- Não há PV disponível compatível
- Aguardando provisionamento dinâmico
- StorageClass não existe
- Recursos insuficientes

### Bound (Vinculado)

```bash
kubectl get pvc

# NAME      STATUS   VOLUME     CAPACITY   ACCESS MODES
# my-pvc    Bound    pv-12345   10Gi       RWO
```

**Significa:**
- PVC encontrou PV compatível
- Bind foi realizado
- Pronto para ser usado por pod

## Exemplo Básico

```yaml
# pvc-basic.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: basic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-pvc
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /usr/share/nginx/html
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: basic-pvc
```

```bash
# Criar
kubectl apply -f pvc-basic.yaml

# Ver PVC
kubectl get pvc basic-pvc

# Ver detalhes
kubectl describe pvc basic-pvc

# Criar arquivo no volume
kubectl exec pod-with-pvc -- sh -c 'echo "<h1>Hello PVC</h1>" > /usr/share/nginx/html/index.html'

# Testar
kubectl exec pod-with-pvc -- cat /usr/share/nginx/html/index.html

# Deletar pod (dados persistem)
kubectl delete pod pod-with-pvc

# Recriar pod
kubectl apply -f pvc-basic.yaml

# Dados ainda existem!
kubectl exec pod-with-pvc -- cat /usr/share/nginx/html/index.html
```

## Access Modes no PVC

### ReadWriteOnce (RWO)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-rwo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

- Um único node pode montar para leitura/escrita
- Múltiplos pods no mesmo node podem usar
- **Uso:** Bancos de dados, aplicações single-instance

### ReadWriteMany (RWX)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-rwx
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

- Múltiplos nodes podem montar para leitura/escrita
- Requer storage que suporte (NFS, CephFS)
- **Uso:** Aplicações distribuídas, shared storage

### ReadOnlyMany (ROX)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-rox
spec:
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 2Gi
```

- Múltiplos nodes podem montar somente leitura
- **Uso:** Configurações compartilhadas, assets estáticos

## StorageClassName

### Usar StorageClass Específica

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-fast
spec:
  storageClassName: fast-ssd
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### Usar StorageClass Padrão

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-default
spec:
  # storageClassName não especificado = usa default
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

### Desabilitar Provisionamento Dinâmico

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-static
spec:
  storageClassName: ""  # String vazia = sem StorageClass
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

## Selector (Seletor)

Filtrar PVs específicos por labels.

```yaml
# PV com labels
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-ssd
  labels:
    type: ssd
    environment: production
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  hostPath:
    path: /mnt/ssd
---
# PVC com selector
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-prod-ssd
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  selector:
    matchLabels:
      type: ssd
      environment: production
```

```bash
# PVC só fará bind com PV que tenha os labels corretos
kubectl get pvc pvc-prod-ssd

# Se não houver PV compatível, fica Pending
```

### Selector com matchExpressions

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-advanced-selector
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  selector:
    matchExpressions:
    - key: type
      operator: In
      values:
      - ssd
      - nvme
    - key: environment
      operator: NotIn
      values:
      - development
```

## Volume Binding Mode

### Immediate (Padrão)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: immediate-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-immediate
spec:
  storageClassName: immediate-sc
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```
1. PVC é criado
   └─> Bind acontece imediatamente
   └─> PV é alocado antes do pod ser criado
   └─> ⚠️ Pod pode não conseguir agendar no node correto
```

### WaitForFirstConsumer (Recomendado)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wait-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-wait
spec:
  storageClassName: wait-sc
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```
1. PVC é criado
   └─> PVC fica Pending

2. Pod é criado usando o PVC
   └─> Scheduler escolhe node

3. Bind acontece no node escolhido
   └─> ✅ Garante que volume está no node correto
```

## Expandir PVC

```yaml
# StorageClass com expansão habilitada
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable
provisioner: rancher.io/local-path
allowVolumeExpansion: true
---
# PVC inicial
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
spec:
  storageClassName: expandable
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```bash
# Criar PVC
kubectl apply -f expandable-pvc.yaml

# Ver tamanho atual
kubectl get pvc expandable-pvc

# Expandir para 5Gi
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'

# Verificar expansão
kubectl get pvc expandable-pvc

# Saída:
# NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES
# expandable-pvc    Bound    pvc-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     5Gi        RWO

# Nota: Pode ser necessário reiniciar o pod para aplicar
```

## Múltiplos Pods Usando Mesmo PVC

### ReadWriteOnce (RWO) - Mesmo Node

```yaml
# pvc-rwo-multiple-pods.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-rwo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-a
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do echo "Pod A: $(date)" >> /data/log.txt; sleep 5; done']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: shared-rwo-pvc
  nodeSelector:
    kubernetes.io/hostname: k8s-worker-1  # Mesmo node
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-b
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'tail -f /data/log.txt']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: shared-rwo-pvc
  nodeSelector:
    kubernetes.io/hostname: k8s-worker-1  # Mesmo node
```

```bash
# Criar
kubectl apply -f pvc-rwo-multiple-pods.yaml

# Ver logs
kubectl logs pod-a
kubectl logs pod-b

# Ambos acessam o mesmo volume (mesmo node)
```

### ReadWriteMany (RWX) - Múltiplos Nodes

```yaml
# pvc-rwx-multiple-pods.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-rwx-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs  # Requer storage RWX (NFS, CephFS, etc)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-pod-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: multi-pod
  template:
    metadata:
      labels:
        app: multi-pod
    spec:
      containers:
      - name: app
        image: nginx
        volumeMounts:
        - name: shared-storage
          mountPath: /usr/share/nginx/html
      volumes:
      - name: shared-storage
        persistentVolumeClaim:
          claimName: shared-rwx-pvc
```

```bash
# Criar
kubectl apply -f pvc-rwx-multiple-pods.yaml

# Ver pods em diferentes nodes
kubectl get pods -o wide

# Criar conteúdo
kubectl exec deployment/multi-pod-app -- sh -c 'echo "<h1>Shared RWX</h1>" > /usr/share/nginx/html/index.html'

# Todos os pods veem o mesmo conteúdo
```

## PVC em Deployment

```yaml
# deployment-with-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 1  # RWO = apenas 1 réplica
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: app-pvc
```

## PVC em StatefulSet

```yaml
# statefulset-with-pvc.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
```

```bash
# Criar
kubectl apply -f statefulset-with-pvc.yaml

# Ver PVCs criados automaticamente
kubectl get pvc

# Saída:
# NAME        STATUS   VOLUME                                     CAPACITY
# www-web-0   Bound    pvc-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     1Gi
# www-web-1   Bound    pvc-yyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy     1Gi
# www-web-2   Bound    pvc-zzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz     1Gi

# Cada pod tem seu próprio PVC!
```

## Deletar PVC

### Comportamento Padrão

```bash
# Deletar PVC
kubectl delete pvc my-pvc

# O que acontece depende do reclaimPolicy do PV:
# - Delete: PV é deletado automaticamente
# - Retain: PV fica em estado Released
```

### PVC em Uso

```bash
# Tentar deletar PVC em uso
kubectl delete pvc my-pvc

# PVC fica em estado Terminating
kubectl get pvc

# NAME     STATUS        VOLUME   CAPACITY
# my-pvc   Terminating   pv-123   5Gi

# PVC só é deletado quando pod parar de usar
kubectl delete pod pod-using-pvc

# Agora PVC é deletado
```

### Forçar Deleção

```bash
# Remover finalizer
kubectl patch pvc my-pvc -p '{"metadata":{"finalizers":null}}'

# ⚠️ Cuidado: Pode causar perda de dados!
```

## Comandos Úteis

```bash
# Listar PVCs
kubectl get pvc
kubectl get persistentvolumeclaims

# Ver detalhes
kubectl describe pvc my-pvc

# Ver em YAML
kubectl get pvc my-pvc -o yaml

# Ver PVCs em todos os namespaces
kubectl get pvc --all-namespaces

# Ver PVCs por StorageClass
kubectl get pvc -o custom-columns=NAME:.metadata.name,STORAGECLASS:.spec.storageClassName,CAPACITY:.status.capacity.storage

# Ver PVCs e seus PVs
kubectl get pvc -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage

# Ver pods usando um PVC
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="my-pvc") | .metadata.name'

# Expandir PVC
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# Deletar PVC
kubectl delete pvc my-pvc

# Deletar todos os PVCs
kubectl delete pvc --all
```

## Troubleshooting

### PVC fica Pending

```bash
# Ver motivo
kubectl describe pvc my-pvc

# Eventos comuns:
# - no persistent volumes available
# - storageclass "xxx" not found
# - insufficient capacity

# Soluções:
# 1. Criar PV compatível
# 2. Verificar StorageClass existe
# 3. Aumentar capacidade do PV
```

### PVC não faz bind com PV

```bash
# Verificar compatibilidade
kubectl get pv,pvc

# Verificar:
# 1. StorageClassName é igual
# 2. AccessModes são compatíveis
# 3. Capacity do PV >= PVC
# 4. Selector (se usado) corresponde

# Ver detalhes
kubectl describe pv my-pv
kubectl describe pvc my-pvc
```

### Erro ao expandir PVC

```bash
# Verificar se StorageClass permite expansão
kubectl get storageclass -o custom-columns=NAME:.metadata.name,ALLOWEXPANSION:.allowVolumeExpansion

# Se não permitir, não é possível expandir
# Solução: Criar novo PVC maior e migrar dados
```

## Resumo

**PersistentVolumeClaim (PVC):**
- ✅ Requisição de storage por usuário
- ✅ Namespace-scoped
- ✅ Abstração sobre PV
- ✅ Usado por pods para acessar storage

**Campos principais:**
- **accessModes**: RWO, ROX, RWX, RWOP
- **resources.requests.storage**: Tamanho desejado
- **storageClassName**: Classe de storage
- **selector**: Filtrar PVs específicos

**Estados:**
- Pending → Bound → (em uso) → Terminating

**Uso:**
- Deployment: 1 PVC compartilhado (RWO) ou múltiplos pods (RWX)
- StatefulSet: 1 PVC por pod (volumeClaimTemplates)

**Próximos tópicos:**
- StatefulSets com PVC
- Volume Snapshots
- Backup e restore de PVCs
