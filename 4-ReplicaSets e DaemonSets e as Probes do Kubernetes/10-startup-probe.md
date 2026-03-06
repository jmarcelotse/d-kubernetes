# Startup Probe

## O que é Startup Probe?

**Startup Probe** (Sonda de Inicialização) é uma verificação que o Kubernetes executa para determinar se um container **completou sua inicialização**.

**Pergunta que responde**: "O container já terminou de inicializar?"

**Ação quando falha**: O Kubernetes **reinicia o container**.

**Característica especial**: Enquanto a Startup Probe não for bem-sucedida, as **Liveness e Readiness Probes são desabilitadas**.

## Por Que Usar Startup Probe?

Aplicações com **inicialização lenta** podem ser mortas pela Liveness Probe antes de terminarem de inicializar:

**Problema sem Startup Probe:**
```
Container inicia → Liveness começa a verificar → Aplicação ainda inicializando
→ Liveness falha 3x → Container reiniciado → Loop infinito de restarts!
```

**Solução com Startup Probe:**
```
Container inicia → Startup verifica → Liveness aguarda
→ Startup sucede → Liveness começa → Aplicação já está pronta!
```

**Casos de uso:**
- Aplicações legadas com startup lento (minutos)
- Aplicações que carregam grandes volumes de dados na inicialização
- Aplicações Java/JVM com warm-up longo
- Bancos de dados com recovery demorado
- Aplicações que precisam migrar dados no startup

## Diferença entre as Três Probes

| Probe | Quando Executa | Falha → Ação | Objetivo |
|-------|---------------|--------------|----------|
| **Startup** | Apenas no início | Reinicia | Proteger startup lento |
| **Liveness** | Após startup, continuamente | Reinicia | Detectar travamentos |
| **Readiness** | Após startup, continuamente | Remove do Service | Controlar tráfego |

## Como Funciona

```
CONTAINER INICIANDO:
┌─────────────────────────────────────────────────────────┐
│ Container iniciado                                      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Startup Probe configurada?                              │
└─────────────────────────────────────────────────────────┘
            │                           │
            ▼ SIM                       ▼ NÃO
┌─────────────────────────┐   ┌─────────────────────────┐
│ Liveness e Readiness    │   │ Liveness e Readiness    │
│ DESABILITADAS           │   │ começam imediatamente   │
└─────────────────────────┘   └─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────┐
│ Aguarda initialDelaySeconds                             │
└─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────┐
│ Executa Startup Probe                                   │
└─────────────────────────────────────────────────────────┘
            │
    ┌───────┴───────┐
    ▼               ▼
✅ SUCESSO      ❌ FALHA
    │               │
    ▼               ▼
┌─────────┐   ┌──────────────┐
│ Startup │   │ Incrementa   │
│ completo│   │ contador     │
└─────────┘   └──────────────┘
    │               │
    ▼               ▼
┌─────────┐   ┌──────────────────┐
│ Liveness│   │ Atingiu          │
│ e       │   │ failureThreshold?│
│Readiness│   └──────────────────┘
│ começam │           │
└─────────┘   ┌───────┴────────┐
              ▼                ▼
            NÃO              SIM
              │                │
              └────────┐       ▼
                       │  ┌──────────┐
                       │  │ REINICIA │
                       │  │CONTAINER │
                       │  └──────────┘
                       │       │
                       └───────┘
```

## Métodos de Verificação

### 1. HTTP GET

```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 30  # 30 * 10s = 5 minutos para inicializar
```

### 2. TCP Socket

```yaml
startupProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 60  # 60 * 5s = 5 minutos
```

### 3. Exec Command

```yaml
startupProbe:
  exec:
    command:
    - cat
    - /tmp/started
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 30  # 30 * 5s = 2.5 minutos
```

## Parâmetros de Configuração

```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  initialDelaySeconds: 0    # Geralmente 0 (começar imediatamente)
  periodSeconds: 10         # Verificar a cada 10s
  timeoutSeconds: 3         # Timeout para cada verificação
  successThreshold: 1       # 1 sucesso = startup completo
  failureThreshold: 30      # 30 falhas = reiniciar (30*10s = 5min)
```

**Cálculo do tempo máximo de startup:**
```
Tempo máximo = initialDelaySeconds + (failureThreshold × periodSeconds)
Exemplo: 0 + (30 × 10) = 300 segundos (5 minutos)
```

## Exemplo Prático 1: Startup Probe Básica

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-basic
  labels:
    app: startup-demo
spec:
  containers:
  - name: slow-app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Starting slow application..."
      sleep 45
      touch /tmp/started
      echo "Application started!"
      sleep 3600
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/started
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 10  # 10 * 5s = 50s para inicializar
```

Salve como `startup-basic.yaml`

```bash
# Criar o Pod
kubectl apply -f startup-basic.yaml

# Observar a inicialização
kubectl get pod startup-basic --watch

# Saída:
# NAME            READY   STATUS    RESTARTS   AGE
# startup-basic   0/1     Running   0          5s
# startup-basic   0/1     Running   0          15s
# startup-basic   0/1     Running   0          25s
# startup-basic   0/1     Running   0          35s
# startup-basic   0/1     Running   0          45s
# startup-basic   1/1     Running   0          50s  ← Ready após startup

# Ver logs
kubectl logs startup-basic

# Saída:
# Starting slow application...
# Application started!

# Ver detalhes da startup probe
kubectl describe pod startup-basic | grep -A 5 Startup

# Saída:
#     Startup:        exec [cat /tmp/started] delay=10s timeout=1s period=5s #success=1 #failure=10
```

## Exemplo Prático 2: Startup, Liveness e Readiness Juntas

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probes-all-three
  labels:
    app: three-probes
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Application starting..."
      sleep 30
      touch /tmp/started
      echo "Application started!"
      touch /tmp/healthy
      touch /tmp/ready
      sleep 3600
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/started
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 10  # 50s para inicializar
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 0  # Começa após startup
      periodSeconds: 10
      failureThreshold: 3
    readinessProbe:
      exec:
        command:
        - cat
        - /tmp/ready
      initialDelaySeconds: 0  # Começa após startup
      periodSeconds: 5
      failureThreshold: 2
```

Salve como `probes-all-three.yaml`

```bash
# Criar o Pod
kubectl apply -f probes-all-three.yaml

# Observar
kubectl get pod probes-all-three --watch

# Ver todas as probes
kubectl describe pod probes-all-three | grep -A 5 "Startup\|Liveness\|Readiness"

# Saída mostrará:
#     Startup:        exec [cat /tmp/started] delay=5s timeout=1s period=5s #success=1 #failure=10
#     Liveness:       exec [cat /tmp/healthy] delay=0s timeout=1s period=10s #success=1 #failure=3
#     Readiness:      exec [cat /tmp/ready] delay=0s timeout=1s period=5s #success=1 #failure=2
```

## Exemplo Prático 3: Aplicação Java com Startup Lento

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: java-app-slow
  labels:
    app: java-app
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "JVM starting..."
      sleep 20
      echo "Loading classes..."
      sleep 20
      echo "Initializing Spring context..."
      sleep 30
      echo "Connecting to database..."
      sleep 15
      echo "Application ready!"
      touch /tmp/started
      sleep 3600
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/started
      initialDelaySeconds: 10
      periodSeconds: 10
      failureThreshold: 12  # 12 * 10s = 2 minutos
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/started
      initialDelaySeconds: 0
      periodSeconds: 10
      failureThreshold: 3
```

Salve como `java-app-slow.yaml`

```bash
# Criar o Pod
kubectl apply -f java-app-slow.yaml

# Observar inicialização (leva ~90s)
kubectl get pod java-app-slow --watch

# Ver logs em tempo real
kubectl logs java-app-slow -f

# Saída:
# JVM starting...
# Loading classes...
# Initializing Spring context...
# Connecting to database...
# Application ready!
```

## Exemplo Prático 4: Comparação Com e Sem Startup Probe

### Sem Startup Probe (Problema)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: without-startup
  labels:
    app: no-startup
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Starting (takes 60s)..."
      sleep 60
      echo "Started!"
      sleep 3600
    livenessProbe:
      exec:
        command:
        - sh
        - -c
        - "ps | grep -v grep | grep sleep"
      initialDelaySeconds: 10
      periodSeconds: 10
      failureThreshold: 3  # 30s de tolerância
```

Salve como `without-startup.yaml`

```bash
# Criar o Pod
kubectl apply -f without-startup.yaml

# Observar - pode entrar em loop de restarts
kubectl get pod without-startup --watch

# Saída:
# NAME              READY   STATUS    RESTARTS   AGE
# without-startup   0/1     Running   0          10s
# without-startup   0/1     Running   1          40s  ← Reiniciado!
# without-startup   0/1     Running   2          70s  ← Reiniciado novamente!

# Problema: Liveness mata o container antes de terminar startup
```

### Com Startup Probe (Solução)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-startup
  labels:
    app: with-startup
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Starting (takes 60s)..."
      sleep 60
      touch /tmp/started
      echo "Started!"
      sleep 3600
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/started
      initialDelaySeconds: 10
      periodSeconds: 10
      failureThreshold: 10  # 100s de tolerância
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/started
      initialDelaySeconds: 0
      periodSeconds: 10
      failureThreshold: 3
```

Salve como `with-startup.yaml`

```bash
# Criar o Pod
kubectl apply -f with-startup.yaml

# Observar - sem restarts
kubectl get pod with-startup --watch

# Saída:
# NAME            READY   STATUS    RESTARTS   AGE
# with-startup    0/1     Running   0          10s
# with-startup    0/1     Running   0          30s
# with-startup    0/1     Running   0          50s
# with-startup    1/1     Running   0          70s  ← Ready sem restarts!

# Sucesso: Startup protegeu a inicialização
```

## Exemplo Prático 5: Deployment com Startup Probe

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-startup
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
        image: nginx:1.27
        ports:
        - containerPort: 80
        startupProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 0
          periodSeconds: 5
          failureThreshold: 6  # 30s para inicializar
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 0
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 0
          periodSeconds: 5
          failureThreshold: 2
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

Salve como `webapp-startup.yaml`

```bash
# Criar o Deployment
kubectl apply -f webapp-startup.yaml

# Ver Pods
kubectl get pods -l app=webapp

# Ver detalhes de um Pod
kubectl describe pod -l app=webapp | grep -A 5 "Startup\|Liveness\|Readiness"

# Escalar para testar múltiplos startups
kubectl scale deployment webapp-startup --replicas=5

# Observar todos os Pods iniciando
kubectl get pods -l app=webapp --watch
```

## Exemplo Prático 6: Banco de Dados com Recovery Lento

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: database-slow-recovery
  labels:
    app: database
spec:
  containers:
  - name: postgres
    image: postgres:16
    env:
    - name: POSTGRES_PASSWORD
      value: "mysecretpassword"
    ports:
    - containerPort: 5432
    startupProbe:
      tcpSocket:
        port: 5432
      initialDelaySeconds: 10
      periodSeconds: 10
      failureThreshold: 30  # 5 minutos para recovery
    livenessProbe:
      tcpSocket:
        port: 5432
      initialDelaySeconds: 0
      periodSeconds: 20
      failureThreshold: 3
    readinessProbe:
      exec:
        command:
        - pg_isready
        - -U
        - postgres
      initialDelaySeconds: 0
      periodSeconds: 10
      failureThreshold: 3
```

Salve como `database-slow-recovery.yaml`

```bash
# Criar o Pod
kubectl apply -f database-slow-recovery.yaml

# Observar inicialização
kubectl get pod database-slow-recovery --watch

# Ver logs do PostgreSQL
kubectl logs database-slow-recovery -f

# Testar conexão após startup
kubectl exec database-slow-recovery -- pg_isready -U postgres

# Saída: /tmp:5432 - accepting connections
```

## Exemplo Prático 7: Startup Probe com Timeout Longo

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-long-timeout
  labels:
    app: long-timeout
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Very slow startup..."
      sleep 120
      touch /tmp/started
      echo "Finally started!"
      sleep 3600
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/started
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 15  # 15 * 10s = 2.5 minutos
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/started
      periodSeconds: 30
      failureThreshold: 2
```

Salve como `startup-long-timeout.yaml`

```bash
# Criar o Pod
kubectl apply -f startup-long-timeout.yaml

# Observar (leva ~2 minutos)
kubectl get pod startup-long-timeout --watch

# Ver eventos
kubectl describe pod startup-long-timeout | tail -20
```

## Configurações Recomendadas por Tipo de Aplicação

### Aplicação Web Moderna (Startup Rápido)

```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  periodSeconds: 5
  failureThreshold: 6  # 30s
```

### Aplicação Java/JVM (Startup Médio)

```yaml
startupProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  periodSeconds: 10
  failureThreshold: 18  # 3 minutos
```

### Aplicação Legada (Startup Muito Lento)

```yaml
startupProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 15
  failureThreshold: 40  # 10 minutos
```

### Banco de Dados

```yaml
startupProbe:
  tcpSocket:
    port: 5432
  periodSeconds: 10
  failureThreshold: 30  # 5 minutos
```

## Boas Práticas

### 1. Use Startup Probe para Apps com Inicialização > 30s

```yaml
# ✅ BOM - App leva 2 minutos para inicializar
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  periodSeconds: 10
  failureThreshold: 15  # 2.5 minutos

# ❌ DESNECESSÁRIO - App inicia em 5s
# Não precisa de startup probe
```

### 2. Configure Tempo Máximo Maior que Startup Real

```yaml
# ✅ BOM - App leva 60s, configurado para 90s
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  periodSeconds: 10
  failureThreshold: 9  # 90s

# ❌ RUIM - App leva 60s, configurado para 40s
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  periodSeconds: 10
  failureThreshold: 4  # 40s - vai reiniciar!
```

### 3. Use initialDelaySeconds = 0 com Startup Probe

```yaml
# ✅ BOM - Startup começa imediatamente
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 10
  failureThreshold: 12

# ❌ DESNECESSÁRIO - initialDelaySeconds com startup
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  initialDelaySeconds: 30  # Não precisa, startup já protege
  periodSeconds: 10
  failureThreshold: 12
```

### 4. Liveness e Readiness com initialDelaySeconds = 0

```yaml
# ✅ BOM - Começam após startup
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  periodSeconds: 10
  failureThreshold: 12

livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 0  # Começa após startup
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 0  # Começa após startup
  periodSeconds: 5
```

### 5. Mesmo Endpoint ou Endpoints Diferentes

```yaml
# ✅ OPÇÃO 1 - Mesmo endpoint (mais simples)
startupProbe:
  httpGet:
    path: /health
    port: 8080

livenessProbe:
  httpGet:
    path: /health
    port: 8080

# ✅ OPÇÃO 2 - Endpoints diferentes (mais controle)
startupProbe:
  httpGet:
    path: /startup  # Verifica inicialização completa
    port: 8080

livenessProbe:
  httpGet:
    path: /healthz  # Verifica se está vivo
    port: 8080
```

## Troubleshooting

### Problema: Pod em loop de restarts durante startup

```bash
# Ver eventos
kubectl describe pod <pod-name> | grep -A 20 Events

# Saída típica:
# Warning  Unhealthy  Startup probe failed
# Normal   Killing    Container will be restarted

# Soluções:
# 1. Aumentar failureThreshold
kubectl edit pod <pod-name>
# Aumentar failureThreshold de 10 para 20

# 2. Aumentar periodSeconds
# Verificar menos frequentemente

# 3. Ver quanto tempo realmente leva para inicializar
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
```

### Problema: Startup muito longo

```bash
# Calcular tempo máximo configurado
# Tempo = failureThreshold × periodSeconds

# Exemplo: failureThreshold=30, periodSeconds=10
# Tempo máximo = 30 × 10 = 300s (5 minutos)

# Se app leva mais que isso, aumentar:
# - Aumentar failureThreshold, ou
# - Aumentar periodSeconds
```

### Problema: Liveness matando container após startup

```bash
# Verificar se liveness tem initialDelaySeconds adequado
kubectl describe pod <pod-name> | grep -A 5 Liveness

# Com startup probe, liveness deve ter initialDelaySeconds=0
# Startup protege a inicialização
```

## Monitoramento

```bash
# Ver status de startup
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].started}'

# Ver contador de restarts
kubectl get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount

# Ver eventos de startup
kubectl get events --field-selector reason=Unhealthy,involvedObject.name=<pod-name>

# Monitorar tempo de startup
time kubectl wait --for=condition=ready pod/<pod-name> --timeout=300s
```

## Limpeza

```bash
# Deletar Pods de exemplo
kubectl delete pod startup-basic probes-all-three java-app-slow without-startup with-startup database-slow-recovery startup-long-timeout

# Deletar Deployment
kubectl delete deployment webapp-startup

# Verificar
kubectl get pods
```

## Resumo

- **Startup Probe** protege aplicações com inicialização lenta
- **Desabilita Liveness e Readiness** até startup completar
- **Falha → Reinicia container** (como liveness)
- Use para apps que levam **> 30 segundos** para inicializar
- Configure **failureThreshold × periodSeconds** maior que tempo real de startup
- Use **initialDelaySeconds = 0** com startup probe
- **Liveness e Readiness** também devem ter **initialDelaySeconds = 0**
- Evita **loop de restarts** durante inicialização
- Essencial para **aplicações legadas, JVM, bancos de dados**
