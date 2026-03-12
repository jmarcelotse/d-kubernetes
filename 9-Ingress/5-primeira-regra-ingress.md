# Criando a Nossa Primeira Regra de Ingress

## Introdução

Uma **regra de Ingress** define como o tráfego HTTP/HTTPS deve ser roteado para os Services dentro do cluster. Neste guia, vamos criar nossa primeira regra de Ingress do zero, entendendo cada componente e testando o funcionamento.

## Anatomia de uma Regra de Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

### Componentes Principais

- **apiVersion:** `networking.k8s.io/v1`
- **kind:** `Ingress`
- **metadata.name:** Nome único do Ingress
- **spec.ingressClassName:** Qual Ingress Controller usar
- **spec.rules:** Lista de regras de roteamento
- **host:** Domínio (opcional)
- **path:** Caminho da URL
- **pathType:** Tipo de matching
- **backend:** Service de destino

## Fluxo de Criação

```
1. Criar aplicação (Deployment + Service)
   ↓
2. Definir regra de Ingress
   ↓
3. Aplicar Ingress no cluster
   ↓
4. Ingress Controller configura Nginx
   ↓
5. Testar acesso via host/path
```

## Pré-requisitos

### Verificar Ingress Controller

```bash
# Verificar se Nginx Ingress está instalado
kubectl get pods -n ingress-nginx

# Verificar IngressClass
kubectl get ingressclass
```

**Saída esperada:**
```
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       5m
```

## Exemplo 1: Regra Básica (Single Host)

### 1. Criar Aplicação

```yaml
# app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
  labels:
    app: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: hashicorp/http-echo:1.0
        args:
        - "-text=Hello from my first Ingress!"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: hello-service
spec:
  selector:
    app: hello
  ports:
  - port: 80
    targetPort: 5678
  type: ClusterIP
```

```bash
kubectl apply -f app.yaml
```

**Saída esperada:**
```
deployment.apps/hello-app created
service/hello-service created
```

### 2. Criar Primeira Regra de Ingress

```yaml
# first-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: first-ingress
  labels:
    app: hello
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: hello.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-service
            port:
              number: 80
```

**Explicação dos campos:**
- **ingressClassName:** Usa o Nginx Ingress Controller
- **host:** Domínio que será usado (hello.local)
- **path:** Rota (/ = raiz)
- **pathType:** Prefix = qualquer path que comece com /
- **backend.service.name:** Nome do Service
- **backend.service.port.number:** Porta do Service

```bash
kubectl apply -f first-ingress.yaml
```

**Saída esperada:**
```
ingress.networking.k8s.io/first-ingress created
```

### 3. Verificar Ingress

```bash
# Ver Ingress criado
kubectl get ingress first-ingress

# Ver detalhes
kubectl describe ingress first-ingress
```

**Saída esperada:**
```
NAME            CLASS   HOSTS         ADDRESS         PORTS   AGE
first-ingress   nginx   hello.local   203.0.113.10    80      30s

Name:             first-ingress
Namespace:        default
Address:          203.0.113.10
Ingress Class:    nginx
Default backend:  <default>
Rules:
  Host         Path  Backends
  ----         ----  --------
  hello.local
               /   hello-service:80 (10.244.1.5:5678,10.244.2.3:5678)
```

### 4. Configurar DNS Local

```bash
# Obter IP do Ingress
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Se estiver usando Kind
INGRESS_IP="127.0.0.1"

# Adicionar ao /etc/hosts
echo "$INGRESS_IP hello.local" | sudo tee -a /etc/hosts
```

### 5. Testar Ingress

```bash
# Testar com curl
curl http://hello.local

# Testar com header (sem DNS)
curl -H "Host: hello.local" http://$INGRESS_IP

# Ver headers da resposta
curl -I http://hello.local
```

**Saída esperada:**
```
Hello from my first Ingress!
```

### 6. Ver Logs do Ingress Controller

```bash
# Ver logs em tempo real
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f

# Fazer requisição e ver log
curl http://hello.local
```

**Saída esperada (logs):**
```
10.244.0.1 - - [11/Mar/2026:15:10:40 +0000] "GET / HTTP/1.1" 200 28 "-" "curl/7.81.0"
```

## Exemplo 2: Regra sem Host (Default Backend)

### 1. Criar Ingress sem Host

```yaml
# default-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: default-ingress
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-service
            port:
              number: 80
```

**Nota:** Sem campo `host`, aceita qualquer domínio.

```bash
kubectl apply -f default-ingress.yaml
```

### 2. Testar

```bash
# Funciona com qualquer host
curl http://$INGRESS_IP
curl -H "Host: anything.com" http://$INGRESS_IP
curl -H "Host: test.local" http://$INGRESS_IP
```

**Saída esperada:** Todas as requisições retornam a mesma resposta.

## Exemplo 3: Regra com Múltiplos Paths

### 1. Criar Múltiplas Aplicações

```yaml
# multi-path-apps.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: home-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: home
  template:
    metadata:
      labels:
        app: home
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Home Page"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: home-service
spec:
  selector:
    app: home
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: about-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: about
  template:
    metadata:
      labels:
        app: about
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=About Page"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: about-service
spec:
  selector:
    app: about
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: contact-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: contact
  template:
    metadata:
      labels:
        app: contact
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Contact Page"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: contact-service
spec:
  selector:
    app: contact
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f multi-path-apps.yaml
```

### 2. Criar Ingress com Múltiplos Paths

```yaml
# multi-path-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: mysite.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: home-service
            port:
              number: 80
      - path: /about
        pathType: Prefix
        backend:
          service:
            name: about-service
            port:
              number: 80
      - path: /contact
        pathType: Prefix
        backend:
          service:
            name: contact-service
            port:
              number: 80
```

**Explicação:**
- `/` → home-service
- `/about` → about-service
- `/contact` → contact-service

```bash
kubectl apply -f multi-path-ingress.yaml
echo "127.0.0.1 mysite.local" | sudo tee -a /etc/hosts
```

### 3. Testar Cada Path

```bash
# Home
curl http://mysite.local/

# About
curl http://mysite.local/about

# Contact
curl http://mysite.local/contact
```

**Saída esperada:**
```
Home Page
About Page
Contact Page
```

## Exemplo 4: Regra com PathType Exact

### 1. Criar Ingress com Exact Match

```yaml
# exact-path-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: exact-path-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: exact.local
    http:
      paths:
      # Exact match - apenas /api
      - path: /api
        pathType: Exact
        backend:
          service:
            name: about-service
            port:
              number: 80
      # Prefix match - /api/*
      - path: /api/
        pathType: Prefix
        backend:
          service:
            name: contact-service
            port:
              number: 80
```

```bash
kubectl apply -f exact-path-ingress.yaml
echo "127.0.0.1 exact.local" | sudo tee -a /etc/hosts
```

### 2. Testar Diferença

```bash
# Exact match - vai para about-service
curl http://exact.local/api

# Prefix match - vai para contact-service
curl http://exact.local/api/
curl http://exact.local/api/users
curl http://exact.local/api/v1/users
```

**Saída esperada:**
```
About Page
Contact Page
Contact Page
Contact Page
```

## Exemplo 5: Regra com Prioridade de Paths

### Ordem de Prioridade

Paths mais específicos devem vir primeiro:

```yaml
# priority-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: priority-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: priority.local
    http:
      paths:
      # Mais específico primeiro
      - path: /api/v2
        pathType: Prefix
        backend:
          service:
            name: contact-service
            port:
              number: 80
      # Menos específico depois
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: about-service
            port:
              number: 80
      # Catch-all por último
      - path: /
        pathType: Prefix
        backend:
          service:
            name: home-service
            port:
              number: 80
```

```bash
kubectl apply -f priority-ingress.yaml
echo "127.0.0.1 priority.local" | sudo tee -a /etc/hosts
```

### Testar Prioridade

```bash
# Vai para contact-service (mais específico)
curl http://priority.local/api/v2

# Vai para about-service
curl http://priority.local/api

# Vai para home-service (catch-all)
curl http://priority.local/
curl http://priority.local/anything
```

## Exemplo 6: Regra Completa com Annotations

```yaml
# complete-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: complete-ingress
  labels:
    app: myapp
    environment: production
  annotations:
    # Rewrite
    nginx.ingress.kubernetes.io/rewrite-target: /
    
    # SSL Redirect
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    
    # CORS
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    
    # Rate Limiting
    nginx.ingress.kubernetes.io/limit-rps: "10"
    
    # Timeouts
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    
    # Custom Headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Custom-Header: MyValue";
      more_set_headers "X-Environment: Production";
spec:
  ingressClassName: nginx
  rules:
  - host: complete.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: home-service
            port:
              number: 80
```

```bash
kubectl apply -f complete-ingress.yaml
echo "127.0.0.1 complete.local" | sudo tee -a /etc/hosts
```

### Testar Annotations

```bash
# Ver headers customizados
curl -I http://complete.local

# Testar CORS
curl -H "Origin: http://example.com" -I http://complete.local

# Testar rate limiting (fazer múltiplas requisições rápidas)
for i in {1..15}; do curl http://complete.local; done
```

## Verificação e Debug

### Ver Regras Aplicadas

```bash
# Listar todos os Ingress
kubectl get ingress

# Ver detalhes de um Ingress
kubectl describe ingress first-ingress

# Ver YAML completo
kubectl get ingress first-ingress -o yaml

# Ver apenas as regras
kubectl get ingress first-ingress -o jsonpath='{.spec.rules}' | jq
```

### Ver Configuração do Nginx

```bash
# Entrar no Pod do Ingress Controller
POD_NAME=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')

# Ver nginx.conf
kubectl exec -n ingress-nginx $POD_NAME -- cat /etc/nginx/nginx.conf | grep -A 20 "server_name hello.local"

# Testar configuração
kubectl exec -n ingress-nginx $POD_NAME -- nginx -t
```

### Ver Logs de Acesso

```bash
# Logs do Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50

# Filtrar por host
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep "hello.local"

# Logs em tempo real
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

## Troubleshooting

### Ingress não Funciona

```bash
# 1. Verificar Ingress existe
kubectl get ingress

# 2. Verificar IngressClass
kubectl get ingressclass

# 3. Verificar Service existe
kubectl get service hello-service

# 4. Verificar Endpoints
kubectl get endpoints hello-service

# 5. Ver eventos
kubectl describe ingress first-ingress

# 6. Ver logs do controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### 404 Not Found

```bash
# Verificar path está correto
kubectl get ingress first-ingress -o jsonpath='{.spec.rules[0].http.paths[0].path}'

# Verificar Service está correto
kubectl get ingress first-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}'

# Testar Service diretamente
kubectl run test --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://hello-service
```

### Host não Resolve

```bash
# Verificar /etc/hosts
cat /etc/hosts | grep hello.local

# Testar com header Host
curl -H "Host: hello.local" http://$INGRESS_IP

# Verificar DNS
nslookup hello.local
```

## Comandos Úteis

### Criar Ingress

```bash
# Via arquivo YAML
kubectl apply -f ingress.yaml

# Via kubectl create (básico)
kubectl create ingress simple-ingress \
  --rule="hello.local/=hello-service:80"

# Com múltiplas regras
kubectl create ingress multi-ingress \
  --rule="app1.local/=service1:80" \
  --rule="app2.local/=service2:80"
```

### Editar Ingress

```bash
# Editar interativamente
kubectl edit ingress first-ingress

# Patch
kubectl patch ingress first-ingress -p '{"spec":{"rules":[{"host":"new.local"}]}}'

# Substituir
kubectl apply -f updated-ingress.yaml
```

### Deletar Ingress

```bash
# Deletar específico
kubectl delete ingress first-ingress

# Deletar múltiplos
kubectl delete ingress first-ingress second-ingress

# Deletar por label
kubectl delete ingress -l app=myapp
```

## Boas Práticas

### 1. Use IngressClassName

```yaml
spec:
  ingressClassName: nginx  # ✅ Explícito
```

### 2. Sempre Defina Host

```yaml
rules:
- host: myapp.example.com  # ✅ Específico
```

### 3. Organize Paths por Especificidade

```yaml
paths:
- path: /api/v2      # ✅ Mais específico primeiro
- path: /api
- path: /
```

### 4. Use Labels e Annotations

```yaml
metadata:
  labels:
    app: myapp
    environment: prod
  annotations:
    description: "Main application ingress"
```

### 5. Documente Regras

```yaml
# Comentários no YAML
rules:
- host: myapp.com
  http:
    paths:
    # Frontend
    - path: /
      pathType: Prefix
      backend:
        service:
          name: frontend-service
          port:
            number: 80
    # API Backend
    - path: /api
      pathType: Prefix
      backend:
        service:
          name: api-service
          port:
            number: 80
```

## Limpeza

```bash
# Remover Ingress
kubectl delete ingress first-ingress default-ingress multi-path-ingress
kubectl delete ingress exact-path-ingress priority-ingress complete-ingress

# Remover aplicações
kubectl delete deployment hello-app home-app about-app contact-app
kubectl delete service hello-service home-service about-service contact-service

# Limpar /etc/hosts
sudo sed -i '/\.local/d' /etc/hosts
```

## Resumo

- **Regra de Ingress** define roteamento HTTP/HTTPS
- **host** especifica domínio (opcional)
- **path** define rota da URL
- **pathType** controla matching (Prefix, Exact)
- **backend** aponta para Service
- **Annotations** adicionam funcionalidades
- **Ordem importa** - paths específicos primeiro
- **IngressClassName** identifica controller

## Próximos Passos

- Adicionar **SSL/TLS** às regras
- Configurar **múltiplos hosts** em um Ingress
- Implementar **autenticação** (Basic Auth, OAuth)
- Usar **rate limiting** e **WAF**
- Configurar **canary deployments**
- Explorar **rewrite rules** avançadas
