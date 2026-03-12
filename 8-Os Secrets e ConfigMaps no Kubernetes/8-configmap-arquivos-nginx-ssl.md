# Criando ConfigMap para Arquivos no Pod e Configurar SSL no Nginx

## Introdução

ConfigMaps são ideais para armazenar arquivos de configuração que serão montados em Pods. Neste guia, vamos criar ConfigMaps para adicionar arquivos de configuração no Nginx, incluindo configuração SSL/TLS.

## Fluxo de Funcionamento

```
1. ConfigMap criado com arquivo de configuração
   ↓
2. Pod referencia ConfigMap como volume
   ↓
3. Kubelet monta ConfigMap no filesystem do Pod
   ↓
4. Nginx lê arquivo de configuração
   ↓
5. Nginx inicia com configuração customizada
   ↓
6. Aplicação responde com SSL habilitado
```

## Exemplo 1: ConfigMap com Arquivo Nginx Básico

### 1. Criar ConfigMap com nginx.conf

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  labels:
    app: nginx
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';
        
        access_log /var/log/nginx/access.log main;
        error_log /var/log/nginx/error.log warn;
        
        sendfile on;
        keepalive_timeout 65;
        
        server {
            listen 80;
            server_name localhost;
            
            location / {
                root /usr/share/nginx/html;
                index index.html index.htm;
            }
            
            location /health {
                access_log off;
                return 200 "healthy\n";
                add_header Content-Type text/plain;
            }
        }
    }
```

```bash
kubectl apply -f nginx-config.yaml
```

**Saída esperada:**
```
configmap/nginx-config created
```

### 2. Deployment com ConfigMap

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-custom
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

```bash
kubectl apply -f nginx-deployment.yaml
```

**Saída esperada:**
```
deployment.apps/nginx-custom created
service/nginx-service created
```

### 3. Verificar

```bash
# Verificar Pods
kubectl get pods -l app=nginx

# Verificar configuração dentro do Pod
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- cat /etc/nginx/nginx.conf

# Testar endpoint
kubectl port-forward service/nginx-service 8080:80
curl http://localhost:8080/health
```

**Saída esperada:**
```
healthy
```

## Exemplo 2: ConfigMap com SSL/TLS no Nginx

### 1. Gerar Certificados SSL

```bash
# Gerar chave privada
openssl genrsa -out tls.key 2048

# Gerar certificado autoassinado
openssl req -new -x509 -key tls.key -out tls.crt -days 365 \
  -subj "/CN=myapp.example.com/O=MyOrg/C=US"
```

**Saída esperada:**
```
Generating RSA private key, 2048 bit long modulus
.....+++
.....+++
e is 65537 (0x10001)
```

### 2. Criar Secret TLS

```bash
kubectl create secret tls nginx-tls \
  --cert=tls.crt \
  --key=tls.key
```

**Saída esperada:**
```
secret/nginx-tls created
```

### 3. Criar ConfigMap com Configuração SSL

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ssl-config
  labels:
    app: nginx-ssl
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        
        # Logging
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
        
        # HTTP Server - Redirect to HTTPS
        server {
            listen 80;
            server_name myapp.example.com;
            
            location / {
                return 301 https://$host$request_uri;
            }
        }
        
        # HTTPS Server
        server {
            listen 443 ssl;
            server_name myapp.example.com;
            
            # SSL Configuration
            ssl_certificate /etc/nginx/ssl/tls.crt;
            ssl_certificate_key /etc/nginx/ssl/tls.key;
            
            # SSL Protocols and Ciphers
            ssl_protocols TLSv1.2 TLSv1.3;
            ssl_ciphers HIGH:!aNULL:!MD5;
            ssl_prefer_server_ciphers on;
            
            # SSL Session
            ssl_session_cache shared:SSL:10m;
            ssl_session_timeout 10m;
            
            # Security Headers
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-Content-Type-Options "nosniff" always;
            add_header X-XSS-Protection "1; mode=block" always;
            
            # Root and Index
            root /usr/share/nginx/html;
            index index.html;
            
            location / {
                try_files $uri $uri/ =404;
            }
            
            location /health {
                access_log off;
                return 200 "healthy\n";
                add_header Content-Type text/plain;
            }
        }
    }
  
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Nginx SSL</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: #f5f5f5;
            }
            .container {
                background: white;
                padding: 30px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            h1 { color: #333; }
            .status { color: #28a745; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔒 Nginx with SSL/TLS</h1>
            <p class="status">✓ SSL is enabled</p>
            <p>This page is served over HTTPS using a self-signed certificate.</p>
            <ul>
                <li>Protocol: TLSv1.2 / TLSv1.3</li>
                <li>Server: Nginx</li>
                <li>Environment: Kubernetes</li>
            </ul>
        </div>
    </body>
    </html>
```

```bash
kubectl apply -f nginx-ssl-config.yaml
```

**Saída esperada:**
```
configmap/nginx-ssl-config created
```

### 4. Deployment com SSL

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ssl
  labels:
    app: nginx-ssl
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-ssl
  template:
    metadata:
      labels:
        app: nginx-ssl
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
        volumeMounts:
        # Nginx configuration
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        # HTML content
        - name: html-content
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        # SSL certificates
        - name: tls-certs
          mountPath: /etc/nginx/ssl
          readOnly: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-ssl-config
      - name: html-content
        configMap:
          name: nginx-ssl-config
      - name: tls-certs
        secret:
          secretName: nginx-tls
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-ssl-service
spec:
  selector:
    app: nginx-ssl
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
  type: LoadBalancer
```

```bash
kubectl apply -f nginx-ssl-deployment.yaml
```

**Saída esperada:**
```
deployment.apps/nginx-ssl created
service/nginx-ssl-service created
```

### 5. Testar SSL

```bash
# Port-forward HTTPS
kubectl port-forward service/nginx-ssl-service 8443:443

# Testar HTTPS (ignorar verificação de certificado autoassinado)
curl -k https://localhost:8443

# Ver certificado
openssl s_client -connect localhost:8443 -servername myapp.example.com < /dev/null 2>/dev/null | openssl x509 -text -noout | head -20

# Testar redirect HTTP -> HTTPS
kubectl port-forward service/nginx-ssl-service 8080:80
curl -I http://localhost:8080
```

**Saída esperada (HTML):**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Nginx SSL</title>
...
```

**Saída esperada (redirect):**
```
HTTP/1.1 301 Moved Permanently
Server: nginx/1.27.0
Location: https://localhost/
```

### 6. Verificar Configuração no Pod

```bash
POD_NAME=$(kubectl get pods -l app=nginx-ssl -o jsonpath='{.items[0].metadata.name}')

# Ver nginx.conf
kubectl exec $POD_NAME -- cat /etc/nginx/nginx.conf

# Ver certificados
kubectl exec $POD_NAME -- ls -la /etc/nginx/ssl/

# Testar configuração do Nginx
kubectl exec $POD_NAME -- nginx -t
```

**Saída esperada:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## Exemplo 3: ConfigMap com Múltiplos Arquivos

### 1. ConfigMap Completo

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-multi-files
  labels:
    app: nginx-multi
data:
  # Main nginx.conf
  nginx.conf: |
    events {
        worker_connections 2048;
    }
    
    http {
        include /etc/nginx/mime.types;
        include /etc/nginx/conf.d/*.conf;
        
        default_type application/octet-stream;
        
        log_format json escape=json '{'
            '"time":"$time_iso8601",'
            '"remote_addr":"$remote_addr",'
            '"request":"$request",'
            '"status":$status,'
            '"body_bytes_sent":$body_bytes_sent,'
            '"request_time":$request_time,'
            '"upstream_response_time":"$upstream_response_time"'
        '}';
        
        access_log /var/log/nginx/access.log json;
        error_log /var/log/nginx/error.log warn;
        
        sendfile on;
        tcp_nopush on;
        keepalive_timeout 65;
        gzip on;
    }
  
  # Default server
  default.conf: |
    server {
        listen 80 default_server;
        server_name _;
        
        root /usr/share/nginx/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        location /api {
            proxy_pass http://backend-service:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location /health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }
        
        location /metrics {
            stub_status on;
            access_log off;
        }
    }
  
  # Custom mime types
  custom-mime.types: |
    types {
        application/json json;
        application/xml xml;
        text/css css;
        text/javascript js;
        image/png png;
        image/jpeg jpg jpeg;
        image/gif gif;
        image/svg+xml svg;
    }
  
  # Index page
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Multi-File Config</title>
        <link rel="stylesheet" href="/style.css">
    </head>
    <body>
        <div class="container">
            <h1>Nginx Multi-File Configuration</h1>
            <p>This deployment uses multiple ConfigMap files:</p>
            <ul>
                <li>nginx.conf - Main configuration</li>
                <li>default.conf - Server configuration</li>
                <li>custom-mime.types - MIME types</li>
                <li>index.html - This page</li>
                <li>style.css - Stylesheet</li>
            </ul>
            <div class="endpoints">
                <h2>Available Endpoints:</h2>
                <ul>
                    <li><a href="/">/</a> - Home page</li>
                    <li><a href="/health">/health</a> - Health check</li>
                    <li><a href="/metrics">/metrics</a> - Nginx metrics</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
  
  # Stylesheet
  style.css: |
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
        box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        max-width: 800px;
        width: 100%;
    }
    
    h1 {
        color: #333;
        margin-bottom: 20px;
        font-size: 2em;
    }
    
    h2 {
        color: #555;
        margin-top: 30px;
        margin-bottom: 15px;
        font-size: 1.5em;
    }
    
    p {
        color: #666;
        line-height: 1.6;
        margin-bottom: 15px;
    }
    
    ul {
        list-style: none;
        padding-left: 20px;
    }
    
    ul li {
        padding: 8px 0;
        color: #555;
    }
    
    ul li:before {
        content: "✓ ";
        color: #667eea;
        font-weight: bold;
        margin-right: 8px;
    }
    
    .endpoints ul li:before {
        content: "→ ";
    }
    
    a {
        color: #667eea;
        text-decoration: none;
        font-weight: 500;
    }
    
    a:hover {
        text-decoration: underline;
    }
```

```bash
kubectl apply -f nginx-multi-files.yaml
```

### 2. Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-multi
  labels:
    app: nginx-multi
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-multi
  template:
    metadata:
      labels:
        app: nginx-multi
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        # Main config
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        # Server config
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
        # Custom MIME types
        - name: config
          mountPath: /etc/nginx/custom-mime.types
          subPath: custom-mime.types
        # HTML content
        - name: config
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        # CSS
        - name: config
          mountPath: /usr/share/nginx/html/style.css
          subPath: style.css
      volumes:
      - name: config
        configMap:
          name: nginx-multi-files
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-multi-service
spec:
  selector:
    app: nginx-multi
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

```bash
kubectl apply -f nginx-multi-deployment.yaml
```

### 3. Testar

```bash
kubectl port-forward service/nginx-multi-service 8080:80

# Testar página principal
curl http://localhost:8080

# Testar health
curl http://localhost:8080/health

# Testar metrics
curl http://localhost:8080/metrics
```

## Exemplo 4: Atualização de ConfigMap

### Atualizar Configuração

```bash
# Método 1: Editar interativamente
kubectl edit configmap nginx-ssl-config

# Método 2: Aplicar novo YAML
cat > updated-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ssl-config
data:
  nginx.conf: |
    events {
        worker_connections 2048;  # Aumentado
    }
    
    http {
        # ... resto da configuração
    }
EOF

kubectl apply -f updated-config.yaml
```

### Recarregar Nginx

```bash
# Opção 1: Reiniciar Deployment
kubectl rollout restart deployment nginx-ssl

# Opção 2: Recarregar Nginx dentro do Pod (se volume)
POD_NAME=$(kubectl get pods -l app=nginx-ssl -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- nginx -s reload
```

**Nota:** ConfigMaps montados como volumes atualizam automaticamente (pode levar até 1 minuto), mas Nginx precisa recarregar a configuração.

## Exemplo 5: ConfigMap com Proxy Reverso

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-proxy-config
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    
    http {
        upstream backend {
            server backend-service:8080 max_fails=3 fail_timeout=30s;
            keepalive 32;
        }
        
        server {
            listen 80;
            server_name api.example.com;
            
            # Proxy settings
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # Buffering
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
            
            location / {
                proxy_pass http://backend;
            }
            
            location /health {
                access_log off;
                return 200 "OK\n";
            }
        }
    }
```

## Comandos Úteis

### Criar ConfigMap a partir de Arquivo

```bash
# Arquivo único
kubectl create configmap nginx-config --from-file=nginx.conf

# Múltiplos arquivos
kubectl create configmap nginx-files \
  --from-file=nginx.conf \
  --from-file=default.conf \
  --from-file=index.html

# Diretório completo
kubectl create configmap nginx-dir --from-file=./nginx-configs/
```

### Verificar ConfigMap no Pod

```bash
# Listar arquivos montados
kubectl exec <pod-name> -- ls -la /etc/nginx/

# Ver conteúdo
kubectl exec <pod-name> -- cat /etc/nginx/nginx.conf

# Testar configuração
kubectl exec <pod-name> -- nginx -t

# Recarregar Nginx
kubectl exec <pod-name> -- nginx -s reload
```

### Debug

```bash
# Ver logs do Nginx
kubectl logs <pod-name>

# Ver logs em tempo real
kubectl logs -f <pod-name>

# Entrar no Pod
kubectl exec -it <pod-name> -- sh

# Ver processos
kubectl exec <pod-name> -- ps aux | grep nginx
```

## Boas Práticas

### 1. Validar Configuração Antes de Aplicar

```bash
# Criar Pod temporário para testar
kubectl run nginx-test --image=nginx:1.27-alpine --rm -it --restart=Never -- sh

# Dentro do Pod, criar arquivo e testar
cat > /tmp/nginx.conf << 'EOF'
# sua configuração
EOF

nginx -t -c /tmp/nginx.conf
```

### 2. Usar subPath para Arquivos Específicos

```yaml
# ✅ Recomendado - não sobrescreve diretório inteiro
volumeMounts:
- name: config
  mountPath: /etc/nginx/nginx.conf
  subPath: nginx.conf

# ❌ Evite - sobrescreve todo o diretório
volumeMounts:
- name: config
  mountPath: /etc/nginx/
```

### 3. Separar Configuração por Ambiente

```yaml
# dev-nginx-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: dev
data:
  nginx.conf: |
    # configuração dev
---
# prod-nginx-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: prod
data:
  nginx.conf: |
    # configuração prod
```

### 4. Versionamento de ConfigMaps

```yaml
metadata:
  name: nginx-config-v2
  labels:
    version: "2.0"
```

### 5. Documentar Configuração

```yaml
metadata:
  annotations:
    description: "Nginx configuration with SSL"
    version: "1.0.0"
    last-updated: "2026-03-10"
    owner: "platform-team"
```

## Troubleshooting

### Nginx não Inicia

```bash
# Ver logs
kubectl logs <pod-name>

# Testar configuração
kubectl exec <pod-name> -- nginx -t

# Ver eventos do Pod
kubectl describe pod <pod-name>
```

### Arquivo não Aparece no Pod

```bash
# Verificar se ConfigMap existe
kubectl get configmap nginx-config

# Verificar montagem
kubectl describe pod <pod-name> | grep -A 10 Mounts

# Verificar volume
kubectl get pod <pod-name> -o yaml | grep -A 10 volumes
```

### SSL não Funciona

```bash
# Verificar certificados
kubectl exec <pod-name> -- ls -la /etc/nginx/ssl/

# Testar SSL
kubectl exec <pod-name> -- openssl s_client -connect localhost:443 < /dev/null

# Ver logs de erro
kubectl logs <pod-name> | grep ssl
```

## Limpeza

```bash
# Remover ConfigMaps
kubectl delete configmap nginx-config nginx-ssl-config nginx-multi-files nginx-proxy-config

# Remover Secrets
kubectl delete secret nginx-tls

# Remover Deployments
kubectl delete deployment nginx-custom nginx-ssl nginx-multi

# Remover Services
kubectl delete service nginx-service nginx-ssl-service nginx-multi-service

# Remover arquivos locais
rm tls.key tls.crt
```

## Resumo

- **ConfigMaps armazenam arquivos de configuração** para Pods
- **subPath** monta arquivo específico sem sobrescrever diretório
- **Combine ConfigMap + Secret** para configuração completa (config + certificados)
- **Volumes atualizam automaticamente**, mas Nginx precisa reload
- **Valide configuração** antes de aplicar em produção
- Use **múltiplos ConfigMaps** para organização
- **Documente** configurações com annotations

## Próximos Passos

- Implementar **reloader automático** (Reloader, Stakater)
- Usar **Kustomize** para gerenciar configs por ambiente
- Integrar com **Cert-Manager** para SSL automático
- Configurar **Ingress** em vez de LoadBalancer
- Implementar **monitoramento** de Nginx (Prometheus)
