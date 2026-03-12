# Criando o Service Expondo Outro Service

## Introdução

No Kubernetes, é possível criar Services que expõem outros Services, permitindo criar camadas de abstração, roteamento avançado e integração entre diferentes namespaces ou clusters. Esta técnica é útil para arquiteturas complexas, multi-tenant e microsserviços.

## Conceitos Fundamentais

### Por Que Expor um Service Através de Outro?

1. **Abstração de Camadas:** Separar lógica de roteamento da aplicação
2. **Cross-Namespace:** Acessar Services de outros namespaces
3. **Proxy/Gateway:** Criar pontos centralizados de entrada
4. **Migração:** Facilitar transição entre versões ou ambientes
5. **Segurança:** Adicionar camada de controle de acesso

### Métodos para Expor Services

| Método | Descrição | Uso |
|--------|-----------|-----|
| **ExternalName** | CNAME para outro Service | Cross-namespace, DNS |
| **Endpoints Manuais** | Endpoints customizados | Controle total |
| **Service sem Selector** | Service + Endpoints | Flexibilidade |
| **Proxy Pod** | Pod intermediário | Lógica customizada |

## Método 1: ExternalName para Service em Outro Namespace

### Cenário

Temos um Service `backend-api` no namespace `production` e queremos acessá-lo do namespace `development` usando um nome local.

### Fluxo

```
Pod (namespace: development)
         ↓
Service ExternalName (namespace: development)
         ↓
Service ClusterIP (namespace: production)
         ↓
Pods Backend (namespace: production)
```

### Implementação

#### 1. Criar Namespace e Backend

```bash
# Criar namespaces
kubectl create namespace production
kubectl create namespace development
```

**Saída esperada:**
```
namespace/production created
namespace/development created
```

#### 2. Deployment e Service no Namespace Production

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:1.0
        args:
        - "-text=Backend API v1.0 - Production"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: backend-api
  namespace: production
spec:
  selector:
    app: backend-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5678
```

```bash
kubectl apply -f backend-production.yaml
```

**Saída esperada:**
```
deployment.apps/backend-api created
service/backend-api created
```

#### 3. Verificar Service no Production

```bash
kubectl get service -n production
```

**Saída esperada:**
```
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
backend-api   ClusterIP   10.96.123.45    <none>        80/TCP    30s
```

#### 4. Service ExternalName no Namespace Development

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-proxy
  namespace: development
spec:
  type: ExternalName
  externalName: backend-api.production.svc.cluster.local
  ports:
  - protocol: TCP
    port: 80
```

```bash
kubectl apply -f backend-proxy-dev.yaml
```

**Saída esperada:**
```
service/backend-proxy created
```

#### 5. Testar Acesso do Namespace Development

```bash
kubectl run test-client -n development --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- sh
```

Dentro do Pod:

```bash
curl http://backend-proxy
```

**Saída esperada:**
```
Backend API v1.0 - Production
```

#### 6. Verificar Resolução DNS

```bash
kubectl run test-dns -n development --image=busybox:1.36 --rm -it --restart=Never -- nslookup backend-proxy
```

**Saída esperada:**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      backend-proxy
Address 1: backend-api.production.svc.cluster.local
```

## Método 2: Service sem Selector com Endpoints Manuais

### Cenário

Criar um Service que aponta para outro Service usando Endpoints customizados, permitindo controle total sobre o roteamento.

### Fluxo

```
Cliente
   ↓
Service Frontend (sem selector)
   ↓
Endpoints (IP do Service Backend)
   ↓
Service Backend
   ↓
Pods Backend
```

### Implementação

#### 1. Criar Backend Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args:
        - "-text=Backend Service"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 5678
```

```bash
kubectl apply -f backend-service.yaml
```

#### 2. Obter ClusterIP do Backend Service

```bash
kubectl get service backend-service -o jsonpath='{.spec.clusterIP}'
```

**Saída esperada:**
```
10.96.200.50
```

#### 3. Criar Service Frontend sem Selector

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-proxy
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Endpoints
metadata:
  name: frontend-proxy
subsets:
- addresses:
  - ip: 10.96.200.50  # ClusterIP do backend-service
  ports:
  - port: 8080
```

**Importante:** O nome do Endpoints deve ser idêntico ao nome do Service.

```bash
kubectl apply -f frontend-proxy.yaml
```

**Saída esperada:**
```
service/frontend-proxy created
endpoints/frontend-proxy created
```

#### 4. Verificar Endpoints

```bash
kubectl get endpoints frontend-proxy
```

**Saída esperada:**
```
NAME             ENDPOINTS          AGE
frontend-proxy   10.96.200.50:8080  20s
```

#### 5. Testar Acesso

```bash
kubectl run test-proxy --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://frontend-proxy
```

**Saída esperada:**
```
Backend Service
```

#### 6. Detalhes do Service

```bash
kubectl describe service frontend-proxy
```

**Saída esperada:**
```
Name:              frontend-proxy
Namespace:         default
Labels:            <none>
Annotations:       <none>
Selector:          <none>
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.96.150.100
IPs:               10.96.150.100
Port:              <unset>  80/TCP
TargetPort:        8080/TCP
Endpoints:         10.96.200.50:8080
Session Affinity:  None
Events:            <none>
```

## Método 3: Proxy Pod com Nginx

### Cenário

Usar um Pod Nginx como proxy reverso para rotear tráfego para múltiplos Services backend.

### Fluxo

```
Cliente
   ↓
Service Nginx Proxy
   ↓
Pod Nginx (proxy reverso)
   ↓
Service Backend 1 | Service Backend 2
   ↓                    ↓
Pods Backend 1    Pods Backend 2
```

### Implementação

#### 1. Criar Backends

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
      version: v1
  template:
    metadata:
      labels:
        app: api
        version: v1
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:1.0
        args:
        - "-text=API Version 1"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: api-v1-service
spec:
  selector:
    app: api
    version: v1
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-v2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
      version: v2
  template:
    metadata:
      labels:
        app: api
        version: v2
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:1.0
        args:
        - "-text=API Version 2"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: api-v2-service
spec:
  selector:
    app: api
    version: v2
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f api-backends.yaml
```

#### 2. ConfigMap com Configuração Nginx

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
        upstream api_v1 {
            server api-v1-service:80;
        }
        
        upstream api_v2 {
            server api-v2-service:80;
        }
        
        server {
            listen 80;
            
            location /v1 {
                proxy_pass http://api_v1/;
            }
            
            location /v2 {
                proxy_pass http://api_v2/;
            }
            
            location / {
                return 200 "Nginx Proxy - Use /v1 or /v2\n";
                add_header Content-Type text/plain;
            }
        }
    }
```

```bash
kubectl apply -f nginx-config.yaml
```

#### 3. Deployment e Service do Nginx Proxy

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-proxy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-proxy
  template:
    metadata:
      labels:
        app: nginx-proxy
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: nginx-proxy-config
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-proxy-service
spec:
  selector:
    app: nginx-proxy
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
```

```bash
kubectl apply -f nginx-proxy.yaml
```

#### 4. Testar Roteamento

```bash
# Testar rota padrão
kubectl run test-nginx --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://nginx-proxy-service

# Testar API v1
kubectl run test-v1 --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://nginx-proxy-service/v1

# Testar API v2
kubectl run test-v2 --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://nginx-proxy-service/v2
```

**Saída esperada:**
```
Nginx Proxy - Use /v1 or /v2
API Version 1
API Version 2
```

#### 5. Verificar Logs do Nginx

```bash
kubectl logs -l app=nginx-proxy --tail=20
```

**Saída esperada:**
```
10.244.1.5 - - [09/Mar/2026:16:15:30 +0000] "GET / HTTP/1.1" 200 32
10.244.1.5 - - [09/Mar/2026:16:15:35 +0000] "GET /v1 HTTP/1.1" 200 15
10.244.1.5 - - [09/Mar/2026:16:15:40 +0000] "GET /v2 HTTP/1.1" 200 15
```

## Método 4: Service Mesh Pattern (Simulado)

### Cenário

Criar um padrão de Service Mesh simplificado onde um Service intermediário adiciona funcionalidades como retry, timeout e logging.

### Implementação

#### 1. Backend Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-core
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend-core
  template:
    metadata:
      labels:
        app: backend-core
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args:
        - "-text=Core Backend"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: backend-core-service
spec:
  selector:
    app: backend-core
  ports:
  - port: 80
    targetPort: 5678
```

#### 2. Proxy Sidecar Pattern

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-with-proxy
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
      # Container principal
      - name: app
        image: curlimages/curl:8.6.0
        command: ["/bin/sh"]
        args:
        - -c
        - |
          while true; do
            echo "App calling proxy..."
            curl -s http://localhost:8080
            sleep 5
          done
        
      # Sidecar proxy
      - name: proxy
        image: nginx:1.27-alpine
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: proxy-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      
      volumes:
      - name: proxy-config
        configMap:
          name: sidecar-proxy-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: sidecar-proxy-config
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    
    http {
        upstream backend {
            server backend-core-service:80;
        }
        
        server {
            listen 8080;
            
            location / {
                proxy_pass http://backend;
                proxy_connect_timeout 2s;
                proxy_read_timeout 5s;
                
                # Adicionar headers customizados
                proxy_set_header X-Proxy-By "Sidecar";
                proxy_set_header X-Request-ID $request_id;
            }
        }
    }
```

```bash
kubectl apply -f backend-core.yaml
kubectl apply -f frontend-with-proxy.yaml
```

#### 3. Verificar Logs

```bash
# Logs do container app
kubectl logs -l app=frontend -c app --tail=10

# Logs do container proxy
kubectl logs -l app=frontend -c proxy --tail=10
```

**Saída esperada (app):**
```
App calling proxy...
Core Backend
App calling proxy...
Core Backend
```

## Exemplo Prático: Multi-Tier Application

### Arquitetura

```
Internet
   ↓
LoadBalancer Service
   ↓
Frontend Service (Nginx)
   ↓
API Gateway Service
   ↓
Backend Service 1 | Backend Service 2
   ↓                    ↓
Database Service    Cache Service
```

### Implementação Completa

```yaml
# Database
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: db
        image: hashicorp/http-echo:1.0
        args: ["-text=Database Layer"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
spec:
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5678
---
# Backend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: hashicorp/http-echo:1.0
        args: ["-text=Backend Layer -> Calling DB"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 5678
---
# API Gateway
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
data:
  nginx.conf: |
    events { worker_connections 1024; }
    http {
        upstream backend {
            server backend-service:8080;
        }
        server {
            listen 80;
            location /api {
                proxy_pass http://backend/;
            }
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gateway
  template:
    metadata:
      labels:
        app: gateway
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: gateway-config
---
apiVersion: v1
kind: Service
metadata:
  name: gateway-service
spec:
  selector:
    app: gateway
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f multi-tier-app.yaml
```

### Testar a Aplicação

```bash
# Obter IP do LoadBalancer (ou usar port-forward)
kubectl port-forward service/gateway-service 8080:80

# Em outro terminal
curl http://localhost:8080/api
```

**Saída esperada:**
```
Backend Layer -> Calling DB
```

## Comandos Úteis

### Verificar Comunicação Entre Services

```bash
# Testar de um Pod específico
kubectl exec -it <pod-name> -- curl http://<service-name>

# Criar Pod temporário para testes
kubectl run debug --image=nicolaka/netshoot --rm -it --restart=Never -- bash
```

### Verificar DNS de Services

```bash
# Resolver Service no mesmo namespace
nslookup <service-name>

# Resolver Service em outro namespace
nslookup <service-name>.<namespace>.svc.cluster.local

# Listar todos os Services
kubectl get svc --all-namespaces
```

### Trace de Requisições

```bash
# Logs em tempo real
kubectl logs -f <pod-name>

# Logs de múltiplos Pods
kubectl logs -l app=<label> --all-containers=true

# Eventos do Service
kubectl get events --field-selector involvedObject.name=<service-name>
```

## Troubleshooting

### Service não Alcança Outro Service

**Verificações:**

```bash
# 1. Verificar se Services existem
kubectl get svc

# 2. Verificar Endpoints
kubectl get endpoints <service-name>

# 3. Testar DNS
kubectl run test-dns --image=busybox:1.36 --rm -it --restart=Never -- nslookup <service-name>

# 4. Testar conectividade
kubectl run test-curl --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl -v http://<service-name>

# 5. Verificar Network Policies
kubectl get networkpolicies
```

### ExternalName não Resolve

**Problema:** Service ExternalName não resolve para outro Service.

**Solução:**

```bash
# Verificar formato do FQDN
# Correto: service-name.namespace.svc.cluster.local
kubectl get svc <service-name> -o yaml | grep externalName

# Testar resolução DNS diretamente
kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- nslookup <external-name>
```

### Endpoints Manuais não Funcionam

**Problema:** Endpoints customizados não roteia tráfego.

**Verificações:**

```bash
# Nome do Endpoints deve ser igual ao Service
kubectl get svc <service-name>
kubectl get endpoints <service-name>

# Verificar se IP está correto
kubectl get svc <backend-service> -o jsonpath='{.spec.clusterIP}'

# Verificar porta
kubectl describe endpoints <service-name>
```

## Boas Práticas

### 1. Naming Convention

```yaml
# Service original
name: user-api

# Service proxy
name: user-api-proxy

# Service cross-namespace
name: user-api-prod-proxy
```

### 2. Labels e Annotations

```yaml
metadata:
  name: proxy-service
  labels:
    app: proxy
    tier: gateway
    proxies: backend-service
  annotations:
    description: "Proxy for backend-service in production namespace"
    owner: "platform-team"
```

### 3. Documentação

```yaml
# Sempre documente o propósito
apiVersion: v1
kind: Service
metadata:
  name: legacy-api-proxy
  annotations:
    purpose: "Proxy to legacy API during migration"
    migration-date: "2026-06-01"
    contact: "devops@example.com"
```

### 4. Monitoramento

```yaml
# Adicione labels para monitoramento
metadata:
  labels:
    monitoring: "true"
    alert-level: "critical"
```

### 5. Segurança

- Use Network Policies para controlar tráfego entre Services
- Implemente mTLS para comunicação segura
- Limite acesso cross-namespace apenas quando necessário
- Use RBAC para controlar criação de Services

## Casos de Uso Reais

### 1. Blue-Green Deployment

```yaml
# Service principal (aponta para blue ou green)
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
    version: blue  # Trocar para 'green' durante deploy
  ports:
  - port: 80
```

### 2. Canary Release

```yaml
# Service principal (80% tráfego)
apiVersion: v1
kind: Service
metadata:
  name: app-stable
spec:
  selector:
    app: myapp
    version: stable
---
# Service canary (20% tráfego via Ingress)
apiVersion: v1
kind: Service
metadata:
  name: app-canary
spec:
  selector:
    app: myapp
    version: canary
```

### 3. Multi-Region

```yaml
# Service local
apiVersion: v1
kind: Service
metadata:
  name: api-local
  namespace: us-east
spec:
  selector:
    app: api
---
# Service apontando para outra região
apiVersion: v1
kind: Service
metadata:
  name: api-west
  namespace: us-east
spec:
  type: ExternalName
  externalName: api-local.us-west.svc.cluster.local
```

## Limpeza

```bash
# Remover todos os recursos criados
kubectl delete deployment --all
kubectl delete service --all
kubectl delete configmap --all
kubectl delete endpoints --all

# Remover namespaces
kubectl delete namespace production development
```

## Resumo

- **ExternalName** é ideal para cross-namespace e integração com DNS
- **Endpoints manuais** oferecem controle total sobre roteamento
- **Proxy Pods** permitem lógica customizada (retry, timeout, logging)
- **Sidecar pattern** adiciona funcionalidades sem modificar aplicação
- Services podem criar camadas de abstração complexas
- Útil para migração, multi-tenant e arquiteturas de microsserviços
- Sempre documente o propósito e relacionamentos entre Services

## Próximos Passos

- Estudar **Ingress** para roteamento HTTP/HTTPS avançado
- Explorar **Service Mesh** (Istio, Linkerd) para controle de tráfego
- Implementar **Network Policies** para segurança
- Configurar **mTLS** para comunicação segura entre Services
- Estudar **Gateway API** (sucessor do Ingress)
