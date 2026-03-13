# Canary Deployment com Ingress no Kubernetes

## Introdução

Canary Deployment é uma estratégia de implantação que permite testar uma nova versão da aplicação com uma pequena porcentagem do tráfego antes de fazer o rollout completo. O nome vem dos "canários nas minas de carvão" - usados para detectar problemas antes que afetem todos.

## O que é Canary Deployment?

### Deployment Tradicional (Big Bang)

```
Versão 1 (100%) → Versão 2 (100%)
                   ↓
            Risco: todos afetados se houver bug
```

### Canary Deployment

```
Versão 1 (100%) → Versão 1 (90%) + Versão 2 (10%)
                   ↓
                  Versão 1 (50%) + Versão 2 (50%)
                   ↓
                  Versão 2 (100%)
                   
Risco: apenas 10% afetados inicialmente
```

## Fluxo de Canary Deployment

```
1. Deploy versão estável (v1) - 100% tráfego
        ↓
2. Deploy versão canary (v2) - 0% tráfego
        ↓
3. Direcionar 10% tráfego para v2
        ↓
4. Monitorar métricas (erros, latência, etc)
        ↓
5. Se OK → aumentar para 25%, 50%, 75%
   Se ERRO → reverter para 100% v1
        ↓
6. Quando 100% em v2 → remover v1
```

---

## Métodos de Canary com Ingress

### 1. Canary por Peso (Weight-Based)

Distribui tráfego por porcentagem.

```yaml
# Deployment versão estável
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: stable
  template:
    metadata:
      labels:
        app: myapp
        version: stable
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
---
# Service versão estável
apiVersion: v1
kind: Service
metadata:
  name: myapp-stable
spec:
  selector:
    app: myapp
    version: stable
  ports:
  - port: 80
    targetPort: 80
---
# Ingress principal
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-stable
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
            name: myapp-stable
            port:
              number: 80
---
# Deployment versão canary
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      version: canary
  template:
    metadata:
      labels:
        app: myapp
        version: canary
    spec:
      containers:
      - name: app
        image: nginx:1.22
        ports:
        - containerPort: 80
---
# Service versão canary
apiVersion: v1
kind: Service
metadata:
  name: myapp-canary
spec:
  selector:
    app: myapp
    version: canary
  ports:
  - port: 80
    targetPort: 80
---
# Ingress canary - 10% do tráfego
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
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
            name: myapp-canary
            port:
              number: 80
```

### 2. Canary por Header

Direciona tráfego baseado em header HTTP específico.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
    nginx.ingress.kubernetes.io/canary-by-header-value: "true"
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
            name: myapp-canary
            port:
              number: 80
```

**Teste:**
```bash
# Vai para versão canary
curl -H "X-Canary: true" http://app.example.com

# Vai para versão estável
curl http://app.example.com
```

### 3. Canary por Cookie

Direciona tráfego baseado em cookie.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-cookie: "canary"
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
            name: myapp-canary
            port:
              number: 80
```

**Teste:**
```bash
# Vai para versão canary
curl -b "canary=always" http://app.example.com

# Vai para versão estável
curl -b "canary=never" http://app.example.com

# Usa weight se cookie não existir
curl http://app.example.com
```

### 4. Canary por Header Pattern (Regex)

Direciona tráfego baseado em padrão regex no header.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "User-Agent"
    nginx.ingress.kubernetes.io/canary-by-header-pattern: ".*Chrome.*"
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
            name: myapp-canary
            port:
              number: 80
```

**Teste:**
```bash
# Vai para versão canary (Chrome)
curl -H "User-Agent: Mozilla/5.0 Chrome/90.0" http://app.example.com

# Vai para versão estável (Firefox)
curl -H "User-Agent: Mozilla/5.0 Firefox/88.0" http://app.example.com
```

---

## Exemplo Prático Completo

### Cenário: Aplicação com Versões Identificáveis

```yaml
# app-stable.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
  labels:
    app: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: stable
  template:
    metadata:
      labels:
        app: myapp
        version: stable
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: app-stable-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-stable-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>App v1.0</title></head>
    <body style="background-color: #4CAF50; color: white; text-align: center; padding: 50px;">
        <h1>Versão Estável v1.0</h1>
        <p>Esta é a versão de produção atual</p>
        <p>Pod: <span id="pod"></span></p>
        <script>
            fetch('/hostname').then(r => r.text()).then(h => {
                document.getElementById('pod').textContent = h;
            }).catch(() => {
                document.getElementById('pod').textContent = 'N/A';
            });
        </script>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-stable
spec:
  selector:
    app: myapp
    version: stable
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-stable
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
            name: myapp-stable
            port:
              number: 80
```

```yaml
# app-canary.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
  labels:
    app: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      version: canary
  template:
    metadata:
      labels:
        app: myapp
        version: canary
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: app-canary-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-canary-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>App v2.0</title></head>
    <body style="background-color: #FF9800; color: white; text-align: center; padding: 50px;">
        <h1>Versão Canary v2.0 🐤</h1>
        <p>Esta é a nova versão em teste</p>
        <p>Pod: <span id="pod"></span></p>
        <script>
            fetch('/hostname').then(r => r.text()).then(h => {
                document.getElementById('pod').textContent = h;
            }).catch(() => {
                document.getElementById('pod').textContent = 'N/A';
            });
        </script>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-canary
spec:
  selector:
    app: myapp
    version: canary
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "20"
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
            name: myapp-canary
            port:
              number: 80
```

### Deploy e Teste

```bash
# 1. Deploy versão estável
kubectl apply -f app-stable.yaml

# Verificar
kubectl get pods -l version=stable
kubectl get svc myapp-stable
kubectl get ingress myapp-stable

# Testar - deve mostrar v1.0 (verde)
curl http://app.example.com

# 2. Deploy versão canary com 20% de tráfego
kubectl apply -f app-canary.yaml

# Verificar
kubectl get pods -l version=canary
kubectl get ingress myapp-canary

# 3. Testar distribuição
for i in {1..10}; do
  curl -s http://app.example.com | grep -o "v[0-9]\.[0-9]"
done

# Resultado esperado: ~8x v1.0 e ~2x v2.0
```

---

## Progressão de Canary Deployment

### Fase 1: Deploy Inicial (0% Canary)

```bash
# Apenas versão estável
kubectl apply -f app-stable.yaml
```

### Fase 2: Canary 10%

```bash
# Criar ingress canary com 10%
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
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
            name: myapp-canary
            port:
              number: 80
EOF

# Monitorar por 15 minutos
watch -n 5 'curl -s http://app.example.com | grep Version'
```

### Fase 3: Aumentar para 25%

```bash
kubectl patch ingress myapp-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"25"}}}'

# Monitorar métricas
kubectl top pods -l app=myapp
```

### Fase 4: Aumentar para 50%

```bash
kubectl patch ingress myapp-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"50"}}}'
```

### Fase 5: Aumentar para 75%

```bash
kubectl patch ingress myapp-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"75"}}}'
```

### Fase 6: Promover Canary (100%)

```bash
# Remover annotation canary (torna ingress normal)
kubectl annotate ingress myapp-canary nginx.ingress.kubernetes.io/canary-

# Ou deletar ingress stable e renomear canary
kubectl delete ingress myapp-stable
kubectl delete deployment myapp-stable
kubectl delete service myapp-stable

# Renomear canary para stable
kubectl patch deployment myapp-canary -p '{"metadata":{"name":"myapp-stable"}}'
```

### Rollback (Se Necessário)

```bash
# Voltar para 0% canary
kubectl patch ingress myapp-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"0"}}}'

# Ou deletar completamente
kubectl delete ingress myapp-canary
kubectl delete deployment myapp-canary
kubectl delete service myapp-canary
```

---

## Combinando Múltiplas Estratégias

### Canary com Weight + Header

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
    nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
    nginx.ingress.kubernetes.io/canary-by-header-value: "always"
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
            name: myapp-canary
            port:
              number: 80
```

**Prioridade:**
1. Se header `X-Canary: always` → 100% canary
2. Se header `X-Canary: never` → 0% canary
3. Senão → usa weight (10%)

### Canary para Usuários Internos

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "X-User-Type"
    nginx.ingress.kubernetes.io/canary-by-header-value: "internal"
    nginx.ingress.kubernetes.io/canary-weight: "5"
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
            name: myapp-canary
            port:
              number: 80
```

**Lógica:**
- Usuários internos (`X-User-Type: internal`) → sempre canary
- Outros usuários → 5% canary, 95% stable

---

## Monitoramento de Canary

### Script de Teste de Distribuição

```bash
#!/bin/bash

TOTAL=100
STABLE=0
CANARY=0

echo "Testando distribuição de tráfego..."

for i in $(seq 1 $TOTAL); do
  VERSION=$(curl -s http://app.example.com | grep -o "v[0-9]\.[0-9]")
  
  if [[ "$VERSION" == "v1.0" ]]; then
    ((STABLE++))
  elif [[ "$VERSION" == "v2.0" ]]; then
    ((CANARY++))
  fi
  
  echo -ne "Progresso: $i/$TOTAL\r"
done

echo ""
echo "Resultados:"
echo "  Stable (v1.0): $STABLE ($((STABLE * 100 / TOTAL))%)"
echo "  Canary (v2.0): $CANARY ($((CANARY * 100 / TOTAL))%)"
```

### Monitorar Logs

```bash
# Logs da versão stable
kubectl logs -l version=stable --tail=50 -f

# Logs da versão canary
kubectl logs -l version=canary --tail=50 -f

# Comparar taxa de erros
kubectl logs -l version=stable | grep -i error | wc -l
kubectl logs -l version=canary | grep -i error | wc -l
```

### Métricas com Prometheus

```yaml
# ServiceMonitor para Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-canary
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
```

**Queries úteis:**
```promql
# Taxa de requisições por versão
rate(http_requests_total{app="myapp"}[5m])

# Taxa de erros por versão
rate(http_requests_total{app="myapp",status=~"5.."}[5m])

# Latência p95 por versão
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="myapp"}[5m]))
```

---

## Automação com Scripts

### Script de Progressão Automática

```bash
#!/bin/bash

WEIGHTS=(10 25 50 75 100)
WAIT_TIME=300  # 5 minutos

for WEIGHT in "${WEIGHTS[@]}"; do
  echo "Configurando canary para ${WEIGHT}%..."
  
  if [ $WEIGHT -eq 100 ]; then
    # Promover canary
    kubectl delete ingress myapp-stable
    kubectl annotate ingress myapp-canary nginx.ingress.kubernetes.io/canary-
  else
    kubectl patch ingress myapp-canary -p "{\"metadata\":{\"annotations\":{\"nginx.ingress.kubernetes.io/canary-weight\":\"$WEIGHT\"}}}"
  fi
  
  echo "Aguardando ${WAIT_TIME}s para monitoramento..."
  sleep $WAIT_TIME
  
  # Verificar taxa de erros
  ERROR_RATE=$(kubectl logs -l version=canary --tail=1000 | grep -i error | wc -l)
  
  if [ $ERROR_RATE -gt 10 ]; then
    echo "ERRO: Taxa de erros muito alta ($ERROR_RATE). Fazendo rollback!"
    kubectl patch ingress myapp-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"0"}}}'
    exit 1
  fi
  
  echo "Tudo OK. Continuando..."
done

echo "Canary deployment concluído com sucesso!"
```

---

## Troubleshooting

### Problema: Canary Não Recebe Tráfego

```bash
# Verificar annotation
kubectl get ingress myapp-canary -o yaml | grep canary

# Verificar se ingress stable existe
kubectl get ingress myapp-stable

# Verificar endpoints
kubectl get endpoints myapp-canary
```

**Solução:** Ingress canary precisa do ingress principal (stable) existindo.

### Problema: Distribuição Incorreta

```bash
# Testar distribuição
for i in {1..100}; do
  curl -s http://app.example.com | grep Version
done | sort | uniq -c

# Verificar configuração do nginx
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep -A 20 "upstream.*myapp"
```

### Problema: Header Não Funciona

```bash
# Verificar se header está sendo enviado
curl -v -H "X-Canary: true" http://app.example.com 2>&1 | grep "X-Canary"

# Verificar annotation
kubectl get ingress myapp-canary -o jsonpath='{.metadata.annotations}'
```

---

## Comandos Úteis

```bash
# Criar canary com 10%
kubectl patch ingress myapp-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary":"true","nginx.ingress.kubernetes.io/canary-weight":"10"}}}'

# Aumentar para 50%
kubectl patch ingress myapp-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"50"}}}'

# Testar com header
curl -H "X-Canary: always" http://app.example.com

# Testar com cookie
curl -b "canary=always" http://app.example.com

# Ver distribuição atual
kubectl get ingress myapp-canary -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}'

# Remover canary (rollback)
kubectl delete ingress myapp-canary

# Promover canary
kubectl delete ingress myapp-stable
kubectl annotate ingress myapp-canary nginx.ingress.kubernetes.io/canary-
```

---

## Conclusão

Canary Deployment com Ingress oferece:

✅ **Risco Reduzido** - Testa com pequena porcentagem de usuários  
✅ **Rollback Rápido** - Volta para versão estável instantaneamente  
✅ **Flexibilidade** - Weight, header, cookie, regex  
✅ **Controle Granular** - Progressão gradual (10% → 25% → 50% → 100%)  
✅ **Testes A/B** - Direciona usuários específicos para canary  
✅ **Zero Downtime** - Transição suave entre versões  
✅ **Monitoramento** - Valida métricas antes de promover  

Use canary deployment para releases de baixo risco, permitindo validação em produção antes do rollout completo!
