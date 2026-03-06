# Deployment no Kubernetes

## O que é?

Um Deployment é um recurso do Kubernetes que gerencia a implantação e atualização de aplicações. Ele garante que um número especificado de réplicas de Pods esteja sempre em execução.

## Principais Funcionalidades

- **Gerenciamento de Réplicas**: Mantém o número desejado de Pods rodando
- **Atualizações Rolling**: Atualiza aplicações sem downtime
- **Rollback**: Reverte para versões anteriores se necessário
- **Self-healing**: Recria Pods que falharam automaticamente
- **Escalabilidade**: Aumenta ou diminui réplicas facilmente

## Estrutura Básica

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minha-app
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
      - name: container-app
        image: nginx:1.21
        ports:
        - containerPort: 80
```

## Como Funciona

1. Você define o estado desejado (número de réplicas, imagem, etc)
2. O Deployment cria um ReplicaSet
3. O ReplicaSet cria e gerencia os Pods
4. O Kubernetes monitora e mantém o estado desejado

## Comandos Úteis

```bash
# Criar deployment
kubectl apply -f deployment.yaml

# Listar deployments
kubectl get deployments

# Ver detalhes
kubectl describe deployment minha-app

# Escalar
kubectl scale deployment minha-app --replicas=5

# Atualizar imagem
kubectl set image deployment/minha-app container-app=nginx:1.22

# Ver histórico
kubectl rollout history deployment/minha-app

# Fazer rollback
kubectl rollout undo deployment/minha-app
```

## Quando Usar

- Aplicações stateless (sem estado)
- APIs e serviços web
- Workers e processadores
- Qualquer aplicação que precise de múltiplas réplicas e atualizações controladas
