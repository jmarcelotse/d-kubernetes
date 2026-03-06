# O que são Volumes no Kubernetes?

Volumes no Kubernetes são mecanismos para persistir dados além do ciclo de vida de um container, permitindo que dados sejam compartilhados entre containers e sobrevivam a reinicializações.

## Por que Volumes?

### Problema: Containers são Efêmeros

```
┌─────────────────────────────────────────┐
│         Container (Efêmero)             │
├─────────────────────────────────────────┤
│  Aplicação grava dados no filesystem    │
│  Container é reiniciado/recriado        │
│  ❌ Dados são PERDIDOS!                 │
└─────────────────────────────────────────┘
```

### Solução: Volumes

```
┌─────────────────────────────────────────┐
│         Container                        │
├─────────────────────────────────────────┤
│  Aplicação grava dados no Volume        │
│  Container é reiniciado/recriado        │
│  ✅ Dados PERSISTEM no Volume!          │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Volume (Persistente)            │
│  - Sobrevive ao ciclo de vida do pod    │
│  - Pode ser compartilhado               │
│  - Diferentes tipos de storage          │
└─────────────────────────────────────────┘
```

## Conceitos Fundamentais

### 1. Volume vs Filesystem do Container

```
Container sem Volume:
┌──────────────────┐
│   Container      │
│  ┌────────────┐  │
│  │ Filesystem │  │  ← Efêmero, perdido ao reiniciar
│  │  /app/data │  │
│  └────────────┘  │
└──────────────────┘

Container com Volume:
┌──────────────────┐
│   Container      │
│  ┌────────────┐  │
│  │ Filesystem │  │
│  │  /app/data ├──┼─→ Volume (Persistente)
│  └────────────┘  │
└──────────────────┘
```

### 2. Ciclo de Vida

| Tipo | Ciclo de Vida | Uso |
|------|---------------|-----|
| **Filesystem do Container** | Dura enquanto o container existe | Dados temporários |
| **Volume emptyDir** | Dura enquanto o pod existe | Compartilhar entre containers |
| **Volume hostPath** | Dura enquanto o node existe | Acesso ao filesystem do node |
| **Persistent Volume** | Independente do pod | Dados persistentes |

## Tipos de Volumes

### 1. emptyDir

Volume vazio criado quando o pod é criado, deletado quando o pod é removido.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-emptydir
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir: {}
```

**Características:**
- ✅ Compartilhar dados entre containers do mesmo pod
- ✅ Cache temporário
- ❌ Dados perdidos quando pod é deletado

**Exemplo Prático:**

```yaml
# pod-emptydir-example.yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'while true; do echo "$(date)" >> /data/log.txt; sleep 5; done']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  
  - name: reader
    image: busybox
    command: ['sh', '-c', 'tail -f /data/log.txt']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  
  volumes:
  - name: shared-data
    emptyDir: {}
```

```bash
# Criar pod
kubectl apply -f pod-emptydir-example.yaml

# Ver logs do writer
kubectl logs shared-volume -c writer

# Ver logs do reader (lendo do volume compartilhado)
kubectl logs shared-volume -c reader

# Verificar volume dentro do pod
kubectl exec shared-volume -c writer -- ls -l /data
kubectl exec shared-volume -c writer -- cat /data/log.txt

# Deletar pod (volume é perdido)
kubectl delete pod shared-volume
```

### 2. hostPath

Monta um diretório do filesystem do node no pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-hostpath
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: host-data
      mountPath: /data
  volumes:
  - name: host-data
    hostPath:
      path: /tmp/data
      type: DirectoryOrCreate
```

**Características:**
- ✅ Acesso direto ao filesystem do node
- ✅ Dados persistem mesmo após pod ser deletado
- ❌ Pod fica preso ao node específico
- ⚠️ Risco de segurança (acesso ao host)

**Tipos de hostPath:**

| Tipo | Descrição |
|------|-----------|
| `DirectoryOrCreate` | Cria diretório se não existir |
| `Directory` | Diretório deve existir |
| `FileOrCreate` | Cria arquivo se não existir |
| `File` | Arquivo deve existir |
| `Socket` | Socket Unix deve existir |
| `CharDevice` | Dispositivo de caractere |
| `BlockDevice` | Dispositivo de bloco |

**Exemplo Prático:**

```yaml
# pod-hostpath-example.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-test
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: host-logs
      mountPath: /var/log/nginx
  volumes:
  - name: host-logs
    hostPath:
      path: /tmp/nginx-logs
      type: DirectoryOrCreate
```

```bash
# Criar pod
kubectl apply -f pod-hostpath-example.yaml

# Gerar logs
kubectl exec hostpath-test -- curl localhost

# Ver logs no volume
kubectl exec hostpath-test -- ls -l /var/log/nginx

# Ver logs no node (SSH no node onde o pod está rodando)
NODE=$(kubectl get pod hostpath-test -o jsonpath='{.spec.nodeName}')
echo "Pod está no node: $NODE"

# No node
ls -l /tmp/nginx-logs/

# Deletar pod
kubectl delete pod hostpath-test

# Logs ainda existem no node
# ls -l /tmp/nginx-logs/
```

### 3. configMap

Monta um ConfigMap como volume.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.conf: |
    server {
      listen 80;
      server_name localhost;
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-configmap
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: config
    configMap:
      name: app-config
```

**Exemplo Prático:**

```yaml
# configmap-volume-example.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  index.html: |
    <html>
    <body>
      <h1>Hello from ConfigMap Volume!</h1>
    </body>
    </html>
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-configmap
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  volumes:
  - name: html
    configMap:
      name: nginx-config
```

```bash
# Criar
kubectl apply -f configmap-volume-example.yaml

# Testar
kubectl exec nginx-configmap -- cat /usr/share/nginx/html/index.html

# Port-forward e acessar
kubectl port-forward nginx-configmap 8080:80
curl http://localhost:8080

# Atualizar ConfigMap
kubectl edit configmap nginx-config
# (alterar conteúdo do index.html)

# Aguardar sincronização (pode levar até 1 minuto)
kubectl exec nginx-configmap -- cat /usr/share/nginx/html/index.html
```

### 4. secret

Monta um Secret como volume.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: admin
  password: secret123
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-secret
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /secrets/username && cat /secrets/password && sleep 3600']
    volumeMounts:
    - name: credentials
      mountPath: /secrets
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: db-credentials
```

**Exemplo Prático:**

```yaml
# secret-volume-example.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  api-key: "my-super-secret-key-12345"
  db-password: "postgres-password-xyz"
---
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secret
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "API Key: $(cat /secrets/api-key)" && echo "DB Pass: $(cat /secrets/db-password)" && sleep 3600']
    volumeMounts:
    - name: secret-volume
      mountPath: /secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: app-secret
```

```bash
# Criar
kubectl apply -f secret-volume-example.yaml

# Ver logs
kubectl logs app-with-secret

# Ver arquivos no volume
kubectl exec app-with-secret -- ls -l /secrets
kubectl exec app-with-secret -- cat /secrets/api-key

# Ver secret (base64 encoded)
kubectl get secret app-secret -o yaml

# Decodificar
kubectl get secret app-secret -o jsonpath='{.data.api-key}' | base64 -d
```

### 5. Persistent Volume (PV) e Persistent Volume Claim (PVC)

Abstração para storage persistente independente do pod.

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
│     - Requisição de storage                     │
│     - Define tamanho e modo de acesso           │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│     PV (Persistent Volume)                      │
│     - Storage real (NFS, EBS, etc)              │
│     - Provisionado pelo admin                   │
└─────────────────────────────────────────────────┘
```

**Exemplo Prático:**

```yaml
# pv-pvc-example.yaml
# Persistent Volume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-local
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /tmp/pv-data
    type: DirectoryOrCreate
---
# Persistent Volume Claim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
---
# Pod usando PVC
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
      claimName: pvc-app
```

```bash
# Criar
kubectl apply -f pv-pvc-example.yaml

# Ver PV
kubectl get pv

# Saída:
# NAME       CAPACITY   ACCESS MODES   STATUS   CLAIM             STORAGECLASS   AGE
# pv-local   1Gi        RWO            Bound    default/pvc-app                  10s

# Ver PVC
kubectl get pvc

# Saída:
# NAME      STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# pvc-app   Bound    pv-local   1Gi        RWO                           10s

# Criar arquivo no volume
kubectl exec pod-with-pvc -- sh -c 'echo "<h1>Persistent Data</h1>" > /usr/share/nginx/html/index.html'

# Deletar pod
kubectl delete pod pod-with-pvc

# Recriar pod
kubectl apply -f pv-pvc-example.yaml

# Dados ainda existem!
kubectl exec pod-with-pvc -- cat /usr/share/nginx/html/index.html
```

## Comparação de Tipos de Volumes

| Tipo | Persistência | Compartilhamento | Uso Comum |
|------|--------------|------------------|-----------|
| **emptyDir** | Enquanto pod existe | Entre containers do pod | Cache, dados temporários |
| **hostPath** | Enquanto node existe | Não recomendado | Logs, acesso ao host |
| **configMap** | Independente | Múltiplos pods | Configurações |
| **secret** | Independente | Múltiplos pods | Credenciais, certificados |
| **PV/PVC** | Independente | Depende do AccessMode | Bancos de dados, arquivos |

## Modos de Acesso (Access Modes)

| Modo | Abreviação | Descrição |
|------|------------|-----------|
| **ReadWriteOnce** | RWO | Leitura/escrita por um único node |
| **ReadOnlyMany** | ROX | Somente leitura por múltiplos nodes |
| **ReadWriteMany** | RWX | Leitura/escrita por múltiplos nodes |
| **ReadWriteOncePod** | RWOP | Leitura/escrita por um único pod |

## Fluxo de Uso de Volumes

### Fluxo 1: emptyDir (Dados Temporários)

```
1. Pod é criado
   └─> Volume emptyDir é criado vazio

2. Container escreve dados no volume
   └─> Dados ficam disponíveis para outros containers

3. Pod é deletado
   └─> Volume emptyDir é deletado
   └─> ❌ Dados são perdidos
```

### Fluxo 2: PV/PVC (Dados Persistentes)

```
1. Admin cria PersistentVolume (PV)
   └─> Define storage real (NFS, EBS, etc)

2. Usuário cria PersistentVolumeClaim (PVC)
   └─> Requisita storage com tamanho e modo de acesso

3. Kubernetes faz bind PVC → PV
   └─> PVC fica "Bound" ao PV

4. Pod usa PVC
   └─> Volume é montado no container

5. Container escreve dados
   └─> Dados são gravados no storage real

6. Pod é deletado
   └─> ✅ Dados persistem no PV

7. Novo pod usa mesmo PVC
   └─> ✅ Dados anteriores estão disponíveis
```

## Exemplo Completo: Aplicação com Banco de Dados

```yaml
# mysql-with-volume.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /tmp/mysql-data
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  containers:
  - name: mysql
    image: mysql:8.0
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: "rootpass"
    - name: MYSQL_DATABASE
      value: "mydb"
    ports:
    - containerPort: 3306
    volumeMounts:
    - name: mysql-storage
      mountPath: /var/lib/mysql
  volumes:
  - name: mysql-storage
    persistentVolumeClaim:
      claimName: mysql-pvc
```

```bash
# Criar
kubectl apply -f mysql-with-volume.yaml

# Aguardar pod ficar pronto
kubectl wait --for=condition=ready pod/mysql --timeout=60s

# Conectar e criar dados
kubectl exec -it mysql -- mysql -uroot -prootpass mydb

# No MySQL:
CREATE TABLE users (id INT, name VARCHAR(50));
INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob');
SELECT * FROM users;
exit

# Deletar pod
kubectl delete pod mysql

# Recriar pod
kubectl apply -f mysql-with-volume.yaml

# Aguardar
kubectl wait --for=condition=ready pod/mysql --timeout=60s

# Verificar dados persistiram
kubectl exec -it mysql -- mysql -uroot -prootpass mydb -e "SELECT * FROM users;"

# Saída:
# +------+-------+
# | id   | name  |
# +------+-------+
# |    1 | Alice |
# |    2 | Bob   |
# +------+-------+
```

## Resumo

**Volumes são essenciais para:**
- ✅ Persistir dados além do ciclo de vida do container
- ✅ Compartilhar dados entre containers
- ✅ Armazenar configurações e secrets
- ✅ Manter estado de aplicações (bancos de dados)

**Tipos principais:**
- **emptyDir**: Temporário, compartilhado no pod
- **hostPath**: Acesso ao filesystem do node
- **configMap/secret**: Configurações e credenciais
- **PV/PVC**: Storage persistente e portável

**Próximos tópicos:**
- Persistent Volumes em detalhes
- StorageClass e provisionamento dinâmico
- StatefulSets com volumes
- Backup e restore de volumes
