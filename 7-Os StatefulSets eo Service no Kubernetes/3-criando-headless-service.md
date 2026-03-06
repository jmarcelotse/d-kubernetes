# Criando o Nosso Headless Service

## O que é um Headless Service?

Um **Headless Service** é um Service do Kubernetes sem ClusterIP (`clusterIP: None`). Em vez de fazer load balancing, ele retorna os endereços IP de **todos os Pods** diretamente e cria **entradas DNS individuais** para cada Pod.

## Diferença: Service Normal vs Headless Service

### Service Normal (ClusterIP)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-normal
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: nginx
```

**Comportamento:**
- Recebe um ClusterIP (ex: 10.96.100.50)
- Faz load balancing entre os Pods
- DNS retorna apenas o IP do Service
- Cliente não sabe qual Pod está respondendo

### Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None  # ← Isso torna o Service "headless"
  ports:
  - port: 80
  selector:
    app: nginx
```

**Comportamento:**
- Não recebe ClusterIP (None)
- Não faz load balancing
- DNS retorna IPs de **todos os Pods**
- Cada Pod tem seu próprio DNS

## Comparação Visual

```
┌─────────────────────────────────────────────────────────────┐
│                    Service Normal                            │
└─────────────────────────────────────────────────────────────┘
                              │
                    DNS: nginx-normal
                    IP: 10.96.100.50
                              │
                    ┌─────────┴─────────┐
                    │  Load Balancing   │
                    └─────────┬─────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
        ┌───────┐         ┌───────┐         ┌───────┐
        │ Pod 1 │         │ Pod 2 │         │ Pod 3 │
        │10.1.1 │         │10.1.2 │         │10.1.3 │
        └───────┘         └───────┘         └───────┘

┌─────────────────────────────────────────────────────────────┐
│                   Headless Service                           │
└─────────────────────────────────────────────────────────────┘
                              │
                    DNS: nginx-headless
                    IP: None
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
        ┌───────┐         ┌───────┐         ┌───────┐
        │ Pod 1 │         │ Pod 2 │         │ Pod 3 │
        │10.1.1 │         │10.1.2 │         │10.1.3 │
        └───────┘         └───────┘         └───────┘
            │                 │                 │
    pod-1.nginx-hs    pod-2.nginx-hs    pod-3.nginx-hs
```

## Quando Usar Headless Service?

✅ **Use Headless Service quando:**
- Trabalhar com **StatefulSets**
- Precisar de **DNS individual** para cada Pod
- Quiser **controlar** qual Pod acessar
- Implementar **descoberta de serviço** customizada
- Trabalhar com **bancos de dados** (master/slave)
- Precisar de **comunicação peer-to-peer**

❌ **NÃO use Headless Service quando:**
- Precisar de load balancing automático
- Trabalhar com aplicações stateless
- Não precisar de identidade individual dos Pods

## Exemplo Prático 1: Headless Service Básico

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

### Passo 2: Criar Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None  # ← Headless
  ports:
  - port: 80
    name: web
  selector:
    app: nginx
```

### Aplicando:

```bash
# Criar Deployment
kubectl apply -f nginx-deployment.yaml

# Criar Headless Service
kubectl apply -f nginx-headless-service.yaml

# Verificar Service
kubectl get svc nginx-headless

# Saída:
# NAME             TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# nginx-headless   ClusterIP   None         <none>        80/TCP    10s
#                              ^^^^
#                              Sem IP!

# Ver detalhes
kubectl describe svc nginx-headless

# Saída importante:
# Name:              nginx-headless
# Namespace:         default
# Labels:            <none>
# Annotations:       <none>
# Selector:          app=nginx
# Type:              ClusterIP
# IP Family Policy:  SingleStack
# IP Families:       IPv4
# IP:                None          ← Headless!
# IPs:               None
# Port:              web  80/TCP
# TargetPort:        80/TCP
# Endpoints:         10.244.1.5:80,10.244.1.6:80,10.244.1.7:80  ← IPs dos Pods
```

### Passo 3: Testar DNS

```bash
# Criar Pod temporário para testes
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Dentro do Pod, testar DNS do Headless Service
nslookup nginx-headless

# Saída:
# Server:    10.96.0.10
# Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
#
# Name:      nginx-headless
# Address 1: 10.244.1.5 10-244-1-5.nginx-headless.default.svc.cluster.local
# Address 2: 10.244.1.6 10-244-1-6.nginx-headless.default.svc.cluster.local
# Address 3: 10.244.1.7 10-244-1-7.nginx-headless.default.svc.cluster.local
#
# ✅ Retorna IPs de TODOS os Pods!

# Comparar com Service normal (se existir)
nslookup nginx-normal

# Saída:
# Name:      nginx-normal
# Address 1: 10.96.100.50 nginx-normal.default.svc.cluster.local
#
# ✅ Retorna apenas o IP do Service
```

## Exemplo Prático 2: Headless Service com StatefulSet

Este é o uso mais comum de Headless Service.

### Arquivo Completo: `statefulset-headless.yaml`

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: web-headless
  labels:
    app: web
spec:
  ports:
  - port: 80
    name: http
  clusterIP: None
  selector:
    app: web
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "web-headless"  # ← Referência ao Headless Service
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: http
```

### Aplicando e Testando:

```bash
# Aplicar
kubectl apply -f statefulset-headless.yaml

# Verificar Pods (nomes ordenados)
kubectl get pods -l app=web

# Saída:
# NAME    READY   STATUS    RESTARTS   AGE
# web-0   1/1     Running   0          30s
# web-1   1/1     Running   0          28s
# web-2   1/1     Running   0          26s

# Verificar Service
kubectl get svc web-headless

# Testar DNS individual de cada Pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# DNS de cada Pod individual
nslookup web-0.web-headless
nslookup web-1.web-headless
nslookup web-2.web-headless

# Saída para web-0:
# Name:      web-0.web-headless
# Address 1: 10.244.1.10 web-0.web-headless.default.svc.cluster.local

# DNS completo (FQDN)
nslookup web-0.web-headless.default.svc.cluster.local

# Testar conectividade
wget -qO- http://web-0.web-headless
wget -qO- http://web-1.web-headless
wget -qO- http://web-2.web-headless
```

## Fluxo de Resolução DNS

```
┌──────────────────────────────────────────────────────────────┐
│  Cliente faz: nslookup web-headless                          │
└──────────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │       CoreDNS / kube-dns           │
        │   Procura Service "web-headless"   │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Service é Headless?              │
        │   clusterIP: None                  │
        └────────────────────────────────────┘
                         │
                    ┌────┴────┐
                    │   SIM   │
                    └────┬────┘
                         ▼
        ┌────────────────────────────────────┐
        │   Busca Endpoints do Service       │
        │   (IPs dos Pods)                   │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Retorna TODOS os IPs dos Pods    │
        │   - 10.244.1.10 (web-0)            │
        │   - 10.244.1.11 (web-1)            │
        │   - 10.244.1.12 (web-2)            │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Cliente recebe lista de IPs      │
        │   e escolhe qual usar              │
        └────────────────────────────────────┘
```

## Exemplo Prático 3: DNS Individual dos Pods

Com StatefulSet + Headless Service, cada Pod tem DNS único.

### Formato do DNS:

```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

### Exemplos:

```bash
# Pod web-0 no namespace default
web-0.web-headless.default.svc.cluster.local

# Pod web-1 no namespace default
web-1.web-headless.default.svc.cluster.local

# Pod mysql-0 no namespace production
mysql-0.mysql-svc.production.svc.cluster.local
```

### Testando:

```bash
# Criar StatefulSet
kubectl apply -f statefulset-headless.yaml

# Testar DNS completo
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Testar diferentes formatos
nslookup web-0.web-headless
nslookup web-0.web-headless.default
nslookup web-0.web-headless.default.svc
nslookup web-0.web-headless.default.svc.cluster.local

# Todos funcionam!

# Ping entre Pods
ping web-0.web-headless
ping web-1.web-headless

# Curl entre Pods
wget -qO- http://web-0.web-headless
wget -qO- http://web-1.web-headless
```

## Exemplo Prático 4: Banco de Dados com Master/Slave

Caso de uso real: MySQL com replicação.

### Arquivo: `mysql-headless.yaml`

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  ports:
  - port: 3306
    name: mysql
  clusterIP: None
  selector:
    app: mysql
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: "mysql"
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "senha123"
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```

### Uso Prático:

```bash
# Aplicar
kubectl apply -f mysql-headless.yaml

# Aguardar Pods
kubectl get pods -w

# Conectar ao master (mysql-0)
kubectl exec -it mysql-0 -- mysql -uroot -psenha123

# Configurar replicação apontando para mysql-0.mysql
# Os slaves usam: mysql-0.mysql.default.svc.cluster.local

# Aplicação pode conectar especificamente:
# - Escrita: mysql-0.mysql (master)
# - Leitura: mysql-1.mysql, mysql-2.mysql (slaves)
```

## Exemplo Prático 5: Descoberta de Serviço

Aplicação que descobre todos os Pods dinamicamente.

### Script Python de Descoberta:

```python
import socket

def discover_pods(service_name):
    """Descobre todos os Pods de um Headless Service"""
    try:
        # Resolve DNS do Headless Service
        hostname = f"{service_name}.default.svc.cluster.local"
        ips = socket.gethostbyname_ex(hostname)[2]
        
        print(f"Pods encontrados para {service_name}:")
        for ip in ips:
            print(f"  - {ip}")
        
        return ips
    except socket.gaierror:
        print(f"Service {service_name} não encontrado")
        return []

# Uso
pods = discover_pods("web-headless")
```

### Deployment com Descoberta:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-discovery
spec:
  replicas: 1
  selector:
    matchLabels:
      app: discovery
  template:
    metadata:
      labels:
        app: discovery
    spec:
      containers:
      - name: app
        image: python:3.9
        command: ["python", "-c"]
        args:
        - |
          import socket
          import time
          while True:
              try:
                  ips = socket.gethostbyname_ex("web-headless.default.svc.cluster.local")[2]
                  print(f"Pods ativos: {ips}")
              except:
                  print("Erro ao descobrir pods")
              time.sleep(10)
```

```bash
# Aplicar
kubectl apply -f app-discovery.yaml

# Ver logs
kubectl logs -f deployment/app-discovery

# Saída:
# Pods ativos: ['10.244.1.10', '10.244.1.11', '10.244.1.12']
# Pods ativos: ['10.244.1.10', '10.244.1.11', '10.244.1.12']
```

## Exemplo Prático 6: Headless Service + Service Normal

Você pode ter ambos para diferentes propósitos.

```yaml
---
# Headless Service para acesso individual
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None
  ports:
  - port: 80
  selector:
    app: web
---
# Service normal para load balancing
apiVersion: v1
kind: Service
metadata:
  name: web-lb
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: web
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "web-headless"
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```

### Uso:

```bash
# Aplicar
kubectl apply -f web-both-services.yaml

# Verificar Services
kubectl get svc

# Saída:
# NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# web-headless   ClusterIP   None            <none>        80/TCP    30s
# web-lb         ClusterIP   10.96.100.50    <none>        80/TCP    30s

# Usar web-lb para load balancing
curl http://web-lb

# Usar web-headless para acesso individual
curl http://web-0.web-headless
curl http://web-1.web-headless
```

## Comandos Úteis

```bash
# Criar Headless Service
kubectl apply -f headless-service.yaml

# Verificar Service
kubectl get svc <nome>

# Ver se é Headless (ClusterIP = None)
kubectl get svc <nome> -o jsonpath='{.spec.clusterIP}'

# Ver Endpoints (IPs dos Pods)
kubectl get endpoints <nome>

# Testar DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>

# Testar DNS de Pod específico (StatefulSet)
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <pod-name>.<service-name>

# Ver detalhes
kubectl describe svc <nome>

# Deletar
kubectl delete svc <nome>
```

## Troubleshooting

### DNS não resolve:

```bash
# Verificar CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Testar DNS do cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Verificar Service existe
kubectl get svc <nome>

# Verificar Endpoints
kubectl get endpoints <nome>
```

### Endpoints vazios:

```bash
# Verificar se há Pods com o label correto
kubectl get pods -l app=<label>

# Verificar selector do Service
kubectl get svc <nome> -o jsonpath='{.spec.selector}'

# Verificar labels dos Pods
kubectl get pods --show-labels
```

### DNS de Pod não funciona (StatefulSet):

```bash
# Verificar se StatefulSet usa o Headless Service
kubectl get statefulset <nome> -o jsonpath='{.spec.serviceName}'

# Verificar se Pods estão Running
kubectl get pods -l app=<label>

# Testar DNS do Service primeiro
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>
```

## Resumo

**Headless Service** é essencial para:

✅ StatefulSets com identidade de Pod
✅ Acesso direto a Pods específicos
✅ Descoberta de serviço customizada
✅ Bancos de dados com master/slave
✅ Comunicação peer-to-peer

**Características principais:**
- `clusterIP: None`
- Retorna IPs de todos os Pods
- Cria DNS individual para cada Pod (com StatefulSet)
- Não faz load balancing
- Permite controle fino de qual Pod acessar

**Formato DNS com StatefulSet:**
```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```
