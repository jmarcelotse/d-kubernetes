# Pod Multicontainer com Manifesto

## O que é um Pod Multicontainer?

Um Pod multicontainer é um Pod que contém **dois ou mais containers** que trabalham juntos de forma acoplada, compartilhando:
- Mesmo endereço IP
- Mesmo namespace de rede
- Mesmos volumes
- Mesmo ciclo de vida

## Quando usar?

- **Sidecar**: Container auxiliar que complementa o container principal (logs, proxy, monitoring)
- **Adapter**: Container que transforma dados do container principal
- **Ambassador**: Container que atua como proxy para serviços externos
- **Init containers**: Containers que executam antes do container principal

## Estrutura básica do manifesto

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nome-do-pod
spec:
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  containers:
  - name: container-1
    image: imagem-1
  - name: container-2
    image: imagem-2
```

### Configurações importantes do spec

#### dnsPolicy: ClusterFirst
Define como o Pod resolve nomes DNS.

**Opções:**
- `ClusterFirst` (padrão): Usa o DNS do cluster Kubernetes. Consultas que não correspondem ao domínio do cluster são encaminhadas para o servidor DNS upstream
- `Default`: Herda a configuração DNS do nó onde o Pod está executando
- `None`: Permite configurar DNS customizado via `dnsConfig`
- `ClusterFirstWithHostNet`: Para Pods usando `hostNetwork: true`

**Por que é importante:**
- Permite que containers resolvam nomes de Services (ex: `database-service.default.svc.cluster.local`)
- Essencial para comunicação entre Pods e Services no cluster
- Sem isso, containers não conseguem descobrir outros serviços

#### restartPolicy: Always
Define quando o Kubernetes deve reiniciar containers que falharam.

**Opções:**
- `Always` (padrão): Sempre reinicia o container, independente do código de saída
- `OnFailure`: Reinicia apenas se o container terminar com erro (exit code != 0)
- `Never`: Nunca reinicia o container automaticamente

**Por que é importante:**
- Garante alta disponibilidade da aplicação
- Em pods multicontainer, afeta todos os containers do Pod
- Crítico para aplicações que devem estar sempre disponíveis

**Exemplo com todas as configurações:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exemplo-completo
spec:
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  containers:
  - name: app
    image: nginx
  - name: sidecar
    image: busybox
```

---

## Exemplo 1: Pod com Nginx e Sidecar de Logs

Este exemplo mostra um container Nginx servindo conteúdo e um container sidecar que monitora os logs.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-with-sidecar
  labels:
    app: webserver
spec:
  # Volume compartilhado entre os containers
  volumes:
  - name: shared-logs
    emptyDir: {}

  containers:
  # Container principal - Nginx
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx

  # Container sidecar - Log processor
  - name: log-sidecar
    image: busybox
    command: ['sh', '-c', 'tail -f /var/log/nginx/access.log']
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
```

### Como funciona:
1. **Volume compartilhado**: `emptyDir` cria um volume temporário compartilhado
2. **Nginx**: Escreve logs em `/var/log/nginx`
3. **Sidecar**: Lê e processa os logs do mesmo diretório

---

## Exemplo 2: Aplicação Web com Proxy Sidecar

Container principal rodando uma aplicação e um sidecar fazendo proxy reverso.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-proxy
  labels:
    app: myapp
spec:
  containers:
  # Container principal - Aplicação
  - name: app
    image: myapp:v1
    ports:
    - containerPort: 8080
    env:
    - name: APP_ENV
      value: "production"

  # Container sidecar - Nginx Proxy
  - name: nginx-proxy
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: nginx-config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf

  volumes:
  - name: nginx-config
    configMap:
      name: nginx-proxy-config
```

---

## Exemplo 3: Pod com Múltiplos Containers e Recursos

Exemplo mais completo com limites de recursos e health checks.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-app
  labels:
    app: fullstack
    tier: backend
spec:
  containers:
  # Container 1 - Aplicação principal
  - name: app
    image: myapp:latest
    ports:
    - containerPort: 8080
      name: http
    env:
    - name: DATABASE_URL
      value: "localhost:5432"
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10

  # Container 2 - Database sidecar
  - name: database
    image: postgres:14
    ports:
    - containerPort: 5432
    env:
    - name: POSTGRES_PASSWORD
      value: "senha123"
    - name: POSTGRES_DB
      value: "mydb"
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    volumeMounts:
    - name: db-data
      mountPath: /var/lib/postgresql/data

  # Container 3 - Monitoring sidecar
  - name: metrics-exporter
    image: prom/node-exporter:latest
    ports:
    - containerPort: 9100
      name: metrics

  volumes:
  - name: db-data
    emptyDir: {}
```

---

## Exemplo 4: Init Container + Containers Principais

Init containers executam **antes** dos containers principais e são úteis para preparação.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-init
  labels:
    app: webapp
spec:
  # Init containers executam sequencialmente antes dos containers principais
  initContainers:
  - name: init-setup
    image: busybox
    command: ['sh', '-c', 'echo "Preparando ambiente..." && sleep 5']
  
  - name: init-database
    image: busybox
    command: ['sh', '-c', 'until nslookup database-service; do echo waiting for database; sleep 2; done']

  # Containers principais executam em paralelo após init containers
  containers:
  - name: web-app
    image: nginx:latest
    ports:
    - containerPort: 80
    
  - name: api-app
    image: myapi:v1
    ports:
    - containerPort: 8080
```

---

## Criando e gerenciando o Pod

### Criar o Pod

```bash
# Criar pod a partir do manifesto
kubectl apply -f pod-multicontainer.yaml

# Verificar criação
kubectl get pods

# Ver detalhes
kubectl get pods -o wide
```

### Verificar status dos containers

```bash
# Ver todos os containers do pod
kubectl get pod nginx-with-sidecar -o jsonpath='{.spec.containers[*].name}'

# Descrever o pod (mostra status de cada container)
kubectl describe pod nginx-with-sidecar
```

### Acessar containers específicos

```bash
# Executar comando no container nginx
kubectl exec -it nginx-with-sidecar -c nginx -- /bin/bash

# Executar comando no container sidecar
kubectl exec -it nginx-with-sidecar -c log-sidecar -- /bin/sh

# Ver logs do container nginx
kubectl logs nginx-with-sidecar -c nginx

# Ver logs do container sidecar
kubectl logs nginx-with-sidecar -c log-sidecar

# Ver logs de todos os containers
kubectl logs nginx-with-sidecar --all-containers=true

# Seguir logs em tempo real
kubectl logs -f nginx-with-sidecar -c nginx
```

---

## Padrões de comunicação entre containers

### 1. Via localhost (mesma rede)

```yaml
containers:
- name: app
  image: myapp
  # App escuta na porta 8080
  
- name: proxy
  image: nginx
  # Proxy acessa app via localhost:8080
  # Ambos compartilham o mesmo IP
```

### 2. Via volume compartilhado

```yaml
volumes:
- name: shared-data
  emptyDir: {}

containers:
- name: writer
  image: busybox
  command: ['sh', '-c', 'echo "data" > /data/file.txt']
  volumeMounts:
  - name: shared-data
    mountPath: /data
    
- name: reader
  image: busybox
  command: ['sh', '-c', 'cat /data/file.txt']
  volumeMounts:
  - name: shared-data
    mountPath: /data
```

### 3. Via variáveis de ambiente

```yaml
containers:
- name: app
  env:
  - name: SIDECAR_PORT
    value: "9090"
    
- name: sidecar
  env:
  - name: APP_PORT
    value: "8080"
```

---

## Tipos de volumes para compartilhamento

### emptyDir
Volume temporário que existe enquanto o Pod existir.

```yaml
volumes:
- name: cache
  emptyDir: {}
```

### hostPath
Monta um diretório do nó host (use com cuidado).

```yaml
volumes:
- name: host-data
  hostPath:
    path: /data
    type: Directory
```

### configMap
Compartilha configurações entre containers.

```yaml
volumes:
- name: config
  configMap:
    name: app-config
```

### secret
Compartilha dados sensíveis.

```yaml
volumes:
- name: secrets
  secret:
    secretName: app-secrets
```

---

## Boas práticas

### 1. Nomeação clara
```yaml
containers:
- name: app-main          # Container principal
- name: logs-sidecar      # Função clara
- name: metrics-exporter  # Propósito explícito
```

### 2. Definir recursos
```yaml
containers:
- name: app
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

### 3. Health checks
```yaml
containers:
- name: app
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
```

### 4. Labels organizadas
```yaml
metadata:
  labels:
    app: myapp
    component: backend
    tier: api
    version: v1
```

---

## Troubleshooting

### Ver status de cada container

```bash
kubectl get pod multi-container-app -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.state}{"\n"}{end}'
```

### Verificar qual container está com problema

```bash
kubectl describe pod multi-container-app | grep -A 10 "Container"
```

### Ver eventos do pod

```bash
kubectl describe pod multi-container-app | grep -A 20 "Events"
```

### Logs de container específico que falhou

```bash
kubectl logs multi-container-app -c container-name --previous
```

### Executar debug em container específico

```bash
kubectl exec -it multi-container-app -c app -- /bin/bash
```

---

## Exemplo completo prático

Vamos criar um pod com aplicação web + banco de dados + monitoramento.

**Arquivo: `fullstack-pod.yaml`**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fullstack-pod
  labels:
    app: fullstack
    env: development
spec:
  volumes:
  - name: app-logs
    emptyDir: {}
  - name: db-storage
    emptyDir: {}

  containers:
  # Container 1: Aplicação Web
  - name: webapp
    image: nginx:alpine
    ports:
    - containerPort: 80
      name: http
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/nginx
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"

  # Container 2: API Backend
  - name: api
    image: node:18-alpine
    command: ['sh', '-c', 'npm install -g json-server && json-server --watch /data/db.json --host 0.0.0.0 --port 3000']
    ports:
    - containerPort: 3000
      name: api
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "400m"

  # Container 3: Log Monitor
  - name: log-monitor
    image: busybox
    command: ['sh', '-c', 'while true; do if [ -f /logs/access.log ]; then tail -f /logs/access.log; fi; sleep 5; done']
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
```

### Comandos para usar:

```bash
# Criar o pod
kubectl apply -f fullstack-pod.yaml

# Verificar status
kubectl get pod fullstack-pod

# Ver todos os containers
kubectl get pod fullstack-pod -o jsonpath='{.spec.containers[*].name}'

# Logs do webapp
kubectl logs fullstack-pod -c webapp

# Logs do api
kubectl logs fullstack-pod -c api

# Logs do monitor
kubectl logs fullstack-pod -c log-monitor

# Acessar webapp
kubectl exec -it fullstack-pod -c webapp -- sh

# Acessar api
kubectl exec -it fullstack-pod -c api -- sh

# Deletar o pod
kubectl delete pod fullstack-pod
```

---

## Resumo

**Pod multicontainer** permite:
- Containers trabalhando juntos de forma acoplada
- Compartilhamento de rede (localhost)
- Compartilhamento de volumes
- Padrões como sidecar, adapter e ambassador

**Principais casos de uso:**
- Logs e monitoramento (sidecar)
- Proxy e service mesh
- Adaptadores de dados
- Init containers para preparação

**Comandos essenciais:**
- `kubectl apply -f` - Criar pod
- `kubectl logs -c` - Ver logs de container específico
- `kubectl exec -c` - Executar comando em container específico
- `kubectl describe` - Ver detalhes e eventos
