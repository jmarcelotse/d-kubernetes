# Liveness Probe

## O que é Liveness Probe?

**Liveness Probe** (Sonda de Vivacidade) é uma verificação que o Kubernetes executa periodicamente para determinar se um container está **vivo e funcionando corretamente**. 

**Pergunta que responde**: "O container está vivo ou travado?"

**Ação quando falha**: O Kubernetes **reinicia o container**.

## Por Que Usar Liveness Probe?

Algumas aplicações podem entrar em estados problemáticos sem crashar:

- **Deadlock**: Threads travadas esperando umas pelas outras
- **Memory leak**: Aplicação consumindo toda memória mas ainda rodando
- **Infinite loop**: Processo preso em loop infinito
- **Conexões travadas**: Aplicação não responde mas o processo está ativo
- **Corrupção de estado**: Estado interno corrompido que impede funcionamento

**Sem Liveness Probe**: Container continua rodando mas não funciona  
**Com Liveness Probe**: Kubernetes detecta e reinicia automaticamente

## Como Funciona

```
┌─────────────────────────────────────────────────────────┐
│ Container iniciado                                      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Aguarda initialDelaySeconds                             │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Executa Liveness Probe                                  │
└─────────────────────────────────────────────────────────┘
                      │
            ┌─────────┴─────────┐
            ▼                   ▼
        ✅ SUCESSO          ❌ FALHA
            │                   │
            ▼                   ▼
    ┌───────────────┐   ┌──────────────┐
    │ Aguarda       │   │ Incrementa   │
    │ periodSeconds │   │ contador     │
    └───────────────┘   └──────────────┘
            │                   │
            │                   ▼
            │           ┌──────────────────┐
            │           │ Atingiu          │
            │           │ failureThreshold?│
            │           └──────────────────┘
            │                   │
            │           ┌───────┴────────┐
            │           ▼                ▼
            │         NÃO              SIM
            │           │                │
            └───────────┘                ▼
                              ┌──────────────────┐
                              │ REINICIA         │
                              │ CONTAINER        │
                              └──────────────────┘
```

## Métodos de Verificação

### 1. HTTP GET

Faz requisição HTTP para um endpoint:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    scheme: HTTP  # ou HTTPS
  initialDelaySeconds: 10
  periodSeconds: 5
```

**Sucesso**: Status code 200-399  
**Falha**: Outros status codes ou timeout

### 2. TCP Socket

Tenta abrir conexão TCP:

```yaml
livenessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 15
  periodSeconds: 10
```

**Sucesso**: Conexão estabelecida  
**Falha**: Não consegue conectar

### 3. Exec Command

Executa comando no container:

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Sucesso**: Exit code 0  
**Falha**: Exit code diferente de 0

## Parâmetros de Configuração

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30   # Aguardar 30s antes da primeira verificação
  periodSeconds: 10         # Verificar a cada 10s
  timeoutSeconds: 5         # Timeout de 5s para cada verificação
  successThreshold: 1       # 1 sucesso = container saudável
  failureThreshold: 3       # 3 falhas consecutivas = reiniciar
```

**Cálculo do tempo até reiniciar:**
```
Tempo = (failureThreshold × periodSeconds) + timeoutSeconds
Exemplo: (3 × 10) + 5 = 35 segundos
```

## Exemplo Prático 1: Liveness HTTP Básica

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http-basic
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

Salve como `liveness-http-basic.yaml`

```bash
# Criar o Pod
kubectl apply -f liveness-http-basic.yaml

# Verificar status
kubectl get pod liveness-http-basic

# Saída:
# NAME                  READY   STATUS    RESTARTS   AGE
# liveness-http-basic   1/1     Running   0          10s

# Ver detalhes da liveness probe
kubectl describe pod liveness-http-basic | grep -A 10 Liveness

# Saída:
#     Liveness:       http-get http://:80/ delay=5s timeout=2s period=5s #success=1 #failure=3

# Ver logs de eventos
kubectl get events --field-selector involvedObject.name=liveness-http-basic
```

### Testando a Falha

```bash
# Simular falha - remover index.html
kubectl exec liveness-http-basic -- rm /usr/share/nginx/html/index.html

# Observar o Pod em tempo real
kubectl get pod liveness-http-basic --watch

# Saída:
# NAME                  READY   STATUS    RESTARTS   AGE
# liveness-http-basic   1/1     Running   0          1m
# liveness-http-basic   1/1     Running   1          1m30s  ← Reiniciado!

# Ver eventos de falha
kubectl describe pod liveness-http-basic | tail -20

# Saída mostrará:
# Warning  Unhealthy  Liveness probe failed: HTTP probe failed with statuscode: 404
# Normal   Killing    Container liveness-http-basic failed liveness probe, will be restarted
```

## Exemplo Prático 2: Liveness com Endpoint Customizado

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-custom
  labels:
    app: custom-health
spec:
  containers:
  - name: app
    image: hashicorp/http-echo:1.0
    args:
    - "-text=healthy"
    - "-listen=:8080"
    ports:
    - containerPort: 8080
    livenessProbe:
      httpGet:
        path: /
        port: 8080
        httpHeaders:
        - name: X-Custom-Header
          value: Liveness-Check
      initialDelaySeconds: 3
      periodSeconds: 3
      timeoutSeconds: 2
      failureThreshold: 2
```

Salve como `liveness-custom.yaml`

```bash
# Criar o Pod
kubectl apply -f liveness-custom.yaml

# Testar o endpoint manualmente
kubectl port-forward liveness-custom 8080:8080 &

# Em outro terminal
curl http://localhost:8080

# Saída: healthy

# Ver status da probe
kubectl describe pod liveness-custom | grep -A 5 Liveness

# Parar o port-forward
pkill -f "port-forward liveness-custom"
```

## Exemplo Prático 3: Liveness TCP Socket

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

# Testar Redis
kubectl exec liveness-tcp -- redis-cli ping

# Saída: PONG

# Simular falha - matar processo Redis
kubectl exec liveness-tcp -- redis-cli shutdown nosave

# Observar reinicialização
kubectl get pod liveness-tcp --watch

# Saída:
# NAME           READY   STATUS    RESTARTS   AGE
# liveness-tcp   1/1     Running   0          1m
# liveness-tcp   1/1     Running   1          1m30s  ← Reiniciado
```

## Exemplo Prático 4: Liveness Exec Command

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
  labels:
    app: exec-demo
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Criar arquivo healthy
      touch /tmp/healthy
      echo "Application started - healthy file created"
      
      # Rodar por 30 segundos
      sleep 30
      
      # Simular falha - remover arquivo
      rm -f /tmp/healthy
      echo "Application unhealthy - file removed"
      
      # Continuar rodando (mas unhealthy)
      sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 2
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

# Ver logs antes do restart
kubectl logs liveness-exec --previous

# Saída:
# Application started - healthy file created
# Application unhealthy - file removed

# Ver eventos
kubectl describe pod liveness-exec | tail -20

# Saída mostrará:
# Warning  Unhealthy  Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
# Normal   Killing    Container app failed liveness probe, will be restarted
```

## Exemplo Prático 5: Aplicação Web com Liveness

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-liveness
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
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

Salve como `webapp-liveness.yaml`

```bash
# Criar o Deployment
kubectl apply -f webapp-liveness.yaml

# Ver Pods
kubectl get pods -l app=webapp

# Saída:
# NAME                               READY   STATUS    RESTARTS   AGE
# webapp-liveness-5d59d67564-abc12   1/1     Running   0          20s
# webapp-liveness-5d59d67564-def34   1/1     Running   0          20s
# webapp-liveness-5d59d67564-ghi56   1/1     Running   0          20s

# Simular falha em um Pod
POD_NAME=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- rm /usr/share/nginx/html/index.html

# Observar - apenas esse Pod será reiniciado
kubectl get pods -l app=webapp --watch

# Ver contador de restarts
kubectl get pods -l app=webapp

# Saída:
# NAME                               READY   STATUS    RESTARTS   AGE
# webapp-liveness-5d59d67564-abc12   1/1     Running   1          2m  ← Reiniciado
# webapp-liveness-5d59d67564-def34   1/1     Running   0          2m
# webapp-liveness-5d59d67564-ghi56   1/1     Running   0          2m
```

## Exemplo Prático 6: Liveness com Script Complexo

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-script
  labels:
    app: script-demo
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Simular aplicação que pode travar
      counter=0
      while true; do
        counter=$((counter + 1))
        echo "Iteration $counter"
        
        # Simular travamento após 10 iterações
        if [ $counter -eq 10 ]; then
          echo "Application stuck in infinite loop!"
          while true; do sleep 1; done
        fi
        
        sleep 5
      done
    livenessProbe:
      exec:
        command:
        - sh
        - -c
        - |
          # Verificar se o processo está respondendo
          # Criar arquivo de heartbeat
          if [ ! -f /tmp/last_check ]; then
            date +%s > /tmp/last_check
            exit 0
          fi
          
          last=$(cat /tmp/last_check)
          now=$(date +%s)
          diff=$((now - last))
          
          # Se passou mais de 30s, considerar travado
          if [ $diff -gt 30 ]; then
            echo "Application appears stuck"
            exit 1
          fi
          
          date +%s > /tmp/last_check
          exit 0
      initialDelaySeconds: 10
      periodSeconds: 10
      failureThreshold: 2
```

Salve como `liveness-script.yaml`

```bash
# Criar o Pod
kubectl apply -f liveness-script.yaml

# Observar logs
kubectl logs liveness-script -f

# Saída:
# Iteration 1
# Iteration 2
# ...
# Iteration 10
# Application stuck in infinite loop!

# Observar reinicialização
kubectl get pod liveness-script --watch
```

## Exemplo Prático 7: Liveness com Múltiplas Verificações

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-multi
  labels:
    app: multi-check
spec:
  containers:
  - name: app
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
      successThreshold: 1
      failureThreshold: 3
    lifecycle:
      postStart:
        exec:
          command:
          - sh
          - -c
          - |
            echo "Container started at $(date)" > /usr/share/nginx/html/index.html
            echo "<br>Hostname: $(hostname)" >> /usr/share/nginx/html/index.html
      preStop:
        exec:
          command:
          - sh
          - -c
          - |
            echo "Container stopping at $(date)"
            sleep 5
```

Salve como `liveness-multi.yaml`

```bash
# Criar o Pod
kubectl apply -f liveness-multi.yaml

# Testar o endpoint
kubectl port-forward liveness-multi 8080:80 &
curl http://localhost:8080

# Saída:
# Container started at Tue Mar 3 15:09:00 UTC 2026
# Hostname: liveness-multi

# Parar port-forward
pkill -f "port-forward liveness-multi"

# Deletar Pod e ver preStop
kubectl delete pod liveness-multi

# Ver logs de eventos
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
```

## Configurações Recomendadas por Tipo de Aplicação

### Aplicação Web (HTTP)

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### Banco de Dados (TCP)

```yaml
livenessProbe:
  tcpSocket:
    port: 5432
  initialDelaySeconds: 60
  periodSeconds: 20
  timeoutSeconds: 5
  failureThreshold: 3
```

### Aplicação com Inicialização Lenta

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 120  # 2 minutos
  periodSeconds: 15
  timeoutSeconds: 5
  failureThreshold: 3
```

### Aplicação Crítica (Tolerante a Falhas)

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 5  # Mais tolerante
```

## Boas Práticas

### 1. Endpoint Leve e Rápido

```yaml
# ✅ BOM - Endpoint simples
livenessProbe:
  httpGet:
    path: /healthz  # Apenas verifica se está vivo
    port: 8080

# ❌ RUIM - Endpoint pesado
livenessProbe:
  httpGet:
    path: /check-all-dependencies  # Muito complexo!
    port: 8080
```

**Por quê?** Liveness deve verificar apenas se o processo está vivo, não se todas as dependências estão OK.

### 2. Configure initialDelaySeconds Adequado

```yaml
# ✅ BOM - Tempo suficiente para inicializar
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30  # Aplicação precisa de 20s para iniciar

# ❌ RUIM - Muito curto
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5  # Aplicação ainda está iniciando!
```

### 3. Use failureThreshold Apropriado

```yaml
# ✅ BOM - Tolera falhas temporárias
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10
  failureThreshold: 3  # 30s de falhas antes de reiniciar

# ❌ RUIM - Muito sensível
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 5
  failureThreshold: 1  # Reinicia na primeira falha!
```

### 4. Não Verifique Dependências Externas

```yaml
# ✅ BOM - Verifica apenas o container
livenessProbe:
  httpGet:
    path: /healthz  # Retorna 200 se o processo está OK
    port: 8080

# ❌ RUIM - Verifica dependências
livenessProbe:
  httpGet:
    path: /health  # Verifica DB, cache, APIs externas
    port: 8080
```

**Por quê?** Se o banco de dados cair, reiniciar o container não resolve. Use readiness probe para dependências.

### 5. Configure Timeout Adequado

```yaml
# ✅ BOM - Timeout razoável
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  timeoutSeconds: 3  # 3s é suficiente

# ❌ RUIM - Timeout muito curto
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  timeoutSeconds: 1  # Pode falhar em rede lenta
```

## Troubleshooting

### Problema: Container reiniciando constantemente

```bash
# Ver eventos
kubectl describe pod <pod-name> | grep -A 20 Events

# Saída típica:
# Warning  Unhealthy  Liveness probe failed: HTTP probe failed with statuscode: 500
# Normal   Killing    Container will be restarted

# Soluções:
# 1. Aumentar initialDelaySeconds
kubectl patch pod <pod-name> -p '{"spec":{"containers":[{"name":"app","livenessProbe":{"initialDelaySeconds":60}}]}}'

# 2. Verificar logs da aplicação
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Logs antes do restart

# 3. Verificar se o endpoint está correto
kubectl exec <pod-name> -- curl -v http://localhost:8080/healthz

# 4. Aumentar failureThreshold
# Editar o Deployment/Pod e aumentar de 3 para 5
```

### Problema: Liveness probe muito lenta

```bash
# Ver tempo de resposta
kubectl describe pod <pod-name> | grep -A 10 Liveness

# Se timeoutSeconds está sendo atingido frequentemente:
# 1. Otimizar o endpoint de health check
# 2. Aumentar timeoutSeconds
# 3. Aumentar periodSeconds (verificar menos frequentemente)
```

### Problema: Falsos positivos

```bash
# Liveness falhando mas aplicação está OK
# Causas comuns:
# 1. Endpoint muito pesado
# 2. Timeout muito curto
# 3. Verificando dependências externas

# Solução: Simplificar o health check
# Criar endpoint /healthz que apenas retorna 200
```

## Monitoramento

```bash
# Ver contador de restarts
kubectl get pods -o wide

# Ver eventos de liveness
kubectl get events --field-selector reason=Unhealthy

# Ver detalhes de um Pod específico
kubectl describe pod <pod-name> | grep -A 20 "Liveness\|Events"

# Monitorar restarts em tempo real
watch -n 2 'kubectl get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount'

# Ver logs de múltiplos restarts
kubectl logs <pod-name> --previous
kubectl logs <pod-name> --previous --tail=50
```

## Limpeza

```bash
# Deletar Pods de exemplo
kubectl delete pod liveness-http-basic liveness-custom liveness-tcp liveness-exec liveness-script liveness-multi

# Deletar Deployment
kubectl delete deployment webapp-liveness

# Verificar
kubectl get pods
```

## Resumo

- **Liveness Probe** verifica se o container está vivo
- **Falha → Reinicia o container**
- Use para detectar **deadlocks, travamentos, corrupção de estado**
- **Endpoint deve ser leve e rápido**
- **Não verifique dependências externas** (use readiness para isso)
- Configure **initialDelaySeconds** adequado para evitar restarts durante startup
- Use **failureThreshold ≥ 3** para tolerar falhas temporárias
- Monitore o **contador de RESTARTS** para detectar problemas
