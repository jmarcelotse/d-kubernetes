# Configurando Upstream Hashing no Ingress

## Introdução

Upstream Hashing é um método de balanceamento de carga que usa um hash consistente baseado em variáveis (IP, header, cookie) para determinar qual pod backend receberá a requisição. Diferente do session affinity baseado em cookies, o hashing é calculado no servidor sem necessidade de cookies.

## O que é Upstream Hashing?

### Comparação de Métodos

**Round-Robin (Padrão)**
```
Requisição 1 → Pod 1
Requisição 2 → Pod 2
Requisição 3 → Pod 3
Requisição 4 → Pod 1
```

**Session Affinity (Cookie)**
```
Requisição 1 → Pod 1 (cookie criado)
Requisição 2 → Pod 1 (cookie lido)
Requisição 3 → Pod 1 (cookie lido)
```

**Upstream Hashing (IP/Header)**
```
IP 192.168.1.10 → hash(IP) → Pod 2 (sempre)
IP 192.168.1.20 → hash(IP) → Pod 1 (sempre)
IP 192.168.1.30 → hash(IP) → Pod 3 (sempre)
```

## Fluxo de Funcionamento

```
1. Cliente faz requisição
        ↓
2. Ingress extrai variável (IP, header, etc)
        ↓
3. Calcula hash da variável
        ↓
4. Hash determina o pod backend
        ↓
5. Requisição enviada ao pod
        ↓
6. Mesma variável = mesmo pod (sempre)
```

---

## Tipos de Upstream Hashing

### 1. Hash por IP do Cliente

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-hash-ip
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$remote_addr"
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
            name: myapp
            port:
              number: 80
```

**Quando usar:**
- Cache distribuído por cliente
- Rate limiting por IP
- Logs agrupados por origem

### 2. Hash por Header Customizado

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-hash-header
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$http_x_user_id"
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
            name: myapp
            port:
              number: 80
```

**Quando usar:**
- Multi-tenancy (tenant ID)
- Sharding por usuário
- Isolamento de dados

### 3. Hash por URI

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-hash-uri
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
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
            name: myapp
            port:
              number: 80
```

**Quando usar:**
- Cache de conteúdo estático
- CDN interno
- Otimização de recursos

### 4. Hash por Query String

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-hash-query
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$arg_session_id"
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
            name: myapp
            port:
              number: 80
```

**Quando usar:**
- API com session ID na URL
- Tracking de requisições
- A/B testing

### 5. Hash Combinado (Múltiplas Variáveis)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-hash-combined
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$remote_addr$http_x_tenant_id"
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
            name: myapp
            port:
              number: 80
```

**Quando usar:**
- Distribuição mais granular
- Múltiplos critérios de roteamento
- Balanceamento complexo

---

## Exemplo Prático Completo

### Cenário: API Multi-Tenant com Cache

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-multitenant
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-multitenant
  template:
    metadata:
      labels:
        app: api-multitenant
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: api-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
data:
  default.conf: |
    server {
        listen 80;
        location / {
            add_header X-Pod-Name $hostname;
            add_header X-Tenant-ID $http_x_tenant_id;
            return 200 "Pod: $hostname\nTenant: $http_x_tenant_id\n";
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: api-multitenant
spec:
  selector:
    app: api-multitenant
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-multitenant
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$http_x_tenant_id"
    nginx.ingress.kubernetes.io/upstream-hash-by-subset: "true"
    nginx.ingress.kubernetes.io/upstream-hash-by-subset-size: "3"
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
            name: api-multitenant
            port:
              number: 80
```

### Aplicar Configuração

```bash
# Aplicar recursos
kubectl apply -f deployment.yaml

# Verificar pods
kubectl get pods -l app=api-multitenant

# Verificar ingress
kubectl get ingress api-multitenant
kubectl describe ingress api-multitenant
```

### Testar Upstream Hashing

```bash
# Tenant A - sempre no mesmo pod
for i in {1..5}; do
  curl -H "X-Tenant-ID: tenant-a" http://api.example.com
done

# Tenant B - sempre no mesmo pod (diferente do A)
for i in {1..5}; do
  curl -H "X-Tenant-ID: tenant-b" http://api.example.com
done

# Tenant C - sempre no mesmo pod
for i in {1..5}; do
  curl -H "X-Tenant-ID: tenant-c" http://api.example.com
done
```

**Resultado Esperado:**
```
# Tenant A
Pod: api-multitenant-7d8f9c-abc12
Tenant: tenant-a
Pod: api-multitenant-7d8f9c-abc12
Tenant: tenant-a
...

# Tenant B
Pod: api-multitenant-7d8f9c-def34
Tenant: tenant-b
Pod: api-multitenant-7d8f9c-def34
Tenant: tenant-b
...

# Tenant C
Pod: api-multitenant-7d8f9c-ghi56
Tenant: tenant-c
Pod: api-multitenant-7d8f9c-ghi56
Tenant: tenant-c
```

---

## Configurações Avançadas

### Consistent Hashing com Subset

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-consistent-hash
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$remote_addr"
    nginx.ingress.kubernetes.io/upstream-hash-by-subset: "true"
    nginx.ingress.kubernetes.io/upstream-hash-by-subset-size: "3"
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
            name: myapp
            port:
              number: 80
```

**Benefícios:**
- Minimiza redistribuição quando pods são adicionados/removidos
- Melhor para cache distribuído
- Reduz cache misses

### Hash com Fallback

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-hash-fallback
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$http_x_user_id$remote_addr"
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
            name: myapp
            port:
              number: 80
```

**Lógica:**
- Se `X-User-ID` existe → usa no hash
- Se não existe → usa IP do cliente

---

## Variáveis Nginx Disponíveis

### Variáveis de Cliente

```bash
$remote_addr          # IP do cliente
$remote_port          # Porta do cliente
$remote_user          # Usuário autenticado
```

### Variáveis de Requisição

```bash
$request_uri          # URI completa (/path?query=value)
$uri                  # URI sem query string (/path)
$args                 # Query string completa (query=value)
$arg_NOME             # Parâmetro específico (?session_id=123)
$request_method       # GET, POST, etc
```

### Variáveis de Headers

```bash
$http_NOME            # Qualquer header (X-User-ID → $http_x_user_id)
$http_host            # Header Host
$http_user_agent      # User-Agent
$http_cookie          # Cookie completo
$cookie_NOME          # Cookie específico
```

### Variáveis de Servidor

```bash
$server_name          # Nome do servidor virtual
$server_port          # Porta do servidor
$scheme               # http ou https
```

---

## Exemplo: Hash por Região Geográfica

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-geo-hash
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$http_x_geo_region"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      set $geo_region "default";
      if ($http_cf_ipcountry = "BR") {
        set $geo_region "sa";
      }
      if ($http_cf_ipcountry = "US") {
        set $geo_region "na";
      }
      if ($http_cf_ipcountry = "DE") {
        set $geo_region "eu";
      }
      proxy_set_header X-Geo-Region $geo_region;
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
            name: myapp
            port:
              number: 80
```

---

## Monitoramento e Debug

### Ver Configuração do Nginx

```bash
# Entrar no pod do ingress controller
kubectl get pods -n ingress-nginx
kubectl exec -it -n ingress-nginx nginx-ingress-controller-xxx -- bash

# Ver configuração gerada
cat /etc/nginx/nginx.conf | grep -A 10 "upstream"
```

### Logs de Balanceamento

```bash
# Habilitar logs detalhados
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/enable-access-log="true"

# Ver logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 -f
```

### Testar Distribuição

```bash
# Script para testar distribuição
#!/bin/bash

declare -A pod_count

for i in {1..100}; do
  TENANT="tenant-$((i % 10))"
  POD=$(curl -s -H "X-Tenant-ID: $TENANT" http://api.example.com | grep Pod | awk '{print $2}')
  pod_count[$POD]=$((${pod_count[$POD]:-0} + 1))
done

echo "Distribuição de requisições:"
for pod in "${!pod_count[@]}"; do
  echo "$pod: ${pod_count[$pod]} requisições"
done
```

---

## Comparação: Session Affinity vs Upstream Hashing

| Característica | Session Affinity | Upstream Hashing |
|----------------|------------------|------------------|
| **Método** | Cookie no cliente | Hash no servidor |
| **Overhead** | Cookie em cada requisição | Cálculo de hash |
| **Privacidade** | Expõe cookie ao cliente | Transparente |
| **Flexibilidade** | Apenas cookie | Qualquer variável |
| **Persistência** | Até expiração do cookie | Enquanto variável for igual |
| **APIs** | Requer suporte a cookies | Funciona com qualquer API |
| **Stateless** | Não (depende de cookie) | Sim (baseado em variável) |

---

## Casos de Uso Reais

### 1. Cache Distribuído

```yaml
annotations:
  nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
```

**Benefício:** Mesma URL sempre no mesmo pod = cache hit

### 2. WebSocket por Usuário

```yaml
annotations:
  nginx.ingress.kubernetes.io/upstream-hash-by: "$http_x_user_id"
```

**Benefício:** Conexões WebSocket do mesmo usuário no mesmo pod

### 3. Rate Limiting por IP

```yaml
annotations:
  nginx.ingress.kubernetes.io/upstream-hash-by: "$remote_addr"
```

**Benefício:** Rate limit consistente por IP

### 4. Sharding de Dados

```yaml
annotations:
  nginx.ingress.kubernetes.io/upstream-hash-by: "$arg_shard_key"
```

**Benefício:** Dados particionados por chave

---

## Troubleshooting

### Problema: Distribuição Desigual

```bash
# Verificar número de pods
kubectl get pods -l app=myapp

# Verificar se todos estão Ready
kubectl get endpoints myapp

# Testar distribuição
for i in {1..100}; do
  curl -s http://app.example.com | grep Pod
done | sort | uniq -c
```

**Solução:** Usar consistent hashing com subset

```yaml
annotations:
  nginx.ingress.kubernetes.io/upstream-hash-by-subset: "true"
  nginx.ingress.kubernetes.io/upstream-hash-by-subset-size: "3"
```

### Problema: Variável Não Encontrada

```bash
# Ver headers recebidos
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep "X-Tenant-ID"
```

**Solução:** Verificar se header está sendo enviado

```bash
curl -v -H "X-Tenant-ID: test" http://app.example.com 2>&1 | grep "X-Tenant-ID"
```

### Problema: Hash Não Funciona Após Scale

```bash
# Verificar eventos
kubectl get events --sort-by='.lastTimestamp'

# Verificar endpoints
kubectl get endpoints myapp -o yaml
```

**Solução:** Aguardar propagação ou usar consistent hashing

---

## Comandos Úteis

```bash
# Aplicar upstream hashing
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/upstream-hash-by='$remote_addr'

# Remover upstream hashing
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/upstream-hash-by-

# Ver configuração atual
kubectl get ingress myapp -o yaml | grep upstream-hash

# Testar com diferentes IPs (simulado)
curl -H "X-Forwarded-For: 192.168.1.10" http://app.example.com
curl -H "X-Forwarded-For: 192.168.1.20" http://app.example.com

# Testar com diferentes headers
curl -H "X-User-ID: user1" http://app.example.com
curl -H "X-User-ID: user2" http://app.example.com

# Ver distribuição em tempo real
watch -n 1 'curl -s http://app.example.com | grep Pod'
```

---

## Conclusão

Upstream Hashing oferece:

✅ **Balanceamento Inteligente** - Baseado em variáveis customizadas  
✅ **Sem Cookies** - Transparente para o cliente  
✅ **Flexível** - Qualquer variável Nginx disponível  
✅ **Consistente** - Mesma variável = mesmo pod  
✅ **Stateless** - Não depende de estado no cliente  
✅ **Performance** - Cache distribuído eficiente  
✅ **Multi-Tenant** - Isolamento por tenant/usuário  

Use upstream hashing quando precisar de roteamento determinístico baseado em características da requisição, especialmente para APIs stateless, cache distribuído e arquiteturas multi-tenant!
