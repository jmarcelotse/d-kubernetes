# O que é o Ingress no Kubernetes?

## Introdução

**Ingress** é um objeto da API do Kubernetes que gerencia o acesso externo aos serviços dentro do cluster, tipicamente HTTP e HTTPS. Ele fornece roteamento baseado em regras, balanceamento de carga, terminação SSL e hospedagem virtual baseada em nome.

## Conceito

O Ingress atua como uma camada de roteamento inteligente que fica entre o mundo externo e os Services internos do cluster. Ele permite expor múltiplos serviços através de um único ponto de entrada (IP ou domínio), usando regras de roteamento baseadas em host e path.

### Por Que Usar Ingress?

- **Economia:** Um único LoadBalancer em vez de múltiplos
- **Roteamento Inteligente:** Baseado em host e path
- **SSL/TLS Centralizado:** Terminação SSL em um único ponto
- **Virtual Hosting:** Múltiplos domínios no mesmo IP
- **Gerenciamento Simplificado:** Regras declarativas
- **Features Avançadas:** Rate limiting, autenticação, rewrite, etc.

## Componentes do Ingress

### 1. Ingress Resource

Objeto YAML que define as regras de roteamento.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  rules:
  - host: myapp.example.com
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

### 2. Ingress Controller

Componente que implementa as regras do Ingress. Exemplos:
- **Nginx Ingress Controller** (mais popular)
- **Traefik**
- **HAProxy**
- **Kong**
- **Istio Gateway**
- **AWS ALB Ingress Controller**
- **GCE Ingress Controller**

**Importante:** O Ingress Resource sozinho não faz nada. Você precisa de um Ingress Controller instalado no cluster.

## Diferença: Service vs Ingress

| Aspecto | Service (LoadBalancer) | Ingress |
|---------|------------------------|---------|
| **Custo** | Um LoadBalancer por Service | Um LoadBalancer para todos |
| **IP Externo** | Um por Service | Um para múltiplos Services |
| **Roteamento** | Apenas porta | Host + Path |
| **SSL/TLS** | Por Service | Centralizado |
| **Domínios** | Um por Service | Múltiplos no mesmo IP |
| **Layer** | Layer 4 (TCP/UDP) | Layer 7 (HTTP/HTTPS) |

## Fluxo de Funcionamento

```
1. Cliente faz requisição HTTP/HTTPS
   ↓
2. DNS resolve para IP do Ingress
   ↓
3. Requisição chega no Ingress Controller
   ↓
4. Ingress Controller lê regras do Ingress
   ↓
5. Roteia para Service correto baseado em host/path
   ↓
6. Service encaminha para Pods
   ↓
7. Resposta retorna pelo mesmo caminho
```

### Fluxo Visual

```
Internet
   ↓
DNS (myapp.example.com → 203.0.113.10)
   ↓
Ingress Controller (LoadBalancer IP: 203.0.113.10)
   ↓
Ingress Rules (host + path matching)
   ↓
Service (ClusterIP)
   ↓
Pods
```

## Anatomia de um Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  namespace: default
  annotations:
    # Annotations específicas do Ingress Controller
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  # Classe do Ingress Controller
  ingressClassName: nginx
  
  # TLS/SSL
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  
  # Regras de roteamento
  rules:
  - host: myapp.example.com
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

### Campos Principais

- **ingressClassName:** Qual Ingress Controller usar
- **tls:** Configuração SSL/TLS
- **rules:** Regras de roteamento
- **host:** Domínio (virtual hosting)
- **path:** Caminho da URL
- **pathType:** Tipo de matching (Prefix, Exact, ImplementationSpecific)
- **backend:** Service de destino

## Instalação do Nginx Ingress Controller

### Método 1: Helm (Recomendado)

```bash
# Adicionar repositório Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Instalar Nginx Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

**Saída esperada:**
```
NAME: ingress-nginx
NAMESPACE: ingress-nginx
STATUS: deployed
```

### Método 2: Manifesto YAML

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
```

**Saída esperada:**
```
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
...
deployment.apps/ingress-nginx-controller created
```

### Verificar Instalação

```bash
# Verificar namespace
kubectl get all -n ingress-nginx

# Verificar Ingress Controller
kubectl get pods -n ingress-nginx

# Obter IP externo
kubectl get service -n ingress-nginx ingress-nginx-controller
```

**Saída esperada:**
```
NAME                                        TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
ingress-nginx-controller                    LoadBalancer   10.96.100.50    203.0.113.10    80:30080/TCP,443:30443/TCP
```

## Exemplo Prático 1: Ingress Básico

### 1. Criar Aplicação

```yaml
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
        - "-text=Hello from Kubernetes!"
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
kubectl apply -f hello-app.yaml
```

**Saída esperada:**
```
deployment.apps/hello-app created
service/hello-service created
```

### 2. Criar Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: hello.example.com
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

```bash
kubectl apply -f hello-ingress.yaml
```

**Saída esperada:**
```
ingress.networking.k8s.io/hello-ingress created
```

### 3. Verificar Ingress

```bash
kubectl get ingress hello-ingress
```

**Saída esperada:**
```
NAME            CLASS   HOSTS               ADDRESS         PORTS   AGE
hello-ingress   nginx   hello.example.com   203.0.113.10    80      30s
```

### 4. Testar

```bash
# Obter IP do Ingress
INGRESS_IP=$(kubectl get ingress hello-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Testar com curl (simulando DNS)
curl -H "Host: hello.example.com" http://$INGRESS_IP
```

**Saída esperada:**
```
Hello from Kubernetes!
```

### 5. Configurar DNS (Opcional)

```bash
# Adicionar entrada no /etc/hosts
echo "$INGRESS_IP hello.example.com" | sudo tee -a /etc/hosts

# Testar com domínio
curl http://hello.example.com
```

## Exemplo Prático 2: Múltiplos Hosts

### 1. Criar Aplicações

```yaml
# App 1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Application 1"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: app1-service
spec:
  selector:
    app: app1
  ports:
  - port: 80
    targetPort: 5678
---
# App 2
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Application 2"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: app2-service
spec:
  selector:
    app: app2
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f multi-apps.yaml
```

### 2. Ingress com Múltiplos Hosts

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

```bash
kubectl apply -f multi-host-ingress.yaml
```

### 3. Testar

```bash
INGRESS_IP=$(kubectl get ingress multi-host-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Testar App 1
curl -H "Host: app1.example.com" http://$INGRESS_IP

# Testar App 2
curl -H "Host: app2.example.com" http://$INGRESS_IP
```

**Saída esperada:**
```
Application 1
Application 2
```

## Exemplo Prático 3: Roteamento por Path

### 1. Criar Aplicações

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Frontend Application"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
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
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=API Backend"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f path-apps.yaml
```

### 2. Ingress com Path Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
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
            name: frontend-service
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
kubectl apply -f path-ingress.yaml
```

### 3. Testar

```bash
INGRESS_IP=$(kubectl get ingress path-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Testar frontend
curl -H "Host: myapp.example.com" http://$INGRESS_IP/

# Testar API
curl -H "Host: myapp.example.com" http://$INGRESS_IP/api
```

**Saída esperada:**
```
Frontend Application
API Backend
```

## Exemplo Prático 4: Ingress com TLS/SSL

### 1. Criar Certificado

```bash
# Gerar certificado autoassinado
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure.example.com/O=MyOrg"

# Criar Secret TLS
kubectl create secret tls secure-tls \
  --cert=tls.crt \
  --key=tls.key

# Limpar arquivos
rm tls.key tls.crt
```

**Saída esperada:**
```
secret/secure-tls created
```

### 2. Criar Aplicação

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure
  template:
    metadata:
      labels:
        app: secure
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Secure Application with TLS"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: secure-service
spec:
  selector:
    app: secure
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f secure-app.yaml
```

### 3. Ingress com TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.example.com
    secretName: secure-tls
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-service
            port:
              number: 80
```

```bash
kubectl apply -f secure-ingress.yaml
```

### 4. Testar HTTPS

```bash
INGRESS_IP=$(kubectl get ingress secure-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Testar HTTPS (ignorar verificação de certificado autoassinado)
curl -k -H "Host: secure.example.com" https://$INGRESS_IP

# Testar redirect HTTP -> HTTPS
curl -I -H "Host: secure.example.com" http://$INGRESS_IP
```

**Saída esperada:**
```
Secure Application with TLS

HTTP/1.1 308 Permanent Redirect
Location: https://secure.example.com/
```

## PathType: Tipos de Matching

### Prefix

Corresponde ao prefixo do path.

```yaml
path: /api
pathType: Prefix
# Matches: /api, /api/, /api/users, /api/v1/users
```

### Exact

Correspondência exata do path.

```yaml
path: /api
pathType: Exact
# Matches: /api
# NOT: /api/, /api/users
```

### ImplementationSpecific

Depende da implementação do Ingress Controller.

```yaml
path: /api
pathType: ImplementationSpecific
```

## Annotations Comuns (Nginx Ingress)

### Rewrite

```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /$2
```

### SSL Redirect

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

### CORS

```yaml
annotations:
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "*"
```

### Rate Limiting

```yaml
annotations:
  nginx.ingress.kubernetes.io/limit-rps: "10"
```

### Basic Auth

```yaml
annotations:
  nginx.ingress.kubernetes.io/auth-type: basic
  nginx.ingress.kubernetes.io/auth-secret: basic-auth
  nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
```

### Custom Headers

```yaml
annotations:
  nginx.ingress.kubernetes.io/configuration-snippet: |
    more_set_headers "X-Custom-Header: value";
```

## Comandos Úteis

### Listar Ingress

```bash
# Todos os Ingress
kubectl get ingress

# Com detalhes
kubectl get ingress -o wide

# Formato YAML
kubectl get ingress <name> -o yaml
```

### Descrever Ingress

```bash
kubectl describe ingress <name>
```

### Ver Logs do Ingress Controller

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Testar Ingress

```bash
# Com curl
curl -H "Host: myapp.example.com" http://<ingress-ip>

# Ver headers
curl -I -H "Host: myapp.example.com" http://<ingress-ip>

# Verbose
curl -v -H "Host: myapp.example.com" http://<ingress-ip>
```

## Troubleshooting

### Ingress não Funciona

```bash
# Verificar Ingress Controller está rodando
kubectl get pods -n ingress-nginx

# Ver logs do controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Verificar Service do Ingress
kubectl get service -n ingress-nginx

# Verificar Ingress
kubectl describe ingress <name>
```

### 404 Not Found

```bash
# Verificar Service existe
kubectl get service <service-name>

# Verificar Endpoints
kubectl get endpoints <service-name>

# Verificar Pods estão rodando
kubectl get pods -l <selector>
```

### SSL não Funciona

```bash
# Verificar Secret TLS existe
kubectl get secret <tls-secret>

# Verificar certificado
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Ver logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep ssl
```

## Boas Práticas

### 1. Use IngressClass

```yaml
spec:
  ingressClassName: nginx
```

### 2. Sempre Configure TLS

```yaml
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
```

### 3. Use Annotations para Customização

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/limit-rps: "100"
```

### 4. Organize por Namespace

```bash
# Ingress no mesmo namespace dos Services
kubectl apply -f ingress.yaml -n myapp
```

### 5. Documente com Labels

```yaml
metadata:
  labels:
    app: myapp
    environment: production
  annotations:
    description: "Main application ingress"
```

## Limpeza

```bash
# Remover Ingress
kubectl delete ingress hello-ingress multi-host-ingress path-ingress secure-ingress

# Remover Deployments
kubectl delete deployment hello-app app1 app2 frontend api secure-app

# Remover Services
kubectl delete service hello-service app1-service app2-service frontend-service api-service secure-service

# Remover Secrets
kubectl delete secret secure-tls

# Desinstalar Nginx Ingress (opcional)
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
```

## Resumo

- **Ingress gerencia acesso HTTP/HTTPS** aos Services
- **Um LoadBalancer para múltiplos Services** (economia)
- **Roteamento por host e path** (Layer 7)
- **Terminação SSL centralizada**
- **Requer Ingress Controller** (Nginx, Traefik, etc.)
- **Annotations** para features avançadas
- **PathType** define tipo de matching (Prefix, Exact)
- **IngressClass** especifica qual controller usar

## Próximos Passos

- Instalar **Cert-Manager** para SSL automático
- Configurar **rate limiting** e **WAF**
- Implementar **autenticação** (OAuth, OIDC)
- Usar **ExternalDNS** para automação de DNS
- Explorar **Gateway API** (sucessor do Ingress)
- Configurar **monitoramento** do Ingress
