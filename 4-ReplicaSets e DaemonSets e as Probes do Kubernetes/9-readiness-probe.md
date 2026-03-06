# Readiness Probe

## O que é Readiness Probe?

**Readiness Probe** (Sonda de Prontidão) é uma verificação que o Kubernetes executa periodicamente para determinar se um container está **pronto para receber tráfego**.

**Pergunta que responde**: "O container está pronto para aceitar requisições?"

**Ação quando falha**: O Kubernetes **remove o Pod do Service** (não recebe tráfego), mas **não reinicia o container**.

## Diferença entre Liveness e Readiness

| Aspecto | Liveness Probe | Readiness Probe |
|---------|---------------|-----------------|
| **Pergunta** | Está vivo? | Está pronto? |
| **Falha → Ação** | Reinicia container | Remove do Service |
| **Objetivo** | Detectar travamentos | Controlar tráfego |
| **Quando usar** | Deadlocks, crashes | Warm-up, dependências |
| **Container continua rodando?** | ❌ Não (reinicia) | ✅ Sim (apenas isolado) |

## Por Que Usar Readiness Probe?

Situações onde o container está rodando mas não deve receber tráfego:

- **Inicialização**: Aplicação ainda carregando configurações/dados
- **Warm-up**: Cache sendo populado, conexões sendo estabelecidas
- **Dependências**: Banco de dados ou APIs externas indisponíveis
- **Sobrecarga**: Aplicação temporariamente sobrecarregada
- **Manutenção**: Drenando conexões antes de desligar
- **Deploy**: Durante rolling update, aguardar nova versão estar pronta

**Sem Readiness Probe**: Tráfego enviado para Pods não prontos = erros  
**Com Readiness Probe**: Apenas Pods prontos recebem tráfego = zero downtime

## Como Funciona

```
POD INICIANDO:
┌─────────────────────────────────────────────────────────┐
│ Container iniciado                                      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Pod Status: Running                                     │
│ Ready: 0/1  ← Pod NÃO está Ready                        │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Aguarda initialDelaySeconds                             │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Executa Readiness Probe                                 │
└─────────────────────────────────────────────────────────┘
                      │
            ┌─────────┴─────────┐
            ▼                   ▼
        ✅ SUCESSO          ❌ FALHA
            │                   │
            ▼                   ▼
    ┌───────────────┐   ┌──────────────────┐
    │ Pod Ready     │   │ Pod NOT Ready    │
    │ 1/1           │   │ 0/1              │
    └───────────────┘   └──────────────────┘
            │                   │
            ▼                   ▼
    ┌───────────────┐   ┌──────────────────┐
    │ Adicionado ao │   │ Removido do      │
    │ Service       │   │ Service          │
    │ (recebe       │   │ (não recebe      │
    │ tráfego)      │   │ tráfego)         │
    └───────────────┘   └──────────────────┘
            │                   │
            └─────────┬─────────┘
                      ▼
            Aguarda periodSeconds
                      │
                      └──> Repete verificação
```

## Métodos de Verificação

### 1. HTTP GET

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 3
```

**Sucesso**: Status code 200-399  
**Falha**: Outros status codes ou timeout

### 2. TCP Socket

```yaml
readinessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 10
  periodSeconds: 5
```

**Sucesso**: Conexão estabelecida  
**Falha**: Não consegue conectar

### 3. Exec Command

```yaml
readinessProbe:
  exec:
    command:
    - cat
    - /tmp/ready
  initialDelaySeconds: 5
  periodSeconds: 3
```

**Sucesso**: Exit code 0  
**Falha**: Exit code diferente de 0

## Parâmetros de Configuração

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10   # Aguardar antes da primeira verificação
  periodSeconds: 5          # Verificar a cada 5s
  timeoutSeconds: 3         # Timeout para cada verificação
  successThreshold: 1       # Sucessos para considerar Ready
  failureThreshold: 3       # Falhas para considerar Not Ready
```

## Exemplo Prático 1: Readiness HTTP Básica

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-http-basic
  labels:
    app: readiness-demo
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
      timeoutSeconds: 2
      failureThreshold: 2
```

Salve como `readiness-http-basic.yaml`

```bash
# Criar o Pod
kubectl apply -f readiness-http-basic.yaml

# Observar o Pod ficando Ready
kubectl get pod readiness-http-basic --watch

# Saída:
# NAME                   READY   STATUS    RESTARTS   AGE
# readiness-http-basic   0/1     Running   0          2s
# readiness-http-basic   1/1     Running   0          7s  ← Ficou Ready!

# Ver detalhes da readiness probe
kubectl describe pod readiness-http-basic | grep -A 10 Readiness

# Saída:
#     Readiness:      http-get http://:80/ delay=5s timeout=2s period=3s #success=1 #failure=2
```

### Testando a Falha

```bash
# Simular falha - remover index.html
kubectl exec readiness-http-basic -- rm /usr/share/nginx/html/index.html

# Observar - Pod fica Not Ready mas NÃO é reiniciado
kubectl get pod readiness-http-basic --watch

# Saída:
# NAME                   READY   STATUS    RESTARTS   AGE
# readiness-http-basic   1/1     Running   0          1m
# readiness-http-basic   0/1     Running   0          1m10s  ← Not Ready (mas ainda Running)

# Ver eventos
kubectl describe pod readiness-http-basic | tail -20

# Saída mostrará:
# Warning  Unhealthy  Readiness probe failed: HTTP probe failed with statuscode: 404

# Restaurar o arquivo
kubectl exec readiness-http-basic -- sh -c 'echo "OK" > /usr/share/nginx/html/index.html'

# Pod volta a ficar Ready
kubectl get pod readiness-http-basic

# Saída:
# NAME                   READY   STATUS    RESTARTS   AGE
# readiness-http-basic   1/1     Running   0          2m  ← Ready novamente, sem restart
```

## Exemplo Prático 2: Readiness com Service

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-1
  labels:
    app: web
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
---
apiVersion: v1
kind: Pod
metadata:
  name: web-2
  labels:
    app: web
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

Salve como `readiness-service.yaml`

```bash
# Criar Pods e Service
kubectl apply -f readiness-service.yaml

# Ver Pods
kubectl get pods -l app=web

# Saída:
# NAME    READY   STATUS    RESTARTS   AGE
# web-1   1/1     Running   0          10s
# web-2   1/1     Running   0          10s

# Ver endpoints do Service (apenas Pods Ready)
kubectl get endpoints web-service

# Saída:
# NAME          ENDPOINTS                     AGE
# web-service   10.244.1.5:80,10.244.2.6:80   15s

# Simular falha no web-1
kubectl exec web-1 -- rm /usr/share/nginx/html/index.html

# Aguardar alguns segundos e verificar endpoints
kubectl get endpoints web-service

# Saída:
# NAME          ENDPOINTS         AGE
# web-service   10.244.2.6:80     1m  ← Apenas web-2 (web-1 foi removido)

# Ver status dos Pods
kubectl get pods -l app=web

# Saída:
# NAME    READY   STATUS    RESTARTS   AGE
# web-1   0/1     Running   0          1m  ← Not Ready
# web-2   1/1     Running   0          1m  ← Ready

# Testar o Service (apenas web-2 responde)
kubectl run test-curl --image=curlimages/curl:8.5.0 --rm -it --restart=Never -- \
  curl http://web-service

# Restaurar web-1
kubectl exec web-1 -- sh -c 'echo "OK" > /usr/share/nginx/html/index.html'

# Verificar endpoints - web-1 volta
kubectl get endpoints web-service

# Saída:
# NAME          ENDPOINTS                     AGE
# web-service   10.244.1.5:80,10.244.2.6:80   2m  ← Ambos novamente
```

## Exemplo Prático 3: Readiness com Inicialização Lenta

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: slow-startup
  labels:
    app: slow-app
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Starting application..."
      echo "Loading configuration..."
      sleep 10
      echo "Connecting to database..."
      sleep 10
      echo "Warming up cache..."
      sleep 10
      echo "Application ready!"
      touch /tmp/ready
      sleep 3600
    readinessProbe:
      exec:
        command:
        - cat
        - /tmp/ready
      initialDelaySeconds: 5
      periodSeconds: 3
      failureThreshold: 15  # Tolera até 45s de startup
```

Salve como `slow-startup.yaml`

```bash
# Criar o Pod
kubectl apply -f slow-startup.yaml

# Observar a inicialização
kubectl get pod slow-startup --watch

# Saída:
# NAME           READY   STATUS    RESTARTS   AGE
# slow-startup   0/1     Running   0          5s
# slow-startup   0/1     Running   0          15s
# slow-startup   0/1     Running   0          25s
# slow-startup   1/1     Running   0          35s  ← Ready após ~30s

# Ver logs
kubectl logs slow-startup

# Saída:
# Starting application...
# Loading configuration...
# Connecting to database...
# Warming up cache...
# Application ready!
```

## Exemplo Prático 4: Readiness Verificando Dependências

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-deps
  labels:
    app: app-deps
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Simular aplicação que depende de serviços externos
      while true; do
        # Verificar se dependências estão OK
        # (simulado com arquivo)
        if [ -f /tmp/deps-ok ]; then
          echo "Dependencies OK - serving requests"
        else
          echo "Waiting for dependencies..."
        fi
        sleep 5
      done
    readinessProbe:
      exec:
        command:
        - sh
        - -c
        - |
          # Verificar dependências
          # Simular: criar arquivo após 20s
          if [ ! -f /tmp/deps-ok ]; then
            uptime_seconds=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
            if [ $uptime_seconds -gt 20 ]; then
              touch /tmp/deps-ok
            fi
          fi
          
          # Verificar se está pronto
          if [ -f /tmp/deps-ok ]; then
            exit 0
          else
            exit 1
          fi
      initialDelaySeconds: 5
      periodSeconds: 3
```

Salve como `app-with-deps.yaml`

```bash
# Criar o Pod
kubectl apply -f app-with-deps.yaml

# Observar
kubectl get pod app-with-deps --watch

# Ver logs
kubectl logs app-with-deps -f

# Simular falha de dependência
kubectl exec app-with-deps -- rm /tmp/deps-ok

# Pod fica Not Ready
kubectl get pod app-with-deps
```

## Exemplo Prático 5: Deployment com Readiness e Rolling Update

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-readiness
  labels:
    app: webapp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
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
        image: nginx:1.26
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
          failureThreshold: 2
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

Salve como `webapp-readiness.yaml`

```bash
# Criar Deployment e Service
kubectl apply -f webapp-readiness.yaml

# Ver Pods
kubectl get pods -l app=webapp

# Ver endpoints
kubectl get endpoints webapp-service

# Atualizar a imagem
kubectl set image deployment/webapp-readiness nginx=nginx:1.27

# Observar rolling update
kubectl get pods -l app=webapp --watch

# Saída mostrará:
# - Novos Pods criados
# - Ficam 0/1 até readiness passar
# - Só então Pods antigos são terminados
# - Zero downtime!

# Ver status do rollout
kubectl rollout status deployment/webapp-readiness

# Ver endpoints durante update (sempre tem Pods Ready)
kubectl get endpoints webapp-service --watch
```

## Exemplo Prático 6: Readiness e Liveness Juntas

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probes-complete
  labels:
    app: complete-demo
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 10
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
      failureThreshold: 2
```

Salve como `probes-complete.yaml`

```bash
# Criar o Pod
kubectl apply -f probes-complete.yaml

# Ver ambas as probes
kubectl describe pod probes-complete | grep -A 5 "Liveness\|Readiness"

# Simular falha
kubectl exec probes-complete -- rm /usr/share/nginx/html/index.html

# Observar comportamento:
# 1. Readiness falha primeiro (periodSeconds=3, failureThreshold=2) = 6s
# 2. Pod fica Not Ready
# 3. Liveness falha depois (periodSeconds=10, failureThreshold=3) = 30s
# 4. Container é reiniciado

kubectl get pod probes-complete --watch

# Saída:
# NAME               READY   STATUS    RESTARTS   AGE
# probes-complete    1/1     Running   0          30s
# probes-complete    0/1     Running   0          36s  ← Not Ready (readiness falhou)
# probes-complete    0/1     Running   1          66s  ← Reiniciado (liveness falhou)
# probes-complete    1/1     Running   1          71s  ← Ready novamente
```

## Exemplo Prático 7: Readiness com Custom Endpoint

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-readiness
  labels:
    app: custom-app
spec:
  containers:
  - name: app
    image: hashicorp/http-echo:1.0
    args:
    - "-text=Application is ready"
    - "-listen=:8080"
    ports:
    - containerPort: 8080
    readinessProbe:
      httpGet:
        path: /
        port: 8080
        httpHeaders:
        - name: X-Readiness-Check
          value: "true"
      initialDelaySeconds: 3
      periodSeconds: 3
      successThreshold: 1
      failureThreshold: 2
```

Salve como `custom-readiness.yaml`

```bash
# Criar o Pod
kubectl apply -f custom-readiness.yaml

# Testar o endpoint
kubectl port-forward custom-readiness 8080:8080 &
curl http://localhost:8080

# Saída: Application is ready

# Ver status
kubectl get pod custom-readiness

# Parar port-forward
pkill -f "port-forward custom-readiness"
```

## Configurações Recomendadas por Cenário

### Aplicação Web Rápida

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 3
  failureThreshold: 2
```

### Aplicação com Inicialização Lenta

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
  failureThreshold: 10  # Tolera até 50s
```

### Aplicação com Dependências Externas

```yaml
readinessProbe:
  httpGet:
    path: /ready  # Verifica DB, cache, APIs
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

### Banco de Dados

```yaml
readinessProbe:
  tcpSocket:
    port: 5432
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

## Boas Práticas

### 1. Sempre Configure Readiness Probe

```yaml
# ✅ BOM - Sempre tenha readiness
readinessProbe:
  httpGet:
    path: /ready
    port: 8080

# ❌ RUIM - Sem readiness probe
# Tráfego enviado para Pods não prontos!
```

### 2. Readiness Pode Ser Mais Rigorosa que Liveness

```yaml
# ✅ BOM - Readiness verifica tudo
readinessProbe:
  httpGet:
    path: /ready  # Verifica app + dependências
    port: 8080
  periodSeconds: 3
  failureThreshold: 2

livenessProbe:
  httpGet:
    path: /healthz  # Verifica apenas se está vivo
    port: 8080
  periodSeconds: 10
  failureThreshold: 3
```

### 3. Use periodSeconds Menor para Readiness

```yaml
# ✅ BOM - Readiness mais frequente
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 3  # Verifica a cada 3s

livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10  # Verifica a cada 10s
```

**Por quê?** Queremos detectar rapidamente quando um Pod fica pronto ou não pronto.

### 4. Configure failureThreshold Apropriado

```yaml
# ✅ BOM - Tolera falhas temporárias
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 3
  failureThreshold: 3  # 9s de falhas antes de marcar Not Ready

# ❌ RUIM - Muito sensível
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 3
  failureThreshold: 1  # Marca Not Ready na primeira falha
```

### 5. Readiness Deve Verificar Dependências

```yaml
# ✅ BOM - Verifica dependências
readinessProbe:
  httpGet:
    path: /ready  # Endpoint verifica DB, cache, APIs
    port: 8080

# ❌ RUIM - Não verifica dependências
readinessProbe:
  httpGet:
    path: /  # Apenas verifica se responde
    port: 8080
```

## Troubleshooting

### Problema: Pod nunca fica Ready

```bash
# Ver status
kubectl get pod <pod-name>

# Saída:
# NAME      READY   STATUS    RESTARTS   AGE
# my-pod    0/1     Running   0          2m

# Ver detalhes da readiness
kubectl describe pod <pod-name> | grep -A 10 Readiness

# Ver eventos
kubectl describe pod <pod-name> | tail -20

# Saída típica:
# Warning  Unhealthy  Readiness probe failed: Get http://10.1.1.1:8080/ready: dial tcp: connection refused

# Soluções:
# 1. Verificar se a porta está correta
kubectl exec <pod-name> -- netstat -tlnp

# 2. Verificar se o endpoint existe
kubectl exec <pod-name> -- curl -v http://localhost:8080/ready

# 3. Aumentar initialDelaySeconds
# 4. Ver logs da aplicação
kubectl logs <pod-name>
```

### Problema: Pod oscilando entre Ready e Not Ready

```bash
# Monitorar status
kubectl get pod <pod-name> --watch

# Saída:
# NAME      READY   STATUS    RESTARTS   AGE
# my-pod    1/1     Running   0          1m
# my-pod    0/1     Running   0          1m10s
# my-pod    1/1     Running   0          1m20s
# my-pod    0/1     Running   0          1m30s

# Causas comuns:
# 1. Endpoint de readiness muito pesado
# 2. Dependências instáveis
# 3. Timeout muito curto
# 4. Aplicação realmente instável

# Soluções:
# 1. Aumentar timeoutSeconds
# 2. Aumentar failureThreshold
# 3. Otimizar endpoint de readiness
# 4. Investigar logs da aplicação
kubectl logs <pod-name> -f
```

### Problema: Service não roteia tráfego

```bash
# Ver endpoints do Service
kubectl get endpoints <service-name>

# Se não houver endpoints:
# NAME          ENDPOINTS   AGE
# my-service    <none>      5m

# Verificar se há Pods Ready
kubectl get pods -l app=<label>

# Se Pods estão Not Ready, verificar readiness probe
kubectl describe pod <pod-name> | grep -A 10 Readiness
```

## Monitoramento

```bash
# Ver status Ready de todos os Pods
kubectl get pods -o wide

# Ver apenas Pods Not Ready
kubectl get pods --field-selector=status.phase=Running | grep "0/"

# Ver endpoints de um Service
kubectl get endpoints <service-name>

# Monitorar mudanças em endpoints
kubectl get endpoints <service-name> --watch

# Ver eventos de readiness
kubectl get events --field-selector reason=Unhealthy

# Verificar quantos Pods estão Ready
kubectl get deployment <name> -o jsonpath='{.status.readyReplicas}/{.status.replicas}'
```

## Limpeza

```bash
# Deletar recursos de exemplo
kubectl delete pod readiness-http-basic slow-startup app-with-deps probes-complete custom-readiness
kubectl delete pod web-1 web-2
kubectl delete service web-service webapp-service
kubectl delete deployment webapp-readiness

# Verificar
kubectl get pods,services,deployments
```

## Resumo

- **Readiness Probe** verifica se o container está pronto para receber tráfego
- **Falha → Remove do Service** (não reinicia)
- Use para **warm-up, dependências, inicialização**
- **Sempre configure readiness probe** em produção
- Readiness pode ser **mais rigorosa** que liveness (verificar dependências)
- Use **periodSeconds menor** que liveness (detectar rapidamente)
- **Essencial para zero downtime** em rolling updates
- Pod **0/1 Ready** = rodando mas não recebe tráfego
- Pod **1/1 Ready** = rodando e recebe tráfego
