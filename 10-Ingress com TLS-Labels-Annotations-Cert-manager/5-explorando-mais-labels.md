# Explorando um Pouco Mais as Labels

## Introdução

Labels são fundamentais no Kubernetes para organização, seleção e gerenciamento de recursos. Este guia explora conceitos avançados, padrões de uso, estratégias de organização e casos práticos reais.

## Anatomia de uma Label

### Estrutura Completa

```
[prefixo/]nome: valor

Exemplos:
app: nginx                           # Simples
kubernetes.io/cluster-service: true  # Com prefixo
example.com/team: backend            # Prefixo customizado
```

### Componentes

**Prefixo (opcional):**
- Formato: `dominio.com/`
- Máximo: 253 caracteres
- Deve ser um subdomínio DNS válido
- Recomendado para evitar conflitos

**Nome:**
- Obrigatório
- Máximo: 63 caracteres
- Regex: `[a-z0-9A-Z]([a-z0-9A-Z-_.]*[a-z0-9A-Z])?`
- Deve começar e terminar com alfanumérico

**Valor:**
- Máximo: 63 caracteres
- Mesmas regras do nome
- Pode ser vazio (`""`)

---

## Estratégias de Organização

### 1. Hierarquia de Aplicação

```yaml
# Nível 1: Plataforma
labels:
  platform: ecommerce

# Nível 2: Aplicação
labels:
  platform: ecommerce
  app: webstore

# Nível 3: Componente
labels:
  platform: ecommerce
  app: webstore
  component: frontend

# Nível 4: Instância
labels:
  platform: ecommerce
  app: webstore
  component: frontend
  instance: webstore-frontend-prod
```

### 2. Organização por Camadas (Tiers)

```yaml
# Camada de Apresentação
labels:
  tier: frontend
  layer: presentation
  
# Camada de Aplicação
labels:
  tier: backend
  layer: application
  
# Camada de Dados
labels:
  tier: database
  layer: data
  
# Camada de Cache
labels:
  tier: cache
  layer: data
```

### 3. Organização por Ambiente

```yaml
# Desenvolvimento
labels:
  environment: development
  env-type: non-prod
  region: us-east-1
  
# Staging
labels:
  environment: staging
  env-type: non-prod
  region: us-east-1
  
# Produção
labels:
  environment: production
  env-type: prod
  region: us-east-1
  ha: enabled
```

### 4. Organização por Equipe

```yaml
labels:
  team: backend
  squad: payments
  tribe: commerce
  owner: john-doe
  cost-center: engineering
  budget-code: ENG-2024-Q1
```

---

## Padrões de Labels Recomendados

### Labels Kubernetes Padrão

```yaml
metadata:
  labels:
    # Identificação da aplicação
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod-001
    app.kubernetes.io/version: "2.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ecommerce-platform
    app.kubernetes.io/managed-by: helm
    
    # Informações adicionais
    app.kubernetes.io/created-by: devops-team
```

### Labels Customizados Comuns

```yaml
metadata:
  labels:
    # Ambiente e região
    environment: production
    region: us-east-1
    zone: us-east-1a
    
    # Versionamento
    version: v2.0
    release: stable
    track: production
    
    # Organização
    tier: backend
    layer: application
    team: backend-team
    
    # Negócio
    customer: enterprise
    tenant: tenant-a
    criticality: high
    
    # Operacional
    monitoring: enabled
    backup: daily
    maintenance-window: weekend
```

---

## Label Selectors Avançados

### Equality-based Selectors

```bash
# Igual (=)
kubectl get pods -l app=nginx
kubectl get pods -l environment=production

# Diferente (!=)
kubectl get pods -l environment!=development
kubectl get pods -l tier!=cache

# Múltiplos (AND implícito)
kubectl get pods -l app=nginx,environment=production
kubectl get pods -l tier=backend,version=v2.0,region=us-east-1
```

### Set-based Selectors

```bash
# In (está em)
kubectl get pods -l 'environment in (production,staging)'
kubectl get pods -l 'tier in (frontend,backend)'

# NotIn (não está em)
kubectl get pods -l 'environment notin (development,test)'
kubectl get pods -l 'tier notin (cache,queue)'

# Exists (label existe)
kubectl get pods -l environment
kubectl get pods -l monitoring

# NotExists (label não existe)
kubectl get pods -l '!environment'
kubectl get pods -l '!deprecated'
```

### Combinações Complexas

```bash
# Múltiplos operadores
kubectl get pods -l 'environment in (production,staging),tier=backend'

# Exists + In
kubectl get pods -l 'monitoring,environment in (production,staging)'

# NotExists + NotIn
kubectl get pods -l '!deprecated,environment notin (development,test)'

# Tudo junto
kubectl get pods -l 'app=myapp,environment in (production,staging),tier!=cache,monitoring'
```

### Em Manifests YAML

```yaml
# Equality-based
selector:
  matchLabels:
    app: myapp
    tier: backend

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
  - key: monitoring
    operator: Exists
  - key: deprecated
    operator: DoesNotExist

# Combinado
selector:
  matchLabels:
    app: myapp
  matchExpressions:
  - key: environment
    operator: In
    values:
    - production
    - staging
```

---

## Casos de Uso Avançados

### 1. Canary Deployment com Pesos

```yaml
# Stable (90% do tráfego)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
  labels:
    app: myapp
    track: stable
    version: v1.0
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
        version: v1.0
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
    version: v2.0
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
        version: v2.0
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
  labels:
    app: myapp
spec:
  selector:
    app: myapp  # Seleciona stable e canary
  ports:
  - port: 80
```

```bash
# Monitorar canary
kubectl get pods -l track=canary
kubectl logs -l track=canary -f

# Aumentar canary gradualmente
kubectl scale deployment myapp-canary --replicas=2  # 20%
kubectl scale deployment myapp-canary --replicas=5  # 50%
kubectl scale deployment myapp-canary --replicas=10 # 100%

# Promover canary para stable
kubectl scale deployment myapp-stable --replicas=0
kubectl patch deployment myapp-canary -p '{"metadata":{"labels":{"track":"stable"}}}'
kubectl patch deployment myapp-canary -p '{"spec":{"template":{"metadata":{"labels":{"track":"stable"}}}}}'
```

### 2. Multi-Region Deployment

```yaml
# US East
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-us-east
  labels:
    app: myapp
    region: us-east-1
    geo: americas
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      region: us-east-1
  template:
    metadata:
      labels:
        app: myapp
        region: us-east-1
        geo: americas
        zone: us-east-1a
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        env:
        - name: REGION
          value: "us-east-1"

---
# EU West
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-eu-west
  labels:
    app: myapp
    region: eu-west-1
    geo: europe
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      region: eu-west-1
  template:
    metadata:
      labels:
        app: myapp
        region: eu-west-1
        geo: europe
        zone: eu-west-1a
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        env:
        - name: REGION
          value: "eu-west-1"

---
# Asia Pacific
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-ap-south
  labels:
    app: myapp
    region: ap-south-1
    geo: asia
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      region: ap-south-1
  template:
    metadata:
      labels:
        app: myapp
        region: ap-south-1
        geo: asia
        zone: ap-south-1a
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        env:
        - name: REGION
          value: "ap-south-1"
```

```bash
# Listar por região
kubectl get pods -l region=us-east-1
kubectl get pods -l region=eu-west-1

# Listar por geografia
kubectl get pods -l geo=americas
kubectl get pods -l geo=europe

# Escalar região específica
kubectl scale deployment myapp-us-east --replicas=5

# Ver distribuição
kubectl get pods -L region,geo,zone
```

### 3. Feature Flags com Labels

```yaml
# Feature habilitada
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-with-feature
  labels:
    app: myapp
    feature-new-ui: enabled
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      feature-new-ui: enabled
  template:
    metadata:
      labels:
        app: myapp
        feature-new-ui: enabled
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        env:
        - name: FEATURE_NEW_UI
          value: "true"

---
# Feature desabilitada
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-without-feature
  labels:
    app: myapp
    feature-new-ui: disabled
spec:
  replicas: 8
  selector:
    matchLabels:
      app: myapp
      feature-new-ui: disabled
  template:
    metadata:
      labels:
        app: myapp
        feature-new-ui: disabled
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        env:
        - name: FEATURE_NEW_UI
          value: "false"
```

```bash
# Listar por feature
kubectl get pods -l feature-new-ui=enabled
kubectl get pods -l feature-new-ui=disabled

# Aumentar feature gradualmente
kubectl scale deployment myapp-with-feature --replicas=5    # 50%
kubectl scale deployment myapp-without-feature --replicas=5

# Habilitar para todos
kubectl scale deployment myapp-with-feature --replicas=10
kubectl scale deployment myapp-without-feature --replicas=0
```

### 4. A/B Testing

```yaml
# Variante A (controle)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-variant-a
  labels:
    app: myapp
    variant: a
    experiment: checkout-flow
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      variant: a
  template:
    metadata:
      labels:
        app: myapp
        variant: a
        experiment: checkout-flow
    spec:
      containers:
      - name: myapp
        image: myapp:variant-a
        env:
        - name: VARIANT
          value: "A"

---
# Variante B (teste)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-variant-b
  labels:
    app: myapp
    variant: b
    experiment: checkout-flow
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      variant: b
  template:
    metadata:
      labels:
        app: myapp
        variant: b
        experiment: checkout-flow
    spec:
      containers:
      - name: myapp
        image: myapp:variant-b
        env:
        - name: VARIANT
          value: "B"
```

```bash
# Monitorar variantes
kubectl get pods -l variant=a
kubectl get pods -l variant=b

# Ver logs por variante
kubectl logs -l variant=a -f
kubectl logs -l variant=b -f

# Métricas por variante
kubectl top pods -l variant=a
kubectl top pods -l variant=b

# Encerrar experimento (promover vencedor)
kubectl scale deployment myapp-variant-b --replicas=10
kubectl scale deployment myapp-variant-a --replicas=0
```

---

## Node Affinity com Labels

### Adicionar Labels aos Nodes

```bash
# Adicionar label a um node
kubectl label node node-1 disktype=ssd
kubectl label node node-1 gpu=nvidia-t4
kubectl label node node-1 workload=compute-intensive

# Adicionar a múltiplos nodes
kubectl label nodes node-2 node-3 disktype=nvme

# Ver labels dos nodes
kubectl get nodes --show-labels
kubectl get nodes -L disktype,gpu,workload
```

### Usar Node Affinity

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
spec:
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      # Requer nodes com SSD
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disktype
                operator: In
                values:
                - ssd
                - nvme
      containers:
      - name: postgres
        image: postgres:14
```

### Node Selector (Simples)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  nodeSelector:
    gpu: nvidia-t4
    workload: compute-intensive
  containers:
  - name: ml-app
    image: tensorflow/tensorflow:latest-gpu
```

---

## Pod Affinity e Anti-Affinity

### Pod Affinity (Agrupar Pods)

```yaml
# Backend deve estar no mesmo node que o cache
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - cache
            topologyKey: kubernetes.io/hostname
      containers:
      - name: backend
        image: backend:latest
```

### Pod Anti-Affinity (Separar Pods)

```yaml
# Distribuir réplicas em nodes diferentes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - frontend
              topologyKey: kubernetes.io/hostname
      containers:
      - name: frontend
        image: frontend:latest
```

---

## Network Policies com Labels

### Permitir Tráfego Específico

```yaml
# Permitir apenas backend acessar database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
```

### Isolar por Ambiente

```yaml
# Produção não pode acessar desenvolvimento
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: env-isolation
spec:
  podSelector:
    matchLabels:
      environment: production
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          environment: production
  egress:
  - to:
    - podSelector:
        matchLabels:
          environment: production
```

---

## Resource Quotas com Labels

### Quota por Equipe

```yaml
# Quota para equipe backend
apiVersion: v1
kind: ResourceQuota
metadata:
  name: backend-team-quota
  namespace: default
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values:
      - backend-priority
```

### Quota por Ambiente

```yaml
# Quota para produção
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    persistentvolumeclaims: "20"
  scopes:
  - NotTerminating
```

---

## Queries e Relatórios

### Listar Recursos com Labels Específicos

```bash
# Formato customizado
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
APP:.metadata.labels.app,\
ENV:.metadata.labels.environment,\
VERSION:.metadata.labels.version

# JSON Path
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.app}{"\n"}{end}'

# Filtrar e formatar
kubectl get pods -l app=myapp -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
NODE:.spec.nodeName,\
LABELS:.metadata.labels
```

### Relatórios por Equipe

```bash
# Contar pods por equipe
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | .metadata.labels.team' | \
  sort | uniq -c

# Recursos por equipe
kubectl get pods -l team=backend -o json | \
  jq -r '.items[] | "\(.metadata.name) \(.spec.containers[].resources.requests)"'

# Custo por equipe (simulado)
kubectl top pods -l team=backend --no-headers | \
  awk '{cpu+=$2; mem+=$3} END {print "CPU:", cpu, "Memory:", mem}'
```

### Auditoria de Labels

```bash
# Pods sem label de ambiente
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.metadata.labels.environment == null) | .metadata.name'

# Pods sem label de equipe
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.metadata.labels.team == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Verificar padrão de labels
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.metadata.labels."app.kubernetes.io/name" == null) | .metadata.name'
```

---

## Automação com Labels

### Script: Adicionar Labels em Massa

```bash
#!/bin/bash
# add-labels.sh

NAMESPACE="default"
LABEL_KEY="environment"
LABEL_VALUE="production"

# Adicionar label a todos os deployments
kubectl get deployments -n $NAMESPACE -o name | while read deployment; do
  kubectl label $deployment -n $NAMESPACE $LABEL_KEY=$LABEL_VALUE --overwrite
  echo "Added label to $deployment"
done

# Adicionar a todos os services
kubectl get services -n $NAMESPACE -o name | while read service; do
  kubectl label $service -n $NAMESPACE $LABEL_KEY=$LABEL_VALUE --overwrite
  echo "Added label to $service"
done
```

### Script: Validar Labels Obrigatórios

```bash
#!/bin/bash
# validate-labels.sh

REQUIRED_LABELS=("app" "environment" "team")

kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | 
    {
      name: .metadata.name,
      namespace: .metadata.namespace,
      labels: .metadata.labels
    }' | \
  jq -c '.' | while read pod; do
    name=$(echo $pod | jq -r '.name')
    namespace=$(echo $pod | jq -r '.namespace')
    
    for label in "${REQUIRED_LABELS[@]}"; do
      value=$(echo $pod | jq -r ".labels.$label // empty")
      if [ -z "$value" ]; then
        echo "WARNING: $namespace/$name missing label: $label"
      fi
    done
  done
```

---

## Boas Práticas Avançadas

### 1. Convenção de Nomenclatura

```yaml
# Usar prefixos para organização
labels:
  # Kubernetes padrão
  app.kubernetes.io/name: myapp
  app.kubernetes.io/version: "1.0.0"
  
  # Empresa
  company.com/team: backend
  company.com/cost-center: engineering
  
  # Ambiente
  env/type: production
  env/region: us-east-1
  
  # Negócio
  business/customer: enterprise
  business/sla: gold
```

### 2. Labels Imutáveis

```yaml
# Labels que não devem mudar
labels:
  app.kubernetes.io/name: myapp        # Nome da aplicação
  app.kubernetes.io/instance: myapp-001 # Instância única
  created-by: devops-team               # Criador
  created-at: "2024-03-13"              # Data de criação
```

### 3. Labels Dinâmicos

```yaml
# Labels que podem mudar
labels:
  version: v2.0           # Versão atual
  release: stable         # Release track
  health: healthy         # Status de saúde
  maintenance: false      # Em manutenção?
```

### 4. Hierarquia de Labels

```yaml
# Nível 1: Organização
labels:
  org: mycompany
  
# Nível 2: Divisão
labels:
  org: mycompany
  division: engineering
  
# Nível 3: Departamento
labels:
  org: mycompany
  division: engineering
  department: platform
  
# Nível 4: Equipe
labels:
  org: mycompany
  division: engineering
  department: platform
  team: infrastructure
```

---

## Resumo dos Comandos

```bash
# Adicionar labels
kubectl label pod mypod app=myapp
kubectl label pods -l tier=frontend environment=production

# Modificar labels
kubectl label pod mypod app=newapp --overwrite

# Remover labels
kubectl label pod mypod app-

# Listar com labels
kubectl get pods --show-labels
kubectl get pods -L app,environment,version

# Selectors
kubectl get pods -l app=myapp
kubectl get pods -l 'environment in (prod,staging)'
kubectl get pods -l app=myapp,tier=backend

# Queries avançadas
kubectl get pods -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels
kubectl get pods -o jsonpath='{.items[*].metadata.labels}'
```

---

## Conclusão

Labels são poderosos para:

✅ **Organização** - Estruturar recursos hierarquicamente  
✅ **Seleção** - Filtrar e agrupar recursos  
✅ **Roteamento** - Direcionar tráfego (Services, Ingress)  
✅ **Scheduling** - Affinity, anti-affinity, node selection  
✅ **Segurança** - Network Policies, RBAC  
✅ **Operações** - Canary, blue-green, A/B testing  
✅ **Governança** - Quotas, auditing, compliance  

Use labels estrategicamente para criar uma arquitetura organizada e gerenciável!
