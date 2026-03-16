# Adicionando Autenticação no Ingress

## Introdução

O Nginx Ingress Controller suporta diferentes métodos de autenticação para proteger aplicações expostas via Ingress. Este guia cobre Basic Auth, OAuth2 Proxy, autenticação por API Key e autenticação externa.

## Métodos de Autenticação

```
┌─────────────────────────────────────────────┐
│           Ingress Controller                │
│                                             │
│  ┌─────────────┐  ┌──────────────────────┐ │
│  │ Basic Auth  │  │ External Auth (OAuth)│ │
│  └─────────────┘  └──────────────────────┘ │
│  ┌─────────────┐  ┌──────────────────────┐ │
│  │  API Key    │  │ Client Certificate   │ │
│  └─────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## Método 1: Basic Auth

### Fluxo

```
1. Usuário acessa URL
2. Ingress retorna 401 (Unauthorized)
3. Navegador exibe popup de login
4. Usuário envia credenciais
5. Ingress valida contra Secret
6. Se válido → acessa aplicação
7. Se inválido → 401 novamente
```

### 1.1 Criar Credenciais

```bash
# Instalar htpasswd (se necessário)
sudo apt-get install apache2-utils  # Debian/Ubuntu
# ou
brew install httpd  # macOS

# Criar arquivo com primeiro usuário
htpasswd -c auth admin
# Senha: digite a senha desejada

# Adicionar mais usuários
htpasswd auth developer
htpasswd auth viewer

# Verificar conteúdo
cat auth
# admin:$apr1$xyz...
# developer:$apr1$abc...
# viewer:$apr1$def...
```

### 1.2 Criar Secret

```bash
# Criar secret a partir do arquivo
kubectl create secret generic basic-auth \
  --from-file=auth \
  -n default

# Verificar
kubectl get secret basic-auth
kubectl describe secret basic-auth
```

### 1.3 Configurar Ingress

```yaml
# ingress-basic-auth.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: protected-ingress
  namespace: default
  annotations:
    # Tipo de autenticação
    nginx.ingress.kubernetes.io/auth-type: basic
    
    # Secret com credenciais
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    
    # Mensagem exibida no popup
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required - Restricted Area"
spec:
  ingressClassName: nginx
  rules:
  - host: protected.example.com
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

### 1.4 Testar

```bash
# Aplicar
kubectl apply -f ingress-basic-auth.yaml

# Testar sem credenciais (deve retornar 401)
curl -I http://protected.example.com
# HTTP/1.1 401 Unauthorized

# Testar com credenciais
curl -u admin:senha123 http://protected.example.com
# HTTP/1.1 200 OK

# Testar com credenciais erradas
curl -u admin:errada http://protected.example.com
# HTTP/1.1 401 Unauthorized
```

### 1.5 Basic Auth com TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: protected-ingress-tls
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - protected.example.com
    secretName: protected-tls
  rules:
  - host: protected.example.com
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

## Método 2: OAuth2 Proxy

### Fluxo

```
1. Usuário acessa URL
2. Ingress redireciona para OAuth2 Proxy
3. OAuth2 Proxy redireciona para Provider (Google, GitHub, etc.)
4. Usuário faz login no Provider
5. Provider retorna token para OAuth2 Proxy
6. OAuth2 Proxy valida token
7. Usuário acessa aplicação
```

### 2.1 Instalar OAuth2 Proxy

```bash
# Via Helm
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update

# Criar secret com cookie
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  -n default
```

### 2.2 Deploy OAuth2 Proxy (GitHub)

```yaml
# oauth2-proxy.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:v7.5.1
        args:
        - --provider=github
        - --email-domain=*
        - --upstream=file:///dev/null
        - --http-address=0.0.0.0:4180
        - --cookie-secure=false
        - --github-org=your-org
        env:
        - name: OAUTH2_PROXY_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secret
              key: client-id
        - name: OAUTH2_PROXY_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secret
              key: client-secret
        - name: OAUTH2_PROXY_COOKIE_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secret
              key: cookie-secret
        ports:
        - containerPort: 4180
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi

---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: default
spec:
  selector:
    app: oauth2-proxy
  ports:
  - port: 4180
    targetPort: 4180
```

### 2.3 Ingress do OAuth2 Proxy

```yaml
# oauth2-proxy-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: oauth2-proxy-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: auth.example.com
    http:
      paths:
      - path: /oauth2
        pathType: Prefix
        backend:
          service:
            name: oauth2-proxy
            port:
              number: 4180
```

### 2.4 Ingress da Aplicação Protegida

```yaml
# app-ingress-oauth.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: protected-app-ingress
  namespace: default
  annotations:
    # URL de autenticação
    nginx.ingress.kubernetes.io/auth-url: "https://auth.example.com/oauth2/auth"
    
    # URL de login
    nginx.ingress.kubernetes.io/auth-signin: "https://auth.example.com/oauth2/start?rd=$scheme://$host$request_uri"
    
    # Headers do usuário autenticado
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User, X-Auth-Request-Email, X-Auth-Request-Groups"
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

### 2.5 Aplicar e Testar

```bash
# Aplicar tudo
kubectl apply -f oauth2-proxy.yaml
kubectl apply -f oauth2-proxy-ingress.yaml
kubectl apply -f app-ingress-oauth.yaml

# Verificar
kubectl get pods -l app=oauth2-proxy
kubectl get ingress

# Testar
# 1. Acessar http://app.example.com
# 2. Será redirecionado para GitHub login
# 3. Após login, acessa a aplicação
```

---

## Método 3: API Key

### Fluxo

```
1. Cliente envia requisição com header X-API-Key
2. Ingress verifica header
3. Se válido → acessa aplicação
4. Se inválido → 403 Forbidden
```

### 3.1 Configurar via Snippet

```yaml
# ingress-api-key.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-key-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      # Verificar API Key
      set $api_key_valid 0;
      
      if ($http_x_api_key = "my-secret-api-key-123") {
        set $api_key_valid 1;
      }
      if ($http_x_api_key = "another-valid-key-456") {
        set $api_key_valid 1;
      }
      
      if ($api_key_valid = 0) {
        return 403 '{"error": "Invalid API Key"}';
      }
spec:
  ingressClassName: nginx
  rules:
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
```

### 3.2 Testar

```bash
# Sem API Key (deve retornar 403)
curl http://api.example.com
# {"error": "Invalid API Key"}

# Com API Key válida
curl -H "X-API-Key: my-secret-api-key-123" http://api.example.com
# 200 OK

# Com API Key inválida
curl -H "X-API-Key: wrong-key" http://api.example.com
# {"error": "Invalid API Key"}
```

---

## Método 4: External Auth (Serviço Externo)

### Fluxo

```
1. Usuário acessa URL
2. Ingress envia subrequest ao serviço de auth
3. Serviço de auth valida token/sessão
4. Se 200 → acessa aplicação
5. Se 401/403 → bloqueia acesso
```

### 4.1 Criar Serviço de Autenticação

```yaml
# auth-service.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: auth-service
  template:
    metadata:
      labels:
        app: auth-service
    spec:
      containers:
      - name: auth
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: auth-config

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: auth-config
  namespace: default
data:
  default.conf: |
    server {
      listen 80;
      
      location = /auth {
        # Verificar header Authorization
        if ($http_authorization = "") {
          return 401;
        }
        
        # Verificar token (exemplo simples)
        if ($http_authorization != "Bearer valid-token-123") {
          return 403;
        }
        
        # Token válido
        return 200;
      }
    }

---
apiVersion: v1
kind: Service
metadata:
  name: auth-service
  namespace: default
spec:
  selector:
    app: auth-service
  ports:
  - port: 80
    targetPort: 80
```

### 4.2 Configurar Ingress com External Auth

```yaml
# ingress-external-auth.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: external-auth-ingress
  namespace: default
  annotations:
    # URL do serviço de autenticação
    nginx.ingress.kubernetes.io/auth-url: "http://auth-service.default.svc.cluster.local/auth"
    
    # Método HTTP para autenticação
    nginx.ingress.kubernetes.io/auth-method: "GET"
    
    # Headers para enviar ao serviço de auth
    nginx.ingress.kubernetes.io/auth-proxy-set-headers: "default/auth-headers"
    
    # Headers da resposta para passar à aplicação
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-User, X-Auth-Role"
    
    # Cache de autenticação (segundos)
    nginx.ingress.kubernetes.io/auth-cache-key: "$remote_addr"
    nginx.ingress.kubernetes.io/auth-cache-duration: "200 202 401 5m"
    
    # Snippet para erro customizado
    nginx.ingress.kubernetes.io/auth-snippet: |
      proxy_set_header X-Original-URI $request_uri;
      proxy_set_header X-Original-Method $request_method;
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

### 4.3 Testar

```bash
# Aplicar
kubectl apply -f auth-service.yaml
kubectl apply -f ingress-external-auth.yaml

# Sem token (401)
curl -I http://app.example.com
# HTTP/1.1 401 Unauthorized

# Com token válido (200)
curl -H "Authorization: Bearer valid-token-123" http://app.example.com
# HTTP/1.1 200 OK

# Com token inválido (403)
curl -H "Authorization: Bearer wrong-token" http://app.example.com
# HTTP/1.1 403 Forbidden
```

---

## Método 5: IP Whitelist

### 5.1 Whitelist Simples

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whitelist-ingress
  namespace: default
  annotations:
    # Permitir apenas IPs específicos
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,203.0.113.50/32"
spec:
  ingressClassName: nginx
  rules:
  - host: internal.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: internal-service
            port:
              number: 80
```

### 5.2 Testar

```bash
# De IP permitido
curl http://internal.example.com
# 200 OK

# De IP não permitido
curl http://internal.example.com
# 403 Forbidden
```

---

## Combinando Métodos

### Basic Auth + IP Whitelist + TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-auth-ingress
  namespace: default
  annotations:
    # Basic Auth
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Restricted Area"
    
    # IP Whitelist
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,192.168.0.0/16"
    
    # TLS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    
    # HSTS
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    
    # Rate Limiting
    nginx.ingress.kubernetes.io/limit-rps: "10"
    
    # Security Headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "DENY" always;
      add_header X-XSS-Protection "1; mode=block" always;
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - admin.example.com
    secretName: admin-tls
  rules:
  - host: admin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```

### Auth por Path

```yaml
# Paths públicos e protegidos no mesmo Ingress
---
# Path público (sem auth)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: public-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /public
        pathType: Prefix
        backend:
          service:
            name: public-service
            port:
              number: 80
      - path: /health
        pathType: Exact
        backend:
          service:
            name: health-service
            port:
              number: 80

---
# Path protegido (com auth)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: protected-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Admin Area"
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /admin
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

```bash
# Testar paths
curl http://app.example.com/public     # 200 (sem auth)
curl http://app.example.com/health     # 200 (sem auth)
curl http://app.example.com/admin      # 401 (requer auth)
curl http://app.example.com/api        # 401 (requer auth)
curl -u admin:senha http://app.example.com/admin  # 200
```

---

## Troubleshooting

### Problema 1: 401 Mesmo com Credenciais Corretas

```bash
# Verificar secret
kubectl get secret basic-auth -o yaml

# Decodificar conteúdo
kubectl get secret basic-auth -o jsonpath='{.data.auth}' | base64 -d

# Recriar secret
kubectl delete secret basic-auth
htpasswd -c auth admin
kubectl create secret generic basic-auth --from-file=auth

# Verificar annotations
kubectl describe ingress protected-ingress
```

### Problema 2: OAuth2 Proxy Não Redireciona

```bash
# Ver logs do OAuth2 Proxy
kubectl logs -l app=oauth2-proxy -f

# Verificar service
kubectl get svc oauth2-proxy
kubectl get endpoints oauth2-proxy

# Testar OAuth2 Proxy diretamente
kubectl port-forward svc/oauth2-proxy 4180:4180
curl http://localhost:4180/oauth2/auth

# Verificar annotations do Ingress
kubectl describe ingress protected-app-ingress
```

### Problema 3: External Auth Timeout

```bash
# Verificar serviço de auth
kubectl get pods -l app=auth-service
kubectl logs -l app=auth-service

# Testar serviço internamente
kubectl run curl-test --rm -it --image=curlimages/curl -- \
  curl -v http://auth-service/auth -H "Authorization: Bearer valid-token-123"

# Aumentar timeout
kubectl annotate ingress external-auth-ingress \
  nginx.ingress.kubernetes.io/auth-proxy-set-headers- \
  nginx.ingress.kubernetes.io/proxy-connect-timeout=30 --overwrite
```

### Problema 4: IP Whitelist Não Funciona

```bash
# Verificar IP real do cliente
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep "client:"

# Verificar se proxy protocol está habilitado
kubectl get configmap -n ingress-nginx ingress-nginx-controller -o yaml | grep proxy-protocol

# Verificar X-Forwarded-For
curl -H "X-Forwarded-For: 10.0.0.1" http://internal.example.com

# Ajustar configuração
kubectl annotate ingress whitelist-ingress \
  nginx.ingress.kubernetes.io/whitelist-source-range="0.0.0.0/0" --overwrite
```

---

## Resumo dos Comandos

```bash
# Basic Auth
htpasswd -c auth admin
kubectl create secret generic basic-auth --from-file=auth

# Testar Basic Auth
curl -u admin:senha http://protected.example.com

# Testar API Key
curl -H "X-API-Key: my-key" http://api.example.com

# Testar Bearer Token
curl -H "Authorization: Bearer token" http://app.example.com

# Ver annotations
kubectl describe ingress <name>

# Logs do Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

---

## Conclusão

Autenticação no Ingress oferece:

✅ **Basic Auth** - Simples e rápido para ambientes internos  
✅ **OAuth2 Proxy** - SSO com GitHub, Google, etc.  
✅ **API Key** - Para APIs e integrações  
✅ **External Auth** - Flexível com serviço customizado  
✅ **IP Whitelist** - Restrição por rede  
✅ **Combinações** - Múltiplas camadas de segurança  

Escolha o método adequado ao seu cenário e combine-os para máxima segurança!
