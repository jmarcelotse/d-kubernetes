# Criando um Secret do Tipo TLS para Certificados

## Introdução

O tipo **kubernetes.io/tls** é usado para armazenar certificados TLS (SSL) e suas chaves privadas. É essencial para configurar HTTPS em Ingress, Services e aplicações que requerem comunicação segura.

## O que é um Secret TLS?

### Conceito

Um Secret TLS contém um par de certificado público e chave privada usados para criptografia TLS/SSL. É o formato padrão para configurar HTTPS no Kubernetes.

### Estrutura

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: <certificado-base64>
  tls.key: <chave-privada-base64>
```

### Chaves Obrigatórias

- **tls.crt**: Certificado público (pode incluir cadeia de certificados)
- **tls.key**: Chave privada correspondente

### Quando Usar

- Configurar HTTPS em Ingress
- Habilitar TLS em Services
- mTLS (mutual TLS) entre serviços
- Certificados para aplicações
- Webhooks que requerem TLS

## Fluxo de Funcionamento

```
1. Gerar/Obter certificado e chave
   ↓
2. Criar Secret TLS no Kubernetes
   ↓
3. Ingress/Service referencia Secret
   ↓
4. Ingress Controller carrega certificado
   ↓
5. Cliente conecta via HTTPS
   ↓
6. TLS handshake com certificado
   ↓
7. Comunicação criptografada estabelecida
```

## Método 1: kubectl create (Recomendado)

### Sintaxe

```bash
kubectl create secret tls <nome> \
  --cert=<arquivo-certificado> \
  --key=<arquivo-chave>
```

### Exemplo 1: Certificado Autoassinado

#### Gerar Certificado

```bash
# Gerar chave privada
openssl genrsa -out tls.key 2048

# Gerar certificado autoassinado (válido por 365 dias)
openssl req -new -x509 -key tls.key -out tls.crt -days 365 \
  -subj "/CN=myapp.example.com/O=MyOrg/C=US"
```

**Saída esperada:**
```
Generating RSA private key, 2048 bit long modulus
.....+++
.....+++
e is 65537 (0x10001)
```

#### Criar Secret

```bash
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key
```

**Saída esperada:**
```
secret/myapp-tls created
```

#### Limpar Arquivos

```bash
rm tls.key tls.crt
```

### Verificar Secret

```bash
kubectl get secret myapp-tls
```

**Saída esperada:**
```
NAME        TYPE                DATA   AGE
myapp-tls   kubernetes.io/tls   2      10s
```

### Ver Detalhes

```bash
kubectl describe secret myapp-tls
```

**Saída esperada:**
```
Name:         myapp-tls
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  kubernetes.io/tls

Data
====
tls.crt:  1123 bytes
tls.key:  1675 bytes
```

### Ver Certificado Decodificado

```bash
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

**Saída esperada:**
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            12:34:56:78:90:ab:cd:ef
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, O=MyOrg, CN=myapp.example.com
        Validity
            Not Before: Mar  9 19:56:00 2026 GMT
            Not After : Mar  9 19:56:00 2027 GMT
        Subject: C=US, O=MyOrg, CN=myapp.example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
```

### Exemplo 2: Certificado com SAN (Subject Alternative Names)

```bash
# Criar arquivo de configuração
cat > san.cnf << 'EOF'
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = US
ST = California
L = San Francisco
O = MyOrg
CN = myapp.example.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = myapp.example.com
DNS.2 = www.myapp.example.com
DNS.3 = api.myapp.example.com
DNS.4 = *.myapp.example.com
IP.1 = 192.168.1.100
EOF

# Gerar chave
openssl genrsa -out tls.key 2048

# Gerar CSR
openssl req -new -key tls.key -out tls.csr -config san.cnf

# Gerar certificado autoassinado
openssl x509 -req -in tls.csr -signkey tls.key -out tls.crt -days 365 \
  -extensions v3_req -extfile san.cnf

# Criar Secret
kubectl create secret tls myapp-tls-san \
  --cert=tls.crt \
  --key=tls.key

# Limpar
rm tls.key tls.crt tls.csr san.cnf
```

**Saída esperada:**
```
secret/myapp-tls-san created
```

### Verificar SAN

```bash
kubectl get secret myapp-tls-san -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A 5 "Subject Alternative Name"
```

**Saída esperada:**
```
X509v3 Subject Alternative Name:
    DNS:myapp.example.com, DNS:www.myapp.example.com, DNS:api.myapp.example.com, DNS:*.myapp.example.com, IP Address:192.168.1.100
```

### Exemplo 3: Certificado com Cadeia Completa

```bash
# Gerar CA (Certificate Authority)
openssl genrsa -out ca.key 2048
openssl req -new -x509 -key ca.key -out ca.crt -days 3650 \
  -subj "/CN=My CA/O=MyOrg/C=US"

# Gerar chave do servidor
openssl genrsa -out server.key 2048

# Gerar CSR do servidor
openssl req -new -key server.key -out server.csr \
  -subj "/CN=myapp.example.com/O=MyOrg/C=US"

# Assinar certificado com CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -days 365

# Criar cadeia completa (server + CA)
cat server.crt ca.crt > fullchain.crt

# Criar Secret
kubectl create secret tls myapp-tls-chain \
  --cert=fullchain.crt \
  --key=server.key

# Limpar
rm ca.key ca.crt ca.srl server.key server.csr server.crt fullchain.crt
```

**Saída esperada:**
```
secret/myapp-tls-chain created
```

## Método 2: YAML Manual

### Estrutura

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-certificate>
  tls.key: <base64-encoded-key>
```

### Exemplo 1: Codificar e Criar

```bash
# Gerar certificado
openssl genrsa -out tls.key 2048
openssl req -new -x509 -key tls.key -out tls.crt -days 365 \
  -subj "/CN=myapp.example.com"

# Codificar em base64
TLS_CRT=$(cat tls.crt | base64 -w 0)
TLS_KEY=$(cat tls.key | base64 -w 0)

# Criar YAML
cat > tls-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: myapp-tls-yaml
  labels:
    app: myapp
type: kubernetes.io/tls
data:
  tls.crt: $TLS_CRT
  tls.key: $TLS_KEY
EOF

# Aplicar
kubectl apply -f tls-secret.yaml

# Limpar
rm tls.key tls.crt tls-secret.yaml
```

**Saída esperada:**
```
secret/myapp-tls-yaml created
```

### Exemplo 2: stringData (Mais Fácil)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-tls-string
type: kubernetes.io/tls
stringData:
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAKL0UG+mRKKzMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
    BAYTAlVTMQ4wDAYDVQQKDAVNeU9yZzEMMAoGA1UEAwwDTXlDQTAeFw0yNjAzMDkx
    ...
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKj
    MzEfYyjiWA4R4/M+fSAznE3PV7l8Kj3dwz8mdYmo9HvijkSVzGvi0qeEiUoH0xnG
    ...
    -----END PRIVATE KEY-----
```

```bash
kubectl apply -f tls-secret-string.yaml
```

**Saída esperada:**
```
secret/myapp-tls-string created
```

## Método 3: Cert-Manager (Automático)

### Instalar Cert-Manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

**Saída esperada:**
```
namespace/cert-manager created
customresourcedefinition.apiextensions.k8s.io/certificaterequests.cert-manager.io created
...
deployment.apps/cert-manager created
```

### Exemplo 1: Certificado Autoassinado

```yaml
# Criar Issuer
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
# Criar Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-cert
spec:
  secretName: myapp-tls-certmanager
  issuerRef:
    name: selfsigned-issuer
    kind: Issuer
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
```

```bash
kubectl apply -f certmanager-selfsigned.yaml
```

**Saída esperada:**
```
issuer.cert-manager.io/selfsigned-issuer created
certificate.cert-manager.io/myapp-cert created
```

### Verificar Certificado

```bash
kubectl get certificate myapp-cert
```

**Saída esperada:**
```
NAME         READY   SECRET                   AGE
myapp-cert   True    myapp-tls-certmanager    30s
```

### Verificar Secret Criado

```bash
kubectl get secret myapp-tls-certmanager
```

**Saída esperada:**
```
NAME                    TYPE                DATA   AGE
myapp-tls-certmanager   kubernetes.io/tls   3      35s
```

### Exemplo 2: Let's Encrypt (Produção)

```yaml
# ClusterIssuer para Let's Encrypt
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
# Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-letsencrypt
spec:
  secretName: myapp-tls-letsencrypt
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
```

```bash
kubectl apply -f letsencrypt-cert.yaml
```

**Saída esperada:**
```
clusterissuer.cert-manager.io/letsencrypt-prod created
certificate.cert-manager.io/myapp-letsencrypt created
```

## Usando Secret TLS em Ingress

### Exemplo 1: Ingress Básico com TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
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

```bash
kubectl apply -f ingress-tls.yaml
```

**Saída esperada:**
```
ingress.networking.k8s.io/myapp-ingress created
```

### Verificar Ingress

```bash
kubectl get ingress myapp-ingress
```

**Saída esperada:**
```
NAME            CLASS   HOSTS                ADDRESS         PORTS     AGE
myapp-ingress   nginx   myapp.example.com    192.168.1.100   80, 443   30s
```

### Testar HTTPS

```bash
# Adicionar entrada no /etc/hosts
echo "192.168.1.100 myapp.example.com" | sudo tee -a /etc/hosts

# Testar (ignorar verificação de certificado autoassinado)
curl -k https://myapp.example.com

# Ver certificado
openssl s_client -connect myapp.example.com:443 -servername myapp.example.com < /dev/null 2>/dev/null | openssl x509 -text -noout
```

### Exemplo 2: Múltiplos Hosts

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app1.example.com
    secretName: app1-tls
  - hosts:
    - app2.example.com
    - www.app2.example.com
    secretName: app2-tls
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

### Exemplo 3: Ingress com Cert-Manager Annotation

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress-auto
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls-auto  # Cert-manager cria automaticamente
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

**Nota:** Cert-manager cria o Secret automaticamente baseado na annotation.

## Usando Secret TLS em Aplicações

### Exemplo 1: Nginx com TLS

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-tls-config
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    
    http {
        server {
            listen 80;
            return 301 https://$host$request_uri;
        }
        
        server {
            listen 443 ssl;
            server_name myapp.example.com;
            
            ssl_certificate /etc/nginx/ssl/tls.crt;
            ssl_certificate_key /etc/nginx/ssl/tls.key;
            ssl_protocols TLSv1.2 TLSv1.3;
            ssl_ciphers HIGH:!aNULL:!MD5;
            
            location / {
                root /usr/share/nginx/html;
                index index.html;
            }
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-tls
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-tls
  template:
    metadata:
      labels:
        app: nginx-tls
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        - containerPort: 443
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: tls-certs
          mountPath: /etc/nginx/ssl
          readOnly: true
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-tls-config
      - name: tls-certs
        secret:
          secretName: myapp-tls
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-tls-service
spec:
  selector:
    app: nginx-tls
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
  type: LoadBalancer
```

```bash
kubectl apply -f nginx-tls-app.yaml
```

**Saída esperada:**
```
configmap/nginx-tls-config created
deployment.apps/nginx-tls created
service/nginx-tls-service created
```

### Testar

```bash
# Port-forward
kubectl port-forward service/nginx-tls-service 8443:443

# Testar HTTPS
curl -k https://localhost:8443
```

### Exemplo 2: Node.js com TLS

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nodejs-tls-app
data:
  server.js: |
    const https = require('https');
    const fs = require('fs');
    
    const options = {
      key: fs.readFileSync('/etc/tls/tls.key'),
      cert: fs.readFileSync('/etc/tls/tls.crt')
    };
    
    const server = https.createServer(options, (req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('Hello HTTPS World!\n');
    });
    
    server.listen(8443, () => {
      console.log('HTTPS Server running on port 8443');
    });
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-tls
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nodejs-tls
  template:
    metadata:
      labels:
        app: nodejs-tls
    spec:
      containers:
      - name: nodejs
        image: node:20-alpine
        command: ["node", "/app/server.js"]
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: app
          mountPath: /app
        - name: tls-certs
          mountPath: /etc/tls
          readOnly: true
      volumes:
      - name: app
        configMap:
          name: nodejs-tls-app
      - name: tls-certs
        secret:
          secretName: myapp-tls
```

```bash
kubectl apply -f nodejs-tls-app.yaml
```

## Renovação de Certificados

### Manual

```bash
# Gerar novo certificado
openssl genrsa -out new-tls.key 2048
openssl req -new -x509 -key new-tls.key -out new-tls.crt -days 365 \
  -subj "/CN=myapp.example.com"

# Deletar Secret antigo
kubectl delete secret myapp-tls

# Criar novo Secret
kubectl create secret tls myapp-tls \
  --cert=new-tls.crt \
  --key=new-tls.key

# Reiniciar Pods
kubectl rollout restart deployment nginx-tls

# Limpar
rm new-tls.key new-tls.crt
```

### Automático com Cert-Manager

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-cert
spec:
  secretName: myapp-tls
  duration: 2160h  # 90 dias
  renewBefore: 360h  # Renovar 15 dias antes
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
```

**Cert-manager renova automaticamente antes de expirar.**

## Verificação de Certificados

### Ver Validade

```bash
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

**Saída esperada:**
```
notBefore=Mar  9 19:56:00 2026 GMT
notAfter=Mar  9 19:56:00 2027 GMT
```

### Ver Subject e Issuer

```bash
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer
```

**Saída esperada:**
```
subject=C = US, O = MyOrg, CN = myapp.example.com
issuer=C = US, O = MyOrg, CN = myapp.example.com
```

### Ver SAN

```bash
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -ext subjectAltName
```

### Verificar Chave e Certificado Correspondem

```bash
# Extrair certificado e chave
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > cert.pem
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.key}' | base64 -d > key.pem

# Comparar modulus
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5

# Devem ser iguais
rm cert.pem key.pem
```

## Comandos Úteis

### Criar

```bash
# Básico
kubectl create secret tls <name> --cert=<cert-file> --key=<key-file>

# Com namespace
kubectl create secret tls <name> --cert=<cert> --key=<key> -n <namespace>

# Com labels
kubectl create secret tls <name> --cert=<cert> --key=<key> \
  --dry-run=client -o yaml | \
  kubectl label -f - --local app=myapp -o yaml | \
  kubectl apply -f -
```

### Listar

```bash
# Todos os Secrets TLS
kubectl get secrets --field-selector type=kubernetes.io/tls

# Com detalhes
kubectl get secrets -o wide
```

### Visualizar

```bash
# Descrever
kubectl describe secret <name>

# Ver certificado
kubectl get secret <name> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Ver apenas CN
kubectl get secret <name> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject
```

### Exportar

```bash
# Exportar certificado
kubectl get secret <name> -o jsonpath='{.data.tls\.crt}' | base64 -d > cert.pem

# Exportar chave
kubectl get secret <name> -o jsonpath='{.data.tls\.key}' | base64 -d > key.pem
```

### Copiar para Outro Namespace

```bash
kubectl get secret myapp-tls -n default -o yaml | \
  sed 's/namespace: default/namespace: production/' | \
  kubectl apply -f -
```

## Troubleshooting

### Certificado Expirado

```bash
# Verificar validade
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# Renovar certificado
```

### Chave e Certificado Não Correspondem

```bash
# Erro: tls: private key does not match public key

# Verificar correspondência
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > cert.pem
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.key}' | base64 -d > key.pem
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5
```

### Ingress Não Usa Certificado

```bash
# Verificar Secret existe
kubectl get secret myapp-tls

# Verificar nome no Ingress
kubectl get ingress myapp-ingress -o yaml | grep secretName

# Verificar logs do Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

## Boas Práticas

### 1. Use Cert-Manager

```yaml
# ✅ Automático, renovação automática
apiVersion: cert-manager.io/v1
kind: Certificate
```

### 2. Certificados com Validade Curta

```yaml
# ✅ 90 dias, renovar 15 dias antes
spec:
  duration: 2160h
  renewBefore: 360h
```

### 3. Labels e Annotations

```yaml
metadata:
  labels:
    app: myapp
    cert-type: tls
  annotations:
    cert-manager.io/issue-temporary-certificate: "true"
    expires: "2027-03-09"
```

### 4. Backup de Certificados

```bash
# Exportar para backup
kubectl get secret myapp-tls -o yaml > myapp-tls-backup.yaml
```

### 5. Monitorar Expiração

```bash
# Script para verificar expiração
kubectl get secrets --field-selector type=kubernetes.io/tls -o json | \
  jq -r '.items[] | .metadata.name + ": " + (.data."tls.crt" | @base64d)' | \
  while read name cert; do
    echo "$name"
    echo "$cert" | openssl x509 -noout -dates
  done
```

## Limpeza

```bash
# Remover Secrets
kubectl delete secret myapp-tls myapp-tls-san myapp-tls-chain
kubectl delete secret myapp-tls-yaml myapp-tls-string myapp-tls-certmanager
kubectl delete secret myapp-tls-letsencrypt myapp-tls-auto

# Remover Deployments
kubectl delete deployment nginx-tls nodejs-tls

# Remover Services
kubectl delete service nginx-tls-service

# Remover Ingress
kubectl delete ingress myapp-ingress multi-host-ingress myapp-ingress-auto

# Remover ConfigMaps
kubectl delete configmap nginx-tls-config nodejs-tls-app

# Remover Cert-Manager (opcional)
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

## Resumo

- **kubernetes.io/tls** armazena certificado e chave privada
- **kubectl create secret tls** é o método mais fácil
- **Cert-Manager** automatiza criação e renovação
- Use em **Ingress** para HTTPS
- Suporta **múltiplos hosts** e **SAN**
- **Let's Encrypt** para certificados gratuitos
- **Renovação automática** com Cert-Manager
- Sempre **verifique validade** e **correspondência** chave/certificado

## Próximos Passos

- Configurar **Let's Encrypt** em produção
- Implementar **mTLS** entre serviços
- Automatizar **monitoramento de expiração**
- Integrar com **External Secrets Operator**
- Configurar **cert-manager** com DNS challenge
