# Estratégias de Atualização de Deployments

## Visão Geral

O Kubernetes oferece duas estratégias principais para atualizar Deployments:
1. **RollingUpdate** (padrão) - Atualização gradual
2. **Recreate** - Recria todos os pods

Cada estratégia tem casos de uso específicos e comportamentos diferentes.

---

## Estratégia 1: RollingUpdate (Padrão)

Atualiza pods gradualmente, mantendo a aplicação disponível durante o processo.

### Características

- **Zero downtime** - Aplicação continua disponível
- **Atualização gradual** - Pods são substituídos aos poucos
- **Rollback fácil** - Pode reverter se houver problema
- **Múltiplas versões** - Versões antiga e nova coexistem temporariamente

### Parâmetros

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # Pods extras permitidos durante update
    maxUnavailable: 0    # Pods indisponíveis permitidos
```

**maxSurge:**
- Número ou porcentagem de pods extras permitidos
- Exemplo: `maxSurge: 2` ou `maxSurge: 25%`
- Controla velocidade da atualização

**maxUnavailable:**
- Número ou porcentagem de pods que podem ficar indisponíveis
- Exemplo: `maxUnavailable: 1` ou `maxUnavailable: 25%`
- `0` = zero downtime garantido

---

## Exemplo 1: RollingUpdate Básico

```yaml
# deployment-rolling-basic.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
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
        image: nginx:1.21
        ports:
        - containerPort: 80
```

```bash
# Aplicar
kubectl apply -f deployment-rolling-basic.yaml

# Atualizar imagem
kubectl set image deployment/webapp webapp=nginx:1.22

# Observar rolling update
kubectl get pods -l app=webapp -w

# Ver eventos
kubectl describe deployment webapp | tail -20
```

**Comportamento:**
```
Estado Inicial:  [v1] [v1] [v1] [v1]
Passo 1:         [v1] [v1] [v1] [v1] [v2]  (maxSurge=1, adiciona v2)
Passo 2:         [v1] [v1] [v1] [v2]       (remove v1)
Passo 3:         [v1] [v1] [v1] [v2] [v2]  (adiciona v2)
Passo 4:         [v1] [v1] [v2] [v2]       (remove v1)
Passo 5:         [v1] [v1] [v2] [v2] [v2]  (adiciona v2)
Passo 6:         [v1] [v2] [v2] [v2]       (remove v1)
Passo 7:         [v1] [v2] [v2] [v2] [v2]  (adiciona v2)
Estado Final:    [v2] [v2] [v2] [v2]       (remove último v1)
```

---

## Exemplo 2: Zero Downtime (Alta Disponibilidade)

```yaml
# deployment-zero-downtime.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-prod
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2          # Permite 2 pods extras
      maxUnavailable: 0    # ZERO pods indisponíveis
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: myapi:v1
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 3
```

```bash
# Aplicar
kubectl apply -f deployment-zero-downtime.yaml

# Atualizar
kubectl set image deployment/api-prod api=myapi:v2

# Observar (sempre 6 ou mais pods disponíveis)
kubectl get deployment api-prod -w
```

**Comportamento:**
- Sempre mantém 6 pods disponíveis
- Pode ter até 8 pods durante atualização (6 + maxSurge 2)
- Garante zero downtime

---

## Exemplo 3: Atualização Rápida

```yaml
# deployment-fast-update.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-fast
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 5          # Permite 5 pods extras
      maxUnavailable: 3    # Permite 3 indisponíveis
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
        image: nginx:1.21
        ports:
        - containerPort: 80
```

```bash
# Aplicar
kubectl apply -f deployment-fast-update.yaml

# Atualizar (será mais rápido)
kubectl set image deployment/webapp-fast webapp=nginx:1.22

# Observar velocidade
time kubectl rollout status deployment/webapp-fast
```

**Comportamento:**
- Atualização mais rápida
- Pode ter até 15 pods durante update (10 + 5)
- Pode ter apenas 7 pods disponíveis (10 - 3)
- Trade-off: velocidade vs disponibilidade

---

## Exemplo 4: Atualização Conservadora

```yaml
# deployment-conservative.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-safe
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # Apenas 1 pod extra
      maxUnavailable: 0    # Zero indisponíveis
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
        image: nginx:1.21
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
```

```bash
# Aplicar
kubectl apply -f deployment-conservative.yaml

# Atualizar (será mais lento mas seguro)
kubectl set image deployment/webapp-safe webapp=nginx:1.22

# Observar (um pod por vez)
kubectl get pods -l app=webapp -w
```

**Comportamento:**
- Atualização mais lenta
- Máximo de 6 pods durante update (5 + 1)
- Sempre mantém 5 pods disponíveis
- Mais seguro para aplicações críticas

---

## Exemplo 5: Usando Porcentagens

```yaml
# deployment-percentage.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-percent
spec:
  replicas: 20
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%        # 25% de 20 = 5 pods extras
      maxUnavailable: 25%  # 25% de 20 = 5 pods indisponíveis
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
        image: nginx:1.21
        ports:
        - containerPort: 80
```

```bash
# Aplicar
kubectl apply -f deployment-percentage.yaml

# Atualizar
kubectl set image deployment/webapp-percent webapp=nginx:1.22

# Observar
kubectl get deployment webapp-percent -w
```

**Comportamento:**
- maxSurge 25% = 5 pods extras (25% de 20)
- maxUnavailable 25% = 5 pods indisponíveis (25% de 20)
- Pode ter 15-25 pods durante update
- Escala automaticamente com número de réplicas

---

## Estratégia 2: Recreate

Para todos os pods antes de criar novos. Causa downtime.

### Características

- **Downtime** - Aplicação fica indisponível durante update
- **Simples** - Para tudo, inicia novo
- **Sem coexistência** - Apenas uma versão por vez
- **Rápido** - Não precisa esperar gradualmente

### Quando Usar

- Aplicações stateful que não suportam múltiplas versões
- Aplicações que compartilham recursos (ex: banco de dados local)
- Quando downtime é aceitável
- Desenvolvimento/teste

---

## Exemplo 6: Recreate Básico

```yaml
# deployment-recreate.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
spec:
  replicas: 1
  strategy:
    type: Recreate
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
        image: postgres:14
        env:
        - name: POSTGRES_PASSWORD
          value: "senha123"
        ports:
        - containerPort: 5432
```

```bash
# Aplicar
kubectl apply -f deployment-recreate.yaml

# Atualizar
kubectl set image deployment/database postgres=postgres:15

# Observar (todos os pods param antes de novos iniciarem)
kubectl get pods -l app=database -w

# Ver eventos
kubectl describe deployment database | tail -20
```

**Comportamento:**
```
Estado Inicial:  [v1]
Passo 1:         []      (para v1)
Passo 2:         [v2]    (inicia v2)
Estado Final:    [v2]
```

---

## Exemplo 7: Recreate com Múltiplas Réplicas

```yaml
# deployment-recreate-multi.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stateful-app
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: stateful
  template:
    metadata:
      labels:
        app: stateful
    spec:
      containers:
      - name: app
        image: myapp:v1
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir: {}
```

```bash
# Aplicar
kubectl apply -f deployment-recreate-multi.yaml

# Atualizar
kubectl set image deployment/stateful-app app=myapp:v2

# Observar (todos os 3 pods param juntos)
kubectl get pods -l app=stateful -w
```

**Comportamento:**
```
Estado Inicial:  [v1] [v1] [v1]
Passo 1:         []              (para todos)
Passo 2:         [v2] [v2] [v2]  (inicia todos novos)
Estado Final:    [v2] [v2] [v2]
```

---

## Comparação de Estratégias

| Aspecto | RollingUpdate | Recreate |
|---------|---------------|----------|
| **Downtime** | Não | Sim |
| **Velocidade** | Gradual | Rápida |
| **Múltiplas versões** | Sim (temporário) | Não |
| **Complexidade** | Maior | Menor |
| **Uso de recursos** | Mais (pods extras) | Menos |
| **Rollback** | Fácil | Requer nova atualização |
| **Casos de uso** | Stateless apps | Stateful apps |

---

## Fluxo de Decisão

```
┌─────────────────────────────────────────────────────────┐
│         ESCOLHENDO ESTRATÉGIA DE ATUALIZAÇÃO            │
└─────────────────────────────────────────────────────────┘

PERGUNTAS:

1. Aplicação pode ter múltiplas versões rodando?
   ├─ SIM → RollingUpdate
   └─ NÃO → Recreate

2. Downtime é aceitável?
   ├─ SIM → Recreate (mais simples)
   └─ NÃO → RollingUpdate

3. Aplicação é stateless?
   ├─ SIM → RollingUpdate
   └─ NÃO → Considerar Recreate ou StatefulSet

4. Precisa de alta disponibilidade?
   ├─ SIM → RollingUpdate com maxUnavailable=0
   └─ NÃO → RollingUpdate padrão ou Recreate

5. Recursos limitados?
   ├─ SIM → RollingUpdate com maxSurge baixo ou Recreate
   └─ NÃO → RollingUpdate com maxSurge alto

RECOMENDAÇÕES:

Stateless Web App (Produção):
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

Stateless Web App (Desenvolvimento):
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1

Database/Stateful App:
  strategy:
    type: Recreate

Microserviço Crítico:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0
```

---

## Exemplo 8: Estratégia por Ambiente

```yaml
# deployment-prod.yaml (Produção)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-prod
  namespace: production
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0    # Zero downtime
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
        image: webapp:v1
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
---
# deployment-dev.yaml (Desenvolvimento)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-dev
  namespace: development
spec:
  replicas: 2
  strategy:
    type: Recreate    # Mais simples para dev
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
        image: webapp:latest
```

---

## Exemplo 9: Pausar e Controlar Atualização

```bash
# Criar deployment
kubectl create deployment webapp --image=nginx:1.21 --replicas=10

# Configurar estratégia
kubectl patch deployment webapp -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":2,"maxUnavailable":1}}}}'

# Iniciar atualização
kubectl set image deployment/webapp webapp=nginx:1.22

# Pausar no meio
kubectl rollout pause deployment/webapp

# Ver status (alguns pods atualizados, outros não)
kubectl get pods -l app=webapp -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# Verificar se está funcionando
kubectl port-forward deployment/webapp 8080:80
curl http://localhost:8080

# Retomar se tudo ok
kubectl rollout resume deployment/webapp

# Ou fazer rollback se houver problema
kubectl rollout undo deployment/webapp
```

---

## Exemplo 10: Canary Deployment (Manual)

```yaml
# deployment-stable.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: webapp
      version: stable
  template:
    metadata:
      labels:
        app: webapp
        version: stable
    spec:
      containers:
      - name: webapp
        image: webapp:v1
---
# deployment-canary.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
spec:
  replicas: 1    # Apenas 10% do tráfego
  selector:
    matchLabels:
      app: webapp
      version: canary
  template:
    metadata:
      labels:
        app: webapp
        version: canary
    spec:
      containers:
      - name: webapp
        image: webapp:v2
---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp    # Seleciona ambos (stable e canary)
  ports:
  - port: 80
    targetPort: 8080
```

```bash
# Aplicar
kubectl apply -f deployment-stable.yaml
kubectl apply -f deployment-canary.yaml
kubectl apply -f service.yaml

# Verificar distribuição (90% v1, 10% v2)
kubectl get pods -l app=webapp --show-labels

# Monitorar canary
kubectl logs -l version=canary -f

# Se ok, promover canary
kubectl scale deployment webapp-stable --replicas=0
kubectl scale deployment webapp-canary --replicas=10

# Ou reverter se houver problema
kubectl scale deployment webapp-canary --replicas=0
```

---

## Boas Práticas

### 1. Use RollingUpdate para Stateless

```yaml
# ✅ BOM
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### 2. Configure Readiness Probes

```yaml
# ✅ ESSENCIAL para RollingUpdate
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 3
```

### 3. Ajuste Parâmetros por Ambiente

```yaml
# Produção - conservador
maxSurge: 1
maxUnavailable: 0

# Staging - balanceado
maxSurge: 2
maxUnavailable: 1

# Dev - rápido
maxSurge: 3
maxUnavailable: 2
```

### 4. Monitore Atualizações

```bash
# Sempre acompanhe
kubectl rollout status deployment/<name>
kubectl get pods -l app=<name> -w
```

### 5. Teste Antes de Produção

```bash
# Testar em dev/staging primeiro
kubectl apply -f deployment.yaml --dry-run=server
kubectl diff -f deployment.yaml
```

---

## Troubleshooting

### RollingUpdate Travado

```bash
# Ver status
kubectl rollout status deployment/<name>

# Ver pods
kubectl get pods -l app=<name>

# Ver eventos
kubectl describe deployment <name>

# Problema comum: readiness probe falhando
kubectl describe pod <pod-name> | grep -A 10 Readiness

# Solução: corrigir probe ou aplicação
kubectl rollout undo deployment/<name>
```

### Recreate Muito Lento

```bash
# Ver por que pods não terminam
kubectl get pods -l app=<name>

# Ver eventos
kubectl describe pod <pod-name>

# Forçar deleção se necessário
kubectl delete pod <pod-name> --force --grace-period=0
```

---

## Resumo

**RollingUpdate:**
- Atualização gradual sem downtime
- Configurável via maxSurge e maxUnavailable
- Ideal para aplicações stateless
- Requer readiness probes

**Recreate:**
- Para todos os pods antes de criar novos
- Causa downtime
- Mais simples
- Ideal para aplicações stateful

**Escolha baseada em:**
- Tipo de aplicação (stateless vs stateful)
- Tolerância a downtime
- Recursos disponíveis
- Ambiente (prod vs dev)

**Parâmetros importantes:**
- `maxSurge`: Pods extras permitidos
- `maxUnavailable`: Pods indisponíveis permitidos
- `readinessProbe`: Essencial para RollingUpdate
