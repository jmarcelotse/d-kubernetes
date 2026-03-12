# Configurando o Kind para Suportar o Ingress

## Introdução

O **Kind** (Kubernetes in Docker) por padrão não expõe portas para o host, o que impede o acesso ao Ingress Controller. Para usar Ingress com Kind, é necessário criar o cluster com configuração especial que mapeia as portas 80 e 443 do host para o cluster.

## Por Que Configurar o Kind?

### Problema

- Kind roda dentro de containers Docker
- Portas do cluster não são acessíveis do host por padrão
- Ingress Controller precisa receber tráfego externo nas portas 80/443

### Solução

- Criar cluster Kind com mapeamento de portas
- Configurar extraPortMappings
- Adicionar labels específicas para o Ingress Controller

## Fluxo de Funcionamento

```
1. Criar cluster Kind com port mapping
   ↓
2. Portas 80/443 do host → Container do Kind
   ↓
3. Instalar Nginx Ingress Controller
   ↓
4. Ingress Controller escuta nas portas mapeadas
   ↓
5. Criar Ingress Resources
   ↓
6. Acessar via localhost:80 ou localhost:443
```

## Pré-requisitos

### Instalar Kind

```bash
# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# macOS
brew install kind

# Verificar instalação
kind version
```

**Saída esperada:**
```
kind v0.22.0 go1.21.0 linux/amd64
```

### Instalar kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verificar
kubectl version --client
```

## Método 1: Cluster Kind com Ingress (Configuração Básica)

### 1. Criar Arquivo de Configuração

```yaml
# kind-ingress-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

**Explicação:**
- **node-labels:** Label para o Ingress Controller usar esse node
- **extraPortMappings:** Mapeia portas 80/443 do host para o container
- **containerPort:** Porta dentro do container Kind
- **hostPort:** Porta no host (seu computador)

### 2. Criar Cluster

```bash
kind create cluster --name ingress-cluster --config kind-ingress-config.yaml
```

**Saída esperada:**
```
Creating cluster "ingress-cluster" ...
 ✓ Ensuring node image (kindest/node:v1.29.2) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-ingress-cluster"
You can now use your cluster with:

kubectl cluster-info --context kind-ingress-cluster
```

### 3. Verificar Cluster

```bash
# Ver nodes
kubectl get nodes

# Ver contexto
kubectl config current-context

# Ver informações do cluster
kubectl cluster-info
```

**Saída esperada:**
```
NAME                            STATUS   ROLES           AGE   VERSION
ingress-cluster-control-plane   Ready    control-plane   1m    v1.29.2

kind-ingress-cluster

Kubernetes control plane is running at https://127.0.0.1:xxxxx
```

### 4. Instalar Nginx Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

**Saída esperada:**
```
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
...
deployment.apps/ingress-nginx-controller created
```

### 5. Aguardar Ingress Controller Ficar Pronto

```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

**Saída esperada:**
```
pod/ingress-nginx-controller-xxxxx condition met
```

### 6. Verificar Ingress Controller

```bash
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx
```

**Saída esperada:**
```
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-xxxxx              1/1     Running   0          2m

NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
ingress-nginx-controller             NodePort    10.96.100.50    <none>        80:30080/TCP,443:30443/TCP
```

## Método 2: Cluster Multi-Node com Ingress

### 1. Configuração Multi-Node

```yaml
# kind-multi-node-ingress.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
# Control plane
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
# Workers
- role: worker
- role: worker
```

### 2. Criar Cluster

```bash
kind create cluster --name multi-node-ingress --config kind-multi-node-ingress.yaml
```

**Saída esperada:**
```
Creating cluster "multi-node-ingress" ...
 ✓ Ensuring node image (kindest/node:v1.29.2) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
```

### 3. Verificar Nodes

```bash
kubectl get nodes
```

**Saída esperada:**
```
NAME                              STATUS   ROLES           AGE   VERSION
multi-node-ingress-control-plane  Ready    control-plane   2m    v1.29.2
multi-node-ingress-worker         Ready    <none>          1m    v1.29.2
multi-node-ingress-worker2        Ready    <none>          1m    v1.29.2
```

## Exemplo Prático 1: Aplicação Simples com Ingress

### 1. Criar Aplicação

```yaml
# hello-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
  labels:
    app: hello
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: hashicorp/http-echo:1.0
        args:
        - "-text=Hello from Kind Ingress!"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: hello-service
spec:
  selector:
    app: hello
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f hello-app.yaml
```

**Saída esperada:**
```
deployment.apps/hello-app created
service/hello-service created
```

### 2. Criar Ingress

```yaml
# hello-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-ingress
spec:
  rules:
  - host: hello.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-service
            port:
              number: 80
```

```bash
kubectl apply -f hello-ingress.yaml
```

**Saída esperada:**
```
ingress.networking.k8s.io/hello-ingress created
```

### 3. Verificar Ingress

```bash
kubectl get ingress hello-ingress
```

**Saída esperada:**
```
NAME            CLASS    HOSTS         ADDRESS     PORTS   AGE
hello-ingress   <none>   hello.local   localhost   80      30s
```

### 4. Testar Acesso

```bash
# Opção 1: Usar curl com header Host
curl -H "Host: hello.local" http://localhost

# Opção 2: Adicionar entrada no /etc/hosts
echo "127.0.0.1 hello.local" | sudo tee -a /etc/hosts

# Testar com domínio
curl http://hello.local
```

**Saída esperada:**
```
Hello from Kind Ingress!
```

### 5. Testar no Navegador

```bash
# Adicionar ao /etc/hosts
echo "127.0.0.1 hello.local" | sudo tee -a /etc/hosts

# Abrir navegador
# http://hello.local
```

## Exemplo Prático 2: Múltiplas Aplicações

### 1. Criar Aplicações

```yaml
# multi-apps.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Application 1"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: app1-service
spec:
  selector:
    app: app1
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Application 2"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: app2-service
spec:
  selector:
    app: app2
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f multi-apps.yaml
```

### 2. Ingress com Múltiplos Hosts

```yaml
# multi-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-ingress
spec:
  rules:
  - host: app1.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

```bash
kubectl apply -f multi-ingress.yaml
```

### 3. Configurar /etc/hosts

```bash
sudo tee -a /etc/hosts << EOF
127.0.0.1 app1.local
127.0.0.1 app2.local
EOF
```

### 4. Testar

```bash
curl http://app1.local
curl http://app2.local
```

**Saída esperada:**
```
Application 1
Application 2
```

## Exemplo Prático 3: Ingress com TLS/SSL

### 1. Gerar Certificado

```bash
# Gerar certificado autoassinado
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure.local/O=MyOrg"

# Criar Secret
kubectl create secret tls secure-tls \
  --cert=tls.crt \
  --key=tls.key

# Limpar arquivos
rm tls.key tls.crt
```

**Saída esperada:**
```
secret/secure-tls created
```

### 2. Criar Aplicação

```yaml
# secure-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure
  template:
    metadata:
      labels:
        app: secure
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Secure Application with TLS"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: secure-service
spec:
  selector:
    app: secure
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f secure-app.yaml
```

### 3. Ingress com TLS

```yaml
# secure-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - secure.local
    secretName: secure-tls
  rules:
  - host: secure.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-service
            port:
              number: 80
```

```bash
kubectl apply -f secure-ingress.yaml
```

### 4. Configurar /etc/hosts

```bash
echo "127.0.0.1 secure.local" | sudo tee -a /etc/hosts
```

### 5. Testar HTTPS

```bash
# Testar HTTPS (ignorar verificação de certificado)
curl -k https://secure.local

# Testar redirect HTTP -> HTTPS
curl -I http://secure.local
```

**Saída esperada:**
```
Secure Application with TLS

HTTP/1.1 308 Permanent Redirect
Location: https://secure.local/
```

## Exemplo Prático 4: Path-Based Routing

### 1. Criar Aplicações

```yaml
# path-apps.yaml
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
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=Frontend"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args: ["-text=API Backend"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f path-apps.yaml
```

### 2. Ingress com Path Routing

```yaml
# path-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

```bash
kubectl apply -f path-ingress.yaml
```

### 3. Configurar /etc/hosts

```bash
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
```

### 4. Testar

```bash
# Frontend
curl http://myapp.local/

# API
curl http://myapp.local/api
```

**Saída esperada:**
```
Frontend
API Backend
```

## Comandos Úteis

### Gerenciar Clusters Kind

```bash
# Listar clusters
kind get clusters

# Ver nodes do cluster
kind get nodes --name ingress-cluster

# Deletar cluster
kind delete cluster --name ingress-cluster

# Exportar kubeconfig
kind export kubeconfig --name ingress-cluster
```

### Debug Ingress

```bash
# Ver logs do Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Ver configuração do Nginx
kubectl exec -n ingress-nginx -it <pod-name> -- cat /etc/nginx/nginx.conf

# Testar dentro do cluster
kubectl run test --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://hello-service
```

### Verificar Port Mapping

```bash
# Ver portas mapeadas no container Docker
docker ps --filter name=ingress-cluster-control-plane --format "{{.Ports}}"
```

**Saída esperada:**
```
0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 127.0.0.1:xxxxx->6443/tcp
```

## Troubleshooting

### Porta 80/443 Já em Uso

```bash
# Verificar o que está usando a porta
sudo lsof -i :80
sudo lsof -i :443

# Parar serviço conflitante (exemplo: Apache)
sudo systemctl stop apache2

# Ou usar portas diferentes no Kind
# hostPort: 8080 (em vez de 80)
# hostPort: 8443 (em vez de 443)
```

### Ingress não Responde

```bash
# Verificar Ingress Controller
kubectl get pods -n ingress-nginx

# Ver logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Verificar Service
kubectl get service -n ingress-nginx

# Verificar Ingress
kubectl describe ingress <name>
```

### DNS não Resolve

```bash
# Verificar /etc/hosts
cat /etc/hosts | grep local

# Adicionar entrada
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts

# Testar com curl e header
curl -H "Host: myapp.local" http://localhost
```

### Certificado SSL Inválido

```bash
# Usar -k para ignorar verificação
curl -k https://secure.local

# Ver certificado
openssl s_client -connect localhost:443 -servername secure.local < /dev/null 2>/dev/null | openssl x509 -text -noout
```

## Configuração Completa de Referência

```yaml
# kind-complete-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: complete-cluster
nodes:
# Control plane com Ingress
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  # Portas customizadas (opcional)
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
# Workers
- role: worker
- role: worker
- role: worker
```

## Script de Automação

```bash
#!/bin/bash
# setup-kind-ingress.sh

set -e

echo "🚀 Creating Kind cluster with Ingress support..."
kind create cluster --name ingress-demo --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

echo "⏳ Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "⏳ Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "✅ Kind cluster with Ingress is ready!"
echo ""
echo "Test with:"
echo "  kubectl get pods -n ingress-nginx"
echo "  kubectl get service -n ingress-nginx"
```

```bash
chmod +x setup-kind-ingress.sh
./setup-kind-ingress.sh
```

## Limpeza

```bash
# Remover recursos
kubectl delete ingress --all
kubectl delete deployment --all
kubectl delete service --all
kubectl delete secret --all

# Deletar cluster Kind
kind delete cluster --name ingress-cluster

# Limpar /etc/hosts
sudo sed -i '/\.local/d' /etc/hosts
```

## Boas Práticas

### 1. Use Arquivo de Configuração

```bash
# ✅ Recomendado
kind create cluster --config kind-config.yaml

# ❌ Evite criar sem configuração
kind create cluster
```

### 2. Nomeie Seus Clusters

```bash
kind create cluster --name dev-cluster --config config.yaml
kind create cluster --name staging-cluster --config config.yaml
```

### 3. Documente Port Mappings

```yaml
# Adicione comentários
extraPortMappings:
- containerPort: 80   # HTTP
  hostPort: 80
- containerPort: 443  # HTTPS
  hostPort: 443
```

### 4. Use Script de Setup

Crie script reutilizável para setup consistente.

### 5. Versione Configurações

Mantenha arquivos de configuração no Git.

## Resumo

- **Kind precisa de configuração especial** para Ingress
- **extraPortMappings** mapeia portas 80/443 do host
- **node-labels: "ingress-ready=true"** identifica node para Ingress
- **Nginx Ingress Controller** específico para Kind
- **localhost** é o endereço de acesso
- **/etc/hosts** para usar domínios customizados
- **Ideal para desenvolvimento e testes locais**

## Próximos Passos

- Testar **múltiplos Ingress** no mesmo cluster
- Configurar **Cert-Manager** para SSL automático
- Implementar **rate limiting** e **auth**
- Explorar **Ingress annotations** avançadas
- Testar **canary deployments** com Ingress
