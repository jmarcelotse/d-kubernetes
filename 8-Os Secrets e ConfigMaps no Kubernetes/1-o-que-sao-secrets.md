# O que são as Secrets do Kubernetes?

## Introdução

**Secrets** são objetos do Kubernetes projetados para armazenar e gerenciar informações sensíveis, como senhas, tokens OAuth, chaves SSH e certificados TLS. Eles permitem que você separe dados confidenciais da configuração da aplicação.

## Conceito

Um Secret é um objeto que contém uma pequena quantidade de dados sensíveis, como uma senha ou chave. Usar Secrets evita que você precise incluir dados confidenciais diretamente no código da aplicação ou nos manifestos YAML.

### Por Que Usar Secrets?

- **Segurança:** Separa dados sensíveis do código da aplicação
- **Centralização:** Gerencia credenciais em um único lugar
- **Controle de Acesso:** RBAC para controlar quem pode acessar
- **Versionamento Seguro:** Evita expor credenciais no Git
- **Rotação:** Facilita atualização de credenciais
- **Auditoria:** Rastreamento de acesso a dados sensíveis

## Características

### Armazenamento

- Dados armazenados em **base64** (não é criptografia!)
- No etcd, podem ser criptografados em repouso (encryption at rest)
- Tamanho máximo: **1MB** por Secret
- Transmitidos apenas para nodes que executam Pods que os utilizam

### Segurança

- Secrets são montados em **tmpfs** (memória RAM), não em disco
- Apenas Pods no mesmo namespace podem acessar
- RBAC controla acesso via API
- Não são criptografados por padrão (apenas base64)

### Tipos de Secrets

| Tipo | Descrição | Uso |
|------|-----------|-----|
| **Opaque** | Dados arbitrários (padrão) | Senhas, tokens, chaves |
| **kubernetes.io/service-account-token** | Token de ServiceAccount | Autenticação de Pods |
| **kubernetes.io/dockercfg** | Credenciais Docker (legado) | Pull de imagens privadas |
| **kubernetes.io/dockerconfigjson** | Credenciais Docker | Pull de imagens privadas |
| **kubernetes.io/basic-auth** | Credenciais básicas | Autenticação HTTP |
| **kubernetes.io/ssh-auth** | Chave SSH | Autenticação SSH |
| **kubernetes.io/tls** | Certificado TLS | HTTPS, mTLS |
| **bootstrap.kubernetes.io/token** | Token de bootstrap | Inicialização de nodes |

## Diferença: Secrets vs ConfigMaps

| Aspecto | Secrets | ConfigMaps |
|---------|---------|------------|
| **Propósito** | Dados sensíveis | Configurações não sensíveis |
| **Codificação** | Base64 | Texto plano |
| **Segurança** | Criptografia opcional | Sem criptografia |
| **Armazenamento** | tmpfs (RAM) | Pode ser disco |
| **Tamanho** | Até 1MB | Até 1MB |
| **Uso** | Senhas, tokens, chaves | Variáveis de ambiente, configs |

## Fluxo de Funcionamento

```
1. Criar Secret
   ↓
2. Secret armazenado no etcd (base64)
   ↓
3. Pod referencia Secret
   ↓
4. Kubelet busca Secret da API
   ↓
5. Secret montado em tmpfs no Pod
   ↓
6. Aplicação lê Secret (decodificado)
```

## Anatomia de um Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
type: Opaque
data:
  username: YWRtaW4=        # base64 de "admin"
  password: cGFzc3dvcmQ=    # base64 de "password"
stringData:
  api-key: my-api-key-123   # Texto plano (convertido para base64)
```

### Campos Principais

- **apiVersion:** Sempre `v1`
- **kind:** Sempre `Secret`
- **metadata.name:** Nome único no namespace
- **type:** Tipo do Secret (Opaque, TLS, etc.)
- **data:** Dados em base64
- **stringData:** Dados em texto plano (convertidos automaticamente)

## Exemplo Prático 1: Secret Opaque Básico

### Criar Secret via kubectl

```bash
# Criar Secret a partir de literais
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=s3cr3t123

# Criar Secret a partir de arquivo
echo -n 'admin' > username.txt
echo -n 's3cr3t123' > password.txt
kubectl create secret generic db-credentials-file \
  --from-file=username=username.txt \
  --from-file=password=password.txt

# Limpar arquivos
rm username.txt password.txt
```

**Saída esperada:**
```
secret/db-credentials created
secret/db-credentials-file created
```

### Verificar Secret

```bash
kubectl get secrets
```

**Saída esperada:**
```
NAME                   TYPE     DATA   AGE
db-credentials         Opaque   2      30s
db-credentials-file    Opaque   2      20s
```

### Ver Detalhes do Secret

```bash
kubectl describe secret db-credentials
```

**Saída esperada:**
```
Name:         db-credentials
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
password:  9 bytes
username:  5 bytes
```

### Ver Conteúdo do Secret (base64)

```bash
kubectl get secret db-credentials -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  password: czNjcjN0MTIz
  username: YWRtaW4=
kind: Secret
metadata:
  name: db-credentials
  namespace: default
type: Opaque
```

### Decodificar Secret

```bash
# Decodificar username
kubectl get secret db-credentials -o jsonpath='{.data.username}' | base64 -d
echo

# Decodificar password
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
echo
```

**Saída esperada:**
```
admin
s3cr3t123
```

## Exemplo Prático 2: Secret via YAML

### Criar Secret YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  labels:
    app: myapp
type: Opaque
stringData:
  database-url: "postgresql://user:pass@db.example.com:5432/mydb"
  api-key: "sk-1234567890abcdef"
  jwt-secret: "my-super-secret-jwt-key"
```

```bash
kubectl apply -f app-secrets.yaml
```

**Saída esperada:**
```
secret/app-secrets created
```

### Verificar

```bash
kubectl get secret app-secrets -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  api-key: c2stMTIzNDU2Nzg5MGFiY2RlZg==
  database-url: cG9zdGdyZXNxbDovL3VzZXI6cGFzc0BkYi5leGFtcGxlLmNvbTo1NDMyL215ZGI=
  jwt-secret: bXktc3VwZXItc2VjcmV0LWp3dC1rZXk=
kind: Secret
metadata:
  labels:
    app: myapp
  name: app-secrets
  namespace: default
type: Opaque
```

## Exemplo Prático 3: Usando Secret em Pod (Variáveis de Ambiente)

### Pod com Secret como Env

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Username: $DB_USERNAME"
      echo "Password: $DB_PASSWORD"
      echo "API Key: $API_KEY"
      sleep 3600
    env:
    # Referência individual
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    # Todas as chaves do Secret
    envFrom:
    - secretRef:
        name: app-secrets
        prefix: APP_
```

```bash
kubectl apply -f pod-with-secrets.yaml
```

### Verificar Variáveis de Ambiente

```bash
kubectl logs app-with-secrets
```

**Saída esperada:**
```
Username: admin
Password: s3cr3t123
API Key: sk-1234567890abcdef
```

### Verificar Dentro do Pod

```bash
kubectl exec -it app-with-secrets -- sh

# Dentro do Pod
env | grep -E "DB_|APP_"
```

**Saída esperada:**
```
DB_USERNAME=admin
DB_PASSWORD=s3cr3t123
APP_database-url=postgresql://user:pass@db.example.com:5432/mydb
APP_api-key=sk-1234567890abcdef
APP_jwt-secret=my-super-secret-jwt-key
```

## Exemplo Prático 4: Usando Secret como Volume

### Pod com Secret Montado

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secret-volume
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "=== Secret Files ==="
      ls -la /etc/secrets/
      echo ""
      echo "=== Username ==="
      cat /etc/secrets/username
      echo ""
      echo "=== Password ==="
      cat /etc/secrets/password
      echo ""
      sleep 3600
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
```

```bash
kubectl apply -f pod-secret-volume.yaml
```

### Verificar Montagem

```bash
kubectl logs app-with-secret-volume
```

**Saída esperada:**
```
=== Secret Files ===
total 0
drwxrwxrwt 3 root root  120 Mar  9 18:55 .
drwxr-xr-x 1 root root 4096 Mar  9 18:55 ..
drwxr-xr-x 2 root root   80 Mar  9 18:55 ..2026_03_09_18_55_30.123456789
lrwxrwxrwx 1 root root   31 Mar  9 18:55 ..data -> ..2026_03_09_18_55_30.123456789
lrwxrwxrwx 1 root root   15 Mar  9 18:55 password -> ..data/password
lrwxrwxrwx 1 root root   15 Mar  9 18:55 username -> ..data/username

=== Username ===
admin
=== Password ===
s3cr3t123
```

### Verificar Dentro do Pod

```bash
kubectl exec -it app-with-secret-volume -- sh

# Dentro do Pod
ls -la /etc/secrets/
cat /etc/secrets/username
cat /etc/secrets/password
```

## Exemplo Prático 5: Secret com Chaves Específicas

### Montar Apenas Chaves Específicas

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-selective-keys
spec:
  containers:
  - name: app
    image: nginx:1.27-alpine
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: app-secrets
      items:
      - key: api-key
        path: api-key.txt
        mode: 0400
      - key: jwt-secret
        path: jwt/secret.key
        mode: 0400
```

```bash
kubectl apply -f pod-selective-keys.yaml
```

### Verificar

```bash
kubectl exec app-selective-keys -- ls -la /etc/config/
kubectl exec app-selective-keys -- cat /etc/config/api-key.txt
kubectl exec app-selective-keys -- cat /etc/config/jwt/secret.key
```

**Saída esperada:**
```
total 0
drwxrwxrwt 3 root root  100 Mar  9 19:00 .
drwxr-xr-x 1 root root 4096 Mar  9 19:00 ..
drwxr-xr-x 3 root root   60 Mar  9 19:00 ..2026_03_09_19_00_15.123456789
lrwxrwxrwx 1 root root   31 Mar  9 19:00 ..data -> ..2026_03_09_19_00_15.123456789
lrwxrwxrwx 1 root root   18 Mar  9 19:00 api-key.txt -> ..data/api-key.txt
drwxr-xr-x 2 root root   40 Mar  9 19:00 jwt

sk-1234567890abcdef
my-super-secret-jwt-key
```

## Exemplo Prático 6: Secret TLS

### Criar Certificado TLS

```bash
# Gerar chave privada
openssl genrsa -out tls.key 2048

# Gerar certificado autoassinado
openssl req -new -x509 -key tls.key -out tls.crt -days 365 \
  -subj "/CN=myapp.example.com/O=MyOrg"

# Criar Secret TLS
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key

# Limpar arquivos
rm tls.key tls.crt
```

**Saída esperada:**
```
secret/myapp-tls created
```

### Verificar Secret TLS

```bash
kubectl get secret myapp-tls -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  tls.crt: LS0tLS1CRUdJTi...
  tls.key: LS0tLS1CRUdJTi...
kind: Secret
metadata:
  name: myapp-tls
  namespace: default
type: kubernetes.io/tls
```

### Usar Secret TLS em Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

## Exemplo Prático 7: Docker Registry Secret

### Criar Secret para Registry Privado

```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

**Saída esperada:**
```
secret/regcred created
```

### Usar em Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  containers:
  - name: app
    image: myuser/private-image:latest
  imagePullSecrets:
  - name: regcred
```

## Exemplo Prático 8: Secret SSH

### Criar Secret SSH

```bash
# Gerar chave SSH
ssh-keygen -t rsa -b 4096 -f id_rsa -N ""

# Criar Secret
kubectl create secret generic ssh-key \
  --from-file=ssh-privatekey=id_rsa \
  --from-file=ssh-publickey=id_rsa.pub \
  --type=kubernetes.io/ssh-auth

# Limpar
rm id_rsa id_rsa.pub
```

**Saída esperada:**
```
secret/ssh-key created
```

### Usar em Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: git-sync
spec:
  containers:
  - name: git-sync
    image: alpine/git:latest
    command: ["/bin/sh"]
    args:
    - -c
    - |
      mkdir -p ~/.ssh
      cp /etc/ssh-key/ssh-privatekey ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
      ssh-keyscan github.com >> ~/.ssh/known_hosts
      git clone git@github.com:user/repo.git /repo
      sleep 3600
    volumeMounts:
    - name: ssh-key
      mountPath: /etc/ssh-key
      readOnly: true
  volumes:
  - name: ssh-key
    secret:
      secretName: ssh-key
      defaultMode: 0400
```

## Comandos Úteis

### Criar Secrets

```bash
# Literal
kubectl create secret generic my-secret --from-literal=key=value

# Arquivo
kubectl create secret generic my-secret --from-file=key=file.txt

# Múltiplos valores
kubectl create secret generic my-secret \
  --from-literal=user=admin \
  --from-literal=pass=secret \
  --from-file=config=config.json

# TLS
kubectl create secret tls tls-secret --cert=cert.pem --key=key.pem

# Docker registry
kubectl create secret docker-registry reg-secret \
  --docker-server=registry.io \
  --docker-username=user \
  --docker-password=pass
```

### Listar e Visualizar

```bash
# Listar Secrets
kubectl get secrets

# Detalhes
kubectl describe secret my-secret

# YAML completo
kubectl get secret my-secret -o yaml

# JSON
kubectl get secret my-secret -o json

# Decodificar chave específica
kubectl get secret my-secret -o jsonpath='{.data.key}' | base64 -d
```

### Editar e Atualizar

```bash
# Editar Secret
kubectl edit secret my-secret

# Atualizar via patch
kubectl patch secret my-secret -p '{"stringData":{"key":"newvalue"}}'

# Substituir
kubectl create secret generic my-secret --from-literal=key=newvalue --dry-run=client -o yaml | kubectl apply -f -
```

### Deletar

```bash
# Deletar Secret específico
kubectl delete secret my-secret

# Deletar múltiplos
kubectl delete secret secret1 secret2

# Deletar por label
kubectl delete secret -l app=myapp
```

## Segurança e Boas Práticas

### 1. Não Commitar Secrets no Git

```bash
# .gitignore
*.secret.yaml
secrets/
credentials/
```

### 2. Usar RBAC

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
  resourceNames: ["db-credentials"]
```

### 3. Encryption at Rest

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}
```

### 4. Usar External Secrets

```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: db-credentials
  data:
  - secretKey: username
    remoteRef:
      key: prod/db/username
  - secretKey: password
    remoteRef:
      key: prod/db/password
```

### 5. Rotação de Secrets

```bash
# Atualizar Secret
kubectl create secret generic db-credentials \
  --from-literal=password=new-password \
  --dry-run=client -o yaml | kubectl apply -f -

# Reiniciar Pods para pegar novo Secret
kubectl rollout restart deployment myapp
```

## Limitações e Considerações

### Limitações

- **Tamanho:** Máximo 1MB por Secret
- **Base64:** Não é criptografia, apenas codificação
- **Namespace:** Secrets são isolados por namespace
- **Imutabilidade:** Secrets não são imutáveis por padrão

### Considerações de Segurança

- Secrets em variáveis de ambiente podem aparecer em logs
- Secrets como volumes são mais seguros (tmpfs)
- Use ferramentas externas para secrets críticos (Vault, AWS Secrets Manager)
- Habilite encryption at rest no etcd
- Implemente RBAC rigoroso
- Audite acesso a Secrets

## Troubleshooting

### Secret não Encontrado

```bash
# Verificar namespace
kubectl get secrets -n <namespace>

# Verificar nome exato
kubectl get secrets --all-namespaces | grep <name>
```

### Pod não Consegue Acessar Secret

```bash
# Verificar se Secret existe
kubectl get secret <secret-name>

# Verificar referência no Pod
kubectl get pod <pod-name> -o yaml | grep -A 10 secret

# Verificar eventos
kubectl describe pod <pod-name>
```

### Valor Incorreto

```bash
# Decodificar e verificar
kubectl get secret <secret-name> -o jsonpath='{.data.<key>}' | base64 -d

# Verificar se há espaços ou quebras de linha
kubectl get secret <secret-name> -o jsonpath='{.data.<key>}' | base64 -d | od -c
```

## Limpeza

```bash
# Remover Secrets criados
kubectl delete secret db-credentials db-credentials-file app-secrets myapp-tls regcred ssh-key

# Remover Pods
kubectl delete pod app-with-secrets app-with-secret-volume app-selective-keys
```

## Resumo

- **Secrets armazenam dados sensíveis** (senhas, tokens, chaves)
- **Base64 não é criptografia**, apenas codificação
- **Tipos principais:** Opaque, TLS, Docker Registry, SSH
- **Consumo:** Variáveis de ambiente ou volumes montados
- **Volumes são mais seguros** que variáveis de ambiente
- **Encryption at rest** deve ser habilitado em produção
- **RBAC** controla acesso a Secrets
- **Ferramentas externas** (Vault, AWS Secrets Manager) para produção crítica

## Próximos Passos

- Estudar **ConfigMaps** para configurações não sensíveis
- Implementar **External Secrets Operator**
- Configurar **Encryption at Rest**
- Integrar com **HashiCorp Vault**
- Implementar **rotação automática de Secrets**
