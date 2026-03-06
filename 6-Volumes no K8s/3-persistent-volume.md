# PV - PersistentVolume

PersistentVolume (PV) é um recurso de armazenamento no cluster Kubernetes que foi provisionado por um administrador ou dinamicamente via StorageClass.

## O que é PersistentVolume?

**PersistentVolume (PV)** é uma abstração de storage no cluster que representa um pedaço de armazenamento físico (disco, NFS, cloud storage, etc).

```
┌─────────────────────────────────────────────────┐
│         Camadas de Abstração                    │
├─────────────────────────────────────────────────┤
│                                                  │
│  Pod → PVC → PV → Storage Físico                │
│                                                  │
│  ┌────┐   ┌─────┐   ┌────┐   ┌──────────────┐ │
│  │Pod │ → │ PVC │ → │ PV │ → │ NFS/EBS/Disk │ │
│  └────┘   └─────┘   └────┘   └──────────────┘ │
│                                                  │
│  Usuário   Claim    Volume    Storage Real      │
│                                                  │
└─────────────────────────────────────────────────┘
```

## PV vs PVC

| Aspecto | PersistentVolume (PV) | PersistentVolumeClaim (PVC) |
|---------|----------------------|----------------------------|
| **O que é** | Recurso de storage no cluster | Requisição de storage |
| **Criado por** | Admin ou StorageClass | Desenvolvedor/Usuário |
| **Escopo** | Cluster-wide | Namespace |
| **Analogia** | Disco físico disponível | Pedido de disco |
| **Ciclo de vida** | Independente | Ligado ao namespace |

## Estrutura de um PV

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-example
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
```

### Campos Principais

| Campo | Descrição | Valores |
|-------|-----------|---------|
| **capacity.storage** | Tamanho do volume | 1Gi, 10Gi, 100Gi |
| **accessModes** | Modos de acesso | RWO, ROX, RWX, RWOP |
| **persistentVolumeReclaimPolicy** | Política de recuperação | Retain, Delete, Recycle |
| **storageClassName** | Classe de storage | manual, fast, slow |
| **hostPath/nfs/etc** | Tipo de storage | Vários tipos |

## Access Modes (Modos de Acesso)

### ReadWriteOnce (RWO)

```yaml
accessModes:
  - ReadWriteOnce
```

- ✅ Leitura e escrita por **um único node**
- ✅ Múltiplos pods no mesmo node podem usar
- ❌ Pods em nodes diferentes não podem usar simultaneamente
- **Uso:** Bancos de dados, aplicações single-instance

### ReadOnlyMany (ROX)

```yaml
accessModes:
  - ReadOnlyMany
```

- ✅ Somente leitura por **múltiplos nodes**
- ✅ Múltiplos pods em diferentes nodes podem ler
- ❌ Nenhum pod pode escrever
- **Uso:** Arquivos estáticos, configurações compartilhadas

### ReadWriteMany (RWX)

```yaml
accessModes:
  - ReadWriteMany
```

- ✅ Leitura e escrita por **múltiplos nodes**
- ✅ Múltiplos pods em diferentes nodes podem ler e escrever
- ⚠️ Requer storage que suporte (NFS, CephFS, GlusterFS)
- **Uso:** Aplicações distribuídas, shared storage

### ReadWriteOncePod (RWOP)

```yaml
accessModes:
  - ReadWriteOncePod
```

- ✅ Leitura e escrita por **um único pod**
- ❌ Apenas um pod pode usar, mesmo no mesmo node
- **Uso:** Garantir exclusividade de acesso

### Comparação Visual

```
RWO (ReadWriteOnce):
┌──────────┐
│  Node 1  │
│ ┌──────┐ │
│ │Pod A │ │ ✅ Pode usar
│ └──────┘ │
│ ┌──────┐ │
│ │Pod B │ │ ✅ Pode usar (mesmo node)
│ └──────┘ │
└──────────┘
┌──────────┐
│  Node 2  │
│ ┌──────┐ │
│ │Pod C │ │ ❌ Não pode usar (outro node)
│ └──────┘ │
└──────────┘

RWX (ReadWriteMany):
┌──────────┐
│  Node 1  │
│ ┌──────┐ │
│ │Pod A │ │ ✅ Pode usar
│ └──────┘ │
└──────────┘
┌──────────┐
│  Node 2  │
│ ┌──────┐ │
│ │Pod B │ │ ✅ Pode usar (outro node)
│ └──────┘ │
└──────────┘
```

## Reclaim Policy (Política de Recuperação)

Define o que acontece com o PV quando o PVC é deletado.

### Retain (Reter)

```yaml
persistentVolumeReclaimPolicy: Retain
```

```
1. PVC é deletado
   └─> PV muda para status "Released"
   └─> Dados permanecem no storage
   └─> PV não pode ser reutilizado automaticamente
   └─> Admin deve limpar manualmente

✅ Uso: Dados importantes, produção
```

### Delete (Deletar)

```yaml
persistentVolumeReclaimPolicy: Delete
```

```
1. PVC é deletado
   └─> PV é deletado automaticamente
   └─> Storage físico é deletado
   └─> Dados são perdidos permanentemente

⚠️ Uso: Dados temporários, desenvolvimento
```

### Recycle (Reciclado) - Deprecated

```yaml
persistentVolumeReclaimPolicy: Recycle
```

```
1. PVC é deletado
   └─> PV executa rm -rf no volume
   └─> PV fica disponível para novo PVC

❌ Deprecated: Não usar mais
```

## Tipos de PersistentVolume

### 1. hostPath (Local no Node)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-hostpath
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
    type: DirectoryOrCreate
```

**Características:**
- ✅ Simples para desenvolvimento
- ✅ Não requer infraestrutura externa
- ❌ Dados ficam no node específico
- ❌ Não funciona em clusters multi-node

**Exemplo Prático:**

```yaml
# pv-hostpath-example.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-local
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/pv-data
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-local
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-pv-local
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
      claimName: pvc-local
```

```bash
# Criar
kubectl apply -f pv-hostpath-example.yaml

# Ver PV
kubectl get pv

# Saída:
# NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
# pv-local   2Gi        RWO            Retain           Bound    default/pvc-local

# Ver PVC
kubectl get pvc

# Saída:
# NAME        STATUS   VOLUME     CAPACITY   ACCESS MODES
# pvc-local   Bound    pv-local   2Gi        RWO

# Criar arquivo
kubectl exec pod-pv-local -- sh -c 'echo "<h1>PV Data</h1>" > /usr/share/nginx/html/index.html'

# Ver arquivo
kubectl exec pod-pv-local -- cat /usr/share/nginx/html/index.html

# Deletar pod
kubectl delete pod pod-pv-local

# Recriar pod
kubectl apply -f pv-hostpath-example.yaml

# Dados ainda existem!
kubectl exec pod-pv-local -- cat /usr/share/nginx/html/index.html
```

### 2. NFS (Network File System)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: nfs-server.example.com
    path: /exports/data
```

**Características:**
- ✅ Compartilhado entre múltiplos nodes (RWX)
- ✅ Dados centralizados
- ✅ Bom para aplicações distribuídas
- ⚠️ Requer servidor NFS configurado

**Exemplo Completo com Servidor NFS:**

```yaml
# nfs-server.yaml (para teste)
apiVersion: v1
kind: Pod
metadata:
  name: nfs-server
  labels:
    app: nfs-server
spec:
  containers:
  - name: nfs-server
    image: itsthenetwork/nfs-server-alpine:latest
    ports:
    - containerPort: 2049
    securityContext:
      privileged: true
    env:
    - name: SHARED_DIRECTORY
      value: /exports
---
apiVersion: v1
kind: Service
metadata:
  name: nfs-service
spec:
  selector:
    app: nfs-server
  ports:
  - port: 2049
    targetPort: 2049
  clusterIP: 10.96.100.100
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-nfs
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.96.100.100
    path: /
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nfs
spec:
  storageClassName: nfs
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-nfs-1
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do echo "Pod 1: $(date)" >> /data/log.txt; sleep 5; done']
    volumeMounts:
    - name: nfs-storage
      mountPath: /data
  volumes:
  - name: nfs-storage
    persistentVolumeClaim:
      claimName: pvc-nfs
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-nfs-2
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'tail -f /data/log.txt']
    volumeMounts:
    - name: nfs-storage
      mountPath: /data
  volumes:
  - name: nfs-storage
    persistentVolumeClaim:
      claimName: pvc-nfs
```

```bash
# Criar tudo
kubectl apply -f nfs-server.yaml

# Aguardar NFS server
kubectl wait --for=condition=ready pod/nfs-server --timeout=60s

# Ver logs do pod-nfs-1 (escrevendo)
kubectl logs pod-nfs-1

# Ver logs do pod-nfs-2 (lendo do mesmo volume)
kubectl logs pod-nfs-2

# Ambos acessam o mesmo arquivo!
```

### 3. Local (Storage Local do Node)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-local-ssd
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/disks/ssd1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-worker-1
```

**Características:**
- ✅ Alta performance (SSD local)
- ✅ Melhor que hostPath (mais controle)
- ❌ Preso ao node específico
- ⚠️ Requer nodeAffinity

### 4. Cloud Storage (AWS EBS)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-aws-ebs
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: gp3
  awsElasticBlockStore:
    volumeID: vol-0123456789abcdef0
    fsType: ext4
```

**Características:**
- ✅ Gerenciado pela AWS
- ✅ Backup automático (snapshots)
- ✅ Alta disponibilidade
- ❌ Custo adicional
- ⚠️ Apenas RWO

## Estados do PersistentVolume

```
┌─────────────────────────────────────────────┐
│         Ciclo de Vida do PV                 │
├─────────────────────────────────────────────┤
│                                              │
│  Available → Bound → Released → Available   │
│      ↓          ↓         ↓          ↑      │
│   (criado)  (em uso)  (liberado)  (limpo)  │
│                                              │
└─────────────────────────────────────────────┘
```

### Available (Disponível)

```bash
kubectl get pv

# NAME       CAPACITY   STATUS      CLAIM
# pv-local   2Gi        Available   
```

- PV foi criado
- Não está vinculado a nenhum PVC
- Pronto para ser usado

### Bound (Vinculado)

```bash
kubectl get pv

# NAME       CAPACITY   STATUS   CLAIM
# pv-local   2Gi        Bound    default/pvc-local
```

- PV está vinculado a um PVC
- Em uso por um pod
- Não pode ser usado por outro PVC

### Released (Liberado)

```bash
kubectl get pv

# NAME       CAPACITY   STATUS     CLAIM
# pv-local   2Gi        Released   default/pvc-local
```

- PVC foi deletado
- PV ainda contém dados
- Não pode ser reutilizado automaticamente
- Admin deve limpar manualmente

### Failed (Falhou)

```bash
kubectl get pv

# NAME       CAPACITY   STATUS   CLAIM
# pv-local   2Gi        Failed   
```

- Erro ao recuperar o volume
- Storage não está acessível
- Requer intervenção manual

## Binding (Vinculação) PV ↔ PVC

### Critérios de Matching

Kubernetes vincula PVC a PV baseado em:

1. **StorageClassName** deve ser igual
2. **AccessModes** devem ser compatíveis
3. **Capacity** do PV deve ser >= PVC
4. **Selector** (se especificado) deve corresponder

### Exemplo de Binding

```yaml
# PV com 10Gi
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-10gi
  labels:
    type: fast
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  hostPath:
    path: /mnt/data
---
# PVC pedindo 5Gi
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-5gi
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      type: fast
```

```bash
# Criar
kubectl apply -f binding-example.yaml

# Ver binding
kubectl get pv,pvc

# Saída:
# NAME                      CAPACITY   STATUS   CLAIM
# persistentvolume/pv-10gi  10Gi       Bound    default/pvc-5gi
#
# NAME                           STATUS   VOLUME    CAPACITY
# persistentvolumeclaim/pvc-5gi  Bound    pv-10gi   10Gi

# PVC pediu 5Gi mas recebeu PV de 10Gi
# PVC usa apenas 5Gi, mas PV inteiro está reservado
```

## Selector (Seletor)

PVC pode usar selector para escolher PV específico.

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
  name: pvc-prod
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
kubectl get pv,pvc

# Se não houver PV com os labels, PVC fica Pending
```

## Expandir PersistentVolume

```yaml
# PV com allowVolumeExpansion
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable
provisioner: rancher.io/local-path
allowVolumeExpansion: true
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-expand
spec:
  storageClassName: expandable
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```bash
# Criar
kubectl apply -f expandable-pv.yaml

# Ver tamanho atual
kubectl get pvc pvc-expand

# Expandir para 2Gi
kubectl patch pvc pvc-expand -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Verificar expansão
kubectl get pvc pvc-expand

# Pode ser necessário reiniciar o pod para aplicar
```

## Comandos Úteis

```bash
# Listar PVs
kubectl get pv
kubectl get persistentvolumes

# Ver detalhes
kubectl describe pv pv-local

# Ver em YAML
kubectl get pv pv-local -o yaml

# Ver PVs por status
kubectl get pv --field-selector status.phase=Available
kubectl get pv --field-selector status.phase=Bound
kubectl get pv --field-selector status.phase=Released

# Ver capacidade total
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage

# Ver PVs e seus PVCs
kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CLAIM:.spec.claimRef.name

# Deletar PV
kubectl delete pv pv-local

# Limpar PV Released (tornar Available novamente)
kubectl patch pv pv-local -p '{"spec":{"claimRef": null}}'
```

## Troubleshooting

### PVC fica Pending

```bash
# Ver motivo
kubectl describe pvc pvc-name

# Possíveis causas:
# 1. Não há PV disponível com capacidade suficiente
# 2. StorageClassName não corresponde
# 3. AccessModes incompatíveis
# 4. Selector não encontra PV

# Solução: Criar PV compatível
```

### PV fica Released

```bash
# Ver PV
kubectl get pv pv-name

# STATUS: Released

# Limpar para reutilizar
kubectl patch pv pv-name -p '{"spec":{"claimRef": null}}'

# Ou deletar dados manualmente e recriar PV
```

### Dados não persistem

```bash
# Verificar reclaim policy
kubectl get pv pv-name -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'

# Se for Delete, mudar para Retain
kubectl patch pv pv-name -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

## Resumo

**PersistentVolume (PV):**
- ✅ Abstração de storage no cluster
- ✅ Criado por admin ou StorageClass
- ✅ Independente do ciclo de vida do pod
- ✅ Suporta vários tipos de storage

**Características principais:**
- **Capacity**: Tamanho do volume
- **AccessModes**: RWO, ROX, RWX, RWOP
- **ReclaimPolicy**: Retain, Delete
- **StorageClassName**: Classe de storage
- **Type**: hostPath, NFS, local, cloud

**Estados:**
- Available → Bound → Released → Available

**Próximos tópicos:**
- PVC (PersistentVolumeClaim) em detalhes
- StatefulSets com PV/PVC
- Volume Snapshots
- Backup e restore
