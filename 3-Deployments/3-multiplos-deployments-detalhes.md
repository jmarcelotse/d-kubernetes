# Criando Múltiplos Deployments e Vendo Detalhes

## Visão Geral

Este guia mostra como criar vários Deployments e inspecionar seus detalhes usando diferentes comandos do kubectl.

---

## Exemplo 1: Criar Múltiplos Deployments Simples

```bash
# Deployment 1 - Nginx
kubectl create deployment nginx --image=nginx:alpine --replicas=3

# Deployment 2 - Apache
kubectl create deployment apache --image=httpd:alpine --replicas=2

# Deployment 3 - Redis
kubectl create deployment redis --image=redis:alpine --replicas=1

# Listar todos
kubectl get deployments
kubectl get deploy

# Saída esperada:
# NAME     READY   UP-TO-DATE   AVAILABLE   AGE
# nginx    3/3     3            3           30s
# apache   2/2     2            2           20s
# redis    1/1     1            1           10s
```

---

## Exemplo 2: Ver Detalhes dos Deployments

### Comando get com Detalhes

```bash
# Listar com mais informações
kubectl get deployments -o wide

# Saída mostra: IMAGES, SELECTOR

# Ver em formato YAML
kubectl get deployment nginx -o yaml

# Ver em formato JSON
kubectl get deployment nginx -o json

# Ver campos específicos
kubectl get deployment nginx -o jsonpath='{.spec.replicas}'
kubectl get deployment nginx -o jsonpath='{.spec.template.spec.containers[0].image}'

# Listar com labels
kubectl get deployments --show-labels
```

### Comando describe (Detalhes Completos)

```bash
# Ver detalhes completos do nginx
kubectl describe deployment nginx

# Saída inclui:
# - Name, Namespace, Labels, Annotations
# - Replicas (desired, updated, available)
# - StrategyType
# - Pod Template (containers, images, ports)
# - Conditions
# - Events
```

**Exemplo de saída:**
```
Name:                   nginx
Namespace:              default
CreationTimestamp:      Tue, 03 Mar 2026 11:00:00 -0300
Labels:                 app=nginx
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=nginx
Replicas:               3 desired | 3 updated | 3 total | 3 available
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=nginx
  Containers:
   nginx:
    Image:        nginx:alpine
    Port:         <none>
    Host Port:    <none>
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  1m    deployment-controller  Scaled up replica set nginx-xxx to 3
```

---

## Exemplo 3: Ver Pods dos Deployments

```bash
# Ver todos os pods
kubectl get pods

# Ver pods de um deployment específico
kubectl get pods -l app=nginx

# Ver pods com mais detalhes
kubectl get pods -o wide

# Ver pods de todos os deployments
kubectl get pods --show-labels

# Ver pods e seus nodes
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
```

---

## Exemplo 4: Ver ReplicaSets

```bash
# Listar ReplicaSets
kubectl get replicasets
kubectl get rs

# Ver ReplicaSet de um deployment
kubectl get rs -l app=nginx

# Detalhes do ReplicaSet
kubectl describe rs <replicaset-name>

# Ver hierarquia
kubectl get deployment nginx
kubectl get rs -l app=nginx
kubectl get pods -l app=nginx
```

---

## Exemplo 5: Criar Deployments com Manifesto e Ver Detalhes

```yaml
# deployments-multiplos.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    tier: frontend
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
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: node
        image: node:18-alpine
        command: ["node", "-e", "require('http').createServer((req,res)=>res.end('Backend')).listen(3000)"]
        ports:
        - containerPort: 3000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  labels:
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:14-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: "senha123"
        ports:
        - containerPort: 5432
```

```bash
# Aplicar
kubectl apply -f deployments-multiplos.yaml

# Ver todos os deployments
kubectl get deployments

# Ver por tier
kubectl get deployments -l tier=frontend
kubectl get deployments -l tier=backend
kubectl get deployments -l tier=database

# Ver detalhes de cada um
kubectl describe deployment frontend
kubectl describe deployment backend
kubectl describe deployment database

# Ver todos os recursos criados
kubectl get all

# Ver pods por tier
kubectl get pods -l tier=frontend
kubectl get pods -l tier=backend
kubectl get pods -l tier=database
```

---

## Exemplo 6: Inspecionar Detalhes Específicos

### Ver Imagens Usadas

```bash
# Ver imagem de um deployment
kubectl get deployment nginx -o jsonpath='{.spec.template.spec.containers[0].image}'

# Ver imagens de todos os deployments
kubectl get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

### Ver Réplicas

```bash
# Ver réplicas de um deployment
kubectl get deployment nginx -o jsonpath='{.spec.replicas}'

# Ver réplicas de todos
kubectl get deployments -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas,AVAILABLE:.status.availableReplicas
```

### Ver Estratégia de Atualização

```bash
# Ver estratégia
kubectl get deployment nginx -o jsonpath='{.spec.strategy}'

# Ver detalhes da estratégia
kubectl describe deployment nginx | grep -A 5 "StrategyType"
```

### Ver Seletores

```bash
# Ver selector
kubectl get deployment nginx -o jsonpath='{.spec.selector}'

# Ver labels do template
kubectl get deployment nginx -o jsonpath='{.spec.template.metadata.labels}'
```

---

## Exemplo 7: Ver Eventos dos Deployments

```bash
# Ver eventos de um deployment
kubectl describe deployment nginx | grep -A 20 Events

# Ver todos os eventos do namespace
kubectl get events --sort-by='.lastTimestamp'

# Ver eventos de um deployment específico
kubectl get events --field-selector involvedObject.name=nginx

# Ver eventos recentes
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

---

## Exemplo 8: Comparar Múltiplos Deployments

```bash
# Criar script para comparar
cat > compare-deployments.sh <<'EOF'
#!/bin/bash
echo "DEPLOYMENT COMPARISON"
echo "===================="
for deploy in $(kubectl get deployments -o name); do
  name=$(echo $deploy | cut -d'/' -f2)
  replicas=$(kubectl get $deploy -o jsonpath='{.spec.replicas}')
  image=$(kubectl get $deploy -o jsonpath='{.spec.template.spec.containers[0].image}')
  available=$(kubectl get $deploy -o jsonpath='{.status.availableReplicas}')
  echo "$name: $replicas replicas, Image: $image, Available: $available"
done
EOF

chmod +x compare-deployments.sh
./compare-deployments.sh
```

---

## Exemplo 9: Ver Status Detalhado

```bash
# Status de um deployment
kubectl rollout status deployment/nginx

# Ver histórico de revisões
kubectl rollout history deployment/nginx

# Ver detalhes de uma revisão
kubectl rollout history deployment/nginx --revision=1

# Ver condições do deployment
kubectl get deployment nginx -o jsonpath='{.status.conditions[*].type}'
kubectl get deployment nginx -o jsonpath='{.status.conditions[*].status}'
```

---

## Exemplo 10: Monitorar Deployments em Tempo Real

```bash
# Watch deployments
kubectl get deployments --watch
kubectl get deployments -w

# Watch pods
kubectl get pods -l app=nginx --watch

# Watch events
kubectl get events --watch

# Em terminais separados:
# Terminal 1:
kubectl get deployments -w

# Terminal 2:
kubectl scale deployment nginx --replicas=5

# Terminal 1 mostrará mudanças em tempo real
```

---

## Fluxo de Inspeção de Deployments

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE INSPEÇÃO DE DEPLOYMENTS                │
└─────────────────────────────────────────────────────────┘

1. LISTAR DEPLOYMENTS
   └─> kubectl get deployments

2. VER DETALHES BÁSICOS
   └─> kubectl get deployment <name> -o wide

3. VER DETALHES COMPLETOS
   └─> kubectl describe deployment <name>

4. INSPECIONAR PODS
   ├─> kubectl get pods -l app=<label>
   └─> kubectl describe pod <pod-name>

5. VER REPLICASETS
   ├─> kubectl get rs -l app=<label>
   └─> kubectl describe rs <rs-name>

6. VER EVENTOS
   └─> kubectl get events --field-selector involvedObject.name=<name>

7. VER HISTÓRICO
   └─> kubectl rollout history deployment/<name>

8. EXPORTAR YAML
   └─> kubectl get deployment <name> -o yaml
```

---

## Comandos de Inspeção Úteis

### Listar e Filtrar

```bash
# Todos os deployments
kubectl get deployments

# Por namespace
kubectl get deployments -n <namespace>

# Todos os namespaces
kubectl get deployments --all-namespaces
kubectl get deployments -A

# Por label
kubectl get deployments -l app=nginx
kubectl get deployments -l tier=frontend

# Com seletor complexo
kubectl get deployments -l 'environment in (prod,staging)'
```

### Formatos de Saída

```bash
# Wide (mais colunas)
kubectl get deployments -o wide

# YAML
kubectl get deployment nginx -o yaml

# JSON
kubectl get deployment nginx -o json

# Custom columns
kubectl get deployments -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas,IMAGE:.spec.template.spec.containers[0].image

# JSONPath
kubectl get deployments -o jsonpath='{.items[*].metadata.name}'
```

### Detalhes e Descrição

```bash
# Describe completo
kubectl describe deployment <name>

# Describe com grep
kubectl describe deployment nginx | grep -A 5 "Replicas"
kubectl describe deployment nginx | grep -A 10 "Pod Template"
kubectl describe deployment nginx | grep -A 20 "Events"

# Ver apenas eventos
kubectl describe deployment nginx | tail -20
```

---

## Exemplo Prático Completo

```bash
# 1. Criar múltiplos deployments
kubectl create deployment web --image=nginx:alpine --replicas=3
kubectl create deployment api --image=node:18-alpine --replicas=2
kubectl create deployment cache --image=redis:alpine --replicas=1

# 2. Listar todos
kubectl get deployments

# 3. Ver detalhes de cada um
echo "=== WEB DEPLOYMENT ==="
kubectl describe deployment web

echo "=== API DEPLOYMENT ==="
kubectl describe deployment api

echo "=== CACHE DEPLOYMENT ==="
kubectl describe deployment cache

# 4. Ver pods de cada deployment
echo "=== WEB PODS ==="
kubectl get pods -l app=web

echo "=== API PODS ==="
kubectl get pods -l app=api

echo "=== CACHE PODS ==="
kubectl get pods -l app=cache

# 5. Ver ReplicaSets
kubectl get replicasets

# 6. Ver todos os recursos
kubectl get all

# 7. Ver em formato tabela customizada
kubectl get deployments -o custom-columns=\
NAME:.metadata.name,\
REPLICAS:.spec.replicas,\
AVAILABLE:.status.availableReplicas,\
IMAGE:.spec.template.spec.containers[0].image

# 8. Exportar para YAML
kubectl get deployment web -o yaml > web-deployment.yaml
kubectl get deployment api -o yaml > api-deployment.yaml
kubectl get deployment cache -o yaml > cache-deployment.yaml

# 9. Ver eventos
kubectl get events --sort-by='.lastTimestamp' | grep -E "web|api|cache"

# 10. Limpar
kubectl delete deployment web api cache
```

---

## Comparação de Comandos

| Comando | Uso | Saída |
|---------|-----|-------|
| `kubectl get deployments` | Listar deployments | Tabela resumida |
| `kubectl get deployment <name> -o wide` | Mais detalhes | Tabela com IMAGES, SELECTOR |
| `kubectl describe deployment <name>` | Detalhes completos | Texto formatado detalhado |
| `kubectl get deployment <name> -o yaml` | Manifesto completo | YAML do recurso |
| `kubectl get deployment <name> -o json` | Manifesto JSON | JSON do recurso |
| `kubectl get pods -l app=<name>` | Pods do deployment | Tabela de pods |
| `kubectl get rs -l app=<name>` | ReplicaSets | Tabela de ReplicaSets |
| `kubectl get events` | Eventos | Lista de eventos |

---

## Troubleshooting

### Deployment não Aparece

```bash
# Verificar namespace
kubectl get deployments --all-namespaces

# Verificar se foi criado
kubectl get deployments -o name

# Ver eventos
kubectl get events
```

### Pods não Aparecem

```bash
# Ver ReplicaSet
kubectl get rs

# Ver eventos do deployment
kubectl describe deployment <name>

# Ver eventos dos pods
kubectl get events --sort-by='.lastTimestamp'
```

### Informações Incompletas

```bash
# Aguardar deployment estar pronto
kubectl rollout status deployment/<name>

# Ver condições
kubectl get deployment <name> -o jsonpath='{.status.conditions}'

# Ver status detalhado
kubectl describe deployment <name>
```

---

## Dicas Úteis

### 1. Usar Aliases

```bash
alias kgd='kubectl get deployments'
alias kdd='kubectl describe deployment'
alias kgp='kubectl get pods'
```

### 2. Watch para Monitorar

```bash
# Monitorar mudanças
watch kubectl get deployments
# ou
kubectl get deployments -w
```

### 3. Filtrar com Labels

```bash
# Adicionar labels ao criar
kubectl create deployment web --image=nginx
kubectl label deployment web tier=frontend

# Filtrar por label
kubectl get deployments -l tier=frontend
```

### 4. Exportar para Análise

```bash
# Exportar todos os deployments
kubectl get deployments -o yaml > all-deployments.yaml

# Exportar lista de imagens
kubectl get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}' > images.txt
```

### 5. Usar JSONPath para Dados Específicos

```bash
# Nome e réplicas
kubectl get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.replicas}{"\n"}{end}'

# Status de disponibilidade
kubectl get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.availableReplicas}/{.spec.replicas}{"\n"}{end}'
```

---

## Resumo

**Criar múltiplos deployments**:
- `kubectl create deployment` - Imperativo
- `kubectl apply -f` - Declarativo (múltiplos em um arquivo)

**Ver detalhes**:
- `kubectl get` - Listagem rápida
- `kubectl describe` - Detalhes completos
- `kubectl get -o yaml/json` - Manifesto completo

**Inspecionar recursos relacionados**:
- Pods: `kubectl get pods -l app=<name>`
- ReplicaSets: `kubectl get rs -l app=<name>`
- Eventos: `kubectl get events`

**Monitorar**:
- `kubectl get deployments -w` - Watch
- `kubectl rollout status` - Status de rollout
- `kubectl top pods` - Uso de recursos
