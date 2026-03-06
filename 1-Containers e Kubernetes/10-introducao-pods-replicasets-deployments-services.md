# Introdução a Pods, ReplicaSets, Deployments e Services

Estes são os quatro objetos fundamentais do Kubernetes para executar e expor aplicações. Cada um tem um propósito específico e trabalham em conjunto para criar aplicações resilientes e escaláveis.

## Hierarquia e Relacionamento

```
Service (expõe aplicação)
    ↓
Deployment (gerencia versões)
    ↓
ReplicaSet (garante réplicas)
    ↓
Pod (executa containers)
    ↓
Container (aplicação)
```

## 1. Pod

### O que é?

**Pod** é a menor e mais básica unidade deployável no Kubernetes. Representa um ou mais containers que compartilham recursos e são executados juntos no mesmo node.

### Características

- **Unidade atômica**: Menor objeto que pode ser criado e gerenciado
- **Compartilhamento**: Containers no mesmo pod compartilham:
  - Endereço IP
  - Namespace de rede
  - Volumes
  - Hostname
- **Efêmero**: Pods são temporários e podem ser destruídos/recriados a qualquer momento
- **Um IP por pod**: Cada pod recebe um IP único no cluster

### Quando usar?

- **Single container**: Caso mais comum (1 container por pod)
- **Multi-container**: Containers fortemente acoplados que precisam compartilhar recursos
  - Sidecar pattern (logging, proxy)
  - Ambassador pattern (proxy de comunicação)
  - Adapter pattern (normalização de dados)

### Exemplo Básico

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
```

### Exemplo Multi-Container (Sidecar)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  containers:
  # Container principal
  - name: app
    image: myapp:1.0
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  
  # Sidecar para logs
  - name: log-shipper
    image: fluentd:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  
  volumes:
  - name: logs
    emptyDir: {}
```

### Ciclo de Vida do Pod

```
Pending → Running → Succeeded/Failed
   ↓         ↓
 Pulling  CrashLoopBackOff
 Images   (se falhar)
```

**Fases:**
- **Pending**: Pod aceito, mas containers ainda não criados
- **Running**: Pod vinculado a node, pelo menos um container rodando
- **Succeeded**: Todos os containers terminaram com sucesso
- **Failed**: Todos os containers terminaram, pelo menos um falhou
- **Unknown**: Estado do pod não pode ser determinado

### Comandos Básicos

```bash
# Criar pod
kubectl apply -f pod.yaml
kubectl run nginx --image=nginx

# Listar pods
kubectl get pods
kubectl get pods -o wide

# Detalhes do pod
kubectl describe pod nginx-pod

# Logs
kubectl logs nginx-pod
kubectl logs nginx-pod -c container-name  # Multi-container

# Executar comando
kubectl exec nginx-pod -- ls /
kubectl exec -it nginx-pod -- /bin/bash

# Deletar pod
kubectl delete pod nginx-pod
```

### Limitações

- **Não se auto-recupera**: Se um pod morre, não é recriado automaticamente
- **Não escala**: Um pod = uma instância
- **Sem rolling updates**: Atualizar requer deletar e recriar
- **Gerenciamento manual**: Você precisa gerenciar cada pod individualmente

**Solução**: Use controllers como ReplicaSet e Deployment

## 2. ReplicaSet

### O que é?

**ReplicaSet** é um controller que garante que um número específico de réplicas de pods esteja rodando a qualquer momento.

### Características

- **Self-healing**: Recria pods que falham
- **Escalabilidade**: Mantém número desejado de réplicas
- **Seletor de labels**: Identifica pods que gerencia
- **Template de pod**: Define como criar novos pods

### Quando usar?

- **Raramente diretamente**: Normalmente você usa Deployments
- **Casos específicos**: Quando precisa apenas de replicação sem rolling updates

### Exemplo

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  labels:
    app: nginx
spec:
  replicas: 3  # Número desejado de pods
  selector:
    matchLabels:
      app: nginx  # Seleciona pods com esta label
  template:
    metadata:
      labels:
        app: nginx  # Label dos pods criados
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```

### Como Funciona

```
ReplicaSet Controller (loop contínuo):
1. Conta pods com label "app: nginx"
2. Compara com replicas desejadas (3)
3. Se < 3: Cria novos pods
4. Se > 3: Deleta pods extras
5. Aguarda e repete
```

**Exemplo de auto-recuperação:**
```bash
# ReplicaSet com 3 réplicas
kubectl get pods
# nginx-rs-abc  Running
# nginx-rs-def  Running
# nginx-rs-ghi  Running

# Deletar um pod
kubectl delete pod nginx-rs-abc

# ReplicaSet cria automaticamente um novo
kubectl get pods
# nginx-rs-def  Running
# nginx-rs-ghi  Running
# nginx-rs-jkl  Running  ← Novo pod criado
```

### Escalando

```bash
# Escalar para 5 réplicas
kubectl scale replicaset nginx-replicaset --replicas=5

# Ou editar o YAML
kubectl edit replicaset nginx-replicaset

# Verificar
kubectl get replicaset
# NAME               DESIRED   CURRENT   READY
# nginx-replicaset   5         5         5
```

### Comandos Básicos

```bash
# Criar ReplicaSet
kubectl apply -f replicaset.yaml

# Listar ReplicaSets
kubectl get replicaset
kubectl get rs  # Abreviação

# Detalhes
kubectl describe replicaset nginx-replicaset

# Escalar
kubectl scale rs nginx-replicaset --replicas=5

# Deletar (deleta pods também)
kubectl delete replicaset nginx-replicaset

# Deletar sem deletar pods
kubectl delete replicaset nginx-replicaset --cascade=orphan
```

### Limitações

- **Sem rolling updates**: Atualizar imagem não atualiza pods existentes
- **Sem rollback**: Não mantém histórico de versões
- **Sem estratégias de deploy**: Não controla como updates acontecem

**Solução**: Use Deployment

## 3. Deployment

### O que é?

**Deployment** é um controller de nível superior que gerencia ReplicaSets e fornece atualizações declarativas para pods.

### Características

- **Rolling updates**: Atualiza pods gradualmente sem downtime
- **Rollback**: Reverte para versões anteriores
- **Histórico de revisões**: Mantém histórico de ReplicaSets
- **Estratégias de deploy**: Controla como updates acontecem
- **Pause/Resume**: Pode pausar e retomar rollouts

### Quando usar?

- **Sempre para aplicações stateless**: É o objeto recomendado
- **Produção**: Quando precisa de updates sem downtime
- **Gerenciamento de versões**: Quando precisa de rollback

### Exemplo

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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
```

### Como Funciona

```
Deployment
    ↓ (cria e gerencia)
ReplicaSet v1 (3 pods nginx:1.21)
    ↓
Pod, Pod, Pod

# Após atualizar imagem para nginx:1.22
Deployment
    ↓
ReplicaSet v1 (0 pods nginx:1.21) ← Mantido para rollback
ReplicaSet v2 (3 pods nginx:1.22) ← Novo ReplicaSet
    ↓
Pod, Pod, Pod
```

### Estratégias de Deploy

#### RollingUpdate (Padrão)

Atualiza pods gradualmente, mantendo aplicação disponível.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Máximo de pods extras durante update
      maxUnavailable: 1  # Máximo de pods indisponíveis durante update
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
```

**Processo:**
```
Inicial: 10 pods v1
Step 1:  9 pods v1, 2 pods v2  (maxSurge=2, maxUnavailable=1)
Step 2:  7 pods v1, 4 pods v2
Step 3:  5 pods v1, 6 pods v2
Step 4:  3 pods v1, 8 pods v2
Step 5:  1 pod  v1, 10 pods v2
Final:   0 pods v1, 10 pods v2
```

#### Recreate

Deleta todos os pods antes de criar novos (causa downtime).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  strategy:
    type: Recreate
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
```

**Processo:**
```
Inicial: 3 pods v1
Step 1:  0 pods (downtime!)
Step 2:  3 pods v2
```

**Quando usar Recreate:**
- Aplicação não suporta múltiplas versões simultâneas
- Banco de dados com schema incompatível
- Recursos compartilhados que não podem ter múltiplas versões

### Rolling Update em Ação

```bash
# Criar deployment
kubectl apply -f deployment.yaml

# Verificar status
kubectl get deployment
kubectl get replicaset
kubectl get pods

# Atualizar imagem (trigger rolling update)
kubectl set image deployment/nginx-deployment nginx=nginx:1.22

# Acompanhar rollout
kubectl rollout status deployment/nginx-deployment

# Ver histórico
kubectl rollout history deployment/nginx-deployment

# Rollback para versão anterior
kubectl rollout undo deployment/nginx-deployment

# Rollback para revisão específica
kubectl rollout undo deployment/nginx-deployment --to-revision=2

# Pausar rollout
kubectl rollout pause deployment/nginx-deployment

# Retomar rollout
kubectl rollout resume deployment/nginx-deployment
```

### Exemplo Completo com Resources e Probes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
  labels:
    app: myapp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v1
    spec:
      containers:
      - name: myapp
        image: myapp:1.0
        ports:
        - containerPort: 8080
        
        # Resource limits
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        
        # Environment variables
        env:
        - name: ENV
          value: "production"
        - name: DB_HOST
          value: "postgres.default.svc.cluster.local"
```

### Comandos Básicos

```bash
# Criar deployment
kubectl apply -f deployment.yaml
kubectl create deployment nginx --image=nginx --replicas=3

# Listar deployments
kubectl get deployments
kubectl get deploy  # Abreviação

# Detalhes
kubectl describe deployment nginx-deployment

# Escalar
kubectl scale deployment nginx-deployment --replicas=5

# Atualizar imagem
kubectl set image deployment/nginx-deployment nginx=nginx:1.22

# Ver status do rollout
kubectl rollout status deployment/nginx-deployment

# Histórico
kubectl rollout history deployment/nginx-deployment

# Rollback
kubectl rollout undo deployment/nginx-deployment

# Pausar/Retomar
kubectl rollout pause deployment/nginx-deployment
kubectl rollout resume deployment/nginx-deployment

# Deletar
kubectl delete deployment nginx-deployment
```

## 4. Service

### O que é?

**Service** é uma abstração que define um conjunto lógico de pods e uma política para acessá-los. Fornece um endpoint estável (IP e DNS) para acessar pods que podem ser efêmeros.

### Por que precisamos?

**Problema:**
- Pods são efêmeros (IPs mudam quando recriam)
- Múltiplas réplicas (qual IP usar?)
- Load balancing entre réplicas

**Solução:**
- Service fornece IP estável (ClusterIP)
- DNS name estável
- Load balancing automático

### Características

- **IP virtual estável**: ClusterIP não muda
- **DNS**: Nome DNS automático (`service-name.namespace.svc.cluster.local`)
- **Load balancing**: Distribui tráfego entre pods
- **Service discovery**: Pods podem encontrar services via DNS
- **Seletor de labels**: Identifica pods backend

### Tipos de Services

#### 1. ClusterIP (Padrão)

Expõe Service em IP interno do cluster. Acessível apenas dentro do cluster.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx  # Seleciona pods com esta label
  ports:
  - protocol: TCP
    port: 80        # Porta do Service
    targetPort: 80  # Porta do container
```

**Uso:**
- Comunicação entre microserviços
- Backend services
- Bancos de dados

**Acesso:**
```bash
# Dentro do cluster
curl http://nginx-service:80
curl http://nginx-service.default.svc.cluster.local:80
```

#### 2. NodePort

Expõe Service em porta estática de cada node. Acessível externamente via `<NodeIP>:<NodePort>`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080  # Porta no node (30000-32767)
```

**Uso:**
- Desenvolvimento/teste
- Acesso externo simples
- Quando não tem load balancer

**Acesso:**
```bash
# De fora do cluster
curl http://<node-ip>:30080
curl http://192.168.1.10:30080
```

**Fluxo:**
```
Cliente → NodeIP:30080 → Service → Pod:80
```

#### 3. LoadBalancer

Cria load balancer externo (cloud provider). Expõe Service externamente.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

**Uso:**
- Produção em cloud
- Aplicações web públicas
- APIs externas

**Acesso:**
```bash
# Via load balancer DNS/IP
curl http://a1b2c3d4.us-east-1.elb.amazonaws.com
```

**Fluxo:**
```
Internet → Cloud LB → NodePort → Service → Pod
```

#### 4. ExternalName

Mapeia Service para nome DNS externo. Não usa seletor ou endpoints.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: api.example.com
```

**Uso:**
- Integração com serviços externos
- Migração gradual para Kubernetes
- Abstração de endpoints externos

**Acesso:**
```bash
# Dentro do cluster
curl http://external-api
# Resolve para api.example.com
```

### Como Service Encontra Pods

Service usa **labels** para selecionar pods:

```yaml
# Deployment cria pods com label "app: nginx"
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
        app: nginx  # ← Label do pod
    spec:
      containers:
      - name: nginx
        image: nginx

---
# Service seleciona pods com label "app: nginx"
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx  # ← Seleciona pods com esta label
  ports:
  - port: 80
    targetPort: 80
```

**Endpoints:**
```bash
# Service cria automaticamente Endpoints
kubectl get endpoints nginx-service

# Output:
# NAME            ENDPOINTS
# nginx-service   10.244.1.5:80,10.244.2.3:80,10.244.3.7:80
```

### Session Affinity

Mantém cliente conectado ao mesmo pod:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 horas
  ports:
  - port: 80
    targetPort: 80
```

### Multi-Port Services

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
  - name: https
    protocol: TCP
    port: 443
    targetPort: 8443
  - name: metrics
    protocol: TCP
    port: 9090
    targetPort: 9090
```

### Comandos Básicos

```bash
# Criar service
kubectl apply -f service.yaml
kubectl expose deployment nginx-deployment --port=80 --type=ClusterIP

# Listar services
kubectl get services
kubectl get svc  # Abreviação

# Detalhes
kubectl describe service nginx-service

# Ver endpoints
kubectl get endpoints nginx-service

# Testar service (de dentro do cluster)
kubectl run test --image=busybox -it --rm -- wget -O- nginx-service:80

# Port-forward (acesso local)
kubectl port-forward service/nginx-service 8080:80
# Acesso: http://localhost:8080

# Deletar
kubectl delete service nginx-service
```

## Exemplo Completo: Deployment + Service

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
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
      - name: webapp
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3

---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

**Deploy:**
```bash
# Aplicar
kubectl apply -f deployment.yaml

# Verificar
kubectl get deployment
kubectl get pods
kubectl get service

# Testar
curl http://<load-balancer-ip>
```

## Fluxo Completo

```
1. Criar Deployment
   ↓
2. Deployment cria ReplicaSet
   ↓
3. ReplicaSet cria Pods (3 réplicas)
   ↓
4. Pods recebem IPs (10.244.1.5, 10.244.2.3, 10.244.3.7)
   ↓
5. Criar Service
   ↓
6. Service seleciona Pods via labels
   ↓
7. Service cria Endpoints com IPs dos Pods
   ↓
8. Service recebe ClusterIP estável (10.96.100.50)
   ↓
9. DNS entry criado (webapp-service.default.svc.cluster.local)
   ↓
10. Clientes acessam via Service
    ↓
11. kube-proxy faz load balancing para Pods
```

## Comparação Rápida

| Objeto | Propósito | Gerencia | Auto-recupera | Escala | Updates | Expõe |
|--------|-----------|----------|---------------|--------|---------|-------|
| Pod | Executa containers | - | ❌ | ❌ | ❌ | ❌ |
| ReplicaSet | Mantém réplicas | Pods | ✅ | ✅ | ❌ | ❌ |
| Deployment | Gerencia versões | ReplicaSets | ✅ | ✅ | ✅ | ❌ |
| Service | Expõe aplicação | - | - | - | - | ✅ |

## Boas Práticas

### Pods
- Não crie pods diretamente em produção
- Use sempre via Deployment/ReplicaSet
- Configure resource requests e limits
- Implemente health probes

### ReplicaSets
- Não use diretamente, use Deployment
- Útil apenas para casos específicos

### Deployments
- Use para todas as aplicações stateless
- Configure rolling update strategy
- Defina maxSurge e maxUnavailable apropriadamente
- Mantenha histórico de revisões
- Use labels consistentes

### Services
- Use ClusterIP para comunicação interna
- Use LoadBalancer para acesso externo em produção
- Configure session affinity quando necessário
- Use nomes de service descritivos
- Documente portas expostas

## Troubleshooting

### Pod não inicia
```bash
# Ver eventos
kubectl describe pod <pod-name>

# Ver logs
kubectl logs <pod-name>

# Verificar imagem
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'
```

### ReplicaSet não cria pods
```bash
# Verificar seletor
kubectl describe replicaset <rs-name>

# Verificar eventos
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Deployment stuck
```bash
# Ver status
kubectl rollout status deployment/<name>

# Ver histórico
kubectl rollout history deployment/<name>

# Rollback
kubectl rollout undo deployment/<name>
```

### Service não alcança pods
```bash
# Verificar endpoints
kubectl get endpoints <service-name>

# Verificar labels
kubectl get pods --show-labels

# Testar conectividade
kubectl run test --image=busybox -it --rm -- wget -O- <service-name>:<port>
```

## Próximos Passos

Após dominar estes conceitos básicos, explore:
- **StatefulSets**: Para aplicações stateful
- **DaemonSets**: Para pods em todos os nodes
- **Jobs e CronJobs**: Para tarefas batch
- **Ingress**: Para roteamento HTTP avançado
- **ConfigMaps e Secrets**: Para configuração
- **Persistent Volumes**: Para armazenamento persistente


---

## Exemplos Práticos

### Exemplo 1: Criar e Gerenciar Pods

```bash
# Criar pod simples
kubectl run nginx --image=nginx

# Ver pod
kubectl get pods

# Ver detalhes
kubectl describe pod nginx

# Ver logs
kubectl logs nginx

# Acessar pod
kubectl exec -it nginx -- bash

# Deletar pod
kubectl delete pod nginx

# Criar pod com YAML
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF
```

### Exemplo 2: Trabalhar com ReplicaSets

```bash
# Criar ReplicaSet
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
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
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

# Ver ReplicaSet
kubectl get replicasets
kubectl get rs

# Ver pods criados
kubectl get pods -l app=nginx

# Escalar ReplicaSet
kubectl scale replicaset nginx-replicaset --replicas=5

# Ver eventos
kubectl describe replicaset nginx-replicaset

# Deletar um pod (ReplicaSet recria automaticamente)
kubectl delete pod <pod-name>
kubectl get pods -w

# Deletar ReplicaSet
kubectl delete replicaset nginx-replicaset
```

### Exemplo 3: Deployments Completos

```bash
# Criar Deployment
kubectl create deployment nginx --image=nginx:1.21 --replicas=3

# Ver Deployment
kubectl get deployments

# Ver ReplicaSet criado
kubectl get replicasets

# Ver pods
kubectl get pods

# Escalar Deployment
kubectl scale deployment nginx --replicas=5

# Atualizar imagem (rolling update)
kubectl set image deployment/nginx nginx=nginx:1.22

# Ver status do rollout
kubectl rollout status deployment/nginx

# Ver histórico
kubectl rollout history deployment/nginx

# Rollback
kubectl rollout undo deployment/nginx

# Pausar rollout
kubectl rollout pause deployment/nginx

# Retomar rollout
kubectl rollout resume deployment/nginx

# Deletar Deployment
kubectl delete deployment nginx
```

### Exemplo 4: Services - ClusterIP

```bash
# Criar Deployment
kubectl create deployment webapp --image=nginx --replicas=3

# Expor como ClusterIP (padrão)
kubectl expose deployment webapp --port=80 --target-port=80

# Ver Service
kubectl get services

# Ver endpoints
kubectl get endpoints webapp

# Testar de dentro do cluster
kubectl run test --image=busybox -it --rm -- wget -O- webapp:80

# Ver detalhes
kubectl describe service webapp

# Deletar
kubectl delete service webapp
kubectl delete deployment webapp
```

### Exemplo 5: Services - NodePort

```bash
# Criar Deployment
kubectl create deployment webapp --image=nginx --replicas=3

# Expor como NodePort
kubectl expose deployment webapp --type=NodePort --port=80

# Ver porta atribuída
kubectl get service webapp

# Testar (substitua <node-ip> e <node-port>)
curl http://<node-ip>:<node-port>

# Ou especificar NodePort
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: webapp-nodeport
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# Testar
curl http://<node-ip>:30080
```

### Exemplo 6: Services - LoadBalancer

```bash
# Criar Deployment
kubectl create deployment webapp --image=nginx --replicas=3

# Expor como LoadBalancer (requer cloud provider)
kubectl expose deployment webapp --type=LoadBalancer --port=80

# Ver Service (aguardar EXTERNAL-IP)
kubectl get service webapp -w

# Testar
curl http://<external-ip>

# Ver detalhes
kubectl describe service webapp
```

### Exemplo 7: Stack Completa

```bash
# Criar namespace
kubectl create namespace myapp

# Deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: myapp
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
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: myapp
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# Verificar tudo
kubectl get all -n myapp

# Testar
curl http://<node-ip>:30080

# Escalar
kubectl scale deployment webapp -n myapp --replicas=5

# Atualizar
kubectl set image deployment/webapp -n myapp nginx=nginx:latest

# Ver rollout
kubectl rollout status deployment/webapp -n myapp

# Limpar
kubectl delete namespace myapp
```

---

## Fluxo Completo: Pod → ReplicaSet → Deployment → Service

```
┌─────────────────────────────────────────────────────────┐
│         HIERARQUIA E FLUXO DE RECURSOS                  │
└─────────────────────────────────────────────────────────┘

1. POD (Unidade Básica)
   ├─> Container(s) rodando
   ├─> IP efêmero
   └─> Pode morrer a qualquer momento

2. REPLICASET (Gerencia Pods)
   ├─> Mantém N réplicas de Pods
   ├─> Recria Pods que morrem
   ├─> Usa selector para identificar Pods
   └─> Raramente criado diretamente

3. DEPLOYMENT (Gerencia ReplicaSets)
   ├─> Cria e gerencia ReplicaSets
   ├─> Rolling updates
   ├─> Rollbacks
   ├─> Histórico de versões
   └─> Forma recomendada de deploy

4. SERVICE (Expõe Pods)
   ├─> IP estável (ClusterIP)
   ├─> DNS name (service-name.namespace.svc.cluster.local)
   ├─> Load balancing entre Pods
   ├─> Tipos: ClusterIP, NodePort, LoadBalancer
   └─> Desacopla consumidores de Pods

FLUXO DE CRIAÇÃO:
kubectl create deployment nginx --image=nginx --replicas=3
   ↓
Deployment criado
   ↓
Deployment cria ReplicaSet
   ↓
ReplicaSet cria 3 Pods
   ↓
Scheduler atribui Pods a Nodes
   ↓
Kubelet inicia containers
   ↓
kubectl expose deployment nginx --port=80
   ↓
Service criado
   ↓
Endpoints apontam para Pods
   ↓
Kube-proxy configura iptables
   ↓
Tráfego pode chegar aos Pods via Service
```

---

## Comparação dos Recursos

| Recurso | Propósito | Quando Usar | Gerencia |
|---------|-----------|-------------|----------|
| **Pod** | Executar container(s) | Testes rápidos | Nada |
| **ReplicaSet** | Manter N réplicas | Raramente direto | Pods |
| **Deployment** | Deploy com rollout | Aplicações stateless | ReplicaSets |
| **Service** | Expor aplicação | Sempre que precisar acesso | Endpoints |

---

## Troubleshooting

### Pod não Inicia

```bash
# Ver status
kubectl describe pod <pod-name>

# Ver eventos
kubectl get events --sort-by='.lastTimestamp' | grep <pod-name>

# Ver logs
kubectl logs <pod-name>

# Problemas comuns:
# - ImagePullBackOff: imagem não existe
# - CrashLoopBackOff: container crashando
# - Pending: sem recursos ou node disponível
```

### ReplicaSet não Cria Pods

```bash
# Ver ReplicaSet
kubectl describe replicaset <rs-name>

# Verificar selector
kubectl get replicaset <rs-name> -o yaml | grep -A 5 selector

# Ver eventos
kubectl get events | grep <rs-name>
```

### Service não Funciona

```bash
# Verificar Service
kubectl describe service <service-name>

# Verificar endpoints
kubectl get endpoints <service-name>

# Se endpoints vazio, verificar selector
kubectl get service <service-name> -o yaml | grep -A 3 selector
kubectl get pods --show-labels

# Testar de dentro do cluster
kubectl run test --image=busybox -it --rm -- wget -O- <service-name>
```

### Deployment Travado

```bash
# Ver status
kubectl rollout status deployment/<deployment-name>

# Ver histórico
kubectl rollout history deployment/<deployment-name>

# Ver eventos
kubectl describe deployment <deployment-name>

# Rollback
kubectl rollout undo deployment/<deployment-name>
```
