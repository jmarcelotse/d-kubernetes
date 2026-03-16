# Configurando Affinity Cookie no Ingress

## Introdução

Session Affinity (também chamado de Sticky Sessions) garante que requisições de um mesmo cliente sejam sempre direcionadas ao mesmo pod backend. Isso é essencial para aplicações stateful que armazenam sessão em memória.

## O que é Session Affinity?

### Sem Affinity (Round-Robin)

```
Cliente → Ingress → Pod 1 (primeira requisição)
Cliente → Ingress → Pod 2 (segunda requisição)
Cliente → Ingress → Pod 3 (terceira requisição)

Problema: Sessão perdida entre requisições!
```

### Com Affinity (Sticky Sessions)

```
Cliente → Ingress → Pod 1 (primeira requisição)
                    ↓ (cookie criado)
Cliente → Ingress → Pod 1 (segunda requisição)
Cliente → Ingress → Pod 1 (terceira requisição)

Solução: Sempre no mesmo pod!
```

## Fluxo de Funcionamento

```
1. Cliente faz primeira requisição
        ↓
2. Ingress escolhe um pod (round-robin)
        ↓
3. Ingress cria cookie com ID do pod
        ↓
4. Cookie enviado ao cliente
        ↓
5. Cliente envia cookie nas próximas requisições
        ↓
6. Ingress lê cookie e direciona ao mesmo pod
```

---

## Configuração Básica

### Habilitar Session Affinity

```yaml
# ingress-affinity.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: affinity-ingress
  namespace: default
  annotations:
    # Habilitar affinity
    nginx.ingress.kubernetes.io/affinity: "cookie"
    
    # Nome do cookie
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### Testar

```bash
# Aplicar
kubectl apply -f ingress-affinity.yaml

# Primeira requisição (recebe cookie)
curl -v http://app.example.com 2>&1 | grep -i "set-cookie"
# Set-Cookie: route=abc123...

# Segunda requisição (envia cookie)
curl -v -b "route=abc123..." http://app.example.com

# Verificar que sempre vai para o mesmo pod
for i in {1..10}; do
  curl -b "route=abc123..." http://app.example.com | grep "Pod:"
done
```

---

## Configurações Avançadas

### Cookie com Expiração

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: affinity-expires-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    
    # Expiração do cookie (segundos)
    nginx.ingress.kubernetes.io/session-cookie-expires: "172800"  # 48 horas
    
    # Max-Age do cookie (segundos)
    nginx.ingress.kubernetes.io/session-cookie-max-age: "172800"  # 48 horas
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### Cookie com Path e Domain

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: affinity-path-domain-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    
    # Path do cookie
    nginx.ingress.kubernetes.io/session-cookie-path: "/app"
    
    # Domain do cookie (para subdomínios)
    nginx.ingress.kubernetes.io/session-cookie-domain: ".example.com"
    
    # Expiração
    nginx.ingress.kubernetes.io/session-cookie-expires: "86400"  # 24 horas
    nginx.ingress.kubernetes.io/session-cookie-max-age: "86400"
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /app
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### Cookie Seguro (HTTPS)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: affinity-secure-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    
    # Cookie seguro (apenas HTTPS)
    nginx.ingress.kubernetes.io/session-cookie-secure: "true"
    
    # HttpOnly (não acessível via JavaScript)
    nginx.ingress.kubernetes.io/session-cookie-httponly: "true"
    
    # SameSite
    nginx.ingress.kubernetes.io/session-cookie-samesite: "Strict"
    
    # Expiração
    nginx.ingress.kubernetes.io/session-cookie-expires: "3600"  # 1 hora
    nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"
    
    # SSL
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

---

## Exemplo Completo: Aplicação Stateful

### 1. Deploy da Aplicação

```yaml
# stateful-app.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stateful-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stateful-app
  template:
    metadata:
      labels:
        app: stateful-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      initContainers:
      - name: setup
        image: busybox
        command:
        - sh
        - -c
        - |
          cat > /html/index.html <<EOF
          <!DOCTYPE html>
          <html>
          <head><title>Stateful App</title></head>
          <body>
            <h1>Stateful Application</h1>
            <p>Pod: $(hostname)</p>
            <p>Session ID: \$(date +%s)</p>
            <p>Refresh this page to see sticky sessions in action!</p>
          </body>
          </html>
          EOF
        volumeMounts:
        - name: html
          mountPath: /html
      volumes:
      - name: html
        emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: stateful-app-service
  namespace: default
spec:
  selector:
    app: stateful-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### 2. Ingress com Affinity

```yaml
# stateful-app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: stateful-app-ingress
  namespace: default
  annotations:
    # Session Affinity
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "STATEFUL_SESSION"
    nginx.ingress.kubernetes.io/session-cookie-expires: "7200"  # 2 horas
    nginx.ingress.kubernetes.io/session-cookie-max-age: "7200"
    nginx.ingress.kubernetes.io/session-cookie-httponly: "true"
    nginx.ingress.kubernetes.io/session-cookie-samesite: "Lax"
    
    # SSL
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - stateful.example.com
    secretName: stateful-tls
  rules:
  - host: stateful.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: stateful-app-service
            port:
              number: 80
```

### 3. Aplicar e Testar

```bash
# Aplicar
kubectl apply -f stateful-app.yaml
kubectl apply -f stateful-app-ingress.yaml

# Verificar pods
kubectl get pods -l app=stateful-app

# Testar sem cookie (cada requisição vai para pod diferente)
for i in {1..5}; do
  curl -s http://stateful.example.com | grep "Pod:"
done

# Testar com cookie (sempre mesmo pod)
COOKIE=$(curl -s -I http://stateful.example.com | grep -i "set-cookie" | awk '{print $2}')
for i in {1..5}; do
  curl -s -b "$COOKIE" http://stateful.example.com | grep "Pod:"
done
```

---

## Affinity com Hash

### Upstream Hash (Alternativa ao Cookie)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hash-affinity-ingress
  namespace: default
  annotations:
    # Hash baseado em IP do cliente
    nginx.ingress.kubernetes.io/upstream-hash-by: "$remote_addr"
    
    # Ou hash baseado em header
    # nginx.ingress.kubernetes.io/upstream-hash-by: "$http_x_user_id"
    
    # Ou hash baseado em URI
    # nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### Comparação: Cookie vs Hash

| Aspecto | Cookie Affinity | Hash Affinity |
|---------|----------------|---------------|
| **Persistência** | Até expiração do cookie | Enquanto IP/header não mudar |
| **Compatibilidade** | Requer cookies habilitados | Funciona sempre |
| **Precisão** | Alta (por sessão) | Média (por IP/header) |
| **Overhead** | Baixo | Muito baixo |
| **Uso** | Aplicações web | APIs, WebSockets |

---

## Affinity com Canary Deployment

### Canary com Sticky Sessions

```yaml
# Stable (90%)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
  namespace: default
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
    spec:
      containers:
      - name: app
        image: myapp:1.0

---
# Canary (10%)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
  namespace: default
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
    spec:
      containers:
      - name: app
        image: myapp:2.0

---
# Service (seleciona ambos)
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: default
spec:
  selector:
    app: myapp
  ports:
  - port: 80

---
# Ingress com Affinity
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary-ingress
  namespace: default
  annotations:
    # Session Affinity
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    nginx.ingress.kubernetes.io/session-cookie-expires: "3600"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

```bash
# Testar distribuição
for i in {1..100}; do
  curl -s http://app.example.com | grep "Version:"
done | sort | uniq -c

# ~90 requisições para v1.0
# ~10 requisições para v2.0

# Uma vez que recebe cookie, fica no mesmo pod
COOKIE=$(curl -s -I http://app.example.com | grep -i "set-cookie" | awk '{print $2}')
for i in {1..10}; do
  curl -s -b "$COOKIE" http://app.example.com | grep "Version:"
done
# Todas para mesma versão
```

---

## Affinity com WebSockets

### WebSocket com Sticky Sessions

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: websocket-ingress
  namespace: default
  annotations:
    # WebSocket
    nginx.ingress.kubernetes.io/websocket-services: "websocket-service"
    
    # Session Affinity (importante para WebSocket)
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "ws_route"
    nginx.ingress.kubernetes.io/session-cookie-expires: "86400"  # 24h
    nginx.ingress.kubernetes.io/session-cookie-max-age: "86400"
    
    # Timeouts maiores para WebSocket
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
spec:
  ingressClassName: nginx
  rules:
  - host: ws.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: websocket-service
            port:
              number: 8080
```

---

## Monitoramento e Debug

### Ver Cookies Criados

```bash
# Ver cookie no response
curl -v http://app.example.com 2>&1 | grep -i "set-cookie"

# Ver detalhes do cookie
curl -v http://app.example.com 2>&1 | grep -i "set-cookie" | sed 's/</\n</g'

# Exemplo de output:
# Set-Cookie: route=1234567890abcdef; Path=/; Expires=Sat, 14-Mar-2026 16:00:00 GMT; Max-Age=3600; HttpOnly
```

### Testar Affinity

```bash
# Script de teste
#!/bin/bash

URL="http://app.example.com"
COOKIE_FILE="/tmp/cookie.txt"

echo "Testing Session Affinity..."

# Primeira requisição (obtém cookie)
curl -s -c $COOKIE_FILE $URL | grep "Pod:" | tee /tmp/first_pod.txt

# 10 requisições subsequentes
for i in {1..10}; do
  curl -s -b $COOKIE_FILE $URL | grep "Pod:"
done | tee /tmp/subsequent_pods.txt

# Verificar se todos foram para o mesmo pod
FIRST_POD=$(cat /tmp/first_pod.txt)
UNIQUE_PODS=$(cat /tmp/subsequent_pods.txt | sort -u | wc -l)

if [ $UNIQUE_PODS -eq 1 ]; then
  echo "✓ Session Affinity working! All requests to: $FIRST_POD"
else
  echo "✗ Session Affinity NOT working! Requests distributed across $UNIQUE_PODS pods"
fi

# Cleanup
rm -f $COOKIE_FILE /tmp/first_pod.txt /tmp/subsequent_pods.txt
```

### Ver Configuração do Nginx

```bash
# Ver configuração do upstream
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
  cat /etc/nginx/nginx.conf | grep -A 20 "upstream.*myapp"

# Procurar por "sticky cookie"
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
  cat /etc/nginx/nginx.conf | grep -i "sticky"
```

### Logs do Ingress Controller

```bash
# Ver logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f

# Filtrar por host
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep "app.example.com"

# Ver cookies nos logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep -i "cookie"
```

---

## Troubleshooting

### Problema 1: Cookie Não é Criado

```bash
# Verificar annotations
kubectl describe ingress affinity-ingress | grep -A 10 Annotations

# Verificar se affinity está habilitado
kubectl get ingress affinity-ingress -o yaml | grep affinity

# Testar com curl verbose
curl -v http://app.example.com 2>&1 | grep -i "set-cookie"

# Solução: Verificar se annotation está correta
kubectl annotate ingress affinity-ingress \
  nginx.ingress.kubernetes.io/affinity=cookie --overwrite
```

### Problema 2: Cookie Expira Muito Rápido

```bash
# Ver expiração atual
curl -v http://app.example.com 2>&1 | grep -i "expires"

# Aumentar expiração
kubectl annotate ingress affinity-ingress \
  nginx.ingress.kubernetes.io/session-cookie-expires=86400 \
  nginx.ingress.kubernetes.io/session-cookie-max-age=86400 \
  --overwrite

# Verificar
curl -v http://app.example.com 2>&1 | grep -i "max-age"
```

### Problema 3: Affinity Não Funciona com HTTPS

```bash
# Verificar se cookie é seguro
curl -v https://app.example.com 2>&1 | grep -i "secure"

# Habilitar cookie seguro
kubectl annotate ingress affinity-ingress \
  nginx.ingress.kubernetes.io/session-cookie-secure=true --overwrite

# Testar
curl -v -k https://app.example.com 2>&1 | grep -i "set-cookie"
```

### Problema 4: Requisições Ainda Distribuídas

```bash
# Verificar se há múltiplos Ingresses para o mesmo host
kubectl get ingress -A | grep "app.example.com"

# Verificar Service
kubectl get svc myapp-service
kubectl get endpoints myapp-service

# Verificar se pods estão saudáveis
kubectl get pods -l app=myapp

# Testar com cookie explícito
COOKIE="route=abc123"
for i in {1..10}; do
  curl -s -b "$COOKIE" http://app.example.com | grep "Pod:"
done
```

---

## Boas Práticas

### ✅ Fazer

```yaml
# Usar nomes descritivos para cookies
annotations:
  nginx.ingress.kubernetes.io/session-cookie-name: "APP_SESSION"

# Definir expiração apropriada
annotations:
  nginx.ingress.kubernetes.io/session-cookie-expires: "3600"  # 1 hora
  nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"

# Usar cookies seguros em produção
annotations:
  nginx.ingress.kubernetes.io/session-cookie-secure: "true"
  nginx.ingress.kubernetes.io/session-cookie-httponly: "true"
  nginx.ingress.kubernetes.io/session-cookie-samesite: "Strict"

# Combinar com SSL
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

### ❌ Evitar

```yaml
# Não usar expiração muito longa
annotations:
  nginx.ingress.kubernetes.io/session-cookie-expires: "31536000"  # 1 ano (muito!)

# Não usar em aplicações stateless
# (use load balancing normal)

# Não confiar apenas em affinity para segurança
# (use autenticação adequada)
```

---

## Resumo dos Comandos

```bash
# Habilitar affinity
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/affinity=cookie

# Configurar nome do cookie
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/session-cookie-name=route

# Configurar expiração
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/session-cookie-expires=3600

# Testar
curl -v http://app.example.com 2>&1 | grep -i "set-cookie"
curl -b "route=abc123" http://app.example.com

# Ver configuração
kubectl describe ingress myapp | grep -A 10 Annotations
```

---

## Conclusão

Session Affinity com cookies oferece:

✅ **Sticky Sessions** - Requisições sempre no mesmo pod  
✅ **Aplicações Stateful** - Sessão em memória preservada  
✅ **WebSockets** - Conexões persistentes mantidas  
✅ **Canary Deployment** - Usuários fixos em versões  
✅ **Configurável** - Expiração, path, domain, segurança  
✅ **Monitorável** - Fácil de testar e debugar  

Use session affinity quando sua aplicação precisa manter estado entre requisições!
