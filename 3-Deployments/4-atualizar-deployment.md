# Como Atualizar um Deployment

## Visão Geral

Atualizar um Deployment no Kubernetes significa modificar sua especificação, geralmente para:
- Atualizar imagem do container
- Alterar número de réplicas
- Modificar variáveis de ambiente
- Ajustar recursos (CPU/memória)
- Mudar configurações

O Kubernetes realiza atualizações de forma controlada usando **Rolling Updates** por padrão.

---

## Métodos de Atualização

### 1. kubectl set image (Mais Comum)
### 2. kubectl apply -f (Declarativo)
### 3. kubectl edit (Interativo)
### 4. kubectl patch (Específico)
### 5. kubectl replace (Substituição completa)

---

## Método 1: kubectl set image

Atualiza a imagem do container de forma rápida.

### Exemplo 1: Atualizar Imagem Básico

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx:1.21 --replicas=3

# Ver versão atual
kubectl get deployment nginx -o jsonpath='{.spec.template.spec.containers[0].image}'

# Atualizar para nova versão
kubectl set image deployment/nginx nginx=nginx:1.22

# Acompanhar atualização
kubectl rollout status deployment/nginx

# Verificar nova versão
kubectl get deployment nginx -o jsonpath='{.spec.template.spec.containers[0].image}'

# Ver pods sendo atualizados
kubectl get pods -l app=nginx -w
```

### Exemplo 2: Atualizar Múltiplos Containers

```bash
# Criar deployment com 2 containers
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
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
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
      - name: sidecar
        image: busybox:1.35
        command: ["sh", "-c", "while true; do echo hello; sleep 10; done"]
EOF

# Atualizar ambos os containers
kubectl set image deployment/webapp nginx=nginx:1.22 sidecar=busybox:1.36

# Acompanhar
kubectl rollout status deployment/webapp
```

### Exemplo 3: Atualizar com Record

```bash
# Atualizar e registrar no histórico
kubectl set image deployment/nginx nginx=nginx:1.23 --record

# Ver histórico com comando registrado
kubectl rollout history deployment/nginx

# Saída mostra o comando usado
```

---

## Método 2: kubectl apply -f (Declarativo)

Atualiza via manifesto YAML - **método recomendado para produção**.

### Exemplo 4: Atualizar via Manifesto

```bash
# 1. Criar deployment inicial
cat > deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
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
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF

kubectl apply -f deployment.yaml

# 2. Editar manifesto (mudar imagem para 1.22)
sed -i 's/nginx:1.21/nginx:1.22/' deployment.yaml

# 3. Aplicar mudanças
kubectl apply -f deployment.yaml

# 4. Ver diferenças antes de aplicar (próxima vez)
kubectl diff -f deployment.yaml

# 5. Acompanhar
kubectl rollout status deployment/webapp
```

### Exemplo 5: Atualizar Múltiplos Campos

```bash
# Editar manifesto para mudar:
# - Imagem
# - Réplicas
# - Recursos
cat > deployment-updated.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 5                    # Era 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: v2              # Novo label
    spec:
      containers:
      - name: webapp
        image: nginx:1.23        # Era 1.22
        ports:
        - containerPort: 80
        env:                     # Novas variáveis
        - name: ENVIRONMENT
          value: "production"
        resources:
          requests:
            memory: "128Mi"      # Era 64Mi
            cpu: "200m"          # Era 100m
          limits:
            memory: "256Mi"      # Era 128Mi
            cpu: "500m"          # Era 200m
EOF

# Aplicar
kubectl apply -f deployment-updated.yaml

# Acompanhar
kubectl rollout status deployment/webapp
```

---

## Método 3: kubectl edit (Interativo)

Edita o deployment diretamente no editor.

### Exemplo 6: Editar Interativamente

```bash
# Abrir editor (vim/nano)
kubectl edit deployment nginx

# No editor, modificar:
# - spec.template.spec.containers[0].image
# - spec.replicas
# - Qualquer outro campo

# Salvar e sair
# Kubernetes aplica automaticamente

# Acompanhar
kubectl rollout status deployment/nginx
```

### Exemplo 7: Editar com Editor Específico

```bash
# Usar nano ao invés de vim
KUBE_EDITOR="nano" kubectl edit deployment nginx

# Ou definir permanentemente
export KUBE_EDITOR="nano"
kubectl edit deployment nginx
```

---

## Método 4: kubectl patch (Atualização Específica)

Atualiza campos específicos sem modificar o resto.

### Exemplo 8: Patch de Imagem

```bash
# Patch simples
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.23"}]}}}}'

# Patch de réplicas
kubectl patch deployment nginx -p '{"spec":{"replicas":5}}'

# Patch com arquivo
cat > patch.yaml <<EOF
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
EOF

kubectl patch deployment nginx --patch-file patch.yaml
```

### Exemplo 9: Patch de Variáveis de Ambiente

```bash
# Adicionar variável de ambiente
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","env":[{"name":"ENV","value":"prod"}]}]}}}}'

# Verificar
kubectl get deployment nginx -o jsonpath='{.spec.template.spec.containers[0].env}'
```

---

## Método 5: kubectl scale (Escalar Réplicas)

Atualiza apenas o número de réplicas.

### Exemplo 10: Escalar Deployment

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Escalar para 5
kubectl scale deployment nginx --replicas=5

# Verificar
kubectl get deployment nginx

# Escalar para baixo
kubectl scale deployment nginx --replicas=2

# Escalar múltiplos deployments
kubectl scale deployment nginx apache redis --replicas=3
```

---

## Rolling Update (Atualização Gradual)

O Kubernetes atualiza pods gradualmente para evitar downtime.

### Exemplo 11: Configurar Estratégia de Rolling Update

```yaml
# deployment-rolling.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2           # Máximo de pods extras durante update
      maxUnavailable: 1     # Máximo de pods indisponíveis
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
kubectl apply -f deployment-rolling.yaml

# Atualizar imagem
kubectl set image deployment/webapp webapp=nginx:1.22

# Observar rolling update
kubectl get pods -l app=webapp -w

# Ver eventos
kubectl describe deployment webapp | grep -A 20 Events
```

### Exemplo 12: Pausar e Retomar Rolling Update

```bash
# Iniciar atualização
kubectl set image deployment/webapp webapp=nginx:1.23

# Pausar no meio da atualização
kubectl rollout pause deployment/webapp

# Verificar status (pausado)
kubectl rollout status deployment/webapp

# Verificar pods (alguns atualizados, outros não)
kubectl get pods -l app=webapp

# Retomar atualização
kubectl rollout resume deployment/webapp

# Acompanhar conclusão
kubectl rollout status deployment/webapp
```

---

## Rollback (Reverter Atualização)

### Exemplo 13: Fazer Rollback

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx:1.21 --replicas=3

# Atualizar para versão com problema
kubectl set image deployment/nginx nginx=nginx:broken-tag

# Ver que falhou
kubectl rollout status deployment/nginx
kubectl get pods -l app=nginx

# Fazer rollback para versão anterior
kubectl rollout undo deployment/nginx

# Verificar
kubectl rollout status deployment/nginx
kubectl get pods -l app=nginx
```

### Exemplo 14: Rollback para Revisão Específica

```bash
# Ver histórico de revisões
kubectl rollout history deployment/nginx

# Ver detalhes de uma revisão
kubectl rollout history deployment/nginx --revision=2

# Fazer rollback para revisão específica
kubectl rollout undo deployment/nginx --to-revision=2

# Verificar
kubectl rollout status deployment/nginx
```

---

## Fluxo de Atualização

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE ROLLING UPDATE                         │
└─────────────────────────────────────────────────────────┘

1. USUÁRIO ATUALIZA DEPLOYMENT
   └─> kubectl set image deployment/nginx nginx=nginx:1.22

2. API SERVER PERSISTE MUDANÇA
   └─> Atualiza spec no etcd

3. DEPLOYMENT CONTROLLER DETECTA MUDANÇA
   ├─> Cria novo ReplicaSet com nova spec
   └─> Mantém ReplicaSet antigo

4. ROLLING UPDATE INICIA
   ├─> Escala novo ReplicaSet: 0 → 1 pod
   ├─> Aguarda pod ficar Ready
   ├─> Escala ReplicaSet antigo: 3 → 2 pods
   ├─> Repete até completar
   └─> Respeita maxSurge e maxUnavailable

5. ATUALIZAÇÃO COMPLETA
   ├─> Novo ReplicaSet: 3 pods (desired)
   ├─> ReplicaSet antigo: 0 pods (mantido para rollback)
   └─> Deployment atualizado

EXEMPLO COM 3 RÉPLICAS:
Estado Inicial:  [v1] [v1] [v1]
Passo 1:         [v1] [v1] [v1] [v2]  (maxSurge=1)
Passo 2:         [v1] [v1] [v2]       (remove v1)
Passo 3:         [v1] [v1] [v2] [v2]  (adiciona v2)
Passo 4:         [v1] [v2] [v2]       (remove v1)
Passo 5:         [v1] [v2] [v2] [v2]  (adiciona v2)
Estado Final:    [v2] [v2] [v2]       (remove último v1)
```

---

## Comandos de Gerenciamento de Rollout

```bash
# Ver status da atualização
kubectl rollout status deployment/<name>

# Ver histórico de revisões
kubectl rollout history deployment/<name>

# Ver detalhes de uma revisão
kubectl rollout history deployment/<name> --revision=<number>

# Pausar rollout
kubectl rollout pause deployment/<name>

# Retomar rollout
kubectl rollout resume deployment/<name>

# Fazer rollback
kubectl rollout undo deployment/<name>

# Rollback para revisão específica
kubectl rollout undo deployment/<name> --to-revision=<number>

# Reiniciar deployment (força recriação de pods)
kubectl rollout restart deployment/<name>
```

---

## Exemplo Prático Completo

```bash
# 1. Criar deployment inicial
kubectl create deployment webapp --image=nginx:1.21 --replicas=5

# 2. Verificar versão
kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'

# 3. Atualizar para v1.22
kubectl set image deployment/webapp webapp=nginx:1.22

# 4. Acompanhar atualização em tempo real
kubectl get pods -l app=webapp -w
# Ctrl+C para parar

# 5. Verificar status
kubectl rollout status deployment/webapp

# 6. Ver histórico
kubectl rollout history deployment/webapp

# 7. Atualizar para v1.23
kubectl set image deployment/webapp webapp=nginx:1.23

# 8. Pausar no meio
kubectl rollout pause deployment/webapp

# 9. Ver pods (alguns v1.22, alguns v1.23)
kubectl get pods -l app=webapp -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# 10. Retomar
kubectl rollout resume deployment/webapp

# 11. Aguardar conclusão
kubectl rollout status deployment/webapp

# 12. Simular problema - atualizar para tag inexistente
kubectl set image deployment/webapp webapp=nginx:broken

# 13. Ver que falhou
kubectl get pods -l app=webapp
kubectl describe pod <pod-name> | grep -A 5 Events

# 14. Fazer rollback
kubectl rollout undo deployment/webapp

# 15. Verificar que voltou
kubectl rollout status deployment/webapp
kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'

# 16. Ver histórico completo
kubectl rollout history deployment/webapp

# 17. Limpar
kubectl delete deployment webapp
```

---

## Estratégias de Atualização

### RollingUpdate (Padrão)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # Pods extras permitidos
    maxUnavailable: 0    # Pods indisponíveis permitidos
```

**Quando usar:**
- Aplicações stateless
- Precisa de zero downtime
- Pode ter múltiplas versões rodando simultaneamente

### Recreate

```yaml
strategy:
  type: Recreate
```

**Quando usar:**
- Aplicações stateful que não suportam múltiplas versões
- Pode ter downtime
- Precisa garantir que versão antiga parou antes de iniciar nova

```bash
# Exemplo com Recreate
cat <<EOF | kubectl apply -f -
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
EOF

# Atualizar (todos os pods param antes de novos iniciarem)
kubectl set image deployment/database postgres=postgres:15
kubectl get pods -l app=database -w
```

---

## Troubleshooting

### Atualização Travada

```bash
# Ver status
kubectl rollout status deployment/<name>

# Ver pods
kubectl get pods -l app=<name>

# Ver eventos
kubectl describe deployment <name>

# Ver detalhes de pod com problema
kubectl describe pod <pod-name>

# Fazer rollback
kubectl rollout undo deployment/<name>
```

### Imagem não Encontrada

```bash
# Ver erro
kubectl describe pod <pod-name> | grep -A 5 Events

# Corrigir imagem
kubectl set image deployment/<name> container=correct-image:tag

# Ou fazer rollback
kubectl rollout undo deployment/<name>
```

### Pods não Ficam Ready

```bash
# Ver readiness probe
kubectl describe pod <pod-name> | grep -A 10 Readiness

# Ver logs
kubectl logs <pod-name>

# Ajustar probe ou corrigir aplicação
kubectl edit deployment <name>
```

---

## Boas Práticas

### 1. Use Versionamento de Imagens

```bash
# ✅ BOM - tag específica
kubectl set image deployment/webapp webapp=nginx:1.22.0

# ❌ RUIM - tag latest (dificulta rollback)
kubectl set image deployment/webapp webapp=nginx:latest
```

### 2. Configure Rolling Update Adequadamente

```yaml
# Para alta disponibilidade
rollingUpdate:
  maxSurge: 1
  maxUnavailable: 0    # Zero downtime

# Para atualização rápida
rollingUpdate:
  maxSurge: 2
  maxUnavailable: 1
```

### 3. Sempre Teste Antes

```bash
# Testar em ambiente de dev/staging primeiro
kubectl apply -f deployment.yaml --dry-run=server
kubectl diff -f deployment.yaml
```

### 4. Monitore a Atualização

```bash
# Acompanhar em tempo real
kubectl rollout status deployment/<name>
kubectl get pods -l app=<name> -w
```

### 5. Mantenha Histórico

```yaml
spec:
  revisionHistoryLimit: 10    # Manter 10 revisões
```

### 6. Use Health Checks

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 3
```

---

## Resumo

**Métodos de atualização:**
- `kubectl set image` - Rápido para imagens
- `kubectl apply -f` - Declarativo (recomendado)
- `kubectl edit` - Interativo
- `kubectl patch` - Campos específicos
- `kubectl scale` - Apenas réplicas

**Rolling Update:**
- Atualização gradual sem downtime
- Configurável via maxSurge e maxUnavailable
- Pode ser pausado e retomado

**Rollback:**
- `kubectl rollout undo` - Voltar versão anterior
- `kubectl rollout undo --to-revision=N` - Versão específica
- Histórico mantido em ReplicaSets antigos

**Comandos principais:**
- `kubectl rollout status` - Ver progresso
- `kubectl rollout history` - Ver histórico
- `kubectl rollout pause/resume` - Controlar atualização
- `kubectl rollout undo` - Reverter
