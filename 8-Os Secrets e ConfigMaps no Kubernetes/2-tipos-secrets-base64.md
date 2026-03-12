# Conhecendo Todos os Tipos de Secrets e a Codificação Base64

## Introdução

O Kubernetes oferece diferentes tipos de Secrets para casos de uso específicos. Cada tipo tem uma estrutura e propósito definidos. Além disso, entender a codificação base64 é fundamental para trabalhar com Secrets de forma segura.

## O que é Base64?

### Conceito

**Base64** é um esquema de codificação que converte dados binários em texto ASCII usando 64 caracteres diferentes (A-Z, a-z, 0-9, +, /). É usado para transportar dados binários em formatos que suportam apenas texto.

### Importante: Base64 NÃO é Criptografia!

```
❌ Base64 NÃO é seguro
❌ Base64 NÃO protege dados
❌ Base64 é facilmente reversível
✅ Base64 é apenas CODIFICAÇÃO
✅ Qualquer um pode decodificar
```

### Como Funciona

```
Texto Original → Base64 → Texto Codificado
     ↓              ↓            ↓
  "admin"    →  Codifica  →  "YWRtaW4="
```

### Exemplos Práticos de Base64

#### Codificar (Encode)

```bash
# Codificar string
echo -n "admin" | base64
# Saída: YWRtaW4=

echo -n "password123" | base64
# Saída: cGFzc3dvcmQxMjM=

echo -n "my-secret-api-key" | base64
# Saída: bXktc2VjcmV0LWFwaS1rZXk=

# Codificar arquivo
cat config.json | base64
```

#### Decodificar (Decode)

```bash
# Decodificar string
echo "YWRtaW4=" | base64 -d
# Saída: admin

echo "cGFzc3dvcmQxMjM=" | base64 -d
# Saída: password123

# Decodificar arquivo
cat encoded.txt | base64 -d > decoded.txt
```

#### Por Que Kubernetes Usa Base64?

1. **Compatibilidade:** Permite armazenar dados binários em YAML/JSON
2. **Uniformidade:** Formato consistente para todos os tipos de dados
3. **API:** Facilita transmissão via HTTP/JSON
4. **Não é para segurança:** É apenas para formato de dados

### Demonstração: Base64 é Inseguro

```bash
# Criar Secret
kubectl create secret generic demo-secret --from-literal=password=SuperSecret123

# Ver Secret (base64)
kubectl get secret demo-secret -o jsonpath='{.data.password}'
# Saída: U3VwZXJTZWNyZXQxMjM=

# Qualquer um pode decodificar!
echo "U3VwZXJTZWNyZXQxMjM=" | base64 -d
# Saída: SuperSecret123
```

**Conclusão:** Nunca confie apenas em base64 para proteger dados sensíveis!

## Tipos de Secrets no Kubernetes

### Visão Geral

| Tipo | Chaves Obrigatórias | Uso Principal |
|------|---------------------|---------------|
| **Opaque** | Nenhuma | Dados genéricos |
| **kubernetes.io/service-account-token** | token, ca.crt, namespace | ServiceAccount |
| **kubernetes.io/dockercfg** | .dockercfg | Registry (legado) |
| **kubernetes.io/dockerconfigjson** | .dockerconfigjson | Registry |
| **kubernetes.io/basic-auth** | username, password | HTTP Basic Auth |
| **kubernetes.io/ssh-auth** | ssh-privatekey | SSH |
| **kubernetes.io/tls** | tls.crt, tls.key | Certificados TLS |
| **bootstrap.kubernetes.io/token** | token-id, token-secret | Bootstrap |

## 1. Opaque (Tipo Padrão)

### Descrição

Tipo genérico para dados arbitrários. Não tem estrutura definida - você define as chaves e valores.

### Quando Usar

- Senhas de banco de dados
- Tokens de API
- Chaves de criptografia
- Qualquer dado sensível sem formato específico

### Exemplo 1: Via kubectl

```bash
# Criar Secret Opaque
kubectl create secret generic app-config \
  --from-literal=db-host=mysql.example.com \
  --from-literal=db-port=3306 \
  --from-literal=db-user=admin \
  --from-literal=db-password=s3cr3t
```

**Saída esperada:**
```
secret/app-config created
```

### Exemplo 2: Via YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-config-yaml
type: Opaque
stringData:
  db-host: mysql.example.com
  db-port: "3306"
  db-user: admin
  db-password: s3cr3t
  api-key: sk-1234567890abcdef
```

```bash
kubectl apply -f opaque-secret.yaml
```

### Exemplo 3: Com Dados Binários

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: binary-secret
type: Opaque
data:
  # Base64 de dados binários
  encryption-key: MTIzNDU2Nzg5MGFiY2RlZjEyMzQ1Njc4OTBhYmNkZWY=
  certificate: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
```

### Verificar

```bash
kubectl get secret app-config -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  api-key: c2stMTIzNDU2Nzg5MGFiY2RlZg==
  db-host: bXlzcWwuZXhhbXBsZS5jb20=
  db-password: czNjcjN0
  db-port: MzMwNg==
  db-user: YWRtaW4=
kind: Secret
metadata:
  name: app-config-yaml
type: Opaque
```

## 2. kubernetes.io/service-account-token

### Descrição

Token usado por Pods para autenticar com a API do Kubernetes. Criado automaticamente para cada ServiceAccount.

### Estrutura

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-sa-token
  annotations:
    kubernetes.io/service-account.name: my-service-account
type: kubernetes.io/service-account-token
data:
  token: <base64-encoded-jwt-token>
  ca.crt: <base64-encoded-ca-certificate>
  namespace: <base64-encoded-namespace>
```

### Exemplo Prático

```bash
# Criar ServiceAccount
kubectl create serviceaccount my-app-sa

# Ver Secret criado automaticamente
kubectl get secrets | grep my-app-sa

# Ver detalhes do token
kubectl describe secret <token-secret-name>
```

**Saída esperada:**
```
Name:         my-app-sa-token-xxxxx
Namespace:    default
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: my-app-sa
              kubernetes.io/service-account.uid: abc-123-def

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1066 bytes
namespace:  7 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6Ij...
```

### Usar em Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sa
spec:
  serviceAccountName: my-app-sa
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "Token: $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
      sleep 3600
```

## 3. kubernetes.io/dockerconfigjson

### Descrição

Credenciais para pull de imagens de registries privados. Formato JSON moderno.

### Estrutura

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

### Exemplo 1: Docker Hub

```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

**Saída esperada:**
```
secret/dockerhub-secret created
```

### Exemplo 2: Registry Privado

```bash
kubectl create secret docker-registry private-registry \
  --docker-server=registry.example.com \
  --docker-username=admin \
  --docker-password=secret123
```

### Exemplo 3: Via YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "registry.example.com": {
          "username": "admin",
          "password": "secret123",
          "auth": "YWRtaW46c2VjcmV0MTIz"
        }
      }
    }
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
    image: registry.example.com/myapp:latest
  imagePullSecrets:
  - name: registry-secret
```

### Verificar

```bash
kubectl get secret registry-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

## 4. kubernetes.io/dockercfg (Legado)

### Descrição

Formato antigo de credenciais Docker. Use `dockerconfigjson` em vez disso.

### Estrutura

```json
{
  "https://index.docker.io/v1/": {
    "username": "myuser",
    "password": "mypassword",
    "email": "myemail@example.com",
    "auth": "base64(username:password)"
  }
}
```

### Exemplo

```bash
# Criar a partir de arquivo ~/.dockercfg
kubectl create secret generic dockercfg-secret \
  --from-file=.dockercfg=$HOME/.dockercfg \
  --type=kubernetes.io/dockercfg
```

## 5. kubernetes.io/basic-auth

### Descrição

Credenciais para autenticação HTTP Basic.

### Estrutura

Chaves obrigatórias:
- `username`: Nome de usuário
- `password`: Senha (opcional)

### Exemplo 1: Via kubectl

```bash
kubectl create secret generic basic-auth-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  --type=kubernetes.io/basic-auth
```

**Saída esperada:**
```
secret/basic-auth-secret created
```

### Exemplo 2: Via YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth
type: kubernetes.io/basic-auth
stringData:
  username: admin
  password: secret123
```

```bash
kubectl apply -f basic-auth.yaml
```

### Verificar

```bash
kubectl get secret basic-auth -o yaml
```

**Saída esperada:**
```yaml
apiVersion: v1
data:
  password: c2VjcmV0MTIz
  username: YWRtaW4=
kind: Secret
metadata:
  name: basic-auth
type: kubernetes.io/basic-auth
```

### Usar em Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-auth-ingress
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

## 6. kubernetes.io/ssh-auth

### Descrição

Chave privada SSH para autenticação.

### Estrutura

Chave obrigatória:
- `ssh-privatekey`: Chave privada SSH

### Exemplo 1: Gerar e Criar

```bash
# Gerar chave SSH
ssh-keygen -t rsa -b 4096 -f id_rsa -N "" -C "k8s-ssh-key"

# Criar Secret
kubectl create secret generic ssh-key-secret \
  --from-file=ssh-privatekey=id_rsa \
  --type=kubernetes.io/ssh-auth

# Limpar
rm id_rsa id_rsa.pub
```

**Saída esperada:**
```
secret/ssh-key-secret created
```

### Exemplo 2: Via YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ssh-key
type: kubernetes.io/ssh-auth
stringData:
  ssh-privatekey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn
    ...
    -----END OPENSSH PRIVATE KEY-----
```

### Exemplo 3: Com Chave Pública (Opcional)

```bash
kubectl create secret generic ssh-key-full \
  --from-file=ssh-privatekey=id_rsa \
  --from-file=ssh-publickey=id_rsa.pub \
  --type=kubernetes.io/ssh-auth
```

### Usar em Pod (Git Clone)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: git-clone-pod
spec:
  containers:
  - name: git
    image: alpine/git:latest
    command: ["/bin/sh", "-c"]
    args:
    - |
      mkdir -p ~/.ssh
      cp /etc/ssh-key/ssh-privatekey ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
      ssh-keyscan github.com >> ~/.ssh/known_hosts
      git clone git@github.com:user/private-repo.git /repo
      ls -la /repo
      sleep 3600
    volumeMounts:
    - name: ssh-key
      mountPath: /etc/ssh-key
      readOnly: true
  volumes:
  - name: ssh-key
    secret:
      secretName: ssh-key-secret
      defaultMode: 0400
```

### Verificar

```bash
kubectl logs git-clone-pod
```

## 7. kubernetes.io/tls

### Descrição

Certificado TLS e chave privada para HTTPS.

### Estrutura

Chaves obrigatórias:
- `tls.crt`: Certificado público
- `tls.key`: Chave privada

### Exemplo 1: Certificado Autoassinado

```bash
# Gerar chave privada
openssl genrsa -out tls.key 2048

# Gerar certificado autoassinado
openssl req -new -x509 -key tls.key -out tls.crt -days 365 \
  -subj "/CN=myapp.example.com/O=MyOrg/C=US"

# Criar Secret TLS
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key

# Limpar
rm tls.key tls.crt
```

**Saída esperada:**
```
secret/myapp-tls created
```

### Exemplo 2: Via YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
stringData:
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAKL0UG+mRKKzMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
    ...
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKj
    ...
    -----END PRIVATE KEY-----
```

### Exemplo 3: Let's Encrypt com Cert-Manager

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-cert
spec:
  secretName: myapp-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
```

### Usar em Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
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

### Verificar Certificado

```bash
# Ver Secret
kubectl get secret myapp-tls -o yaml

# Decodificar e ver certificado
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

**Saída esperada:**
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 123456789
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=myapp.example.com, O=MyOrg, C=US
        Validity
            Not Before: Mar  9 19:00:00 2026 GMT
            Not After : Mar  9 19:00:00 2027 GMT
        Subject: CN=myapp.example.com, O=MyOrg, C=US
```

## 8. bootstrap.kubernetes.io/token

### Descrição

Token usado para bootstrap de novos nodes no cluster.

### Estrutura

Chaves obrigatórias:
- `token-id`: ID do token (6 caracteres)
- `token-secret`: Secret do token (16 caracteres)

Chaves opcionais:
- `description`: Descrição
- `expiration`: Data de expiração
- `usage-bootstrap-authentication`: "true"
- `usage-bootstrap-signing`: "true"
- `auth-extra-groups`: Grupos adicionais

### Exemplo

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-abc123
  namespace: kube-system
type: bootstrap.kubernetes.io/token
stringData:
  token-id: abc123
  token-secret: 0123456789abcdef
  description: "Bootstrap token for new nodes"
  expiration: 2026-12-31T23:59:59Z
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
  auth-extra-groups: system:bootstrappers:kubeadm:default-node-token
```

```bash
kubectl apply -f bootstrap-token.yaml
```

### Usar no Kubeadm Join

```bash
# Token completo: abc123.0123456789abcdef
kubeadm join <control-plane-host>:6443 \
  --token abc123.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:...
```

## Comparação de Tipos

### Tabela Resumida

| Tipo | Uso | Chaves | Criação |
|------|-----|--------|---------|
| **Opaque** | Genérico | Qualquer | Manual |
| **service-account-token** | API Auth | token, ca.crt, namespace | Automático |
| **dockerconfigjson** | Registry | .dockerconfigjson | Manual |
| **dockercfg** | Registry (legado) | .dockercfg | Manual |
| **basic-auth** | HTTP Auth | username, password | Manual |
| **ssh-auth** | SSH | ssh-privatekey | Manual |
| **tls** | HTTPS | tls.crt, tls.key | Manual |
| **bootstrap** | Node Join | token-id, token-secret | Manual |

## Comandos Úteis para Todos os Tipos

### Listar por Tipo

```bash
# Todos os Secrets
kubectl get secrets

# Por tipo específico
kubectl get secrets --field-selector type=Opaque
kubectl get secrets --field-selector type=kubernetes.io/tls
kubectl get secrets --field-selector type=kubernetes.io/dockerconfigjson
```

### Ver Tipo do Secret

```bash
kubectl get secret <secret-name> -o jsonpath='{.type}'
```

### Converter Entre Formatos

```bash
# Exportar Secret
kubectl get secret my-secret -o yaml > secret.yaml

# Editar tipo
# Alterar: type: Opaque para type: kubernetes.io/basic-auth

# Aplicar
kubectl apply -f secret.yaml
```

## Boas Práticas por Tipo

### Opaque
- Use para dados genéricos
- Organize com labels
- Documente as chaves usadas

### Service Account Token
- Deixe o Kubernetes gerenciar
- Use RBAC para limitar permissões
- Não exponha tokens

### Docker Registry
- Um Secret por registry
- Use imagePullSecrets em ServiceAccount
- Rotacione credenciais regularmente

### Basic Auth
- Use apenas com HTTPS
- Prefira OAuth/OIDC quando possível
- Implemente rate limiting

### SSH Auth
- Proteja chaves privadas
- Use chaves específicas por aplicação
- Rotacione chaves periodicamente

### TLS
- Use cert-manager para automação
- Renove certificados antes de expirar
- Use Let's Encrypt em produção

### Bootstrap Token
- Defina expiração curta
- Delete após uso
- Limite escopo com RBAC

## Limpeza

```bash
# Remover Secrets de exemplo
kubectl delete secret app-config app-config-yaml
kubectl delete secret dockerhub-secret private-registry registry-secret
kubectl delete secret basic-auth-secret basic-auth
kubectl delete secret ssh-key-secret ssh-key-full
kubectl delete secret myapp-tls tls-secret

# Remover Pods
kubectl delete pod app-with-sa private-image-pod git-clone-pod
```

## Resumo

- **Base64 é codificação, NÃO criptografia** - qualquer um pode decodificar
- **8 tipos principais de Secrets** para casos de uso específicos
- **Opaque** é o tipo padrão para dados genéricos
- **TLS** para certificados HTTPS
- **dockerconfigjson** para registries privados
- **ssh-auth** para chaves SSH
- **basic-auth** para HTTP Basic Authentication
- **service-account-token** gerenciado automaticamente
- Cada tipo tem **estrutura e chaves específicas**
- Use o **tipo correto** para melhor validação e documentação

## Próximos Passos

- Estudar **Encryption at Rest** para proteger Secrets no etcd
- Implementar **External Secrets Operator**
- Integrar com **HashiCorp Vault**
- Configurar **RBAC** para controle de acesso
- Automatizar **rotação de Secrets**
