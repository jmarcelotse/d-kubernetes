# Entendendo as Alternativas de Ingress e Como Resolver Problemas

## Introdução

Existem várias alternativas ao Nginx Ingress Controller e diferentes abordagens para expor aplicações no Kubernetes. Este guia explora as opções disponíveis, quando usar cada uma e como resolver problemas comuns.

## Alternativas de Exposição

### Comparação Geral

| Método | Layer | Custo | Complexidade | Uso |
|--------|-------|-------|--------------|-----|
| **ClusterIP** | L4 | Gratuito | Baixa | Interno |
| **NodePort** | L4 | Gratuito | Baixa | Dev/Test |
| **LoadBalancer** | L4 | Alto (por Service) | Baixa | Produção simples |
| **Ingress** | L7 | Médio (1 LB) | Média | Produção (HTTP/HTTPS) |
| **Gateway API** | L7 | Médio | Alta | Futuro do Ingress |
| **Service Mesh** | L7 | Médio | Alta | Microsserviços avançados |

## Alternativa 1: Service LoadBalancer

### Quando Usar

- Aplicação única ou poucas aplicações
- Não precisa de roteamento por host/path
- Protocolo não-HTTP (TCP/UDP)
- Simplicidade é prioridade

### Exemplo

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

### Prós e Contras

**Prós:**
- ✅ Simples de configurar
- ✅ Funciona com qualquer protocolo
- ✅ Sem dependências adicionais

**Contras:**
- ❌ Um LoadBalancer por Service (caro)
- ❌ Sem roteamento inteligente
- ❌ Sem SSL centralizado

## Alternativa 2: NodePort

### Quando Usar

- Ambiente de desenvolvimento
- Cluster on-premise sem LoadBalancer
- Testes locais
- Acesso direto aos nodes

### Exemplo

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-nodeport
spec:
  type: NodePort
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

### Acesso

```bash
# Via IP do Node
curl http://<node-ip>:30080

# Via qualquer Node do cluster
curl http://node1:30080
curl http://node2:30080
```

### Prós e Contras

**Prós:**
- ✅ Gratuito
- ✅ Funciona em qualquer cluster
- ✅ Simples

**Contras:**
- ❌ Portas limitadas (30000-32767)
- ❌ Precisa conhecer IP dos Nodes
- ❌ Sem balanceamento externo

## Alternativa 3: Ingress Controllers

### Opções Disponíveis

#### 1. Nginx Ingress Controller

**Mais popular e maduro**

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

**Prós:**
- ✅ Mais usado (comunidade grande)
- ✅ Bem documentado
- ✅ Performance excelente
- ✅ Muitas features

**Contras:**
- ❌ Configuração via annotations pode ser confusa
- ❌ Algumas features específicas do Nginx

#### 2. Traefik

**Moderno e fácil de usar**

```bash
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace
```

**Prós:**
- ✅ Dashboard web integrado
- ✅ Configuração mais intuitiva
- ✅ Suporte nativo a Let's Encrypt
- ✅ Métricas integradas

**Contras:**
- ❌ Menos maduro que Nginx
- ❌ Performance um pouco inferior

**Exemplo:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-ingress
spec:
  ingressClassName: traefik
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

#### 3. HAProxy Ingress

**Alta performance**

```bash
helm install haproxy-ingress haproxy-ingress/haproxy-ingress \
  --namespace haproxy-ingress \
  --create-namespace
```

**Prós:**
- ✅ Performance superior
- ✅ Configuração avançada de balanceamento
- ✅ Suporte a TCP/UDP

**Contras:**
- ❌ Menos popular
- ❌ Documentação limitada

#### 4. Kong Ingress

**API Gateway completo**

```bash
helm install kong kong/kong \
  --namespace kong \
  --create-namespace
```

**Prós:**
- ✅ API Gateway completo
- ✅ Plugins para autenticação, rate limiting, etc.
- ✅ Dashboard web

**Contras:**
- ❌ Mais complexo
- ❌ Overhead maior

#### 5. Contour (Envoy)

**Baseado em Envoy Proxy**

```bash
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
```

**Prós:**
- ✅ Baseado em Envoy (usado por Istio)
- ✅ Performance excelente
- ✅ Configuração via CRDs

**Contras:**
- ❌ Menos features que Nginx
- ❌ Comunidade menor

### Comparação de Performance

```
Requisições por segundo (benchmark):

Nginx:    ~50,000 req/s
HAProxy:  ~55,000 req/s
Traefik:  ~40,000 req/s
Kong:     ~35,000 req/s
Contour:  ~48,000 req/s
```

## Alternativa 4: Gateway API

### O Futuro do Ingress

Gateway API é o sucessor do Ingress, oferecendo mais flexibilidade e recursos.

### Exemplo

```yaml
# Gateway (substitui Ingress Controller)
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
# HTTPRoute (substitui Ingress)
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
  - name: my-gateway
  hostnames:
  - "myapp.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: myapp-service
      port: 80
```

### Vantagens sobre Ingress

- ✅ Mais expressivo (múltiplos tipos de rotas)
- ✅ Separação de responsabilidades (Gateway vs Routes)
- ✅ Suporte a TCP/UDP
- ✅ Traffic splitting nativo
- ✅ Configuração mais granular

### Status Atual

- 🟡 Beta (Kubernetes 1.26+)
- 🟡 Nem todos os controllers suportam
- 🟡 Em evolução

## Alternativa 5: Service Mesh

### Quando Usar

- Arquitetura de microsserviços complexa
- Precisa de mTLS entre serviços
- Observabilidade avançada
- Traffic management sofisticado

### Opções

#### Istio

```bash
istioctl install --set profile=demo
```

**Features:**
- mTLS automático
- Traffic management avançado
- Observabilidade completa
- Circuit breaking
- Retry policies

**Exemplo:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp.example.com
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: myapp-service
        port:
          number: 80
```

#### Linkerd

```bash
linkerd install | kubectl apply -f -
```

**Features:**
- Mais leve que Istio
- mTLS automático
- Métricas integradas
- Simples de usar

## Resolvendo Problemas Comuns

### Problema 1: Ingress não Responde (404)

#### Diagnóstico

```bash
# 1. Verificar Ingress existe
kubectl get ingress

# 2. Verificar IngressClass
kubectl get ingressclass

# 3. Verificar Service
kubectl get service <service-name>

# 4. Verificar Endpoints
kubectl get endpoints <service-name>

# 5. Ver logs do Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

#### Soluções

**Solução 1: IngressClass não definida**

```yaml
# Adicionar ingressClassName
spec:
  ingressClassName: nginx  # ✅ Adicionar isso
  rules:
  - host: myapp.example.com
```

**Solução 2: Service não existe**

```bash
# Verificar nome do Service
kubectl get service

# Corrigir nome no Ingress
backend:
  service:
    name: correct-service-name  # ✅ Nome correto
```

**Solução 3: Endpoints vazios**

```bash
# Verificar Pods estão rodando
kubectl get pods -l app=myapp

# Verificar selector do Service
kubectl get service myapp-service -o yaml | grep selector

# Verificar labels dos Pods
kubectl get pods -l app=myapp --show-labels
```

### Problema 2: SSL/TLS não Funciona

#### Diagnóstico

```bash
# 1. Verificar Secret TLS existe
kubectl get secret <tls-secret>

# 2. Verificar certificado
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# 3. Ver logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep ssl
```

#### Soluções

**Solução 1: Secret não existe**

```bash
# Criar Secret TLS
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key
```

**Solução 2: Certificado expirado**

```bash
# Verificar validade
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# Renovar certificado
```

**Solução 3: Host não corresponde**

```yaml
spec:
  tls:
  - hosts:
    - myapp.example.com  # ✅ Deve corresponder ao host nas rules
    secretName: myapp-tls
  rules:
  - host: myapp.example.com  # ✅ Mesmo host
```

### Problema 3: LoadBalancer Pending

#### Diagnóstico

```bash
# Ver status do Service
kubectl get service ingress-nginx-controller -n ingress-nginx

# Ver eventos
kubectl describe service ingress-nginx-controller -n ingress-nginx
```

#### Soluções

**Solução 1: Cluster local (Kind/Minikube)**

```bash
# Usar NodePort em vez de LoadBalancer
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=NodePort
```

**Solução 2: Instalar MetalLB (bare metal)**

```bash
# Instalar MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml

# Configurar IP pool
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
EOF
```

### Problema 4: Múltiplos Ingress Controllers

#### Cenário

Você tem Nginx e Traefik instalados e quer usar ambos.

#### Solução

```yaml
# Ingress para Nginx
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  ingressClassName: nginx  # ✅ Especificar classe
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: app1-service
            port:
              number: 80
---
# Ingress para Traefik
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-ingress
spec:
  ingressClassName: traefik  # ✅ Especificar classe
  rules:
  - host: app2.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

### Problema 5: Rate Limiting não Funciona

#### Solução

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rate-limited-ingress
  annotations:
    # Rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"
    
    # Definir zona de memória
    nginx.ingress.kubernetes.io/limit-connections: "10"
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

**Testar:**

```bash
# Fazer múltiplas requisições rápidas
for i in {1..20}; do
  curl -w "\n%{http_code}\n" http://api.example.com
done

# Deve retornar 503 após limite
```

## Matriz de Decisão

### Escolhendo a Melhor Opção

```
┌─────────────────────────────────────────────────────────┐
│ Precisa expor aplicação?                                │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
        ┌───────────────┐
        │ Apenas interno?│
        └───────┬────────┘
                │
        ┌───────┴────────┐
        │                │
       Sim              Não
        │                │
        ▼                ▼
   ClusterIP    ┌──────────────┐
                │ HTTP/HTTPS?  │
                └───────┬───────┘
                        │
                ┌───────┴────────┐
                │                │
               Sim              Não
                │                │
                ▼                ▼
        ┌──────────────┐   LoadBalancer
        │ Múltiplos    │   (TCP/UDP)
        │ Services?    │
        └───────┬──────┘
                │
        ┌───────┴────────┐
        │                │
       Sim              Não
        │                │
        ▼                ▼
     Ingress      LoadBalancer
                  (HTTP simples)
```

### Tabela de Decisão

| Cenário | Solução Recomendada |
|---------|---------------------|
| Acesso interno apenas | ClusterIP |
| Dev/Test local | NodePort |
| 1-2 aplicações HTTP | LoadBalancer |
| Múltiplas aplicações HTTP | Ingress (Nginx) |
| Precisa dashboard | Ingress (Traefik) |
| API Gateway | Kong Ingress |
| Microsserviços complexos | Service Mesh (Istio) |
| Futuro-proof | Gateway API |
| Bare metal | Ingress + MetalLB |

## Checklist de Troubleshooting

### Antes de Criar Issue

- [ ] Ingress Controller está instalado?
- [ ] IngressClass existe?
- [ ] Service existe e tem Endpoints?
- [ ] Pods estão rodando e healthy?
- [ ] DNS está configurado?
- [ ] Firewall permite tráfego?
- [ ] Logs do Ingress Controller verificados?
- [ ] Configuração do Nginx verificada?

### Comandos de Debug

```bash
# 1. Status geral
kubectl get all -n ingress-nginx
kubectl get ingress --all-namespaces

# 2. Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100

# 3. Configuração
kubectl exec -n ingress-nginx <pod> -- cat /etc/nginx/nginx.conf

# 4. Teste interno
kubectl run test --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://<service>

# 5. Eventos
kubectl get events --sort-by='.lastTimestamp' -n ingress-nginx
```

## Resumo

### Alternativas Principais

1. **ClusterIP** - Interno
2. **NodePort** - Dev/Test
3. **LoadBalancer** - Simples, caro
4. **Ingress** - Produção HTTP/HTTPS
5. **Gateway API** - Futuro
6. **Service Mesh** - Microsserviços avançados

### Ingress Controllers

- **Nginx** - Mais popular, maduro
- **Traefik** - Moderno, fácil
- **HAProxy** - Performance
- **Kong** - API Gateway
- **Contour** - Envoy-based

### Problemas Comuns

- 404 → Verificar Service/Endpoints
- SSL → Verificar Secret TLS
- Pending → NodePort ou MetalLB
- Rate limit → Annotations corretas

## Próximos Passos

- Testar **diferentes Ingress Controllers**
- Explorar **Gateway API**
- Implementar **Service Mesh** (Istio/Linkerd)
- Configurar **monitoramento** completo
- Automatizar com **GitOps** (ArgoCD/Flux)
