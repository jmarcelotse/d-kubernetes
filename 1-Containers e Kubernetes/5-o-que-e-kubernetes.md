# O que é o Kubernetes?

**Kubernetes** (também conhecido como K8s) é uma plataforma open source de orquestração de containers que automatiza a implantação, o dimensionamento e o gerenciamento de aplicações containerizadas.

## Origem

- **Criado por**: Google (baseado no sistema interno Borg)
- **Lançamento**: 2014
- **Governança**: Cloud Native Computing Foundation (CNCF) desde 2015
- **Nome**: Do grego "timoneiro" ou "piloto" (daí o logo do leme)
- **K8s**: Abreviação (K + 8 letras + s)

## O que o Kubernetes Faz?

### Orquestração de Containers
- Gerencia centenas ou milhares de containers
- Distribui containers entre múltiplos servidores (nodes)
- Garante que aplicações estejam sempre rodando
- Escala aplicações automaticamente

### Principais Funcionalidades

**1. Service Discovery e Load Balancing**
- Descobre containers automaticamente
- Distribui tráfego entre réplicas
- Expõe serviços via DNS ou IP

**2. Orquestração de Storage**
- Monta volumes automaticamente
- Suporta storage local, cloud (AWS EBS, Azure Disk) e NFS
- Gerencia persistent volumes

**3. Rollouts e Rollbacks Automatizados**
- Atualiza aplicações sem downtime
- Reverte para versão anterior em caso de falha
- Controla velocidade de deploy (rolling updates)

**4. Self-Healing**
- Reinicia containers que falham
- Substitui containers em nodes com problemas
- Mata containers que não respondem health checks

**5. Gerenciamento de Configuração e Secrets**
- Armazena configurações (ConfigMaps)
- Gerencia informações sensíveis (Secrets)
- Injeta configurações em containers

**6. Escalonamento Automático**
- Horizontal Pod Autoscaler (HPA): escala número de pods
- Vertical Pod Autoscaler (VPA): ajusta recursos de pods
- Cluster Autoscaler: adiciona/remove nodes

**7. Batch Execution**
- Executa jobs únicos ou recorrentes (CronJobs)
- Gerencia workloads batch e processamento paralelo

## Arquitetura do Kubernetes

```
┌─────────────────────────────────────────────────────────┐
│                    CONTROL PLANE                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ API Server   │  │  Scheduler   │  │  Controller  │  │
│  │              │  │              │  │   Manager    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │              etcd (Key-Value Store)              │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌──────▼─────────┐
│   Worker Node  │  │   Worker Node  │  │  Worker Node   │
│ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │
│ │  Kubelet   │ │  │ │  Kubelet   │ │  │ │  Kubelet   │ │
│ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │
│ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │
│ │ Kube-proxy │ │  │ │ Kube-proxy │ │  │ │ Kube-proxy │ │
│ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │
│ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │
│ │ Container  │ │  │ │ Container  │ │  │ │ Container  │ │
│ │  Runtime   │ │  │ │  Runtime   │ │  │ │  Runtime   │ │
│ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │
│  [Pods]        │  │  [Pods]        │  │  [Pods]        │
└────────────────┘  └────────────────┘  └────────────────┘
```

### Componentes do Control Plane

**API Server (kube-apiserver)**
- Front-end do Kubernetes
- Expõe a API REST
- Ponto de entrada para todos os comandos

**etcd**
- Banco de dados key-value distribuído
- Armazena todo o estado do cluster
- Backup crítico para recuperação

**Scheduler (kube-scheduler)**
- Decide em qual node cada pod será executado
- Considera recursos, constraints e políticas

**Controller Manager (kube-controller-manager)**
- Executa controllers que regulam o estado do cluster
- Node Controller, Replication Controller, Endpoints Controller, etc.

**Cloud Controller Manager**
- Integra com APIs de cloud providers
- Gerencia load balancers, volumes e networking cloud

### Componentes dos Worker Nodes

**Kubelet**
- Agente que roda em cada node
- Garante que containers estejam rodando nos pods
- Comunica com o API Server

**Kube-proxy**
- Proxy de rede em cada node
- Mantém regras de rede
- Permite comunicação entre pods

**Container Runtime**
- Software que executa containers
- Exemplos: containerd, CRI-O, Docker

## Objetos Principais do Kubernetes

### Pod
- Menor unidade deployável
- Agrupa um ou mais containers
- Compartilha rede e storage

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
```

### Deployment
- Gerencia ReplicaSets
- Declara estado desejado para pods
- Controla rollouts e rollbacks

```yaml
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
```

### Service
- Expõe pods como serviço de rede
- Load balancing entre pods
- Tipos: ClusterIP, NodePort, LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: LoadBalancer
```

### ConfigMap
- Armazena configurações não-sensíveis
- Desacopla configuração do código

### Secret
- Armazena informações sensíveis (senhas, tokens)
- Codificado em base64

### Namespace
- Isolamento lógico de recursos
- Multi-tenancy no mesmo cluster

### Ingress
- Gerencia acesso externo aos serviços
- Roteamento HTTP/HTTPS
- SSL/TLS termination

### Volume
- Armazena dados persistentes
- Sobrevive a reinicializações de containers

## Casos de Uso

### Microserviços
- Deploy e gerenciamento de arquiteturas distribuídas
- Service mesh e comunicação entre serviços

### CI/CD
- Pipelines de deploy automatizados
- Ambientes de teste efêmeros
- Blue-green e canary deployments

### Aplicações Cloud-Native
- Aplicações escaláveis e resilientes
- Multi-cloud e hybrid cloud

### Machine Learning
- Treinamento distribuído de modelos
- Serving de modelos em produção
- Kubeflow para ML workflows

### Big Data
- Processamento distribuído (Spark, Hadoop)
- Streaming de dados (Kafka)

## Distribuições e Serviços Kubernetes

### Kubernetes Gerenciados (Cloud)
- **Amazon EKS** (Elastic Kubernetes Service)
- **Google GKE** (Google Kubernetes Engine)
- **Azure AKS** (Azure Kubernetes Service)
- **DigitalOcean Kubernetes**

### Distribuições On-Premises
- **Red Hat OpenShift**
- **Rancher**
- **VMware Tanzu**
- **SUSE Rancher**

### Kubernetes Local/Desenvolvimento
- **Minikube**: Cluster local de um node
- **Kind** (Kubernetes in Docker): Clusters em containers
- **K3s**: Kubernetes leve para edge/IoT
- **MicroK8s**: Kubernetes mínimo da Canonical

## Ferramentas do Ecossistema

### CLI e Gerenciamento
- **kubectl**: CLI oficial do Kubernetes
- **k9s**: Interface TUI para gerenciar clusters
- **Lens**: IDE para Kubernetes
- **Octant**: Dashboard web

### Package Management
- **Helm**: Gerenciador de pacotes para Kubernetes
- **Kustomize**: Customização de manifests YAML

### Service Mesh
- **Istio**: Gerenciamento de tráfego e segurança
- **Linkerd**: Service mesh leve
- **Consul**: Service mesh e service discovery

### Monitoring e Observabilidade
- **Prometheus**: Monitoramento e alertas
- **Grafana**: Visualização de métricas
- **ELK Stack**: Logs centralizados
- **Jaeger**: Distributed tracing

### Segurança
- **Falco**: Runtime security
- **OPA** (Open Policy Agent): Policy enforcement
- **Trivy**: Vulnerability scanning

## Comandos Básicos

```bash
# Ver informações do cluster
kubectl cluster-info

# Listar nodes
kubectl get nodes

# Listar pods
kubectl get pods

# Criar recursos a partir de arquivo
kubectl apply -f deployment.yaml

# Ver logs de um pod
kubectl logs pod-name

# Executar comando em pod
kubectl exec -it pod-name -- /bin/bash

# Escalar deployment
kubectl scale deployment nginx-deployment --replicas=5

# Ver detalhes de um recurso
kubectl describe pod pod-name

# Deletar recursos
kubectl delete -f deployment.yaml
```

## Vantagens do Kubernetes

- **Portabilidade**: Roda em qualquer lugar (on-premises, cloud, hybrid)
- **Escalabilidade**: Escala horizontal automaticamente
- **Alta disponibilidade**: Self-healing e redundância
- **Declarativo**: Define estado desejado, K8s mantém
- **Extensível**: APIs e plugins customizados
- **Comunidade**: Ecossistema rico e ativo

## Desafios

- **Complexidade**: Curva de aprendizado íngreme
- **Overhead**: Pode ser excessivo para aplicações simples
- **Custo**: Requer recursos significativos
- **Segurança**: Configuração incorreta pode expor vulnerabilidades

## Quando Usar Kubernetes?

### Use Kubernetes quando:
- Tem múltiplos microserviços
- Precisa de alta disponibilidade
- Requer escalonamento automático
- Deploy em múltiplos ambientes
- Equipe com expertise em containers

### Considere alternativas quando:
- Aplicação monolítica simples
- Poucos containers
- Equipe pequena sem experiência
- Recursos limitados

## Recursos para Aprender

- **Documentação oficial**: https://kubernetes.io/docs/
- **Tutoriais interativos**: https://kubernetes.io/docs/tutorials/
- **Playground**: https://labs.play-with-k8s.com/
- **Certificações**: CKA, CKAD, CKS

---

## Exemplos Práticos

### Exemplo 1: Primeiro Pod

```bash
# Criar pod simples
kubectl run nginx --image=nginx --port=80

# Ver pod criado
kubectl get pods

# Ver detalhes
kubectl describe pod nginx

# Ver logs
kubectl logs nginx

# Acessar pod
kubectl exec -it nginx -- bash

# Deletar pod
kubectl delete pod nginx
```

### Exemplo 2: Deployment Completo

```yaml
# deployment.yaml
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
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

```bash
# Aplicar deployment
kubectl apply -f deployment.yaml

# Ver deployments
kubectl get deployments

# Ver pods criados
kubectl get pods -l app=webapp

# Escalar
kubectl scale deployment webapp --replicas=5

# Ver status do rollout
kubectl rollout status deployment webapp
```

### Exemplo 3: Service para Expor Aplicação

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: NodePort
```

```bash
# Criar service
kubectl apply -f service.yaml

# Ver services
kubectl get services

# Ver endpoints
kubectl get endpoints webapp-service

# Testar (minikube)
minikube service webapp-service
```

### Exemplo 4: ConfigMap e Secret

```bash
# Criar ConfigMap
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info

# Criar Secret
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=senha123

# Ver recursos
kubectl get configmaps
kubectl get secrets

# Usar em Pod
cat > pod-with-config.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: DB_PASSWORD
EOF

kubectl apply -f pod-with-config.yaml
kubectl exec app -- env | grep -E "APP_ENV|DB_PASSWORD"
```

### Exemplo 5: Stack Completa (Web + API + DB)

```yaml
# stack.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14
        env:
        - name: POSTGRES_PASSWORD
          value: senha123
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: myapp
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: myapp
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
      - name: api
        image: node:18-alpine
        command: ["sh", "-c", "npm install -g json-server && json-server --watch /data/db.json --host 0.0.0.0"]
        ports:
        - containerPort: 3000
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: myapp
spec:
  selector:
    app: api
  ports:
  - port: 3000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: myapp
spec:
  replicas: 3
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
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: myapp
spec:
  selector:
    app: frontend
  ports:
  - port: 80
  type: NodePort
```

```bash
# Aplicar stack completa
kubectl apply -f stack.yaml

# Ver recursos no namespace
kubectl get all -n myapp

# Ver pods
kubectl get pods -n myapp

# Ver services
kubectl get services -n myapp

# Logs da API
kubectl logs -n myapp -l app=api

# Limpar
kubectl delete namespace myapp
```

---

## Fluxo de Trabalho Kubernetes

```
┌─────────────────────────────────────────────────────┐
│         FLUXO DE DEPLOY NO KUBERNETES               │
└─────────────────────────────────────────────────────┘

1. DESENVOLVEDOR
   ├─> Escreve manifests YAML (Deployment, Service)
   └─> kubectl apply -f deployment.yaml

2. API SERVER
   ├─> Valida requisição
   ├─> Autentica e autoriza
   ├─> Persiste no etcd
   └─> Notifica controllers

3. CONTROLLER MANAGER
   ├─> Deployment Controller detecta novo Deployment
   ├─> Cria ReplicaSet
   └─> ReplicaSet Controller cria Pods

4. SCHEDULER
   ├─> Detecta Pods sem node atribuído
   ├─> Avalia recursos disponíveis
   ├─> Considera constraints e affinity
   └─> Atribui Pod a um node

5. KUBELET (no node escolhido)
   ├─> Detecta novo Pod atribuído
   ├─> Puxa imagem do container
   ├─> Chama container runtime
   └─> Inicia containers do Pod

6. KUBE-PROXY
   ├─> Detecta novo Service
   ├─> Configura regras iptables/ipvs
   └─> Habilita load balancing

7. APLICAÇÃO RODANDO
   └─> Pods recebendo tráfego via Service
```

---

## Comandos Essenciais

### Cluster

```bash
# Info do cluster
kubectl cluster-info

# Ver nodes
kubectl get nodes
kubectl describe node <node-name>

# Ver componentes do sistema
kubectl get pods -n kube-system
```

### Pods

```bash
# Listar pods
kubectl get pods
kubectl get pods -A  # todos os namespaces
kubectl get pods -o wide  # mais informações

# Criar pod
kubectl run nginx --image=nginx

# Ver detalhes
kubectl describe pod nginx

# Logs
kubectl logs nginx
kubectl logs -f nginx  # seguir logs

# Executar comando
kubectl exec nginx -- ls /
kubectl exec -it nginx -- bash

# Port forward
kubectl port-forward nginx 8080:80

# Deletar
kubectl delete pod nginx
```

### Deployments

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Listar
kubectl get deployments

# Escalar
kubectl scale deployment nginx --replicas=5

# Atualizar imagem
kubectl set image deployment/nginx nginx=nginx:alpine

# Ver histórico
kubectl rollout history deployment nginx

# Rollback
kubectl rollout undo deployment nginx

# Status do rollout
kubectl rollout status deployment nginx

# Deletar
kubectl delete deployment nginx
```

### Services

```bash
# Expor deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Listar services
kubectl get services

# Ver detalhes
kubectl describe service nginx

# Deletar
kubectl delete service nginx
```

### Namespaces

```bash
# Listar namespaces
kubectl get namespaces

# Criar namespace
kubectl create namespace dev

# Usar namespace
kubectl get pods -n dev
kubectl apply -f deployment.yaml -n dev

# Deletar namespace
kubectl delete namespace dev
```

### ConfigMaps e Secrets

```bash
# ConfigMap
kubectl create configmap app-config --from-literal=key=value
kubectl get configmaps
kubectl describe configmap app-config

# Secret
kubectl create secret generic app-secret --from-literal=password=123
kubectl get secrets
kubectl describe secret app-secret
```

### Debug

```bash
# Ver eventos
kubectl get events --sort-by='.lastTimestamp'

# Ver logs de pod que crashou
kubectl logs <pod-name> --previous

# Debug de pod
kubectl debug <pod-name> -it --image=busybox

# Ver uso de recursos
kubectl top nodes
kubectl top pods
```

---

## Exemplo Completo: Do Zero ao Deploy

```bash
# 1. Criar cluster local (kind)
kind create cluster --name meu-cluster

# 2. Verificar cluster
kubectl cluster-info
kubectl get nodes

# 3. Criar namespace
kubectl create namespace producao

# 4. Criar deployment
cat > app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minha-app
  namespace: producao
spec:
  replicas: 3
  selector:
    matchLabels:
      app: minha-app
  template:
    metadata:
      labels:
        app: minha-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: minha-app
  namespace: producao
spec:
  selector:
    app: minha-app
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF

# 5. Aplicar
kubectl apply -f app.yaml

# 6. Verificar
kubectl get all -n producao

# 7. Ver pods
kubectl get pods -n producao -o wide

# 8. Ver logs
kubectl logs -n producao -l app=minha-app

# 9. Testar
kubectl port-forward -n producao service/minha-app 8080:80
# Acessar: http://localhost:8080

# 10. Escalar
kubectl scale deployment minha-app -n producao --replicas=5

# 11. Atualizar
kubectl set image deployment/minha-app -n producao nginx=nginx:latest

# 12. Ver rollout
kubectl rollout status deployment/minha-app -n producao

# 13. Limpar
kubectl delete namespace producao
kind delete cluster --name meu-cluster
```
