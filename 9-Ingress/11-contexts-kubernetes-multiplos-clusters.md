# Entendendo os Contexts do Kubernetes para Gerenciar Vários Clusters

## Introdução

Contexts no Kubernetes permitem alternar facilmente entre diferentes clusters, usuários e namespaces. Isso é essencial quando você gerencia múltiplos ambientes (desenvolvimento, staging, produção) ou clusters em diferentes provedores (AWS, GCP, Azure, on-premises).

## O que são Contexts?

### Conceito

Um **context** é uma combinação de três elementos:

```
Context = Cluster + User + Namespace
```

```
┌─────────────────────────────────────┐
│           kubeconfig                │
│                                     │
│  ┌──────────┐  ┌──────────┐       │
│  │ Clusters │  │  Users   │       │
│  └──────────┘  └──────────┘       │
│         ↓            ↓             │
│      ┌─────────────────┐          │
│      │    Contexts     │          │
│      │  (Cluster +     │          │
│      │   User +        │          │
│      │   Namespace)    │          │
│      └─────────────────┘          │
└─────────────────────────────────────┘
```

### Componentes do kubeconfig

1. **Clusters**: Informações sobre os clusters (API server URL, certificados)
2. **Users**: Credenciais de autenticação (certificados, tokens)
3. **Contexts**: Combinação de cluster + user + namespace
4. **Current-context**: Context ativo no momento

---

## Estrutura do kubeconfig

### Localização

```bash
# Arquivo padrão
~/.kube/config

# Verificar localização
echo $KUBECONFIG

# Ver conteúdo
cat ~/.kube/config
```

### Estrutura Básica

```yaml
apiVersion: v1
kind: Config
current-context: dev-cluster

clusters:
- cluster:
    certificate-authority-data: LS0tLS...
    server: https://dev-cluster.example.com:6443
  name: dev-cluster

- cluster:
    certificate-authority-data: LS0tLS...
    server: https://prod-cluster.example.com:6443
  name: prod-cluster

users:
- name: dev-user
  user:
    client-certificate-data: LS0tLS...
    client-key-data: LS0tLS...

- name: prod-user
  user:
    client-certificate-data: LS0tLS...
    client-key-data: LS0tLS...

contexts:
- context:
    cluster: dev-cluster
    user: dev-user
    namespace: development
  name: dev

- context:
    cluster: prod-cluster
    user: prod-user
    namespace: production
  name: prod
```

---

## Comandos Básicos de Context

### Ver Contexts

```bash
# Listar todos os contexts
kubectl config get-contexts

# Output:
# CURRENT   NAME    CLUSTER         AUTHINFO    NAMESPACE
# *         dev     dev-cluster     dev-user    development
#           prod    prod-cluster    prod-user   production

# Ver context atual
kubectl config current-context

# Ver detalhes de um context específico
kubectl config get-contexts dev
```

### Alternar Entre Contexts

```bash
# Mudar para outro context
kubectl config use-context prod

# Verificar mudança
kubectl config current-context
# Output: prod

# Ver nodes do cluster atual
kubectl get nodes

# Voltar para dev
kubectl config use-context dev
```

### Ver Configuração Completa

```bash
# Ver toda a configuração
kubectl config view

# Ver configuração com credenciais (cuidado!)
kubectl config view --raw

# Ver apenas clusters
kubectl config view -o jsonpath='{.clusters[*].name}'

# Ver apenas users
kubectl config view -o jsonpath='{.users[*].name}'

# Ver apenas contexts
kubectl config view -o jsonpath='{.contexts[*].name}'
```

---

## Cenário 1: Múltiplos Clusters Locais (Kind)

### 1.1 Criar Clusters Kind

```bash
# Cluster 1: Development
cat <<EOF | kind create cluster --name dev --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
EOF

# Cluster 2: Staging
cat <<EOF | kind create cluster --name staging --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
EOF

# Cluster 3: Production
cat <<EOF | kind create cluster --name prod --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Verificar clusters
kind get clusters
```

### 1.2 Ver Contexts Criados

```bash
# Listar contexts
kubectl config get-contexts

# Output:
# CURRENT   NAME              CLUSTER           AUTHINFO          NAMESPACE
# *         kind-dev          kind-dev          kind-dev
#           kind-staging      kind-staging      kind-staging
#           kind-prod         kind-prod         kind-prod
```

### 1.3 Testar Cada Cluster

```bash
# Dev
kubectl config use-context kind-dev
kubectl get nodes
kubectl create namespace app-dev

# Staging
kubectl config use-context kind-staging
kubectl get nodes
kubectl create namespace app-staging

# Production
kubectl config use-context kind-prod
kubectl get nodes
kubectl create namespace app-prod

# Verificar
kubectl config get-contexts
```

---

## Cenário 2: Clusters em Diferentes Provedores

### 2.1 Adicionar Cluster EKS (AWS)

```bash
# Criar cluster EKS
eksctl create cluster \
  --name eks-prod \
  --region us-east-1 \
  --nodes 2

# Configurar kubeconfig (automático)
aws eks update-kubeconfig \
  --region us-east-1 \
  --name eks-prod

# Verificar
kubectl config get-contexts | grep eks
```

### 2.2 Adicionar Cluster GKE (Google Cloud)

```bash
# Criar cluster GKE
gcloud container clusters create gke-prod \
  --zone us-central1-a \
  --num-nodes 2

# Configurar kubeconfig (automático)
gcloud container clusters get-credentials gke-prod \
  --zone us-central1-a

# Verificar
kubectl config get-contexts | grep gke
```

### 2.3 Adicionar Cluster AKS (Azure)

```bash
# Criar cluster AKS
az aks create \
  --resource-group myResourceGroup \
  --name aks-prod \
  --node-count 2

# Configurar kubeconfig
az aks get-credentials \
  --resource-group myResourceGroup \
  --name aks-prod

# Verificar
kubectl config get-contexts | grep aks
```

### 2.4 Ver Todos os Contexts

```bash
# Listar
kubectl config get-contexts

# Output:
# CURRENT   NAME              CLUSTER           AUTHINFO
# *         kind-dev          kind-dev          kind-dev
#           kind-staging      kind-staging      kind-staging
#           kind-prod         kind-prod         kind-prod
#           eks-prod          eks-prod          eks-prod
#           gke-prod          gke-prod          gke-prod
#           aks-prod          aks-prod          aks-prod
```

---

## Gerenciamento Avançado de Contexts

### Criar Context Manualmente

```bash
# Adicionar cluster
kubectl config set-cluster my-cluster \
  --server=https://my-cluster.example.com:6443 \
  --certificate-authority=/path/to/ca.crt

# Adicionar user
kubectl config set-credentials my-user \
  --client-certificate=/path/to/client.crt \
  --client-key=/path/to/client.key

# Criar context
kubectl config set-context my-context \
  --cluster=my-cluster \
  --user=my-user \
  --namespace=default

# Usar context
kubectl config use-context my-context
```

### Modificar Context Existente

```bash
# Alterar namespace padrão
kubectl config set-context kind-dev --namespace=app-dev

# Alterar user
kubectl config set-context kind-dev --user=new-user

# Alterar cluster
kubectl config set-context kind-dev --cluster=new-cluster

# Verificar
kubectl config get-contexts kind-dev
```

### Renomear Context

```bash
# Renomear
kubectl config rename-context kind-dev development
kubectl config rename-context kind-prod production

# Verificar
kubectl config get-contexts
```

### Deletar Context

```bash
# Deletar context
kubectl config delete-context kind-staging

# Deletar cluster
kubectl config delete-cluster kind-staging

# Deletar user
kubectl config delete-user kind-staging

# Verificar
kubectl config get-contexts
```

---

## Múltiplos Arquivos kubeconfig

### Mesclar Arquivos

```bash
# Método 1: Variável KUBECONFIG
export KUBECONFIG=~/.kube/config:~/.kube/config-eks:~/.kube/config-gke

# Verificar
kubectl config get-contexts

# Método 2: Mesclar permanentemente
KUBECONFIG=~/.kube/config:~/.kube/config-eks:~/.kube/config-gke \
  kubectl config view --flatten > ~/.kube/config-merged

# Backup do original
cp ~/.kube/config ~/.kube/config.backup

# Usar o mesclado
mv ~/.kube/config-merged ~/.kube/config
```

### Organizar por Ambiente

```bash
# Estrutura de diretórios
mkdir -p ~/.kube/configs

# Separar por ambiente
mv ~/.kube/config ~/.kube/configs/local
cp ~/.kube/config-eks ~/.kube/configs/aws
cp ~/.kube/config-gke ~/.kube/configs/gcp

# Usar específico
export KUBECONFIG=~/.kube/configs/aws
kubectl get nodes

# Usar todos
export KUBECONFIG=$(find ~/.kube/configs -type f | tr '\n' ':')
kubectl config get-contexts
```

---

## Ferramentas para Gerenciar Contexts

### 1. kubectx e kubens

```bash
# Instalar (Linux)
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# Instalar (macOS)
brew install kubectx

# Listar contexts
kubectx

# Mudar context
kubectx kind-dev

# Voltar ao anterior
kubectx -

# Listar namespaces
kubens

# Mudar namespace
kubens app-dev

# Voltar ao anterior
kubens -
```

### 2. k9s (Terminal UI)

```bash
# Instalar
brew install k9s

# Executar
k9s

# Atalhos:
# :ctx - Listar e mudar contexts
# :ns  - Listar e mudar namespaces
# Ctrl+A - Ver todos os namespaces
# :q   - Sair
```

### 3. Lens (Desktop UI)

```bash
# Instalar (macOS)
brew install --cask lens

# Instalar (Linux)
# Download: https://k8slens.dev/

# Lens detecta automaticamente todos os contexts do kubeconfig
# Interface gráfica para alternar entre clusters
```

---

## Aliases e Automação

### Aliases Úteis

```bash
# Adicionar ao ~/.bashrc ou ~/.zshrc

# Contexts
alias kctx='kubectl config get-contexts'
alias kuse='kubectl config use-context'
alias kcur='kubectl config current-context'

# Namespaces
alias kns='kubectl config set-context --current --namespace'

# Clusters específicos
alias kdev='kubectl config use-context kind-dev'
alias kstg='kubectl config use-context kind-staging'
alias kprd='kubectl config use-context kind-prod'

# Reload
source ~/.bashrc
```

### Prompt com Context Atual

```bash
# Adicionar ao ~/.bashrc

# Função para mostrar context
kube_ps1() {
  local context=$(kubectl config current-context 2>/dev/null)
  local namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
  if [ -n "$context" ]; then
    echo "[$context:${namespace:-default}]"
  fi
}

# Adicionar ao PS1
PS1='$(kube_ps1) \u@\h:\w\$ '

# Ou usar kube-ps1
git clone https://github.com/jonmosco/kube-ps1.git ~/.kube-ps1
echo 'source ~/.kube-ps1/kube-ps1.sh' >> ~/.bashrc
echo 'PS1="$(kube_ps1) $PS1"' >> ~/.bashrc
```

---

## Cenário Prático: Deploy Multi-Cluster

### 1. Preparar Aplicação

Crie o arquivo `app-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### 2. Deploy em Múltiplos Clusters

```bash
# Script para deploy multi-cluster
#!/bin/bash

CONTEXTS=("kind-dev" "kind-staging" "kind-prod")

for ctx in "${CONTEXTS[@]}"; do
  echo "Deploying to $ctx..."
  kubectl config use-context $ctx
  kubectl apply -f app-deployment.yaml
  kubectl rollout status deployment/myapp
  echo "✓ Deployed to $ctx"
  echo "---"
done

# Voltar ao context original
kubectl config use-context kind-dev
```

### 3. Verificar em Todos os Clusters

```bash
#!/bin/bash

CONTEXTS=("kind-dev" "kind-staging" "kind-prod")

for ctx in "${CONTEXTS[@]}"; do
  echo "Checking $ctx..."
  kubectl config use-context $ctx
  kubectl get pods -l app=myapp
  echo "---"
done
```

### 4. Deletar de Todos os Clusters

```bash
#!/bin/bash

CONTEXTS=("kind-dev" "kind-staging" "kind-prod")

for ctx in "${CONTEXTS[@]}"; do
  echo "Deleting from $ctx..."
  kubectl config use-context $ctx
  kubectl delete -f app-deployment.yaml
  echo "✓ Deleted from $ctx"
  echo "---"
done
```

---

## Segurança e Boas Práticas

### 1. Separar Credenciais por Ambiente

```bash
# Produção: Credenciais restritas
kubectl config set-credentials prod-user \
  --client-certificate=/secure/prod-client.crt \
  --client-key=/secure/prod-client.key

# Development: Credenciais mais permissivas
kubectl config set-credentials dev-user \
  --client-certificate=/home/user/dev-client.crt \
  --client-key=/home/user/dev-client.key
```

### 2. Usar Namespaces Padrão

```bash
# Sempre definir namespace no context
kubectl config set-context kind-dev --namespace=development
kubectl config set-context kind-prod --namespace=production

# Evita comandos acidentais no namespace errado
```

### 3. Backup do kubeconfig

```bash
# Backup regular
cp ~/.kube/config ~/.kube/config.backup.$(date +%Y%m%d)

# Ou usar git
cd ~/.kube
git init
git add config
git commit -m "Backup kubeconfig"
```

### 4. Proteger Arquivo kubeconfig

```bash
# Permissões corretas
chmod 600 ~/.kube/config

# Verificar
ls -la ~/.kube/config
# Output: -rw------- 1 user user 5678 Mar 11 13:00 config
```

---

## Troubleshooting

### Problema 1: Context Não Encontrado

```bash
# Listar contexts disponíveis
kubectl config get-contexts

# Verificar nome correto
kubectl config view -o jsonpath='{.contexts[*].name}'

# Recriar context se necessário
kubectl config set-context <name> --cluster=<cluster> --user=<user>
```

### Problema 2: Credenciais Inválidas

```bash
# Verificar certificados
kubectl config view --raw -o jsonpath='{.users[?(@.name=="<user>")].user}'

# Testar conectividade
kubectl cluster-info

# Reconfigurar credenciais
aws eks update-kubeconfig --name <cluster>  # EKS
gcloud container clusters get-credentials <cluster>  # GKE
```

### Problema 3: Namespace Não Existe

```bash
# Ver namespace do context
kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}'

# Criar namespace
kubectl create namespace <namespace>

# Ou remover namespace do context
kubectl config set-context --current --namespace=default
```

### Problema 4: Múltiplos kubeconfig Conflitantes

```bash
# Ver qual arquivo está sendo usado
echo $KUBECONFIG

# Limpar variável
unset KUBECONFIG

# Usar apenas o padrão
export KUBECONFIG=~/.kube/config

# Verificar
kubectl config get-contexts
```

---

## Script Completo de Gerenciamento

Crie o arquivo `kube-context-manager.sh`:

```bash
#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções
list_contexts() {
  echo -e "${GREEN}Available contexts:${NC}"
  kubectl config get-contexts
}

current_context() {
  local ctx=$(kubectl config current-context)
  echo -e "${GREEN}Current context:${NC} ${YELLOW}$ctx${NC}"
}

switch_context() {
  if [ -z "$1" ]; then
    echo -e "${RED}Error: Context name required${NC}"
    return 1
  fi
  kubectl config use-context "$1"
  echo -e "${GREEN}Switched to:${NC} ${YELLOW}$1${NC}"
}

create_context() {
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo -e "${RED}Error: Usage: create <name> <cluster> <user> [namespace]${NC}"
    return 1
  fi
  kubectl config set-context "$1" --cluster="$2" --user="$3" --namespace="${4:-default}"
  echo -e "${GREEN}Created context:${NC} ${YELLOW}$1${NC}"
}

delete_context() {
  if [ -z "$1" ]; then
    echo -e "${RED}Error: Context name required${NC}"
    return 1
  fi
  kubectl config delete-context "$1"
  echo -e "${GREEN}Deleted context:${NC} ${YELLOW}$1${NC}"
}

# Menu
case "$1" in
  list|ls)
    list_contexts
    ;;
  current|cur)
    current_context
    ;;
  switch|use)
    switch_context "$2"
    ;;
  create)
    create_context "$2" "$3" "$4" "$5"
    ;;
  delete|del)
    delete_context "$2"
    ;;
  *)
    echo "Usage: $0 {list|current|switch|create|delete}"
    echo ""
    echo "Commands:"
    echo "  list              - List all contexts"
    echo "  current           - Show current context"
    echo "  switch <name>     - Switch to context"
    echo "  create <name> <cluster> <user> [ns] - Create context"
    echo "  delete <name>     - Delete context"
    exit 1
    ;;
esac
```

### Usar o Script

```bash
# Tornar executável
chmod +x kube-context-manager.sh

# Listar
./kube-context-manager.sh list

# Ver atual
./kube-context-manager.sh current

# Mudar
./kube-context-manager.sh switch kind-prod

# Criar
./kube-context-manager.sh create my-ctx my-cluster my-user default

# Deletar
./kube-context-manager.sh delete my-ctx
```

---

## Resumo dos Comandos

```bash
# Listar contexts
kubectl config get-contexts

# Ver atual
kubectl config current-context

# Mudar context
kubectl config use-context <name>

# Criar context
kubectl config set-context <name> --cluster=<cluster> --user=<user> --namespace=<ns>

# Modificar context
kubectl config set-context <name> --namespace=<ns>

# Renomear context
kubectl config rename-context <old> <new>

# Deletar context
kubectl config delete-context <name>

# Ver configuração
kubectl config view

# Mesclar configs
export KUBECONFIG=file1:file2:file3
kubectl config view --flatten > merged-config
```

---

## Conclusão

Contexts são essenciais para gerenciar múltiplos clusters Kubernetes:

✅ **Organização** - Separar ambientes claramente  
✅ **Segurança** - Credenciais isoladas por cluster  
✅ **Produtividade** - Alternar rapidamente entre clusters  
✅ **Automação** - Scripts para deploy multi-cluster  
✅ **Flexibilidade** - Gerenciar clusters de diferentes provedores  
✅ **Controle** - Namespace padrão por context  

Com contexts bem configurados, você pode gerenciar dezenas de clusters Kubernetes de forma eficiente e segura!
