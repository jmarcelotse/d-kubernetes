# O que são os ConfigMaps?

## Introdução

**ConfigMaps** são objetos do Kubernetes usados para armazenar dados de configuração não confidenciais em pares chave-valor. Eles permitem separar a configuração da aplicação do código, facilitando a portabilidade e o gerenciamento.

## Conceito

Um ConfigMap é um objeto da API que armazena dados de configuração que podem ser consumidos por Pods. Diferente dos Secrets, os ConfigMaps são projetados para dados não sensíveis como arquivos de configuração, variáveis de ambiente, argumentos de linha de comando e scripts.

### Por Que Usar ConfigMaps?

- **Separação de Configuração:** Desacopla configuração do código da aplicação
- **Reutilização:** Mesma configuração para múltiplos Pods
- **Versionamento:** Controle de versão de configurações
- **Ambientes Diferentes:** Configurações específicas por ambiente (dev, staging, prod)
- **Atualização Dinâmica:** Alterar configuração sem rebuild da imagem
- **Portabilidade:** Aplicação independente de ambiente

## Características

### Armazenamento

- Dados armazenados em **texto plano** (não codificados)
- Tamanho máximo: **1MB** por ConfigMap
- Armazenados no etcd
- Podem conter arquivos completos ou valores simples

### Tipos de Dados

- **Literais:** Pares chave-valor simples
- **Arquivos:** Conteúdo de arquivos de configuração
- **Diretórios:** Múltiplos arquivos de um diretório

### Consumo

- **Variáveis de ambiente:** Injetadas no container
- **Volumes:** Montados como arquivos no filesystem
- **Argumentos de comando:** Passados para o container

## Diferença: ConfigMaps vs Secrets

| Aspecto | ConfigMaps | Secrets |
|---------|------------|---------|
| **Propósito** | Configurações não sensíveis | Dados sensíveis |
| **Codificação** | Texto plano | Base64 |
| **Segurança** | Sem proteção especial | Criptografia opcional |
| **Armazenamento** | Disco/etcd | tmpfs (RAM) |
| **Uso** | Configs, scripts, arquivos | Senhas, tokens, chaves |
| **Visibilidade** | Pode ser visto facilmente | Requer decodificação |
| **RBAC** | Controle de acesso | Controle de acesso mais restrito |

## Fluxo de Funcionamento

```
1. ConfigMap criado no Kubernetes
   ↓
2. ConfigMap armazenado no etcd
   ↓
3. Pod referencia ConfigMap
   ↓
4. Kubelet busca ConfigMap da API
   ↓
5. Dados injetados no Pod (env ou volume)
   ↓
6. Aplicação lê configuração
```

## Anatomia de um ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  namespace: default
data:
  # Chave-valor simples
  database_host: postgres.example.com
  database_port: "5432"
  log_level: info
  
  # Arquivo completo
  app.properties: |
    server.port=8080
    server.host=0.0.0.0
    app.name=MyApp
  
  # JSON
  config.json: |
    {
      "api_url": "https://api.example.com",
      "timeout": 30
    }
```

### Campos Principais

- **apiVersion:** Sempre `v1`
- **kind:** Sempre `ConfigMap`
- **metadata.name:** Nome único no namespace
- **data:** Dados em texto plano (chave-valor)
- **binaryData:** Dados binários em base64 (opcional)

## Exemplo Prático 1: ConfigMap Simples

### Criar via kubectl

```bash
# Criar ConfigMap a partir de literais
kubectl create configmap app-config \
  --from-literal=database_host=postgres.example.com \
  --from-literal=database_port=5432 \
  --from-literal=log_level=info \
  --from-literal=app_name=MyApp
```

**Saída esperada:**
```
configmap/app-config created
```

### Verificar ConfigMap

```bash
kubectl get configmap app-config
```

**Saída esperada:**
```
NAME         DATA   AGE
app-config   4      10s
```

### Ver Detalhes

```bash
kubectl describe configmap app-config
```

**Saída esperada:**
```
Name:         app-config
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
app_name:
----
MyApp
database_host:
----
postgres.example.com
database_port:
----
5432
log_level:
----
info

Events:  <none>
```

### Ver Conteúdo Completo

```bash
kubectl get configmap app-config -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  app_name: MyApp
  database_host: postgres.example.com
  database_port: "5432"
  log_level: info
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
```

## Exemplo Prático 2: ConfigMap a partir de Arquivo

### Criar Arquivo de Configuração

```bash
# Criar arquivo de propriedades
cat > application.properties << 'EOF'
server.port=8080
server.host=0.0.0.0
app.name=MyApplication
app.version=1.0.0
database.url=jdbc:postgresql://postgres:5432/mydb
database.pool.size=10
cache.enabled=true
cache.ttl=3600
EOF
```

### Criar ConfigMap

```bash
kubectl create configmap app-properties \
  --from-file=application.properties
```

**Saída esperada:**
```
configmap/app-properties created
```

### Verificar

```bash
kubectl get configmap app-properties -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  application.properties: |
    server.port=8080
    server.host=0.0.0.0
    app.name=MyApplication
    app.version=1.0.0
    database.url=jdbc:postgresql://postgres:5432/mydb
    database.pool.size=10
    cache.enabled=true
    cache.ttl=3600
kind: ConfigMap
metadata:
  name: app-properties
```

### Limpar Arquivo

```bash
rm application.properties
```

## Exemplo Prático 3: ConfigMap com Múltiplos Arquivos

### Criar Arquivos

```bash
# Criar diretório de configuração
mkdir config

# Arquivo 1: nginx.conf
cat > config/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
}
EOF

# Arquivo 2: app.json
cat > config/app.json << 'EOF'
{
  "api_url": "https://api.example.com",
  "timeout": 30,
  "retry": 3,
  "debug": false
}
EOF

# Arquivo 3: script.sh
cat > config/script.sh << 'EOF'
#!/bin/bash
echo "Starting application..."
echo "Environment: $ENVIRONMENT"
echo "Version: $VERSION"
EOF
```

### Criar ConfigMap a partir de Diretório

```bash
kubectl create configmap app-files \
  --from-file=config/
```

**Saída esperada:**
```
configmap/app-files created
```

### Verificar

```bash
kubectl describe configmap app-files
```

**Saída esperada:**
```
Name:         app-files
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
app.json:
----
{
  "api_url": "https://api.example.com",
  "timeout": 30,
  "retry": 3,
  "debug": false
}

nginx.conf:
----
events {
    worker_connections 1024;
}
...

script.sh:
----
#!/bin/bash
echo "Starting application..."
...
```

### Limpar

```bash
rm -rf config/
```

## Exemplo Prático 4: ConfigMap via YAML

### ConfigMap Completo

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  labels:
    app: webapp
    environment: production
  annotations:
    description: "Web application configuration"
    owner: "platform-team"
data:
  # Variáveis simples
  ENVIRONMENT: production
  LOG_LEVEL: info
  PORT: "8080"
  
  # Database
  DB_HOST: postgres.production.svc.cluster.local
  DB_PORT: "5432"
  DB_NAME: webapp_prod
  
  # Redis
  REDIS_HOST: redis.production.svc.cluster.local
  REDIS_PORT: "6379"
  
  # Arquivo de configuração
  application.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    
    database:
      host: postgres.production.svc.cluster.local
      port: 5432
      name: webapp_prod
      pool:
        min: 5
        max: 20
    
    cache:
      enabled: true
      ttl: 3600
    
    logging:
      level: info
      format: json
  
  # Nginx config
  nginx.conf: |
    events {
        worker_connections 2048;
    }
    
    http {
        upstream backend {
            server backend-service:8080;
        }
        
        server {
            listen 80;
            
            location / {
                proxy_pass http://backend;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
            }
        }
    }
  
  # Script de inicialização
  init.sh: |
    #!/bin/bash
    set -e
    
    echo "Initializing application..."
    echo "Environment: $ENVIRONMENT"
    
    # Aguardar database
    until nc -z $DB_HOST $DB_PORT; do
      echo "Waiting for database..."
      sleep 2
    done
    
    echo "Database is ready!"
    echo "Starting application..."
```

```bash
kubectl apply -f webapp-config.yaml
```

**Saída esperada:**
```
configmap/webapp-config created
```

## Exemplo Prático 5: Usando ConfigMap como Variáveis de Ambiente

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-config
data:
  APP_NAME: MyApplication
  APP_VERSION: "1.0.0"
  LOG_LEVEL: debug
  CACHE_ENABLED: "true"
```

```bash
kubectl apply -f env-config.yaml
```

### Pod com ConfigMap (Chaves Específicas)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-env-specific
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "App Name: $APP_NAME"
      echo "Version: $VERSION"
      echo "Log Level: $LOG_LEVEL"
      sleep 3600
    env:
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: env-config
          key: APP_NAME
    - name: VERSION
      valueFrom:
        configMapKeyRef:
          name: env-config
          key: APP_VERSION
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: env-config
          key: LOG_LEVEL
```

```bash
kubectl apply -f pod-env-specific.yaml
kubectl logs app-env-specific
```

**Saída esperada:**
```
App Name: MyApplication
Version: 1.0.0
Log Level: debug
```

### Pod com ConfigMap (Todas as Chaves)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-env-all
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "env | grep -E 'APP_|LOG_|CACHE_' | sort && sleep 3600"]
    envFrom:
    - configMapRef:
        name: env-config
```

```bash
kubectl apply -f pod-env-all.yaml
kubectl logs app-env-all
```

**Saída esperada:**
```
APP_NAME=MyApplication
APP_VERSION=1.0.0
CACHE_ENABLED=true
LOG_LEVEL=debug
```

## Exemplo Prático 6: Usando ConfigMap como Volume

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: volume-config
data:
  config.json: |
    {
      "api_url": "https://api.example.com",
      "timeout": 30
    }
  script.sh: |
    #!/bin/bash
    echo "Hello from ConfigMap!"
```

```bash
kubectl apply -f volume-config.yaml
```

### Pod com Volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-volume
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Files in /etc/config ==="
      ls -la /etc/config/
      echo ""
      echo "=== config.json ==="
      cat /etc/config/config.json
      echo ""
      echo "=== script.sh ==="
      cat /etc/config/script.sh
      sleep 3600
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: volume-config
```

```bash
kubectl apply -f pod-volume.yaml
kubectl logs app-volume
```

**Saída esperada:**
```
=== Files in /etc/config ===
total 0
drwxrwxrwx 3 root root  100 Mar 10 12:46 .
drwxr-xr-x 1 root root 4096 Mar 10 12:46 ..
drwxr-xr-x 2 root root   80 Mar 10 12:46 ..2026_03_10_12_46_30.123456789
lrwxrwxrwx 1 root root   31 Mar 10 12:46 ..data -> ..2026_03_10_12_46_30.123456789
lrwxrwxrwx 1 root root   18 Mar 10 12:46 config.json -> ..data/config.json
lrwxrwxrwx 1 root root   16 Mar 10 12:46 script.sh -> ..data/script.sh

=== config.json ===
{
  "api_url": "https://api.example.com",
  "timeout": 30
}

=== script.sh ===
#!/bin/bash
echo "Hello from ConfigMap!"
```

## Exemplo Prático 7: Aplicação Completa com ConfigMap

### 1. ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-app-config
data:
  # Nginx configuration
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    
    http {
        server {
            listen 80;
            server_name localhost;
            
            location / {
                root /usr/share/nginx/html;
                index index.html;
            }
            
            location /api {
                proxy_pass http://backend:8080;
            }
        }
    }
  
  # HTML page
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>My App</title>
    </head>
    <body>
        <h1>Hello from ConfigMap!</h1>
        <p>Environment: Production</p>
    </body>
    </html>
```

```bash
kubectl apply -f nginx-app-config.yaml
```

### 2. Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  labels:
    app: nginx-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-app
  template:
    metadata:
      labels:
        app: nginx-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: html-content
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-app-config
      - name: html-content
        configMap:
          name: nginx-app-config
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-app
spec:
  selector:
    app: nginx-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

```bash
kubectl apply -f nginx-app.yaml
```

### 3. Testar

```bash
# Port-forward
kubectl port-forward service/nginx-app 8080:80

# Testar
curl http://localhost:8080
```

**Saída esperada:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>My App</title>
</head>
<body>
    <h1>Hello from ConfigMap!</h1>
    <p>Environment: Production</p>
</body>
</html>
```

## Atualização de ConfigMaps

### Atualizar ConfigMap

```bash
# Editar interativamente
kubectl edit configmap app-config

# Ou aplicar novo YAML
kubectl apply -f updated-config.yaml
```

### Comportamento de Atualização

#### Variáveis de Ambiente
```
❌ NÃO atualizam automaticamente
✅ Precisa reiniciar Pods
```

```bash
kubectl rollout restart deployment nginx-app
```

#### Volumes
```
✅ Atualizam automaticamente (após alguns segundos)
⏱️ Pode levar até 1 minuto
```

### Exemplo: Atualização Automática

```bash
# Criar ConfigMap
kubectl create configmap test-config --from-literal=message="Hello v1"

# Criar Pod com volume
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        echo "Message: \$(cat /config/message)"
        sleep 5
      done
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    configMap:
      name: test-config
EOF

# Ver logs
kubectl logs -f test-pod

# Em outro terminal, atualizar ConfigMap
kubectl create configmap test-config --from-literal=message="Hello v2" --dry-run=client -o yaml | kubectl apply -f -

# Logs mostrarão nova mensagem após alguns segundos
```

## Casos de Uso Reais

### 1. Configuração por Ambiente

```yaml
# dev-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: dev
data:
  ENVIRONMENT: development
  LOG_LEVEL: debug
  DB_HOST: postgres-dev
---
# prod-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: prod
data:
  ENVIRONMENT: production
  LOG_LEVEL: info
  DB_HOST: postgres-prod
```

### 2. Feature Flags

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
data:
  features.json: |
    {
      "new_ui": true,
      "beta_features": false,
      "experimental_api": true,
      "maintenance_mode": false
    }
```

### 3. Configuração de Logging

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: logging-config
data:
  log4j.properties: |
    log4j.rootLogger=INFO, stdout
    log4j.appender.stdout=org.apache.log4j.ConsoleAppender
    log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
    log4j.appender.stdout.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss} %-5p %c{1}:%L - %m%n
```

### 4. Scripts de Inicialização

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: init-scripts
data:
  init-db.sh: |
    #!/bin/bash
    psql -U $DB_USER -d $DB_NAME <<EOF
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(50) UNIQUE NOT NULL,
      email VARCHAR(100) UNIQUE NOT NULL
    );
    EOF
```

## Comandos Úteis

### Criar

```bash
# Literal
kubectl create configmap <name> --from-literal=key=value

# Arquivo
kubectl create configmap <name> --from-file=<file>

# Diretório
kubectl create configmap <name> --from-file=<dir>/

# Múltiplos valores
kubectl create configmap <name> \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --from-file=config.json

# Com namespace
kubectl create configmap <name> --from-literal=key=value -n <namespace>
```

### Listar

```bash
# Todos os ConfigMaps
kubectl get configmaps

# Com detalhes
kubectl get configmaps -o wide

# Formato YAML
kubectl get configmap <name> -o yaml

# Formato JSON
kubectl get configmap <name> -o json
```

### Visualizar

```bash
# Descrever
kubectl describe configmap <name>

# Ver chave específica
kubectl get configmap <name> -o jsonpath='{.data.key}'

# Ver todas as chaves
kubectl get configmap <name> -o jsonpath='{.data}' | jq
```

### Editar

```bash
# Editar interativamente
kubectl edit configmap <name>

# Substituir
kubectl create configmap <name> --from-literal=key=newvalue --dry-run=client -o yaml | kubectl apply -f -
```

### Deletar

```bash
# Deletar ConfigMap
kubectl delete configmap <name>

# Deletar múltiplos
kubectl delete configmap cm1 cm2

# Deletar por label
kubectl delete configmap -l app=myapp
```

## Boas Práticas

### 1. Naming Convention

```yaml
metadata:
  name: <app>-<tipo>-<ambiente>
  # Exemplos:
  # webapp-config-prod
  # api-nginx-staging
  # cache-redis-dev
```

### 2. Labels e Annotations

```yaml
metadata:
  labels:
    app: myapp
    component: config
    environment: production
  annotations:
    description: "Application configuration"
    version: "1.0.0"
```

### 3. Organização por Propósito

```bash
# ✅ Separado por função
kubectl create configmap app-env --from-literal=...
kubectl create configmap app-files --from-file=...
kubectl create configmap app-scripts --from-file=...

# ❌ Evite misturar tudo
```

### 4. Versionamento

```yaml
# Incluir versão no nome
metadata:
  name: app-config-v2
  labels:
    version: "2.0"
```

### 5. Imutabilidade (Kubernetes 1.21+)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
immutable: true
data:
  key: value
```

**Vantagens:**
- Protege contra alterações acidentais
- Melhor performance (kubelet não precisa monitorar)
- Para atualizar, criar novo ConfigMap

## Troubleshooting

### ConfigMap não Encontrado

```bash
# Verificar namespace
kubectl get configmaps -n <namespace>

# Verificar nome exato
kubectl get configmaps --all-namespaces | grep <name>
```

### Pod não Consegue Acessar ConfigMap

```bash
# Verificar se ConfigMap existe
kubectl get configmap <name>

# Verificar referência no Pod
kubectl get pod <pod-name> -o yaml | grep -A 10 configMap

# Ver eventos
kubectl describe pod <pod-name>
```

### Volume não Monta

```bash
# Verificar logs do kubelet
journalctl -u kubelet | grep configmap

# Verificar permissões
kubectl exec <pod-name> -- ls -la /path/to/mount
```

## Limpeza

```bash
# Remover ConfigMaps
kubectl delete configmap app-config app-properties app-files webapp-config
kubectl delete configmap env-config volume-config nginx-app-config
kubectl delete configmap test-config feature-flags logging-config init-scripts

# Remover Pods
kubectl delete pod app-env-specific app-env-all app-volume test-pod

# Remover Deployments
kubectl delete deployment nginx-app

# Remover Services
kubectl delete service nginx-app
```

## Resumo

- **ConfigMaps armazenam configurações não sensíveis** em texto plano
- **Separação de configuração** do código da aplicação
- **Consumo via variáveis de ambiente ou volumes**
- **Volumes atualizam automaticamente**, variáveis não
- **Tamanho máximo: 1MB** por ConfigMap
- **Diferente de Secrets:** sem codificação, sem proteção especial
- Use **labels e annotations** para organização
- **Imutabilidade** para proteção e performance

## Próximos Passos

- Estudar **Secrets** para dados sensíveis
- Implementar **atualização automática** com reloader
- Usar **Kustomize** para gerenciar ConfigMaps por ambiente
- Integrar com **Helm** para templates
- Configurar **RBAC** para controle de acesso
