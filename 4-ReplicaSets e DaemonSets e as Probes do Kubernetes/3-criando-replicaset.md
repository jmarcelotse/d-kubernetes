# Criando o Nosso ReplicaSet

## Introdução

Neste guia, vamos criar ReplicaSets do zero, entendendo cada campo do manifesto e testando na prática. Embora em produção você use Deployments, entender como criar ReplicaSets diretamente é fundamental para compreender o funcionamento do Kubernetes.

## Estrutura Básica de um ReplicaSet

```yaml
apiVersion: apps/v1          # Versão da API
kind: ReplicaSet             # Tipo do recurso
metadata:                    # Metadados
  name: nome-replicaset      # Nome único
  labels:                    # Labels do ReplicaSet
    chave: valor
spec:                        # Especificação
  replicas: 3                # Número de réplicas desejadas
  selector:                  # Como identificar os Pods
    matchLabels:
      chave: valor
  template:                  # Template do Pod
    metadata:
      labels:                # Labels dos Pods (deve corresponder ao selector)
        chave: valor
    spec:                    # Especificação do Pod
      containers:
      - name: nome-container
        image: imagem:tag
```

## Exemplo 1: ReplicaSet Simples com Nginx

### Passo 1: Criar o Manifesto

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    app: webserver
    tier: frontend
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

Salve como `nginx-replicaset.yaml`

### Passo 2: Aplicar o ReplicaSet

```bash
# Criar o ReplicaSet
kubectl apply -f nginx-replicaset.yaml

# Saída:
# replicaset.apps/nginx-rs created
```

### Passo 3: Verificar o ReplicaSet

```bash
# Ver o ReplicaSet
kubectl get replicaset nginx-rs

# Saída:
# NAME       DESIRED   CURRENT   READY   AGE
# nginx-rs   3         3         3       10s

# Ver detalhes completos
kubectl describe replicaset nginx-rs
```

### Passo 4: Verificar os Pods Criados

```bash
# Listar Pods
kubectl get pods

# Saída:
# NAME             READY   STATUS    RESTARTS   AGE
# nginx-rs-7x8k9   1/1     Running   0          20s
# nginx-rs-m4n5p   1/1     Running   0          20s
# nginx-rs-q2r3s   1/1     Running   0          20s

# Ver Pods com labels
kubectl get pods --show-labels

# Ver apenas Pods do nosso ReplicaSet
kubectl get pods -l app=nginx
```

### Passo 5: Testar a Autocorreção

```bash
# Deletar um Pod
kubectl delete pod nginx-rs-7x8k9

# Verificar imediatamente
kubectl get pods -l app=nginx

# Saída: Um novo Pod já foi criado automaticamente
# NAME             READY   STATUS    RESTARTS   AGE
# nginx-rs-m4n5p   1/1     Running   0          2m
# nginx-rs-q2r3s   1/1     Running   0          2m
# nginx-rs-t6u7v   1/1     Running   0          3s  ← Novo Pod
```

## Exemplo 2: ReplicaSet com Múltiplos Containers

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: app-rs
  labels:
    app: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      environment: dev
  template:
    metadata:
      labels:
        app: myapp
        environment: dev
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
      - name: busybox
        image: busybox:1.36
        command: ['sh', '-c', 'while true; do echo "Hello from sidecar"; sleep 30; done']
```

Salve como `app-replicaset.yaml`

```bash
# Criar o ReplicaSet
kubectl apply -f app-replicaset.yaml

# Ver os Pods (cada um com 2 containers)
kubectl get pods

# Saída:
# NAME           READY   STATUS    RESTARTS   AGE
# app-rs-abc12   2/2     Running   0          15s
# app-rs-def34   2/2     Running   0          15s

# Ver logs do container específico
kubectl logs app-rs-abc12 -c busybox

# Ver logs do nginx
kubectl logs app-rs-abc12 -c nginx
```

## Exemplo 3: ReplicaSet com Recursos Limitados

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: limited-rs
  labels:
    app: limited
spec:
  replicas: 3
  selector:
    matchLabels:
      app: limited
  template:
    metadata:
      labels:
        app: limited
    spec:
      containers:
      - name: nginx
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

Salve como `limited-replicaset.yaml`

```bash
# Criar o ReplicaSet
kubectl apply -f limited-replicaset.yaml

# Ver recursos dos Pods
kubectl describe pods -l app=limited | grep -A 5 "Limits\|Requests"

# Saída:
#     Limits:
#       cpu:     500m
#       memory:  128Mi
#     Requests:
#       cpu:        250m
#       memory:     64Mi
```

## Exemplo 4: ReplicaSet com Variáveis de Ambiente

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: env-rs
  labels:
    app: envapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: envapp
  template:
    metadata:
      labels:
        app: envapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "development"
        - name: APP_VERSION
          value: "1.0.0"
        - name: LOG_LEVEL
          value: "debug"
```

Salve como `env-replicaset.yaml`

```bash
# Criar o ReplicaSet
kubectl apply -f env-replicaset.yaml

# Verificar variáveis de ambiente em um Pod
kubectl exec env-rs-abc12 -- env | grep -E "ENVIRONMENT|APP_VERSION|LOG_LEVEL"

# Saída:
# ENVIRONMENT=development
# APP_VERSION=1.0.0
# LOG_LEVEL=debug
```

## Exemplo 5: ReplicaSet com Health Checks

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: health-rs
  labels:
    app: healthapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: healthapp
  template:
    metadata:
      labels:
        app: healthapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
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
```

Salve como `health-replicaset.yaml`

```bash
# Criar o ReplicaSet
kubectl apply -f health-replicaset.yaml

# Ver status dos Pods (observe a coluna READY)
kubectl get pods -l app=healthapp

# Ver detalhes das probes
kubectl describe pod health-rs-abc12 | grep -A 10 "Liveness\|Readiness"
```

## Exemplo 6: ReplicaSet com Seletor Avançado

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: advanced-rs
  labels:
    app: advanced
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      tier: backend
    matchExpressions:
    - key: environment
      operator: In
      values:
      - production
      - staging
  template:
    metadata:
      labels:
        app: myapp
        tier: backend
        environment: production
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
```

Salve como `advanced-replicaset.yaml`

```bash
# Criar o ReplicaSet
kubectl apply -f advanced-replicaset.yaml

# Ver Pods com todas as labels
kubectl get pods --show-labels -l app=myapp

# Filtrar por expressão
kubectl get pods -l 'environment in (production,staging)'
```

## Exemplo 7: Criando ReplicaSet via Linha de Comando (Dry-run)

```bash
# Gerar YAML sem criar o recurso
kubectl create replicaset nginx-rs \
  --image=nginx:1.27 \
  --replicas=3 \
  --dry-run=client -o yaml > generated-replicaset.yaml

# Ver o arquivo gerado
cat generated-replicaset.yaml

# Editar conforme necessário e aplicar
kubectl apply -f generated-replicaset.yaml
```

## Exemplo 8: ReplicaSet com Volume EmptyDir

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: volume-rs
  labels:
    app: volumeapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: volumeapp
  template:
    metadata:
      labels:
        app: volumeapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        volumeMounts:
        - name: shared-data
          mountPath: /usr/share/nginx/html
      - name: writer
        image: busybox:1.36
        command: ['sh', '-c', 'while true; do echo "Hello from $(hostname) at $(date)" > /data/index.html; sleep 10; done']
        volumeMounts:
        - name: shared-data
          mountPath: /data
      volumes:
      - name: shared-data
        emptyDir: {}
```

Salve como `volume-replicaset.yaml`

```bash
# Criar o ReplicaSet
kubectl apply -f volume-replicaset.yaml

# Testar o volume compartilhado
kubectl exec volume-rs-abc12 -c nginx -- cat /usr/share/nginx/html/index.html

# Saída:
# Hello from volume-rs-abc12 at Tue Mar 3 14:27:00 UTC 2026

# Fazer port-forward e testar no navegador
kubectl port-forward volume-rs-abc12 8080:80

# Em outro terminal:
curl localhost:8080
```

## Operações Comuns com ReplicaSets

### Escalar o ReplicaSet

```bash
# Método 1: kubectl scale
kubectl scale replicaset nginx-rs --replicas=5

# Método 2: kubectl edit
kubectl edit replicaset nginx-rs
# Alterar spec.replicas para 5

# Método 3: kubectl patch
kubectl patch replicaset nginx-rs -p '{"spec":{"replicas":5}}'

# Verificar
kubectl get replicaset nginx-rs
```

### Ver Logs dos Pods

```bash
# Logs de um Pod específico
kubectl logs nginx-rs-abc12

# Logs de todos os Pods do ReplicaSet
kubectl logs -l app=nginx

# Seguir logs em tempo real
kubectl logs -f nginx-rs-abc12

# Logs de container específico (em Pod multicontainer)
kubectl logs nginx-rs-abc12 -c nginx
```

### Executar Comandos nos Pods

```bash
# Executar comando único
kubectl exec nginx-rs-abc12 -- nginx -v

# Abrir shell interativo
kubectl exec -it nginx-rs-abc12 -- /bin/bash

# Em Pod multicontainer, especificar o container
kubectl exec -it app-rs-abc12 -c nginx -- /bin/bash
```

### Atualizar o ReplicaSet

```bash
# Editar diretamente
kubectl edit replicaset nginx-rs

# Aplicar arquivo modificado
kubectl apply -f nginx-replicaset.yaml

# Patch específico (ex: mudar imagem)
kubectl patch replicaset nginx-rs -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.27.1"}]}}}}'

# IMPORTANTE: Atualizar o ReplicaSet NÃO atualiza Pods existentes!
# Você precisa deletar os Pods manualmente para que sejam recriados
kubectl delete pods -l app=nginx
```

### Deletar o ReplicaSet

```bash
# Deletar ReplicaSet e seus Pods
kubectl delete replicaset nginx-rs

# Deletar usando o arquivo
kubectl delete -f nginx-replicaset.yaml

# Deletar mantendo os Pods (órfãos)
kubectl delete replicaset nginx-rs --cascade=orphan

# Deletar todos os ReplicaSets de uma label
kubectl delete replicaset -l app=nginx
```

## Troubleshooting

### Problema: Pods não são criados

```bash
# Ver eventos do ReplicaSet
kubectl describe replicaset nginx-rs

# Ver eventos do cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Verificar se há recursos suficientes
kubectl top nodes
kubectl describe nodes
```

### Problema: Selector não corresponde aos labels

```bash
# Erro comum:
# The ReplicaSet "nginx-rs" is invalid: spec.template.metadata.labels: 
# Invalid value: map[string]string{"app":"web"}: 
# `selector` does not match template `labels`

# Solução: Labels do template devem incluir todos os labels do selector
```

**Exemplo incorreto:**
```yaml
spec:
  selector:
    matchLabels:
      app: nginx
      tier: frontend
  template:
    metadata:
      labels:
        app: nginx  # Falta tier: frontend
```

**Exemplo correto:**
```yaml
spec:
  selector:
    matchLabels:
      app: nginx
      tier: frontend
  template:
    metadata:
      labels:
        app: nginx
        tier: frontend  # Agora está correto
```

### Problema: ReplicaSet não deleta Pods extras

```bash
# Se você criar Pods manualmente com as mesmas labels,
# o ReplicaSet vai "adotá-los" e pode deletar alguns

# Ver quantos Pods existem
kubectl get pods -l app=nginx

# Se houver mais Pods que o desejado, o ReplicaSet vai deletar os extras
# Para evitar isso, use labels diferentes para Pods manuais
```

## Validando o Manifesto Antes de Aplicar

```bash
# Validar sintaxe YAML
kubectl apply -f nginx-replicaset.yaml --dry-run=client

# Ver o que seria criado
kubectl apply -f nginx-replicaset.yaml --dry-run=client -o yaml

# Validar no servidor (sem criar)
kubectl apply -f nginx-replicaset.yaml --dry-run=server

# Usar kubeval (ferramenta externa)
kubeval nginx-replicaset.yaml
```

## Monitorando o ReplicaSet

```bash
# Watch em tempo real
kubectl get replicaset nginx-rs --watch

# Ver métricas (requer metrics-server)
kubectl top pods -l app=nginx

# Ver eventos continuamente
kubectl get events --watch

# Monitorar múltiplos recursos
watch -n 2 'kubectl get replicaset,pods -l app=nginx'
```

## Exportando ReplicaSet Existente

```bash
# Exportar para YAML
kubectl get replicaset nginx-rs -o yaml > nginx-rs-export.yaml

# Exportar sem informações de runtime
kubectl get replicaset nginx-rs -o yaml \
  | kubectl neat > nginx-rs-clean.yaml

# Ou manualmente remover campos desnecessários
kubectl get replicaset nginx-rs -o yaml \
  | grep -v "creationTimestamp\|resourceVersion\|uid\|selfLink" \
  > nginx-rs-clean.yaml
```

## Boas Práticas ao Criar ReplicaSets

1. **Use labels descritivas e consistentes**
   ```yaml
   labels:
     app: nome-app
     tier: frontend/backend
     environment: dev/staging/prod
     version: v1.0.0
   ```

2. **Sempre defina recursos (requests e limits)**
   ```yaml
   resources:
     requests:
       memory: "64Mi"
       cpu: "250m"
     limits:
       memory: "128Mi"
       cpu: "500m"
   ```

3. **Configure health checks (probes)**
   ```yaml
   livenessProbe:
     httpGet:
       path: /health
       port: 80
   readinessProbe:
     httpGet:
       path: /ready
       port: 80
   ```

4. **Use nomes significativos**
   - Nome do ReplicaSet: `app-tier-rs` (ex: `web-frontend-rs`)
   - Nome do container: descreva sua função

5. **Documente com annotations**
   ```yaml
   metadata:
     annotations:
       description: "ReplicaSet para aplicação web frontend"
       maintainer: "time-devops@empresa.com"
       version: "1.0.0"
   ```

6. **Valide antes de aplicar**
   ```bash
   kubectl apply -f replicaset.yaml --dry-run=client
   ```

7. **Use namespaces para organização**
   ```yaml
   metadata:
     name: nginx-rs
     namespace: production
   ```

## Limpeza Completa

```bash
# Deletar todos os ReplicaSets criados neste guia
kubectl delete replicaset nginx-rs app-rs limited-rs env-rs health-rs advanced-rs volume-rs

# Ou deletar por label
kubectl delete replicaset -l tier=frontend

# Verificar que tudo foi removido
kubectl get replicaset
kubectl get pods
```

## Resumo

- ReplicaSets garantem que um número específico de Pods esteja sempre rodando
- A estrutura básica inclui: `replicas`, `selector` e `template`
- Labels do `template` devem corresponder ao `selector`
- ReplicaSets criam Pods automaticamente e os recriam se falharem
- Atualizar o ReplicaSet não atualiza Pods existentes automaticamente
- Em produção, use Deployments em vez de ReplicaSets diretamente
- Sempre valide manifestos com `--dry-run` antes de aplicar
