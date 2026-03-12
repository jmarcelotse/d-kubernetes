# Deploy da Aplicação de Exemplo para Expor via Ingress

## Introdução

Neste guia, vamos fazer o deploy de uma aplicação de exemplo que será exposta através do Ingress. Usaremos uma aplicação web simples para demonstrar todos os conceitos de roteamento, SSL e configurações avançadas do Ingress.

## Aplicação de Exemplo

Vamos usar o **Nginx** como servidor web para hospedar uma aplicação HTML simples. Esta aplicação será exposta através do Ingress com diferentes configurações.

## Fluxo Completo

```
1. Criar aplicação (Deployment + Service)
   ↓
2. Criar Ingress Resource
   ↓
3. Ingress Controller roteia tráfego
   ↓
4. Service encaminha para Pods
   ↓
5. Aplicação responde
```

## Exemplo 1: Aplicação Web Simples

### 1. Criar ConfigMap com HTML

```yaml
# webapp-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-html
  labels:
    app: webapp
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Aplicação de Exemplo - Kubernetes Ingress</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }
            
            .container {
                background: white;
                padding: 40px;
                border-radius: 12px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                max-width: 800px;
                width: 100%;
            }
            
            h1 {
                color: #333;
                margin-bottom: 20px;
                font-size: 2.5em;
                text-align: center;
            }
            
            .status {
                background: #28a745;
                color: white;
                padding: 15px;
                border-radius: 8px;
                text-align: center;
                margin: 20px 0;
                font-size: 1.2em;
            }
            
            .info {
                background: #f8f9fa;
                padding: 20px;
                border-radius: 8px;
                margin: 20px 0;
            }
            
            .info h2 {
                color: #555;
                margin-bottom: 15px;
                font-size: 1.5em;
            }
            
            .info ul {
                list-style: none;
                padding-left: 0;
            }
            
            .info li {
                padding: 10px 0;
                border-bottom: 1px solid #dee2e6;
                color: #666;
            }
            
            .info li:last-child {
                border-bottom: none;
            }
            
            .info li strong {
                color: #333;
                margin-right: 10px;
            }
            
            .footer {
                text-align: center;
                margin-top: 30px;
                color: #999;
                font-size: 0.9em;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Aplicação Kubernetes</h1>
            
            <div class="status">
                ✓ Aplicação rodando com sucesso!
            </div>
            
            <div class="info">
                <h2>Informações da Aplicação</h2>
                <ul>
                    <li><strong>Servidor:</strong> Nginx</li>
                    <li><strong>Ambiente:</strong> Kubernetes</li>
                    <li><strong>Exposição:</strong> Ingress Controller</li>
                    <li><strong>Protocolo:</strong> HTTP/HTTPS</li>
                </ul>
            </div>
            
            <div class="info">
                <h2>Recursos Kubernetes</h2>
                <ul>
                    <li><strong>Deployment:</strong> webapp</li>
                    <li><strong>Service:</strong> webapp-service (ClusterIP)</li>
                    <li><strong>Ingress:</strong> webapp-ingress</li>
                    <li><strong>Réplicas:</strong> 3 Pods</li>
                </ul>
            </div>
            
            <div class="footer">
                <p>Kubernetes Ingress Demo Application</p>
                <p>Powered by Nginx</p>
            </div>
        </div>
    </body>
    </html>
```

```bash
kubectl apply -f webapp-config.yaml
```

**Saída esperada:**
```
configmap/webapp-html created
```

### 2. Criar Deployment

```yaml
# webapp-deployment.yaml
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
          name: http
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: html
        configMap:
          name: webapp-html
```

```bash
kubectl apply -f webapp-deployment.yaml
```

**Saída esperada:**
```
deployment.apps/webapp created
```

### 3. Criar Service

```yaml
# webapp-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  labels:
    app: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  type: ClusterIP
```

```bash
kubectl apply -f webapp-service.yaml
```

**Saída esperada:**
```
service/webapp-service created
```

### 4. Verificar Deployment

```bash
# Ver Pods
kubectl get pods -l app=webapp

# Ver Deployment
kubectl get deployment webapp

# Ver Service
kubectl get service webapp-service

# Testar Service internamente
kubectl run test --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://webapp-service
```

**Saída esperada:**
```
NAME                      READY   STATUS    RESTARTS   AGE
webapp-5d7f8c9b4d-abc12   1/1     Running   0          1m
webapp-5d7f8c9b4d-def34   1/1     Running   0          1m
webapp-5d7f8c9b4d-ghi56   1/1     Running   0          1m

NAME     READY   UP-TO-DATE   AVAILABLE   AGE
webapp   3/3     3            3           1m

NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
webapp-service   ClusterIP   10.96.100.50    <none>        80/TCP    1m
```

### 5. Criar Ingress

```yaml
# webapp-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: webapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-service
            port:
              number: 80
```

```bash
kubectl apply -f webapp-ingress.yaml
```

**Saída esperada:**
```
ingress.networking.k8s.io/webapp-ingress created
```

### 6. Configurar DNS Local

```bash
# Obter IP do Ingress
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Se estiver usando Kind, use localhost
INGRESS_IP="127.0.0.1"

# Adicionar ao /etc/hosts
echo "$INGRESS_IP webapp.local" | sudo tee -a /etc/hosts
```

### 7. Testar Aplicação

```bash
# Via curl
curl http://webapp.local

# Via navegador
# Abrir: http://webapp.local
```

**Saída esperada:** Página HTML renderizada com informações da aplicação.

## Exemplo 2: Aplicação Multi-Página

### 1. ConfigMap com Múltiplas Páginas

```yaml
# multipage-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: multipage-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Home - Multi-Page App</title>
        <style>
            body { font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px; }
            nav { background: #333; padding: 15px; margin-bottom: 20px; }
            nav a { color: white; margin-right: 20px; text-decoration: none; }
            nav a:hover { text-decoration: underline; }
            h1 { color: #333; }
        </style>
    </head>
    <body>
        <nav>
            <a href="/">Home</a>
            <a href="/about.html">About</a>
            <a href="/contact.html">Contact</a>
        </nav>
        <h1>Home Page</h1>
        <p>Welcome to the multi-page application!</p>
    </body>
    </html>
  
  about.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>About - Multi-Page App</title>
        <style>
            body { font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px; }
            nav { background: #333; padding: 15px; margin-bottom: 20px; }
            nav a { color: white; margin-right: 20px; text-decoration: none; }
            h1 { color: #333; }
        </style>
    </head>
    <body>
        <nav>
            <a href="/">Home</a>
            <a href="/about.html">About</a>
            <a href="/contact.html">Contact</a>
        </nav>
        <h1>About Page</h1>
        <p>This is a Kubernetes demo application.</p>
    </body>
    </html>
  
  contact.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Contact - Multi-Page App</title>
        <style>
            body { font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px; }
            nav { background: #333; padding: 15px; margin-bottom: 20px; }
            nav a { color: white; margin-right: 20px; text-decoration: none; }
            h1 { color: #333; }
        </style>
    </head>
    <body>
        <nav>
            <a href="/">Home</a>
            <a href="/about.html">About</a>
            <a href="/contact.html">Contact</a>
        </nav>
        <h1>Contact Page</h1>
        <p>Email: contact@example.com</p>
    </body>
    </html>
```

```bash
kubectl apply -f multipage-config.yaml
```

### 2. Deployment

```yaml
# multipage-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multipage-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multipage
  template:
    metadata:
      labels:
        app: multipage
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: multipage-html
---
apiVersion: v1
kind: Service
metadata:
  name: multipage-service
spec:
  selector:
    app: multipage
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multipage-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: multipage.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: multipage-service
            port:
              number: 80
```

```bash
kubectl apply -f multipage-deployment.yaml
echo "127.0.0.1 multipage.local" | sudo tee -a /etc/hosts
```

### 3. Testar

```bash
curl http://multipage.local/
curl http://multipage.local/about.html
curl http://multipage.local/contact.html
```

## Exemplo 3: Aplicação com API Backend

### 1. Backend API

```yaml
# backend-api.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
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
      - name: api
        image: hashicorp/http-echo:1.0
        args:
        - "-text={\"status\":\"ok\",\"message\":\"API is working\",\"version\":\"1.0.0\"}"
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
kubectl apply -f backend-api.yaml
```

### 2. Frontend

```yaml
# frontend-app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Frontend + API</title>
        <style>
            body { font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px; }
            button { padding: 10px 20px; font-size: 16px; cursor: pointer; }
            #result { margin-top: 20px; padding: 15px; background: #f0f0f0; border-radius: 5px; }
        </style>
    </head>
    <body>
        <h1>Frontend Application</h1>
        <button onclick="callAPI()">Call API</button>
        <div id="result"></div>
        
        <script>
            async function callAPI() {
                try {
                    const response = await fetch('/api');
                    const data = await response.text();
                    document.getElementById('result').innerHTML = '<pre>' + data + '</pre>';
                } catch (error) {
                    document.getElementById('result').innerHTML = 'Error: ' + error;
                }
            }
        </script>
    </body>
    </html>
---
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
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: html
        configMap:
          name: frontend-html
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
    targetPort: 80
```

```bash
kubectl apply -f frontend-app.yaml
```

### 3. Ingress com Path Routing

```yaml
# fullstack-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fullstack-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: fullstack.local
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
kubectl apply -f fullstack-ingress.yaml
echo "127.0.0.1 fullstack.local" | sudo tee -a /etc/hosts
```

### 4. Testar

```bash
# Frontend
curl http://fullstack.local/

# API
curl http://fullstack.local/api

# Abrir no navegador e clicar no botão
# http://fullstack.local
```

## Exemplo 4: Aplicação Completa (All-in-One)

```yaml
# complete-app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: complete-app-html
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <title>Aplicação Completa - Kubernetes</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 20px;
            }
            .container {
                max-width: 1200px;
                margin: 0 auto;
                background: white;
                border-radius: 12px;
                padding: 40px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            }
            h1 { color: #333; text-align: center; margin-bottom: 30px; }
            .grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin-top: 30px;
            }
            .card {
                background: #f8f9fa;
                padding: 20px;
                border-radius: 8px;
                border-left: 4px solid #667eea;
            }
            .card h2 { color: #555; margin-bottom: 15px; }
            .card p { color: #666; line-height: 1.6; }
            .status {
                background: #28a745;
                color: white;
                padding: 15px;
                border-radius: 8px;
                text-align: center;
                font-size: 1.2em;
                margin-bottom: 30px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Aplicação Kubernetes Completa</h1>
            
            <div class="status">
                ✓ Sistema Operacional
            </div>
            
            <div class="grid">
                <div class="card">
                    <h2>📦 Deployment</h2>
                    <p><strong>Nome:</strong> complete-app</p>
                    <p><strong>Réplicas:</strong> 3</p>
                    <p><strong>Imagem:</strong> nginx:1.27-alpine</p>
                </div>
                
                <div class="card">
                    <h2>🔌 Service</h2>
                    <p><strong>Nome:</strong> complete-service</p>
                    <p><strong>Tipo:</strong> ClusterIP</p>
                    <p><strong>Porta:</strong> 80</p>
                </div>
                
                <div class="card">
                    <h2>🌐 Ingress</h2>
                    <p><strong>Nome:</strong> complete-ingress</p>
                    <p><strong>Host:</strong> complete.local</p>
                    <p><strong>Controller:</strong> Nginx</p>
                </div>
                
                <div class="card">
                    <h2>📊 Status</h2>
                    <p><strong>Health:</strong> ✓ Healthy</p>
                    <p><strong>Uptime:</strong> Running</p>
                    <p><strong>Version:</strong> 1.0.0</p>
                </div>
            </div>
        </div>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complete-app
  labels:
    app: complete
spec:
  replicas: 3
  selector:
    matchLabels:
      app: complete
  template:
    metadata:
      labels:
        app: complete
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      volumes:
      - name: html
        configMap:
          name: complete-app-html
---
apiVersion: v1
kind: Service
metadata:
  name: complete-service
  labels:
    app: complete
spec:
  selector:
    app: complete
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: complete-ingress
  labels:
    app: complete
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
            name: complete-service
            port:
              number: 80
```

```bash
kubectl apply -f complete-app.yaml
echo "127.0.0.1 complete.local" | sudo tee -a /etc/hosts
curl http://complete.local
```

## Comandos Úteis

### Verificar Recursos

```bash
# Ver todos os recursos
kubectl get all -l app=webapp

# Ver Pods com detalhes
kubectl get pods -l app=webapp -o wide

# Ver logs
kubectl logs -l app=webapp --tail=50

# Descrever Ingress
kubectl describe ingress webapp-ingress
```

### Testar Aplicação

```bash
# Testar Service internamente
kubectl run test --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://webapp-service

# Testar via Ingress
curl http://webapp.local

# Ver headers
curl -I http://webapp.local

# Verbose
curl -v http://webapp.local
```

### Debug

```bash
# Entrar no Pod
kubectl exec -it <pod-name> -- sh

# Ver arquivos HTML
kubectl exec <pod-name> -- ls -la /usr/share/nginx/html/

# Ver configuração do Nginx
kubectl exec <pod-name> -- cat /etc/nginx/nginx.conf
```

## Limpeza

```bash
# Remover aplicações
kubectl delete -f webapp-config.yaml
kubectl delete -f webapp-deployment.yaml
kubectl delete -f webapp-service.yaml
kubectl delete -f webapp-ingress.yaml

# Ou remover por label
kubectl delete all -l app=webapp

# Limpar /etc/hosts
sudo sed -i '/\.local/d' /etc/hosts
```

## Resumo

- **ConfigMap** armazena HTML e arquivos estáticos
- **Deployment** gerencia Pods da aplicação
- **Service ClusterIP** expõe aplicação internamente
- **Ingress** expõe aplicação externamente
- **Nginx** serve conteúdo estático
- **Path routing** permite múltiplos backends
- **/etc/hosts** para DNS local

## Próximos Passos

- Adicionar **SSL/TLS** com certificados
- Implementar **health checks** avançados
- Configurar **autoscaling** (HPA)
- Adicionar **monitoramento** com Prometheus
- Implementar **CI/CD** para deploy automático
