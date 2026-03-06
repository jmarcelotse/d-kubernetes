# O que é um Container Runtime?

Um **container runtime** é o componente de software de baixo nível responsável por executar e gerenciar containers no sistema operacional. Ele é a camada que realmente cria o isolamento e executa os processos dentro dos containers.

## Função Principal

O container runtime:
- Cria e configura namespaces do kernel Linux
- Configura cgroups para limitar recursos
- Monta o sistema de arquivos do container
- Executa o processo principal do container
- Gerencia o ciclo de vida do container em execução

## Tipos de Container Runtime

### 1. Low-Level Runtime (OCI Runtime)

Runtimes que implementam a especificação OCI (Open Container Initiative) e interagem diretamente com o kernel:

#### runc
- Runtime padrão da indústria
- Implementação de referência da especificação OCI
- Usado pelo Docker e containerd
- Escrito em Go

#### crun
- Runtime escrito em C
- Mais rápido e leve que runc
- Menor consumo de memória
- Alternativa compatível com OCI

#### Kata Containers
- Executa containers em máquinas virtuais leves
- Maior isolamento e segurança
- Compatível com OCI
- Ideal para workloads multi-tenant

#### gVisor (runsc)
- Sandbox de segurança desenvolvido pelo Google
- Implementa syscalls em user-space
- Maior isolamento sem VMs completas
- Trade-off entre segurança e performance

### 2. High-Level Runtime (CRI Runtime)

Runtimes que fornecem APIs de alto nível e gerenciam imagens:

#### containerd
- Runtime de alto nível mais popular
- Usado pelo Docker e Kubernetes
- Gerencia imagens, snapshots e networking
- Projeto graduado da CNCF

#### CRI-O
- Runtime otimizado para Kubernetes
- Implementa a Container Runtime Interface (CRI)
- Leve e focado em produção
- Não inclui funcionalidades extras

## Arquitetura em Camadas

```
┌──────────────────────────────────────┐
│  Container Engine (Docker/Podman)    │  ← Interface do usuário
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│  High-Level Runtime (containerd)     │  ← Gerencia imagens e APIs
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│  Low-Level Runtime (runc)            │  ← Executa containers
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│  Kernel Linux                        │  ← Namespaces, cgroups
└──────────────────────────────────────┘
```

## Especificação OCI

A Open Container Initiative define padrões para runtimes:

### OCI Runtime Specification
- Como executar um container
- Formato de configuração (config.json)
- Operações do ciclo de vida (create, start, kill, delete)

### OCI Image Specification
- Formato de imagens de container
- Manifests e layers
- Distribuição de imagens

## Container Runtime Interface (CRI)

Interface padrão do Kubernetes para comunicação com runtimes:

```
┌─────────────┐
│  Kubelet    │
└──────┬──────┘
       │ CRI (gRPC)
┌──────▼──────────────────┐
│  CRI Runtime            │
│  (containerd/CRI-O)     │
└──────┬──────────────────┘
       │
┌──────▼──────┐
│  OCI Runtime│
│  (runc)     │
└─────────────┘
```

## Comparação de Runtimes

| Runtime | Tipo | Uso Principal | Características |
|---------|------|---------------|-----------------|
| runc | Low-level | Padrão da indústria | Referência OCI, estável |
| crun | Low-level | Performance | Mais rápido, escrito em C |
| containerd | High-level | Docker, K8s | Completo, robusto |
| CRI-O | High-level | Kubernetes | Leve, focado em K8s |
| Kata Containers | Low-level | Segurança | Isolamento com VMs |
| gVisor | Low-level | Segurança | Sandbox user-space |

## Escolhendo um Runtime

### Para Desenvolvimento
- **runc**: Padrão, funciona em todos os lugares
- **crun**: Se busca performance máxima

### Para Kubernetes
- **containerd**: Mais usado, bem testado
- **CRI-O**: Alternativa leve e focada

### Para Segurança
- **Kata Containers**: Isolamento forte com VMs
- **gVisor**: Sandbox sem overhead de VMs completas

## Comandos Básicos (runc)

```bash
# Criar container
runc create mycontainer

# Iniciar container
runc start mycontainer

# Listar containers
runc list

# Deletar container
runc delete mycontainer
```

## Relação com Container Engine

- **Container Engine** (Docker, Podman): Interface completa para usuários
- **Container Runtime** (containerd, runc): Execução real dos containers

O engine usa o runtime, mas adiciona funcionalidades como:
- Build de imagens
- Gerenciamento de rede
- Volumes e storage
- APIs e CLI amigáveis

---

## Exemplos Práticos

### Exemplo 1: Usando runc diretamente

```bash
# 1. Criar diretório para o container
mkdir -p mycontainer/rootfs

# 2. Exportar filesystem de uma imagem
docker export $(docker create busybox) | tar -C mycontainer/rootfs -xf -

# 3. Gerar configuração OCI
cd mycontainer
runc spec

# 4. Editar config.json para definir comando
# "args": ["sh"]

# 5. Criar e executar container
runc run mycontainer

# 6. Em outro terminal, listar
runc list

# 7. Deletar
runc delete mycontainer
```

### Exemplo 2: containerd com ctr

```bash
# Baixar imagem
ctr image pull docker.io/library/nginx:alpine

# Listar imagens
ctr image ls

# Executar container
ctr run -d docker.io/library/nginx:alpine nginx1

# Listar containers
ctr container ls

# Ver tarefas (processos)
ctr task ls

# Parar container
ctr task kill nginx1

# Remover container
ctr container rm nginx1
```

### Exemplo 3: CRI-O com crictl (Kubernetes)

```bash
# Listar imagens
crictl images

# Baixar imagem
crictl pull nginx:alpine

# Criar Pod
cat > pod.json << 'EOF'
{
  "metadata": {
    "name": "nginx-pod",
    "namespace": "default"
  },
  "log_directory": "/tmp",
  "linux": {}
}
EOF

crictl runp pod.json

# Criar container no Pod
cat > container.json << 'EOF'
{
  "metadata": {
    "name": "nginx"
  },
  "image": {
    "image": "nginx:alpine"
  },
  "log_path": "nginx.log"
}
EOF

POD_ID=$(crictl pods -q)
crictl create $POD_ID container.json pod.json

# Iniciar container
CONTAINER_ID=$(crictl ps -a -q)
crictl start $CONTAINER_ID

# Listar
crictl ps
```

### Exemplo 4: Comparando runtimes

```bash
# Testar performance do runc
time runc run test-runc

# Testar performance do crun
time crun run test-crun

# crun geralmente é mais rápido (escrito em C)
```

---

## Fluxo de Execução do Runtime

```
┌─────────────────────────────────────────────────────┐
│         FLUXO DE EXECUÇÃO DO RUNTIME                │
└─────────────────────────────────────────────────────┘

1. RECEBE REQUISIÇÃO
   └─> containerd recebe: "criar container nginx"

2. PREPARAÇÃO (High-Level Runtime)
   ├─> Baixa imagem se necessário
   ├─> Extrai layers da imagem
   ├─> Cria snapshot do filesystem
   ├─> Prepara configuração OCI (config.json)
   └─> Gera bundle OCI

3. CRIAÇÃO (Low-Level Runtime - runc)
   ├─> Lê config.json
   ├─> Cria namespaces:
   │   ├─> PID namespace (processos isolados)
   │   ├─> NET namespace (rede isolada)
   │   ├─> MNT namespace (filesystem isolado)
   │   ├─> UTS namespace (hostname isolado)
   │   ├─> IPC namespace (IPC isolado)
   │   └─> USER namespace (usuários isolados)
   ├─> Configura cgroups:
   │   ├─> CPU limits
   │   ├─> Memory limits
   │   ├─> I/O limits
   │   └─> Network limits
   └─> Monta filesystem

4. EXECUÇÃO
   ├─> Fork processo
   ├─> Aplica capabilities
   ├─> Executa comando do container
   └─> Container rodando!

5. MONITORAMENTO
   ├─> Runtime monitora processo
   ├─> Coleta métricas
   ├─> Gerencia logs
   └─> Reporta status
```

---

## Arquitetura Detalhada com Kubernetes

```
┌─────────────────────────────────────────────────────┐
│                   KUBELET                           │
│         (Gerenciador de Pods no nó)                 │
└────────────────────┬────────────────────────────────┘
                     │ CRI (gRPC)
                     │
┌────────────────────▼────────────────────────────────┐
│            CRI RUNTIME (containerd/CRI-O)           │
│  ┌──────────────────────────────────────────────┐  │
│  │  Image Service                               │  │
│  │  - Pull images                               │  │
│  │  - List images                               │  │
│  │  - Remove images                             │  │
│  ├──────────────────────────────────────────────┤  │
│  │  Runtime Service                             │  │
│  │  - RunPodSandbox                             │  │
│  │  - CreateContainer                           │  │
│  │  - StartContainer                            │  │
│  │  - StopContainer                             │  │
│  └──────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│            OCI RUNTIME (runc/crun)                  │
│  - Implementa OCI Runtime Spec                      │
│  - Cria namespaces e cgroups                        │
│  - Executa containers                               │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│              KERNEL LINUX                           │
│  - Namespaces (PID, NET, MNT, UTS, IPC, USER)      │
│  - Cgroups (cpu, memory, blkio, net_cls)           │
│  - Capabilities (CAP_NET_ADMIN, etc)               │
│  - SELinux / AppArmor                               │
└─────────────────────────────────────────────────────┘
```

---

## Especificação OCI - config.json

```json
{
  "ociVersion": "1.0.0",
  "process": {
    "terminal": true,
    "user": {
      "uid": 0,
      "gid": 0
    },
    "args": [
      "sh"
    ],
    "env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
      "TERM=xterm"
    ],
    "cwd": "/",
    "capabilities": {
      "bounding": [
        "CAP_AUDIT_WRITE",
        "CAP_KILL",
        "CAP_NET_BIND_SERVICE"
      ]
    }
  },
  "root": {
    "path": "rootfs",
    "readonly": false
  },
  "hostname": "mycontainer",
  "mounts": [
    {
      "destination": "/proc",
      "type": "proc",
      "source": "proc"
    },
    {
      "destination": "/dev",
      "type": "tmpfs",
      "source": "tmpfs"
    }
  ],
  "linux": {
    "namespaces": [
      {"type": "pid"},
      {"type": "network"},
      {"type": "ipc"},
      {"type": "uts"},
      {"type": "mount"}
    ],
    "resources": {
      "memory": {
        "limit": 536870912
      },
      "cpu": {
        "quota": 50000,
        "period": 100000
      }
    }
  }
}
```

---

## Comandos por Runtime

### runc

```bash
# Criar container
runc create <container-id> --bundle <path>

# Iniciar container
runc start <container-id>

# Listar containers
runc list

# Ver estado
runc state <container-id>

# Executar comando
runc exec <container-id> <command>

# Matar container
runc kill <container-id>

# Deletar container
runc delete <container-id>

# Ver eventos
runc events <container-id>
```

### containerd (ctr)

```bash
# Imagens
ctr image pull <image>
ctr image ls
ctr image rm <image>

# Containers
ctr container create <image> <container-id>
ctr container ls
ctr container rm <container-id>

# Tarefas (processos)
ctr task start <container-id>
ctr task ls
ctr task kill <container-id>
ctr task rm <container-id>

# Namespaces
ctr namespace ls
ctr -n <namespace> container ls
```

### CRI-O (crictl)

```bash
# Imagens
crictl images
crictl pull <image>
crictl rmi <image-id>

# Pods
crictl pods
crictl runp <pod-config.json>
crictl stopp <pod-id>
crictl rmp <pod-id>

# Containers
crictl ps
crictl create <pod-id> <container-config.json> <pod-config.json>
crictl start <container-id>
crictl stop <container-id>
crictl rm <container-id>

# Logs e exec
crictl logs <container-id>
crictl exec -it <container-id> sh

# Info
crictl info
crictl version
```

---

## Verificando Runtime no Sistema

```bash
# Ver qual runtime o Docker usa
docker info | grep -i runtime

# Ver processos do containerd
ps aux | grep containerd

# Ver processos do runc
ps aux | grep runc

# Verificar se CRI-O está rodando
systemctl status crio

# Ver configuração do containerd
cat /etc/containerd/config.toml

# Ver configuração do CRI-O
cat /etc/crio/crio.conf
```

---

## Exemplo Completo: Do Docker ao Kernel

```bash
# 1. Usuário executa
docker run -d --name web -p 80:80 nginx

# 2. Docker Engine processa
# - Verifica imagem nginx localmente
# - Se não existe, faz pull do Docker Hub
# - Prepara configuração do container

# 3. Docker chama containerd via gRPC
# containerd-shim gerencia o container

# 4. containerd chama runc
# runc cria o container

# 5. runc configura kernel
# - Cria PID namespace
ps aux | grep nginx  # Processo isolado

# - Cria NET namespace
docker exec web ip addr  # IP diferente do host

# - Configura cgroups
cat /sys/fs/cgroup/memory/docker/<container-id>/memory.limit_in_bytes

# - Monta filesystem
docker exec web ls /  # Filesystem isolado

# 6. Container rodando
docker ps
curl http://localhost:80
```

---

## Troubleshooting

```bash
# Ver logs do containerd
journalctl -u containerd -f

# Ver logs do CRI-O
journalctl -u crio -f

# Debug do runc
runc --debug run mycontainer

# Ver namespaces de um processo
ls -la /proc/<pid>/ns/

# Ver cgroups de um container
cat /proc/<pid>/cgroup

# Verificar OCI bundle
runc spec
cat config.json

# Testar runtime manualmente
runc run test-container
```

---

## Comparação de Performance

```bash
# Benchmark runc vs crun
#!/bin/bash

echo "Testing runc..."
time for i in {1..100}; do
  runc run test-$i --bundle /tmp/bundle
  runc delete test-$i
done

echo "Testing crun..."
time for i in {1..100}; do
  crun run test-$i --bundle /tmp/bundle
  crun delete test-$i
done

# crun geralmente é 30-50% mais rápido
```
