# Volume EmptyDir

## O que é EmptyDir?

EmptyDir é um tipo de volume **temporário** criado quando um Pod é atribuído a um nó e existe enquanto o Pod estiver em execução naquele nó.

### Características principais

- **Temporário**: Dados são perdidos quando o Pod é removido
- **Compartilhado**: Todos os containers do Pod podem acessar
- **Vazio inicialmente**: Começa vazio (daí o nome)
- **Local**: Armazenado no disco do nó (ou RAM se configurado)
- **Ciclo de vida**: Vinculado ao Pod, não ao container

## Quando usar?

- **Compartilhamento de dados** entre containers do mesmo Pod
- **Cache temporário** que pode ser recriado
- **Processamento de dados** temporários
- **Logs compartilhados** entre containers
- **Dados intermediários** que não precisam persistir

## Quando NÃO usar?

- Dados que precisam **persistir** após o Pod ser removido
- Dados que precisam ser **compartilhados entre Pods**
- Backups ou dados críticos
- Para esses casos, use PersistentVolume

---

## Sintaxe básica

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-emptydir
spec:
  volumes:
  - name: shared-data
    emptyDir: {}
  
  containers:
  - name: container-1
    image: nginx
    volumeMounts:
    - name: shared-data
      mountPath: /data
```

---

## Exemplo 1: Compartilhando dados entre containers

Dois containers compartilhando o mesmo volume para trocar arquivos.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-pod
  labels:
    app: data-sharing
spec:
  volumes:
  - name: shared-data
    emptyDir: {}

  containers:
  # Container que escreve dados
  - name: writer
    image: busybox
    command: ['sh', '-c', 'echo "Hello from writer" > /data/message.txt && sleep 3600']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  
  # Container que lê dados
  - name: reader
    image: busybox
    command: ['sh', '-c', 'sleep 10 && cat /data/message.txt && sleep 3600']
    volumeMounts:
    - name: shared-data
      mountPath: /data
```

**Como funciona:**
1. Volume `shared-data` é criado vazio
2. Container `writer` escreve arquivo em `/data/message.txt`
3. Container `reader` lê o mesmo arquivo de `/data/message.txt`
4. Ambos veem o mesmo conteúdo porque compartilham o volume

**Testar:**
```bash
# Criar o pod
kubectl apply -f shared-volume-pod.yaml

# Ver logs do reader (deve mostrar a mensagem)
kubectl logs shared-volume-pod -c reader

# Acessar o writer e criar mais arquivos
kubectl exec -it shared-volume-pod -c writer -- sh
echo "New data" > /data/newfile.txt
exit

# Verificar no reader
kubectl exec -it shared-volume-pod -c reader -- cat /data/newfile.txt
```

---

## Exemplo 2: Nginx com logs compartilhados

Container Nginx gerando logs e container sidecar processando esses logs.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-with-logs
  labels:
    app: webserver
spec:
  volumes:
  - name: nginx-logs
    emptyDir: {}

  containers:
  # Container principal - Nginx
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: nginx-logs
      mountPath: /var/log/nginx
  
  # Container sidecar - Log processor
  - name: log-processor
    image: busybox
    command: ['sh', '-c', 'tail -f /logs/access.log']
    volumeMounts:
    - name: nginx-logs
      mountPath: /logs
```

**Como funciona:**
1. Nginx escreve logs em `/var/log/nginx/access.log`
2. Sidecar lê logs de `/logs/access.log` (mesmo arquivo, caminho diferente)
3. Ambos acessam o mesmo volume `nginx-logs`

**Testar:**
```bash
# Criar o pod
kubectl apply -f nginx-with-logs.yaml

# Gerar tráfego no nginx
kubectl exec -it nginx-with-logs -c nginx -- curl localhost

# Ver logs processados pelo sidecar
kubectl logs nginx-with-logs -c log-processor
```

---

## Exemplo 3: Cache temporário

Aplicação usando EmptyDir como cache de dados.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-cache
spec:
  volumes:
  - name: cache-volume
    emptyDir: {}

  containers:
  - name: app
    image: myapp:v1
    volumeMounts:
    - name: cache-volume
      mountPath: /app/cache
    env:
    - name: CACHE_DIR
      value: "/app/cache"
```

---

## Exemplo 4: EmptyDir em memória (RAM)

Para dados que precisam de acesso muito rápido, pode-se usar RAM ao invés de disco.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-backed-pod
spec:
  volumes:
  - name: memory-cache
    emptyDir:
      medium: Memory
      sizeLimit: 128Mi

  containers:
  - name: app
    image: redis:alpine
    volumeMounts:
    - name: memory-cache
      mountPath: /data
```

**Importante:**
- `medium: Memory` armazena dados na RAM do nó
- `sizeLimit: 128Mi` limita o tamanho máximo
- Muito mais rápido que disco
- Conta contra o limite de memória do container
- Use apenas para dados temporários que precisam de alta performance

---

## Exemplo 5: Múltiplos volumes EmptyDir

Pod com vários volumes EmptyDir para diferentes propósitos.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-volume-pod
spec:
  volumes:
  - name: logs
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: temp
    emptyDir:
      medium: Memory
      sizeLimit: 64Mi

  containers:
  - name: app
    image: myapp:v1
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
    - name: cache
      mountPath: /app/cache
    - name: temp
      mountPath: /tmp/fast
```

---

## Exemplo 6: Processamento de dados temporários

Pipeline de processamento onde containers trabalham em sequência.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-pipeline
spec:
  volumes:
  - name: pipeline-data
    emptyDir: {}

  initContainers:
  # Init container baixa dados
  - name: downloader
    image: curlimages/curl
    command: ['sh', '-c', 'curl -o /data/input.json https://api.example.com/data']
    volumeMounts:
    - name: pipeline-data
      mountPath: /data

  containers:
  # Container processa dados
  - name: processor
    image: python:3.9-alpine
    command: ['sh', '-c', 'python /app/process.py /data/input.json > /data/output.json && sleep 3600']
    volumeMounts:
    - name: pipeline-data
      mountPath: /data
  
  # Container envia resultado
  - name: uploader
    image: curlimages/curl
    command: ['sh', '-c', 'sleep 30 && curl -X POST -d @/data/output.json https://api.example.com/result']
    volumeMounts:
    - name: pipeline-data
      mountPath: /data
```

---

## Opções de configuração

### medium

Define onde o volume será armazenado.

```yaml
emptyDir:
  medium: ""        # Padrão: disco do nó
  # ou
  medium: Memory    # RAM do nó
```

### sizeLimit

Limita o tamanho máximo do volume.

```yaml
emptyDir:
  sizeLimit: 1Gi    # Máximo de 1 Gibibyte
```

**Exemplo completo:**
```yaml
volumes:
- name: limited-volume
  emptyDir:
    medium: Memory
    sizeLimit: 256Mi
```

---

## Diferenças entre caminhos de montagem

Containers podem montar o mesmo volume em caminhos diferentes:

```yaml
spec:
  volumes:
  - name: shared
    emptyDir: {}

  containers:
  - name: container-1
    volumeMounts:
    - name: shared
      mountPath: /data        # Container 1 acessa via /data
  
  - name: container-2
    volumeMounts:
    - name: shared
      mountPath: /app/files   # Container 2 acessa via /app/files
```

**Resultado:**
- `/data/file.txt` no container-1 = `/app/files/file.txt` no container-2
- Mesmo arquivo, caminhos diferentes

---

## Ciclo de vida do EmptyDir

### Quando é criado
- Pod é **agendado** em um nó
- Volume é criado **vazio**

### Quando persiste
- Container **reinicia** (dados permanecem)
- Container **falha** (dados permanecem)
- Pod continua **rodando** (dados permanecem)

### Quando é deletado
- Pod é **removido** do nó
- Pod é **deletado**
- Nó **falha** (dados são perdidos)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-test
spec:
  restartPolicy: Always  # Container reinicia, volume persiste
  volumes:
  - name: data
    emptyDir: {}
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "data" > /data/file.txt && sleep 30 && exit 1']
    volumeMounts:
    - name: data
      mountPath: /data
```

**Teste:**
```bash
# Criar pod
kubectl apply -f lifecycle-test.yaml

# Container vai falhar após 30s e reiniciar
# Dados em /data/file.txt persistem entre reinicializações

# Mas se deletar o pod:
kubectl delete pod lifecycle-test
# Dados são perdidos permanentemente
```

---

## Verificando volumes

### Ver volumes de um pod

```bash
# Ver volumes definidos
kubectl get pod <pod-name> -o jsonpath='{.spec.volumes}'

# Ver volumes montados em cada container
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].volumeMounts}'

# Descrever pod (mostra volumes e montagens)
kubectl describe pod <pod-name>
```

### Acessar dados do volume

```bash
# Entrar no container
kubectl exec -it <pod-name> -c <container-name> -- sh

# Listar arquivos no volume
ls -la /data

# Ver conteúdo
cat /data/file.txt

# Criar arquivo
echo "test" > /data/test.txt
```

---

## Comparação com outros tipos de volume

| Tipo | Persistência | Compartilhamento | Uso |
|------|--------------|------------------|-----|
| **emptyDir** | Temporário (vida do Pod) | Entre containers do Pod | Cache, logs, dados temporários |
| **hostPath** | Persiste no nó | Entre Pods no mesmo nó | Acesso a arquivos do host |
| **persistentVolume** | Permanente | Entre Pods e nós | Dados que devem persistir |
| **configMap** | Permanente | Entre Pods | Configurações |
| **secret** | Permanente | Entre Pods | Dados sensíveis |

---

## Boas práticas

### 1. Use para dados temporários

```yaml
# ✅ BOM - Cache que pode ser recriado
volumes:
- name: cache
  emptyDir: {}

# ❌ RUIM - Dados críticos que devem persistir
# Use PersistentVolume para isso
```

### 2. Defina sizeLimit

```yaml
# ✅ BOM - Previne uso excessivo de disco
volumes:
- name: cache
  emptyDir:
    sizeLimit: 1Gi

# ⚠️ CUIDADO - Sem limite pode encher o disco do nó
volumes:
- name: cache
  emptyDir: {}
```

### 3. Use Memory para dados críticos de performance

```yaml
# ✅ BOM - Dados que precisam de acesso rápido
volumes:
- name: fast-cache
  emptyDir:
    medium: Memory
    sizeLimit: 256Mi
```

### 4. Nomeie volumes de forma descritiva

```yaml
# ✅ BOM
volumes:
- name: nginx-logs
- name: app-cache
- name: shared-config

# ❌ RUIM
volumes:
- name: vol1
- name: data
- name: temp
```

### 5. Documente o propósito

```yaml
volumes:
- name: shared-logs
  emptyDir: {}  # Logs compartilhados entre nginx e log-processor
```

---

## Troubleshooting

### Volume não está compartilhando dados

```bash
# Verificar se volumes estão montados corretamente
kubectl describe pod <pod-name>

# Verificar nome do volume
# spec.volumes[].name deve corresponder a volumeMounts[].name

# Entrar nos containers e verificar
kubectl exec -it <pod-name> -c container-1 -- ls -la /data
kubectl exec -it <pod-name> -c container-2 -- ls -la /data
```

### Disco cheio no nó

```bash
# Ver uso de disco dos nós
kubectl top nodes

# Ver eventos
kubectl get events --sort-by='.lastTimestamp' | grep -i disk

# Adicionar sizeLimit aos volumes
```

### Dados desapareceram

```bash
# Verificar se pod foi reiniciado ou recriado
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].restartCount}'

# Ver eventos do pod
kubectl describe pod <pod-name> | grep -A 20 Events

# EmptyDir perde dados quando Pod é deletado - isso é esperado
# Use PersistentVolume se precisa persistência
```

---

## Exemplo completo prático

Aplicação web com cache, logs e dados temporários.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-complete
  labels:
    app: webapp
spec:
  volumes:
  # Volume para logs (disco)
  - name: app-logs
    emptyDir:
      sizeLimit: 500Mi
  
  # Volume para cache (memória)
  - name: app-cache
    emptyDir:
      medium: Memory
      sizeLimit: 128Mi
  
  # Volume para dados temporários (disco)
  - name: temp-data
    emptyDir:
      sizeLimit: 1Gi

  containers:
  # Aplicação principal
  - name: webapp
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/nginx
    - name: app-cache
      mountPath: /var/cache/nginx
    - name: temp-data
      mountPath: /tmp
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  # Sidecar para processar logs
  - name: log-processor
    image: busybox
    command: ['sh', '-c', 'while true; do if [ -f /logs/access.log ]; then tail -n 10 /logs/access.log; fi; sleep 30; done']
    volumeMounts:
    - name: app-logs
      mountPath: /logs
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  
  # Sidecar para monitorar cache
  - name: cache-monitor
    image: busybox
    command: ['sh', '-c', 'while true; do du -sh /cache; sleep 60; done']
    volumeMounts:
    - name: app-cache
      mountPath: /cache
    resources:
      requests:
        memory: "32Mi"
        cpu: "25m"
      limits:
        memory: "64Mi"
        cpu: "50m"
```

**Comandos para testar:**

```bash
# Criar o pod
kubectl apply -f webapp-complete.yaml

# Verificar volumes
kubectl describe pod webapp-complete | grep -A 10 "Volumes:"

# Gerar tráfego
kubectl exec -it webapp-complete -c webapp -- curl localhost

# Ver logs processados
kubectl logs webapp-complete -c log-processor

# Ver uso de cache
kubectl logs webapp-complete -c cache-monitor

# Acessar webapp e criar arquivos
kubectl exec -it webapp-complete -c webapp -- sh
echo "test" > /tmp/test.txt
ls -la /tmp
exit

# Verificar no outro container
kubectl exec -it webapp-complete -c log-processor -- ls -la /logs

# Deletar pod (dados são perdidos)
kubectl delete pod webapp-complete
```

---

## Resumo

**EmptyDir:**
- Volume **temporário** que existe enquanto o Pod existir
- **Compartilhado** entre todos os containers do Pod
- Começa **vazio**
- Dados são **perdidos** quando Pod é removido

**Quando usar:**
- Cache temporário
- Logs compartilhados
- Dados intermediários de processamento
- Compartilhamento entre containers

**Configurações:**
- `medium: Memory` - Armazena em RAM (mais rápido)
- `sizeLimit` - Limita tamanho máximo

**Persistência:**
- ✅ Sobrevive a reinicializações de container
- ❌ Perdido quando Pod é deletado
- ❌ Não compartilhado entre Pods

**Para dados persistentes, use PersistentVolume**
