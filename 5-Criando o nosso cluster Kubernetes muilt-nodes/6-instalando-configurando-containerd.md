# Instalando e Configurando o Containerd

O containerd é o container runtime recomendado para Kubernetes. Este guia mostra como instalar e configurar corretamente.

## O que é Containerd?

Containerd é um runtime de containers de alto desempenho, originalmente parte do Docker, agora um projeto independente da CNCF.

```
┌─────────────────────────────────────────┐
│           Kubernetes (kubelet)          │
└──────────────┬──────────────────────────┘
               │ CRI (Container Runtime Interface)
               │
┌──────────────▼──────────────────────────┐
│            containerd                    │
├─────────────────────────────────────────┤
│  - Gerenciamento de containers          │
│  - Gerenciamento de imagens             │
│  - Execução de containers                │
│  - Snapshots e storage                   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│            runc (OCI Runtime)           │
└─────────────────────────────────────────┘
```

## Por que Containerd?

- ✅ Padrão do Kubernetes (Docker foi deprecated)
- ✅ Leve e eficiente
- ✅ Compatível com CRI
- ✅ Amplamente suportado
- ✅ Projeto CNCF graduado

## Métodos de Instalação

### Método 1: Via Repositório APT (Recomendado)

```bash
# Atualizar sistema
sudo apt-get update
sudo apt-get upgrade -y

# Instalar containerd
sudo apt-get install -y containerd

# Verificar instalação
containerd --version
# Saída: containerd github.com/containerd/containerd v1.7.x
```

### Método 2: Via Docker Repository

```bash
# Instalar dependências
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Adicionar chave GPG do Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Adicionar repositório
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar containerd
sudo apt-get update
sudo apt-get install -y containerd.io

# Verificar
containerd --version
```

### Método 3: Instalação Manual (Binário)

```bash
# Baixar containerd
CONTAINERD_VERSION="1.7.8"
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Extrair
sudo tar Cxzvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Baixar systemd service
sudo wget -O /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

# Recarregar systemd
sudo systemctl daemon-reload
sudo systemctl enable containerd
sudo systemctl start containerd

# Verificar
containerd --version
```

## Configuração do Containerd

### 1. Gerar Configuração Padrão

```bash
# Criar diretório de configuração
sudo mkdir -p /etc/containerd

# Gerar configuração padrão
containerd config default | sudo tee /etc/containerd/config.toml

# Verificar arquivo criado
ls -l /etc/containerd/config.toml
```

### 2. Configurar SystemdCgroup (IMPORTANTE!)

O Kubernetes requer que o containerd use `systemd` como cgroup driver.

```bash
# Editar configuração
sudo vim /etc/containerd/config.toml

# Localizar a seção [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
# Alterar SystemdCgroup de false para true
```

**Ou via sed (automatizado):**

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Verificar alteração
grep SystemdCgroup /etc/containerd/config.toml
# Saída: SystemdCgroup = true
```

### 3. Configuração Completa Recomendada

```bash
# Backup da configuração original
sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.bak

# Criar nova configuração otimizada
cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.9"
    
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true

    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"

  [plugins."io.containerd.internal.v1.opt"]
    path = "/opt/containerd"

[metrics]
  address = "127.0.0.1:1338"
EOF
```

### 4. Reiniciar Containerd

```bash
# Reiniciar serviço
sudo systemctl restart containerd

# Habilitar na inicialização
sudo systemctl enable containerd

# Verificar status
sudo systemctl status containerd

# Saída esperada:
# ● containerd.service - containerd container runtime
#      Loaded: loaded (/lib/systemd/system/containerd.service; enabled)
#      Active: active (running) since ...
```

## Verificar Instalação

### 1. Status do Serviço

```bash
# Ver status
sudo systemctl status containerd

# Ver logs
sudo journalctl -u containerd -f

# Ver logs recentes
sudo journalctl -u containerd --since "10 minutes ago"
```

### 2. Testar com ctr (CLI do containerd)

```bash
# Verificar versão
sudo ctr version

# Listar namespaces
sudo ctr namespaces list

# Listar imagens
sudo ctr images list

# Baixar imagem de teste
sudo ctr images pull docker.io/library/nginx:latest

# Listar imagens novamente
sudo ctr images list

# Criar container de teste
sudo ctr run --rm -t docker.io/library/nginx:latest test-nginx

# Listar containers em execução (em outro terminal)
sudo ctr containers list
sudo ctr tasks list
```

### 3. Testar com crictl (CLI do CRI)

```bash
# Instalar crictl
VERSION="v1.28.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

# Configurar crictl para usar containerd
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Verificar versão
sudo crictl version

# Listar imagens
sudo crictl images

# Baixar imagem
sudo crictl pull nginx:latest

# Ver informações do runtime
sudo crictl info
```

## Script Completo de Instalação

```bash
#!/bin/bash
# install-containerd.sh - Instalar e configurar containerd para Kubernetes

set -e

echo "=== Instalando e Configurando Containerd ==="

# Verificar se já está instalado
if command -v containerd &> /dev/null; then
    echo "Containerd já está instalado: $(containerd --version)"
    read -p "Deseja reinstalar? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 0
    fi
fi

# Atualizar sistema
echo "Atualizando sistema..."
sudo apt-get update
sudo apt-get upgrade -y

# Instalar containerd
echo "Instalando containerd..."
sudo apt-get install -y containerd

# Criar diretório de configuração
echo "Criando configuração..."
sudo mkdir -p /etc/containerd

# Gerar configuração padrão
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Configurar SystemdCgroup
echo "Configurando SystemdCgroup..."
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Verificar alteração
if grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
    echo "✅ SystemdCgroup configurado corretamente"
else
    echo "❌ Erro ao configurar SystemdCgroup"
    exit 1
fi

# Reiniciar containerd
echo "Reiniciando containerd..."
sudo systemctl restart containerd
sudo systemctl enable containerd

# Aguardar serviço iniciar
sleep 3

# Verificar status
if sudo systemctl is-active --quiet containerd; then
    echo "✅ Containerd está rodando"
else
    echo "❌ Containerd não está rodando"
    sudo systemctl status containerd
    exit 1
fi

# Instalar crictl
echo "Instalando crictl..."
CRICTL_VERSION="v1.28.0"
wget -q https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-$CRICTL_VERSION-linux-amd64.tar.gz
sudo tar zxf crictl-$CRICTL_VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$CRICTL_VERSION-linux-amd64.tar.gz

# Configurar crictl
cat <<EOF | sudo tee /etc/crictl.yaml > /dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Verificar instalação
echo ""
echo "=== Verificando Instalação ==="
echo "Containerd version: $(containerd --version)"
echo "Crictl version: $(sudo crictl version --short 2>/dev/null || echo 'N/A')"
echo ""
echo "Status do serviço:"
sudo systemctl status containerd --no-pager | head -n 5

echo ""
echo "=== Containerd instalado e configurado com sucesso! ==="
```

## Configurações Avançadas

### 1. Configurar Registry Privado

```bash
# Editar configuração
sudo vim /etc/containerd/config.toml

# Adicionar na seção [plugins."io.containerd.grpc.v1.cri".registry]
[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["https://registry-1.docker.io"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.example.com"]
    endpoint = ["https://registry.example.com"]

[plugins."io.containerd.grpc.v1.cri".registry.configs]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."registry.example.com".auth]
    username = "user"
    password = "pass"

# Reiniciar
sudo systemctl restart containerd
```

### 2. Configurar Limites de Recursos

```bash
# Editar systemd service
sudo systemctl edit containerd

# Adicionar:
[Service]
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity

# Recarregar e reiniciar
sudo systemctl daemon-reload
sudo systemctl restart containerd
```

### 3. Habilitar Métricas

```bash
# Já configurado no config.toml:
[metrics]
  address = "127.0.0.1:1338"

# Testar métricas
curl http://127.0.0.1:1338/v1/metrics
```

## Troubleshooting

### Containerd não inicia

```bash
# Ver logs detalhados
sudo journalctl -u containerd -n 100 --no-pager

# Verificar configuração
sudo containerd config dump

# Testar configuração
sudo containerd --config /etc/containerd/config.toml --log-level debug
```

### Erro de permissão

```bash
# Verificar socket
ls -l /run/containerd/containerd.sock

# Adicionar usuário ao grupo
sudo usermod -aG docker $USER
newgrp docker
```

### SystemdCgroup não aplicado

```bash
# Verificar configuração
sudo grep -A 5 "runc.options" /etc/containerd/config.toml

# Deve mostrar:
# [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#   SystemdCgroup = true

# Se não estiver, corrigir:
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
```

### Erro ao baixar imagens

```bash
# Testar conectividade
sudo crictl pull nginx:latest

# Ver logs
sudo journalctl -u containerd -f

# Verificar DNS
cat /etc/resolv.conf

# Testar registry
curl -I https://registry-1.docker.io/v2/
```

## Comandos Úteis

### Gerenciamento de Imagens

```bash
# Listar imagens
sudo crictl images
sudo ctr -n k8s.io images list

# Baixar imagem
sudo crictl pull nginx:latest

# Remover imagem
sudo crictl rmi nginx:latest

# Inspecionar imagem
sudo crictl inspecti nginx:latest
```

### Gerenciamento de Containers

```bash
# Listar containers
sudo crictl ps -a

# Ver logs de container
sudo crictl logs <container-id>

# Executar comando em container
sudo crictl exec -it <container-id> /bin/bash

# Parar container
sudo crictl stop <container-id>

# Remover container
sudo crictl rm <container-id>
```

### Gerenciamento de Pods

```bash
# Listar pods
sudo crictl pods

# Inspecionar pod
sudo crictl inspectp <pod-id>

# Ver logs de pod
sudo crictl logs <pod-id>

# Remover pod
sudo crictl stopp <pod-id>
sudo crictl rmp <pod-id>
```

### Informações do Sistema

```bash
# Informações do runtime
sudo crictl info

# Estatísticas
sudo crictl stats

# Versão
sudo crictl version

# Configuração
sudo crictl config
```

## Diferenças: ctr vs crictl

| Comando | ctr | crictl |
|---------|-----|--------|
| **Propósito** | CLI nativo do containerd | CLI compatível com CRI (Kubernetes) |
| **Namespace** | Requer especificar (-n k8s.io) | Usa k8s.io por padrão |
| **Uso** | Debug e desenvolvimento | Kubernetes e produção |
| **Pods** | Não suporta | Suporta |

```bash
# ctr - baixo nível
sudo ctr -n k8s.io images list
sudo ctr -n k8s.io containers list

# crictl - alto nível (Kubernetes)
sudo crictl images
sudo crictl ps
sudo crictl pods
```

## Integração com Kubernetes

Após instalar e configurar o containerd, o kubelet automaticamente detecta e usa o runtime:

```bash
# Verificar runtime no kubelet
sudo systemctl status kubelet

# Ver configuração do kubelet
cat /var/lib/kubelet/config.yaml | grep containerRuntime

# Verificar socket
ls -l /run/containerd/containerd.sock
```

## Checklist de Instalação

```bash
# ✅ Containerd instalado
containerd --version

# ✅ Serviço rodando
sudo systemctl is-active containerd

# ✅ SystemdCgroup configurado
grep "SystemdCgroup = true" /etc/containerd/config.toml

# ✅ crictl instalado
crictl version

# ✅ crictl configurado
cat /etc/crictl.yaml

# ✅ Pode baixar imagens
sudo crictl pull nginx:latest

# ✅ Socket acessível
ls -l /run/containerd/containerd.sock
```

## Resumo

**Instalação:**
```bash
sudo apt-get install -y containerd
```

**Configuração:**
```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

**Verificação:**
```bash
sudo systemctl status containerd
sudo crictl version
sudo crictl images
```

Pronto para usar com Kubernetes! 🚀
