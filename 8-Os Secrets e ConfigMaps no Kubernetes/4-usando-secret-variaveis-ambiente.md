# Utilizando o Nosso Secret como Variável de Ambiente no Pod

## Introdução

Uma das formas mais comuns de consumir Secrets em Pods é através de **variáveis de ambiente**. Isso permite que a aplicação acesse credenciais e configurações sensíveis sem hardcoding no código.

## Métodos de Injeção

### Visão Geral

| Método | Descrição | Uso |
|--------|-----------|-----|
| **valueFrom.secretKeyRef** | Injeta uma chave específica | Controle granular |
| **envFrom.secretRef** | Injeta todas as chaves | Simplicidade |
| **envFrom com prefix** | Injeta todas com prefixo | Organização |
| **Combinação** | Mistura métodos | Flexibilidade |

## Fluxo de Funcionamento

```
1. Secret criado no Kubernetes
   ↓
2. Pod referencia Secret no spec
   ↓
3. Kubelet busca Secret da API
   ↓
4. Secret decodificado (base64 → texto)
   ↓
5. Variáveis injetadas no container
   ↓
6. Aplicação lê variáveis (process.env, os.getenv, etc.)
```

## Preparação: Criar Secret

### Secret de Exemplo

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  # Database
  DB_HOST: postgres.example.com
  DB_PORT: "5432"
  DB_NAME: myapp_db
  DB_USER: admin
  DB_PASSWORD: SuperSecret123
  
  # API Keys
  API_KEY: sk-1234567890abcdef
  API_SECRET: secret-abcdefghijklmnop
  
  # JWT
  JWT_SECRET: my-jwt-secret-key-2024
```

```bash
kubectl apply -f app-secrets.yaml
```

**Saída esperada:**
```
secret/app-secrets created
```

### Verificar Secret

```bash
kubectl get secret app-secrets
```

**Saída esperada:**
```
NAME          TYPE     DATA   AGE
app-secrets   Opaque   8      10s
```

## Método 1: valueFrom.secretKeyRef (Chave Específica)

### Descrição

Injeta uma chave específica do Secret como variável de ambiente. Oferece controle total sobre nomes de variáveis.

### Sintaxe

```yaml
env:
- name: NOME_VARIAVEL
  valueFrom:
    secretKeyRef:
      name: nome-do-secret
      key: chave-do-secret
```

### Exemplo 1: Variáveis Individuais

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-env-individual
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Database Configuration ==="
      echo "Host: $DATABASE_HOST"
      echo "Port: $DATABASE_PORT"
      echo "Database: $DATABASE_NAME"
      echo "User: $DATABASE_USER"
      echo "Password: $DATABASE_PASSWORD"
      echo ""
      echo "=== API Configuration ==="
      echo "API Key: $API_KEY"
      echo "API Secret: $API_SECRET"
      echo ""
      sleep 3600
    env:
    # Database credentials
    - name: DATABASE_HOST
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_HOST
    - name: DATABASE_PORT
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_PORT
    - name: DATABASE_NAME
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_NAME
    - name: DATABASE_USER
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_USER
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_PASSWORD
    
    # API credentials
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: API_KEY
    - name: API_SECRET
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: API_SECRET
```

```bash
kubectl apply -f pod-env-individual.yaml
```

**Saída esperada:**
```
pod/app-env-individual created
```

### Verificar Logs

```bash
kubectl logs app-env-individual
```

**Saída esperada:**
```
=== Database Configuration ===
Host: postgres.example.com
Port: 5432
Database: myapp_db
User: admin
Password: SuperSecret123

=== API Configuration ===
API Key: sk-1234567890abcdef
API Secret: secret-abcdefghijklmnop
```

### Verificar Dentro do Pod

```bash
kubectl exec -it app-env-individual -- sh

# Dentro do Pod
env | grep -E "DATABASE|API"
```

**Saída esperada:**
```
DATABASE_HOST=postgres.example.com
DATABASE_PORT=5432
DATABASE_NAME=myapp_db
DATABASE_USER=admin
DATABASE_PASSWORD=SuperSecret123
API_KEY=sk-1234567890abcdef
API_SECRET=secret-abcdefghijklmnop
```

### Exemplo 2: Renomear Variáveis

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-env-renamed
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "env | grep -E 'POSTGRES|SECRET' && sleep 3600"]
    env:
    # Renomear variáveis para padrão da aplicação
    - name: POSTGRES_HOST
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_HOST
    - name: POSTGRES_PORT
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_PORT
    - name: POSTGRES_DB
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_NAME
    - name: POSTGRES_USER
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_USER
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_PASSWORD
    - name: SECRET_KEY
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: JWT_SECRET
```

```bash
kubectl apply -f pod-env-renamed.yaml
kubectl logs app-env-renamed
```

**Saída esperada:**
```
POSTGRES_HOST=postgres.example.com
POSTGRES_PORT=5432
POSTGRES_DB=myapp_db
POSTGRES_USER=admin
POSTGRES_PASSWORD=SuperSecret123
SECRET_KEY=my-jwt-secret-key-2024
```

## Método 2: envFrom.secretRef (Todas as Chaves)

### Descrição

Injeta todas as chaves do Secret como variáveis de ambiente. Os nomes das variáveis são os mesmos das chaves do Secret.

### Sintaxe

```yaml
envFrom:
- secretRef:
    name: nome-do-secret
```

### Exemplo 1: Injetar Tudo

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-env-all
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== All Environment Variables from Secret ==="
      env | sort
      echo ""
      echo "=== Testing Variables ==="
      echo "DB_HOST: $DB_HOST"
      echo "DB_USER: $DB_USER"
      echo "API_KEY: $API_KEY"
      sleep 3600
    envFrom:
    - secretRef:
        name: app-secrets
```

```bash
kubectl apply -f pod-env-all.yaml
```

**Saída esperada:**
```
pod/app-env-all created
```

### Verificar Logs

```bash
kubectl logs app-env-all
```

**Saída esperada:**
```
=== All Environment Variables from Secret ===
API_KEY=sk-1234567890abcdef
API_SECRET=secret-abcdefghijklmnop
DB_HOST=postgres.example.com
DB_NAME=myapp_db
DB_PASSWORD=SuperSecret123
DB_PORT=5432
DB_USER=admin
JWT_SECRET=my-jwt-secret-key-2024
...

=== Testing Variables ===
DB_HOST: postgres.example.com
DB_USER: admin
API_KEY: sk-1234567890abcdef
```

### Exemplo 2: Múltiplos Secrets

```bash
# Criar segundo Secret
kubectl create secret generic cache-secrets \
  --from-literal=REDIS_HOST=redis.example.com \
  --from-literal=REDIS_PORT=6379 \
  --from-literal=REDIS_PASSWORD=redis-secret
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-multi-secrets
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "env | grep -E 'DB_|REDIS_|API_' | sort && sleep 3600"]
    envFrom:
    - secretRef:
        name: app-secrets
    - secretRef:
        name: cache-secrets
```

```bash
kubectl apply -f pod-multi-secrets.yaml
kubectl logs app-multi-secrets
```

**Saída esperada:**
```
API_KEY=sk-1234567890abcdef
API_SECRET=secret-abcdefghijklmnop
DB_HOST=postgres.example.com
DB_NAME=myapp_db
DB_PASSWORD=SuperSecret123
DB_PORT=5432
DB_USER=admin
REDIS_HOST=redis.example.com
REDIS_PASSWORD=redis-secret
REDIS_PORT=6379
```

## Método 3: envFrom com Prefix

### Descrição

Injeta todas as chaves do Secret com um prefixo, evitando conflitos de nomes.

### Sintaxe

```yaml
envFrom:
- secretRef:
    name: nome-do-secret
  prefix: PREFIXO_
```

### Exemplo 1: Prefixo Simples

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-env-prefix
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "env | grep APP_ | sort && sleep 3600"]
    envFrom:
    - secretRef:
        name: app-secrets
      prefix: APP_
```

```bash
kubectl apply -f pod-env-prefix.yaml
kubectl logs app-env-prefix
```

**Saída esperada:**
```
APP_API_KEY=sk-1234567890abcdef
APP_API_SECRET=secret-abcdefghijklmnop
APP_DB_HOST=postgres.example.com
APP_DB_NAME=myapp_db
APP_DB_PASSWORD=SuperSecret123
APP_DB_PORT=5432
APP_DB_USER=admin
APP_JWT_SECRET=my-jwt-secret-key-2024
```

### Exemplo 2: Múltiplos Secrets com Prefixos

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-multi-prefix
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "env | grep -E 'DATABASE_|CACHE_' | sort && sleep 3600"]
    envFrom:
    # Database secrets com prefixo
    - secretRef:
        name: app-secrets
      prefix: DATABASE_
    
    # Cache secrets com prefixo
    - secretRef:
        name: cache-secrets
      prefix: CACHE_
```

```bash
kubectl apply -f pod-multi-prefix.yaml
kubectl logs app-multi-prefix
```

**Saída esperada:**
```
CACHE_REDIS_HOST=redis.example.com
CACHE_REDIS_PASSWORD=redis-secret
CACHE_REDIS_PORT=6379
DATABASE_API_KEY=sk-1234567890abcdef
DATABASE_API_SECRET=secret-abcdefghijklmnop
DATABASE_DB_HOST=postgres.example.com
DATABASE_DB_NAME=myapp_db
DATABASE_DB_PASSWORD=SuperSecret123
DATABASE_DB_PORT=5432
DATABASE_DB_USER=admin
DATABASE_JWT_SECRET=my-jwt-secret-key-2024
```

## Método 4: Combinação de Métodos

### Exemplo: Misturando Técnicas

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-env-combined
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Combined Environment Variables ==="
      echo "DATABASE_URL: $DATABASE_URL"
      echo "DB_HOST: $DB_HOST"
      echo "CUSTOM_API_KEY: $CUSTOM_API_KEY"
      echo "APP_DB_USER: $APP_DB_USER"
      sleep 3600
    
    # Variáveis individuais customizadas
    env:
    - name: CUSTOM_API_KEY
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: API_KEY
    
    # Construir DATABASE_URL a partir de múltiplas chaves
    - name: DATABASE_URL
      value: "postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)"
    
    # Injetar todas as chaves do Secret
    envFrom:
    - secretRef:
        name: app-secrets
    
    # Injetar com prefixo
    - secretRef:
        name: cache-secrets
      prefix: APP_
```

```bash
kubectl apply -f pod-env-combined.yaml
kubectl logs app-env-combined
```

**Saída esperada:**
```
=== Combined Environment Variables ===
DATABASE_URL: postgresql://admin:SuperSecret123@postgres.example.com:5432/myapp_db
DB_HOST: postgres.example.com
CUSTOM_API_KEY: sk-1234567890abcdef
APP_DB_USER: admin
```

## Exemplo Prático: Deployment com Secret

### 1. Criar Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-config
type: Opaque
stringData:
  # Database
  POSTGRES_HOST: postgres.production.svc.cluster.local
  POSTGRES_PORT: "5432"
  POSTGRES_DB: webapp_prod
  POSTGRES_USER: webapp_user
  POSTGRES_PASSWORD: prod-secret-password-123
  
  # Redis
  REDIS_HOST: redis.production.svc.cluster.local
  REDIS_PORT: "6379"
  REDIS_PASSWORD: redis-prod-password
  
  # Application
  SECRET_KEY: django-secret-key-production-2024
  JWT_SECRET: jwt-secret-key-production
  
  # External APIs
  STRIPE_API_KEY: sk_live_1234567890abcdef
  SENDGRID_API_KEY: SG.1234567890abcdef
  AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
  AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

```bash
kubectl apply -f webapp-config.yaml
```

### 2. Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
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
      - name: webapp
        image: myapp:latest
        ports:
        - containerPort: 8000
        
        # Variáveis customizadas
        env:
        - name: ENVIRONMENT
          value: "production"
        
        - name: DATABASE_URL
          value: "postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_HOST):$(POSTGRES_PORT)/$(POSTGRES_DB)"
        
        - name: REDIS_URL
          value: "redis://:$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/0"
        
        # Injetar todas as variáveis do Secret
        envFrom:
        - secretRef:
            name: webapp-config
        
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

```bash
kubectl apply -f webapp-deployment.yaml
```

**Saída esperada:**
```
deployment.apps/webapp created
```

### 3. Verificar Deployment

```bash
kubectl get deployment webapp
```

**Saída esperada:**
```
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
webapp   3/3     3            3           30s
```

### 4. Verificar Variáveis em um Pod

```bash
# Obter nome do Pod
POD_NAME=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')

# Ver variáveis de ambiente
kubectl exec $POD_NAME -- env | grep -E "POSTGRES|REDIS|SECRET|STRIPE|AWS" | sort
```

**Saída esperada:**
```
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
DATABASE_URL=postgresql://webapp_user:prod-secret-password-123@postgres.production.svc.cluster.local:5432/webapp_prod
JWT_SECRET=jwt-secret-key-production
POSTGRES_DB=webapp_prod
POSTGRES_HOST=postgres.production.svc.cluster.local
POSTGRES_PASSWORD=prod-secret-password-123
POSTGRES_PORT=5432
POSTGRES_USER=webapp_user
REDIS_HOST=redis.production.svc.cluster.local
REDIS_PASSWORD=redis-prod-password
REDIS_PORT=6379
REDIS_URL=redis://:redis-prod-password@redis.production.svc.cluster.local:6379/0
SECRET_KEY=django-secret-key-production-2024
SENDGRID_API_KEY=SG.1234567890abcdef
STRIPE_API_KEY=sk_live_1234567890abcdef
```

## Exemplo: Aplicação Real (Node.js)

### 1. Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nodejs-app-secrets
type: Opaque
stringData:
  DB_HOST: postgres.default.svc.cluster.local
  DB_PORT: "5432"
  DB_NAME: nodejs_app
  DB_USER: appuser
  DB_PASSWORD: apppass123
  JWT_SECRET: my-jwt-secret
  API_KEY: sk-1234567890
```

### 2. Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodejs-app
  template:
    metadata:
      labels:
        app: nodejs-app
    spec:
      containers:
      - name: app
        image: node:20-alpine
        workingDir: /app
        command: ["/bin/sh"]
        args:
        - -c
        - |
          cat > server.js << 'EOF'
          const http = require('http');
          
          const server = http.createServer((req, res) => {
            const config = {
              database: {
                host: process.env.DB_HOST,
                port: process.env.DB_PORT,
                name: process.env.DB_NAME,
                user: process.env.DB_USER,
                password: '***' // Não expor senha
              },
              jwt_secret: process.env.JWT_SECRET ? '***' : 'not set',
              api_key: process.env.API_KEY ? '***' : 'not set'
            };
            
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(config, null, 2));
          });
          
          server.listen(3000, () => {
            console.log('Server running on port 3000');
            console.log('DB_HOST:', process.env.DB_HOST);
            console.log('DB_USER:', process.env.DB_USER);
          });
          EOF
          
          node server.js
        ports:
        - containerPort: 3000
        envFrom:
        - secretRef:
            name: nodejs-app-secrets
---
apiVersion: v1
kind: Service
metadata:
  name: nodejs-app
spec:
  selector:
    app: nodejs-app
  ports:
  - port: 80
    targetPort: 3000
```

```bash
kubectl apply -f nodejs-app-secrets.yaml
kubectl apply -f nodejs-app.yaml
```

### 3. Testar Aplicação

```bash
# Port-forward
kubectl port-forward service/nodejs-app 8080:80

# Em outro terminal
curl http://localhost:8080
```

**Saída esperada:**
```json
{
  "database": {
    "host": "postgres.default.svc.cluster.local",
    "port": "5432",
    "name": "nodejs_app",
    "user": "appuser",
    "password": "***"
  },
  "jwt_secret": "***",
  "api_key": "***"
}
```

## Considerações Importantes

### 1. Variáveis Aparecem em Logs

```bash
# ❌ Evite isso
kubectl exec pod-name -- env

# ❌ Logs podem expor variáveis
kubectl logs pod-name
```

**Solução:** Use volumes em vez de variáveis para dados muito sensíveis.

### 2. Variáveis Não Atualizam Automaticamente

```bash
# Atualizar Secret
kubectl create secret generic app-secrets \
  --from-literal=DB_PASSWORD=new-password \
  --dry-run=client -o yaml | kubectl apply -f -

# Pods NÃO pegam novo valor automaticamente
# Precisa reiniciar Pods
kubectl rollout restart deployment webapp
```

### 3. Chaves Inválidas São Ignoradas

```yaml
# Se chave não existe no Secret, Pod não inicia
env:
- name: MY_VAR
  valueFrom:
    secretKeyRef:
      name: app-secrets
      key: CHAVE_INEXISTENTE  # ❌ Erro!
```

**Solução:** Use `optional: true`

```yaml
env:
- name: MY_VAR
  valueFrom:
    secretKeyRef:
      name: app-secrets
      key: CHAVE_INEXISTENTE
      optional: true  # ✅ Não falha se não existir
```

### 4. Ordem de Precedência

```yaml
# Se mesma variável definida em múltiplos lugares:
# 1. env (último ganha)
# 2. envFrom (último ganha)

env:
- name: API_KEY
  value: "from-env"  # ✅ Este prevalece

envFrom:
- secretRef:
    name: app-secrets  # Tem API_KEY, mas é sobrescrito
```

## Comandos Úteis

### Verificar Variáveis

```bash
# Listar variáveis de ambiente
kubectl exec pod-name -- env

# Filtrar variáveis específicas
kubectl exec pod-name -- env | grep DB_

# Ver variável específica
kubectl exec pod-name -- printenv DB_PASSWORD

# Verificar se variável existe
kubectl exec pod-name -- sh -c 'echo $DB_PASSWORD'
```

### Debug

```bash
# Ver spec do Pod
kubectl get pod pod-name -o yaml | grep -A 20 env

# Ver eventos
kubectl describe pod pod-name

# Logs
kubectl logs pod-name

# Shell interativo
kubectl exec -it pod-name -- sh
```

## Boas Práticas

### 1. Use envFrom para Simplicidade

```yaml
# ✅ Simples e limpo
envFrom:
- secretRef:
    name: app-secrets
```

### 2. Use valueFrom para Controle

```yaml
# ✅ Quando precisa renomear ou selecionar
env:
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secrets
      key: DB_PASSWORD
```

### 3. Use Prefixos para Organização

```yaml
# ✅ Evita conflitos
envFrom:
- secretRef:
    name: db-secrets
  prefix: DB_
- secretRef:
    name: cache-secrets
  prefix: CACHE_
```

### 4. Documente Variáveis Esperadas

```yaml
metadata:
  annotations:
    required-env-vars: "DB_HOST,DB_USER,DB_PASSWORD,API_KEY"
```

### 5. Não Exponha Secrets em Logs

```javascript
// ❌ Evite
console.log('Password:', process.env.DB_PASSWORD);

// ✅ Faça
console.log('Password:', process.env.DB_PASSWORD ? '***' : 'not set');
```

## Limpeza

```bash
# Remover Pods
kubectl delete pod app-env-individual app-env-renamed app-env-all app-multi-secrets
kubectl delete pod app-env-prefix app-multi-prefix app-env-combined

# Remover Deployments
kubectl delete deployment webapp nodejs-app

# Remover Services
kubectl delete service nodejs-app

# Remover Secrets
kubectl delete secret app-secrets cache-secrets webapp-config nodejs-app-secrets
```

## Resumo

- **valueFrom.secretKeyRef** para chaves específicas com controle de nomes
- **envFrom.secretRef** para injetar todas as chaves rapidamente
- **prefix** para organizar e evitar conflitos
- **Combine métodos** para flexibilidade máxima
- Variáveis **não atualizam automaticamente** - precisa reiniciar Pods
- **Cuidado com logs** - variáveis podem ser expostas
- Use **optional: true** para chaves opcionais
- **Volumes são mais seguros** que variáveis para dados muito sensíveis

## Próximos Passos

- Estudar **Secrets como volumes** (mais seguro)
- Implementar **atualização automática** com reloader
- Configurar **RBAC** para controle de acesso
- Usar **External Secrets Operator**
- Implementar **rotação de Secrets**
