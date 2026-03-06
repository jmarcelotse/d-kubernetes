# O que é um Cluster Kubernetes?

Um **cluster Kubernetes** é um conjunto de máquinas (físicas ou virtuais) que trabalham juntas para executar aplicações containerizadas de forma coordenada, escalável e resiliente.

## Componentes Principais

Um cluster Kubernetes é dividido em dois tipos de nós:

### 1. Control Plane (Plano de Controle)

O "cérebro" do cluster que gerencia e coordena todas as operações.

**Componentes:**

- **kube-apiserver** - API REST que recebe comandos (kubectl)
- **etcd** - Banco de dados chave-valor que armazena o estado do cluster
- **kube-scheduler** - Decide em qual nó os pods serão executados
- **kube-controller-manager** - Gerencia controladores (ReplicaSet, Deployment, etc)
- **cloud-controller-manager** - Integração com provedores de nuvem (opcional)

### 2. Worker Nodes (Nós de Trabalho)

Máquinas que executam as aplicações (pods).

**Componentes:**

- **kubelet** - Agente que garante que os containers estão rodando
- **kube-proxy** - Gerencia regras de rede e balanceamento
- **Container Runtime** - Docker, containerd, CRI-O (executa os containers)

## Arquitetura Visual

```
┌─────────────────────────────────────────────────────────────┐
│                      CLUSTER KUBERNETES                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────────────────────────────────────┐      │
│  │           CONTROL PLANE (Master Node)             │      │
│  ├───────────────────────────────────────────────────┤      │
│  │  ┌──────────────┐  ┌──────┐  ┌───────────────┐  │      │
│  │  │ kube-apiserver│  │ etcd │  │ kube-scheduler│  │      │
│  │  └──────────────┘  └──────┘  └───────────────┘  │      │
│  │  ┌────────────────────────────────────────────┐  │      │
│  │  │     kube-controller-manager                │  │      │
│  │  └────────────────────────────────────────────┘  │      │
│  └───────────────────────────────────────────────────┘      │
│                          │                                   │
│                          │ (comunicação)                     │
│                          │                                   │
│  ┌───────────────────────┼───────────────────────────────┐  │
│  │                       │                               │  │
│  │  ┌────────────────────▼──────┐  ┌──────────────────┐ │  │
│  │  │    WORKER NODE 1          │  │  WORKER NODE 2   │ │  │
│  │  ├───────────────────────────┤  ├──────────────────┤ │  │
│  │  │ kubelet | kube-proxy      │  │ kubelet | proxy  │ │  │
│  │  │ Container Runtime         │  │ Container Runtime│ │  │
│  │  ├───────────────────────────┤  ├──────────────────┤ │  │
│  │  │  Pod 1    │    Pod 2      │  │  Pod 3  │ Pod 4  │ │  │
│  │  │ [nginx]   │  [postgres]   │  │ [redis] │ [api]  │ │  │
│  │  └───────────────────────────┘  └──────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Fluxo de Criação de um Pod

```
1. Usuário executa comando
   └─> kubectl create deployment nginx --image=nginx

2. kubectl envia requisição HTTP para kube-apiserver
   └─> POST /apis/apps/v1/namespaces/default/deployments

3. kube-apiserver valida e salva no etcd
   └─> Deployment criado com estado "desired"

4. kube-controller-manager detecta novo Deployment
   └─> Cria ReplicaSet correspondente

5. ReplicaSet Controller cria especificação do Pod
   └─> Pod fica em estado "Pending"

6. kube-scheduler observa Pod sem nó atribuído
   └─> Analisa recursos disponíveis
   └─> Seleciona melhor Worker Node
   └─> Atualiza Pod com nodeName

7. kubelet do Worker Node detecta novo Pod
   └─> Baixa imagem do container
   └─> Cria container via Container Runtime
   └─> Pod muda para "Running"

8. kube-proxy configura regras de rede
   └─> Pod fica acessível na rede do cluster
```

## Exemplo Prático: Criando um Cluster Local com Kind

### 1. Criar arquivo de configuração

```yaml
# kind-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
```

### 2. Criar o cluster

```bash
# Criar cluster
kind create cluster --name meu-cluster --config kind-cluster.yaml

# Verificar nós
kubectl get nodes

# Saída esperada:
# NAME                        STATUS   ROLES           AGE   VERSION
# meu-cluster-control-plane   Ready    control-plane   1m    v1.27.3
# meu-cluster-worker          Ready    <none>          1m    v1.27.3
# meu-cluster-worker2         Ready    <none>          1m    v1.27.3
# meu-cluster-worker3         Ready    <none>          1m    v1.27.3
```

### 3. Verificar componentes do Control Plane

```bash
kubectl get pods -n kube-system

# Saída:
# NAME                                                READY   STATUS    RESTARTS
# coredns-5d78c9869d-abc12                           1/1     Running   0
# coredns-5d78c9869d-def34                           1/1     Running   0
# etcd-meu-cluster-control-plane                     1/1     Running   0
# kube-apiserver-meu-cluster-control-plane           1/1     Running   0
# kube-controller-manager-meu-cluster-control-plane  1/1     Running   0
# kube-proxy-xyz12                                   1/1     Running   0
# kube-scheduler-meu-cluster-control-plane           1/1     Running   0
```

### 4. Verificar informações detalhadas do cluster

```bash
# Ver informações do cluster
kubectl cluster-info

# Saída:
# Kubernetes control plane is running at https://127.0.0.1:xxxxx
# CoreDNS is running at https://127.0.0.1:xxxxx/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

# Ver detalhes de um nó
kubectl describe node meu-cluster-worker

# Informações mostradas:
# - Capacidade (CPU, memória, pods)
# - Condições (Ready, MemoryPressure, DiskPressure)
# - Pods em execução
# - Eventos
```

## Exemplo Prático: Deploy de Aplicação no Cluster

### 1. Criar Deployment

```bash
# Criar deployment com 3 réplicas
kubectl create deployment nginx --image=nginx:1.25 --replicas=3

# Ver deployments
kubectl get deployments

# Ver pods distribuídos nos workers
kubectl get pods -o wide

# Saída:
# NAME                     READY   STATUS    NODE
# nginx-7854ff8877-abc12   1/1     Running   meu-cluster-worker
# nginx-7854ff8877-def34   1/1     Running   meu-cluster-worker2
# nginx-7854ff8877-ghi56   1/1     Running   meu-cluster-worker3
```

### 2. Expor aplicação

```bash
# Criar Service
kubectl expose deployment nginx --port=80 --type=NodePort

# Ver service
kubectl get service nginx

# Testar acesso
kubectl port-forward service/nginx 8080:80

# Em outro terminal
curl http://localhost:8080
```

### 3. Escalar aplicação

```bash
# Escalar para 6 réplicas
kubectl scale deployment nginx --replicas=6

# Kubernetes distribui automaticamente nos workers
kubectl get pods -o wide

# Ver distribuição por nó
kubectl get pods -o wide | awk '{print $7}' | sort | uniq -c
```

## Características de um Cluster Kubernetes

### Alta Disponibilidade

```bash
# Simular falha de um pod
kubectl delete pod <pod-name>

# Kubernetes recria automaticamente
kubectl get pods -w
```

### Auto-recuperação

```bash
# Ver eventos de recuperação
kubectl get events --sort-by='.lastTimestamp'
```

### Balanceamento de Carga

```bash
# Service distribui tráfego entre pods
kubectl get endpoints nginx

# Saída mostra IPs de todos os pods
# NAME    ENDPOINTS                           AGE
# nginx   10.244.1.2:80,10.244.2.3:80,...    5m
```

## Comandos Úteis para Gerenciar o Cluster

```bash
# Ver informações do cluster
kubectl cluster-info
kubectl cluster-info dump

# Ver todos os recursos
kubectl get all --all-namespaces

# Ver uso de recursos
kubectl top nodes
kubectl top pods

# Ver logs de componentes
kubectl logs -n kube-system kube-apiserver-<nome>

# Drenar nó (manutenção)
kubectl drain <node-name> --ignore-daemonsets

# Marcar nó como não agendável
kubectl cordon <node-name>

# Reativar nó
kubectl uncordon <node-name>

# Deletar cluster Kind
kind delete cluster --name meu-cluster
```

## Tipos de Clusters

### 1. Cluster Local (Desenvolvimento)

- **Kind** - Kubernetes in Docker
- **Minikube** - VM local
- **k3d** - k3s em Docker

### 2. Cluster Gerenciado (Produção)

- **EKS** - Amazon Elastic Kubernetes Service
- **GKE** - Google Kubernetes Engine
- **AKS** - Azure Kubernetes Service

### 3. Cluster On-Premises

- **kubeadm** - Ferramenta oficial
- **Rancher** - Plataforma de gerenciamento
- **OpenShift** - Plataforma Red Hat

## Resumo

Um cluster Kubernetes é:

- **Conjunto de máquinas** trabalhando juntas
- **Control Plane** gerencia o estado desejado
- **Workers** executam as aplicações
- **Comunicação** via kube-apiserver
- **Estado** armazenado no etcd
- **Auto-recuperação** e alta disponibilidade
- **Escalável** horizontal e verticalmente
- **Declarativo** - você define o estado desejado, Kubernetes mantém
