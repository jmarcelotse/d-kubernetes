# Entendendo e Instalando o kubectl

O **kubectl** (Kubernetes Control) é a ferramenta de linha de comando oficial para interagir com clusters Kubernetes. É a principal interface para gerenciar aplicações, inspecionar recursos e debugar problemas.

## O que é o kubectl?

### Descrição

kubectl é um cliente CLI que se comunica com o API Server do Kubernetes via API REST. Ele permite criar, inspecionar, atualizar e deletar recursos do cluster.

### Características

- **Interface unificada**: Gerencia qualquer cluster Kubernetes (local, cloud, on-premises)
- **Declarativo e imperativo**: Suporta ambos os modos de operação
- **Extensível**: Plugins e customizações
- **Multi-cluster**: Gerencia múltiplos clusters via contexts
- **Auto-complete**: Suporte para bash, zsh, fish, powershell

### Como Funciona

```
┌──────────────┐
│   kubectl    │  (CLI local)
└──────┬───────┘
       │ HTTPS (porta 6443)
       │ Autenticação via certificados/tokens
       │
┌──────▼───────────────────────────┐
│   API Server                     │
│   (Control Plane)                │
└──────────────────────────────────┘
```

**Fluxo:**
1. kubectl lê comando do usuário
2. Lê configuração do kubeconfig (~/.kube/config)
3. Faz requisição HTTPS ao API Server
4. API Server autentica e autoriza
5. API Server processa e retorna resposta
6. kubectl formata e exibe resultado

## Instalação

### Linux

#### Método 1: Download Direto (Recomendado)

```bash
# Baixar última versão
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Validar binário (opcional)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Instalar
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verificar instalação
kubectl version --client
```

#### Método 2: Gerenciador de Pacotes

**Ubuntu/Debian:**
```bash
# Adicionar repositório
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Instalar
sudo apt-get update
sudo apt-get install -y kubectl
```

**CentOS/RHEL/Fedora:**
```bash
# Adicionar repositório
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

# Instalar
sudo yum install -y kubectl
```

**Arch Linux:**
```bash
sudo pacman -S kubectl
```

#### Método 3: Snap

```bash
sudo snap install kubectl --classic
```

### macOS

#### Método 1: Homebrew (Recomendado)

```bash
# Instalar
brew install kubectl

# Ou via cask
brew install --cask kubectl

# Verificar
kubectl version --client
```

#### Método 2: Download Direto

```bash
# Intel
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"

# Apple Silicon (M1/M2)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"

# Tornar executável
chmod +x ./kubectl

# Mover para PATH
sudo mv ./kubectl /usr/local/bin/kubectl
sudo chown root: /usr/local/bin/kubectl

# Verificar
kubectl version --client
```

#### Método 3: MacPorts

```bash
sudo port selfupdate
sudo port install kubectl
```

### Windows

#### Método 1: Chocolatey

```powershell
choco install kubernetes-cli
```

#### Método 2: Scoop

```powershell
scoop install kubectl
```

#### Método 3: Download Direto

```powershell
# PowerShell
curl.exe -LO "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"

# Adicionar ao PATH
# 1. Mover kubectl.exe para C:\Program Files\kubectl\
# 2. Adicionar C:\Program Files\kubectl\ ao PATH do sistema
```

#### Método 4: Winget

```powershell
winget install -e --id Kubernetes.kubectl
```

### Docker Desktop

Se você usa Docker Desktop, kubectl já vem incluído:

```bash
# Verificar
kubectl version --client
```

### Instalando Versão Específica

```bash
# Linux
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"

# macOS (Intel)
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/darwin/amd64/kubectl"

# macOS (Apple Silicon)
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/darwin/arm64/kubectl"

# Windows
curl.exe -LO "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"
```

## Configuração

### kubeconfig

kubectl usa arquivo de configuração chamado **kubeconfig** para conectar ao cluster.

**Localização padrão:**
- Linux/macOS: `~/.kube/config`
- Windows: `%USERPROFILE%\.kube\config`

**Estrutura do kubeconfig:**

```yaml
apiVersion: v1
kind: Config
current-context: my-cluster

# Clusters (API Server endpoints)
clusters:
- cluster:
    certificate-authority-data: <base64-encoded-ca-cert>
    server: https://192.168.1.100:6443
  name: my-cluster

# Users (credenciais)
users:
- name: my-user
  user:
    client-certificate-data: <base64-encoded-client-cert>
    client-key-data: <base64-encoded-client-key>

# Contexts (cluster + user + namespace)
contexts:
- context:
    cluster: my-cluster
    user: my-user
    namespace: default
  name: my-cluster
```

### Obtendo kubeconfig

#### Clusters Gerenciados (Cloud)

**AWS EKS:**
```bash
aws eks update-kubeconfig --region us-east-1 --name my-cluster
```

**Google GKE:**
```bash
gcloud container clusters get-credentials my-cluster --region us-central1
```

**Azure AKS:**
```bash
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

**DigitalOcean:**
```bash
doctl kubernetes cluster kubeconfig save my-cluster
```

#### Clusters Locais

**Minikube:**
```bash
minikube start
# kubeconfig configurado automaticamente
```

**Kind:**
```bash
kind create cluster
# kubeconfig configurado automaticamente
```

**K3s:**
```bash
# kubeconfig em /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

**kubeadm:**
```bash
# No master node
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Gerenciando Múltiplos Clusters

```bash
# Ver configuração atual
kubectl config view

# Listar contexts
kubectl config get-contexts

# Ver context atual
kubectl config current-context

# Mudar de context
kubectl config use-context my-other-cluster

# Definir namespace padrão para context
kubectl config set-context --current --namespace=my-namespace

# Criar novo context
kubectl config set-context dev-context \
  --cluster=my-cluster \
  --user=dev-user \
  --namespace=development

# Deletar context
kubectl config delete-context old-context

# Usar kubeconfig alternativo
kubectl --kubeconfig=/path/to/config get pods

# Ou via variável de ambiente
export KUBECONFIG=/path/to/config
kubectl get pods
```

### Múltiplos kubeconfig

```bash
# Mesclar múltiplos arquivos
export KUBECONFIG=~/.kube/config:~/.kube/config-cluster2:~/.kube/config-cluster3

# Ver configuração mesclada
kubectl config view

# Salvar configuração mesclada
kubectl config view --flatten > ~/.kube/config-merged
```

## Verificando Instalação

```bash
# Versão do cliente
kubectl version --client

# Versão do cliente e servidor
kubectl version

# Informações do cluster
kubectl cluster-info

# Verificar conectividade
kubectl get nodes

# Verificar permissões
kubectl auth can-i create deployments
kubectl auth can-i '*' '*' --all-namespaces
```

## Comandos Básicos

### Sintaxe

```bash
kubectl [command] [TYPE] [NAME] [flags]
```

- **command**: Operação (get, create, apply, delete, etc.)
- **TYPE**: Tipo de recurso (pod, service, deployment, etc.)
- **NAME**: Nome do recurso
- **flags**: Opções adicionais

### Comandos Essenciais

```bash
# GET - Listar recursos
kubectl get pods
kubectl get services
kubectl get deployments
kubectl get all

# DESCRIBE - Detalhes de um recurso
kubectl describe pod my-pod
kubectl describe service my-service

# CREATE - Criar recurso
kubectl create deployment nginx --image=nginx
kubectl create namespace dev

# APPLY - Aplicar configuração (declarativo)
kubectl apply -f deployment.yaml
kubectl apply -f ./configs/

# DELETE - Deletar recurso
kubectl delete pod my-pod
kubectl delete -f deployment.yaml

# LOGS - Ver logs
kubectl logs my-pod
kubectl logs my-pod -f  # Follow
kubectl logs my-pod -c container-name  # Multi-container

# EXEC - Executar comando em container
kubectl exec my-pod -- ls /
kubectl exec -it my-pod -- /bin/bash

# PORT-FORWARD - Encaminhar porta local
kubectl port-forward pod/my-pod 8080:80
kubectl port-forward service/my-service 8080:80

# EDIT - Editar recurso
kubectl edit deployment my-deployment

# SCALE - Escalar deployment
kubectl scale deployment my-deployment --replicas=5

# ROLLOUT - Gerenciar rollouts
kubectl rollout status deployment/my-deployment
kubectl rollout history deployment/my-deployment
kubectl rollout undo deployment/my-deployment
```

### Flags Úteis

```bash
# Namespace
kubectl get pods -n kube-system
kubectl get pods --all-namespaces
kubectl get pods -A  # Abreviação

# Output formats
kubectl get pods -o wide
kubectl get pods -o yaml
kubectl get pods -o json
kubectl get pods -o name

# Labels
kubectl get pods --show-labels
kubectl get pods -l app=nginx
kubectl get pods -l 'env in (prod,staging)'

# Sorting
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods --sort-by=.status.startTime

# Watch
kubectl get pods --watch
kubectl get pods -w

# Dry-run
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml
kubectl apply -f deployment.yaml --dry-run=server

# Force
kubectl delete pod my-pod --force --grace-period=0

# Help
kubectl get --help
kubectl create deployment --help
```

## Auto-completion

### Bash

```bash
# Instalar bash-completion
sudo apt-get install bash-completion  # Ubuntu/Debian
sudo yum install bash-completion      # CentOS/RHEL

# Habilitar kubectl completion
echo 'source <(kubectl completion bash)' >>~/.bashrc

# Alias com completion
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc

# Recarregar
source ~/.bashrc
```

### Zsh

```bash
# Habilitar kubectl completion
echo 'source <(kubectl completion zsh)' >>~/.zshrc

# Alias com completion
echo 'alias k=kubectl' >>~/.zshrc
echo 'compdef __start_kubectl k' >>~/.zshrc

# Recarregar
source ~/.zshrc
```

### Fish

```bash
kubectl completion fish | source

# Persistir
kubectl completion fish > ~/.config/fish/completions/kubectl.fish
```

### PowerShell

```powershell
kubectl completion powershell | Out-String | Invoke-Expression

# Adicionar ao profile
kubectl completion powershell >> $PROFILE
```

## Plugins

### Krew (Plugin Manager)

**Instalação:**

```bash
# Linux/macOS
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Adicionar ao PATH
echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Plugins Úteis:**

```bash
# Listar plugins disponíveis
kubectl krew search

# Instalar plugins
kubectl krew install ctx      # Trocar contexts facilmente
kubectl krew install ns       # Trocar namespaces facilmente
kubectl krew install tree     # Visualizar hierarquia de recursos
kubectl krew install tail     # Tail logs de múltiplos pods
kubectl krew install view-secret  # Ver secrets decodificados

# Usar plugins
kubectl ctx                   # Listar contexts
kubectl ctx my-cluster        # Trocar context
kubectl ns development        # Trocar namespace
kubectl tree deployment nginx # Ver hierarquia
```

### Plugins Populares

**kubectx e kubens:**
```bash
# Instalação manual (sem krew)
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# Uso
kubectx                       # Listar contexts
kubectx my-cluster            # Trocar context
kubens                        # Listar namespaces
kubens development            # Trocar namespace
```

## Ferramentas Complementares

### k9s (Terminal UI)

```bash
# Instalação
brew install k9s              # macOS
sudo snap install k9s         # Linux
choco install k9s             # Windows

# Uso
k9s
```

### Lens (Desktop IDE)

- Download: https://k8slens.dev/
- Interface gráfica completa para Kubernetes
- Multi-cluster management

### Stern (Multi-pod logs)

```bash
# Instalação
brew install stern            # macOS

# Uso
stern my-app                  # Logs de todos os pods com "my-app" no nome
stern --namespace=prod my-app # Namespace específico
```

### kubetail

```bash
# Instalação
brew tap johanhaleby/kubetail && brew install kubetail

# Uso
kubetail my-app               # Tail logs de múltiplos pods
```

## Aliases Úteis

```bash
# Adicionar ao ~/.bashrc ou ~/.zshrc

# Kubectl
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kdd='kubectl describe deployment'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Contexts e Namespaces
alias kctx='kubectl config get-contexts'
alias kuse='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

# Watch
alias kgpw='kubectl get pods --watch'
alias kgaw='kubectl get all --watch'
```

## Troubleshooting

### kubectl não conecta ao cluster

```bash
# Verificar kubeconfig
kubectl config view

# Verificar context atual
kubectl config current-context

# Testar conectividade
kubectl cluster-info

# Verificar certificados
kubectl config view --raw

# Verificar se API Server está acessível
curl -k https://<api-server-ip>:6443/healthz
```

### Erro de permissão

```bash
# Verificar permissões
kubectl auth can-i get pods
kubectl auth can-i create deployments

# Ver suas permissões
kubectl auth can-i --list

# Verificar RBAC
kubectl get rolebindings
kubectl get clusterrolebindings
```

### Versão incompatível

```bash
# Verificar versões
kubectl version

# Regra: kubectl deve estar dentro de +/- 1 minor version do cluster
# Cluster 1.28 → kubectl 1.27, 1.28 ou 1.29
```

### Timeout ao conectar

```bash
# Aumentar timeout
kubectl get pods --request-timeout=30s

# Verificar firewall/security groups
# Porta 6443 deve estar acessível
```

## Boas Práticas

### Segurança

1. **Não compartilhe kubeconfig**
   - Contém credenciais sensíveis
   - Use RBAC para controlar acesso

2. **Use namespaces**
   - Isole ambientes (dev, staging, prod)
   - Configure namespace padrão por context

3. **Princípio do menor privilégio**
   - Crie service accounts específicos
   - Evite usar admin credentials

4. **Rotacione credenciais**
   - Atualize certificados regularmente
   - Use tokens com expiração

### Produtividade

1. **Use aliases**
   - Economize digitação
   - Padronize comandos

2. **Habilite auto-completion**
   - Reduz erros
   - Acelera workflow

3. **Use dry-run**
   - Teste comandos antes de aplicar
   - Gere YAMLs rapidamente

4. **Organize kubeconfigs**
   - Um arquivo por cluster
   - Use KUBECONFIG para mesclar

### Operacional

1. **Use declarativo (apply)**
   - Mais previsível que imperativo
   - Facilita versionamento

2. **Sempre especifique namespace**
   - Evita erros em cluster errado
   - Use `-n` ou `--all-namespaces`

3. **Use labels e selectors**
   - Facilita filtragem
   - Melhora organização

4. **Documente contexts**
   - Nomeie contexts claramente
   - Adicione comentários no kubeconfig

## Recursos de Aprendizado

### Documentação Oficial
- https://kubernetes.io/docs/reference/kubectl/
- https://kubernetes.io/docs/reference/kubectl/cheatsheet/

### Cheat Sheets
```bash
# Ver todos os recursos disponíveis
kubectl api-resources

# Ver versões de API
kubectl api-versions

# Explicar recurso
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers

# Exemplos
kubectl create deployment --help
kubectl run --help
```

### Prática

```bash
# Criar cluster local para prática
minikube start

# Ou
kind create cluster

# Praticar comandos
kubectl create deployment nginx --image=nginx
kubectl get pods
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- /bin/bash
kubectl delete deployment nginx
```

## Próximos Passos

Após dominar kubectl, explore:
- **Helm**: Gerenciador de pacotes para Kubernetes
- **Kustomize**: Customização de manifests YAML
- **kubectl plugins**: Estenda funcionalidades
- **CI/CD**: Integre kubectl em pipelines
- **GitOps**: Argo CD, Flux


---

## Exemplos Práticos

### Exemplo 1: Instalar kubectl no Linux

```bash
# Método 1: Download direto (recomendado)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Verificar checksum
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Instalar
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verificar
kubectl version --client

# Método 2: Via package manager (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

### Exemplo 2: Instalar kubectl no macOS

```bash
# Método 1: Homebrew (recomendado)
brew install kubectl

# Método 2: Download direto
# Intel
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"

# Apple Silicon (M1/M2)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"

# Tornar executável
chmod +x ./kubectl

# Mover para PATH
sudo mv ./kubectl /usr/local/bin/kubectl

# Verificar
kubectl version --client
```

### Exemplo 3: Instalar kubectl no Windows

```powershell
# Método 1: Chocolatey
choco install kubernetes-cli

# Método 2: Download direto
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"

# Adicionar ao PATH
# Mover kubectl.exe para C:\Windows\System32\
# Ou adicionar diretório ao PATH

# Verificar
kubectl version --client
```

### Exemplo 4: Configurar kubectl

```bash
# Ver configuração atual
kubectl config view

# Ver contexts disponíveis
kubectl config get-contexts

# Ver context atual
kubectl config current-context

# Trocar de context
kubectl config use-context <context-name>

# Definir namespace padrão
kubectl config set-context --current --namespace=<namespace>

# Ver arquivo de configuração
cat ~/.kube/config
```

### Exemplo 5: Conectar a Cluster

```bash
# Conectar a cluster kind
kind create cluster --name meu-cluster
# kubectl já é configurado automaticamente

# Conectar a cluster minikube
minikube start
# kubectl já é configurado automaticamente

# Conectar a cluster remoto (copiar kubeconfig)
scp user@server:~/.kube/config ~/.kube/config-remote
export KUBECONFIG=~/.kube/config-remote
kubectl get nodes

# Ou mesclar configs
KUBECONFIG=~/.kube/config:~/.kube/config-remote kubectl config view --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config
```

### Exemplo 6: Comandos Básicos

```bash
# Ver versão
kubectl version

# Ver informações do cluster
kubectl cluster-info

# Listar nodes
kubectl get nodes

# Listar pods
kubectl get pods

# Listar todos os recursos
kubectl get all

# Criar recurso
kubectl apply -f deployment.yaml

# Deletar recurso
kubectl delete -f deployment.yaml

# Ver logs
kubectl logs <pod-name>

# Executar comando
kubectl exec -it <pod-name> -- bash

# Port forward
kubectl port-forward <pod-name> 8080:80
```

### Exemplo 7: Autocompletion

```bash
# Bash (Linux)
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc

# Zsh (macOS)
echo 'source <(kubectl completion zsh)' >> ~/.zshrc
echo 'alias k=kubectl' >> ~/.zshrc
echo 'compdef __start_kubectl k' >> ~/.zshrc
source ~/.zshrc

# Testar
kubectl get po<TAB>  # completa para 'pods'
k get no<TAB>  # completa para 'nodes'
```

### Exemplo 8: Plugins kubectl

```bash
# Instalar krew (gerenciador de plugins)
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Adicionar ao PATH
echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Listar plugins disponíveis
kubectl krew search

# Instalar plugins úteis
kubectl krew install ctx      # Trocar contexts
kubectl krew install ns       # Trocar namespaces
kubectl krew install tree     # Ver hierarquia de recursos
kubectl krew install tail     # Tail logs de múltiplos pods

# Usar plugins
kubectl ctx                   # Listar contexts
kubectl ns                    # Listar namespaces
kubectl tree deployment nginx # Ver hierarquia
```

---

## Fluxo de Configuração kubectl

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE CONFIGURAÇÃO DO KUBECTL                │
└─────────────────────────────────────────────────────────┘

1. INSTALAR KUBECTL
   └─> Download binário ou package manager

2. OBTER KUBECONFIG
   ├─> Cluster local: automático (kind, minikube)
   ├─> Cluster cloud: download do provider
   └─> Cluster custom: copiar de admin

3. KUBECONFIG (~/.kube/config)
   ├─> clusters: lista de clusters
   ├─> users: credenciais de autenticação
   ├─> contexts: combinação de cluster + user + namespace
   └─> current-context: context ativo

4. KUBECTL EXECUTA COMANDO
   ├─> Lê current-context
   ├─> Obtém cluster URL e certificados
   ├─> Obtém user credentials
   ├─> Faz requisição HTTPS ao API Server
   └─> Retorna resultado

EXEMPLO DE KUBECONFIG:
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://127.0.0.1:6443
    certificate-authority-data: <base64>
  name: kind-kind
users:
- name: kind-kind
  user:
    client-certificate-data: <base64>
    client-key-data: <base64>
contexts:
- context:
    cluster: kind-kind
    user: kind-kind
    namespace: default
  name: kind-kind
current-context: kind-kind
```

---

## Troubleshooting

### kubectl não Encontrado

```bash
# Verificar se está no PATH
which kubectl

# Verificar PATH
echo $PATH

# Adicionar ao PATH (Linux/macOS)
export PATH=$PATH:/usr/local/bin

# Tornar permanente
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

### Erro de Conexão

```bash
# Verificar configuração
kubectl config view

# Verificar context
kubectl config current-context

# Testar conectividade
kubectl cluster-info

# Ver erro detalhado
kubectl get nodes -v=8

# Verificar se cluster está rodando
# kind:
kind get clusters
docker ps | grep kind

# minikube:
minikube status
```

### Erro de Permissão

```bash
# Verificar permissões do kubeconfig
ls -la ~/.kube/config

# Corrigir permissões
chmod 600 ~/.kube/config

# Verificar certificados
kubectl config view --raw
```

### Múltiplos Clusters

```bash
# Listar contexts
kubectl config get-contexts

# Ver context atual
kubectl config current-context

# Trocar context
kubectl config use-context <context-name>

# Usar context específico em comando
kubectl --context=<context-name> get pods

# Definir namespace padrão para context
kubectl config set-context --current --namespace=<namespace>
```
