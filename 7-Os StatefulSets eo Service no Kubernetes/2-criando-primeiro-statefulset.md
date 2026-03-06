# Criando o Nosso Primeiro StatefulSet

## Objetivo

Neste guia, vamos criar um StatefulSet do zero, entendendo cada componente e vendo na prática como funciona a criação ordenada de Pods, identidade estável e persistência de dados.

## Pré-requisitos

```bash
# Verificar cluster Kubernetes
kubectl cluster-info

# Verificar nodes
kubectl get nodes

# Criar namespace para testes (opcional)
kubectl create namespace statefulset-demo
kubectl config set-context --current --namespace=statefulset-demo
```

## Passo 1: Criar o Headless Service

O **Headless Service** é essencial para StatefulSets. Ele fornece DNS estável para cada Pod.

### O que é Headless Service?

Um Service com `clusterIP: None` que não faz load balancing, mas cria entradas DNS individuais para cada Pod.

### Arquivo: `nginx-headless-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
  labels:
    app: nginx-stateful
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None  # Isso torna o Service "headless"
  selector:
    app: nginx-stateful
```

### Aplicando o Service:

```bash
# Criar o Headless Service
kubectl apply -f nginx-headless-service.yaml

# Verificar o Service
kubectl get svc nginx-headless

# Saída esperada:
# NAME             TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# nginx-headless   ClusterIP   None         <none>        80/TCP    5s

# Ver detalhes
kubectl describe svc nginx-headless
```

## Passo 2: Criar o StatefulSet

Agora vamos criar o StatefulSet que usará o Headless Service.

### Arquivo: `nginx-statefulset.yaml`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-sts
spec:
  serviceName: "nginx-headless"  # Referência ao Headless Service
  replicas: 3
  selector:
    matchLabels:
      app: nginx-stateful
  template:
    metadata:
      labels:
        app: nginx-stateful
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

### Aplicando o StatefulSet:

```bash
# Criar o StatefulSet
kubectl apply -f nginx-statefulset.yaml

# Observar criação SEQUENCIAL dos Pods
kubectl get pods -w

# Saída esperada (observe a ordem):
# NAME         READY   STATUS    RESTARTS   AGE
# nginx-sts-0  0/1     Pending   0          0s
# nginx-sts-0  0/1     Pending   0          2s
# nginx-sts-0  0/1     ContainerCreating   0          2s
# nginx-sts-0  1/1     Running   0          5s
# nginx-sts-1  0/1     Pending   0          0s    ← Só começa após nginx-sts-0 estar Running
# nginx-sts-1  0/1     ContainerCreating   0          1s
# nginx-sts-1  1/1     Running   0          4s
# nginx-sts-2  0/1     Pending   0          0s    ← Só começa após nginx-sts-1 estar Running
# nginx-sts-2  0/1     ContainerCreating   0          1s
# nginx-sts-2  1/1     Running   0          4s
```

## Fluxo de Criação do StatefulSet

```
┌─────────────────────────────────────────────────────────────┐
│  kubectl apply -f nginx-statefulset.yaml                    │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   StatefulSet Controller           │
        │   Inicia criação sequencial        │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Cria nginx-sts-0                 │
        │   - PVC: www-nginx-sts-0           │
        │   - Pod: nginx-sts-0               │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Aguarda nginx-sts-0 = Running    │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Cria nginx-sts-1                 │
        │   - PVC: www-nginx-sts-1           │
        │   - Pod: nginx-sts-1               │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Aguarda nginx-sts-1 = Running    │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Cria nginx-sts-2                 │
        │   - PVC: www-nginx-sts-2           │
        │   - Pod: nginx-sts-2               │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   StatefulSet Completo             │
        │   3/3 Pods Running                 │
        └────────────────────────────────────┘
```

## Passo 3: Verificar os Recursos Criados

```bash
# Ver StatefulSet
kubectl get statefulset nginx-sts

# Saída:
# NAME        READY   AGE
# nginx-sts   3/3     2m

# Ver Pods (observe os nomes ordenados)
kubectl get pods -l app=nginx-stateful

# Saída:
# NAME         READY   STATUS    RESTARTS   AGE
# nginx-sts-0  1/1     Running   0          3m
# nginx-sts-1  1/1     Running   0          2m50s
# nginx-sts-2  1/1     Running   0          2m45s

# Ver PVCs criados automaticamente
kubectl get pvc

# Saída:
# NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES
# www-nginx-sts-0   Bound    pvc-abc123...                              1Gi        RWO
# www-nginx-sts-1   Bound    pvc-def456...                              1Gi        RWO
# www-nginx-sts-2   Bound    pvc-ghi789...                              1Gi        RWO

# Ver PVs
kubectl get pv
```

## Passo 4: Testar Identidade Estável (DNS)

Cada Pod tem um DNS único e estável.

```bash
# Criar Pod temporário para testes
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Dentro do Pod, testar DNS
nslookup nginx-sts-0.nginx-headless
nslookup nginx-sts-1.nginx-headless
nslookup nginx-sts-2.nginx-headless

# Saída esperada para nginx-sts-0:
# Server:    10.96.0.10
# Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
#
# Name:      nginx-sts-0.nginx-headless
# Address 1: 10.244.1.5 nginx-sts-0.nginx-headless.default.svc.cluster.local

# Testar conectividade HTTP
wget -qO- http://nginx-sts-0.nginx-headless
wget -qO- http://nginx-sts-1.nginx-headless
wget -qO- http://nginx-sts-2.nginx-headless

# Sair do Pod
exit
```

## Passo 5: Testar Persistência de Dados

Vamos adicionar conteúdo único em cada Pod e verificar que persiste após reinicialização.

```bash
# Adicionar conteúdo no nginx-sts-0
kubectl exec nginx-sts-0 -- sh -c 'echo "Pod 0 - $(hostname)" > /usr/share/nginx/html/index.html'

# Adicionar conteúdo no nginx-sts-1
kubectl exec nginx-sts-1 -- sh -c 'echo "Pod 1 - $(hostname)" > /usr/share/nginx/html/index.html'

# Adicionar conteúdo no nginx-sts-2
kubectl exec nginx-sts-2 -- sh -c 'echo "Pod 2 - $(hostname)" > /usr/share/nginx/html/index.html'

# Verificar conteúdo
kubectl exec nginx-sts-0 -- cat /usr/share/nginx/html/index.html
kubectl exec nginx-sts-1 -- cat /usr/share/nginx/html/index.html
kubectl exec nginx-sts-2 -- cat /usr/share/nginx/html/index.html

# Saída:
# Pod 0 - nginx-sts-0
# Pod 1 - nginx-sts-1
# Pod 2 - nginx-sts-2
```

### Testar Persistência Após Deleção:

```bash
# Deletar o Pod nginx-sts-1
kubectl delete pod nginx-sts-1

# Observar recriação automática
kubectl get pods -w

# Aguardar até nginx-sts-1 estar Running novamente

# Verificar que o conteúdo PERSISTIU
kubectl exec nginx-sts-1 -- cat /usr/share/nginx/html/index.html

# Saída:
# Pod 1 - nginx-sts-1
# ✅ Os dados persistiram!
```

## Passo 6: Escalar o StatefulSet

```bash
# Ver replicas atuais
kubectl get statefulset nginx-sts

# Escalar para 5 replicas
kubectl scale statefulset nginx-sts --replicas=5

# Observar criação sequencial dos novos Pods
kubectl get pods -w

# Saída:
# nginx-sts-3  0/1     Pending   0          0s
# nginx-sts-3  0/1     ContainerCreating   0          1s
# nginx-sts-3  1/1     Running   0          4s
# nginx-sts-4  0/1     Pending   0          0s
# nginx-sts-4  0/1     ContainerCreating   0          1s
# nginx-sts-4  1/1     Running   0          4s

# Verificar PVCs criados
kubectl get pvc

# Agora temos 5 PVCs (www-nginx-sts-0 até www-nginx-sts-4)
```

### Reduzir Replicas:

```bash
# Reduzir para 2 replicas
kubectl scale statefulset nginx-sts --replicas=2

# Observar deleção em ORDEM REVERSA
kubectl get pods -w

# Saída:
# nginx-sts-4  1/1     Terminating   0          2m
# nginx-sts-4  0/1     Terminating   0          2m10s
# nginx-sts-3  1/1     Terminating   0          3m
# nginx-sts-3  0/1     Terminating   0          3m10s
# nginx-sts-2  1/1     Terminating   0          5m
# nginx-sts-2  0/1     Terminating   0          5m10s

# Verificar Pods restantes
kubectl get pods

# Saída:
# NAME         READY   STATUS    RESTARTS   AGE
# nginx-sts-0  1/1     Running   0          10m
# nginx-sts-1  1/1     Running   0          9m

# IMPORTANTE: Os PVCs NÃO são deletados!
kubectl get pvc

# Saída:
# NAME              STATUS   VOLUME        CAPACITY   ACCESS MODES
# www-nginx-sts-0   Bound    pvc-abc...    1Gi        RWO
# www-nginx-sts-1   Bound    pvc-def...    1Gi        RWO
# www-nginx-sts-2   Bound    pvc-ghi...    1Gi        RWO  ← Ainda existe!
# www-nginx-sts-3   Bound    pvc-jkl...    1Gi        RWO  ← Ainda existe!
# www-nginx-sts-4   Bound    pvc-mno...    1Gi        RWO  ← Ainda existe!
```

## Passo 7: Atualizar o StatefulSet

```bash
# Ver imagem atual
kubectl get statefulset nginx-sts -o jsonpath='{.spec.template.spec.containers[0].image}'

# Saída: nginx:1.21

# Atualizar para nginx:1.22
kubectl set image statefulset/nginx-sts nginx=nginx:1.22

# Observar rolling update em ORDEM REVERSA
kubectl rollout status statefulset/nginx-sts

# Ver Pods sendo atualizados
kubectl get pods -w

# Saída:
# nginx-sts-1  1/1     Terminating         0          15m
# nginx-sts-1  0/1     Terminating         0          15m
# nginx-sts-1  0/1     Pending             0          0s
# nginx-sts-1  0/1     ContainerCreating   0          1s
# nginx-sts-1  1/1     Running             0          4s
# nginx-sts-0  1/1     Terminating         0          16m
# nginx-sts-0  0/1     Terminating         0          16m
# nginx-sts-0  0/1     Pending             0          0s
# nginx-sts-0  0/1     ContainerCreating   0          1s
# nginx-sts-0  1/1     Running             0          4s

# Verificar nova imagem
kubectl get pods nginx-sts-0 -o jsonpath='{.spec.containers[0].image}'

# Saída: nginx:1.22
```

## Passo 8: Criar Service Normal (ClusterIP) para Load Balancing

Além do Headless Service, podemos criar um Service normal para load balancing.

### Arquivo: `nginx-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx-stateful
```

```bash
# Criar Service
kubectl apply -f nginx-service.yaml

# Verificar Service
kubectl get svc nginx-lb

# Saída:
# NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# nginx-lb   ClusterIP   10.96.123.45    <none>        80/TCP    5s

# Testar load balancing
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Fazer múltiplas requisições
wget -qO- http://nginx-lb
wget -qO- http://nginx-lb
wget -qO- http://nginx-lb

# As requisições serão distribuídas entre os Pods
```

## Fluxo Completo: Acesso aos Pods

```
┌──────────────────────────────────────────────────────────────┐
│                    Formas de Acessar                          │
└──────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
    ┌───────────────────────┐   ┌───────────────────────┐
    │  Headless Service     │   │  ClusterIP Service    │
    │  nginx-headless       │   │  nginx-lb             │
    │  (DNS individual)     │   │  (Load Balancing)     │
    └───────────────────────┘   └───────────────────────┘
                │                           │
        ┌───────┼───────┐                   │
        │       │       │                   │
        ▼       ▼       ▼                   ▼
    ┌────┐  ┌────┐  ┌────┐         ┌──────────────┐
    │Pod0│  │Pod1│  │Pod2│         │Round-robin   │
    └────┘  └────┘  └────┘         │entre Pods    │
        │       │       │           └──────────────┘
        │       │       │                   │
        ▼       ▼       ▼           ┌───────┼───────┐
    ┌────┐  ┌────┐  ┌────┐         │       │       │
    │PVC0│  │PVC1│  │PVC2│         ▼       ▼       ▼
    └────┘  └────┘  └────┘     ┌────┐  ┌────┐  ┌────┐
                                │Pod0│  │Pod1│  │Pod2│
    Acesso direto:              └────┘  └────┘  └────┘
    nginx-sts-0.nginx-headless
    nginx-sts-1.nginx-headless  Acesso balanceado:
    nginx-sts-2.nginx-headless  nginx-lb
```

## Passo 9: Ver Detalhes e Logs

```bash
# Detalhes do StatefulSet
kubectl describe statefulset nginx-sts

# Ver eventos
kubectl get events --sort-by=.metadata.creationTimestamp

# Logs de um Pod específico
kubectl logs nginx-sts-0

# Logs de todos os Pods
kubectl logs -l app=nginx-stateful

# Seguir logs em tempo real
kubectl logs -f nginx-sts-0

# Executar comando em Pod
kubectl exec -it nginx-sts-0 -- bash

# Ver configuração do StatefulSet em YAML
kubectl get statefulset nginx-sts -o yaml

# Ver configuração de um Pod
kubectl get pod nginx-sts-0 -o yaml
```

## Passo 10: Limpeza

```bash
# Deletar StatefulSet (Pods são deletados, PVCs NÃO)
kubectl delete statefulset nginx-sts

# Verificar que PVCs ainda existem
kubectl get pvc

# Deletar Services
kubectl delete svc nginx-headless nginx-lb

# Deletar PVCs manualmente
kubectl delete pvc www-nginx-sts-0 www-nginx-sts-1 www-nginx-sts-2

# Ou deletar todos os PVCs
kubectl delete pvc -l app=nginx-stateful

# Deletar namespace (se criou)
kubectl delete namespace statefulset-demo
```

## Exemplo Completo: Arquivo Único

Para facilitar, aqui está tudo em um único arquivo:

### Arquivo: `statefulset-completo.yaml`

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx-stateful
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx-stateful
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-sts
spec:
  serviceName: "nginx-headless"
  replicas: 3
  selector:
    matchLabels:
      app: nginx-stateful
  template:
    metadata:
      labels:
        app: nginx-stateful
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

```bash
# Aplicar tudo de uma vez
kubectl apply -f statefulset-completo.yaml

# Verificar tudo
kubectl get all,pvc
```

## Comandos Resumidos

```bash
# Criar
kubectl apply -f statefulset-completo.yaml

# Verificar
kubectl get statefulset
kubectl get pods -l app=nginx-stateful
kubectl get pvc
kubectl get svc

# Escalar
kubectl scale statefulset nginx-sts --replicas=5

# Atualizar
kubectl set image statefulset/nginx-sts nginx=nginx:1.22

# Rollback
kubectl rollout undo statefulset/nginx-sts

# Deletar
kubectl delete -f statefulset-completo.yaml
kubectl delete pvc -l app=nginx-stateful
```

## Troubleshooting

### Pod não inicia:

```bash
# Ver eventos
kubectl describe pod nginx-sts-0

# Ver logs
kubectl logs nginx-sts-0

# Ver eventos do StatefulSet
kubectl describe statefulset nginx-sts
```

### PVC não é criado:

```bash
# Verificar StorageClass
kubectl get storageclass

# Ver eventos do PVC
kubectl describe pvc www-nginx-sts-0

# Verificar se há PVs disponíveis
kubectl get pv
```

### DNS não funciona:

```bash
# Verificar Headless Service
kubectl get svc nginx-headless

# Verificar se clusterIP é None
kubectl get svc nginx-headless -o jsonpath='{.spec.clusterIP}'

# Testar DNS do cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

## Resumo

Criamos com sucesso um StatefulSet completo com:

✅ Headless Service para DNS estável
✅ StatefulSet com 3 replicas
✅ Volumes persistentes por Pod
✅ Service para load balancing
✅ Testes de persistência
✅ Escalabilidade
✅ Rolling updates

O StatefulSet garante identidade estável, ordem de criação e persistência de dados para aplicações stateful!
