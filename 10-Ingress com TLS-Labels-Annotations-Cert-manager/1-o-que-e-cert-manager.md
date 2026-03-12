# O que é o Cert-Manager?

## Introdução

Cert-Manager é um controlador nativo do Kubernetes que automatiza o gerenciamento e emissão de certificados TLS/SSL. Ele integra-se com autoridades certificadoras (CAs) como Let's Encrypt, HashiCorp Vault, Venafi e outras, eliminando a necessidade de gerenciar certificados manualmente.

## O que é Cert-Manager?

### Conceito

```
┌─────────────────────────────────────────┐
│         Cert-Manager                    │
│  ┌────────────────────────────────┐    │
│  │  Certificate Controller        │    │
│  │  - Monitora Certificates       │    │
│  │  - Solicita certificados       │    │
│  │  - Renova automaticamente      │    │
│  └────────────────────────────────┘    │
│                ↓                        │
│  ┌────────────────────────────────┐    │
│  │  Issuer / ClusterIssuer        │    │
│  │  - Let's Encrypt               │    │
│  │  - Self-Signed                 │    │
│  │  - CA                          │    │
│  │  - Vault                       │    │
│  └────────────────────────────────┘    │
│                ↓                        │
│  ┌────────────────────────────────┐    │
│  │  Secret (TLS)                  │    │
│  │  - tls.crt                     │    │
│  │  - tls.key                     │    │
│  └────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### Funcionalidades Principais

- **Emissão Automática**: Solicita certificados automaticamente
- **Renovação Automática**: Renova antes do vencimento (30 dias)
- **Múltiplas CAs**: Suporta várias autoridades certificadoras
- **Validação**: HTTP-01, DNS-01, TLS-ALPN-01
- **Integração**: Funciona nativamente com Ingress
- **Monitoramento**: Métricas Prometheus integradas

---

## Arquitetura do Cert-Manager

### Componentes

```
┌──────────────────────────────────────────────────┐
│                 Cert-Manager                     │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌─────────────────┐  ┌─────────────────┐      │
│  │   Controller    │  │    Webhook      │      │
│  │   (Core)        │  │   (Validation)  │      │
│  └─────────────────┘  └─────────────────┘      │
│           ↓                    ↓                 │
│  ┌─────────────────────────────────────┐        │
│  │         CRDs (Custom Resources)     │        │
│  │  - Certificate                      │        │
│  │  - CertificateRequest               │        │
│  │  - Issuer / ClusterIssuer           │        │
│  │  - Challenge                        │        │
│  │  - Order                            │        │
│  └─────────────────────────────────────┘        │
└──────────────────────────────────────────────────┘
```

### Fluxo de Emissão de Certificado

```
1. Usuário cria Certificate
        ↓
2. Cert-Manager detecta novo Certificate
        ↓
3. Cria CertificateRequest
        ↓
4. Issuer processa requisição
        ↓
5. Cria Order (ACME)
        ↓
6. Cria Challenge (validação)
        ↓
7. Valida domínio (HTTP-01 ou DNS-01)
        ↓
8. CA emite certificado
        ↓
9. Cert-Manager armazena em Secret
        ↓
10. Ingress usa Secret automaticamente
```

---

## Instalação do Cert-Manager

### Método 1: kubectl apply (Simples)

```bash
# Instalar CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml

# Instalar cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verificar instalação
kubectl get pods -n cert-manager

# Output esperado:
# NAME                                       READY   STATUS    RESTARTS   AGE
# cert-manager-7d9f8c8d4-xxxxx              1/1     Running   0          1m
# cert-manager-cainjector-5c5695c4b-xxxxx   1/1     Running   0          1m
# cert-manager-webhook-7b8c8c8d4-xxxxx      1/1     Running   0          1m
```

### Método 2: Helm (Recomendado)

```bash
# Adicionar repositório
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Instalar cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true

# Verificar
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager
```

### Método 3: Helm com Valores Customizados

Crie o arquivo `cert-manager-values.yaml`:

```yaml
# Recursos
resources:
  requests:
    cpu: 10m
    memory: 32Mi
  limits:
    cpu: 100m
    memory: 128Mi

# Métricas Prometheus
prometheus:
  enabled: true
  servicemonitor:
    enabled: false

# Webhook
webhook:
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi

# CA Injector
cainjector:
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi

# Global
global:
  leaderElection:
    namespace: cert-manager
```

```bash
# Instalar com valores customizados
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true \
  --values cert-manager-values.yaml
```

### Verificar Instalação

```bash
# Ver pods
kubectl get pods -n cert-manager

# Ver CRDs
kubectl get crd | grep cert-manager

# Output esperado:
# certificaterequests.cert-manager.io
# certificates.cert-manager.io
# challenges.acme.cert-manager.io
# clusterissuers.cert-manager.io
# issuers.cert-manager.io
# orders.acme.cert-manager.io

# Ver versão
kubectl get deployment cert-manager -n cert-manager -o jsonpath='{.spec.template.spec.containers[0].image}'

# Testar webhook
kubectl run test-cert-manager --image=busybox --rm -it --restart=Never -- echo "OK"
```

---

## Custom Resources (CRDs)

### 1. Issuer

**Escopo**: Namespace específico

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: my-issuer
  namespace: default
spec:
  selfSigned: {}
```

### 2. ClusterIssuer

**Escopo**: Todo o cluster

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: my-cluster-issuer
spec:
  selfSigned: {}
```

### 3. Certificate

**Recurso principal** - Define certificado desejado

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-certificate
  namespace: default
spec:
  secretName: my-tls-secret
  issuerRef:
    name: my-issuer
    kind: Issuer
  dnsNames:
  - example.com
  - www.example.com
```

### 4. CertificateRequest

**Criado automaticamente** pelo Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: CertificateRequest
metadata:
  name: my-certificate-xxxxx
  namespace: default
spec:
  request: LS0tLS1CRUdJTi...
  issuerRef:
    name: my-issuer
    kind: Issuer
```

### 5. Order (ACME)

**Criado automaticamente** para Let's Encrypt

```yaml
apiVersion: acme.cert-manager.io/v1
kind: Order
metadata:
  name: my-certificate-xxxxx-xxxxx
  namespace: default
spec:
  request: LS0tLS1CRUdJTi...
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

### 6. Challenge (ACME)

**Criado automaticamente** para validação

```yaml
apiVersion: acme.cert-manager.io/v1
kind: Challenge
metadata:
  name: my-certificate-xxxxx-xxxxx-xxxxx
  namespace: default
spec:
  type: http-01
  url: https://acme-v02.api.letsencrypt.org/acme/chall-v3/...
  token: xxxxx
```

---

## Tipos de Issuers

### 1. Self-Signed (Auto-assinado)

**Uso**: Desenvolvimento e testes

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

### 2. CA (Certificate Authority)

**Uso**: CA interna da empresa

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
```

### 3. ACME (Let's Encrypt)

**Uso**: Produção (gratuito)

```yaml
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
```

### 4. Vault

**Uso**: Integração com HashiCorp Vault

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-issuer
spec:
  vault:
    server: https://vault.example.com
    path: pki/sign/example-dot-com
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
        secretRef:
          name: vault-token
          key: token
```

### 5. Venafi

**Uso**: Integração com Venafi TPP/Cloud

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: venafi-issuer
spec:
  venafi:
    zone: "DevOps\\Kubernetes"
    tpp:
      url: https://tpp.example.com/vedsdk
      credentialsRef:
        name: venafi-credentials
```

---

## Exemplo Completo: Self-Signed

### 1. Criar ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

```bash
# Aplicar
kubectl apply -f selfsigned-issuer.yaml

# Verificar
kubectl get clusterissuer selfsigned-issuer
kubectl describe clusterissuer selfsigned-issuer
```

### 2. Criar Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-cert
  namespace: default
spec:
  secretName: myapp-tls-secret
  duration: 2160h # 90 dias
  renewBefore: 360h # 15 dias antes
  subject:
    organizations:
    - MyCompany
  commonName: myapp.example.com
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
  - server auth
  - client auth
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
    group: cert-manager.io
```

```bash
# Aplicar
kubectl apply -f certificate.yaml

# Verificar
kubectl get certificate myapp-cert
kubectl describe certificate myapp-cert

# Ver secret criado
kubectl get secret myapp-tls-secret
kubectl describe secret myapp-tls-secret
```

### 3. Usar no Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls-secret
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

---

## Exemplo Completo: Let's Encrypt

### 1. Criar ClusterIssuer Staging

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # Servidor staging (para testes)
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    
    # Email para notificações
    email: admin@example.com
    
    # Secret para armazenar chave privada da conta ACME
    privateKeySecretRef:
      name: letsencrypt-staging
    
    # Solvers (métodos de validação)
    solvers:
    - http01:
        ingress:
          class: nginx
```

### 2. Criar ClusterIssuer Production

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Servidor production
    server: https://acme-v02.api.letsencrypt.org/directory
    
    email: admin@example.com
    
    privateKeySecretRef:
      name: letsencrypt-prod
    
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
# Aplicar ambos
kubectl apply -f letsencrypt-staging.yaml
kubectl apply -f letsencrypt-prod.yaml

# Verificar
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### 3. Criar Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-letsencrypt-cert
  namespace: default
spec:
  secretName: myapp-letsencrypt-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
```

### 4. Ou Usar Annotation no Ingress (Mais Simples)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-letsencrypt-tls
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
# Aplicar
kubectl apply -f ingress.yaml

# Cert-Manager cria Certificate automaticamente
kubectl get certificate

# Ver processo de validação
kubectl get challenge
kubectl describe challenge

# Ver order
kubectl get order
kubectl describe order

# Aguardar certificado (1-2 minutos)
kubectl get certificate -w

# Verificar secret
kubectl get secret myapp-letsencrypt-tls
```

---

## Métodos de Validação ACME

### 1. HTTP-01 (Mais Comum)

**Como funciona**:
1. Let's Encrypt solicita arquivo em `http://domain/.well-known/acme-challenge/token`
2. Cert-Manager cria Ingress temporário
3. Let's Encrypt acessa URL e valida
4. Certificado é emitido

**Vantagens**:
- Simples de configurar
- Funciona com qualquer Ingress Controller

**Desvantagens**:
- Requer porta 80 aberta
- Não funciona para wildcard (*.example.com)

**Configuração**:
```yaml
solvers:
- http01:
    ingress:
      class: nginx
```

### 2. DNS-01 (Para Wildcard)

**Como funciona**:
1. Let's Encrypt solicita registro TXT em `_acme-challenge.domain`
2. Cert-Manager cria registro DNS via API
3. Let's Encrypt verifica registro DNS
4. Certificado é emitido

**Vantagens**:
- Suporta wildcard (*.example.com)
- Não requer porta 80

**Desvantagens**:
- Requer integração com provedor DNS
- Mais complexo de configurar

**Configuração (Route 53)**:
```yaml
solvers:
- dns01:
    route53:
      region: us-east-1
      hostedZoneID: Z1234567890ABC
      accessKeyID: AKIAIOSFODNN7EXAMPLE
      secretAccessKeySecretRef:
        name: route53-credentials
        key: secret-access-key
```

**Configuração (CloudFlare)**:
```yaml
solvers:
- dns01:
    cloudflare:
      email: admin@example.com
      apiTokenSecretRef:
        name: cloudflare-api-token
        key: api-token
```

### 3. TLS-ALPN-01 (Menos Comum)

**Como funciona**:
- Validação via TLS handshake na porta 443

**Configuração**:
```yaml
solvers:
- http01:
    ingress:
      class: nginx
      podTemplate:
        spec:
          nodeSelector:
            kubernetes.io/os: linux
```

---

## Monitoramento e Troubleshooting

### Ver Status dos Recursos

```bash
# Certificates
kubectl get certificate -A
kubectl describe certificate myapp-cert -n default

# CertificateRequests
kubectl get certificaterequest -A
kubectl describe certificaterequest myapp-cert-xxxxx -n default

# Orders (ACME)
kubectl get order -A
kubectl describe order myapp-cert-xxxxx-xxxxx -n default

# Challenges (ACME)
kubectl get challenge -A
kubectl describe challenge myapp-cert-xxxxx-xxxxx-xxxxx -n default

# Issuers
kubectl get issuer -A
kubectl get clusterissuer
```

### Logs do Cert-Manager

```bash
# Logs do controller
kubectl logs -n cert-manager -l app=cert-manager -f

# Logs do webhook
kubectl logs -n cert-manager -l app=webhook -f

# Logs do cainjector
kubectl logs -n cert-manager -l app=cainjector -f

# Filtrar por namespace
kubectl logs -n cert-manager -l app=cert-manager | grep "default/myapp-cert"
```

### Eventos

```bash
# Ver eventos do namespace
kubectl get events -n default --sort-by=.metadata.creationTimestamp

# Filtrar eventos do cert-manager
kubectl get events -n default | grep cert-manager

# Ver eventos de um Certificate específico
kubectl describe certificate myapp-cert -n default | grep -A 10 Events
```

---

## Troubleshooting Comum

### Problema 1: Certificate Fica em Pending

```bash
# Ver status
kubectl describe certificate myapp-cert

# Ver CertificateRequest
kubectl get certificaterequest
kubectl describe certificaterequest myapp-cert-xxxxx

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Solução comum: Verificar Issuer
kubectl get clusterissuer letsencrypt-prod
kubectl describe clusterissuer letsencrypt-prod
```

### Problema 2: Challenge Falha (HTTP-01)

```bash
# Ver challenge
kubectl get challenge
kubectl describe challenge myapp-cert-xxxxx-xxxxx-xxxxx

# Testar URL manualmente
curl http://myapp.example.com/.well-known/acme-challenge/test

# Verificar Ingress temporário
kubectl get ingress -A | grep cm-acme

# Solução: Verificar se porta 80 está acessível
```

### Problema 3: DNS-01 Falha

```bash
# Ver challenge
kubectl describe challenge myapp-cert-xxxxx-xxxxx-xxxxx

# Verificar registro DNS
dig _acme-challenge.myapp.example.com TXT +short

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager | grep dns01

# Solução: Verificar credenciais do provedor DNS
kubectl get secret route53-credentials -o yaml
```

### Problema 4: Certificado Não Renova

```bash
# Ver quando expira
kubectl get certificate myapp-cert -o jsonpath='{.status.notAfter}'

# Forçar renovação
kubectl delete certificaterequest myapp-cert-xxxxx

# Ou deletar e recriar Certificate
kubectl delete certificate myapp-cert
kubectl apply -f certificate.yaml

# Verificar configuração de renovação
kubectl get certificate myapp-cert -o yaml | grep renewBefore
```

---

## Resumo dos Comandos

```bash
# Instalar cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Criar ClusterIssuer
kubectl apply -f clusterissuer.yaml

# Criar Certificate
kubectl apply -f certificate.yaml

# Verificar
kubectl get certificate
kubectl get clusterissuer
kubectl get secret

# Logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Troubleshooting
kubectl describe certificate <name>
kubectl get challenge
kubectl get order
```

---

## Conclusão

Cert-Manager oferece:

✅ **Automação** - Emissão e renovação automática  
✅ **Integração** - Funciona nativamente com Ingress  
✅ **Múltiplas CAs** - Let's Encrypt, Vault, Venafi, etc.  
✅ **Validação** - HTTP-01, DNS-01, TLS-ALPN-01  
✅ **Monitoramento** - Métricas e eventos  
✅ **Produção-ready** - Usado por milhares de empresas  

Com cert-manager, você nunca mais precisa gerenciar certificados manualmente!
