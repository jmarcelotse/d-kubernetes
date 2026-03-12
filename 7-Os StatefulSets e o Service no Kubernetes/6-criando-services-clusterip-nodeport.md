# Criando os Nossos Services ClusterIP e NodePort

## Introdução

Neste guia, vamos criar Services do tipo **ClusterIP** (acesso interno) e **NodePort** (acesso externo) do zero, entendendo cada componente e testando na prática.

## Pré-requisitos

```bash
# Verificar cluster
kubectl cluster-info

# Verificar nodes
kubectl get nodes

# Criar namespace para testes (opcional)
kubectl create namespace services-demo
kubectl config set-context --current --namespace=services-demo
```

## Parte 1: ClusterIP Service

### O que é ClusterIP?

- **Tipo padrão** de Service
- Expõe o Service **apenas dentro do cluster**
- Recebe um **IP interno** (ClusterIP)
- Ideal para **comunicação entre serviços**

### Passo 1: Criar Deployment

Primeiro, precisamos de Pods para expor.

#### Arquivo: `nginx-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  labels:
    app: nginx
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
          name: http
```

```bash
# Aplicar Deployment
kubectl apply -f nginx-deployment.yaml

# Verificar Pods
kubectl get pods -l app=nginx

# Saída:
# NAME                            READY   STATUS    RESTARTS   AGE
# nginx-deploy-7d8f9c5b6d-abc12   1/1     Running   0          30s
# nginx-deploy-7d8f9c5b6d-def34   1/1     Running   0          30s
# nginx-deploy-7d8f9c5b6d-ghi56   1/1     Running   0          30s

# Ver IPs dos Pods (dinâmicos)
kubectl get pods -l app=nginx -o wide

# Saída:
# NAME                            READY   STATUS    IP            NODE
# nginx-deploy-7d8f9c5b6d-abc12   1/1     Running   10.244.1.5    node-1
# nginx-deploy-7d8f9c5b6d-def34   1/1     Running   10.244.1.6    node-2
# nginx-deploy-7d8f9c5b6d-ghi56   1/1     Running   10.244.1.7    node-1
```

### Passo 2: Criar ClusterIP Service (Método 1 - YAML)

#### Arquivo: `nginx-clusterip-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-clusterip
  labels:
    app: nginx
spec:
  type: ClusterIP  # Pode omitir, é o padrão
  selector:
    app: nginx  # Deve corresponder aos labels dos Pods
  ports:
  - name: http
    port: 80        # Porta do Service
    targetPort: 80  # Porta do container no Pod
    protocol: TCP
```

```bash
# Aplicar Service
kubectl apply -f nginx-clusterip-service.yaml

# Verificar Service
kubectl get svc nginx-clusterip

# Saída:
# NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# nginx-clusterip   ClusterIP   10.96.100.50    <none>        80/TCP    10s
#                                ^^^^^^^^^^^^
#                                IP estável!

# Ver detalhes completos
kubectl describe svc nginx-clusterip
```

### Saída do describe:

```
Name:              nginx-clusterip
Namespace:         default
Labels:            app=nginx
Annotations:       <none>
Selector:          app=nginx
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.96.100.50
IPs:               10.96.100.50
Port:              http  80/TCP
TargetPort:        80/TCP
Endpoints:         10.244.1.5:80,10.244.1.6:80,10.244.1.7:80  ← IPs dos Pods
Session Affinity:  None
Events:            <none>
```

### Passo 3: Criar ClusterIP Service (Método 2 - kubectl expose)

```bash
# Criar Service a partir do Deployment
kubectl expose deployment nginx-deploy --name=nginx-clusterip-2 --port=80 --target-port=80 --type=ClusterIP

# Verificar
kubectl get svc nginx-clusterip-2

# Saída:
# NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# nginx-clusterip-2   ClusterIP   10.96.150.100   <none>        80/TCP    5s
```

### Passo 4: Verificar Endpoints

Endpoints são os IPs dos Pods que o Service gerencia.

```bash
# Ver Endpoints
kubectl get endpoints nginx-clusterip

# Saída:
# NAME              ENDPOINTS                                         AGE
# nginx-clusterip   10.244.1.5:80,10.244.1.6:80,10.244.1.7:80        2m

# Ver detalhes
kubectl describe endpoints nginx-clusterip

# Saída:
# Name:         nginx-clusterip
# Namespace:    default
# Labels:       app=nginx
# Annotations:  <none>
# Subsets:
#   Addresses:          10.244.1.5,10.244.1.6,10.244.1.7
#   NotReadyAddresses:  <none>
#   Ports:
#     Name     Port  Protocol
#     ----     ----  --------
#     http     80    TCP
```

### Passo 5: Testar o ClusterIP Service

#### Teste 1: Via Pod Temporário

```bash
# Criar Pod temporário
kubectl run test --image=busybox --restart=Never -it --rm -- sh

# Dentro do Pod, testar acesso via IP
wget -qO- http://10.96.100.50

# Saída: HTML do nginx

# Testar acesso via DNS (nome do Service)
wget -qO- http://nginx-clusterip

# Saída: HTML do nginx

# Testar DNS completo
wget -qO- http://nginx-clusterip.default.svc.cluster.local

# Testar resolução DNS
nslookup nginx-clusterip

# Saída:
# Server:    10.96.0.10
# Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
#
# Name:      nginx-clusterip
# Address 1: 10.96.100.50 nginx-clusterip.default.svc.cluster.local

# Sair
exit
```

#### Teste 2: Via curl em Loop (Load Balancing)

```bash
# Criar Pod com curl
kubectl run curl --image=curlimages/curl --restart=Never -it --rm -- sh

# Fazer múltiplas requisições
for i in $(seq 1 10); do
  curl -s http://nginx-clusterip | grep -o "nginx-deploy-[a-z0-9-]*" || echo "Request $i"
done

# As requisições são distribuídas entre os 3 Pods!
```

#### Teste 3: Port-forward para Teste Local

```bash
# Fazer port-forward do Service para sua máquina local
kubectl port-forward svc/nginx-clusterip 8080:80

# Em outro terminal, acessar
curl http://localhost:8080

# Saída: HTML do nginx

# Ou abrir no navegador: http://localhost:8080
```

### Passo 6: Testar Load Balancing

```bash
# Adicionar conteúdo único em cada Pod
kubectl get pods -l app=nginx -o name | while read pod; do
  kubectl exec $pod -- sh -c "echo 'Response from $pod' > /usr/share/nginx/html/index.html"
done

# Testar múltiplas requisições
kubectl run test --image=busybox --restart=Never -it --rm -- sh

# Fazer 10 requisições
for i in $(seq 1 10); do
  wget -qO- http://nginx-clusterip
done

# Saída (distribuída entre os Pods):
# Response from nginx-deploy-7d8f9c5b6d-abc12
# Response from nginx-deploy-7d8f9c5b6d-def34
# Response from nginx-deploy-7d8f9c5b6d-ghi56
# Response from nginx-deploy-7d8f9c5b6d-abc12
# ...
```

## Fluxo ClusterIP Service

```
┌──────────────────────────────────────────────────────────────┐
│  kubectl apply -f nginx-clusterip-service.yaml               │
└──────────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  Service criado                    │
        │  Nome: nginx-clusterip             │
        │  ClusterIP: 10.96.100.50           │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  Kubernetes busca Pods com         │
        │  label "app=nginx"                 │
        └────────────────────────────────────┘
                         │
            ┌────────────┼────────────┐
            │            │            │
            ▼            ▼            ▼
        ┌───────┐    ┌───────┐    ┌───────┐
        │Pod 1  │    │Pod 2  │    │Pod 3  │
        │.1.5:80│    │.1.6:80│    │.1.7:80│
        └───────┘    └───────┘    └───────┘
            │            │            │
            └────────────┼────────────┘
                         ▼
        ┌────────────────────────────────────┐
        │  Endpoints criados                 │
        │  10.244.1.5:80                     │
        │  10.244.1.6:80                     │
        │  10.244.1.7:80                     │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  DNS criado                        │
        │  nginx-clusterip → 10.96.100.50    │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  kube-proxy configura iptables     │
        │  para load balancing               │
        └────────────────────────────────────┘
```

## Parte 2: NodePort Service

### O que é NodePort?

- Expõe o Service **externamente**
- Abre uma **porta em todos os Nodes** (30000-32767)
- Acesso via `<NodeIP>:<NodePort>`
- Ideal para **desenvolvimento e testes**

### Passo 1: Criar NodePort Service (Método 1 - YAML)

#### Arquivo: `nginx-nodeport-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
  labels:
    app: nginx
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - name: http
    port: 80        # Porta do Service (ClusterIP)
    targetPort: 80  # Porta do container no Pod
    nodePort: 30080 # Porta no Node (opcional, auto se omitido)
    protocol: TCP
```

**Observações:**
- `nodePort` é opcional (Kubernetes escolhe automaticamente entre 30000-32767)
- Se especificar, deve estar no range 30000-32767
- A porta é aberta em **todos os Nodes**

```bash
# Aplicar Service
kubectl apply -f nginx-nodeport-service.yaml

# Verificar Service
kubectl get svc nginx-nodeport

# Saída:
# NAME             TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx-nodeport   NodePort   10.96.200.100   <none>        80:30080/TCP   10s
#                                                               ^^^^^
#                                                            NodePort!

# Ver detalhes
kubectl describe svc nginx-nodeport
```

### Saída do describe:

```
Name:                     nginx-nodeport
Namespace:                default
Labels:                   app=nginx
Annotations:              <none>
Selector:                 app=nginx
Type:                     NodePort
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.200.100
IPs:                      10.96.200.100
Port:                     http  80/TCP
TargetPort:               80/TCP
NodePort:                 http  30080/TCP  ← Porta no Node
Endpoints:                10.244.1.5:80,10.244.1.6:80,10.244.1.7:80
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

### Passo 2: Criar NodePort Service (Método 2 - kubectl expose)

```bash
# Criar NodePort Service
kubectl expose deployment nginx-deploy --name=nginx-nodeport-2 --port=80 --target-port=80 --type=NodePort

# Verificar
kubectl get svc nginx-nodeport-2

# Saída:
# NAME               TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx-nodeport-2   NodePort   10.96.250.50    <none>        80:31234/TCP   5s
#                                                                 ^^^^^
#                                                              Auto-gerado!
```

### Passo 3: Obter IP dos Nodes

```bash
# Ver IPs dos Nodes
kubectl get nodes -o wide

# Saída:
# NAME     STATUS   ROLES           INTERNAL-IP    EXTERNAL-IP
# node-1   Ready    control-plane   192.168.1.10   <none>
# node-2   Ready    worker          192.168.1.11   <none>
# node-3   Ready    worker          192.168.1.12   <none>

# Ou apenas os IPs
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# Saída:
# 192.168.1.10 192.168.1.11 192.168.1.12
```

### Passo 4: Testar NodePort Service

#### Teste 1: De Dentro do Cluster

```bash
# Acessar via ClusterIP (funciona normalmente)
kubectl run test --image=busybox --restart=Never -it --rm -- wget -qO- http://nginx-nodeport

# Acessar via NodePort de dentro do cluster
kubectl run test --image=busybox --restart=Never -it --rm -- wget -qO- http://192.168.1.10:30080
```

#### Teste 2: De Fora do Cluster

```bash
# Acessar de fora do cluster (sua máquina)
curl http://192.168.1.10:30080
curl http://192.168.1.11:30080
curl http://192.168.1.12:30080

# Todos funcionam! A porta está aberta em todos os Nodes

# Ou no navegador:
# http://192.168.1.10:30080
```

#### Teste 3: Com kind (Kubernetes in Docker)

Se estiver usando kind, precisa mapear a porta:

```bash
# Criar cluster kind com port mapping
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
EOF

# Agora pode acessar
curl http://localhost:30080
```

#### Teste 4: Com minikube

```bash
# Obter URL do Service
minikube service nginx-nodeport --url

# Saída:
# http://192.168.49.2:30080

# Acessar
curl http://192.168.49.2:30080

# Ou abrir no navegador
minikube service nginx-nodeport
```

### Passo 5: NodePort sem Especificar Porta

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport-auto
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    # nodePort omitido - será auto-gerado
```

```bash
# Aplicar
kubectl apply -f nginx-nodeport-auto.yaml

# Ver porta gerada
kubectl get svc nginx-nodeport-auto

# Saída:
# NAME                  TYPE       CLUSTER-IP      PORT(S)        AGE
# nginx-nodeport-auto   NodePort   10.96.180.50    80:31567/TCP   5s
#                                                      ^^^^^
#                                                   Auto-gerado!
```

## Fluxo NodePort Service

```
┌──────────────────────────────────────────────────────────────┐
│  kubectl apply -f nginx-nodeport-service.yaml                │
└──────────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  Service criado                    │
        │  Nome: nginx-nodeport              │
        │  ClusterIP: 10.96.200.100          │
        │  NodePort: 30080                   │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  kube-proxy abre porta 30080       │
        │  em TODOS os Nodes                 │
        └────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
    ┌────────┐      ┌────────┐      ┌────────┐
    │ Node 1 │      │ Node 2 │      │ Node 3 │
    │:30080  │      │:30080  │      │:30080  │
    └────────┘      └────────┘      └────────┘
        │                │                │
        └────────────────┼────────────────┘
                         ▼
        ┌────────────────────────────────────┐
        │  Tráfego roteado para ClusterIP    │
        │  10.96.200.100:80                  │
        └────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
    ┌───────┐        ┌───────┐        ┌───────┐
    │ Pod 1 │        │ Pod 2 │        │ Pod 3 │
    │:80    │        │:80    │        │:80    │
    └───────┘        └───────┘        └───────┘

Acesso Externo:
http://192.168.1.10:30080 ─┐
http://192.168.1.11:30080 ─┼─→ Qualquer Node → ClusterIP → Pods
http://192.168.1.12:30080 ─┘
```

## Comparação: ClusterIP vs NodePort

### Arquivo Completo: `services-comparison.yaml`

```yaml
---
# Deployment
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
---
# ClusterIP Service (interno)
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
---
# NodePort Service (externo)
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
    nodePort: 30080
```

```bash
# Aplicar tudo
kubectl apply -f services-comparison.yaml

# Ver todos os Services
kubectl get svc

# Saída:
# NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx-clusterip   ClusterIP   10.96.100.50    <none>        80/TCP         1m
# nginx-nodeport    NodePort    10.96.200.100   <none>        80:30080/TCP   1m

# Testar ClusterIP (interno)
kubectl run test --image=busybox --restart=Never -it --rm -- wget -qO- http://nginx-clusterip

# Testar NodePort (externo)
curl http://<node-ip>:30080
```

## Exemplo Prático: Aplicação Multi-Tier

### Cenário: Frontend (NodePort) + Backend (ClusterIP)

```yaml
---
# Backend Deployment
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
        image: hashicorp/http-echo
        args:
        - "-text=Backend Response"
        ports:
        - containerPort: 5678
---
# Backend Service (ClusterIP - interno)
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 5678
---
# Frontend Deployment
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
        image: nginx:1.21
        ports:
        - containerPort: 80
---
# Frontend Service (NodePort - externo)
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30090
```

```bash
# Aplicar
kubectl apply -f multi-tier-app.yaml

# Verificar
kubectl get all

# Frontend acessível externamente
curl http://<node-ip>:30090

# Backend acessível apenas internamente
kubectl run test --image=busybox --restart=Never -it --rm -- wget -qO- http://backend-service
```

## Comandos Úteis

```bash
# Criar ClusterIP Service
kubectl expose deployment <nome> --port=80 --type=ClusterIP

# Criar NodePort Service
kubectl expose deployment <nome> --port=80 --type=NodePort

# Criar NodePort com porta específica
kubectl expose deployment <nome> --port=80 --type=NodePort --node-port=30080

# Ver Services
kubectl get svc
kubectl get services

# Ver detalhes
kubectl describe svc <nome>

# Ver Endpoints
kubectl get endpoints <nome>

# Editar Service
kubectl edit svc <nome>

# Mudar tipo de Service
kubectl patch svc <nome> -p '{"spec":{"type":"NodePort"}}'

# Deletar Service
kubectl delete svc <nome>

# Port-forward (teste local)
kubectl port-forward svc/<nome> 8080:80

# Ver IPs dos Nodes
kubectl get nodes -o wide

# Testar de dentro do cluster
kubectl run test --image=busybox --restart=Never -it --rm -- wget -qO- http://<service-name>
```

## Troubleshooting

### ClusterIP não responde:

```bash
# Verificar Endpoints
kubectl get endpoints <service-name>

# Se vazio, verificar labels
kubectl get svc <service-name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels

# Verificar Pods estão Running
kubectl get pods -l app=<label>
```

### NodePort não acessível:

```bash
# Verificar porta está aberta
kubectl get svc <service-name>

# Verificar firewall do Node
# (no Node)
sudo iptables -L -n | grep 30080

# Verificar kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Ver logs do kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

### DNS não resolve:

```bash
# Testar DNS do cluster
kubectl run test --image=busybox --restart=Never -it --rm -- nslookup kubernetes.default

# Verificar CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

## Boas Práticas

1. **Use ClusterIP** para comunicação interna entre serviços
2. **Use NodePort** apenas para desenvolvimento/testes
3. **Em produção**, use LoadBalancer ou Ingress em vez de NodePort
4. **Nomeie as portas** para melhor documentação
5. **Use labels consistentes** entre Deployments e Services
6. **Configure readiness probes** para evitar tráfego para Pods não prontos
7. **Documente** as portas NodePort usadas
8. **Use ranges altos** (31000+) para NodePort para evitar conflitos
9. **Monitore** os Endpoints regularmente
10. **Teste** sempre após criar Services

## Resumo

### ClusterIP:
```bash
# Criar
kubectl expose deployment nginx --port=80 --type=ClusterIP

# Acessar (interno)
http://nginx-service
```

**Uso:** Comunicação interna entre serviços

### NodePort:
```bash
# Criar
kubectl expose deployment nginx --port=80 --type=NodePort --node-port=30080

# Acessar (externo)
http://<node-ip>:30080
```

**Uso:** Acesso externo em desenvolvimento/testes

| Característica | ClusterIP | NodePort |
|----------------|-----------|----------|
| **Acesso** | Interno | Externo |
| **IP** | ClusterIP | ClusterIP + NodePort |
| **Porta** | Qualquer | 30000-32767 |
| **Uso** | Produção (interno) | Dev/Teste |
| **DNS** | Sim | Sim |
| **Load Balancing** | Sim | Sim |
