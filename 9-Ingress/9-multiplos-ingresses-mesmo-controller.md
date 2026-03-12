# Criando Múltiplos Ingresses no Mesmo Ingress Controller

## Introdução

Um único Ingress Controller pode gerenciar múltiplos recursos Ingress simultaneamente. Isso permite organizar melhor as regras de roteamento, separar responsabilidades por equipes, ambientes ou aplicações, mantendo um único ponto de entrada para o cluster.

## Conceito

```
                    Ingress Controller (Único)
                            ↓
        ┌───────────────────┼───────────────────┐
        ↓                   ↓                   ↓
   Ingress 1           Ingress 2           Ingress 3
   (app1.com)          (app2.com)          (api.com)
        ↓                   ↓                   ↓
   Service 1           Service 2           Service 3
```

### Por Que Usar Múltiplos Ingresses?

- **Organização**: Separar regras por aplicação ou equipe
- **Manutenção**: Atualizar regras sem afetar outras aplicações
- **Segurança**: Aplicar políticas diferentes por Ingress
- **Namespaces**: Isolar Ingresses por namespace
- **Versionamento**: Facilitar rollback de regras específicas

---

## Cenário 1: Múltiplos Ingresses com Hosts Diferentes

### Arquitetura

```
Internet
    ↓
Ingress Controller
    ├─→ Ingress 1 (blog.example.com) → Blog Service → Blog Pods
    ├─→ Ingress 2 (shop.example.com) → Shop Service → Shop Pods
    └─→ Ingress 3 (api.example.com)  → API Service  → API Pods
```

### 1.1 Criar Aplicações de Exemplo

```bash
# Criar namespace
kubectl create namespace multi-ingress-demo

# App 1: Blog
kubectl create deployment blog \
  --image=nginx:alpine \
  --replicas=2 \
  -n multi-ingress-demo

kubectl expose deployment blog \
  --port=80 \
  --target-port=80 \
  --name=blog-service \
  -n multi-ingress-demo

# App 2: Shop
kubectl create deployment shop \
  --image=httpd:alpine \
  --replicas=2 \
  -n multi-ingress-demo

kubectl expose deployment shop \
  --port=80 \
  --target-port=80 \
  --name=shop-service \
  -n multi-ingress-demo

# App 3: API
kubectl create deployment api \
  --image=kennethreitz/httpbin \
  --replicas=2 \
  -n multi-ingress-demo

kubectl expose deployment api \
  --port=80 \
  --target-port=80 \
  --name=api-service \
  -n multi-ingress-demo

# Verificar
kubectl get all -n multi-ingress-demo
```

### 1.2 Ingress 1 - Blog

Crie o arquivo `ingress-blog.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-blog
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  labels:
    app: blog
    team: content
spec:
  ingressClassName: nginx
  rules:
  - host: blog.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80
```

### 1.3 Ingress 2 - Shop

Crie o arquivo `ingress-shop.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-shop
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/limit-rps: "100"
  labels:
    app: shop
    team: ecommerce
spec:
  ingressClassName: nginx
  rules:
  - host: shop.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop-service
            port:
              number: 80
```

### 1.4 Ingress 3 - API

Crie o arquivo `ingress-api.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-api
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
  labels:
    app: api
    team: backend
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

### 1.5 Aplicar e Testar

```bash
# Aplicar todos os Ingresses
kubectl apply -f ingress-blog.yaml
kubectl apply -f ingress-shop.yaml
kubectl apply -f ingress-api.yaml

# Verificar
kubectl get ingress -n multi-ingress-demo
kubectl describe ingress -n multi-ingress-demo

# Configurar /etc/hosts
sudo bash -c 'cat >> /etc/hosts << EOF
127.0.0.1 blog.example.com
127.0.0.1 shop.example.com
127.0.0.1 api.example.com
EOF'

# Testar cada host
curl http://blog.example.com
curl http://shop.example.com
curl http://api.example.com/get
```

---

## Cenário 2: Múltiplos Ingresses no Mesmo Host (Paths Diferentes)

### Arquitetura

```
app.example.com
    ├─→ /blog/*  → Ingress 1 → Blog Service
    ├─→ /shop/*  → Ingress 2 → Shop Service
    └─→ /api/*   → Ingress 3 → API Service
```

### 2.1 Ingress com Path /blog

Crie o arquivo `ingress-path-blog.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-path-blog
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /blog(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: blog-service
            port:
              number: 80
```

### 2.2 Ingress com Path /shop

Crie o arquivo `ingress-path-shop.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-path-shop
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /shop(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: shop-service
            port:
              number: 80
```

### 2.3 Ingress com Path /api

Crie o arquivo `ingress-path-api.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-path-api
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: api-service
            port:
              number: 80
```

### 2.4 Aplicar e Testar

```bash
# Aplicar
kubectl apply -f ingress-path-blog.yaml
kubectl apply -f ingress-path-shop.yaml
kubectl apply -f ingress-path-api.yaml

# Verificar
kubectl get ingress -n multi-ingress-demo

# Adicionar ao /etc/hosts
sudo bash -c 'echo "127.0.0.1 app.example.com" >> /etc/hosts'

# Testar paths
curl http://app.example.com/blog
curl http://app.example.com/shop
curl http://app.example.com/api/get
```

---

## Cenário 3: Múltiplos Ingresses em Namespaces Diferentes

### Arquitetura

```
Ingress Controller
    ├─→ Namespace: production
    │   └─→ Ingress (prod.example.com)
    ├─→ Namespace: staging
    │   └─→ Ingress (staging.example.com)
    └─→ Namespace: development
        └─→ Ingress (dev.example.com)
```

### 3.1 Criar Namespaces e Aplicações

```bash
# Criar namespaces
kubectl create namespace production
kubectl create namespace staging
kubectl create namespace development

# Deploy em Production
kubectl create deployment web \
  --image=nginx:alpine \
  --replicas=3 \
  -n production

kubectl expose deployment web \
  --port=80 \
  --name=web-service \
  -n production

# Deploy em Staging
kubectl create deployment web \
  --image=nginx:alpine \
  --replicas=2 \
  -n staging

kubectl expose deployment web \
  --port=80 \
  --name=web-service \
  -n staging

# Deploy em Development
kubectl create deployment web \
  --image=nginx:alpine \
  --replicas=1 \
  -n development

kubectl expose deployment web \
  --port=80 \
  --name=web-service \
  -n development
```

### 3.2 Ingress Production

Crie o arquivo `ingress-production.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-production
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  labels:
    environment: production
spec:
  ingressClassName: nginx
  rules:
  - host: prod.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### 3.3 Ingress Staging

Crie o arquivo `ingress-staging.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-staging
  namespace: staging
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  labels:
    environment: staging
spec:
  ingressClassName: nginx
  rules:
  - host: staging.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### 3.4 Ingress Development

Crie o arquivo `ingress-development.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-development
  namespace: development
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  labels:
    environment: development
spec:
  ingressClassName: nginx
  rules:
  - host: dev.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### 3.5 Aplicar e Testar

```bash
# Aplicar
kubectl apply -f ingress-production.yaml
kubectl apply -f ingress-staging.yaml
kubectl apply -f ingress-development.yaml

# Verificar todos os Ingresses
kubectl get ingress --all-namespaces

# Configurar /etc/hosts
sudo bash -c 'cat >> /etc/hosts << EOF
127.0.0.1 prod.example.com
127.0.0.1 staging.example.com
127.0.0.1 dev.example.com
EOF'

# Testar
curl http://prod.example.com
curl http://staging.example.com
curl http://dev.example.com
```

---

## Cenário 4: Ingresses com Diferentes Annotations

### 4.1 Ingress com Basic Auth

Crie o arquivo `ingress-with-auth.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-with-auth
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
spec:
  ingressClassName: nginx
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80
```

### 4.2 Criar Secret para Basic Auth

```bash
# Criar usuário e senha
htpasswd -c auth admin
# Senha: admin123

# Criar secret
kubectl create secret generic basic-auth \
  --from-file=auth \
  -n multi-ingress-demo

# Aplicar Ingress
kubectl apply -f ingress-with-auth.yaml

# Testar
curl http://secure.example.com
# Deve retornar 401

curl -u admin:admin123 http://secure.example.com
# Deve funcionar
```

### 4.3 Ingress com Whitelist IP

Crie o arquivo `ingress-with-whitelist.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-with-whitelist
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
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
            name: api-service
            port:
              number: 80
```

### 4.4 Ingress com Redirect

Crie o arquivo `ingress-with-redirect.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-with-redirect
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/permanent-redirect: "https://blog.example.com"
spec:
  ingressClassName: nginx
  rules:
  - host: old.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80
```

---

## Cenário 5: Ingresses com TLS em Diferentes Domínios

### 5.1 Criar Certificados

```bash
# Certificado para blog.example.com
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout blog-tls.key -out blog-tls.crt \
  -subj "/CN=blog.example.com/O=Blog"

kubectl create secret tls blog-tls-secret \
  --cert=blog-tls.crt \
  --key=blog-tls.key \
  -n multi-ingress-demo

# Certificado para shop.example.com
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout shop-tls.key -out shop-tls.crt \
  -subj "/CN=shop.example.com/O=Shop"

kubectl create secret tls shop-tls-secret \
  --cert=shop-tls.crt \
  --key=shop-tls.key \
  -n multi-ingress-demo

# Certificado para api.example.com
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout api-tls.key -out api-tls.crt \
  -subj "/CN=api.example.com/O=API"

kubectl create secret tls api-tls-secret \
  --cert=api-tls.crt \
  --key=api-tls.key \
  -n multi-ingress-demo
```

### 5.2 Ingress Blog com TLS

Crie o arquivo `ingress-blog-tls.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-blog-tls
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - blog.example.com
    secretName: blog-tls-secret
  rules:
  - host: blog.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80
```

### 5.3 Ingress Shop com TLS

Crie o arquivo `ingress-shop-tls.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-shop-tls
  namespace: multi-ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - shop.example.com
    secretName: shop-tls-secret
  rules:
  - host: shop.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop-service
            port:
              number: 80
```

### 5.4 Testar TLS

```bash
# Aplicar
kubectl apply -f ingress-blog-tls.yaml
kubectl apply -f ingress-shop-tls.yaml

# Testar HTTPS
curl -k https://blog.example.com
curl -k https://shop.example.com

# Verificar certificado
openssl s_client -connect blog.example.com:443 -servername blog.example.com < /dev/null 2>/dev/null | openssl x509 -noout -text | grep CN
```

---

## Gerenciamento de Múltiplos Ingresses

### Listar Todos os Ingresses

```bash
# Todos os namespaces
kubectl get ingress --all-namespaces

# Com labels
kubectl get ingress --all-namespaces --show-labels

# Filtrar por label
kubectl get ingress -l team=backend --all-namespaces

# Output customizado
kubectl get ingress --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
HOSTS:.spec.rules[*].host,\
ADDRESS:.status.loadBalancer.ingress[*].ip
```

### Verificar Configuração do Nginx

```bash
# Ver configuração gerada
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
  cat /etc/nginx/nginx.conf | grep -A 10 "server_name"

# Ver upstreams
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
  cat /etc/nginx/nginx.conf | grep -A 5 "upstream"
```

### Monitorar Logs por Ingress

```bash
# Logs do controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f

# Filtrar por host específico
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f | grep "blog.example.com"

# Ver apenas erros
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f | grep -i error
```

---

## Boas Práticas

### 1. Organização por Labels

```yaml
metadata:
  labels:
    app: blog
    team: content
    environment: production
    version: v1
```

### 2. Naming Convention

```yaml
# Padrão: ingress-<app>-<environment>-<feature>
metadata:
  name: ingress-blog-production-main
  name: ingress-shop-staging-api
  name: ingress-api-development-v2
```

### 3. Annotations Consistentes

```yaml
annotations:
  # Sempre incluir
  nginx.ingress.kubernetes.io/rewrite-target: /
  
  # Segurança
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  
  # Performance
  nginx.ingress.kubernetes.io/proxy-body-size: "10m"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
```

### 4. Separação por Namespace

```bash
# Produção
kubectl apply -f ingress-prod.yaml -n production

# Staging
kubectl apply -f ingress-staging.yaml -n staging

# Development
kubectl apply -f ingress-dev.yaml -n development
```

---

## Troubleshooting

### Problema 1: Conflito de Hosts

```bash
# Verificar conflitos
kubectl get ingress --all-namespaces -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.spec.rules[].host)"' | \
  sort

# Solução: Usar hosts únicos ou paths diferentes
```

### Problema 2: Ingress Não Aparece no Controller

```bash
# Verificar ingressClassName
kubectl get ingress <name> -n <namespace> -o yaml | grep ingressClassName

# Verificar se controller está rodando
kubectl get pods -n ingress-nginx

# Ver logs do controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50
```

### Problema 3: Roteamento Incorreto

```bash
# Verificar ordem de prioridade
kubectl get ingress --all-namespaces --sort-by=.metadata.creationTimestamp

# Testar com header Host
curl -H "Host: blog.example.com" http://localhost

# Ver configuração do Nginx
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- \
  nginx -T | grep -A 20 "server_name blog.example.com"
```

### Problema 4: TLS Não Funciona

```bash
# Verificar secrets
kubectl get secrets -n multi-ingress-demo | grep tls

# Verificar certificado
kubectl get secret blog-tls-secret -n multi-ingress-demo -o yaml

# Testar TLS
curl -vk https://blog.example.com 2>&1 | grep -i "ssl\|tls"
```

---

## Stack Completa - Múltiplos Ingresses

Crie o arquivo `multi-ingress-complete.yaml`:

```yaml
---
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: multi-app

---
# App 1: Blog
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog
  namespace: multi-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blog
  template:
    metadata:
      labels:
        app: blog
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: blog-service
  namespace: multi-app
spec:
  selector:
    app: blog
  ports:
  - port: 80

---
# App 2: Shop
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
  namespace: multi-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shop
  template:
    metadata:
      labels:
        app: shop
    spec:
      containers:
      - name: httpd
        image: httpd:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: shop-service
  namespace: multi-app
spec:
  selector:
    app: shop
  ports:
  - port: 80

---
# App 3: API
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: multi-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: multi-app
spec:
  selector:
    app: api
  ports:
  - port: 80

---
# Ingress 1: Blog
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-blog
  namespace: multi-app
  labels:
    app: blog
spec:
  ingressClassName: nginx
  rules:
  - host: blog.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80

---
# Ingress 2: Shop
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-shop
  namespace: multi-app
  labels:
    app: shop
spec:
  ingressClassName: nginx
  rules:
  - host: shop.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop-service
            port:
              number: 80

---
# Ingress 3: API
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-api
  namespace: multi-app
  labels:
    app: api
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

### Deploy Completo

```bash
# Aplicar tudo
kubectl apply -f multi-ingress-complete.yaml

# Verificar
kubectl get all,ingress -n multi-app

# Configurar hosts
sudo bash -c 'cat >> /etc/hosts << EOF
127.0.0.1 blog.example.com
127.0.0.1 shop.example.com
127.0.0.1 api.example.com
EOF'

# Testar
curl http://blog.example.com
curl http://shop.example.com
curl http://api.example.com/get
```

---

## Limpeza

```bash
# Deletar namespace específico
kubectl delete namespace multi-ingress-demo
kubectl delete namespace multi-app

# Deletar por ambiente
kubectl delete namespace production
kubectl delete namespace staging
kubectl delete namespace development

# Deletar Ingresses específicos
kubectl delete ingress ingress-blog -n multi-ingress-demo
kubectl delete ingress ingress-shop -n multi-ingress-demo

# Verificar
kubectl get ingress --all-namespaces
```

---

## Resumo dos Comandos

```bash
# Criar múltiplos Ingresses
kubectl apply -f ingress-1.yaml
kubectl apply -f ingress-2.yaml
kubectl apply -f ingress-3.yaml

# Listar todos
kubectl get ingress --all-namespaces

# Verificar por namespace
kubectl get ingress -n production

# Filtrar por label
kubectl get ingress -l app=blog --all-namespaces

# Ver detalhes
kubectl describe ingress <name> -n <namespace>

# Testar
curl http://host1.example.com
curl http://host2.example.com

# Deletar
kubectl delete ingress <name> -n <namespace>
```

---

## Conclusão

Múltiplos Ingresses no mesmo Controller permitem:

✅ **Organização** - Separar regras por aplicação  
✅ **Flexibilidade** - Diferentes annotations por Ingress  
✅ **Isolamento** - Namespaces separados  
✅ **Manutenção** - Atualizar sem afetar outros  
✅ **Escalabilidade** - Adicionar novos Ingresses facilmente  
✅ **Segurança** - Políticas diferentes por aplicação  

Um único Ingress Controller pode gerenciar centenas de Ingresses, tornando a solução eficiente e econômica!
