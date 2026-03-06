# O que é um ReplicaSet?

## Conceito

Um **ReplicaSet** é um objeto do Kubernetes que garante que um número específico de réplicas (cópias) de um Pod esteja sempre em execução no cluster. Ele monitora constantemente o estado dos Pods e cria ou remove instâncias conforme necessário para manter o número desejado.

## Função Principal

O ReplicaSet atua como um **controlador de replicação**, garantindo:

- **Alta disponibilidade**: Se um Pod falhar, o ReplicaSet cria automaticamente um novo
- **Escalabilidade**: Permite aumentar ou diminuir o número de réplicas facilmente
- **Balanceamento de carga**: Distribui múltiplas réplicas entre os nós do cluster
- **Autocorreção**: Mantém o estado desejado mesmo em caso de falhas

## Como Funciona

```
┌─────────────────────────────────────────────────┐
│           ReplicaSet Controller                 │
│  (Monitora e mantém o número de réplicas)       │
└─────────────────────────────────────────────────┘
                      │
                      ▼
        ┌─────────────────────────┐
        │  Número Desejado: 3     │
        └─────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
    ┌─────┐       ┌─────┐       ┌─────┐
    │ Pod │       │ Pod │       │ Pod │
    │  1  │       │  2  │       │  3  │
    └─────┘       └─────┘       └─────┘
```

**Fluxo de Operação:**

1. Você define o número desejado de réplicas
2. O ReplicaSet Controller verifica quantos Pods estão rodando
3. Se houver menos Pods que o desejado → cria novos Pods
4. Se houver mais Pods que o desejado → remove Pods excedentes
5. Esse processo se repete continuamente (loop de reconciliação)

## Estrutura de um ReplicaSet

Um ReplicaSet possui três componentes principais:

1. **Selector**: Define quais Pods o ReplicaSet gerencia (através de labels)
2. **Replicas**: Número desejado de Pods
3. **Template**: Especificação do Pod a ser criado

## Exemplo Prático 1: ReplicaSet Básico

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
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
        image: nginx:1.27
        ports:
        - containerPort: 80
```

### Criando o ReplicaSet

```bash
# Criar o ReplicaSet
kubectl apply -f nginx-replicaset.yaml

# Verificar o ReplicaSet
kubectl get replicaset
kubectl get rs  # forma abreviada

# Saída esperada:
# NAME               DESIRED   CURRENT   READY   AGE
# nginx-replicaset   3         3         3       10s
```

### Verificando os Pods Criados

```bash
# Listar Pods criados pelo ReplicaSet
kubectl get pods

# Saída esperada:
# NAME                     READY   STATUS    RESTARTS   AGE
# nginx-replicaset-abc12   1/1     Running   0          20s
# nginx-replicaset-def34   1/1     Running   0          20s
# nginx-replicaset-ghi56   1/1     Running   0          20s
```

### Testando a Autocorreção

```bash
# Deletar um Pod manualmente
kubectl delete pod nginx-replicaset-abc12

# Verificar novamente - um novo Pod será criado automaticamente
kubectl get pods

# Saída:
# NAME                     READY   STATUS    RESTARTS   AGE
# nginx-replicaset-def34   1/1     Running   0          2m
# nginx-replicaset-ghi56   1/1     Running   0          2m
# nginx-replicaset-jkl78   1/1     Running   0          5s  ← Novo Pod criado
```

## Exemplo Prático 2: Escalando um ReplicaSet

### Método 1: Usando kubectl scale

```bash
# Escalar para 5 réplicas
kubectl scale replicaset nginx-replicaset --replicas=5

# Verificar
kubectl get rs nginx-replicaset

# Saída:
# NAME               DESIRED   CURRENT   READY   AGE
# nginx-replicaset   5         5         5       5m
```

### Método 2: Editando o manifesto

```bash
# Editar o ReplicaSet diretamente
kubectl edit replicaset nginx-replicaset

# Alterar o campo 'replicas' de 3 para 5 e salvar
```

### Método 3: Atualizando o arquivo YAML

```yaml
# Alterar no arquivo nginx-replicaset.yaml
spec:
  replicas: 5  # Alterado de 3 para 5
```

```bash
# Aplicar a mudança
kubectl apply -f nginx-replicaset.yaml
```

## Exemplo Prático 3: ReplicaSet com Recursos Definidos

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: app-replicaset
spec:
  replicas: 4
  selector:
    matchLabels:
      app: myapp
      tier: backend
  template:
    metadata:
      labels:
        app: myapp
        tier: backend
    spec:
      containers:
      - name: app-container
        image: nginx:1.27
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

```bash
# Criar o ReplicaSet
kubectl apply -f app-replicaset.yaml

# Ver detalhes do ReplicaSet
kubectl describe rs app-replicaset
```

## Comandos Úteis

```bash
# Listar ReplicaSets
kubectl get replicaset
kubectl get rs

# Ver detalhes de um ReplicaSet
kubectl describe rs <nome-replicaset>

# Escalar ReplicaSet
kubectl scale rs <nome-replicaset> --replicas=<número>

# Deletar ReplicaSet (e seus Pods)
kubectl delete rs <nome-replicaset>

# Deletar ReplicaSet mantendo os Pods
kubectl delete rs <nome-replicaset> --cascade=orphan

# Ver logs de um Pod do ReplicaSet
kubectl logs <nome-pod>

# Ver ReplicaSets com labels
kubectl get rs --show-labels

# Filtrar ReplicaSets por label
kubectl get rs -l app=nginx
```

## Exemplo Prático 4: Seletor com Múltiplas Labels

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-replicaset
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      environment: production
      version: v1
  template:
    metadata:
      labels:
        app: web
        environment: production
        version: v1
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
```

```bash
# Criar o ReplicaSet
kubectl apply -f web-replicaset.yaml

# Filtrar Pods por múltiplas labels
kubectl get pods -l app=web,environment=production
```

## ReplicaSet vs Deployment

**Importante**: Na prática, você raramente criará ReplicaSets diretamente. Em vez disso, você usará **Deployments**, que gerenciam ReplicaSets automaticamente e oferecem recursos adicionais:

| Recurso | ReplicaSet | Deployment |
|---------|-----------|------------|
| Gerencia réplicas | ✅ | ✅ |
| Autocorreção | ✅ | ✅ |
| Atualizações rolling | ❌ | ✅ |
| Rollback | ❌ | ✅ |
| Histórico de versões | ❌ | ✅ |
| Estratégias de atualização | ❌ | ✅ |

**Fluxo de Relacionamento:**

```
Deployment
    │
    ├─── ReplicaSet v1 (versão antiga)
    │       ├─── Pod
    │       └─── Pod
    │
    └─── ReplicaSet v2 (versão atual)
            ├─── Pod
            ├─── Pod
            └─── Pod
```

## Quando Usar ReplicaSet Diretamente?

Use ReplicaSet diretamente apenas em casos específicos:

- **Testes e aprendizado**: Para entender como funciona o controle de réplicas
- **Casos muito simples**: Quando não precisa de atualizações ou rollbacks
- **Controladores customizados**: Quando está criando seu próprio operador

**Para uso em produção**: Sempre prefira usar **Deployments**.

## Verificando o Estado do ReplicaSet

```bash
# Ver informações detalhadas
kubectl describe rs nginx-replicaset

# Saída importante:
# Name:         nginx-replicaset
# Namespace:    default
# Selector:     app=nginx
# Labels:       app=nginx
# Replicas:     3 current / 3 desired
# Pods Status:  3 Running / 0 Waiting / 0 Succeeded / 0 Failed
# Events:
#   Type    Reason            Age   From                   Message
#   ----    ------            ----  ----                   -------
#   Normal  SuccessfulCreate  2m    replicaset-controller  Created pod: nginx-replicaset-abc12
```

## Limpeza

```bash
# Deletar o ReplicaSet e todos os Pods
kubectl delete rs nginx-replicaset

# Deletar usando o arquivo
kubectl delete -f nginx-replicaset.yaml

# Verificar que tudo foi removido
kubectl get rs
kubectl get pods
```

## Resumo

- **ReplicaSet** garante que um número específico de Pods esteja sempre rodando
- Usa **labels** e **selectors** para identificar os Pods que gerencia
- Fornece **autocorreção** automática quando Pods falham
- Permite **escalabilidade** fácil aumentando ou diminuindo réplicas
- Na prática, é gerenciado automaticamente por **Deployments**
- Raramente criado diretamente em ambientes de produção
