# Entendendo Como o Ingress Funciona

## Introdução

Para usar o Ingress efetivamente, é essencial entender sua arquitetura interna, como os componentes interagem e como o tráfego flui desde o cliente até a aplicação. Este guia explora o funcionamento detalhado do Ingress.

## Arquitetura do Ingress

### Componentes

```
┌─────────────────────────────────────────────────┐
│                   Internet                       │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│          LoadBalancer / NodePort                 │
│              (IP Externo)                        │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│         Ingress Controller (Nginx Pod)           │
│  - Lê recursos Ingress                          │
│  - Configura Nginx dinamicamente                │
│  - Roteia tráfego baseado em regras             │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│            Ingress Resources                     │
│  - Regras de roteamento (host + path)           │
│  - Configurações SSL/TLS                        │
│  - Annotations (comportamento)                  │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│              Services (ClusterIP)                │
│  - Abstração sobre Pods                         │
│  - Balanceamento de carga interno               │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│                    Pods                          │
│  - Aplicação rodando                            │
└─────────────────────────────────────────────────┘
```

## Fluxo de Tráfego Detalhado

### 1. Requisição do Cliente

```
Cliente faz requisição:
GET http://myapp.example.com/api/users
```

### 2. Resolução DNS

```
DNS resolve myapp.example.com → 203.0.113.10 (IP do LoadBalancer)
```

### 3. LoadBalancer

```
LoadBalancer recebe requisição na porta 80/443
↓
Encaminha para Ingress Controller (NodePort ou ClusterIP)
```

### 4. Ingress Controller

```
Nginx recebe requisição
↓
Lê header "Host: myapp.example.com"
↓
Lê path "/api/users"
↓
Consulta regras do Ingress
↓
Encontra match: host=myapp.example.com, path=/api
↓
Roteia para Service: api-service:80
```

### 5. Service

```
Service (ClusterIP) recebe requisição
↓
Seleciona Pod baseado em selector
↓
Balanceia carga entre Pods disponíveis
↓
Encaminha para Pod: 10.244.1.5:8080
```

### 6. Pod

```
Pod recebe requisição
↓
Aplicação processa
↓
Retorna resposta
```

### 7. Resposta

```
Resposta volta pelo mesmo caminho:
Pod → Service → Ingress Controller → LoadBalancer → Cliente
```

## Fluxo Visual Completo

```
┌──────────┐
│ Cliente  │
│ Browser  │
└────┬─────┘
     │ 1. GET http://myapp.example.com/api/users
     │
     ▼
┌──────────────────┐
│   DNS Server     │
│ myapp.example.com│
│ → 203.0.113.10   │
└────┬─────────────┘
     │ 2. IP do LoadBalancer
     │
     ▼
┌──────────────────────────────────────┐
│      LoadBalancer (203.0.113.10)     │
│      Porta 80 → NodePort 30080       │
└────┬─────────────────────────────────┘
     │ 3. Encaminha para Ingress Controller
     │
     ▼
┌──────────────────────────────────────┐
│    Ingress Controller (Nginx Pod)    │
│                                      │
│  1. Lê Host: myapp.example.com       │
│  2. Lê Path: /api/users              │
│  3. Consulta Ingress Resources       │
│  4. Match encontrado:                │
│     - host: myapp.example.com        │
│     - path: /api                     │
│     - backend: api-service:80        │
│  5. Proxy para api-service           │
└────┬─────────────────────────────────┘
     │ 4. proxy_pass http://api-service:80
     │
     ▼
┌──────────────────────────────────────┐
│    Service: api-service (ClusterIP)  │
│    IP: 10.96.100.50                  │
│                                      │
│  Selector: app=api                   │
│  Endpoints:                          │
│    - 10.244.1.5:8080                 │
│    - 10.244.2.3:8080                 │
│    - 10.244.3.7:8080                 │
└────┬─────────────────────────────────┘
     │ 5. Balanceia para um Pod
     │
     ▼
┌──────────────────────────────────────┐
│    Pod: api-xxx (10.244.1.5:8080)    │
│    Container: api                    │
│    Aplicação processa requisição     │
└──────────────────────────────────────┘
```

## Como o Ingress Controller Funciona

### 1. Watch Loop

O Ingress Controller monitora constantemente a API do Kubernetes:

```go
// Pseudocódigo
for {
    // Monitora mudanças em Ingress Resources
    watch(IngressResources)
    
    // Monitora mudanças em Services
    watch(Services)
    
    // Monitora mudanças em Endpoints
    watch(Endpoints)
    
    // Monitora mudanças em Secrets (TLS)
    watch(Secrets)
    
    // Quando detecta mudança
    if (changeDetected) {
        regenerateNginxConfig()
        reloadNginx()
    }
}
```

### 2. Geração de Configuração

Quando um Ingress é criado:

```yaml
# Ingress Resource
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        backend:
          service:
            name: api-service
            port:
              number: 80
```

O Controller gera configuração Nginx:

```nginx
# Configuração Nginx gerada
server {
    listen 80;
    server_name myapp.example.com;
    
    location /api {
        proxy_pass http://upstream_api_service;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

upstream upstream_api_service {
    # Endpoints do Service
    server 10.244.1.5:8080;
    server 10.244.2.3:8080;
    server 10.244.3:8080;
}
```

### 3. Reload do Nginx

```bash
# Controller executa
nginx -t  # Testa configuração
nginx -s reload  # Recarrega sem downtime
```

## Exemplo Prático: Rastreando uma Requisição

### 1. Setup

```yaml
# app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:1.0
        args:
        - "-text=Pod: $(POD_NAME) - IP: $(POD_IP)"
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo-service
spec:
  selector:
    app: echo
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: echo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: echo-service
            port:
              number: 80
```

```bash
kubectl apply -f app.yaml
echo "127.0.0.1 echo.local" | sudo tee -a /etc/hosts
```

### 2. Rastrear Requisição

```bash
# Terminal 1: Ver logs do Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f

# Terminal 2: Fazer requisições
for i in {1..10}; do
  curl http://echo.local
  sleep 1
done
```

**Saída esperada:**
```
Pod: echo-app-xxx - IP: 10.244.1.5
Pod: echo-app-yyy - IP: 10.244.2.3
Pod: echo-app-zzz - IP: 10.244.3.7
...
```

**Logs do Ingress:**
```
10.244.0.1 - - [11/Mar/2026:15:24:55 +0000] "GET / HTTP/1.1" 200 45 "-" "curl/7.81.0" 84 0.003 [default-echo-service-80] [] 10.244.1.5:5678 45 0.003 200
10.244.0.1 - - [11/Mar/2026:15:24:56 +0000] "GET / HTTP/1.1" 200 45 "-" "curl/7.81.0" 84 0.002 [default-echo-service-80] [] 10.244.2.3:5678 45 0.002 200
```

### 3. Ver Configuração Gerada

```bash
# Entrar no Pod do Ingress Controller
POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')

# Ver configuração do server
kubectl exec -n ingress-nginx $POD -- cat /etc/nginx/nginx.conf | grep -A 30 "server_name echo.local"
```

**Saída esperada:**
```nginx
server {
    server_name echo.local;
    listen 80;
    
    location / {
        proxy_pass http://upstream_balancer;
        proxy_set_header Host $host;
        ...
    }
}

upstream upstream_balancer {
    server 10.244.1.5:5678 max_fails=0 fail_timeout=0;
    server 10.244.2.3:5678 max_fails=0 fail_timeout=0;
    server 10.244.3.7:5678 max_fails=0 fail_timeout=0;
}
```

## Matching de Regras

### Como o Nginx Escolhe a Regra

1. **Host Matching** (mais específico primeiro)
2. **Path Matching** (mais longo primeiro)
3. **PathType** (Exact > Prefix)

### Exemplo de Prioridade

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: priority-test
spec:
  ingressClassName: nginx
  rules:
  # Regra 1: Host específico + Path específico
  - host: api.example.com
    http:
      paths:
      - path: /v2/users
        pathType: Exact
        backend:
          service:
            name: users-v2-service
            port:
              number: 80
  
  # Regra 2: Host específico + Path menos específico
  - host: api.example.com
    http:
      paths:
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: api-v2-service
            port:
              number: 80
  
  # Regra 3: Host específico + Path genérico
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
  
  # Regra 4: Sem host (catch-all)
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: default-service
            port:
              number: 80
```

**Ordem de matching:**

```
GET api.example.com/v2/users
→ Match: Regra 1 (Exact match)

GET api.example.com/v2/products
→ Match: Regra 2 (Prefix /v2)

GET api.example.com/v1/users
→ Match: Regra 3 (Prefix /)

GET other.example.com/anything
→ Match: Regra 4 (No host, catch-all)
```

## Balanceamento de Carga

### Algoritmos do Nginx

Por padrão, o Nginx usa **round-robin**:

```nginx
upstream backend {
    server 10.244.1.5:8080;  # Pod 1
    server 10.244.2.3:8080;  # Pod 2
    server 10.244.3.7:8080;  # Pod 3
}

# Requisições distribuídas:
# Req 1 → Pod 1
# Req 2 → Pod 2
# Req 3 → Pod 3
# Req 4 → Pod 1
# ...
```

### Configurar Algoritmo

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  # Least connections
  load-balance: "least_conn"
  
  # IP Hash (sticky sessions)
  # load-balance: "ip_hash"
```

## Health Checks

### Como o Ingress Detecta Pods Saudáveis

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        ports:
        - containerPort: 8080
        # Readiness Probe
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Fluxo:**

```
1. Pod inicia
   ↓
2. Readiness probe falha
   ↓
3. Pod NÃO é adicionado aos Endpoints
   ↓
4. Ingress NÃO roteia tráfego para este Pod
   ↓
5. Readiness probe passa
   ↓
6. Pod adicionado aos Endpoints
   ↓
7. Ingress Controller detecta mudança
   ↓
8. Atualiza upstream do Nginx
   ↓
9. Tráfego começa a ser roteado
```

## SSL/TLS Termination

### Como Funciona

```
Cliente (HTTPS) → Ingress Controller (termina SSL) → Service (HTTP) → Pod
```

### Fluxo Detalhado

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
  - hosts:
    - secure.example.com
    secretName: tls-secret
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: app-service
            port:
              number: 80
```

**Processo:**

```
1. Cliente faz requisição HTTPS
   ↓
2. TLS handshake com Ingress Controller
   ↓
3. Ingress Controller usa certificado do Secret
   ↓
4. Conexão SSL estabelecida
   ↓
5. Ingress Controller descriptografa requisição
   ↓
6. Encaminha HTTP (não criptografado) para Service
   ↓
7. Service encaminha para Pod
   ↓
8. Resposta volta em HTTP
   ↓
9. Ingress Controller criptografa resposta
   ↓
10. Cliente recebe resposta HTTPS
```

## Atualizações Dinâmicas

### Quando um Pod é Adicionado

```
1. Novo Pod criado
   ↓
2. Readiness probe passa
   ↓
3. Pod adicionado aos Endpoints do Service
   ↓
4. Ingress Controller detecta mudança (watch)
   ↓
5. Regenera configuração Nginx
   ↓
6. Adiciona novo server ao upstream
   ↓
7. Recarrega Nginx (sem downtime)
   ↓
8. Novo Pod começa a receber tráfego
```

### Quando um Ingress é Modificado

```
1. kubectl apply -f updated-ingress.yaml
   ↓
2. API Server atualiza Ingress Resource
   ↓
3. Ingress Controller detecta mudança
   ↓
4. Valida nova configuração
   ↓
5. Gera novo nginx.conf
   ↓
6. Testa configuração (nginx -t)
   ↓
7. Se válido: nginx -s reload
   ↓
8. Se inválido: mantém configuração antiga + log erro
```

## Exemplo Prático: Ver Tudo em Ação

### 1. Deploy Completo

```yaml
# complete-demo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args:
        - "-text=Response from $(HOSTNAME)"
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        ports:
        - containerPort: 5678
        readinessProbe:
          httpGet:
            path: /
            port: 5678
          initialDelaySeconds: 2
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: demo-service
spec:
  selector:
    app: demo
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Backend-Pod: $upstream_addr";
spec:
  ingressClassName: nginx
  rules:
  - host: demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-service
            port:
              number: 80
```

```bash
kubectl apply -f complete-demo.yaml
echo "127.0.0.1 demo.local" | sudo tee -a /etc/hosts
```

### 2. Observar Comportamento

```bash
# Terminal 1: Logs do Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f

# Terminal 2: Fazer requisições
while true; do
  curl -s http://demo.local
  sleep 1
done

# Terminal 3: Escalar aplicação
kubectl scale deployment demo-app --replicas=5

# Terminal 4: Ver Endpoints mudando
kubectl get endpoints demo-service -w
```

### 3. Ver Header com Pod Backend

```bash
curl -I http://demo.local
```

**Saída esperada:**
```
HTTP/1.1 200 OK
X-Backend-Pod: 10.244.1.5:5678
...
```

## Resumo do Funcionamento

### Componentes

1. **Ingress Resource** - Definição declarativa de regras
2. **Ingress Controller** - Implementação (Nginx, Traefik, etc.)
3. **LoadBalancer/NodePort** - Ponto de entrada externo
4. **Service** - Abstração sobre Pods
5. **Endpoints** - IPs reais dos Pods

### Fluxo de Tráfego

```
Cliente → DNS → LoadBalancer → Ingress Controller → Service → Pod
```

### Fluxo de Configuração

```
Ingress Resource → Controller Watch → Gera nginx.conf → Reload Nginx
```

### Características

- **Dinâmico** - Atualiza automaticamente
- **Sem Downtime** - Reload graceful do Nginx
- **Balanceamento** - Round-robin por padrão
- **Health Checks** - Usa Readiness Probes
- **SSL Termination** - Descriptografa no Ingress
- **Layer 7** - Roteamento HTTP/HTTPS inteligente

## Próximos Passos

- Explorar **annotations** avançadas
- Configurar **rate limiting**
- Implementar **canary deployments**
- Usar **ExternalDNS** para automação
- Configurar **monitoramento** com Prometheus
- Implementar **WAF** (Web Application Firewall)
