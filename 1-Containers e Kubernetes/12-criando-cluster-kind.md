# Criando o Primeiro Cluster com o Kind

**Kind** (Kubernetes in Docker) é uma ferramenta para executar clusters Kubernetes locais usando containers Docker como nodes. É ideal para desenvolvimento, testes e aprendizado.

## O que é o Kind?

### Descrição

Kind foi originalmente desenvolvido para testar o próprio Kubernetes, mas se tornou uma ferramenta popular para desenvolvimento local devido à sua simplicidade e velocidade.

### Características

- **Rápido**: Cria clusters em segundos
- **Leve**: Usa containers Docker ao invés de VMs
- **Multi-node**: Suporta clusters com múltiplos nodes
- **Conformidade**: Clusters totalmente funcionais e certificados
- **CI/CD friendly**: Ideal para pipelines de integração contínua

### Quando Usar Kind?

**Use Kind para:**
- Desenvolvimento local
- Testes de aplicações Kubernetes
- Aprendizado e experimentação
- CI/CD pipelines
- Testar configurações de cluster

**Use alternativas para:**
- Produção (use clusters gerenciados)
- Desenvolvimento com GUI (use Docker Desktop ou Minikube)
- Clusters persistentes de longa duração

## Pré-requisitos

### Docker

Kind requer Docker instalado e rodando.

**Verificar Docker:**
```bash
docker --version
docker ps
```

**Instalar Docker (se necessário):**

**Linux:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

**macOS:**
```bash
brew install --cask docker
# Ou baixar Docker Desktop: https://www.docker.com/products/docker-desktop
```

**Windows:**
- Baixar Docker Desktop: https://www.docker.com/products/docker-desktop

### kubectl

Kind não instala kubectl automaticamente.

```bash
# Verificar se kubectl está instalado
kubectl version --client

# Se não estiver, instalar (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

## Instalação do Kind

### Linux

```bash
# Método 1: Download direto (recomendado)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Método 2: Via Go
go install sigs.k8s.io/kind@v0.20.0

# Verificar instalação
kind version
```

### macOS

```bash
# Método 1: Homebrew (recomendado)
brew install kind

# Método 2: Download direto
# Intel
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64

# Apple Silicon (M1/M2)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-arm64

chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verificar instalação
kind version
```

### Windows

```powershell
# Método 1: Chocolatey
choco install kind

# Método 2: Download direto
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe c:\windows\system32\kind.exe

# Verificar instalação
kind version
```

## Criando o Primeiro Cluster

### Cluster Básico (Single Node)

```bash
# Criar cluster com nome padrão "kind"
kind create cluster

# Output:
# Creating cluster "kind" ...
# ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
# ✓ Preparing nodes 📦
# ✓ Writing configuration 📜
# ✓ Starting control-plane 🕹️
# ✓ Installing CNI 🔌
# ✓ Installing StorageClass 💾
# Set kubectl context to "kind-kind"
# You can now use your cluster with:
# kubectl cluster-info --context kind-kind
```

**Verificar cluster:**
```bash
# Ver clusters kind
kind get clusters

# Ver nodes
kubectl get nodes

# Informações do cluster
kubectl cluster-info --context kind-kind

# Ver pods do sistema
kubectl get pods -n kube-system
```

### Cluster com Nome Customizado

```bash
# Criar cluster com nome específico
kind create cluster --name meu-cluster

# Verificar
kind get clusters
# kind
# meu-cluster

# Usar o cluster
kubectl cluster-info --context kind-meu-cluster
```

### Especificar Versão do Kubernetes

```bash
# Listar imagens disponíveis
# https://hub.docker.com/r/kindest/node/tags

# Criar cluster com versão específica
kind create cluster --name k8s-1-27 --image kindest/node:v1.27.3
kind create cluster --name k8s-1-28 --image kindest/node:v1.28.0
kind create cluster --name k8s-1-29 --image kindest/node:v1.29.0
```

## Configuração Avançada

### Cluster Multi-Node

Criar arquivo de configuração `kind-config.yaml`:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
```

**Criar cluster:**
```bash
kind create cluster --name multi-node --config kind-config.yaml

# Verificar nodes
kubectl get nodes
# NAME                       STATUS   ROLES           AGE
# multi-node-control-plane   Ready    control-plane   2m
# multi-node-worker          Ready    <none>          2m
# multi-node-worker2         Ready    <none>          2m
# multi-node-worker3         Ready    <none>          2m
```

### Cluster com Múltiplos Control Planes (HA)

```yaml
# kind-ha-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
```

```bash
kind create cluster --name ha-cluster --config kind-ha-config.yaml

kubectl get nodes
# NAME                       STATUS   ROLES           AGE
# ha-cluster-control-plane   Ready    control-plane   3m
# ha-cluster-control-plane2  Ready    control-plane   3m
# ha-cluster-control-plane3  Ready    control-plane   3m
# ha-cluster-worker          Ready    <none>          3m
# ha-cluster-worker2         Ready    <none>          3m
```

### Expondo Portas (Port Mapping)

```yaml
# kind-port-mapping.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
  - containerPort: 30001
    hostPort: 30001
    protocol: TCP
- role: worker
```

```bash
kind create cluster --name port-mapping --config kind-port-mapping.yaml

# Agora NodePort services nas portas 30000-30001 são acessíveis via localhost
```

### Configurar Ingress

```yaml
# kind-ingress.yaml
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
- role: worker
- role: worker
```

```bash
# Criar cluster
kind create cluster --name ingress-cluster --config kind-ingress.yaml

# Instalar NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Aguardar ingress controller estar pronto
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Montar Volumes do Host

```yaml
# kind-volumes.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /path/on/host
    containerPath: /path/in/node
- role: worker
  extraMounts:
  - hostPath: /data
    containerPath: /data
```

### Configurar Feature Gates

```yaml
# kind-feature-gates.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
featureGates:
  EphemeralContainers: true
  PodSecurity: true
nodes:
- role: control-plane
- role: worker
```

### Configurar Networking

```yaml
# kind-networking.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  # Subnet para pods
  podSubnet: "10.244.0.0/16"
  # Subnet para services
  serviceSubnet: "10.96.0.0/12"
  # Desabilitar CNI padrão (para instalar outro)
  disableDefaultCNI: false
  # API Server port
  apiServerPort: 6443
  # API Server address
  apiServerAddress: "127.0.0.1"
nodes:
- role: control-plane
- role: worker
```

## Gerenciando Clusters

### Listar Clusters

```bash
# Listar todos os clusters kind
kind get clusters

# Ver nodes do cluster
kubectl get nodes

# Ver containers Docker (nodes do kind)
docker ps
```

### Obter Kubeconfig

```bash
# Kind configura kubectl automaticamente
# Mas você pode exportar o kubeconfig

# Exportar kubeconfig
kind get kubeconfig --name meu-cluster > kubeconfig-meu-cluster

# Usar kubeconfig exportado
kubectl --kubeconfig=kubeconfig-meu-cluster get nodes

# Ou definir variável de ambiente
export KUBECONFIG=kubeconfig-meu-cluster
kubectl get nodes
```

### Trocar entre Clusters

```bash
# Listar contexts
kubectl config get-contexts

# Trocar para cluster kind
kubectl config use-context kind-meu-cluster

# Verificar context atual
kubectl config current-context
```

### Deletar Cluster

```bash
# Deletar cluster específico
kind delete cluster --name meu-cluster

# Deletar cluster padrão
kind delete cluster

# Deletar todos os clusters kind
kind get clusters | xargs -I {} kind delete cluster --name {}
```

## Carregando Imagens Docker

Kind não tem acesso ao Docker Hub por padrão. Para usar imagens locais:

### Método 1: Load de Imagem Local

```bash
# Build imagem localmente
docker build -t myapp:1.0 .

# Carregar imagem no cluster kind
kind load docker-image myapp:1.0 --name meu-cluster

# Verificar imagem no node
docker exec -it meu-cluster-control-plane crictl images | grep myapp
```

### Método 2: Load de Arquivo Tar

```bash
# Salvar imagem como tar
docker save myapp:1.0 -o myapp.tar

# Carregar no kind
kind load image-archive myapp.tar --name meu-cluster
```

### Usar Imagem Carregada

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
spec:
  containers:
  - name: myapp
    image: myapp:1.0
    imagePullPolicy: Never  # Importante: não tentar pull
```

## Exemplo Completo: Deploy de Aplicação

### 1. Criar Cluster

```bash
# Criar cluster com 3 nodes
cat <<EOF | kind create cluster --name demo --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
- role: worker
- role: worker
EOF
```

### 2. Verificar Cluster

```bash
kubectl cluster-info --context kind-demo
kubectl get nodes
```

### 3. Deploy de Aplicação

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
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
# Aplicar manifests
kubectl apply -f deployment.yaml

# Verificar
kubectl get deployments
kubectl get pods
kubectl get services

# Acessar aplicação
curl http://localhost:8080
```

### 4. Escalar Aplicação

```bash
# Escalar para 5 réplicas
kubectl scale deployment nginx-deployment --replicas=5

# Verificar
kubectl get pods
```

### 5. Limpar

```bash
# Deletar recursos
kubectl delete -f deployment.yaml

# Deletar cluster
kind delete cluster --name demo
```

## Troubleshooting

### Cluster não cria

```bash
# Verificar Docker está rodando
docker ps

# Verificar logs
kind create cluster --name debug --verbosity=3

# Limpar e tentar novamente
kind delete cluster --name debug
docker system prune -a
kind create cluster --name debug
```

### Erro de rede

```bash
# Verificar redes Docker
docker network ls

# Recriar rede kind
docker network rm kind
kind create cluster
```

### Pods não iniciam

```bash
# Ver eventos
kubectl get events --sort-by=.metadata.creationTimestamp

# Descrever pod
kubectl describe pod <pod-name>

# Ver logs
kubectl logs <pod-name>
```

### Imagem não encontrada

```bash
# Verificar se imagem foi carregada
docker exec -it <cluster-name>-control-plane crictl images

# Carregar imagem
kind load docker-image <image-name> --name <cluster-name>

# Usar imagePullPolicy: Never no pod
```

### Cluster lento

```bash
# Aumentar recursos do Docker Desktop
# Settings → Resources → Increase CPU/Memory

# Ou usar cluster menor
kind create cluster --name small  # Single node
```

## Configurações Úteis

### Alias

```bash
# Adicionar ao ~/.bashrc ou ~/.zshrc
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'

# Kind specific
alias kc='kind create cluster'
alias kd='kind delete cluster'
alias kl='kind get clusters'
```

### Script de Setup Rápido

```bash
#!/bin/bash
# setup-kind-cluster.sh

CLUSTER_NAME=${1:-dev}

echo "Creating kind cluster: $CLUSTER_NAME"

cat <<EOF | kind create cluster --name $CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
- role: worker
- role: worker
EOF

echo "Cluster created successfully!"
kubectl cluster-info --context kind-$CLUSTER_NAME
kubectl get nodes
```

**Uso:**
```bash
chmod +x setup-kind-cluster.sh
./setup-kind-cluster.sh meu-cluster
```

## Comparação: Kind vs Outras Ferramentas

| Característica | Kind | Minikube | Docker Desktop | K3d |
|----------------|------|----------|----------------|-----|
| Backend | Docker | VM/Docker | VM | Docker |
| Velocidade | Rápido | Médio | Rápido | Muito rápido |
| Multi-node | ✅ | ✅ | ❌ | ✅ |
| GUI | ❌ | ✅ | ✅ | ❌ |
| CI/CD | ✅ | ⚠️ | ❌ | ✅ |
| Recursos | Baixo | Médio | Médio | Muito baixo |
| Complexidade | Baixa | Média | Baixa | Baixa |

## Boas Práticas

### Desenvolvimento

1. **Use clusters descartáveis**
   - Crie e delete clusters frequentemente
   - Mantenha configurações em arquivos

2. **Nomeie clusters claramente**
   ```bash
   kind create cluster --name feature-xyz
   kind create cluster --name bug-123
   ```

3. **Use configurações versionadas**
   - Mantenha arquivos de configuração no Git
   - Documente requisitos específicos

4. **Carregue imagens locais**
   - Evite pulls desnecessários
   - Acelera desenvolvimento

### CI/CD

1. **Automatize criação/destruição**
   ```yaml
   # .github/workflows/test.yml
   - name: Create k8s cluster
     run: kind create cluster
   
   - name: Run tests
     run: kubectl apply -f manifests/
   
   - name: Cleanup
     run: kind delete cluster
   ```

2. **Use cache de imagens**
   - Pre-carregue imagens comuns
   - Reduza tempo de build

3. **Paralelização**
   - Crie clusters isolados por job
   - Evite conflitos

### Performance

1. **Limite recursos**
   - Não crie clusters muito grandes
   - Use single-node quando possível

2. **Limpeza regular**
   ```bash
   # Deletar clusters não usados
   kind get clusters | xargs -I {} kind delete cluster --name {}
   
   # Limpar Docker
   docker system prune -a
   ```

3. **Monitore recursos**
   ```bash
   docker stats
   ```

## Recursos Adicionais

### Documentação Oficial
- https://kind.sigs.k8s.io/
- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://kind.sigs.k8s.io/docs/user/configuration/

### Exemplos de Configuração
- https://github.com/kubernetes-sigs/kind/tree/main/site/content/docs/user

### Comunidade
- GitHub: https://github.com/kubernetes-sigs/kind
- Slack: Kubernetes #kind channel

## Próximos Passos

Após dominar Kind, explore:
- **Helm**: Instalar aplicações complexas
- **Ingress**: Configurar roteamento HTTP
- **Monitoring**: Prometheus e Grafana
- **Service Mesh**: Istio ou Linkerd
- **GitOps**: Argo CD ou Flux
