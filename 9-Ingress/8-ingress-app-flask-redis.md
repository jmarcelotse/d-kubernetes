# Configurando um Ingress para a Nossa App em Flask e usando Redis

## Introdução

Neste guia, vamos criar uma aplicação completa em Flask que usa Redis como backend de cache/sessão e expor essa aplicação através do Ingress. Este é um cenário real de produção onde temos uma aplicação web stateless conectada a um serviço de dados.

## Arquitetura da Solução

```
Internet
    ↓
Ingress (app.example.com)
    ↓
Flask Service (ClusterIP)
    ↓
Flask Pods (3 réplicas)
    ↓
Redis Service (ClusterIP)
    ↓
Redis Pod (1 réplica)
```

## Fluxo de Requisição

```
1. Usuário acessa: http://app.example.com
2. Ingress recebe a requisição
3. Ingress roteia para Flask Service
4. Service distribui para um dos Pods Flask
5. Flask conecta ao Redis Service
6. Redis Service direciona para Redis Pod
7. Resposta retorna pelo mesmo caminho
```

---

## Passo 1: Criar a Aplicação Flask

### 1.1 Código da Aplicação

Crie o arquivo `app.py`:

```python
from flask import Flask
import redis
import os
import socket

app = Flask(__name__)

# Conectar ao Redis
redis_host = os.getenv('REDIS_HOST', 'redis-service')
redis_port = int(os.getenv('REDIS_PORT', 6379))
cache = redis.Redis(host=redis_host, port=redis_port)

def get_hit_count():
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1

@app.route('/')
def hello():
    count = get_hit_count()
    hostname = socket.gethostname()
    return f'''
    <h1>Flask + Redis App</h1>
    <p>Esta página foi visitada <strong>{count}</strong> vezes.</p>
    <p>Servido pelo pod: <strong>{hostname}</strong></p>
    <p>Redis host: <strong>{redis_host}</strong></p>
    '''

@app.route('/health')
def health():
    try:
        cache.ping()
        return {'status': 'healthy', 'redis': 'connected'}, 200
    except:
        return {'status': 'unhealthy', 'redis': 'disconnected'}, 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### 1.2 Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
```

### 1.3 Requirements

```txt
flask==3.0.0
redis==5.0.1
```

### 1.4 Build e Push da Imagem

```bash
# Build da imagem
docker build -t seu-usuario/flask-redis-app:v1 .

# Push para Docker Hub
docker login
docker push seu-usuario/flask-redis-app:v1
```

---

## Passo 2: Deploy do Redis

### 2.1 Redis Deployment

Crie o arquivo `redis-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: redis
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          tcpSocket:
            port: 6379
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 2.2 Redis Service

Crie o arquivo `redis-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  labels:
    app: redis
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  selector:
    app: redis
```

### 2.3 Aplicar Redis

```bash
# Aplicar Deployment
kubectl apply -f redis-deployment.yaml

# Aplicar Service
kubectl apply -f redis-service.yaml

# Verificar
kubectl get pods -l app=redis
kubectl get svc redis-service

# Testar Redis
kubectl run redis-test --rm -it --image=redis:7-alpine -- redis-cli -h redis-service ping
# Deve retornar: PONG
```

---

## Passo 3: Deploy da Aplicação Flask

### 3.1 Flask Deployment

Crie o arquivo `flask-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
  labels:
    app: flask-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask
        image: seu-usuario/flask-redis-app:v1
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: REDIS_HOST
          value: "redis-service"
        - name: REDIS_PORT
          value: "6379"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 3.2 Flask Service

Crie o arquivo `flask-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: flask-service
  labels:
    app: flask-app
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 5000
    protocol: TCP
    name: http
  selector:
    app: flask-app
```

### 3.3 Aplicar Flask

```bash
# Aplicar Deployment
kubectl apply -f flask-deployment.yaml

# Aplicar Service
kubectl apply -f flask-service.yaml

# Verificar
kubectl get pods -l app=flask-app
kubectl get svc flask-service

# Ver logs
kubectl logs -l app=flask-app --tail=20

# Testar internamente
kubectl run curl-test --rm -it --image=curlimages/curl -- curl http://flask-service
```

---

## Passo 4: Configurar o Ingress

### 4.1 Ingress Simples (HTTP)

Crie o arquivo `flask-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flask-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
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
            name: flask-service
            port:
              number: 80
```

### 4.2 Aplicar Ingress

```bash
# Aplicar
kubectl apply -f flask-ingress.yaml

# Verificar
kubectl get ingress flask-ingress
kubectl describe ingress flask-ingress

# Ver endereço do Ingress
kubectl get ingress flask-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 4.3 Configurar /etc/hosts (Ambiente Local)

```bash
# Obter IP do Ingress Controller
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Adicionar ao /etc/hosts
sudo bash -c 'echo "127.0.0.1 app.example.com" >> /etc/hosts'

# Ou se estiver usando Kind
sudo bash -c 'echo "127.0.0.1 app.example.com" >> /etc/hosts'
```

### 4.4 Testar a Aplicação

```bash
# Testar via curl
curl http://app.example.com

# Testar múltiplas vezes para ver load balancing
for i in {1..10}; do
  curl http://app.example.com | grep "pod:"
  sleep 1
done

# Testar health check
curl http://app.example.com/health
```

---

## Passo 5: Ingress com Path-Based Routing

### 5.1 Ingress com Múltiplos Paths

Crie o arquivo `flask-ingress-paths.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flask-ingress-paths
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /app(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: flask-service
            port:
              number: 80
      - path: /health
        pathType: Exact
        backend:
          service:
            name: flask-service
            port:
              number: 80
```

### 5.2 Testar Path-Based Routing

```bash
# Acessar via /app
curl http://app.example.com/app

# Acessar health check
curl http://app.example.com/health
```

---

## Passo 6: Ingress com TLS/SSL

### 6.1 Criar Certificado Self-Signed

```bash
# Gerar certificado
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=app.example.com/O=MyOrg"

# Criar Secret TLS
kubectl create secret tls flask-tls-secret \
  --cert=tls.crt \
  --key=tls.key

# Verificar
kubectl get secret flask-tls-secret
kubectl describe secret flask-tls-secret
```

### 6.2 Ingress com TLS

Crie o arquivo `flask-ingress-tls.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flask-ingress-tls
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: flask-tls-secret
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: flask-service
            port:
              number: 80
```

### 6.3 Testar HTTPS

```bash
# Aplicar
kubectl apply -f flask-ingress-tls.yaml

# Testar HTTPS (ignorar certificado self-signed)
curl -k https://app.example.com

# Testar redirecionamento HTTP → HTTPS
curl -I http://app.example.com
# Deve retornar 308 Permanent Redirect
```

---

## Passo 7: Ingress com Annotations Avançadas

### 7.1 Ingress com Rate Limiting e CORS

Crie o arquivo `flask-ingress-advanced.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flask-ingress-advanced
  annotations:
    # Rate Limiting
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
    
    # CORS
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    
    # Timeouts
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
    
    # Buffer
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    
    # Custom Headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-App-Name "Flask-Redis-App" always;
      add_header X-Powered-By "Kubernetes" always;
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: flask-tls-secret
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: flask-service
            port:
              number: 80
```

### 7.2 Testar Annotations

```bash
# Aplicar
kubectl apply -f flask-ingress-advanced.yaml

# Testar rate limiting
for i in {1..20}; do
  curl -s -o /dev/null -w "%{http_code}\n" https://app.example.com -k
done
# Após 10 requisições, deve retornar 503

# Testar CORS headers
curl -I https://app.example.com -k | grep -i cors

# Testar custom headers
curl -I https://app.example.com -k | grep -i "X-App-Name"
```

---

## Passo 8: Múltiplos Hosts no Mesmo Ingress

### 8.1 Ingress Multi-Host

Crie o arquivo `flask-ingress-multihost.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flask-ingress-multihost
spec:
  ingressClassName: nginx
  rules:
  # Host 1: Produção
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: flask-service
            port:
              number: 80
  
  # Host 2: Staging
  - host: staging.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: flask-service-staging
            port:
              number: 80
  
  # Host 3: API
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: flask-service
            port:
              number: 80
```

### 8.2 Configurar Hosts

```bash
# Adicionar ao /etc/hosts
sudo bash -c 'cat >> /etc/hosts << EOF
127.0.0.1 app.example.com
127.0.0.1 staging.example.com
127.0.0.1 api.example.com
EOF'

# Testar cada host
curl http://app.example.com
curl http://staging.example.com
curl http://api.example.com
```

---

## Passo 9: Monitoramento e Troubleshooting

### 9.1 Verificar Status Completo

```bash
# Ver todos os recursos
kubectl get all -l app=flask-app
kubectl get all -l app=redis

# Ver Ingress
kubectl get ingress
kubectl describe ingress flask-ingress

# Ver endpoints
kubectl get endpoints flask-service
kubectl get endpoints redis-service
```

### 9.2 Logs

```bash
# Logs do Flask
kubectl logs -l app=flask-app --tail=50 -f

# Logs do Redis
kubectl logs -l app=redis --tail=50 -f

# Logs do Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100 -f
```

### 9.3 Debug de Conectividade

```bash
# Testar Flask → Redis
kubectl exec -it deployment/flask-app -- sh
# Dentro do pod:
ping redis-service
nc -zv redis-service 6379
exit

# Testar acesso ao Flask internamente
kubectl run debug --rm -it --image=curlimages/curl -- sh
# Dentro do pod:
curl http://flask-service
curl http://flask-service/health
exit
```

### 9.4 Verificar Ingress Controller

```bash
# Status do Ingress Controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Configuração do Nginx
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep -A 20 "server_name app.example.com"

# Métricas
kubectl top pods -l app=flask-app
kubectl top pods -l app=redis
```

---

## Passo 10: Stack Completa em um Único Arquivo

### 10.1 Arquivo all-in-one.yaml

Crie o arquivo `flask-redis-stack.yaml`:

```yaml
---
# Redis Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"

---
# Redis Service
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
  selector:
    app: redis

---
# Flask Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask
        image: seu-usuario/flask-redis-app:v1
        ports:
        - containerPort: 5000
        env:
        - name: REDIS_HOST
          value: "redis-service"
        - name: REDIS_PORT
          value: "6379"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5

---
# Flask Service
apiVersion: v1
kind: Service
metadata:
  name: flask-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 5000
  selector:
    app: flask-app

---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flask-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
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
            name: flask-service
            port:
              number: 80
```

### 10.2 Deploy Completo

```bash
# Aplicar tudo de uma vez
kubectl apply -f flask-redis-stack.yaml

# Verificar
kubectl get all
kubectl get ingress

# Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod -l app=flask-app --timeout=60s
kubectl wait --for=condition=ready pod -l app=redis --timeout=60s

# Testar
curl http://app.example.com
```

---

## Troubleshooting Comum

### Problema 1: Pods Flask não conectam ao Redis

```bash
# Verificar DNS
kubectl exec -it deployment/flask-app -- nslookup redis-service

# Verificar conectividade
kubectl exec -it deployment/flask-app -- nc -zv redis-service 6379

# Verificar variáveis de ambiente
kubectl exec -it deployment/flask-app -- env | grep REDIS
```

**Solução**: Verificar se o nome do Service está correto e se o Redis está rodando.

### Problema 2: Ingress retorna 503

```bash
# Verificar endpoints
kubectl get endpoints flask-service

# Verificar se pods estão ready
kubectl get pods -l app=flask-app

# Ver logs do Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

**Solução**: Verificar se os pods passaram nos readiness probes.

### Problema 3: Ingress não resolve o host

```bash
# Verificar /etc/hosts
cat /etc/hosts | grep example.com

# Verificar Ingress
kubectl describe ingress flask-ingress

# Testar com IP direto
INGRESS_IP=$(kubectl get ingress flask-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: app.example.com" http://$INGRESS_IP
```

**Solução**: Adicionar entrada no /etc/hosts ou configurar DNS.

### Problema 4: Rate Limiting muito agressivo

```bash
# Ajustar annotations
kubectl annotate ingress flask-ingress-advanced \
  nginx.ingress.kubernetes.io/limit-rps=100 --overwrite

# Remover rate limiting
kubectl annotate ingress flask-ingress-advanced \
  nginx.ingress.kubernetes.io/limit-rps- \
  nginx.ingress.kubernetes.io/limit-connections-
```

---

## Limpeza

```bash
# Deletar Ingress
kubectl delete ingress flask-ingress

# Deletar Services
kubectl delete svc flask-service redis-service

# Deletar Deployments
kubectl delete deployment flask-app redis

# Deletar Secrets
kubectl delete secret flask-tls-secret

# Ou deletar tudo de uma vez
kubectl delete -f flask-redis-stack.yaml

# Verificar
kubectl get all
```

---

## Resumo dos Comandos Principais

```bash
# Deploy completo
kubectl apply -f flask-redis-stack.yaml

# Verificar status
kubectl get pods,svc,ingress

# Testar aplicação
curl http://app.example.com

# Ver logs
kubectl logs -l app=flask-app -f

# Escalar Flask
kubectl scale deployment flask-app --replicas=5

# Atualizar imagem
kubectl set image deployment/flask-app flask=seu-usuario/flask-redis-app:v2

# Deletar tudo
kubectl delete -f flask-redis-stack.yaml
```

---

## Próximos Passos

1. **Adicionar Persistent Volume ao Redis** para não perder dados
2. **Configurar HPA** (Horizontal Pod Autoscaler) para Flask
3. **Implementar Cert-Manager** para certificados Let's Encrypt
4. **Adicionar Prometheus** para métricas
5. **Configurar Network Policies** para segurança
6. **Implementar CI/CD** com GitOps (ArgoCD/Flux)

---

## Conclusão

Você agora tem uma aplicação Flask completa conectada ao Redis e exposta via Ingress com:

✅ Load balancing entre múltiplos pods Flask  
✅ Comunicação interna via Services  
✅ Health checks configurados  
✅ Ingress com suporte a HTTP e HTTPS  
✅ Rate limiting e CORS  
✅ Múltiplos hosts e paths  
✅ Monitoramento e troubleshooting  

Esta é uma arquitetura pronta para produção que pode ser adaptada para qualquer aplicação web moderna!
