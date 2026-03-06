# O que são as Probes no Kubernetes?

## Conceito

**Probes** (sondas) são verificações de saúde que o Kubernetes executa periodicamente nos containers para determinar seu estado e disponibilidade. Elas permitem que o Kubernetes tome decisões automáticas sobre quando reiniciar containers, quando enviar tráfego para eles, ou quando considerá-los prontos para uso.

## Tipos de Probes

O Kubernetes oferece três tipos de probes:

### 1. Liveness Probe (Sonda de Vivacidade)

**Pergunta**: "O container está vivo e funcionando?"

- Verifica se o container está em execução corretamente
- Se falhar, o Kubernetes **reinicia o container**
- Detecta containers travados ou em deadlock
- Usado para recuperação automática de falhas

**Quando usar:**
- Aplicações que podem travar sem crashar
- Processos que podem entrar em deadlock
- Aplicações que precisam de restart para se recuperar

### 2. Readiness Probe (Sonda de Prontidão)

**Pergunta**: "O container está pronto para receber tráfego?"

- Verifica se o container está pronto para aceitar requisições
- Se falhar, o Kubernetes **remove o Pod do Service** (não recebe tráfego)
- O container **não é reiniciado**, apenas isolado do tráfego
- Usado para warm-up, carregamento de dados, dependências

**Quando usar:**
- Aplicações que precisam de tempo para inicializar
- Aplicações que dependem de serviços externos
- Aplicações que precisam carregar dados/cache antes de servir

### 3. Startup Probe (Sonda de Inicialização)

**Pergunta**: "O container já terminou de inicializar?"

- Verifica se o container completou sua inicialização
- Desabilita liveness e readiness probes até que seja bem-sucedida
- Se falhar, o Kubernetes **reinicia o container**
- Usado para aplicações com inicialização lenta

**Quando usar:**
- Aplicações legadas com startup lento
- Aplicações que precisam de muito tempo para inicializar
- Evitar que liveness probe mate o container durante startup

## Comparação entre Probes

| Probe | Falha → Ação | Quando Executar | Objetivo |
|-------|-------------|-----------------|----------|
| **Liveness** | Reinicia container | Durante toda vida | Detectar containers travados |
| **Readiness** | Remove do Service | Durante toda vida | Controlar tráfego |
| **Startup** | Reinicia container | Apenas no início | Proteger startup lento |

## Fluxo de Funcionamento

```
POD INICIANDO:
┌─────────────────────────────────────────────────────────┐
│ 1. Container inicia                                     │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Startup Probe executa (se configurada)              │
│    - Liveness e Readiness aguardam                      │
│    - Se falhar: reinicia container                      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Startup Probe bem-sucedida                           │
│    - Liveness e Readiness começam a executar            │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Readiness Probe verifica                             │
│    ✅ Sucesso: Pod recebe tráfego do Service            │
│    ❌ Falha: Pod removido do Service                    │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 5. Liveness Probe verifica continuamente                │
│    ✅ Sucesso: Container continua rodando               │
│    ❌ Falha: Container é reiniciado                     │
└─────────────────────────────────────────────────────────┘
```

## Métodos de Verificação

Cada probe pode usar um dos três métodos:

### 1. HTTP GET

Faz uma requisição HTTP GET para um endpoint:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: Awesome
  initialDelaySeconds: 3
  periodSeconds: 3
```

**Sucesso**: Status code entre 200-399  
**Falha**: Qualquer outro status code ou timeout

### 2. TCP Socket

Tenta abrir uma conexão TCP:

```yaml
livenessProbe:
  tcpSocket:
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
```

**Sucesso**: Conexão estabelecida  
**Falha**: Não consegue conectar

### 3. Exec Command

Executa um comando dentro do container:

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Sucesso**: Comando retorna exit code 0  
**Falha**: Comando retorna exit code diferente de 0

## Parâmetros de Configuração

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10  # Aguardar antes da primeira verificação
  periodSeconds: 5         # Intervalo entre verificações
  timeoutSeconds: 3        # Timeout para cada verificação
  successThreshold: 1      # Sucessos consecutivos para considerar OK
  failureThreshold: 3      # Falhas consecutivas para considerar falha
```

**Parâmetros:**
- `initialDelaySeconds`: Tempo de espera antes da primeira verificação (padrão: 0)
- `periodSeconds`: Frequência das verificações (padrão: 10)
- `timeoutSeconds`: Tempo máximo de espera por resposta (padrão: 1)
- `successThreshold`: Sucessos consecutivos necessários (padrão: 1)
- `failureThreshold`: Falhas consecutivas para considerar falha (padrão: 3)

## Exemplo Prático 1: Liveness Probe com HTTP

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
  labels:
    app: liveness-demo
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
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 2
      failureThreshold: 3
```

Salve como `liveness-http.yaml`

```bash
# Criar o Pod
kubectl apply -f liveness-http.yaml

# Verificar o Pod
kubectl get pod liveness-http

# Ver detalhes da probe
kubectl describe pod liveness-http | grep -A 10 Liveness

# Saída:
#     Liveness:       http-get http://:80/ delay=5s timeout=2s period=5s #success=1 #failure=3

# Ver eventos
kubectl get events --field-selector involvedObject.name=liveness-http

# Simular falha (deletar nginx)
kubectl exec liveness-http -- rm /usr/share/nginx/html/index.html

# Aguardar - o container será reiniciado após 3 falhas
kubectl get pod liveness-http --watch

# Ver contador de restarts
kubectl get pod liveness-http

# Saída:
# NAME            READY   STATUS    RESTARTS   AGE
# liveness-http   1/1     Running   1          2m
```

## Exemplo Prático 2: Readiness Probe com HTTP

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-http
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
      successThreshold: 1
      failureThreshold: 2
```

Salve como `readiness-http.yaml`

```bash
# Criar o Pod
kubectl apply -f readiness-http.yaml

# Verificar - Pod fica 0/1 até readiness passar
kubectl get pod readiness-http --watch

# Saída:
# NAME             READY   STATUS    RESTARTS   AGE
# readiness-http   0/1     Running   0          3s
# readiness-http   1/1     Running   0          8s  ← Readiness passou

# Ver detalhes
kubectl describe pod readiness-http | grep -A 10 Readiness

# Simular falha
kubectl exec readiness-http -- rm /usr/share/nginx/html/index.html

# Pod fica Not Ready mas não é reiniciado
kubectl get pod readiness-http

# Saída:
# NAME             READY   STATUS    RESTARTS   AGE
# readiness-http   0/1     Running   0          2m
```

## Exemplo Prático 3: Liveness e Readiness Juntas

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probes-combined
  labels:
    app: probes-demo
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
      periodSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
      failureThreshold: 2
```

Salve como `probes-combined.yaml`

```bash
# Criar o Pod
kubectl apply -f probes-combined.yaml

# Observar o comportamento
kubectl get pod probes-combined --watch

# Ver ambas as probes
kubectl describe pod probes-combined | grep -A 5 "Liveness\|Readiness"
```

## Exemplo Prático 4: Liveness Probe com TCP

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-tcp
  labels:
    app: tcp-demo
spec:
  containers:
  - name: redis
    image: redis:7.2
    ports:
    - containerPort: 6379
    livenessProbe:
      tcpSocket:
        port: 6379
      initialDelaySeconds: 15
      periodSeconds: 10
      timeoutSeconds: 3
      failureThreshold: 3
```

Salve como `liveness-tcp.yaml`

```bash
# Criar o Pod
kubectl apply -f liveness-tcp.yaml

# Verificar
kubectl get pod liveness-tcp

# Ver detalhes da probe
kubectl describe pod liveness-tcp | grep -A 5 Liveness

# Saída:
#     Liveness:       tcp-socket :6379 delay=15s timeout=3s period=10s #success=1 #failure=3

# Testar conexão TCP
kubectl exec liveness-tcp -- redis-cli ping

# Saída: PONG
```

## Exemplo Prático 5: Liveness Probe com Exec

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
  labels:
    app: exec-demo
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      touch /tmp/healthy
      sleep 30
      rm -f /tmp/healthy
      sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 2
```

Salve como `liveness-exec.yaml`

```bash
# Criar o Pod
kubectl apply -f liveness-exec.yaml

# Observar o comportamento
kubectl get pod liveness-exec --watch

# Saída:
# NAME            READY   STATUS    RESTARTS   AGE
# liveness-exec   1/1     Running   0          10s
# liveness-exec   1/1     Running   0          35s
# liveness-exec   1/1     Running   1          45s  ← Reiniciado após 30s

# Ver eventos
kubectl describe pod liveness-exec | grep -A 20 Events

# Saída mostrará:
# Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
# Container liveness-exec failed liveness probe, will be restarted
```

## Exemplo Prático 6: Startup Probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-probe
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
      touch /tmp/ready
      echo "Application ready!"
      sleep 3600
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/ready
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 10  # 10 * 5s = 50s para inicializar
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/ready
      periodSeconds: 5
      failureThreshold: 3
```

Salve como `startup-probe.yaml`

```bash
# Criar o Pod
kubectl apply -f startup-probe.yaml

# Observar a inicialização
kubectl get pod startup-probe --watch

# Ver detalhes das probes
kubectl describe pod startup-probe | grep -A 5 "Startup\|Liveness"

# Saída:
#     Startup:        exec [cat /tmp/ready] delay=10s timeout=1s period=5s #success=1 #failure=10
#     Liveness:       exec [cat /tmp/ready] delay=0s timeout=1s period=5s #success=1 #failure=3
```

## Exemplo Prático 7: Aplicação Web Completa com Todas as Probes

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
          failureThreshold: 6  # 30 segundos para inicializar
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 0
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 0
          periodSeconds: 5
          timeoutSeconds: 2
          successThreshold: 1
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

Salve como `webapp-complete.yaml`

```bash
# Criar Deployment e Service
kubectl apply -f webapp-complete.yaml

# Ver Pods
kubectl get pods -l app=webapp

# Ver detalhes de um Pod
kubectl describe pod -l app=webapp | grep -A 5 "Startup\|Liveness\|Readiness"

# Ver endpoints do Service (apenas Pods ready)
kubectl get endpoints webapp-service

# Testar o Service
kubectl run test-curl --image=curlimages/curl:8.5.0 --rm -it --restart=Never -- \
  curl http://webapp-service

# Simular falha em um Pod
POD_NAME=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- rm /usr/share/nginx/html/index.html

# Observar - Pod fica Not Ready e é removido do Service
kubectl get pods -l app=webapp
kubectl get endpoints webapp-service
```

## Exemplo Prático 8: Probe com Custom Headers

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-headers
  labels:
    app: headers-demo
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
        httpHeaders:
        - name: X-Custom-Header
          value: Kubernetes-Probe
        - name: User-Agent
          value: Kubernetes-Liveness-Probe
      initialDelaySeconds: 5
      periodSeconds: 5
    readinessProbe:
      httpGet:
        path: /
        port: 80
        httpHeaders:
        - name: X-Readiness-Check
          value: "true"
      initialDelaySeconds: 3
      periodSeconds: 3
```

Salve como `probe-headers.yaml`

```bash
# Criar o Pod
kubectl apply -f probe-headers.yaml

# Ver detalhes
kubectl describe pod probe-headers | grep -A 10 "Liveness\|Readiness"
```

## Boas Práticas

### 1. Sempre Configure Readiness Probe

```yaml
# ✅ BOM
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 3
```

**Por quê?** Evita enviar tráfego para Pods que ainda não estão prontos.

### 2. Use Liveness Probe com Cuidado

```yaml
# ✅ BOM - Endpoint leve e rápido
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10
  failureThreshold: 3

# ❌ RUIM - Endpoint pesado
livenessProbe:
  httpGet:
    path: /check-database-and-all-dependencies  # Muito pesado!
    port: 8080
```

**Por quê?** Liveness probe pesada pode causar reinicializações desnecessárias.

### 3. Configure Timeouts Apropriados

```yaml
# ✅ BOM
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  timeoutSeconds: 3      # Tempo razoável
  periodSeconds: 10      # Não muito frequente
  failureThreshold: 3    # Tolera falhas temporárias
```

### 4. Use Startup Probe para Apps Lentas

```yaml
# ✅ BOM - Para apps com startup lento
startupProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 10
  failureThreshold: 30  # 5 minutos para inicializar
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 10
  failureThreshold: 3   # Mais rigoroso após startup
```

### 5. Endpoints Diferentes para Cada Probe

```yaml
# ✅ BOM - Endpoints específicos
startupProbe:
  httpGet:
    path: /startup    # Verifica inicialização
    port: 8080
livenessProbe:
  httpGet:
    path: /healthz    # Verifica saúde básica
    port: 8080
readinessProbe:
  httpGet:
    path: /ready      # Verifica prontidão completa
    port: 8080
```

## Troubleshooting

### Problema: Pod reiniciando constantemente

```bash
# Ver eventos
kubectl describe pod <pod-name> | grep -A 20 Events

# Saída típica:
# Liveness probe failed: HTTP probe failed with statuscode: 500
# Container will be restarted

# Soluções:
# 1. Aumentar initialDelaySeconds
# 2. Aumentar failureThreshold
# 3. Aumentar timeoutSeconds
# 4. Verificar se o endpoint está correto
# 5. Verificar logs da aplicação
kubectl logs <pod-name>
```

### Problema: Pod nunca fica Ready

```bash
# Ver status
kubectl get pod <pod-name>

# Saída:
# NAME      READY   STATUS    RESTARTS   AGE
# my-pod    0/1     Running   0          2m

# Ver detalhes da readiness probe
kubectl describe pod <pod-name> | grep -A 10 Readiness

# Ver eventos
kubectl describe pod <pod-name> | grep -A 20 Events

# Saída típica:
# Readiness probe failed: Get http://10.1.1.1:8080/ready: dial tcp 10.1.1.1:8080: connect: connection refused

# Soluções:
# 1. Verificar se a porta está correta
# 2. Verificar se o endpoint existe
# 3. Aumentar initialDelaySeconds
# 4. Ver logs da aplicação
kubectl logs <pod-name>
```

### Problema: Startup Probe falhando

```bash
# Ver detalhes
kubectl describe pod <pod-name> | grep -A 10 Startup

# Soluções:
# 1. Aumentar failureThreshold
# 2. Aumentar periodSeconds
# 3. Verificar tempo real de inicialização
kubectl logs <pod-name>
```

## Resumo

| Probe | Quando Falha | Uso Principal | Endpoint Recomendado |
|-------|-------------|---------------|---------------------|
| **Startup** | Reinicia container | Proteger startup lento | `/startup` |
| **Liveness** | Reinicia container | Detectar travamentos | `/healthz` (leve) |
| **Readiness** | Remove do Service | Controlar tráfego | `/ready` (completo) |

**Regras de ouro:**
1. Sempre configure **Readiness Probe**
2. Configure **Liveness Probe** com cuidado (endpoint leve)
3. Use **Startup Probe** para aplicações com inicialização lenta
4. Configure timeouts e thresholds apropriados
5. Use endpoints diferentes para cada probe
6. Teste as probes antes de ir para produção
