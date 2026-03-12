# Criando um Secret do Tipo Opaque

## Introdução

O tipo **Opaque** é o tipo padrão e mais comum de Secret no Kubernetes. É usado para armazenar dados arbitrários como senhas, tokens de API, chaves de criptografia e outras informações sensíveis que não se encaixam em tipos específicos.

## O que é um Secret Opaque?

### Características

- **Tipo padrão:** Se não especificar tipo, será Opaque
- **Flexível:** Aceita qualquer chave e valor
- **Sem validação:** Kubernetes não valida a estrutura dos dados
- **Base64:** Dados armazenados em base64
- **Tamanho:** Máximo 1MB por Secret

### Quando Usar

- Senhas de banco de dados
- Tokens de API
- Chaves de criptografia
- Credenciais de serviços externos
- Configurações sensíveis
- Qualquer dado que não se encaixa em tipos específicos

## Métodos de Criação

### Visão Geral

| Método | Vantagens | Desvantagens |
|--------|-----------|--------------|
| **kubectl literal** | Rápido, simples | Não versionável, fica no histórico |
| **kubectl file** | Dados de arquivos | Arquivos sensíveis no disco |
| **YAML (data)** | Versionável | Precisa codificar base64 manualmente |
| **YAML (stringData)** | Versionável, texto plano | Expõe dados no YAML |
| **kubectl dry-run** | Gera YAML | Dois passos |

## Método 1: kubectl create com --from-literal

### Sintaxe

```bash
kubectl create secret generic <nome> \
  --from-literal=<chave>=<valor> \
  --from-literal=<chave2>=<valor2>
```

### Exemplo 1: Credenciais de Banco de Dados

```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=SuperSecret123 \
  --from-literal=database=myapp_db \
  --from-literal=host=mysql.example.com \
  --from-literal=port=3306
```

**Saída esperada:**
```
secret/db-credentials created
```

### Verificar Secret

```bash
kubectl get secret db-credentials
```

**Saída esperada:**
```
NAME             TYPE     DATA   AGE
db-credentials   Opaque   5      10s
```

### Ver Detalhes

```bash
kubectl describe secret db-credentials
```

**Saída esperada:**
```
Name:         db-credentials
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
database:  9 bytes
host:      18 bytes
password:  15 bytes
port:      4 bytes
username:  5 bytes
```

### Ver Conteúdo (Base64)

```bash
kubectl get secret db-credentials -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  database: bXlhcHBfZGI=
  host: bXlzcWwuZXhhbXBsZS5jb20=
  password: U3VwZXJTZWNyZXQxMjM=
  port: MzMwNg==
  username: YWRtaW4=
kind: Secret
metadata:
  name: db-credentials
  namespace: default
type: Opaque
```

### Decodificar Valores

```bash
# Decodificar username
kubectl get secret db-credentials -o jsonpath='{.data.username}' | base64 -d
echo

# Decodificar password
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
echo

# Decodificar todos os valores
kubectl get secret db-credentials -o json | jq -r '.data | map_values(@base64d)'
```

**Saída esperada:**
```
admin
SuperSecret123
{
  "database": "myapp_db",
  "host": "mysql.example.com",
  "password": "SuperSecret123",
  "port": "3306",
  "username": "admin"
}
```

### Exemplo 2: Token de API

```bash
kubectl create secret generic api-tokens \
  --from-literal=github-token=ghp_EXAMPLE1234567890abcdefghijklmnopqrstuvwxyz \
  --from-literal=slack-token=xoxb-EXAMPLE-1234567890-1234567890-EXAMPLETOKEN \
  --from-literal=stripe-key=sk_test_EXAMPLE1234567890abcdefghijklmnop
```

**Saída esperada:**
```
secret/api-tokens created
```

## Método 2: kubectl create com --from-file

### Sintaxe

```bash
kubectl create secret generic <nome> \
  --from-file=<chave>=<arquivo> \
  --from-file=<arquivo>  # chave = nome do arquivo
```

### Exemplo 1: Arquivo Único

```bash
# Criar arquivo com senha
echo -n 'SuperSecret123' > db-password.txt

# Criar Secret
kubectl create secret generic db-password \
  --from-file=password=db-password.txt

# Limpar arquivo
rm db-password.txt
```

**Saída esperada:**
```
secret/db-password created
```

### Verificar

```bash
kubectl get secret db-password -o jsonpath='{.data.password}' | base64 -d
```

**Saída esperada:**
```
SuperSecret123
```

### Exemplo 2: Múltiplos Arquivos

```bash
# Criar arquivos
echo -n 'admin' > username.txt
echo -n 'SuperSecret123' > password.txt
echo -n 'myapp_db' > database.txt

# Criar Secret
kubectl create secret generic db-config \
  --from-file=username.txt \
  --from-file=password.txt \
  --from-file=database.txt

# Limpar arquivos
rm username.txt password.txt database.txt
```

**Saída esperada:**
```
secret/db-config created
```

### Verificar

```bash
kubectl describe secret db-config
```

**Saída esperada:**
```
Name:         db-config
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
database.txt:  9 bytes
password.txt:  15 bytes
username.txt:  5 bytes
```

### Exemplo 3: Arquivo de Configuração JSON

```bash
# Criar arquivo JSON
cat > app-config.json << 'EOF'
{
  "api_url": "https://api.example.com",
  "api_key": "sk-1234567890",
  "timeout": 30,
  "retry": 3
}
EOF

# Criar Secret
kubectl create secret generic app-config \
  --from-file=config.json=app-config.json

# Limpar
rm app-config.json
```

**Saída esperada:**
```
secret/app-config created
```

### Verificar JSON

```bash
kubectl get secret app-config -o jsonpath='{.data.config\.json}' | base64 -d | jq
```

**Saída esperada:**
```json
{
  "api_url": "https://api.example.com",
  "api_key": "sk-1234567890",
  "timeout": 30,
  "retry": 3
}
```

### Exemplo 4: Chave SSH

```bash
# Gerar chave SSH
ssh-keygen -t rsa -b 2048 -f myapp-key -N ""

# Criar Secret
kubectl create secret generic ssh-keys \
  --from-file=private-key=myapp-key \
  --from-file=public-key=myapp-key.pub

# Limpar
rm myapp-key myapp-key.pub
```

**Saída esperada:**
```
secret/ssh-keys created
```

## Método 3: YAML com data (Base64 Manual)

### Estrutura

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
data:
  key1: <valor-base64>
  key2: <valor-base64>
```

### Exemplo 1: Secret Básico

```bash
# Codificar valores
echo -n 'admin' | base64
# Saída: YWRtaW4=

echo -n 'SuperSecret123' | base64
# Saída: U3VwZXJTZWNyZXQxMjM=
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-creds-yaml
  labels:
    app: myapp
    tier: database
type: Opaque
data:
  username: YWRtaW4=
  password: U3VwZXJTZWNyZXQxMjM=
```

```bash
kubectl apply -f db-creds-yaml.yaml
```

**Saída esperada:**
```
secret/db-creds-yaml created
```

### Exemplo 2: Secret com Múltiplas Chaves

```bash
# Codificar valores
echo -n 'postgresql://user:pass@db.example.com:5432/mydb' | base64
# Saída: cG9zdGdyZXNxbDovL3VzZXI6cGFzc0BkYi5leGFtcGxlLmNvbTo1NDMyL215ZGI=

echo -n 'sk-1234567890abcdef' | base64
# Saída: c2stMTIzNDU2Nzg5MGFiY2RlZg==

echo -n 'my-jwt-secret-key' | base64
# Saída: bXktand0LXNlY3JldC1rZXk=
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: default
  labels:
    app: myapp
    environment: production
  annotations:
    description: "Application secrets for production"
    owner: "platform-team"
type: Opaque
data:
  database-url: cG9zdGdyZXNxbDovL3VzZXI6cGFzc0BkYi5leGFtcGxlLmNvbTo1NDMyL215ZGI=
  api-key: c2stMTIzNDU2Nzg5MGFiY2RlZg==
  jwt-secret: bXktand0LXNlY3JldC1rZXk=
```

```bash
kubectl apply -f app-secrets.yaml
```

**Saída esperada:**
```
secret/app-secrets created
```

## Método 4: YAML com stringData (Texto Plano)

### Estrutura

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
stringData:
  key1: valor-texto-plano
  key2: outro-valor
```

**Importante:** `stringData` é convertido automaticamente para base64 e armazenado em `data`.

### Exemplo 1: Secret Simples

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-simple
type: Opaque
stringData:
  username: admin
  password: SuperSecret123
  host: mysql.example.com
  port: "3306"
```

```bash
kubectl apply -f db-simple.yaml
```

**Saída esperada:**
```
secret/db-simple created
```

### Verificar Conversão

```bash
kubectl get secret db-simple -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  host: bXlzcWwuZXhhbXBsZS5jb20=
  password: U3VwZXJTZWNyZXQxMjM=
  port: MzMwNg==
  username: YWRtaW4=
kind: Secret
metadata:
  name: db-simple
type: Opaque
```

### Exemplo 2: Secret com Dados Multilinhas

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-config-multi
type: Opaque
stringData:
  database-url: "postgresql://user:pass@db.example.com:5432/mydb"
  api-key: "sk-1234567890abcdef"
  config.json: |
    {
      "api_url": "https://api.example.com",
      "timeout": 30,
      "retry": 3
    }
  script.sh: |
    #!/bin/bash
    echo "Running backup..."
    mysqldump -u $DB_USER -p$DB_PASS mydb > backup.sql
```

```bash
kubectl apply -f app-config-multi.yaml
```

**Saída esperada:**
```
secret/app-config-multi created
```

### Verificar Conteúdo Multilinha

```bash
kubectl get secret app-config-multi -o jsonpath='{.data.config\.json}' | base64 -d
echo
kubectl get secret app-config-multi -o jsonpath='{.data.script\.sh}' | base64 -d
```

**Saída esperada:**
```json
{
  "api_url": "https://api.example.com",
  "timeout": 30,
  "retry": 3
}

#!/bin/bash
echo "Running backup..."
mysqldump -u $DB_USER -p$DB_PASS mydb > backup.sql
```

### Exemplo 3: Misturando data e stringData

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mixed-secret
type: Opaque
data:
  # Já em base64
  encrypted-key: bXktZW5jcnlwdGVkLWtleQ==
stringData:
  # Texto plano (será convertido)
  api-key: sk-1234567890
  password: SuperSecret123
```

```bash
kubectl apply -f mixed-secret.yaml
```

**Nota:** Se a mesma chave existir em `data` e `stringData`, o valor de `stringData` prevalece.

## Método 5: kubectl dry-run (Gerar YAML)

### Sintaxe

```bash
kubectl create secret generic <nome> \
  --from-literal=<chave>=<valor> \
  --dry-run=client -o yaml > secret.yaml
```

### Exemplo 1: Gerar YAML a partir de Literais

```bash
kubectl create secret generic api-credentials \
  --from-literal=api-key=sk-1234567890 \
  --from-literal=api-secret=secret-abcdef \
  --dry-run=client -o yaml > api-credentials.yaml
```

**Conteúdo de api-credentials.yaml:**
```yaml
apiVersion: v1
data:
  api-key: c2stMTIzNDU2Nzg5MA==
  api-secret: c2VjcmV0LWFiY2RlZg==
kind: Secret
metadata:
  creationTimestamp: null
  name: api-credentials
type: Opaque
```

### Editar e Aplicar

```bash
# Editar arquivo (adicionar labels, annotations, etc.)
vim api-credentials.yaml

# Aplicar
kubectl apply -f api-credentials.yaml
```

**Saída esperada:**
```
secret/api-credentials created
```

### Exemplo 2: Gerar YAML a partir de Arquivos

```bash
# Criar arquivos
echo -n 'admin' > user.txt
echo -n 'pass123' > pass.txt

# Gerar YAML
kubectl create secret generic file-secret \
  --from-file=username=user.txt \
  --from-file=password=pass.txt \
  --dry-run=client -o yaml > file-secret.yaml

# Limpar
rm user.txt pass.txt

# Aplicar
kubectl apply -f file-secret.yaml
```

## Exemplo Prático Completo: Aplicação com Secret

### 1. Criar Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
  labels:
    app: webapp
type: Opaque
stringData:
  # Database
  DB_HOST: postgres.example.com
  DB_PORT: "5432"
  DB_NAME: webapp_db
  DB_USER: webapp_user
  DB_PASSWORD: SuperSecret123
  
  # API Keys
  STRIPE_API_KEY: sk_test_1234567890
  SENDGRID_API_KEY: SG.1234567890abcdef
  
  # JWT
  JWT_SECRET: my-super-secret-jwt-key-2024
  
  # Redis
  REDIS_URL: redis://:password@redis.example.com:6379/0
```

```bash
kubectl apply -f webapp-secrets.yaml
```

**Saída esperada:**
```
secret/webapp-secrets created
```

### 2. Deployment Usando o Secret

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
      - name: app
        image: myapp:latest
        ports:
        - containerPort: 8080
        
        # Injetar todas as variáveis do Secret
        envFrom:
        - secretRef:
            name: webapp-secrets
        
        # Ou injetar variáveis específicas
        env:
        - name: DATABASE_URL
          value: "postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)"
```

```bash
kubectl apply -f webapp-deployment.yaml
```

**Saída esperada:**
```
deployment.apps/webapp created
```

### 3. Verificar Variáveis no Pod

```bash
# Obter nome do Pod
POD_NAME=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')

# Verificar variáveis de ambiente
kubectl exec $POD_NAME -- env | grep -E "DB_|STRIPE|JWT|REDIS"
```

**Saída esperada:**
```
DB_HOST=postgres.example.com
DB_PORT=5432
DB_NAME=webapp_db
DB_USER=webapp_user
DB_PASSWORD=SuperSecret123
STRIPE_API_KEY=sk_test_1234567890
SENDGRID_API_KEY=SG.1234567890abcdef
JWT_SECRET=my-super-secret-jwt-key-2024
REDIS_URL=redis://:password@redis.example.com:6379/0
DATABASE_URL=postgresql://webapp_user:SuperSecret123@postgres.example.com:5432/webapp_db
```

## Comandos Úteis

### Criar

```bash
# Literal
kubectl create secret generic my-secret --from-literal=key=value

# Arquivo
kubectl create secret generic my-secret --from-file=key=file.txt

# Múltiplos valores
kubectl create secret generic my-secret \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --from-file=key3=file.txt

# Com namespace
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --namespace=production
```

### Listar

```bash
# Todos os Secrets
kubectl get secrets

# Secrets Opaque
kubectl get secrets --field-selector type=Opaque

# Com detalhes
kubectl get secrets -o wide

# Formato YAML
kubectl get secret my-secret -o yaml

# Formato JSON
kubectl get secret my-secret -o json
```

### Visualizar

```bash
# Descrever
kubectl describe secret my-secret

# Ver chaves
kubectl get secret my-secret -o jsonpath='{.data}' | jq 'keys'

# Decodificar chave específica
kubectl get secret my-secret -o jsonpath='{.data.key}' | base64 -d

# Decodificar todas as chaves
kubectl get secret my-secret -o json | jq -r '.data | map_values(@base64d)'
```

### Editar

```bash
# Editar interativamente
kubectl edit secret my-secret

# Patch
kubectl patch secret my-secret -p '{"stringData":{"newkey":"newvalue"}}'

# Substituir
kubectl create secret generic my-secret \
  --from-literal=key=newvalue \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Deletar

```bash
# Deletar Secret
kubectl delete secret my-secret

# Deletar múltiplos
kubectl delete secret secret1 secret2

# Deletar por label
kubectl delete secret -l app=myapp
```

## Boas Práticas

### 1. Naming Convention

```yaml
metadata:
  name: <app>-<tipo>-<ambiente>
  # Exemplos:
  # webapp-db-prod
  # api-tokens-staging
  # cache-credentials-dev
```

### 2. Labels e Annotations

```yaml
metadata:
  name: my-secret
  labels:
    app: myapp
    component: database
    environment: production
    managed-by: terraform
  annotations:
    description: "Database credentials for production"
    owner: "platform-team@example.com"
    created-by: "automation"
    rotation-date: "2026-03-01"
```

### 3. Organização por Namespace

```bash
# Desenvolvimento
kubectl create namespace dev
kubectl create secret generic db-creds --from-literal=pass=dev123 -n dev

# Produção
kubectl create namespace prod
kubectl create secret generic db-creds --from-literal=pass=prod456 -n prod
```

### 4. Não Commitar Secrets no Git

```bash
# .gitignore
*.secret.yaml
secrets/
*-secret.yaml
credentials/
```

### 5. Usar stringData em Desenvolvimento

```yaml
# dev-secret.yaml (não commitar!)
apiVersion: v1
kind: Secret
metadata:
  name: dev-secret
type: Opaque
stringData:
  password: dev-password-123
```

### 6. Usar data em Produção (CI/CD)

```bash
# Pipeline CI/CD
PASSWORD=$(vault read -field=password secret/prod/db)
PASSWORD_B64=$(echo -n "$PASSWORD" | base64)

cat > prod-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: prod-secret
type: Opaque
data:
  password: $PASSWORD_B64
EOF

kubectl apply -f prod-secret.yaml
```

### 7. Validar Secrets

```bash
# Dry-run
kubectl apply -f secret.yaml --dry-run=client

# Validar no servidor
kubectl apply -f secret.yaml --dry-run=server

# Verificar após criação
kubectl get secret my-secret -o jsonpath='{.data.key}' | base64 -d
```

## Troubleshooting

### Secret não Aparece

```bash
# Verificar namespace
kubectl get secrets --all-namespaces | grep my-secret

# Verificar nome exato
kubectl get secrets

# Ver eventos
kubectl get events --sort-by='.lastTimestamp'
```

### Valor Incorreto Após Decodificar

```bash
# Verificar espaços/quebras de linha
kubectl get secret my-secret -o jsonpath='{.data.key}' | base64 -d | od -c

# Recriar Secret
kubectl delete secret my-secret
echo -n 'correct-value' | base64
# Usar valor correto no YAML
```

### Pod não Consegue Acessar Secret

```bash
# Verificar se Secret existe
kubectl get secret my-secret

# Verificar namespace
kubectl get secret my-secret -n <namespace>

# Verificar referência no Pod
kubectl get pod my-pod -o yaml | grep -A 10 secret

# Ver logs do Pod
kubectl logs my-pod

# Descrever Pod
kubectl describe pod my-pod
```

## Limpeza

```bash
# Remover Secrets criados
kubectl delete secret db-credentials api-tokens db-password db-config app-config ssh-keys
kubectl delete secret db-creds-yaml app-secrets db-simple app-config-multi mixed-secret
kubectl delete secret api-credentials file-secret webapp-secrets

# Remover Deployment
kubectl delete deployment webapp
```

## Resumo

- **Opaque é o tipo padrão** para dados genéricos
- **5 métodos de criação:** literal, file, YAML data, YAML stringData, dry-run
- **stringData é mais fácil** (texto plano), mas **data é mais seguro** (não expõe valores)
- **kubectl literal** é rápido mas não versionável
- **YAML é recomendado** para produção (versionamento, CI/CD)
- **Sempre use labels e annotations** para organização
- **Nunca commite Secrets no Git**
- **Base64 não é criptografia** - use encryption at rest

## Próximos Passos

- Estudar **como usar Secrets em Pods** (env, volume)
- Implementar **Encryption at Rest**
- Integrar com **External Secrets Operator**
- Configurar **RBAC** para controle de acesso
- Automatizar **rotação de Secrets**
