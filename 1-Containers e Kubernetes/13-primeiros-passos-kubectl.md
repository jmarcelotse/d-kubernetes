# Primeiros Passos no Kubernetes com kubectl

Este guia prático ensina os comandos essenciais do kubectl para começar a trabalhar com Kubernetes, desde a verificação do cluster até o deploy de aplicações.

## Verificando o Ambiente

### Verificar Instalação

```bash
# Versão do kubectl
kubectl version --client

# Versão do cliente e servidor
kubectl version

# Informações do cluster
kubectl cluster-info

# Ver context atual
kubectl config current-context

# Ver configuração
kubectl config view
```

### Verificar Nodes

```bash
# Listar nodes do cluster
kubectl get nodes

# Detalhes de um node
kubectl describe node <node-name>

# Ver nodes com mais informações
kubectl get nodes -o wide

# Ver labels dos nodes
kubectl get nodes --show-labels
```

## Sintaxe Básica do kubectl

```bash
kubectl [comando] [tipo] [nome] [flags]
```

**Exemplos:**
```bash
kubectl get pods
kubectl describe pod nginx-pod
kubectl delete deployment nginx-deployment
kubectl logs my-pod -f
```

## Comandos Essenciais

### 1. get - Listar Recursos

```bash
# Listar pods
kubectl get pods
kubectl get po  # Abreviação

# Listar todos os recursos
kubectl get all

# Listar services
kubectl get services
kubectl get svc  # Abreviação

# Listar deployments
kubectl get deployments
kubectl get deploy  # Abreviação

# Listar replicasets
kubectl get replicasets
kubectl get rs  # Abreviação

# Listar namespaces
kubectl get namespaces
kubectl get ns  # Abreviação

# Listar em todos os namespaces
kubectl get pods --all-namespaces
kubectl get pods -A  # Abreviação

# Listar em namespace específico
kubectl get pods -n kube-system

# Output com mais informações
kubectl get pods -o wide

# Output em YAML
kubectl get pod nginx-pod -o yaml

# Output em JSON
kubectl get pod nginx-pod -o json

# Listar com labels
kubectl get pods --show-labels

# Filtrar por label
kubectl get pods -l app=nginx
kubectl get pods -l 'env in (prod,staging)'

# Watch (atualização contínua)
kubectl get pods --watch
kubectl get pods -w
```

### 2. describe - Detalhes de Recursos

```bash
# Detalhes de um pod
kubectl describe pod nginx-pod

# Detalhes de um service
kubectl describe service nginx-service

# Detalhes de um deployment
kubectl describe deployment nginx-deployment

# Detalhes de um node
kubectl describe node node-1

# Ver eventos do recurso
kubectl describe pod nginx-pod | grep Events -A 20
```

### 3. create - Criar Recursos (Imperativo)

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx

# Criar deployment com réplicas
kubectl create deployment nginx --image=nginx --replicas=3

# Criar service
kubectl create service clusterip nginx --tcp=80:80

# Criar namespace
kubectl create namespace dev

# Criar configmap
kubectl create configmap app-config --from-literal=ENV=production

# Criar secret
kubectl create secret generic db-secret --from-literal=password=mypassword

# Criar job
kubectl create job hello --image=busybox -- echo "Hello World"

# Criar cronjob
kubectl create cronjob hello --image=busybox --schedule="*/5 * * * *" -- echo "Hello"
```

### 4. apply - Aplicar Configuração (Declarativo)

```bash
# Aplicar arquivo YAML
kubectl apply -f deployment.yaml

# Aplicar múltiplos arquivos
kubectl apply -f deployment.yaml -f service.yaml

# Aplicar diretório inteiro
kubectl apply -f ./manifests/

# Aplicar recursivamente
kubectl apply -f ./manifests/ -R

# Aplicar de URL
kubectl apply -f https://example.com/deployment.yaml
```

### 5. delete - Deletar Recursos

```bash
# Deletar pod
kubectl delete pod nginx-pod

# Deletar deployment
kubectl delete deployment nginx-deployment

# Deletar service
kubectl delete service nginx-service

# Deletar via arquivo
kubectl delete -f deployment.yaml

# Deletar por label
kubectl delete pods -l app=nginx

# Deletar todos os pods
kubectl delete pods --all

# Deletar namespace (e todos os recursos nele)
kubectl delete namespace dev

# Forçar deleção
kubectl delete pod nginx-pod --force --grace-period=0
```

### 6. logs - Ver Logs

```bash
# Logs de um pod
kubectl logs nginx-pod

# Logs com follow (tempo real)
kubectl logs nginx-pod -f

# Logs de container específico (multi-container pod)
kubectl logs nginx-pod -c nginx

# Últimas N linhas
kubectl logs nginx-pod --tail=50

# Logs desde timestamp
kubectl logs nginx-pod --since=1h
kubectl logs nginx-pod --since=2024-01-01T10:00:00Z

# Logs de todos os pods de um deployment
kubectl logs -l app=nginx

# Logs anteriores (container que crashou)
kubectl logs nginx-pod --previous
```

### 7. exec - Executar Comandos

```bash
# Executar comando
kubectl exec nginx-pod -- ls /

# Executar comando com argumentos
kubectl exec nginx-pod -- cat /etc/nginx/nginx.conf

# Shell interativo
kubectl exec -it nginx-pod -- /bin/bash
kubectl exec -it nginx-pod -- /bin/sh

# Executar em container específico
kubectl exec -it nginx-pod -c nginx -- /bin/bash

# Executar comando e sair
kubectl exec nginx-pod -- env
```

### 8. port-forward - Encaminhar Portas

```bash
# Encaminhar porta de pod
kubectl port-forward pod/nginx-pod 8080:80

# Encaminhar porta de service
kubectl port-forward service/nginx-service 8080:80

# Encaminhar porta de deployment
kubectl port-forward deployment/nginx-deployment 8080:80

# Múltiplas portas
kubectl port-forward pod/nginx-pod 8080:80 8443:443

# Escutar em todas as interfaces
kubectl port-forward --address 0.0.0.0 pod/nginx-pod 8080:80

# Acessar: http://localhost:8080
```

### 9. edit - Editar Recursos

```bash
# Editar deployment
kubectl edit deployment nginx-deployment

# Editar service
kubectl edit service nginx-service

# Editar com editor específico
KUBE_EDITOR="nano" kubectl edit deployment nginx-deployment
```

### 10. scale - Escalar Recursos

```bash
# Escalar deployment
kubectl scale deployment nginx-deployment --replicas=5

# Escalar replicaset
kubectl scale replicaset nginx-rs --replicas=3

# Escalar statefulset
kubectl scale statefulset web --replicas=3

# Escalar com condição
kubectl scale deployment nginx-deployment --replicas=5 --current-replicas=3
```

## Trabalhando com Pods

### Criar Pod Simples

```bash
# Criar pod imperativo
kubectl run nginx --image=nginx

# Criar pod com porta
kubectl run nginx --image=nginx --port=80

# Criar pod com variáveis de ambiente
kubectl run nginx --image=nginx --env="ENV=production"

# Criar pod e expor
kubectl run nginx --image=nginx --port=80 --expose

# Dry-run (gerar YAML sem criar)
kubectl run nginx --image=nginx --dry-run=client -o yaml

# Salvar YAML em arquivo
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
```

### Gerenciar Pods

```bash
# Listar pods
kubectl get pods

# Ver detalhes
kubectl describe pod nginx

# Ver logs
kubectl logs nginx

# Acessar shell
kubectl exec -it nginx -- /bin/bash

# Copiar arquivos
kubectl cp nginx:/etc/nginx/nginx.conf ./nginx.conf
kubectl cp ./index.html nginx:/usr/share/nginx/html/

# Deletar pod
kubectl delete pod nginx
```

### Pod com Arquivo YAML

```yaml
# pod.yaml
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

```bash
# Criar pod
kubectl apply -f pod.yaml

# Verificar
kubectl get pod nginx-pod

# Testar
kubectl port-forward pod/nginx-pod 8080:80
curl http://localhost:8080
```

## Trabalhando com Deployments

### Criar Deployment

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Ou com YAML
cat <<EOF | kubectl apply -f -
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
EOF
```

### Gerenciar Deployments

```bash
# Listar deployments
kubectl get deployments

# Ver detalhes
kubectl describe deployment nginx-deployment

# Ver pods do deployment
kubectl get pods -l app=nginx

# Escalar
kubectl scale deployment nginx-deployment --replicas=5

# Atualizar imagem
kubectl set image deployment/nginx-deployment nginx=nginx:1.22

# Ver status do rollout
kubectl rollout status deployment/nginx-deployment

# Ver histórico
kubectl rollout history deployment/nginx-deployment

# Rollback
kubectl rollout undo deployment/nginx-deployment

# Rollback para revisão específica
kubectl rollout undo deployment/nginx-deployment --to-revision=2

# Pausar rollout
kubectl rollout pause deployment/nginx-deployment

# Retomar rollout
kubectl rollout resume deployment/nginx-deployment

# Reiniciar deployment
kubectl rollout restart deployment/nginx-deployment
```

## Trabalhando com Services

### Criar Service

```bash
# Expor deployment como ClusterIP
kubectl expose deployment nginx-deployment --port=80 --target-port=80

# Expor como NodePort
kubectl expose deployment nginx-deployment --type=NodePort --port=80

# Expor como LoadBalancer
kubectl expose deployment nginx-deployment --type=LoadBalancer --port=80

# Ou com YAML
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
EOF
```

### Gerenciar Services

```bash
# Listar services
kubectl get services

# Ver detalhes
kubectl describe service nginx-service

# Ver endpoints
kubectl get endpoints nginx-service

# Testar service (de dentro do cluster)
kubectl run test --image=busybox -it --rm -- wget -O- nginx-service:80

# Port-forward para testar localmente
kubectl port-forward service/nginx-service 8080:80
```

## Trabalhando com Namespaces

### Criar e Usar Namespaces

```bash
# Listar namespaces
kubectl get namespaces

# Criar namespace
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod

# Ver recursos em namespace específico
kubectl get pods -n dev

# Ver recursos em todos os namespaces
kubectl get pods --all-namespaces
kubectl get pods -A

# Definir namespace padrão para context
kubectl config set-context --current --namespace=dev

# Verificar namespace atual
kubectl config view --minify | grep namespace:

# Deletar namespace
kubectl delete namespace dev
```

### Deploy em Namespace

```bash
# Criar deployment em namespace
kubectl create deployment nginx --image=nginx -n dev

# Aplicar YAML em namespace
kubectl apply -f deployment.yaml -n dev

# Ou especificar no YAML
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: dev
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: dev
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
EOF
```

## Trabalhando com Labels e Selectors

### Labels

```bash
# Ver labels
kubectl get pods --show-labels

# Adicionar label
kubectl label pod nginx-pod env=production

# Atualizar label
kubectl label pod nginx-pod env=staging --overwrite

# Remover label
kubectl label pod nginx-pod env-

# Adicionar label a múltiplos recursos
kubectl label pods --all tier=frontend
```

### Selectors

```bash
# Filtrar por label
kubectl get pods -l app=nginx
kubectl get pods -l env=production

# Múltiplas labels (AND)
kubectl get pods -l app=nginx,env=production

# Operadores
kubectl get pods -l 'env in (prod,staging)'
kubectl get pods -l 'env notin (dev)'
kubectl get pods -l 'tier'  # Tem a label tier
kubectl get pods -l '!tier'  # Não tem a label tier

# Deletar por label
kubectl delete pods -l app=nginx
```

## Exemplo Prático Completo

### 1. Criar Namespace

```bash
kubectl create namespace myapp
kubectl config set-context --current --namespace=myapp
```

### 2. Deploy da Aplicação

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
```

```bash
kubectl apply -f deployment.yaml
```

### 3. Criar Service

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

```bash
kubectl apply -f service.yaml
```

### 4. Verificar Deploy

```bash
# Ver todos os recursos
kubectl get all

# Ver pods
kubectl get pods

# Ver detalhes do deployment
kubectl describe deployment webapp

# Ver service
kubectl get service webapp-service

# Ver endpoints
kubectl get endpoints webapp-service
```

### 5. Testar Aplicação

```bash
# Port-forward
kubectl port-forward service/webapp-service 8080:80

# Em outro terminal
curl http://localhost:8080

# Ou se NodePort estiver acessível
curl http://<node-ip>:30080
```

### 6. Ver Logs

```bash
# Logs de um pod
kubectl logs -l app=webapp --tail=50

# Logs em tempo real
kubectl logs -l app=webapp -f
```

### 7. Escalar

```bash
# Escalar para 5 réplicas
kubectl scale deployment webapp --replicas=5

# Verificar
kubectl get pods
```

### 8. Atualizar Imagem

```bash
# Atualizar para nova versão
kubectl set image deployment/webapp webapp=nginx:1.22

# Acompanhar rollout
kubectl rollout status deployment/webapp

# Ver histórico
kubectl rollout history deployment/webapp
```

### 9. Rollback

```bash
# Voltar para versão anterior
kubectl rollout undo deployment/webapp

# Verificar
kubectl rollout status deployment/webapp
```

### 10. Limpar

```bash
# Deletar recursos
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml

# Ou deletar namespace inteiro
kubectl delete namespace myapp
```

## Comandos de Debug

### Verificar Status

```bash
# Ver eventos do cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Ver eventos de namespace
kubectl get events -n myapp

# Ver eventos de recurso específico
kubectl describe pod nginx-pod | grep Events -A 20
```

### Debug de Pods

```bash
# Ver por que pod não está rodando
kubectl describe pod nginx-pod

# Ver logs
kubectl logs nginx-pod
kubectl logs nginx-pod --previous  # Container anterior

# Executar comandos de debug
kubectl exec nginx-pod -- ps aux
kubectl exec nginx-pod -- netstat -tlnp
kubectl exec nginx-pod -- cat /etc/resolv.conf

# Debug interativo
kubectl exec -it nginx-pod -- /bin/bash
```

### Debug de Rede

```bash
# Testar conectividade DNS
kubectl run test --image=busybox -it --rm -- nslookup kubernetes.default

# Testar conectividade com service
kubectl run test --image=busybox -it --rm -- wget -O- nginx-service:80

# Ver endpoints
kubectl get endpoints

# Descrever service
kubectl describe service nginx-service
```

### Debug de Recursos

```bash
# Ver uso de recursos
kubectl top nodes
kubectl top pods

# Ver limites de recursos
kubectl describe node <node-name> | grep -A 5 "Allocated resources"

# Ver quotas
kubectl get resourcequota
kubectl describe resourcequota
```

## Comandos Úteis

### Informações do Cluster

```bash
# Informações do cluster
kubectl cluster-info

# Versão
kubectl version

# API resources disponíveis
kubectl api-resources

# API versions
kubectl api-versions

# Explicar recurso
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
```

### Dry-run e Geradores

```bash
# Gerar YAML sem criar
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml

# Gerar e salvar
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml

# Dry-run no servidor (valida)
kubectl apply -f deployment.yaml --dry-run=server

# Ver diferenças antes de aplicar
kubectl diff -f deployment.yaml
```

### Contextos e Configuração

```bash
# Ver configuração
kubectl config view

# Listar contexts
kubectl config get-contexts

# Ver context atual
kubectl config current-context

# Trocar context
kubectl config use-context kind-kind

# Definir namespace padrão
kubectl config set-context --current --namespace=dev
```

## Atalhos e Aliases

```bash
# Adicionar ao ~/.bashrc ou ~/.zshrc

# Kubectl
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'

# Describe
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kdd='kubectl describe deployment'

# Logs
alias kl='kubectl logs'
alias klf='kubectl logs -f'

# Exec
alias kex='kubectl exec -it'

# Apply/Delete
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Namespace
alias kn='kubectl config set-context --current --namespace'

# Watch
alias kgpw='kubectl get pods --watch'
```

## Dicas e Boas Práticas

### 1. Use Dry-run

```bash
# Sempre teste antes de aplicar
kubectl apply -f deployment.yaml --dry-run=server
kubectl diff -f deployment.yaml
```

### 2. Use Labels Consistentes

```bash
# Facilita filtragem e organização
kubectl get pods -l app=nginx,env=prod
```

### 3. Especifique Namespace

```bash
# Evita erros em cluster errado
kubectl get pods -n production
```

### 4. Use Output Formats

```bash
# YAML para ver configuração completa
kubectl get pod nginx -o yaml

# JSON para parsing
kubectl get pods -o json | jq '.items[].metadata.name'

# Wide para mais informações
kubectl get pods -o wide
```

### 5. Documente com Annotations

```bash
kubectl annotate deployment nginx-deployment \
  description="Production NGINX deployment" \
  owner="team-platform"
```

### 6. Use Resource Limits

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

### 7. Implemente Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

## Próximos Passos

Após dominar estes comandos básicos, explore:

- **ConfigMaps e Secrets**: Gerenciar configurações
- **Volumes**: Armazenamento persistente
- **Ingress**: Roteamento HTTP avançado
- **StatefulSets**: Aplicações stateful
- **Jobs e CronJobs**: Tarefas batch
- **RBAC**: Controle de acesso
- **Network Policies**: Segurança de rede
- **Helm**: Gerenciador de pacotes
- **Monitoring**: Prometheus e Grafana
