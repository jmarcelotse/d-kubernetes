# Conhecendo o YAML e o kubectl com Dry-run

Este guia explica a sintaxe YAML para Kubernetes e como usar dry-run para gerar e validar manifests sem aplicá-los ao cluster.

## O que é YAML?

**YAML** (YAML Ain't Markup Language) é um formato de serialização de dados legível por humanos, usado pelo Kubernetes para definir recursos.

### Características

- **Legível**: Sintaxe simples e clara
- **Hierárquico**: Usa indentação para estrutura
- **Sensível a espaços**: Indentação define hierarquia
- **Declarativo**: Descreve estado desejado

### YAML vs JSON

```yaml
# YAML
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.21
```

```json
// JSON (equivalente)
{
  "apiVersion": "v1",
  "kind": "Pod",
  "metadata": {
    "name": "nginx"
  },
  "spec": {
    "containers": [
      {
        "name": "nginx",
        "image": "nginx:1.21"
      }
    ]
  }
}
```

## Sintaxe YAML Básica

### Indentação

```yaml
# Use 2 espaços (não tabs!)
parent:
  child:
    grandchild: value
```

### Tipos de Dados

```yaml
# String
name: nginx
description: "Web server"
multiline: |
  Linha 1
  Linha 2
  Linha 3

# Número
replicas: 3
port: 80
cpu: 0.5

# Boolean
enabled: true
debug: false

# Null
value: null
value: ~

# Lista (array)
ports:
- 80
- 443
- 8080

# Ou inline
ports: [80, 443, 8080]

# Objeto (map)
metadata:
  name: nginx
  namespace: default

# Lista de objetos
containers:
- name: nginx
  image: nginx:1.21
- name: sidecar
  image: busybox
```

### Comentários

```yaml
# Comentário de linha única
apiVersion: v1  # Comentário inline
kind: Pod

# Comentários múltiplas linhas
# Linha 1
# Linha 2
metadata:
  name: nginx
```

### Âncoras e Aliases (Reutilização)

```yaml
# Definir âncora
defaults: &defaults
  replicas: 3
  strategy:
    type: RollingUpdate

# Usar alias
deployment1:
  <<: *defaults
  name: app1

deployment2:
  <<: *defaults
  name: app2
  replicas: 5  # Sobrescreve
```

## Estrutura de um Manifest Kubernetes

### Campos Obrigatórios

Todo manifest Kubernetes tem 4 campos obrigatórios:

```yaml
apiVersion: v1        # Versão da API
kind: Pod             # Tipo de recurso
metadata:             # Metadados
  name: nginx-pod
spec:                 # Especificação
  containers:
  - name: nginx
    image: nginx
```

### apiVersion

Define a versão da API do Kubernetes:

```yaml
# Core API (v1)
apiVersion: v1
kind: Pod, Service, ConfigMap, Secret, Namespace, PersistentVolume

# Apps API
apiVersion: apps/v1
kind: Deployment, StatefulSet, DaemonSet, ReplicaSet

# Batch API
apiVersion: batch/v1
kind: Job, CronJob

# Networking
apiVersion: networking.k8s.io/v1
kind: Ingress, NetworkPolicy

# RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: Role, RoleBinding, ClusterRole, ClusterRoleBinding

# Storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
```

**Ver versões disponíveis:**
```bash
kubectl api-versions
```

### kind

Tipo de recurso a ser criado:

```yaml
kind: Pod
kind: Deployment
kind: Service
kind: ConfigMap
kind: Secret
```

**Ver recursos disponíveis:**
```bash
kubectl api-resources
```

### metadata

Metadados do recurso:

```yaml
metadata:
  name: nginx-pod              # Nome (obrigatório)
  namespace: default           # Namespace
  labels:                      # Labels (key-value)
    app: nginx
    env: production
    tier: frontend
  annotations:                 # Annotations (metadados)
    description: "NGINX web server"
    owner: "team-platform"
    version: "1.0"
```

### spec

Especificação do recurso (varia por tipo):

```yaml
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
```

## Exemplos de Manifests

### Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
    env: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
    env:
    - name: ENV
      value: "development"
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
```

### Deployment

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
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  sessionAffinity: ClientIP
```

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Chave-valor simples
  ENV: "production"
  LOG_LEVEL: "info"
  
  # Arquivo completo
  app.properties: |
    server.port=8080
    server.host=0.0.0.0
    database.url=postgres://db:5432
```

### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  # Valores em base64
  username: YWRtaW4=        # admin
  password: cGFzc3dvcmQ=    # password
stringData:
  # Valores em texto plano (convertidos automaticamente)
  api-key: "my-secret-key"
```

### Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    env: dev
```

### Múltiplos Recursos

```yaml
# Separar com ---
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
---
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
      - name: webapp
        image: nginx:1.21
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: myapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
```

## kubectl Dry-run

**Dry-run** permite testar comandos sem aplicá-los ao cluster, útil para:
- Gerar manifests YAML
- Validar sintaxe
- Testar mudanças
- Criar templates

### Tipos de Dry-run

#### client (--dry-run=client)

Valida apenas no cliente (kubectl), não envia ao servidor.

```bash
# Gerar YAML sem criar
kubectl run nginx --image=nginx --dry-run=client -o yaml

# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=3 --dry-run=client -o yaml

# Criar service
kubectl expose deployment nginx --port=80 --dry-run=client -o yaml
```

**Uso:** Gerar templates YAML rapidamente.

#### server (--dry-run=server)

Envia ao servidor para validação completa (RBAC, admission controllers, etc).

```bash
# Validar no servidor
kubectl apply -f deployment.yaml --dry-run=server

# Validar criação
kubectl create deployment nginx --image=nginx --dry-run=server
```

**Uso:** Validar se recurso pode ser criado antes de aplicar.

### Gerando Manifests com Dry-run

#### Pod

```bash
# Pod básico
kubectl run nginx --image=nginx --dry-run=client -o yaml

# Pod com porta
kubectl run nginx --image=nginx --port=80 --dry-run=client -o yaml

# Pod com variáveis de ambiente
kubectl run nginx --image=nginx --env="ENV=prod" --dry-run=client -o yaml

# Pod com labels
kubectl run nginx --image=nginx --labels="app=nginx,tier=frontend" --dry-run=client -o yaml

# Salvar em arquivo
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
```

**Output:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: nginx
  name: nginx
spec:
  containers:
  - image: nginx
    name: nginx
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

#### Deployment

```bash
# Deployment básico
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml

# Com réplicas
kubectl create deployment nginx --image=nginx --replicas=3 --dry-run=client -o yaml

# Com múltiplos containers (editar depois)
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml

# Salvar
kubectl create deployment webapp \
  --image=nginx:1.21 \
  --replicas=3 \
  --dry-run=client -o yaml > deployment.yaml
```

#### Service

```bash
# ClusterIP
kubectl create service clusterip nginx --tcp=80:80 --dry-run=client -o yaml

# NodePort
kubectl create service nodeport nginx --tcp=80:80 --node-port=30080 --dry-run=client -o yaml

# LoadBalancer
kubectl create service loadbalancer nginx --tcp=80:80 --dry-run=client -o yaml

# Expor deployment
kubectl expose deployment nginx --port=80 --target-port=80 --dry-run=client -o yaml

# Expor com tipo específico
kubectl expose deployment nginx \
  --port=80 \
  --target-port=80 \
  --type=LoadBalancer \
  --dry-run=client -o yaml > service.yaml
```

#### ConfigMap

```bash
# De literais
kubectl create configmap app-config \
  --from-literal=ENV=production \
  --from-literal=LOG_LEVEL=info \
  --dry-run=client -o yaml

# De arquivo
kubectl create configmap app-config \
  --from-file=config.properties \
  --dry-run=client -o yaml

# De diretório
kubectl create configmap app-config \
  --from-file=./configs/ \
  --dry-run=client -o yaml
```

#### Secret

```bash
# Generic secret
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  --dry-run=client -o yaml

# TLS secret
kubectl create secret tls tls-secret \
  --cert=path/to/cert.crt \
  --key=path/to/key.key \
  --dry-run=client -o yaml

# Docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=user \
  --docker-password=pass \
  --docker-email=user@example.com \
  --dry-run=client -o yaml
```

#### Namespace

```bash
kubectl create namespace dev --dry-run=client -o yaml
```

#### Job

```bash
kubectl create job hello \
  --image=busybox \
  -- echo "Hello World" \
  --dry-run=client -o yaml
```

#### CronJob

```bash
kubectl create cronjob hello \
  --image=busybox \
  --schedule="*/5 * * * *" \
  -- echo "Hello" \
  --dry-run=client -o yaml
```

### Workflow com Dry-run

#### 1. Gerar Template

```bash
# Gerar YAML base
kubectl create deployment webapp \
  --image=nginx:1.21 \
  --replicas=3 \
  --dry-run=client -o yaml > deployment.yaml
```

#### 2. Editar Template

```bash
# Editar arquivo
vim deployment.yaml

# Adicionar resources, probes, etc.
```

#### 3. Validar Sintaxe

```bash
# Validar YAML
kubectl apply -f deployment.yaml --dry-run=client

# Validar no servidor
kubectl apply -f deployment.yaml --dry-run=server
```

#### 4. Ver Diferenças

```bash
# Ver o que mudaria
kubectl diff -f deployment.yaml
```

#### 5. Aplicar

```bash
# Aplicar ao cluster
kubectl apply -f deployment.yaml
```

### Validando Manifests

#### Validação de Sintaxe

```bash
# Validar YAML (client-side)
kubectl apply -f deployment.yaml --dry-run=client

# Validar com servidor (mais completo)
kubectl apply -f deployment.yaml --dry-run=server

# Validar múltiplos arquivos
kubectl apply -f ./manifests/ --dry-run=server --recursive
```

#### Ver Diferenças

```bash
# Ver o que mudaria
kubectl diff -f deployment.yaml

# Diff de diretório
kubectl diff -f ./manifests/
```

#### Validar Criação

```bash
# Testar se pode criar
kubectl create -f deployment.yaml --dry-run=server

# Testar comando imperativo
kubectl create deployment nginx --image=nginx --dry-run=server
```

## Ferramentas para YAML

### kubectl explain

Documentação inline de recursos:

```bash
# Explicar recurso
kubectl explain pod

# Explicar campo específico
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.resources

# Ver todos os campos
kubectl explain pod --recursive

# Ver com exemplos
kubectl explain pod.spec.containers.livenessProbe
```

### kubeval

Validador de manifests Kubernetes:

```bash
# Instalar
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
tar xf kubeval-linux-amd64.tar.gz
sudo mv kubeval /usr/local/bin

# Validar arquivo
kubeval deployment.yaml

# Validar diretório
kubeval manifests/*.yaml

# Validar versão específica
kubeval --kubernetes-version 1.28.0 deployment.yaml
```

### yamllint

Linter para YAML:

```bash
# Instalar
pip install yamllint

# Validar arquivo
yamllint deployment.yaml

# Validar diretório
yamllint manifests/

# Com configuração customizada
yamllint -c .yamllint deployment.yaml
```

### yq

Processar YAML na linha de comando:

```bash
# Instalar
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Ler valor
yq '.metadata.name' deployment.yaml

# Modificar valor
yq '.spec.replicas = 5' deployment.yaml

# Mesclar arquivos
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' base.yaml overlay.yaml
```

## Exemplos Práticos

### Exemplo 1: Criar Deployment Completo

```bash
# 1. Gerar base
kubectl create deployment webapp \
  --image=nginx:1.21 \
  --replicas=3 \
  --dry-run=client -o yaml > deployment.yaml

# 2. Editar e adicionar configurações
cat <<EOF > deployment.yaml
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
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
EOF

# 3. Validar
kubectl apply -f deployment.yaml --dry-run=server

# 4. Aplicar
kubectl apply -f deployment.yaml
```

### Exemplo 2: Criar Service

```bash
# 1. Gerar base
kubectl expose deployment webapp \
  --port=80 \
  --target-port=80 \
  --type=LoadBalancer \
  --dry-run=client -o yaml > service.yaml

# 2. Validar
kubectl apply -f service.yaml --dry-run=server

# 3. Aplicar
kubectl apply -f service.yaml
```

### Exemplo 3: ConfigMap e Secret

```bash
# 1. Criar ConfigMap
kubectl create configmap app-config \
  --from-literal=ENV=production \
  --from-literal=LOG_LEVEL=info \
  --dry-run=client -o yaml > configmap.yaml

# 2. Criar Secret
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  --dry-run=client -o yaml > secret.yaml

# 3. Usar no Deployment
cat <<EOF >> deployment.yaml
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: db-secret
EOF

# 4. Aplicar tudo
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment.yaml
```

### Exemplo 4: Stack Completo

```bash
# Gerar todos os manifests
kubectl create namespace myapp --dry-run=client -o yaml > namespace.yaml

kubectl create deployment webapp \
  --image=nginx:1.21 \
  --replicas=3 \
  --namespace=myapp \
  --dry-run=client -o yaml > deployment.yaml

kubectl create service loadbalancer webapp \
  --tcp=80:80 \
  --namespace=myapp \
  --dry-run=client -o yaml > service.yaml

# Validar todos
kubectl apply -f . --dry-run=server

# Aplicar
kubectl apply -f .
```

## Boas Práticas

### YAML

1. **Use 2 espaços para indentação**
   ```yaml
   spec:
     containers:
     - name: nginx
   ```

2. **Sempre use aspas para strings com caracteres especiais**
   ```yaml
   value: "true"  # String, não boolean
   value: "123"   # String, não número
   ```

3. **Organize campos logicamente**
   ```yaml
   metadata:
     name: nginx
     namespace: default
     labels:
       app: nginx
   ```

4. **Use comentários**
   ```yaml
   # Production deployment
   replicas: 3  # High availability
   ```

5. **Separe recursos com ---**
   ```yaml
   apiVersion: v1
   kind: Service
   ---
   apiVersion: apps/v1
   kind: Deployment
   ```

### Dry-run

1. **Sempre valide antes de aplicar**
   ```bash
   kubectl apply -f deployment.yaml --dry-run=server
   ```

2. **Use client para gerar, server para validar**
   ```bash
   # Gerar
   kubectl create deployment nginx --image=nginx --dry-run=client -o yaml
   
   # Validar
   kubectl apply -f deployment.yaml --dry-run=server
   ```

3. **Verifique diferenças**
   ```bash
   kubectl diff -f deployment.yaml
   ```

4. **Salve templates**
   ```bash
   kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > template.yaml
   ```

5. **Valide sintaxe YAML**
   ```bash
   yamllint deployment.yaml
   kubeval deployment.yaml
   ```

### Organização

1. **Um recurso por arquivo (pequenos projetos)**
   ```
   manifests/
   ├── namespace.yaml
   ├── deployment.yaml
   ├── service.yaml
   └── configmap.yaml
   ```

2. **Agrupe por aplicação (projetos médios)**
   ```
   manifests/
   ├── webapp/
   │   ├── deployment.yaml
   │   └── service.yaml
   └── database/
       ├── statefulset.yaml
       └── service.yaml
   ```

3. **Agrupe por ambiente (projetos grandes)**
   ```
   manifests/
   ├── base/
   │   ├── deployment.yaml
   │   └── service.yaml
   ├── dev/
   │   └── kustomization.yaml
   └── prod/
       └── kustomization.yaml
   ```

## Troubleshooting

### Erro de Indentação

```bash
# Erro comum
Error: error parsing deployment.yaml: error converting YAML to JSON: yaml: line 10: did not find expected key

# Solução: Verificar indentação
yamllint deployment.yaml
```

### Erro de Tipo

```bash
# Erro
error: unable to recognize "deployment.yaml": no matches for kind "Deploymen" in version "apps/v1"

# Solução: Verificar kind e apiVersion
kubectl api-resources | grep -i deploy
```

### Erro de Validação

```bash
# Erro
error: error validating "deployment.yaml": error validating data: ValidationError

# Solução: Validar com explain
kubectl explain deployment.spec.replicas
```

### Campo Desconhecido

```bash
# Erro
error: error validating "deployment.yaml": error validating data: unknown field "replicass"

# Solução: Verificar nome do campo
kubectl explain deployment.spec --recursive | grep -i replica
```

## Recursos Adicionais

### Documentação
- https://kubernetes.io/docs/concepts/overview/working-with-objects/
- https://kubernetes.io/docs/reference/kubectl/conventions/
- https://yaml.org/spec/

### Ferramentas
- kubectl explain
- kubeval: https://github.com/instrumenta/kubeval
- yamllint: https://github.com/adrienverge/yamllint
- yq: https://github.com/mikefarah/yq

### Editores
- VS Code: Kubernetes extension
- IntelliJ: Kubernetes plugin
- Vim: vim-kubernetes

## Próximos Passos

- **Kustomize**: Customização de manifests
- **Helm**: Templates e gerenciamento de pacotes
- **GitOps**: Argo CD, Flux
- **Validação**: OPA, Kyverno
- **CI/CD**: Integração com pipelines


---

## Exemplos Práticos

### Exemplo 1: Gerar YAML com Dry-run

```bash
# Pod
kubectl run nginx --image=nginx --dry-run=client -o yaml

# Deployment
kubectl create deployment nginx --image=nginx --replicas=3 --dry-run=client -o yaml

# Service
kubectl create service clusterip nginx --tcp=80:80 --dry-run=client -o yaml

# Job
kubectl create job hello --image=busybox --dry-run=client -o yaml -- echo "Hello"

# CronJob
kubectl create cronjob hello --image=busybox --schedule="*/5 * * * *" --dry-run=client -o yaml -- echo "Hello"

# Salvar em arquivo
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml
```

### Exemplo 2: Validar YAML antes de Aplicar

```bash
# Criar arquivo YAML
cat > pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

# Dry-run no cliente (validação básica)
kubectl apply -f pod.yaml --dry-run=client

# Dry-run no servidor (validação completa)
kubectl apply -f pod.yaml --dry-run=server

# Ver diferenças antes de aplicar
kubectl diff -f pod.yaml

# Aplicar se tudo ok
kubectl apply -f pod.yaml
```

### Exemplo 3: YAML Completo de Deployment

```yaml
# deployment-completo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
    environment: production
  annotations:
    description: "Aplicação web principal"
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: v1
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config
        configMap:
          name: webapp-config
```

```bash
# Validar
kubectl apply -f deployment-completo.yaml --dry-run=server

# Aplicar
kubectl apply -f deployment-completo.yaml
```

### Exemplo 4: Múltiplos Recursos em um Arquivo

```yaml
# stack.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: myapp
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: myapp
type: Opaque
stringData:
  DB_PASSWORD: "senha123"
---
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
      - name: webapp
        image: nginx:alpine
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secret
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
```

```bash
# Validar tudo
kubectl apply -f stack.yaml --dry-run=server

# Aplicar
kubectl apply -f stack.yaml

# Verificar
kubectl get all -n myapp

# Deletar tudo
kubectl delete -f stack.yaml
```

### Exemplo 5: Converter JSON para YAML

```bash
# Gerar JSON
kubectl create deployment nginx --image=nginx --dry-run=client -o json > deployment.json

# Converter para YAML (usando yq)
yq eval -P deployment.json > deployment.yaml

# Ou usar kubectl
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml
```

### Exemplo 6: Extrair YAML de Recurso Existente

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Extrair YAML
kubectl get deployment nginx -o yaml > nginx-deployment.yaml

# Limpar campos desnecessários
kubectl get deployment nginx -o yaml | \
  grep -v "creationTimestamp\|resourceVersion\|uid\|selfLink\|status" \
  > nginx-deployment-clean.yaml

# Ou usar --export (deprecated mas útil)
kubectl get deployment nginx -o yaml --export > nginx-deployment.yaml
```

### Exemplo 7: Validar Sintaxe YAML

```bash
# Usando kubectl
kubectl apply -f deployment.yaml --dry-run=client

# Usando yamllint (instalar: pip install yamllint)
yamllint deployment.yaml

# Usando kubeval (instalar: brew install kubeval)
kubeval deployment.yaml

# Usando kube-score (análise de boas práticas)
kube-score score deployment.yaml
```

### Exemplo 8: Templates com Variáveis

```bash
# Criar template
cat > deployment-template.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${IMAGE}
        ports:
        - containerPort: ${PORT}
EOF

# Substituir variáveis
export APP_NAME=webapp
export REPLICAS=3
export IMAGE=nginx:alpine
export PORT=80

envsubst < deployment-template.yaml > deployment.yaml

# Aplicar
kubectl apply -f deployment.yaml
```

---

## Fluxo de Trabalho com YAML e Dry-run

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE TRABALHO YAML + DRY-RUN                │
└─────────────────────────────────────────────────────────┘

1. GERAR YAML BASE
   └─> kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml

2. EDITAR YAML
   ├─> Adicionar recursos (requests/limits)
   ├─> Adicionar probes (liveness/readiness)
   ├─> Adicionar variáveis de ambiente
   └─> Adicionar volumes

3. VALIDAR SINTAXE
   └─> yamllint deployment.yaml

4. DRY-RUN CLIENTE (validação local)
   └─> kubectl apply -f deployment.yaml --dry-run=client

5. DRY-RUN SERVIDOR (validação completa)
   └─> kubectl apply -f deployment.yaml --dry-run=server

6. VER DIFERENÇAS
   └─> kubectl diff -f deployment.yaml

7. APLICAR
   └─> kubectl apply -f deployment.yaml

8. VERIFICAR
   ├─> kubectl get deployments
   ├─> kubectl get pods
   └─> kubectl describe deployment nginx

9. VERSIONAR
   └─> git add deployment.yaml && git commit -m "Add nginx deployment"
```

---

## Boas Práticas com YAML

### 1. Use Indentação Consistente (2 espaços)

```yaml
# ✅ BOM
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx

# ❌ RUIM (tabs ou 4 espaços)
apiVersion: v1
kind: Pod
metadata:
    name: nginx
```

### 2. Sempre Defina Resources

```yaml
# ✅ BOM
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"

# ❌ RUIM (sem resources)
# Pode causar problemas de scheduling
```

### 3. Use Labels Organizadas

```yaml
# ✅ BOM
metadata:
  labels:
    app: webapp
    component: frontend
    environment: production
    version: v1.2.3

# ❌ RUIM (labels genéricas)
metadata:
  labels:
    name: app
```

### 4. Adicione Health Checks

```yaml
# ✅ BOM
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
```

### 5. Use ConfigMaps e Secrets

```yaml
# ✅ BOM
env:
- name: APP_ENV
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: environment
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: password

# ❌ RUIM (hardcoded)
env:
- name: DB_PASSWORD
  value: "senha123"
```

---

## Comandos Úteis

```bash
# Gerar YAML de qualquer recurso
kubectl create <resource> <name> --dry-run=client -o yaml

# Validar antes de aplicar
kubectl apply -f file.yaml --dry-run=server

# Ver diferenças
kubectl diff -f file.yaml

# Aplicar diretório inteiro
kubectl apply -f ./manifests/

# Aplicar recursivamente
kubectl apply -f ./manifests/ -R

# Deletar via YAML
kubectl delete -f file.yaml

# Substituir recurso
kubectl replace -f file.yaml

# Aplicar com force
kubectl apply -f file.yaml --force

# Ver YAML de recurso existente
kubectl get <resource> <name> -o yaml

# Editar recurso diretamente
kubectl edit <resource> <name>

# Explicar campos do YAML
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
```

---

## Troubleshooting

### Erro de Sintaxe YAML

```bash
# Validar sintaxe
kubectl apply -f deployment.yaml --dry-run=client

# Usar yamllint
yamllint deployment.yaml

# Verificar indentação
cat -A deployment.yaml  # Mostra tabs e espaços
```

### Erro de Validação

```bash
# Ver erro detalhado
kubectl apply -f deployment.yaml --dry-run=server -v=8

# Explicar campo
kubectl explain deployment.spec.replicas

# Ver schema completo
kubectl explain deployment --recursive
```

### YAML não Aplica

```bash
# Verificar se recurso já existe
kubectl get deployment nginx

# Ver diferenças
kubectl diff -f deployment.yaml

# Forçar substituição
kubectl replace -f deployment.yaml --force

# Ou deletar e recriar
kubectl delete -f deployment.yaml
kubectl apply -f deployment.yaml
```
