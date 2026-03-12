# Criando um Secret para Autenticar no Docker Hub (dockerconfigjson)

## Introdução

O tipo **kubernetes.io/dockerconfigjson** é usado para armazenar credenciais de registries de containers (Docker Hub, ECR, GCR, etc.). Isso permite que o Kubernetes faça pull de imagens privadas durante a criação de Pods.

## O que é dockerconfigjson?

### Conceito

Um Secret do tipo `dockerconfigjson` contém as credenciais necessárias para autenticar em um registry de containers. É equivalente ao arquivo `~/.docker/config.json` usado pelo Docker CLI.

### Estrutura do dockerconfigjson

```json
{
  "auths": {
    "https://index.docker.io/v1/": {
      "username": "myuser",
      "password": "mypassword",
      "email": "myemail@example.com",
      "auth": "base64(username:password)"
    }
  }
}
```

### Quando Usar

- Pull de imagens privadas do Docker Hub
- Pull de imagens de registries privados (ECR, GCR, ACR, Harbor)
- Autenticação em múltiplos registries
- CI/CD pipelines que usam imagens privadas

## Fluxo de Funcionamento

```
1. Secret dockerconfigjson criado
   ↓
2. Pod referencia Secret em imagePullSecrets
   ↓
3. Kubelet precisa fazer pull da imagem
   ↓
4. Kubelet lê credenciais do Secret
   ↓
5. Kubelet autentica no registry
   ↓
6. Imagem privada baixada
   ↓
7. Container iniciado
```

## Método 1: kubectl create (Recomendado)

### Sintaxe

```bash
kubectl create secret docker-registry <nome> \
  --docker-server=<servidor> \
  --docker-username=<usuario> \
  --docker-password=<senha> \
  --docker-email=<email>
```

### Exemplo 1: Docker Hub

```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myusername \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

**Saída esperada:**
```
secret/dockerhub-secret created
```

### Verificar Secret

```bash
kubectl get secret dockerhub-secret
```

**Saída esperada:**
```
NAME               TYPE                             DATA   AGE
dockerhub-secret   kubernetes.io/dockerconfigjson   1      10s
```

### Ver Detalhes

```bash
kubectl describe secret dockerhub-secret
```

**Saída esperada:**
```
Name:         dockerhub-secret
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  kubernetes.io/dockerconfigjson

Data
====
.dockerconfigjson:  123 bytes
```

### Ver Conteúdo (Decodificado)

```bash
kubectl get secret dockerhub-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

**Saída esperada:**
```json
{
  "auths": {
    "https://index.docker.io/v1/": {
      "username": "myusername",
      "password": "mypassword",
      "email": "myemail@example.com",
      "auth": "bXl1c2VybmFtZTpteXBhc3N3b3Jk"
    }
  }
}
```

### Exemplo 2: Docker Hub com Token de Acesso

```bash
# Usar Personal Access Token em vez de senha
kubectl create secret docker-registry dockerhub-token \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myusername \
  --docker-password=dckr_pat_1234567890abcdefghijklmnop \
  --docker-email=myemail@example.com
```

**Nota:** Tokens de acesso são mais seguros que senhas.

### Exemplo 3: Registry Privado

```bash
kubectl create secret docker-registry private-registry \
  --docker-server=registry.example.com \
  --docker-username=admin \
  --docker-password=secret123
```

**Saída esperada:**
```
secret/private-registry created
```

### Exemplo 4: AWS ECR

```bash
# Obter token do ECR (válido por 12 horas)
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1
ECR_PASSWORD=$(aws ecr get-login-password --region $AWS_REGION)

# Criar Secret
kubectl create secret docker-registry ecr-secret \
  --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$ECR_PASSWORD
```

**Saída esperada:**
```
secret/ecr-secret created
```

### Exemplo 5: Google Container Registry (GCR)

```bash
# Usar service account key
kubectl create secret docker-registry gcr-secret \
  --docker-server=gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat ~/gcp-key.json)"
```

**Saída esperada:**
```
secret/gcr-secret created
```

### Exemplo 6: Azure Container Registry (ACR)

```bash
ACR_NAME=myregistry
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

kubectl create secret docker-registry acr-secret \
  --docker-server=${ACR_NAME}.azurecr.io \
  --docker-username=$ACR_NAME \
  --docker-password=$ACR_PASSWORD
```

**Saída esperada:**
```
secret/acr-secret created
```

## Método 2: YAML Manual

### Estrutura

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-json>
```

### Exemplo 1: Criar JSON e Codificar

```bash
# Criar arquivo JSON
cat > docker-config.json << 'EOF'
{
  "auths": {
    "https://index.docker.io/v1/": {
      "username": "myusername",
      "password": "mypassword",
      "email": "myemail@example.com",
      "auth": "bXl1c2VybmFtZTpteXBhc3N3b3Jk"
    }
  }
}
EOF

# Codificar em base64
cat docker-config.json | base64 -w 0
```

**Saída esperada:**
```
ewogICJhdXRocyI6IHsKICAgICJodHRwczovL2luZGV4LmRvY2tlci5pby92MS8iOiB7CiAgICAgICJ1c2VybmFtZSI6ICJteXVzZXJuYW1lIiwKICAgICAgInBhc3N3b3JkIjogIm15cGFzc3dvcmQiLAogICAgICAiZW1haWwiOiAibXllbWFpbEBleGFtcGxlLmNvbSIsCiAgICAgICJhdXRoIjogImJYbDFjMlZ5Ym1GdFpUcHRlWEJoYzNOM2IzSmsiCiAgICB9CiAgfQp9Cg==
```

### YAML Completo

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-yaml
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ewogICJhdXRocyI6IHsKICAgICJodHRwczovL2luZGV4LmRvY2tlci5pby92MS8iOiB7CiAgICAgICJ1c2VybmFtZSI6ICJteXVzZXJuYW1lIiwKICAgICAgInBhc3N3b3JkIjogIm15cGFzc3dvcmQiLAogICAgICAiZW1haWwiOiAibXllbWFpbEBleGFtcGxlLmNvbSIsCiAgICAgICJhdXRoIjogImJYbDFjMlZ5Ym1GdFpUcHRlWEJoYzNOM2IzSmsiCiAgICB9CiAgfQp9Cg==
```

```bash
kubectl apply -f dockerhub-yaml.yaml
```

**Saída esperada:**
```
secret/dockerhub-yaml created
```

### Exemplo 2: stringData (Mais Fácil)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-stringdata
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "https://index.docker.io/v1/": {
          "username": "myusername",
          "password": "mypassword",
          "email": "myemail@example.com",
          "auth": "bXl1c2VybmFtZTpteXBhc3N3b3Jk"
        }
      }
    }
```

```bash
kubectl apply -f dockerhub-stringdata.yaml
```

**Saída esperada:**
```
secret/dockerhub-stringdata created
```

### Exemplo 3: Múltiplos Registries

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: multi-registry
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "https://index.docker.io/v1/": {
          "username": "dockerhub-user",
          "password": "dockerhub-pass",
          "auth": "ZG9ja2VyaHViLXVzZXI6ZG9ja2VyaHViLXBhc3M="
        },
        "registry.example.com": {
          "username": "private-user",
          "password": "private-pass",
          "auth": "cHJpdmF0ZS11c2VyOnByaXZhdGUtcGFzcw=="
        },
        "gcr.io": {
          "username": "_json_key",
          "password": "{\"type\":\"service_account\",...}",
          "auth": "X2pzb25fa2V5Ont9"
        }
      }
    }
```

```bash
kubectl apply -f multi-registry.yaml
```

## Método 3: A partir do ~/.docker/config.json

### Usar Arquivo Docker Existente

```bash
# Se você já fez docker login
docker login

# Criar Secret a partir do arquivo
kubectl create secret generic dockerhub-from-file \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson
```

**Saída esperada:**
```
secret/dockerhub-from-file created
```

### Verificar

```bash
kubectl get secret dockerhub-from-file -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

## Usando o Secret em Pods

### Método 1: imagePullSecrets no Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  containers:
  - name: app
    image: myusername/private-app:latest
    ports:
    - containerPort: 8080
  imagePullSecrets:
  - name: dockerhub-secret
```

```bash
kubectl apply -f private-image-pod.yaml
```

**Saída esperada:**
```
pod/private-image-pod created
```

### Verificar Pod

```bash
kubectl get pod private-image-pod
```

**Saída esperada:**
```
NAME                READY   STATUS    RESTARTS   AGE
private-image-pod   1/1     Running   0          30s
```

### Ver Eventos (Se Houver Erro)

```bash
kubectl describe pod private-image-pod
```

**Saída esperada (sucesso):**
```
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  30s   default-scheduler  Successfully assigned default/private-image-pod to node1
  Normal  Pulling    29s   kubelet            Pulling image "myusername/private-app:latest"
  Normal  Pulled     25s   kubelet            Successfully pulled image "myusername/private-app:latest"
  Normal  Created    25s   kubelet            Created container app
  Normal  Started    25s   kubelet            Started container app
```

### Método 2: imagePullSecrets no Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: private-app
  labels:
    app: private-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: private-app
  template:
    metadata:
      labels:
        app: private-app
    spec:
      containers:
      - name: app
        image: myusername/private-app:v1.0
        ports:
        - containerPort: 8080
      imagePullSecrets:
      - name: dockerhub-secret
```

```bash
kubectl apply -f private-app-deployment.yaml
```

**Saída esperada:**
```
deployment.apps/private-app created
```

### Verificar Deployment

```bash
kubectl get deployment private-app
```

**Saída esperada:**
```
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
private-app   3/3     3            3           45s
```

### Método 3: imagePullSecrets no ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
imagePullSecrets:
- name: dockerhub-secret
- name: private-registry
- name: gcr-secret
```

```bash
kubectl apply -f app-sa.yaml
```

**Saída esperada:**
```
serviceaccount/app-sa created
```

### Usar ServiceAccount no Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-sa
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: myusername/private-app:latest
```

```bash
kubectl apply -f pod-with-sa.yaml
```

**Saída esperada:**
```
pod/pod-with-sa created
```

**Vantagem:** Todos os Pods que usam esse ServiceAccount herdam os imagePullSecrets automaticamente.

## Exemplo Prático Completo: Aplicação Privada

### 1. Criar Imagem Privada (Simulação)

```bash
# Criar Dockerfile simples
cat > Dockerfile << 'EOF'
FROM nginx:alpine
RUN echo "<h1>Private App</h1>" > /usr/share/nginx/html/index.html
EOF

# Build
docker build -t myusername/private-app:v1.0 .

# Login no Docker Hub
docker login

# Push
docker push myusername/private-app:v1.0
```

### 2. Criar Secret

```bash
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myusername \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

**Saída esperada:**
```
secret/dockerhub-creds created
```

### 3. Deployment Completo

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: private-webapp
  labels:
    app: private-webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: private-webapp
  template:
    metadata:
      labels:
        app: private-webapp
    spec:
      containers:
      - name: webapp
        image: myusername/private-app:v1.0
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      imagePullSecrets:
      - name: dockerhub-creds
---
apiVersion: v1
kind: Service
metadata:
  name: private-webapp
spec:
  selector:
    app: private-webapp
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

```bash
kubectl apply -f private-webapp.yaml
```

**Saída esperada:**
```
deployment.apps/private-webapp created
service/private-webapp created
```

### 4. Verificar

```bash
# Verificar Deployment
kubectl get deployment private-webapp

# Verificar Pods
kubectl get pods -l app=private-webapp

# Verificar Service
kubectl get service private-webapp

# Testar aplicação
kubectl port-forward service/private-webapp 8080:80
# Acessar http://localhost:8080
```

**Saída esperada:**
```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
private-webapp   2/2     2            2           1m

NAME                              READY   STATUS    RESTARTS   AGE
private-webapp-5d7f8c9b4d-abc12   1/1     Running   0          1m
private-webapp-5d7f8c9b4d-def34   1/1     Running   0          1m

NAME             TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
private-webapp   LoadBalancer   10.96.100.50    <pending>     80:30080/TCP   1m
```

## Exemplo: CI/CD com Múltiplos Registries

### Cenário

Aplicação que usa imagens de diferentes registries:
- Frontend: Docker Hub privado
- Backend: AWS ECR
- Database: Google GCR

### 1. Criar Secrets

```bash
# Docker Hub
kubectl create secret docker-registry dockerhub \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myuser \
  --docker-password=mypass

# AWS ECR
kubectl create secret docker-registry ecr \
  --docker-server=123456789012.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1)

# Google GCR
kubectl create secret docker-registry gcr \
  --docker-server=gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat ~/gcp-key.json)"
```

### 2. ServiceAccount com Múltiplos Secrets

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: multi-registry-sa
imagePullSecrets:
- name: dockerhub
- name: ecr
- name: gcr
```

```bash
kubectl apply -f multi-registry-sa.yaml
```

### 3. Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-registry-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multi-registry-app
  template:
    metadata:
      labels:
        app: multi-registry-app
    spec:
      serviceAccountName: multi-registry-sa
      containers:
      - name: frontend
        image: myuser/frontend:latest
      - name: backend
        image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest
      - name: database
        image: gcr.io/my-project/database:latest
```

```bash
kubectl apply -f multi-registry-app.yaml
```

## Rotação de Credenciais

### Atualizar Secret

```bash
# Deletar Secret antigo
kubectl delete secret dockerhub-secret

# Criar novo Secret com novas credenciais
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myusername \
  --docker-password=new-password \
  --docker-email=myemail@example.com

# Reiniciar Pods para usar novo Secret
kubectl rollout restart deployment private-app
```

**Saída esperada:**
```
secret "dockerhub-secret" deleted
secret/dockerhub-secret created
deployment.apps/private-app restarted
```

### Atualizar Secret sem Downtime

```bash
# Criar novo Secret com nome diferente
kubectl create secret docker-registry dockerhub-secret-v2 \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myusername \
  --docker-password=new-password

# Atualizar Deployment para usar novo Secret
kubectl patch deployment private-app -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"dockerhub-secret-v2"}]}}}}'

# Após confirmar funcionamento, deletar Secret antigo
kubectl delete secret dockerhub-secret
```

## Troubleshooting

### Erro: ImagePullBackOff

```bash
kubectl describe pod <pod-name>
```

**Saída de erro:**
```
Events:
  Type     Reason     Message
  ----     ------     -------
  Warning  Failed     Failed to pull image "myuser/private-app:latest": rpc error: code = Unknown desc = Error response from daemon: pull access denied for myuser/private-app, repository does not exist or may require 'docker login'
  Warning  Failed     Error: ErrImagePull
  Normal   BackOff    Back-off pulling image "myuser/private-app:latest"
  Warning  Failed     Error: ImagePullBackOff
```

**Causas comuns:**
1. Secret não existe
2. Secret no namespace errado
3. Credenciais incorretas
4. Imagem não existe
5. imagePullSecrets não configurado

### Verificar Secret

```bash
# Secret existe?
kubectl get secret dockerhub-secret

# Secret no namespace correto?
kubectl get secret dockerhub-secret -n <namespace>

# Credenciais corretas?
kubectl get secret dockerhub-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq

# Testar credenciais manualmente
docker login -u <username> -p <password>
```

### Verificar imagePullSecrets no Pod

```bash
kubectl get pod <pod-name> -o jsonpath='{.spec.imagePullSecrets}'
```

**Saída esperada:**
```json
[{"name":"dockerhub-secret"}]
```

### Testar Pull Manual

```bash
# No node onde o Pod está rodando
docker pull myuser/private-app:latest
```

## Comandos Úteis

### Criar

```bash
# Docker Hub
kubectl create secret docker-registry <name> \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<user> \
  --docker-password=<pass>

# Registry privado
kubectl create secret docker-registry <name> \
  --docker-server=<server> \
  --docker-username=<user> \
  --docker-password=<pass>

# Com namespace
kubectl create secret docker-registry <name> \
  --docker-server=<server> \
  --docker-username=<user> \
  --docker-password=<pass> \
  --namespace=<namespace>
```

### Listar

```bash
# Todos os Secrets
kubectl get secrets

# Apenas dockerconfigjson
kubectl get secrets --field-selector type=kubernetes.io/dockerconfigjson

# Com detalhes
kubectl get secrets -o wide
```

### Visualizar

```bash
# Descrever
kubectl describe secret <name>

# Ver JSON decodificado
kubectl get secret <name> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq

# Ver apenas auths
kubectl get secret <name> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.auths'
```

### Copiar para Outro Namespace

```bash
kubectl get secret dockerhub-secret -n default -o yaml | \
  sed 's/namespace: default/namespace: production/' | \
  kubectl apply -f -
```

## Boas Práticas

### 1. Use Tokens em Vez de Senhas

```bash
# Docker Hub: Personal Access Token
# GitHub: Personal Access Token
# GitLab: Deploy Token
kubectl create secret docker-registry registry-token \
  --docker-username=myuser \
  --docker-password=<token>
```

### 2. Um Secret por Registry

```bash
# ✅ Separado
kubectl create secret docker-registry dockerhub-secret ...
kubectl create secret docker-registry ecr-secret ...
kubectl create secret docker-registry gcr-secret ...

# ❌ Evite misturar tudo em um Secret
```

### 3. Use ServiceAccount

```yaml
# ✅ Centralizado
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
imagePullSecrets:
- name: dockerhub-secret
```

### 4. Rotação Regular

```bash
# Agendar rotação de credenciais
# Exemplo: a cada 90 dias
```

### 5. Namespace Específico

```bash
# Criar Secret no namespace correto
kubectl create secret docker-registry secret-name \
  --docker-username=user \
  --docker-password=pass \
  --namespace=production
```

### 6. Labels e Annotations

```yaml
metadata:
  name: dockerhub-secret
  labels:
    registry: dockerhub
    environment: production
  annotations:
    created-by: "devops-team"
    rotation-date: "2026-06-01"
```

## Limpeza

```bash
# Remover Secrets
kubectl delete secret dockerhub-secret dockerhub-token private-registry
kubectl delete secret ecr-secret gcr-secret acr-secret
kubectl delete secret dockerhub-yaml dockerhub-stringdata multi-registry
kubectl delete secret dockerhub-from-file dockerhub-creds

# Remover Pods e Deployments
kubectl delete pod private-image-pod pod-with-sa
kubectl delete deployment private-app private-webapp multi-registry-app

# Remover ServiceAccount
kubectl delete serviceaccount app-sa multi-registry-sa

# Remover Service
kubectl delete service private-webapp
```

## Resumo

- **dockerconfigjson** armazena credenciais de registry
- **kubectl create docker-registry** é o método mais fácil
- Use **imagePullSecrets** no Pod ou Deployment
- **ServiceAccount** centraliza imagePullSecrets
- Suporta **múltiplos registries** em um Secret
- **Tokens são mais seguros** que senhas
- **Rotação regular** de credenciais é essencial
- Troubleshooting: verificar Secret, namespace e credenciais

## Próximos Passos

- Automatizar **rotação de credenciais** com CronJob
- Integrar com **External Secrets Operator**
- Usar **Workload Identity** (GKE) ou **IRSA** (EKS)
- Implementar **registry mirror** para cache
- Configurar **image pull policies**
