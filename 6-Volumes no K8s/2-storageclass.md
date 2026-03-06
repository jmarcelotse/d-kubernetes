# StorageClass no Kubernetes

StorageClass é um recurso que permite o provisionamento dinâmico de volumes persistentes, eliminando a necessidade de criar PVs manualmente.

## O que é StorageClass?

**StorageClass** define "classes" de armazenamento com diferentes características (performance, backup, replicação) e permite que PVs sejam criados automaticamente quando um PVC é solicitado.

## Problema: Provisionamento Manual

### Sem StorageClass (Manual)

```
1. Admin cria PersistentVolume (PV) manualmente
   └─> Define storage físico (NFS, EBS, etc)

2. Desenvolvedor cria PersistentVolumeClaim (PVC)
   └─> Espera encontrar PV compatível

3. Kubernetes faz bind PVC → PV
   └─> Se não houver PV disponível, PVC fica Pending

❌ Problemas:
   - Admin precisa criar PVs antecipadamente
   - Desperdício de storage (PVs não utilizados)
   - Não escala bem
```

### Com StorageClass (Dinâmico)

```
1. Admin cria StorageClass
   └─> Define provisioner e parâmetros

2. Desenvolvedor cria PVC referenciando StorageClass
   └─> PVC solicita storage dinamicamente

3. Kubernetes cria PV automaticamente
   └─> Provisioner cria storage real (EBS, NFS, etc)

4. Kubernetes faz bind PVC → PV
   └─> Tudo automático!

✅ Vantagens:
   - Provisionamento sob demanda
   - Sem desperdício
   - Escala automaticamente
```

## Arquitetura

```
┌─────────────────────────────────────────────────┐
│                    Pod                          │
│  ┌──────────────────────────────────────────┐  │
│  │         Container                        │  │
│  │  volumeMount: /data                      │  │
│  └──────────────┬───────────────────────────┘  │
└─────────────────┼───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│     PVC (Persistent Volume Claim)               │
│     storageClassName: fast-ssd                  │
│     storage: 10Gi                               │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│     StorageClass: fast-ssd                      │
│     provisioner: kubernetes.io/aws-ebs          │
│     parameters:                                 │
│       type: gp3                                 │
│       iops: 3000                                │
└─────────────────┬───────────────────────────────┘
                  │
                  │ (Provisioner cria automaticamente)
                  │
┌─────────────────▼───────────────────────────────┐
│     PV (Persistent Volume)                      │
│     - Criado automaticamente                    │
│     - EBS volume na AWS                         │
└─────────────────────────────────────────────────┘
```

## Componentes do StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### Campos Principais

| Campo | Descrição | Valores |
|-------|-----------|---------|
| **provisioner** | Plugin que cria o volume | aws-ebs, gce-pd, nfs, local-path |
| **parameters** | Parâmetros específicos do provisioner | type, iops, replication |
| **reclaimPolicy** | O que fazer quando PVC é deletado | Delete, Retain |
| **allowVolumeExpansion** | Permite expandir volume | true, false |
| **volumeBindingMode** | Quando fazer bind | Immediate, WaitForFirstConsumer |

## Provisioners Comuns

### 1. Local Path (Desenvolvimento)

```yaml
# storageclass-local.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

**Características:**
- ✅ Simples para desenvolvimento
- ✅ Não requer infraestrutura externa
- ❌ Não é dinâmico (precisa criar PV manualmente)
- ❌ Dados ficam no node

### 2. HostPath (Rancher Local Path Provisioner)

```bash
# Instalar Local Path Provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Verificar
kubectl get storageclass

# Saída:
# NAME         PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# local-path   rancher.io/local-path   Delete          WaitForFirstConsumer
```

**Exemplo de uso:**

```yaml
# pvc-local-path.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: app-local
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
      claimName: local-pvc
```

```bash
# Criar
kubectl apply -f pvc-local-path.yaml

# Ver PVC (aguardar ficar Bound)
kubectl get pvc local-pvc

# Ver PV criado automaticamente
kubectl get pv

# Criar arquivo
kubectl exec app-local -- sh -c 'echo "<h1>Dynamic Storage!</h1>" > /usr/share/nginx/html/index.html'

# Testar
kubectl exec app-local -- cat /usr/share/nginx/html/index.html

# Ver onde o volume foi criado no node
kubectl get pv -o yaml | grep path
```

### 3. NFS (Storage Compartilhado)

```yaml
# storageclass-nfs.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exports/kubernetes
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

**Instalar NFS CSI Driver:**

```bash
# Adicionar repo Helm
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update

# Instalar driver
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --set kubeletDir=/var/lib/kubelet

# Verificar
kubectl get pods -n kube-system | grep nfs
```

### 4. AWS EBS (Produção na AWS)

```yaml
# storageclass-aws-ebs.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**Tipos de EBS:**

| Tipo | Descrição | IOPS | Throughput | Uso |
|------|-----------|------|------------|-----|
| **gp3** | SSD de propósito geral | 3000-16000 | 125-1000 MB/s | Geral |
| **gp2** | SSD de propósito geral (antigo) | 100-16000 | - | Legado |
| **io2** | SSD de alta performance | 100-64000 | 1000 MB/s | Bancos de dados |
| **st1** | HDD otimizado para throughput | - | 500 MB/s | Big data |
| **sc1** | HDD cold storage | - | 250 MB/s | Arquivos |

### 5. GCP Persistent Disk

```yaml
# storageclass-gcp-pd.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 6. Azure Disk

```yaml
# storageclass-azure-disk.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium
provisioner: disk.csi.azure.com
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

## Reclaim Policy

Define o que acontece com o PV quando o PVC é deletado.

### Delete (Padrão)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: auto-delete
provisioner: rancher.io/local-path
reclaimPolicy: Delete
```

```
1. PVC é deletado
   └─> PV é deletado automaticamente
   └─> Storage físico é deletado
   └─> ❌ Dados são perdidos permanentemente
```

### Retain

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: keep-data
provisioner: rancher.io/local-path
reclaimPolicy: Retain
```

```
1. PVC é deletado
   └─> PV fica em estado "Released"
   └─> Storage físico é mantido
   └─> ✅ Dados são preservados
   └─> Admin pode recuperar dados manualmente
```

**Exemplo Prático:**

```yaml
# storageclass-retain.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: retain-storage
provisioner: rancher.io/local-path
reclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: important-data
spec:
  storageClassName: retain-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: data-writer
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'echo "Important data!" > /data/important.txt && sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: important-data
```

```bash
# Criar
kubectl apply -f storageclass-retain.yaml

# Verificar dados
kubectl exec data-writer -- cat /data/important.txt

# Obter nome do PV
PV_NAME=$(kubectl get pvc important-data -o jsonpath='{.spec.volumeName}')
echo "PV Name: $PV_NAME"

# Deletar PVC
kubectl delete pvc important-data

# Ver PV (ainda existe, status Released)
kubectl get pv $PV_NAME

# Saída:
# NAME                                       CAPACITY   STATUS     CLAIM
# pvc-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     1Gi        Released   default/important-data

# Dados ainda existem no node!
```

## Volume Binding Mode

### Immediate (Padrão)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: immediate-binding
provisioner: rancher.io/local-path
volumeBindingMode: Immediate
```

```
1. PVC é criado
   └─> PV é criado imediatamente
   └─> Bind acontece imediatamente
   └─> ⚠️ Pod pode não conseguir agendar no node correto
```

### WaitForFirstConsumer (Recomendado)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wait-for-pod
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
```

```
1. PVC é criado
   └─> PVC fica Pending

2. Pod é criado usando o PVC
   └─> Scheduler escolhe node para o pod

3. PV é criado no node escolhido
   └─> Bind acontece
   └─> ✅ Garante que volume está no node correto
```

## Allow Volume Expansion

Permite expandir o tamanho do volume sem recriar.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable
provisioner: rancher.io/local-path
allowVolumeExpansion: true
```

**Exemplo de Expansão:**

```yaml
# pvc-expandable.yaml
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
kubectl apply -f pvc-expandable.yaml

# Ver tamanho atual
kubectl get pvc expandable-pvc

# Expandir para 2Gi
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Verificar expansão
kubectl get pvc expandable-pvc

# Saída:
# NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES
# expandable-pvc    Bound    pvc-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     2Gi        RWO
```

## StorageClass Padrão

Define qual StorageClass usar quando PVC não especifica.

```bash
# Ver StorageClass padrão
kubectl get storageclass

# Saída:
# NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer

# Definir como padrão
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Remover padrão
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

**PVC sem storageClassName usa o padrão:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: default-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # storageClassName não especificado = usa padrão
```

## Exemplo Completo: Múltiplas Classes

```yaml
# multiple-storageclasses.yaml
# StorageClass para desenvolvimento (rápido, sem backup)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: dev-storage
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
# StorageClass para produção (retém dados)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prod-storage
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
# PVC para desenvolvimento
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dev-pvc
spec:
  storageClassName: dev-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
---
# PVC para produção
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prod-pvc
spec:
  storageClassName: prod-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
# Pod de desenvolvimento
apiVersion: v1
kind: Pod
metadata:
  name: dev-app
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: dev-pvc
---
# Pod de produção
apiVersion: v1
kind: Pod
metadata:
  name: prod-app
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: prod-pvc
```

```bash
# Criar
kubectl apply -f multiple-storageclasses.yaml

# Ver StorageClasses
kubectl get storageclass

# Ver PVCs
kubectl get pvc

# Ver PVs criados automaticamente
kubectl get pv

# Testar dev
kubectl exec dev-app -- sh -c 'echo "Dev data" > /data/test.txt'

# Testar prod
kubectl exec prod-app -- sh -c 'echo "Prod data" > /data/test.txt'

# Deletar PVC dev (dados são deletados)
kubectl delete pvc dev-pvc

# Deletar PVC prod (dados são retidos)
kubectl delete pvc prod-pvc

# Ver PVs
kubectl get pv
# PV de prod ainda existe com status Released
```

## Comandos Úteis

```bash
# Listar StorageClasses
kubectl get storageclass
kubectl get sc

# Ver detalhes
kubectl describe storageclass local-path

# Ver em YAML
kubectl get storageclass local-path -o yaml

# Criar StorageClass
kubectl apply -f storageclass.yaml

# Deletar StorageClass
kubectl delete storageclass local-path

# Ver PVCs usando uma StorageClass
kubectl get pvc --all-namespaces -o json | jq -r '.items[] | select(.spec.storageClassName=="local-path") | .metadata.name'

# Ver uso de storage por namespace
kubectl get pvc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STORAGECLASS:.spec.storageClassName,CAPACITY:.status.capacity.storage
```

## Resumo

**StorageClass permite:**
- ✅ Provisionamento dinâmico de volumes
- ✅ Diferentes classes de storage (dev, prod, fast, slow)
- ✅ Políticas de retenção (Delete, Retain)
- ✅ Expansão de volumes
- ✅ Controle de quando fazer bind

**Componentes principais:**
- **provisioner**: Plugin que cria o volume
- **parameters**: Configurações específicas
- **reclaimPolicy**: Delete ou Retain
- **volumeBindingMode**: Immediate ou WaitForFirstConsumer
- **allowVolumeExpansion**: Permite expandir

**Próximos tópicos:**
- StatefulSets com volumes dinâmicos
- Backup e restore de volumes
- Performance e otimização de storage
