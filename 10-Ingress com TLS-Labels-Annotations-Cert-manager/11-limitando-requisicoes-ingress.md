# Limitando Requisições às Aplicações com Ingress

## Introdução

Rate Limiting é uma técnica essencial para proteger suas aplicações contra abuso, ataques DDoS, e garantir uso justo dos recursos. O Nginx Ingress Controller oferece annotations poderosas para implementar diferentes tipos de limitação de requisições.

## Por que Limitar Requisições?

### Sem Rate Limiting

```
Cliente malicioso → 10.000 req/s → Aplicação
                                      ↓
                                   Sobrecarga
                                      ↓
                                   Indisponível
```

### Com Rate Limiting

```
Cliente malicioso → 10.000 req/s → Ingress (Rate Limit)
                                      ↓
                                   100 req/s → Aplicação
                                      ↓
                                   Funcionando normalmente
```

## Fluxo de Rate Limiting

```
1. Cliente faz requisição
        ↓
2. Ingress verifica contador de requisições
        ↓
3. Se dentro do limite → permite
   Se excedeu limite → retorna 503 (ou 429)
        ↓
4. Atualiza contador
        ↓
5. Aguarda janela de tempo para resetar
```

---

## Tipos de Rate Limiting

### 1. Limite por IP (RPS - Requests Per Second)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-rate-limit-ip
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
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

**Comportamento:**
- Cada IP pode fazer até 10 requisições por segundo
- Requisições excedentes retornam HTTP 503

### 2. Limite por Conexões Simultâneas

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-rate-limit-connections
  annotations:
    nginx.ingress.kubernetes.io/limit-connections: "5"
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

**Comportamento:**
- Cada IP pode ter até 5 conexões simultâneas
- Conexões excedentes são rejeitadas

### 3. Limite por RPM (Requests Per Minute)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-rate-limit-rpm
  annotations:
    nginx.ingress.kubernetes.io/limit-rpm: "100"
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

**Comportamento:**
- Cada IP pode fazer até 100 requisições por minuto
- Útil para APIs com limites mais generosos

### 4. Burst (Rajada Permitida)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-rate-limit-burst
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "5"
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "3"
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

**Comportamento:**
- Limite: 5 req/s
- Burst: 5 × 3 = 15 requisições
- Permite picos temporários de até 15 req/s

### 5. Whitelist de IPs (Sem Limite)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-rate-limit-whitelist
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8,192.168.1.100"
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

**Comportamento:**
- IPs na whitelist não têm limite
- Outros IPs: 10 req/s

---

## Exemplo Prático Completo

### Aplicação com Rate Limiting Configurado

```yaml
# app-with-rate-limit.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-limited
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-limited
  template:
    metadata:
      labels:
        app: api-limited
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
          name: api-limited-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-limited-config
data:
  default.conf: |
    server {
        listen 80;
        
        location / {
            add_header X-Pod-Name $hostname;
            add_header X-Request-Time $request_time;
            return 200 "API Response\nPod: $hostname\nTime: $time_iso8601\n";
        }
        
        location /health {
            return 200 "OK\n";
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: api-limited
spec:
  selector:
    app: api-limited
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-limited
  annotations:
    # Limite de 10 requisições por segundo por IP
    nginx.ingress.kubernetes.io/limit-rps: "10"
    
    # Permite burst de até 20 requisições
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "2"
    
    # Máximo de 5 conexões simultâneas por IP
    nginx.ingress.kubernetes.io/limit-connections: "5"
    
    # Whitelist de IPs internos (sem limite)
    nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8"
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
            name: api-limited
            port:
              number: 80
```

### Deploy e Teste

```bash
# Aplicar configuração
kubectl apply -f app-with-rate-limit.yaml

# Verificar
kubectl get pods -l app=api-limited
kubectl get ingress api-limited
kubectl describe ingress api-limited | grep -A 5 Annotations

# Teste 1: Requisições normais (dentro do limite)
for i in {1..5}; do
  curl -s http://api.example.com
  sleep 0.2
done

# Teste 2: Exceder limite (deve retornar 503)
for i in {1..20}; do
  curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://api.example.com
done

# Teste 3: Medir taxa de sucesso
SUCCESS=0
FAILED=0

for i in {1..100}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://api.example.com)
  if [ "$CODE" == "200" ]; then
    ((SUCCESS++))
  else
    ((FAILED++))
  fi
done

echo "Sucesso: $SUCCESS, Falhas: $FAILED"
```

---

## Configurações Avançadas

### Rate Limiting por Path

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-path-limits
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      # API pública - limite restritivo
      - path: /public
        pathType: Prefix
        backend:
          service:
            name: api-public
            port:
              number: 80
      # API privada - limite generoso
      - path: /private
        pathType: Prefix
        backend:
          service:
            name: api-private
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-public-limit
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "5"
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /public
        pathType: Prefix
        backend:
          service:
            name: api-public
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-private-limit
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "100"
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /private
        pathType: Prefix
        backend:
          service:
            name: api-private
            port:
              number: 80
```

### Rate Limiting com Código de Erro Customizado

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-custom-error
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-rate-status-code: "429"
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
            name: myapp
            port:
              number: 80
```

**Comportamento:**
- Retorna HTTP 429 (Too Many Requests) em vez de 503
- Mais semântico para APIs REST

### Rate Limiting por Zona Customizada

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-custom-zone
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-rate: "100k"
    nginx.ingress.kubernetes.io/limit-rate-after: "1m"
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
            name: myapp
            port:
              number: 80
```

**Comportamento:**
- Após 1MB transferido, limita velocidade para 100KB/s
- Útil para downloads grandes

---

## Rate Limiting por Header/Cookie

### Limite por API Key (Header)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  limit-req-zone: "$http_x_api_key zone=api_key_limit:10m rate=100r/s"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-key-limit
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=api_key_limit burst=20 nodelay;
      
      if ($http_x_api_key = "") {
        return 401 "API Key required\n";
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
            name: myapp
            port:
              number: 80
```

**Teste:**
```bash
# Sem API key - retorna 401
curl http://api.example.com

# Com API key - funciona
curl -H "X-API-Key: abc123" http://api.example.com

# Exceder limite da mesma API key
for i in {1..150}; do
  curl -H "X-API-Key: abc123" http://api.example.com
done
```

### Limite por User ID (Cookie)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-user-limit
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      set $limit_key $cookie_user_id;
      
      if ($limit_key = "") {
        set $limit_key $remote_addr;
      }
      
      limit_req_zone $limit_key zone=user_limit:10m rate=50r/s;
      limit_req zone=user_limit burst=10 nodelay;
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
            name: myapp
            port:
              number: 80
```

---

## Monitoramento de Rate Limiting

### Ver Logs de Requisições Limitadas

```bash
# Logs do ingress controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 | grep "limiting requests"

# Filtrar apenas erros 503
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 | grep "503"

# Contar requisições limitadas
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=1000 | grep -c "limiting requests"
```

### Métricas com Prometheus

```yaml
# ServiceMonitor para Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-ingress
  namespace: ingress-nginx
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
  endpoints:
  - port: metrics
    interval: 30s
```

**Queries úteis:**
```promql
# Taxa de requisições limitadas
rate(nginx_ingress_controller_requests{status="503"}[5m])

# Porcentagem de requisições limitadas
rate(nginx_ingress_controller_requests{status="503"}[5m]) 
/ 
rate(nginx_ingress_controller_requests[5m]) * 100

# Top IPs sendo limitados
topk(10, sum by (remote_addr) (rate(nginx_ingress_controller_requests{status="503"}[5m])))
```

### Dashboard Grafana

```json
{
  "title": "Rate Limiting",
  "panels": [
    {
      "title": "Requisições Limitadas",
      "targets": [
        {
          "expr": "rate(nginx_ingress_controller_requests{status=\"503\"}[5m])"
        }
      ]
    },
    {
      "title": "Taxa de Limite (%)",
      "targets": [
        {
          "expr": "rate(nginx_ingress_controller_requests{status=\"503\"}[5m]) / rate(nginx_ingress_controller_requests[5m]) * 100"
        }
      ]
    }
  ]
}
```

---

## Exemplo: API com Múltiplos Níveis de Limite

```yaml
# api-tiered-limits.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-tiered
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-tiered
  template:
    metadata:
      labels:
        app: api-tiered
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-tiered
spec:
  selector:
    app: api-tiered
  ports:
  - port: 80
---
# Tier Free - 10 req/s
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-free
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "1"
    nginx.ingress.kubernetes.io/limit-rate-status-code: "429"
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /free
        pathType: Prefix
        backend:
          service:
            name: api-tiered
            port:
              number: 80
---
# Tier Pro - 100 req/s
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-pro
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "2"
    nginx.ingress.kubernetes.io/limit-rate-status-code: "429"
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /pro
        pathType: Prefix
        backend:
          service:
            name: api-tiered
            port:
              number: 80
---
# Tier Enterprise - sem limite
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-enterprise
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /enterprise
        pathType: Prefix
        backend:
          service:
            name: api-tiered
            port:
              number: 80
```

### Teste dos Tiers

```bash
# Tier Free - deve limitar em ~10 req/s
echo "Testando Tier Free..."
for i in {1..50}; do
  curl -s -o /dev/null -w "%{http_code} " http://api.example.com/free
done
echo ""

# Tier Pro - deve limitar em ~100 req/s
echo "Testando Tier Pro..."
for i in {1..200}; do
  curl -s -o /dev/null -w "%{http_code} " http://api.example.com/pro
done
echo ""

# Tier Enterprise - sem limite
echo "Testando Tier Enterprise..."
for i in {1..200}; do
  curl -s -o /dev/null -w "%{http_code} " http://api.example.com/enterprise
done
echo ""
```

---

## Troubleshooting

### Problema: Limite Não Funciona

```bash
# Verificar annotations
kubectl get ingress api-limited -o yaml | grep limit

# Verificar configuração do nginx
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep -A 10 "limit_req"

# Verificar logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
```

### Problema: Limite Muito Restritivo

```bash
# Aumentar limite
kubectl patch ingress api-limited -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/limit-rps":"50"}}}'

# Aumentar burst
kubectl patch ingress api-limited -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/limit-burst-multiplier":"5"}}}'
```

### Problema: Whitelist Não Funciona

```bash
# Verificar IP real do cliente
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=10 | grep "remote_addr"

# Adicionar IP à whitelist
kubectl annotate ingress api-limited nginx.ingress.kubernetes.io/limit-whitelist="10.0.0.0/8,192.168.1.100"
```

---

## Comandos Úteis

```bash
# Aplicar rate limit de 10 req/s
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/limit-rps="10"

# Aplicar limite de conexões
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/limit-connections="5"

# Aplicar burst multiplier
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/limit-burst-multiplier="3"

# Mudar código de erro para 429
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/limit-rate-status-code="429"

# Adicionar whitelist
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/limit-whitelist="10.0.0.0/8"

# Remover rate limit
kubectl annotate ingress myapp nginx.ingress.kubernetes.io/limit-rps-

# Ver configuração atual
kubectl get ingress myapp -o jsonpath='{.metadata.annotations}' | jq

# Testar limite
for i in {1..100}; do curl -s -o /dev/null -w "%{http_code}\n" http://app.example.com; done | sort | uniq -c

# Monitorar requisições limitadas
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f | grep "limiting"
```

---

## Boas Práticas

### 1. Defina Limites Realistas

```yaml
# Muito restritivo - pode afetar usuários legítimos
nginx.ingress.kubernetes.io/limit-rps: "1"

# Balanceado - protege sem afetar uso normal
nginx.ingress.kubernetes.io/limit-rps: "10"
nginx.ingress.kubernetes.io/limit-burst-multiplier: "2"
```

### 2. Use Whitelist para Serviços Internos

```yaml
nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8,172.16.0.0/12"
```

### 3. Retorne Código HTTP Apropriado

```yaml
# Use 429 para APIs REST
nginx.ingress.kubernetes.io/limit-rate-status-code: "429"
```

### 4. Monitore Requisições Limitadas

```bash
# Alerta se muitas requisições sendo limitadas
rate(nginx_ingress_controller_requests{status="503"}[5m]) > 100
```

### 5. Combine com Outras Proteções

```yaml
annotations:
  # Rate limiting
  nginx.ingress.kubernetes.io/limit-rps: "10"
  
  # Autenticação
  nginx.ingress.kubernetes.io/auth-type: basic
  
  # IP whitelist
  nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8"
```

---

## Conclusão

Rate Limiting com Ingress oferece:

✅ **Proteção contra Abuso** - Previne ataques DDoS e scraping  
✅ **Uso Justo** - Garante recursos para todos os usuários  
✅ **Flexibilidade** - Por IP, conexão, path, header, cookie  
✅ **Burst Control** - Permite picos temporários controlados  
✅ **Whitelist** - Exceções para IPs/serviços confiáveis  
✅ **Monitoramento** - Métricas e logs detalhados  
✅ **Fácil Configuração** - Apenas annotations no Ingress  

Use rate limiting para proteger suas aplicações e garantir disponibilidade e performance para todos os usuários!
