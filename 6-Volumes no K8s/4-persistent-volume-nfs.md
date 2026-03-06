# PersistentVolume com NFS

Este guia mostra como configurar e usar PersistentVolumes com NFS (Network File System) no Kubernetes, permitindo compartilhamento de dados entre múltiplos pods e nodes.

## Por que NFS?

### Vantagens do NFS

```
┌─────────────────────────────────────────────────┐
│         Cluster Kubernetes                      │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │ Worker 1 │  │ Worker 2 │  │ Worker 3 │     │
│  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │     │
│  │ │Pod A │ │  │ │Pod B │ │  │ │Pod C │ │     │
│  │ └───┬──┘ │  │ └───┬──┘ │  │ └───┬──┘ │     │
│  └─────┼────┘  └─────┼────┘  └─────┼────┘     │
│        │             │             │            │
│        └─────────────┼─────────────┘            │
│                      │                          │
│              ┌───────▼────────┐                 │
│              │  NFS Server    │                 │
│              │  /exports/data │                 │
│              └────────────────┘                 │
│                                                  │
│  ✅ Todos os pods acessam os mesmos dados      │
│  ✅ ReadWriteMany (RWX) suportado              │
│  ✅ Dados centralizados                         │
│                                                  │
└─────────────────────────────────────────────────┘
```

**Vantagens:**
- ✅ **ReadWriteMany (RWX)**: Múltiplos pods em diferentes nodes podem ler e escrever
- ✅ **Compartilhamento**: Dados compartilhados entre aplicações
- ✅ **Centralizado**: Backup e gerenciamento simplificados
- ✅ **Escalável**: Adicionar mais clientes facilmente

**Desvantagens:**
- ⚠️ **Performance**: Mais lento que storage local
- ⚠️ **Rede**: Depende da latência de rede
- ⚠️ **Single Point of Failure**: Se NFS cair, todos perdem acesso

## Arquitetura NFS + Kubernetes

```
┌─────────────────────────────────────────────────────────┐
│                  Fluxo Completo                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. Pod solicita volume via PVC                         │
│     └─> PVC: storageClassName: nfs                      │
│                                                          │
│  2. PVC faz bind com PV                                 │
│     └─> PV: nfs.server + nfs.path                       │
│                                                          │
│  3. Kubelet monta NFS no pod                            │
│     └─> mount -t nfs server:/path /mnt/volume           │
│                                                          │
│  4. Container acessa dados via mountPath                │
│     └─> /data → NFS:/exports/data                       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Opção 1: Servidor NFS Externo

### Configurar Servidor NFS (Ubuntu/Debian)

```bash
# No servidor NFS (pode ser uma VM ou servidor físico)

# Instalar NFS server
sudo apt-get update
sudo apt-get install -y nfs-kernel-server

# Criar diretório para exportar
sudo mkdir -p /exports/kubernetes
sudo chown nobody:nogroup /exports/kubernetes
sudo chmod 777 /exports/kubernetes

# Configurar exports
cat <<EOF | sudo tee /etc/exports
/exports/kubernetes *(rw,sync,no_subtree_check,no_root_squash)
EOF

# Aplicar configuração
sudo exportfs -ra

# Reiniciar serviço
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# Verificar exports
sudo exportfs -v

# Saída:
# /exports/kubernetes
#         <world>(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,no_root_squash,no_all_squash)

# Ver status
sudo systemctl status nfs-kernel-server

# Permitir no firewall (se necessário)
sudo ufw allow from 10.0.0.0/8 to any port nfs
```

### Testar NFS nos Nodes

```bash
# Em cada worker node do Kubernetes

# Instalar cliente NFS
sudo apt-get update
sudo apt-get install -y nfs-common

# Testar montagem manual
sudo mkdir -p /mnt/test-nfs
sudo mount -t nfs <NFS-SERVER-IP>:/exports/kubernetes /mnt/test-nfs

# Criar arquivo de teste
echo "NFS works!" | sudo tee /mnt/test-nfs/test.txt

# Verificar
cat /mnt/test-nfs/test.txt

# Desmontar
sudo umount /mnt/test-nfs
```

### Criar PV e PVC com NFS Externo

```yaml
# nfs-external-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 192.168.1.100  # IP do servidor NFS
    path: /exports/kubernetes
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  storageClassName: nfs
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

```bash
# Criar PV e PVC
kubectl apply -f nfs-external-pv.yaml

# Verificar
kubectl get pv,pvc

# Saída:
# NAME                      CAPACITY   ACCESS MODES   STATUS   CLAIM
# persistentvolume/nfs-pv   10Gi       RWX            Bound    default/nfs-pvc
#
# NAME                            STATUS   VOLUME   CAPACITY   ACCESS MODES
# persistentvolumeclaim/nfs-pvc   Bound    nfs-pv   10Gi       RWX
```

### Usar NFS em Pods

```yaml
# pods-using-nfs.yaml
# Pod 1 - Escreve dados
apiVersion: v1
kind: Pod
metadata:
  name: nfs-writer
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'while true; do echo "$(date) - Writer" >> /data/log.txt; sleep 5; done']
    volumeMounts:
    - name: nfs-storage
      mountPath: /data
  volumes:
  - name: nfs-storage
    persistentVolumeClaim:
      claimName: nfs-pvc
---
# Pod 2 - Lê dados
apiVersion: v1
kind: Pod
metadata:
  name: nfs-reader
spec:
  containers:
  - name: reader
    image: busybox
    command: ['sh', '-c', 'tail -f /data/log.txt']
    volumeMounts:
    - name: nfs-storage
      mountPath: /data
  volumes:
  - name: nfs-storage
    persistentVolumeClaim:
      claimName: nfs-pvc
---
# Pod 3 - Também lê dados (em outro node)
apiVersion: v1
kind: Pod
metadata:
  name: nfs-reader-2
spec:
  containers:
  - name: reader
    image: busybox
    command: ['sh', '-c', 'tail -f /data/log.txt']
    volumeMounts:
    - name: nfs-storage
      mountPath: /data
  volumes:
  - name: nfs-storage
    persistentVolumeClaim:
      claimName: nfs-pvc
```

```bash
# Criar pods
kubectl apply -f pods-using-nfs.yaml

# Ver logs do writer
kubectl logs nfs-writer

# Ver logs dos readers (lendo do mesmo arquivo!)
kubectl logs nfs-reader
kubectl logs nfs-reader-2

# Verificar em qual node cada pod está
kubectl get pods -o wide

# Todos acessam o mesmo arquivo, mesmo em nodes diferentes!

# Acessar diretamente no servidor NFS
# ssh para o servidor NFS
cat /exports/kubernetes/log.txt
```

## Opção 2: Servidor NFS no Kubernetes

### Criar Servidor NFS como Pod

```yaml
# nfs-server-in-cluster.yaml
# Deployment do servidor NFS
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-server
  template:
    metadata:
      labels:
        app: nfs-server
    spec:
      containers:
      - name: nfs-server
        image: itsthenetwork/nfs-server-alpine:latest
        ports:
        - containerPort: 2049
          name: nfs
        - containerPort: 111
          name: rpcbind
        securityContext:
          privileged: true
        env:
        - name: SHARED_DIRECTORY
          value: /exports
        volumeMounts:
        - name: nfs-storage
          mountPath: /exports
      volumes:
      - name: nfs-storage
        hostPath:
          path: /mnt/nfs-data
          type: DirectoryOrCreate
---
# Service para o servidor NFS
apiVersion: v1
kind: Service
metadata:
  name: nfs-service
spec:
  selector:
    app: nfs-server
  ports:
  - name: nfs
    port: 2049
    targetPort: 2049
  - name: rpcbind
    port: 111
    targetPort: 111
  clusterIP: 10.96.100.100  # IP fixo para facilitar
```

```bash
# Criar servidor NFS
kubectl apply -f nfs-server-in-cluster.yaml

# Aguardar pod ficar pronto
kubectl wait --for=condition=ready pod -l app=nfs-server --timeout=60s

# Ver IP do service
kubectl get svc nfs-service

# Testar do próprio cluster
kubectl run -it --rm test-nfs --image=busybox --restart=Never -- sh

# Dentro do pod de teste:
mkdir /mnt/test
mount -t nfs 10.96.100.100:/ /mnt/test
echo "Test" > /mnt/test/file.txt
cat /mnt/test/file.txt
umount /mnt/test
exit
```

### Criar PV usando NFS no Cluster

```yaml
# nfs-cluster-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-cluster-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-cluster
  nfs:
    server: 10.96.100.100  # IP do service NFS
    path: /
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-cluster-pvc
spec:
  storageClassName: nfs-cluster
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
```

```bash
# Criar
kubectl apply -f nfs-cluster-pv.yaml

# Verificar
kubectl get pv,pvc
```

## Opção 3: NFS Provisioner Dinâmico

### Instalar NFS Subdir External Provisioner

```bash
# Adicionar repo Helm
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update

# Instalar provisioner
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.1.100 \
  --set nfs.path=/exports/kubernetes \
  --set storageClass.name=nfs-client \
  --set storageClass.defaultClass=false

# Verificar
kubectl get pods | grep nfs-provisioner
kubectl get storageclass nfs-client
```

### Usar Provisioner Dinâmico

```yaml
# nfs-dynamic-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-dynamic-pvc
spec:
  storageClassName: nfs-client
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: app-dynamic-nfs
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
      claimName: nfs-dynamic-pvc
```

```bash
# Criar
kubectl apply -f nfs-dynamic-pvc.yaml

# PV é criado automaticamente!
kubectl get pv,pvc

# Ver diretório criado no servidor NFS
# ls -l /exports/kubernetes/
# Saída: default-nfs-dynamic-pvc-pvc-xxxxx/
```

## Exemplo Completo: Aplicação Web com NFS

```yaml
# webapp-with-nfs.yaml
# PV e PVC
apiVersion: v1
kind: PersistentVolume
metadata:
  name: webapp-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 192.168.1.100
    path: /exports/kubernetes/webapp
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-pvc
spec:
  storageClassName: nfs
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 2Gi
---
# Deployment com 3 réplicas
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: shared-storage
          mountPath: /usr/share/nginx/html
      volumes:
      - name: shared-storage
        persistentVolumeClaim:
          claimName: webapp-pvc
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
```

```bash
# Criar
kubectl apply -f webapp-with-nfs.yaml

# Criar conteúdo HTML
kubectl exec -it deployment/webapp -- sh -c 'echo "<h1>Shared NFS Storage</h1><p>Pod: $(hostname)</p>" > /usr/share/nginx/html/index.html'

# Testar
kubectl port-forward service/webapp-service 8080:80

# Acessar http://localhost:8080
# Todos os pods servem o mesmo conteúdo!

# Atualizar conteúdo
kubectl exec -it deployment/webapp -- sh -c 'echo "<h1>Updated Content</h1>" > /usr/share/nginx/html/index.html'

# Todos os pods veem a atualização imediatamente
```

## Múltiplos PVs no Mesmo Servidor NFS

```yaml
# multiple-nfs-pvs.yaml
# PV 1 - Desenvolvimento
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-dev-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  nfs:
    server: 192.168.1.100
    path: /exports/kubernetes/dev
---
# PV 2 - Produção
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-prod-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  nfs:
    server: 192.168.1.100
    path: /exports/kubernetes/prod
---
# PV 3 - Backup
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-backup-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  nfs:
    server: 192.168.1.100
    path: /exports/kubernetes/backup
```

## Performance e Otimização

### Opções de Montagem NFS

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-optimized-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  mountOptions:
    - nfsvers=4.1
    - rsize=1048576
    - wsize=1048576
    - hard
    - timeo=600
    - retrans=2
    - noresvport
  nfs:
    server: 192.168.1.100
    path: /exports/kubernetes
```

**Opções importantes:**

| Opção | Descrição | Recomendação |
|-------|-----------|--------------|
| `nfsvers=4.1` | Versão do protocolo NFS | Use 4.1 ou 4.2 |
| `rsize=1048576` | Tamanho de leitura (1MB) | Aumentar para melhor performance |
| `wsize=1048576` | Tamanho de escrita (1MB) | Aumentar para melhor performance |
| `hard` | Retry infinito em caso de falha | Recomendado para dados críticos |
| `soft` | Desiste após timeout | Use apenas para dados não críticos |
| `timeo=600` | Timeout em décimos de segundo | Ajustar conforme latência |

## Troubleshooting

### Pod fica em ContainerCreating

```bash
# Ver eventos
kubectl describe pod <pod-name>

# Erro comum:
# MountVolume.SetUp failed: mount failed: exit status 32
# Mounting command: mount
# Mounting arguments: -t nfs 192.168.1.100:/exports/kubernetes /var/lib/kubelet/pods/.../volumes/...
# Output: mount.nfs: Connection timed out

# Soluções:
# 1. Verificar se servidor NFS está acessível
ping 192.168.1.100

# 2. Testar montagem manual no node
ssh node
sudo mount -t nfs 192.168.1.100:/exports/kubernetes /mnt/test

# 3. Verificar firewall
sudo ufw status
sudo ufw allow from 10.0.0.0/8 to any port nfs

# 4. Verificar se nfs-common está instalado nos nodes
sudo apt-get install -y nfs-common
```

### Performance Lenta

```bash
# Testar performance de escrita
kubectl run -it --rm nfs-test --image=busybox --restart=Never -- sh

# Dentro do pod:
mount | grep nfs
dd if=/dev/zero of=/data/testfile bs=1M count=100
# Ver velocidade de escrita

# Ajustar mountOptions no PV
# Adicionar: rsize=1048576, wsize=1048576
```

### Dados não Sincronizam

```bash
# Verificar opções de montagem
kubectl get pv <pv-name> -o yaml | grep mountOptions

# Adicionar 'sync' nas mountOptions
mountOptions:
  - sync

# Ou no servidor NFS (/etc/exports)
/exports/kubernetes *(rw,sync,no_subtree_check)
```

## Comandos Úteis

```bash
# Ver PVs NFS
kubectl get pv -o custom-columns=NAME:.metadata.name,SERVER:.spec.nfs.server,PATH:.spec.nfs.path

# Ver pods usando NFS
kubectl get pods -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="nfs-pvc") | .metadata.name'

# Testar conectividade NFS de um pod
kubectl run -it --rm nfs-test --image=busybox --restart=Never -- sh
# mount -t nfs <server>:<path> /mnt/test

# Ver estatísticas NFS no servidor
nfsstat -s

# Ver clientes conectados
showmount -a
```

## Resumo

**NFS com Kubernetes:**
- ✅ ReadWriteMany (RWX) - múltiplos pods em diferentes nodes
- ✅ Compartilhamento de dados entre aplicações
- ✅ Centralização de storage
- ✅ Fácil backup e gerenciamento

**Opções de implementação:**
1. **Servidor NFS externo** - Mais estável, recomendado para produção
2. **Servidor NFS no cluster** - Bom para testes e desenvolvimento
3. **NFS Provisioner dinâmico** - Provisionamento automático de volumes

**Configuração essencial:**
- Instalar `nfs-common` em todos os nodes
- Configurar `/etc/exports` no servidor
- Usar `mountOptions` para otimizar performance
- Definir `persistentVolumeReclaimPolicy: Retain` para dados importantes

**Próximos tópicos:**
- StatefulSets com NFS
- Backup de volumes NFS
- Alta disponibilidade com NFS
