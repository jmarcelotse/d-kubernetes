# O Deployment e o ReplicaSet

## Relação entre Deployment e ReplicaSet

Um **Deployment** é um objeto de nível superior que gerencia **ReplicaSets** automaticamente. Quando você cria um Deployment, o Kubernetes cria um ReplicaSet para você, e esse ReplicaSet gerencia os Pods.

```
┌─────────────────────────────────────────┐
│           DEPLOYMENT                    │
│  (Gerencia ReplicaSets e atualizações)  │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│           REPLICASET                    │
│  (Garante número de réplicas)           │
└─────────────────────────────────────────┘
                  │
        ┌─────────┼─────────┐
        ▼         ▼         ▼
    ┌─────┐   ┌─────┐   ┌─────┐
    │ Pod │   │ Pod │   │ Pod │
    └─────┘   └─────┘   └─────┘
```

## Por Que Usar Deployment em Vez de ReplicaSet?

O Deployment adiciona funcionalidades essenciais que o ReplicaSet não possui:

| Funcionalidade | ReplicaSet | Deployment |
|----------------|-----------|------------|
| Manter número de réplicas | ✅ | ✅ |
| Autocorreção de Pods | ✅ | ✅ |
| Escalabilidade | ✅ | ✅ |
| **Atualizações rolling** | ❌ | ✅ |
| **Rollback de versões** | ❌ | ✅ |
| **Histórico de revisões** | ❌ | ✅ |
| **Pausar/Retomar atualizações** | ❌ | ✅ |
| **Estratégias de atualização** | ❌ | ✅ |

## Como o Deployment Gerencia ReplicaSets

Quando você atualiza um Deployment, ele:

1. Cria um **novo ReplicaSet** com a nova versão
2. Aumenta gradualmente as réplicas do novo ReplicaSet
3. Diminui gradualmente as réplicas do ReplicaSet antigo
4. Mantém o ReplicaSet antigo para possibilitar rollback

```
ANTES DA ATUALIZAÇÃO:
┌──────────────┐
│ Deployment   │
└──────────────┘
       │
       ▼
┌──────────────┐
│ ReplicaSet   │ ← versão 1.0 (3 réplicas)
│   v1.0       │
└──────────────┘
       │
   ┌───┼───┐
   ▼   ▼   ▼
  Pod Pod Pod


DURANTE A ATUALIZAÇÃO (Rolling Update):
┌──────────────┐
│ Deployment   │
└──────────────┘
       │
   ┌───┴───┐
   ▼       ▼
┌─────┐  ┌─────┐
│ RS  │  │ RS  │ ← versão 2.0 (2 réplicas, aumentando)
│ v1.0│  │ v2.0│
└─────┘  └─────┘
   │        │
   ▼      ┌─┴─┐
  Pod     ▼   ▼
         Pod Pod


APÓS A ATUALIZAÇÃO:
┌──────────────┐
│ Deployment   │
└──────────────┘
       │
   ┌───┴───┐
   ▼       ▼
┌─────┐  ┌─────┐
│ RS  │  │ RS  │ ← versão 2.0 (3 réplicas)
│ v1.0│  │ v2.0│
└─────┘  └─────┘
(0 rép)     │
        ┌───┼───┐
        ▼   ▼   ▼
       Pod Pod Pod
```

## Exemplo Prático 1: Criando um Deployment e Observando o ReplicaSet

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
        image: nginx:1.26
        ports:
        - containerPort: 80
```

```bash
# Criar o Deployment
kubectl apply -f nginx-deployment.yaml

# Ver o Deployment criado
kubectl get deployment

# Saída:
# NAME               READY   UP-TO-DATE   AVAILABLE   AGE
# nginx-deployment   3/3     3            3           10s

# Ver o ReplicaSet criado automaticamente
kubectl get replicaset

# Saída:
# NAME                          DESIRED   CURRENT   READY   AGE
# nginx-deployment-5d59d67564   3         3         3       15s
#                   ^^^^^^^^^^
#                   hash gerado automaticamente

# Ver os Pods criados
kubectl get pods

# Saída:
# NAME                                READY   STATUS    RESTARTS   AGE
# nginx-deployment-5d59d67564-abc12   1/1     Running   0          20s
# nginx-deployment-5d59d67564-def34   1/1     Running   0          20s
# nginx-deployment-5d59d67564-ghi56   1/1     Running   0          20s
```

### Observando a Hierarquia

```bash
# Ver todos os recursos relacionados
kubectl get deployment,replicaset,pod -l app=nginx

# Ver detalhes do Deployment (mostra o ReplicaSet gerenciado)
kubectl describe deployment nginx-deployment

# Saída relevante:
# NewReplicaSet:   nginx-deployment-5d59d67564 (3/3 replicas created)
# Events:
#   Type    Reason             Age   From                   Message
#   ----    ------             ----  ----                   -------
#   Normal  ScalingReplicaSet  30s   deployment-controller  Scaled up replica set nginx-deployment-5d59d67564 to 3
```

## Exemplo Prático 2: Atualização e Criação de Novo ReplicaSet

```bash
# Atualizar a imagem do container
kubectl set image deployment/nginx-deployment nginx=nginx:1.27

# Ou editar o Deployment
kubectl edit deployment nginx-deployment
# Alterar: image: nginx:1.26 → image: nginx:1.27

# Observar os ReplicaSets durante a atualização
kubectl get replicaset --watch

# Saída (em tempo real):
# NAME                          DESIRED   CURRENT   READY   AGE
# nginx-deployment-5d59d67564   3         3         3       2m    ← ReplicaSet antigo
# nginx-deployment-7d9c8f6b5a   1         1         0       2s    ← Novo ReplicaSet criado
# nginx-deployment-5d59d67564   2         3         3       2m    ← Reduzindo réplicas antigas
# nginx-deployment-7d9c8f6b5a   2         1         1       5s    ← Aumentando novas réplicas
# nginx-deployment-5d59d67564   2         2         2       2m
# nginx-deployment-7d9c8f6b5a   3         2         2       8s
# nginx-deployment-5d59d67564   1         2         2       2m
# nginx-deployment-7d9c8f6b5a   3         3         3       10s
# nginx-deployment-5d59d67564   0         1         1       2m    ← ReplicaSet antigo zerado
```

### Verificando os ReplicaSets Após Atualização

```bash
# Listar ReplicaSets
kubectl get replicaset

# Saída:
# NAME                          DESIRED   CURRENT   READY   AGE
# nginx-deployment-5d59d67564   0         0         0       5m    ← Versão antiga (mantida para rollback)
# nginx-deployment-7d9c8f6b5a   3         3         3       2m    ← Versão atual
```

## Exemplo Prático 3: Múltiplas Atualizações e Histórico de ReplicaSets

```bash
# Primeira atualização
kubectl set image deployment/nginx-deployment nginx=nginx:1.27
kubectl rollout status deployment/nginx-deployment

# Segunda atualização
kubectl set image deployment/nginx-deployment nginx=nginx:1.27.1
kubectl rollout status deployment/nginx-deployment

# Terceira atualização
kubectl set image deployment/nginx-deployment nginx=nginx:1.27.2
kubectl rollout status deployment/nginx-deployment

# Ver histórico de revisões
kubectl rollout history deployment/nginx-deployment

# Saída:
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>
# 3         <none>
# 4         <none>

# Ver todos os ReplicaSets (incluindo os antigos)
kubectl get replicaset

# Saída:
# NAME                          DESIRED   CURRENT   READY   AGE
# nginx-deployment-5d59d67564   0         0         0       10m   ← Revisão 1
# nginx-deployment-7d9c8f6b5a   0         0         0       8m    ← Revisão 2
# nginx-deployment-8e4a9b7c6d   0         0         0       5m    ← Revisão 3
# nginx-deployment-9f5b0c8d7e   3         3         3       2m    ← Revisão 4 (atual)
```

## Exemplo Prático 4: Rollback e Reativação de ReplicaSet Antigo

```bash
# Fazer rollback para a revisão anterior
kubectl rollout undo deployment/nginx-deployment

# Observar os ReplicaSets
kubectl get replicaset

# Saída:
# NAME                          DESIRED   CURRENT   READY   AGE
# nginx-deployment-5d59d67564   0         0         0       15m
# nginx-deployment-7d9c8f6b5a   0         0         0       13m
# nginx-deployment-8e4a9b7c6d   3         3         3       10m   ← Reativado!
# nginx-deployment-9f5b0c8d7e   0         0         0       7m    ← Desativado

# Ver detalhes do Deployment
kubectl describe deployment nginx-deployment

# Saída relevante:
# NewReplicaSet:   nginx-deployment-8e4a9b7c6d (3/3 replicas created)
# OldReplicaSets:  nginx-deployment-9f5b0c8d7e (0/0 replicas created)
```

### Rollback para Revisão Específica

```bash
# Ver histórico detalhado
kubectl rollout history deployment/nginx-deployment

# Ver detalhes de uma revisão específica
kubectl rollout history deployment/nginx-deployment --revision=2

# Fazer rollback para revisão específica
kubectl rollout undo deployment/nginx-deployment --to-revision=2

# Verificar qual ReplicaSet foi reativado
kubectl get replicaset
```

## Exemplo Prático 5: Escalando Deployment (Afeta o ReplicaSet)

```bash
# Escalar o Deployment
kubectl scale deployment nginx-deployment --replicas=5

# Ver o ReplicaSet atualizado
kubectl get replicaset

# Saída:
# NAME                          DESIRED   CURRENT   READY   AGE
# nginx-deployment-8e4a9b7c6d   5         5         5       15m   ← Escalado para 5

# Ver os Pods
kubectl get pods -l app=nginx

# Saída: 5 Pods rodando
```

## Exemplo Prático 6: Deletando Deployment (Remove ReplicaSets e Pods)

```bash
# Deletar o Deployment
kubectl delete deployment nginx-deployment

# Verificar que ReplicaSets foram removidos
kubectl get replicaset

# Verificar que Pods foram removidos
kubectl get pods -l app=nginx

# Tudo foi removido em cascata
```

## Exemplo Prático 7: Deployment com Anotações para Rastrear Mudanças

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  labels:
    app: myapp
spec:
  replicas: 3
  revisionHistoryLimit: 10  # Quantos ReplicaSets antigos manter
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:1.26
        ports:
        - containerPort: 80
```

```bash
# Criar com anotação de mudança
kubectl apply -f app-deployment.yaml --record

# Atualizar com anotação
kubectl set image deployment/app-deployment app=nginx:1.27 --record

# Ver histórico com as mudanças registradas
kubectl rollout history deployment/app-deployment

# Saída:
# REVISION  CHANGE-CAUSE
# 1         kubectl apply --filename=app-deployment.yaml --record=true
# 2         kubectl set image deployment/app-deployment app=nginx:1.27 --record=true
```

## Exemplo Prático 8: Observando a Relação em Tempo Real

```bash
# Terminal 1: Observar Deployments
kubectl get deployment --watch

# Terminal 2: Observar ReplicaSets
kubectl get replicaset --watch

# Terminal 3: Observar Pods
kubectl get pods --watch

# Terminal 4: Fazer uma atualização
kubectl set image deployment/nginx-deployment nginx=nginx:1.27

# Você verá a cascata de mudanças em tempo real:
# 1. Deployment inicia atualização
# 2. Novo ReplicaSet é criado
# 3. Novos Pods são criados gradualmente
# 4. Pods antigos são terminados gradualmente
# 5. ReplicaSet antigo é zerado
```

## Comandos para Inspecionar a Relação

```bash
# Ver Deployment e seus ReplicaSets
kubectl describe deployment <nome-deployment>

# Ver qual ReplicaSet está ativo
kubectl get replicaset -l app=<label>

# Ver os Pods de um ReplicaSet específico
kubectl get pods -l app=<label>

# Ver a árvore de recursos (se kubectl tree estiver instalado)
kubectl tree deployment <nome-deployment>

# Ver eventos relacionados
kubectl get events --sort-by=.metadata.creationTimestamp

# Ver todos os recursos relacionados
kubectl get all -l app=<label>
```

## Configurando Limite de ReplicaSets Antigos

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  revisionHistoryLimit: 5  # Manter apenas 5 ReplicaSets antigos
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
        image: nginx:1.27
```

```bash
# Aplicar
kubectl apply -f nginx-deployment.yaml

# Fazer várias atualizações
kubectl set image deployment/nginx-deployment nginx=nginx:1.27.1
kubectl set image deployment/nginx-deployment nginx=nginx:1.27.2
kubectl set image deployment/nginx-deployment nginx=alpine
kubectl set image deployment/nginx-deployment nginx=nginx:1.26
kubectl set image deployment/nginx-deployment nginx=nginx:1.27

# Ver ReplicaSets - apenas os últimos 5 serão mantidos
kubectl get replicaset
```

## Fluxo Completo: Do Deployment ao Pod

```
1. Você cria um DEPLOYMENT
   └─> kubectl apply -f deployment.yaml

2. Deployment Controller cria um REPLICASET
   └─> ReplicaSet com hash único (ex: deployment-5d59d67564)

3. ReplicaSet Controller cria os PODS
   └─> Número de Pods = spec.replicas

4. Você atualiza o DEPLOYMENT
   └─> kubectl set image deployment/...

5. Deployment Controller cria NOVO REPLICASET
   └─> Novo ReplicaSet com hash diferente (ex: deployment-7d9c8f6b5a)

6. Rolling Update acontece:
   ├─> Novo ReplicaSet aumenta réplicas gradualmente
   └─> ReplicaSet antigo diminui réplicas gradualmente

7. Após conclusão:
   ├─> Novo ReplicaSet tem todas as réplicas
   └─> ReplicaSet antigo fica com 0 réplicas (mantido para rollback)
```

## Quando o Deployment Cria Novos ReplicaSets?

O Deployment cria um **novo ReplicaSet** quando você altera:

✅ **Cria novo ReplicaSet:**
- Imagem do container (`image`)
- Comando ou argumentos do container (`command`, `args`)
- Variáveis de ambiente (`env`)
- Portas do container (`ports`)
- Volumes e montagens (`volumes`, `volumeMounts`)
- Qualquer campo dentro de `spec.template`

❌ **NÃO cria novo ReplicaSet:**
- Número de réplicas (`replicas`)
- Labels do Deployment (`metadata.labels`)
- Anotações do Deployment (`metadata.annotations`)
- Estratégia de atualização (`strategy`)

```bash
# Isso cria novo ReplicaSet
kubectl set image deployment/nginx-deployment nginx=nginx:1.27

# Isso NÃO cria novo ReplicaSet (apenas escala o existente)
kubectl scale deployment nginx-deployment --replicas=5
```

## Resumo da Relação

- **Deployment** é o controlador de alto nível que você gerencia
- **ReplicaSet** é criado e gerenciado automaticamente pelo Deployment
- Cada atualização do Deployment cria um **novo ReplicaSet**
- ReplicaSets antigos são **mantidos** (com 0 réplicas) para permitir rollback
- O número de ReplicaSets antigos mantidos é controlado por `revisionHistoryLimit`
- **Nunca edite ReplicaSets diretamente** quando eles são gerenciados por um Deployment
- Use sempre **Deployment** em produção, não ReplicaSet diretamente

## Boas Práticas

1. **Sempre use Deployment**, não ReplicaSet diretamente
2. **Configure `revisionHistoryLimit`** para controlar quantos ReplicaSets antigos manter
3. **Use `--record`** ao fazer mudanças para rastrear o histórico (ou anotações)
4. **Monitore os ReplicaSets** durante atualizações para detectar problemas
5. **Não delete ReplicaSets manualmente** se eles pertencem a um Deployment
6. **Use labels consistentes** para facilitar o rastreamento da hierarquia
