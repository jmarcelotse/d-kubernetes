# Por Que Não Usamos o kubectl create Agora?

## Introdução

Nos exemplos anteriores com Pods e Deployments, frequentemente usamos `kubectl create` ou `kubectl run` para criar recursos rapidamente. No entanto, para **ReplicaSets** e **DaemonSets**, usamos principalmente `kubectl apply` com arquivos YAML. Vamos entender o porquê.

## Comandos Imperativos vs Declarativos

### Comandos Imperativos (kubectl create/run)

Você diz ao Kubernetes **como fazer** algo:

```bash
# Criar um Pod
kubectl run nginx --image=nginx:1.27

# Criar um Deployment
kubectl create deployment nginx --image=nginx:1.27 --replicas=3

# Criar um Service
kubectl create service clusterip my-service --tcp=80:80
```

**Características:**
- ✅ Rápido para testes e desenvolvimento
- ✅ Bom para aprendizado inicial
- ❌ Difícil de versionar
- ❌ Difícil de reproduzir
- ❌ Não mantém histórico
- ❌ Limitado em opções de configuração

### Comandos Declarativos (kubectl apply)

Você diz ao Kubernetes **o que você quer** (estado desejado):

```bash
# Aplicar configuração de um arquivo
kubectl apply -f deployment.yaml

# Aplicar múltiplos arquivos
kubectl apply -f ./configs/

# Aplicar de uma URL
kubectl apply -f https://example.com/config.yaml
```

**Características:**
- ✅ Versionável (Git)
- ✅ Reproduzível
- ✅ Mantém histórico de mudanças
- ✅ Suporta todas as opções de configuração
- ✅ Ideal para produção
- ✅ Facilita automação (CI/CD)
- ❌ Requer criar arquivo YAML

## Por Que kubectl create Não Funciona Bem para ReplicaSets e DaemonSets?

### 1. kubectl create Não Suporta ReplicaSet Diretamente

```bash
# Isso NÃO funciona
kubectl create replicaset nginx --image=nginx:1.27 --replicas=3

# Erro:
# error: unknown command "replicaset" for "kubectl create"
```

**Motivo**: O Kubernetes não fornece um comando imperativo para criar ReplicaSets porque você **não deveria criar ReplicaSets diretamente** em produção - você deveria usar Deployments.

### 2. kubectl create Não Suporta DaemonSet Diretamente

```bash
# Isso NÃO funciona
kubectl create daemonset node-monitor --image=busybox:1.36

# Erro:
# error: unknown command "daemonset" for "kubectl create"
```

**Motivo**: DaemonSets têm configurações específicas (tolerations, nodeSelector, hostNetwork, etc.) que são difíceis de expressar em uma linha de comando.

## Comparação: Recursos Suportados por kubectl create

| Recurso | kubectl create | kubectl run | Recomendação |
|---------|---------------|-------------|--------------|
| Pod | ❌ | ✅ | Use `kubectl run` para testes |
| Deployment | ✅ | ❌ | Use `kubectl create` para testes |
| ReplicaSet | ❌ | ❌ | Use `kubectl apply` sempre |
| DaemonSet | ❌ | ❌ | Use `kubectl apply` sempre |
| Service | ✅ | ❌ | Use `kubectl create` ou YAML |
| ConfigMap | ✅ | ❌ | Use `kubectl create` ou YAML |
| Secret | ✅ | ❌ | Use `kubectl create` ou YAML |

## Exemplo Prático: Tentando Criar ReplicaSet Imperativamente

### Tentativa 1: Comando Direto (Falha)

```bash
# Tentar criar ReplicaSet diretamente
kubectl create replicaset nginx-rs --image=nginx:1.27 --replicas=3

# Erro:
# error: unknown command "replicaset" for "kubectl create"
```

### Tentativa 2: Usando kubectl run (Não Cria ReplicaSet)

```bash
# kubectl run cria apenas Pods, não ReplicaSets
kubectl run nginx --image=nginx:1.27

# Verificar o que foi criado
kubectl get all

# Saída: Apenas um Pod, não um ReplicaSet
# NAME        READY   STATUS    RESTARTS   AGE
# pod/nginx   1/1     Running   0          5s
```

### Solução: Usar kubectl apply com YAML

```yaml
# nginx-replicaset.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
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
```

```bash
# Criar usando apply
kubectl apply -f nginx-replicaset.yaml

# Sucesso!
# replicaset.apps/nginx-rs created
```

## Exemplo Prático: Tentando Criar DaemonSet Imperativamente

### Tentativa 1: Comando Direto (Falha)

```bash
# Tentar criar DaemonSet diretamente
kubectl create daemonset node-monitor --image=busybox:1.36

# Erro:
# error: unknown command "daemonset" for "kubectl create"
```

### Tentativa 2: Verificar Comandos Disponíveis

```bash
# Ver comandos create disponíveis
kubectl create --help

# Saída (comandos disponíveis):
# Available Commands:
#   clusterrole         Create a cluster role
#   clusterrolebinding  Create a cluster role binding
#   configmap           Create a config map
#   cronjob             Create a cronjob
#   deployment          Create a deployment
#   ingress             Create an ingress
#   job                 Create a job
#   namespace           Create a namespace
#   poddisruptionbudget Create a pod disruption budget
#   priorityclass       Create a priority class
#   quota               Create a quota
#   role                Create a role
#   rolebinding         Create a role binding
#   secret              Create a secret
#   service             Create a service
#   serviceaccount      Create a service account

# Note: Não há "replicaset" nem "daemonset"
```

### Solução: Usar kubectl apply com YAML

```yaml
# node-monitor-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
spec:
  selector:
    matchLabels:
      app: node-monitor
  template:
    metadata:
      labels:
        app: node-monitor
    spec:
      containers:
      - name: monitor
        image: busybox:1.36
        command: ['sh', '-c', 'while true; do echo "Monitoring..."; sleep 30; done']
```

```bash
# Criar usando apply
kubectl apply -f node-monitor-daemonset.yaml

# Sucesso!
# daemonset.apps/node-monitor created
```

## Usando dry-run para Gerar YAML Base

Embora não possamos criar ReplicaSets e DaemonSets imperativamente, podemos usar outros recursos como base:

### Gerando YAML de Deployment como Base

```bash
# Gerar YAML de Deployment
kubectl create deployment nginx --image=nginx:1.27 --replicas=3 --dry-run=client -o yaml > base.yaml

# Ver o arquivo gerado
cat base.yaml
```

**Saída:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
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
      - image: nginx:1.27
        name: nginx
```

### Convertendo para ReplicaSet

```bash
# Editar o arquivo
# 1. Mudar kind: Deployment para kind: ReplicaSet
# 2. Remover campos específicos de Deployment (strategy, etc.)

cat > nginx-replicaset.yaml << 'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
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
      - image: nginx:1.27
        name: nginx
EOF

# Aplicar
kubectl apply -f nginx-replicaset.yaml
```

### Convertendo para DaemonSet

```bash
# Editar o arquivo
# 1. Mudar kind: Deployment para kind: DaemonSet
# 2. Remover o campo replicas (DaemonSet não usa)

cat > node-monitor-daemonset.yaml << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
spec:
  selector:
    matchLabels:
      app: node-monitor
  template:
    metadata:
      labels:
        app: node-monitor
    spec:
      containers:
      - image: busybox:1.36
        name: monitor
        command: ['sh', '-c', 'while true; do echo "Monitoring..."; sleep 30; done']
EOF

# Aplicar
kubectl apply -f node-monitor-daemonset.yaml
```

## Fluxo de Trabalho Recomendado

```
DESENVOLVIMENTO/TESTES:
┌─────────────────────────────────────┐
│ 1. Usar kubectl run/create         │
│    para testes rápidos              │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ 2. Gerar YAML com --dry-run        │
│    kubectl create ... -o yaml       │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ 3. Editar e ajustar o YAML         │
│    Adicionar configurações          │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ 4. Aplicar com kubectl apply       │
│    kubectl apply -f config.yaml     │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ 5. Versionar no Git                │
│    git add config.yaml              │
│    git commit -m "Add config"       │
└─────────────────────────────────────┘


PRODUÇÃO:
┌─────────────────────────────────────┐
│ SEMPRE usar kubectl apply           │
│ com arquivos YAML versionados       │
└─────────────────────────────────────┘
```

## Vantagens do Approach Declarativo (YAML + apply)

### 1. Versionamento com Git

```bash
# Estrutura de diretórios
k8s-configs/
├── base/
│   ├── replicaset.yaml
│   ├── daemonset.yaml
│   └── service.yaml
├── dev/
│   └── kustomization.yaml
└── prod/
    └── kustomization.yaml

# Histórico de mudanças
git log --oneline replicaset.yaml

# Saída:
# a1b2c3d Update nginx to 1.27
# d4e5f6g Add resource limits
# g7h8i9j Initial ReplicaSet config
```

### 2. Reprodutibilidade

```bash
# Aplicar a mesma configuração em múltiplos ambientes
kubectl apply -f replicaset.yaml --context=dev
kubectl apply -f replicaset.yaml --context=staging
kubectl apply -f replicaset.yaml --context=prod

# Ou usar Kustomize
kubectl apply -k ./dev
kubectl apply -k ./prod
```

### 3. Revisão de Código (Code Review)

```bash
# Criar branch para mudança
git checkout -b update-replicaset

# Editar arquivo
vim replicaset.yaml

# Commit e push
git add replicaset.yaml
git commit -m "Update ReplicaSet replicas to 5"
git push origin update-replicaset

# Criar Pull Request para revisão
# Equipe pode revisar as mudanças antes de aplicar
```

### 4. Automação (CI/CD)

```yaml
# .github/workflows/deploy.yml
name: Deploy to Kubernetes
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Deploy ReplicaSet
      run: |
        kubectl apply -f k8s/replicaset.yaml
    - name: Deploy DaemonSet
      run: |
        kubectl apply -f k8s/daemonset.yaml
```

### 5. Documentação Integrada

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  annotations:
    description: "ReplicaSet para aplicação web frontend"
    maintainer: "team-devops@company.com"
    version: "1.0.0"
    changelog: |
      v1.0.0 - Initial release
      v1.1.0 - Added resource limits
      v1.2.0 - Updated to nginx 1.27
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
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

## Quando Usar Cada Abordagem

### Use kubectl run/create (Imperativo)

✅ **Testes rápidos e experimentação**
```bash
kubectl run test-pod --image=nginx:1.27 --rm -it -- /bin/bash
```

✅ **Debug e troubleshooting**
```bash
kubectl run debug --image=busybox:1.36 --rm -it -- sh
```

✅ **Aprendizado inicial**
```bash
kubectl create deployment nginx --image=nginx:1.27
```

### Use kubectl apply (Declarativo)

✅ **Produção (SEMPRE)**
```bash
kubectl apply -f production/
```

✅ **ReplicaSets e DaemonSets (SEMPRE)**
```bash
kubectl apply -f replicaset.yaml
kubectl apply -f daemonset.yaml
```

✅ **Configurações complexas**
```bash
kubectl apply -f complex-config.yaml
```

✅ **Ambientes versionados**
```bash
kubectl apply -k ./overlays/production
```

✅ **CI/CD pipelines**
```bash
kubectl apply -f k8s/ --recursive
```

## Exemplo Completo: Workflow Recomendado

### Passo 1: Desenvolvimento Local

```bash
# Criar arquivo YAML
cat > nginx-replicaset.yaml << 'EOF'
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    app: nginx
    env: dev
spec:
  replicas: 2
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
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF
```

### Passo 2: Validar Antes de Aplicar

```bash
# Validar sintaxe
kubectl apply -f nginx-replicaset.yaml --dry-run=client

# Validar no servidor (sem criar)
kubectl apply -f nginx-replicaset.yaml --dry-run=server

# Ver o que seria criado
kubectl apply -f nginx-replicaset.yaml --dry-run=client -o yaml
```

### Passo 3: Aplicar em Desenvolvimento

```bash
# Aplicar
kubectl apply -f nginx-replicaset.yaml

# Verificar
kubectl get replicaset nginx-rs
kubectl get pods -l app=nginx
```

### Passo 4: Versionar

```bash
# Inicializar Git (se ainda não foi feito)
git init

# Adicionar arquivo
git add nginx-replicaset.yaml

# Commit
git commit -m "Add nginx ReplicaSet with 2 replicas"

# Push para repositório
git push origin main
```

### Passo 5: Atualizar

```bash
# Editar arquivo
vim nginx-replicaset.yaml
# Alterar replicas: 2 para replicas: 3

# Aplicar mudança
kubectl apply -f nginx-replicaset.yaml

# Verificar
kubectl get replicaset nginx-rs

# Versionar mudança
git add nginx-replicaset.yaml
git commit -m "Scale nginx ReplicaSet to 3 replicas"
git push origin main
```

## Resumo

| Aspecto | kubectl create | kubectl apply |
|---------|---------------|---------------|
| **ReplicaSet** | ❌ Não suportado | ✅ Recomendado |
| **DaemonSet** | ❌ Não suportado | ✅ Recomendado |
| **Versionamento** | ❌ Difícil | ✅ Fácil (Git) |
| **Reprodutibilidade** | ❌ Limitada | ✅ Total |
| **Produção** | ❌ Não recomendado | ✅ Obrigatório |
| **Testes rápidos** | ✅ Bom | ⚠️ Requer arquivo |
| **Configurações complexas** | ❌ Limitado | ✅ Suporta tudo |
| **CI/CD** | ❌ Difícil | ✅ Ideal |

## Conclusão

Não usamos `kubectl create` para ReplicaSets e DaemonSets porque:

1. **Não é suportado** - O comando não existe para esses recursos
2. **Não é recomendado** - Mesmo que existisse, YAML é melhor para produção
3. **Limitações** - Comandos imperativos não suportam todas as configurações
4. **Boas práticas** - Abordagem declarativa é o padrão da indústria

**Regra de ouro**: Use `kubectl apply` com arquivos YAML para qualquer coisa que vá para produção, especialmente ReplicaSets e DaemonSets.
