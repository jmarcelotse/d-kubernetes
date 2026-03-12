# O que são os Services?

## Conceito

**Service** é um objeto do Kubernetes que expõe um conjunto de Pods como um serviço de rede. Ele fornece um **endereço IP estável** e **DNS** para acessar Pods que podem ser criados, destruídos e recriados dinamicamente.

## Por que Precisamos de Services?

### Problema: Pods são Efêmeros

```
Pod nginx-abc123 (IP: 10.244.1.5)  ← Pod morre
                ↓
Pod nginx-xyz789 (IP: 10.244.1.8)  ← Novo Pod, novo IP!
```

**Problemas:**
- Pods têm IPs dinâmicos que mudam
- Pods podem ser recriados a qualquer momento
- Múltiplos Pods precisam de load balancing
- Clientes não sabem qual Pod acessar

### Solução: Services

```
Cliente → Service (IP fixo: 10.96.100.50) → Load Balancing → Pods
                                                    ↓
                                    ┌───────────────┼───────────────┐
                                    │               │               │
                                Pod 1           Pod 2           Pod 3
                              (10.244.1.5)   (10.244.1.6)   (10.244.1.7)
```

**Benefícios:**
- ✅ IP e DNS estáveis
- ✅ Load balancing automático
- ✅ Descoberta de serviço
- ✅ Abstração dos Pods

## Componentes de um Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service        # Nome do Service
spec:
  type: ClusterIP            # Tipo do Service
  selector:                  # Seleciona Pods
    app: nginx
  ports:
  - port: 80                 # Porta do Service
    targetPort: 80           # Porta do Pod
    protocol: TCP
```

### Elementos Principais:

1. **selector**: Define quais Pods o Service gerencia (por labels)
2. **port**: Porta exposta pelo Service
3. **targetPort**: Porta do container no Pod
4. **type**: Tipo de exposição do Service

## Tipos de Services

### 1. ClusterIP (Padrão)

Expõe o Service **apenas dentro do cluster**.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-clusterip
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

**Características:**
- IP interno do cluster
- Acessível apenas de dentro do cluster
- Tipo padrão se não especificar

### 2. NodePort

Expõe o Service em uma **porta de cada Node**.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Porta no Node (30000-32767)
```

**Características:**
- Acessível de fora do cluster
- Usa porta alta (30000-32767)
- Acesso via `<NodeIP>:<NodePort>`

### 3. LoadBalancer

Cria um **load balancer externo** (cloud provider).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

**Características:**
- Cria load balancer externo (AWS ELB, GCP LB, etc)
- IP público automático
- Ideal para produção em cloud

### 4. ExternalName

Mapeia o Service para um **nome DNS externo**.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: database.example.com
```

**Características:**
- Não tem selector
- Não tem ClusterIP
- Retorna CNAME para DNS externo

## Fluxo de Funcionamento

```
┌──────────────────────────────────────────────────────────────┐
│                    Como um Service Funciona                   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌────────────────────────────────────┐
        │  Cliente faz requisição            │
        │  http://nginx-service              │
        └────────────────────────────────────┘
                              │
                              ▼
        ┌────────────────────────────────────┐
        │  CoreDNS resolve                   │
        │  nginx-service → 10.96.100.50      │
        └────────────────────────────────────┘
                              │
                              ▼
        ┌────────────────────────────────────┐
        │  Service (10.96.100.50:80)         │
        │  Recebe requisição                 │
        └────────────────────────────────────┘
                              │
                              ▼
        ┌────────────────────────────────────┐
        │  kube-proxy (iptables/IPVS)        │
        │  Faz load balancing                │
        └────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
        ┌───────┐         ┌───────┐         ┌───────┐
        │ Pod 1 │         │ Pod 2 │         │ Pod 3 │
        │:80    │         │:80    │         │:80    │
        └───────┘         └───────┘         └───────┘
```

## Exemplo Prático 1: ClusterIP Service

### Passo 1: Criar Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  replicas: 3
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
        image: nginx:1.21
        ports:
        - containerPort: 80
```

### Passo 2: Criar ClusterIP Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx  # Deve corresponder aos labels dos Pods
  ports:
  - port: 80
    targetPort: 80
```

### Aplicando:

```bash
# Criar Deployment
kubectl apply -f nginx-deployment.yaml

# Criar Service
kubectl apply -f nginx-service.yaml

# Verificar Service
kubectl get svc nginx-service

# Saída:
# NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# nginx-service   ClusterIP   10.96.100.50    <none>        80/TCP    10s

# Ver detalhes
kubectl describe svc nginx-service

# Saída importante:
# Name:              nginx-service
# Namespace:         default
# Labels:            <none>
# Selector:          app=nginx
# Type:              ClusterIP
# IP Family Policy:  SingleStack
# IP:                10.96.100.50
# Port:              <unset>  80/TCP
# TargetPort:        80/TCP
# Endpoints:         10.244.1.5:80,10.244.1.6:80,10.244.1.7:80  ← IPs dos Pods

# Ver Endpoints
kubectl get endpoints nginx-service

# Saída:
# NAME            ENDPOINTS                                         AGE
# nginx-service   10.244.1.5:80,10.244.1.6:80,10.244.1.7:80        1m
```

### Testando o Service:

```bash
# Criar Pod temporário para teste
kubectl run test --image=busybox --restart=Never -it --rm -- sh

# Dentro do Pod, testar acesso
wget -qO- http://nginx-service

# Saída: HTML do nginx

# Testar DNS
nslookup nginx-service

# Saída:
# Server:    10.96.0.10
# Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
#
# Name:      nginx-service
# Address 1: 10.96.100.50 nginx-service.default.svc.cluster.local

# Testar múltiplas requisições (load balancing)
for i in $(seq 1 10); do wget -qO- http://nginx-service | grep -o "nginx-deploy-[a-z0-9-]*"; done
```

## Exemplo Prático 2: NodePort Service

Expõe o Service externamente através de uma porta em cada Node.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80        # Porta do Service
    targetPort: 80  # Porta do Pod
    nodePort: 30080 # Porta no Node (opcional, auto se omitido)
```

```bash
# Aplicar
kubectl apply -f nginx-nodeport.yaml

# Verificar Service
kubectl get svc nginx-nodeport

# Saída:
# NAME             TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx-nodeport   NodePort   10.96.200.100   <none>        80:30080/TCP   10s
#                                                               ^^^^^
#                                                            NodePort

# Ver detalhes
kubectl describe svc nginx-nodeport

# Obter IP dos Nodes
kubectl get nodes -o wide

# Saída:
# NAME     STATUS   ROLES    INTERNAL-IP    EXTERNAL-IP
# node-1   Ready    master   192.168.1.10   <none>
# node-2   Ready    worker   192.168.1.11   <none>

# Acessar de fora do cluster
curl http://192.168.1.10:30080
curl http://192.168.1.11:30080

# Ambos funcionam! O Service está em todos os Nodes
```

## Exemplo Prático 3: LoadBalancer Service

Cria um load balancer externo (requer cloud provider).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

```bash
# Aplicar
kubectl apply -f nginx-loadbalancer.yaml

# Verificar Service
kubectl get svc nginx-lb

# Saída (em cloud provider):
# NAME       TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)        AGE
# nginx-lb   LoadBalancer   10.96.150.50    203.0.113.10      80:31234/TCP   2m
#                                           ^^^^^^^^^^^^
#                                           IP público!

# Saída (em ambiente local como kind/minikube):
# NAME       TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx-lb   LoadBalancer   10.96.150.50    <pending>     80:31234/TCP   2m
#                                           ^^^^^^^^^
#                                           Não disponível localmente

# Acessar (em cloud)
curl http://203.0.113.10

# Ver detalhes
kubectl describe svc nginx-lb
```

## Exemplo Prático 4: ExternalName Service

Mapeia para um serviço externo.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: api.example.com
```

```bash
# Aplicar
kubectl apply -f external-service.yaml

# Verificar
kubectl get svc external-api

# Saída:
# NAME           TYPE           CLUSTER-IP   EXTERNAL-IP        PORT(S)   AGE
# external-api   ExternalName   <none>       api.example.com    <none>    10s

# Testar DNS
kubectl run test --image=busybox --restart=Never -it --rm -- nslookup external-api

# Saída:
# Name:      external-api
# Address 1: 93.184.216.34 api.example.com  ← Retorna CNAME

# Usar no código da aplicação
# http://external-api → resolve para api.example.com
```

## Exemplo Prático 5: Service com Múltiplas Portas

```yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-port-service
spec:
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
  - name: metrics
    port: 9090
    targetPort: 9090
```

```bash
# Aplicar
kubectl apply -f multi-port-service.yaml

# Verificar
kubectl get svc multi-port-service

# Acessar diferentes portas
kubectl run test --image=busybox --restart=Never -it --rm -- sh

# HTTP
wget -qO- http://multi-port-service:80

# HTTPS
wget -qO- https://multi-port-service:443

# Metrics
wget -qO- http://multi-port-service:9090/metrics
```

## Exemplo Prático 6: Service sem Selector (Manual Endpoints)

Para apontar para serviços externos ou IPs específicos.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  ports:
  - port: 3306
    targetPort: 3306
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db  # Mesmo nome do Service
subsets:
- addresses:
  - ip: 192.168.1.100  # IP do banco externo
  ports:
  - port: 3306
```

```bash
# Aplicar
kubectl apply -f external-db-service.yaml

# Verificar
kubectl get svc external-db
kubectl get endpoints external-db

# Saída:
# NAME          ENDPOINTS            AGE
# external-db   192.168.1.100:3306   10s

# Usar no código
# mysql -h external-db -P 3306
```

## Descoberta de Serviço (Service Discovery)

### Via DNS (Recomendado)

```bash
# Formato DNS:
# <service-name>.<namespace>.svc.cluster.local

# Exemplos:
nginx-service.default.svc.cluster.local
nginx-service.default.svc
nginx-service.default
nginx-service  # Se estiver no mesmo namespace
```

### Via Variáveis de Ambiente

Quando um Pod é criado, o Kubernetes injeta variáveis de ambiente para cada Service.

```bash
# Criar Service
kubectl apply -f nginx-service.yaml

# Criar Pod
kubectl run test --image=busybox --command -- sleep 3600

# Ver variáveis de ambiente
kubectl exec test -- env | grep NGINX_SERVICE

# Saída:
# NGINX_SERVICE_SERVICE_HOST=10.96.100.50
# NGINX_SERVICE_SERVICE_PORT=80
# NGINX_SERVICE_PORT=tcp://10.96.100.50:80
# NGINX_SERVICE_PORT_80_TCP=tcp://10.96.100.50:80
# NGINX_SERVICE_PORT_80_TCP_PROTO=tcp
# NGINX_SERVICE_PORT_80_TCP_PORT=80
# NGINX_SERVICE_PORT_80_TCP_ADDR=10.96.100.50
```

## Fluxo de Seleção de Pods

```
┌──────────────────────────────────────────────────────────────┐
│  Service: nginx-service                                       │
│  Selector: app=nginx                                          │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌────────────────────────────────────┐
        │  Kubernetes busca Pods com         │
        │  label "app=nginx"                 │
        └────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
        ┌───────┐         ┌───────┐         ┌───────┐
        │ Pod 1 │         │ Pod 2 │         │ Pod 3 │
        │app=   │         │app=   │         │app=   │
        │nginx  │         │nginx  │         │nginx  │
        └───────┘         └───────┘         └───────┘
            │                 │                 │
            └─────────────────┼─────────────────┘
                              ▼
        ┌────────────────────────────────────┐
        │  Endpoints criados automaticamente │
        │  10.244.1.5:80                     │
        │  10.244.1.6:80                     │
        │  10.244.1.7:80                     │
        └────────────────────────────────────┘
```

## Comparação dos Tipos de Services

| Tipo | Acesso | Uso | IP Externo | Porta |
|------|--------|-----|------------|-------|
| **ClusterIP** | Interno | Comunicação interna | Não | Qualquer |
| **NodePort** | Externo | Desenvolvimento/teste | Não | 30000-32767 |
| **LoadBalancer** | Externo | Produção (cloud) | Sim | Qualquer |
| **ExternalName** | Externo | Proxy para DNS externo | Não | N/A |

## Comandos Úteis

```bash
# Criar Service
kubectl apply -f service.yaml

# Criar Service via CLI (expose)
kubectl expose deployment nginx-deploy --port=80 --type=ClusterIP

# Listar Services
kubectl get svc
kubectl get services

# Ver detalhes
kubectl describe svc <nome>

# Ver Endpoints
kubectl get endpoints <nome>

# Ver Service em YAML
kubectl get svc <nome> -o yaml

# Editar Service
kubectl edit svc <nome>

# Deletar Service
kubectl delete svc <nome>

# Testar Service de dentro do cluster
kubectl run test --image=busybox --restart=Never -it --rm -- wget -qO- http://<service-name>

# Ver logs do kube-proxy (troubleshooting)
kubectl logs -n kube-system -l k8s-app=kube-proxy

# Port-forward para testar localmente
kubectl port-forward svc/<service-name> 8080:80
# Acessa em: http://localhost:8080
```

## Exemplo Completo: Aplicação com Service

```yaml
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
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
        image: nginx:1.21
        ports:
        - containerPort: 80
---
# ClusterIP Service (interno)
apiVersion: v1
kind: Service
metadata:
  name: webapp-internal
spec:
  type: ClusterIP
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
---
# NodePort Service (externo)
apiVersion: v1
kind: Service
metadata:
  name: webapp-external
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

```bash
# Aplicar tudo
kubectl apply -f webapp-complete.yaml

# Verificar
kubectl get all

# Testar interno
kubectl run test --image=busybox --restart=Never -it --rm -- wget -qO- http://webapp-internal

# Testar externo
curl http://<node-ip>:30080
```

## Troubleshooting

### Service não responde:

```bash
# Verificar Service existe
kubectl get svc <nome>

# Verificar Endpoints
kubectl get endpoints <nome>

# Se Endpoints estiver vazio:
# 1. Verificar selector do Service
kubectl get svc <nome> -o jsonpath='{.spec.selector}'

# 2. Verificar labels dos Pods
kubectl get pods --show-labels

# 3. Verificar se Pods estão Running
kubectl get pods -l app=<label>
```

### DNS não resolve:

```bash
# Testar DNS do cluster
kubectl run test --image=busybox --restart=Never -it --rm -- nslookup kubernetes.default

# Verificar CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Ver logs do CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### LoadBalancer fica em Pending:

```bash
# Verificar se está em cloud provider
kubectl get nodes -o wide

# Se estiver em ambiente local (kind/minikube):
# Use NodePort ou port-forward

# Se estiver em cloud:
# Verificar logs do cloud-controller-manager
kubectl logs -n kube-system -l component=cloud-controller-manager
```

## Boas Práticas

1. **Use ClusterIP** para comunicação interna
2. **Use LoadBalancer** para produção em cloud
3. **Evite NodePort** em produção (use Ingress)
4. **Nomeie as portas** em Services com múltiplas portas
5. **Use labels consistentes** entre Deployments e Services
6. **Configure readiness probes** nos Pods
7. **Use DNS** em vez de IPs ou variáveis de ambiente
8. **Documente** os Services e suas portas
9. **Monitore** os Endpoints
10. **Use Ingress** para HTTP/HTTPS em vez de múltiplos LoadBalancers

## Resumo

**Service** é essencial para:

✅ Fornecer IP e DNS estáveis para Pods
✅ Load balancing automático
✅ Descoberta de serviço
✅ Expor aplicações interna ou externamente

**Tipos principais:**
- **ClusterIP**: Acesso interno (padrão)
- **NodePort**: Acesso externo via porta do Node
- **LoadBalancer**: Acesso externo via load balancer (cloud)
- **ExternalName**: Proxy para DNS externo

**Formato DNS:**
```
<service-name>.<namespace>.svc.cluster.local
```
