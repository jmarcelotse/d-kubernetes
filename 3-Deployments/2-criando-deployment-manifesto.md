# Criando Deployments através de Manifesto

## O que é um Manifesto?

Um **manifesto** é um arquivo YAML ou JSON que descreve de forma declarativa os recursos do Kubernetes. Para Deployments, o manifesto define o estado desejado da aplicação.

## Estrutura Básica de um Manifesto de Deployment

```yaml
apiVersion: apps/v1          # Versão da API
kind: Deployment             # Tipo de recurso
metadata:                    # Metadados
  name: nome-deployment
  labels:
    app: minha-app
spec:                        # Especificação
  replicas: 3                # Número de réplicas
  selector:                  # Seletor de pods
    matchLabels:
      app: minha-app
  template:                  # Template do pod
    metadata:
      labels:
        app: minha-app
    spec:
      containers:
      - name: container-app
        image: nginx:alpine
        ports:
        - containerPort: 80
```

## Campos Principais

### apiVersion
Define a versão da API do Kubernetes a ser usada.
- Para Deployments: `apps/v1`

### kind
Tipo de recurso que está sendo criado.
- Para Deployments: `Deployment`

### metadata
Informações sobre o Deployment.
- `name`: Nome único do Deployment
- `labels`: Labels para organização
- `annotations`: Metadados adicionais

### spec
Especificação do Deployment.
- `replicas`: Número de pods desejados
- `selector`: Como identificar os pods gerenciados
- `template`: Template dos pods a serem criados

### template
Define como os pods serão criados.
- `metadata`: Labels dos pods
- `spec`: Especificação dos containers

---

## Exemplo 1: Deployment Básico

```yaml
# deployment-basico.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
```

**Aplicar:**
```bash
# Criar deployment
kubectl apply -f deployment-basico.yaml

# Verificar
kubectl get deployments
kubectl get pods
kubectl get replicasets

# Ver detalhes
kubectl describe deployment nginx-deployment

# Testar
kubectl port-forward deployment/nginx-deployment 8080:80
curl http://localhost:8080

# Deletar
kubectl delete -f deployment-basico.yaml
```

---

## Exemplo 2: Deployment com Recursos

```yaml
# deployment-recursos.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
    environment: production
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
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

**Aplicar:**
```bash
# Criar
kubectl apply -f deployment-recursos.yaml

# Ver uso de recursos
kubectl top pods

# Ver alocação de recursos
kubectl describe deployment webapp | grep -A 10 "Limits\|Requests"

# Deletar
kubectl delete -f deployment-recursos.yaml
```

---

## Exemplo 3: Deployment com Variáveis de Ambiente

```yaml
# deployment-env.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-backend
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
      - name: backend
        image: node:18-alpine
        command: ["sh", "-c", "env && sleep 3600"]
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        - name: DATABASE_HOST
          value: "postgres.default.svc.cluster.local"
        - name: DATABASE_PORT
          value: "5432"
```

**Aplicar:**
```bash
# Criar
kubectl apply -f deployment-env.yaml

# Ver variáveis de ambiente
kubectl exec -it deployment/app-backend -- env

# Ver logs
kubectl logs -l app=backend

# Deletar
kubectl delete -f deployment-env.yaml
```

---

## Exemplo 4: Deployment com Health Checks

```yaml
# deployment-healthchecks.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-health
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
        image: nginx:alpine
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
          timeoutSeconds: 2
          successThreshold: 1
```

**Aplicar:**
```bash
# Criar
kubectl apply -f deployment-healthchecks.yaml

# Ver status dos probes
kubectl describe pod -l app=webapp | grep -A 10 "Liveness\|Readiness"

# Ver eventos
kubectl get events --sort-by='.lastTimestamp' | grep webapp

# Deletar
kubectl delete -f deployment-healthchecks.yaml
```

---

## Exemplo 5: Deployment com Volumes

```yaml
# deployment-volumes.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-volumes
spec:
  replicas: 2
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
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: html
        emptyDir: {}
      - name: config
        configMap:
          name: nginx-config
```

**Aplicar:**
```bash
# Criar ConfigMap primeiro
kubectl create configmap nginx-config \
  --from-literal=default.conf="server { listen 80; location / { return 200 'Hello from ConfigMap!'; } }"

# Criar deployment
kubectl apply -f deployment-volumes.yaml

# Verificar volumes
kubectl describe pod -l app=webapp | grep -A 5 "Volumes\|Mounts"

# Deletar
kubectl delete -f deployment-volumes.yaml
kubectl delete configmap nginx-config
```

---

## Exemplo 6: Deployment com ConfigMap e Secret

```yaml
# deployment-config-secret.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  API_URL: "https://api.example.com"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  DB_PASSWORD: "senha123"
  API_KEY: "abc123xyz"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-full
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sh", "-c", "env && sleep 3600"]
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secret
```

**Aplicar:**
```bash
# Criar tudo
kubectl apply -f deployment-config-secret.yaml

# Ver variáveis
kubectl exec -it deployment/app-full -- env | grep -E "APP_|DB_|API_"

# Ver ConfigMap
kubectl get configmap app-config -o yaml

# Ver Secret (base64)
kubectl get secret app-secret -o yaml

# Deletar
kubectl delete -f deployment-config-secret.yaml
```

---

## Exemplo 7: Deployment com Estratégia de Atualização

```yaml
# deployment-strategy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-strategy
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: v1
    spec:
      containers:
      - name: webapp
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
```

**Aplicar:**
```bash
# Criar
kubectl apply -f deployment-strategy.yaml

# Ver deployment
kubectl get deployment webapp-strategy

# Atualizar imagem (rolling update)
kubectl set image deployment/webapp-strategy webapp=nginx:1.22-alpine

# Acompanhar rollout
kubectl rollout status deployment/webapp-strategy

# Ver histórico
kubectl rollout history deployment/webapp-strategy

# Rollback
kubectl rollout undo deployment/webapp-strategy

# Deletar
kubectl delete -f deployment-strategy.yaml
```

---

## Exemplo 8: Deployment Completo (Produção)

```yaml
# deployment-producao.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-prod
  labels:
    app: webapp
    environment: production
    tier: frontend
  annotations:
    description: "Aplicação web principal"
    owner: "team-platform"
spec:
  replicas: 5
  revisionHistoryLimit: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app: webapp
      environment: production
  template:
    metadata:
      labels:
        app: webapp
        environment: production
        version: v1.0.0
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "128Mi"
            cpu: "200m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: logs
          mountPath: /var/log/nginx
      volumes:
      - name: cache
        emptyDir: {}
      - name: logs
        emptyDir: {}
```

**Aplicar:**
```bash
# Criar
kubectl apply -f deployment-producao.yaml

# Verificar tudo
kubectl get deployment webapp-prod
kubectl get pods -l app=webapp
kubectl describe deployment webapp-prod

# Ver recursos
kubectl top pods -l app=webapp

# Ver eventos
kubectl get events --sort-by='.lastTimestamp' | grep webapp-prod

# Escalar
kubectl scale deployment webapp-prod --replicas=10

# Atualizar
kubectl set image deployment/webapp-prod webapp=nginx:latest

# Acompanhar
kubectl rollout status deployment/webapp-prod

# Deletar
kubectl delete -f deployment-producao.yaml
```

---

## Fluxo de Criação via Manifesto

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE CRIAÇÃO DE DEPLOYMENT                  │
└─────────────────────────────────────────────────────────┘

1. CRIAR MANIFESTO YAML
   ├─> Definir apiVersion, kind, metadata
   ├─> Definir spec (replicas, selector)
   ├─> Definir template (pods)
   └─> Salvar arquivo .yaml

2. VALIDAR MANIFESTO
   ├─> kubectl apply -f deployment.yaml --dry-run=client
   ├─> kubectl apply -f deployment.yaml --dry-run=server
   └─> kubectl diff -f deployment.yaml

3. APLICAR MANIFESTO
   └─> kubectl apply -f deployment.yaml

4. KUBERNETES PROCESSA
   ├─> API Server valida e persiste no etcd
   ├─> Deployment Controller cria ReplicaSet
   ├─> ReplicaSet Controller cria Pods
   └─> Scheduler atribui Pods a Nodes

5. KUBELET EXECUTA
   ├─> Puxa imagens
   ├─> Cria containers
   └─> Inicia aplicação

6. DEPLOYMENT ATIVO
   ├─> Pods rodando
   ├─> Self-healing ativo
   └─> Pronto para receber tráfego

7. GERENCIAR
   ├─> kubectl get deployment
   ├─> kubectl scale deployment
   ├─> kubectl set image deployment
   └─> kubectl rollout undo deployment
```

---

## Comandos Úteis

### Criar e Aplicar

```bash
# Aplicar manifesto
kubectl apply -f deployment.yaml

# Aplicar múltiplos arquivos
kubectl apply -f deployment.yaml -f service.yaml

# Aplicar diretório
kubectl apply -f ./manifests/

# Aplicar com dry-run
kubectl apply -f deployment.yaml --dry-run=server

# Ver diferenças
kubectl diff -f deployment.yaml
```

### Verificar

```bash
# Listar deployments
kubectl get deployments
kubectl get deploy

# Ver detalhes
kubectl describe deployment <name>

# Ver YAML do deployment
kubectl get deployment <name> -o yaml

# Ver pods do deployment
kubectl get pods -l app=<label>

# Ver replicasets
kubectl get replicasets
```

### Atualizar

```bash
# Aplicar mudanças
kubectl apply -f deployment.yaml

# Editar diretamente
kubectl edit deployment <name>

# Atualizar imagem
kubectl set image deployment/<name> container=image:tag

# Escalar
kubectl scale deployment <name> --replicas=5
```

### Rollout

```bash
# Ver status
kubectl rollout status deployment/<name>

# Ver histórico
kubectl rollout history deployment/<name>

# Pausar rollout
kubectl rollout pause deployment/<name>

# Retomar rollout
kubectl rollout resume deployment/<name>

# Rollback
kubectl rollout undo deployment/<name>

# Rollback para revisão específica
kubectl rollout undo deployment/<name> --to-revision=2
```

### Deletar

```bash
# Deletar via manifesto
kubectl delete -f deployment.yaml

# Deletar por nome
kubectl delete deployment <name>

# Deletar por label
kubectl delete deployment -l app=<label>
```

---

## Boas Práticas

### 1. Use Labels Organizadas

```yaml
metadata:
  labels:
    app: webapp
    component: frontend
    environment: production
    version: v1.0.0
```

### 2. Sempre Defina Resources

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "200m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

### 3. Implemente Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

### 4. Use Estratégia de Atualização

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### 5. Mantenha Histórico de Revisões

```yaml
spec:
  revisionHistoryLimit: 10
```

### 6. Use ConfigMaps e Secrets

```yaml
envFrom:
- configMapRef:
    name: app-config
- secretRef:
    name: app-secret
```

### 7. Adicione Annotations

```yaml
metadata:
  annotations:
    description: "Aplicação principal"
    owner: "team-platform"
    version: "1.0.0"
```

---

## Troubleshooting

### Deployment não Cria Pods

```bash
# Ver eventos
kubectl describe deployment <name>

# Ver replicaset
kubectl get replicasets
kubectl describe replicaset <rs-name>

# Verificar selector
kubectl get deployment <name> -o yaml | grep -A 5 selector
```

### Pods não Iniciam

```bash
# Ver status dos pods
kubectl get pods -l app=<label>

# Ver detalhes
kubectl describe pod <pod-name>

# Ver logs
kubectl logs <pod-name>

# Ver eventos
kubectl get events --sort-by='.lastTimestamp'
```

### Rollout Travado

```bash
# Ver status
kubectl rollout status deployment/<name>

# Ver histórico
kubectl rollout history deployment/<name>

# Fazer rollback
kubectl rollout undo deployment/<name>

# Ver eventos
kubectl describe deployment <name>
```

### Erro de Recursos

```bash
# Ver recursos dos nodes
kubectl top nodes

# Ver recursos dos pods
kubectl top pods

# Ver alocação
kubectl describe nodes | grep -A 5 "Allocated resources"
```

---

## Exemplo Prático Completo

```bash
# 1. Criar manifesto
cat > webapp-deployment.yaml <<EOF
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
      - name: nginx
        image: nginx:alpine
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

# 2. Validar
kubectl apply -f webapp-deployment.yaml --dry-run=server

# 3. Aplicar
kubectl apply -f webapp-deployment.yaml

# 4. Verificar
kubectl get deployments
kubectl get pods
kubectl get replicasets

# 5. Testar
kubectl port-forward deployment/webapp 8080:80
curl http://localhost:8080

# 6. Escalar
kubectl scale deployment webapp --replicas=5

# 7. Atualizar
kubectl set image deployment/webapp nginx=nginx:latest

# 8. Acompanhar
kubectl rollout status deployment/webapp

# 9. Ver histórico
kubectl rollout history deployment/webapp

# 10. Limpar
kubectl delete -f webapp-deployment.yaml
```

---

## Resumo

**Manifesto de Deployment** permite:
- Definir estado desejado de forma declarativa
- Versionamento via Git
- Reprodutibilidade
- Automação via CI/CD
- Rollback fácil

**Estrutura básica**:
- apiVersion, kind, metadata
- spec: replicas, selector, template
- template: metadata, spec (containers)

**Comandos principais**:
- `kubectl apply -f` - Criar/atualizar
- `kubectl get deployment` - Listar
- `kubectl describe deployment` - Detalhes
- `kubectl rollout` - Gerenciar atualizações
- `kubectl delete -f` - Remover
