# O que são Annotations e Labels no Kubernetes?

## Introdução

Labels e Annotations são metadados que podem ser anexados a objetos do Kubernetes. Embora pareçam similares, têm propósitos e comportamentos diferentes. Este guia explica as diferenças, casos de uso e melhores práticas para cada um.

## Diferenças Fundamentais

### Comparação Rápida

| Aspecto | Labels | Annotations |
|---------|--------|-------------|
| **Propósito** | Identificar e selecionar objetos | Armazenar metadados não-identificadores |
| **Seleção** | Sim (via selectors) | Não |
| **Tamanho** | Limitado (63 caracteres) | Maior (256KB total) |
| **Estrutura** | Chave-valor simples | Pode conter JSON, YAML, etc. |
| **Uso** | Organização e agrupamento | Configuração e informações |
| **Indexação** | Sim (otimizado) | Não |

---

## Labels (Rótulos)

### O que são Labels?

Labels são pares chave-valor usados para **identificar, organizar e selecionar** objetos do Kubernetes. São essenciais para o funcionamento de Services, ReplicaSets, Deployments e outros recursos.

### Estrutura

```yaml
metadata:
  labels:
    key1: value1
    key2: value2
```

### Regras de Nomenclatura

**Chave:**
- Prefixo (opcional): `dominio.com/`
- Nome: até 63 caracteres
- Caracteres permitidos: `[a-z0-9A-Z]`, `-`, `_`, `.`
- Deve começar e terminar com alfanumérico

**Valor:**
- Até 63 caracteres
- Mesmas regras da chave
- Pode ser vazio

### Exemplos Válidos

```yaml
metadata:
  labels:
    # Simples
    app: nginx
    version: v1.0
    environment: production
    
    # Com prefixo
    example.com/team: backend
    kubernetes.io/cluster-service: "true"
    
    # Hierárquico
    tier: frontend
    release: stable
```

---

## Annotations (Anotações)

### O que são Annotations?

Annotations são pares chave-valor usados para armazenar **metadados arbitrários** que não são usados para identificação ou seleção. São úteis para ferramentas, bibliotecas e informações descritivas.

### Estrutura

```yaml
metadata:
  annotations:
    key1: value1
    key2: "valor com espaços e caracteres especiais"
    key3: |
      Valor
      multilinha
```

### Regras de Nomenclatura

**Chave:**
- Mesmas regras das labels
- Prefixo recomendado para evitar conflitos

**Valor:**
- Até 256KB (total de todas annotations)
- Qualquer string (JSON, YAML, texto, etc.)
- Sem restrições de caracteres

### Exemplos Válidos

```yaml
metadata:
  annotations:
    # Informações descritivas
    description: "Aplicação web principal"
    maintainer: "team@example.com"
    
    # Configurações de ferramentas
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    
    # JSON estruturado
    config: '{"timeout": 30, "retries": 3}'
    
    # Informações de build
    build-date: "2024-03-12"
    git-commit: "abc123def456"
```

---

## Labels: Casos de Uso

### 1. Seleção de Pods por Services

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      tier: frontend
  template:
    metadata:
      labels:
        app: webapp
        tier: frontend
        version: v1.0
    spec:
      containers:
      - name: nginx
        image: nginx:alpine

---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
    tier: frontend
  ports:
  - port: 80
    targetPort: 80
```

### 2. Organização por Ambiente

```yaml
# production
metadata:
  labels:
    app: myapp
    environment: production
    tier: backend

# staging
metadata:
  labels:
    app: myapp
    environment: staging
    tier: backend

# development
metadata:
  labels:
    app: myapp
    environment: development
    tier: backend
```

```bash
# Listar por ambiente
kubectl get pods -l environment=production
kubectl get pods -l environment=staging

# Listar por tier
kubectl get pods -l tier=backend
kubectl get pods -l tier=frontend

# Múltiplos labels
kubectl get pods -l app=myapp,environment=production
```

### 3. Versionamento e Releases

```yaml
metadata:
  labels:
    app: api
    version: v2.0
    release: stable
```

```bash
# Listar por versão
kubectl get pods -l version=v2.0

# Listar por release
kubectl get pods -l release=stable
kubectl get pods -l release=canary

# Rollback (mudar selector do Service)
kubectl patch service api-service -p '{"spec":{"selector":{"version":"v1.0"}}}'
```

### 4. Equipes e Ownership

```yaml
metadata:
  labels:
    app: payment-service
    team: payments
    owner: john-doe
    cost-center: engineering
```

```bash
# Listar por equipe
kubectl get pods -l team=payments

# Listar por owner
kubectl get pods -l owner=john-doe

# Relatório de custos
kubectl get pods -l cost-center=engineering -o wide
```

---

## Annotations: Casos de Uso

### 1. Configuração de Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    # Nginx Ingress Controller
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    
    # Cert-Manager
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    
    # CORS
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### 2. Monitoramento (Prometheus)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  annotations:
    # Prometheus scraping
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
    prometheus.io/scheme: "http"
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
  - port: 9090
    name: metrics
```

### 3. Informações de Build e Deploy

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    # CI/CD
    build.date: "2024-03-12T10:30:00Z"
    build.number: "1234"
    git.commit: "abc123def456"
    git.branch: "main"
    
    # Deployment info
    deployed.by: "jenkins"
    deployed.at: "2024-03-12T11:00:00Z"
    
    # Change tracking
    change.ticket: "JIRA-1234"
    change.description: "Update to version 2.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:2.0
```

### 4. Documentação e Descrição

```yaml
apiVersion: v1
kind: Service
metadata:
  name: database-service
  annotations:
    description: "PostgreSQL database service for production"
    documentation: "https://wiki.example.com/database"
    contact: "dba-team@example.com"
    sla: "99.9%"
    backup-schedule: "daily at 2am UTC"
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
```

### 5. Configuração de Recursos AWS

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  annotations:
    # AWS Load Balancer
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    
    # EBS
    volume.beta.kubernetes.io/storage-class: "gp3"
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 80
```

---

## Label Selectors

### Equality-based (Baseado em Igualdade)

```bash
# Igual
kubectl get pods -l environment=production
kubectl get pods -l tier=frontend

# Diferente
kubectl get pods -l environment!=development

# Múltiplos (AND)
kubectl get pods -l app=myapp,environment=production
```

### Set-based (Baseado em Conjunto)

```bash
# In (está em)
kubectl get pods -l 'environment in (production,staging)'

# NotIn (não está em)
kubectl get pods -l 'environment notin (development,test)'

# Exists (existe)
kubectl get pods -l environment

# NotExists (não existe)
kubectl get pods -l '!environment'
```

### Em Manifests YAML

```yaml
# Equality-based
selector:
  matchLabels:
    app: myapp
    tier: frontend

# Set-based
selector:
  matchExpressions:
  - key: environment
    operator: In
    values:
    - production
    - staging
  - key: tier
    operator: NotIn
    values:
    - cache
  - key: version
    operator: Exists
```

---

## Gerenciamento de Labels

### Adicionar Labels

```bash
# Adicionar label a um pod
kubectl label pod mypod environment=production

# Adicionar a múltiplos pods
kubectl label pods -l app=myapp tier=frontend

# Adicionar a todos os pods de um namespace
kubectl label pods --all environment=production -n default
```

### Modificar Labels

```bash
# Modificar label existente (requer --overwrite)
kubectl label pod mypod environment=staging --overwrite

# Modificar múltiplos
kubectl label pods -l app=myapp version=v2.0 --overwrite
```

### Remover Labels

```bash
# Remover label (sufixo -)
kubectl label pod mypod environment-

# Remover de múltiplos
kubectl label pods -l app=myapp tier-
```

### Ver Labels

```bash
# Listar com labels
kubectl get pods --show-labels

# Listar labels específicos
kubectl get pods -L app,environment,version

# Ver labels de um recurso
kubectl get pod mypod -o jsonpath='{.metadata.labels}'

# Formato customizado
kubectl get pods -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels
```

---

## Gerenciamento de Annotations

### Adicionar Annotations

```bash
# Adicionar annotation
kubectl annotate pod mypod description="Main application pod"

# Adicionar a múltiplos
kubectl annotate pods -l app=myapp maintainer="team@example.com"

# Annotation com JSON
kubectl annotate pod mypod config='{"timeout":30,"retries":3}'
```

### Modificar Annotations

```bash
# Modificar (requer --overwrite)
kubectl annotate pod mypod description="Updated description" --overwrite
```

### Remover Annotations

```bash
# Remover annotation (sufixo -)
kubectl annotate pod mypod description-

# Remover múltiplas
kubectl annotate pod mypod description- maintainer-
```

### Ver Annotations

```bash
# Ver annotations de um recurso
kubectl get pod mypod -o jsonpath='{.metadata.annotations}'

# Formato YAML
kubectl get pod mypod -o yaml | grep -A 10 annotations

# Annotation específica
kubectl get pod mypod -o jsonpath='{.metadata.annotations.description}'
```

---

## Boas Práticas

### Labels

**✅ Fazer:**

```yaml
# Usar labels padronizados
labels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/instance: myapp-prod
  app.kubernetes.io/version: "1.0.0"
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: ecommerce
  app.kubernetes.io/managed-by: helm
```

```yaml
# Organizar por camadas
labels:
  tier: frontend
  layer: presentation
  
# Identificar ambiente
labels:
  environment: production
  region: us-east-1
  
# Versionamento
labels:
  version: v2.0
  release: stable
```

**❌ Evitar:**

```yaml
# Labels muito longos
labels:
  description: "This is a very long description that should be an annotation"
  
# Informações que mudam frequentemente
labels:
  last-updated: "2024-03-12T10:30:00Z"
  
# Dados sensíveis
labels:
  api-key: "secret123"
```

### Annotations

**✅ Fazer:**

```yaml
# Usar prefixos para evitar conflitos
annotations:
  mycompany.com/owner: "team-backend"
  mycompany.com/cost-center: "engineering"
  
# Informações descritivas
annotations:
  description: "Main API service"
  documentation: "https://docs.example.com"
  
# Configurações de ferramentas
annotations:
  prometheus.io/scrape: "true"
  nginx.ingress.kubernetes.io/rate-limit: "100"
```

**❌ Evitar:**

```yaml
# Usar para seleção (use labels)
annotations:
  app: myapp  # Deveria ser label
  
# Dados muito grandes (>256KB total)
annotations:
  large-data: "..." # Use ConfigMap ou Secret
```

---

## Labels Recomendados (Kubernetes)

### Labels Padrão

```yaml
metadata:
  labels:
    # Nome da aplicação
    app.kubernetes.io/name: myapp
    
    # Instância única
    app.kubernetes.io/instance: myapp-prod
    
    # Versão
    app.kubernetes.io/version: "1.0.0"
    
    # Componente dentro da aplicação
    app.kubernetes.io/component: database
    
    # Parte de uma aplicação maior
    app.kubernetes.io/part-of: ecommerce-platform
    
    # Ferramenta que gerencia
    app.kubernetes.io/managed-by: helm
```

### Exemplo Completo

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-backend
  labels:
    # Labels recomendados
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "2.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: myapp-platform
    app.kubernetes.io/managed-by: kubectl
    
    # Labels customizados
    environment: production
    tier: backend
    team: backend-team
  
  annotations:
    # Informações de build
    build.date: "2024-03-12T10:30:00Z"
    git.commit: "abc123"
    
    # Documentação
    description: "Backend API service"
    contact: "backend-team@example.com"
    
    # Monitoramento
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"

spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: myapp
      app.kubernetes.io/component: backend
  template:
    metadata:
      labels:
        app.kubernetes.io/name: myapp
        app.kubernetes.io/instance: myapp-prod
        app.kubernetes.io/version: "2.0.0"
        app.kubernetes.io/component: backend
        environment: production
    spec:
      containers:
      - name: backend
        image: myapp:2.0.0
        ports:
        - containerPort: 8080
        - containerPort: 9090
          name: metrics
```

---

## Exemplos Práticos

### Exemplo 1: Blue-Green Deployment

```yaml
# Blue (versão atual)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: myapp
        image: myapp:1.0

---
# Green (nova versão)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: myapp
        image: myapp:2.0

---
# Service (inicialmente aponta para blue)
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
    version: blue  # Mudar para green quando pronto
  ports:
  - port: 80
```

```bash
# Testar green
kubectl port-forward deployment/myapp-green 8080:80

# Mudar tráfego para green
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback para blue se necessário
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Exemplo 2: Canary Deployment

```yaml
# Stable (90% do tráfego)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
  labels:
    app: myapp
    track: stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp
        track: stable
    spec:
      containers:
      - name: myapp
        image: myapp:1.0

---
# Canary (10% do tráfego)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
  labels:
    app: myapp
    track: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp
        track: canary
    spec:
      containers:
      - name: myapp
        image: myapp:2.0

---
# Service (seleciona ambos)
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp  # Seleciona stable e canary
  ports:
  - port: 80
```

### Exemplo 3: Multi-Tenant

```yaml
# Tenant A
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-tenant-a
  labels:
    app: myapp
    tenant: tenant-a
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      tenant: tenant-a
  template:
    metadata:
      labels:
        app: myapp
        tenant: tenant-a
        tier: frontend
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        - name: TENANT_ID
          value: "tenant-a"

---
# Tenant B
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-tenant-b
  labels:
    app: myapp
    tenant: tenant-b
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      tenant: tenant-b
  template:
    metadata:
      labels:
        app: myapp
        tenant: tenant-b
        tier: frontend
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        - name: TENANT_ID
          value: "tenant-b"
```

```bash
# Listar por tenant
kubectl get pods -l tenant=tenant-a
kubectl get pods -l tenant=tenant-b

# Escalar tenant específico
kubectl scale deployment app-tenant-a --replicas=5

# Ver recursos por tenant
kubectl top pods -l tenant=tenant-a
```

---

## Resumo dos Comandos

```bash
# Labels
kubectl label pod mypod app=myapp
kubectl label pod mypod app=myapp --overwrite
kubectl label pod mypod app-
kubectl get pods -l app=myapp
kubectl get pods --show-labels

# Annotations
kubectl annotate pod mypod description="My app"
kubectl annotate pod mypod description="Updated" --overwrite
kubectl annotate pod mypod description-
kubectl get pod mypod -o jsonpath='{.metadata.annotations}'

# Selectors
kubectl get pods -l environment=production
kubectl get pods -l 'environment in (prod,staging)'
kubectl get pods -l app=myapp,tier=frontend
```

---

## Conclusão

**Labels:**
✅ Identificação e seleção  
✅ Organização e agrupamento  
✅ Roteamento de tráfego  
✅ Queries e filtros  

**Annotations:**
✅ Metadados descritivos  
✅ Configuração de ferramentas  
✅ Informações de build/deploy  
✅ Documentação  

Use labels para **organizar e selecionar**, annotations para **configurar e documentar**!
