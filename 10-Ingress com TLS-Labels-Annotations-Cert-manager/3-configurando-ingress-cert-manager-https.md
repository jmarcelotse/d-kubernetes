# Configurando o Ingress para Usar o Cert-Manager e Ter HTTPS

## Introdução

Este guia mostra como integrar o Cert-Manager com o Ingress para obter certificados TLS/SSL automaticamente e habilitar HTTPS nas suas aplicações. Vamos cobrir desde a configuração básica até cenários avançados com múltiplos domínios.

## Fluxo de Funcionamento

```
1. Criar Ingress com annotation cert-manager
        ↓
2. Cert-Manager detecta annotation
        ↓
3. Cria Certificate automaticamente
        ↓
4. Solicita certificado ao Issuer
        ↓
5. Valida domínio (HTTP-01 ou DNS-01)
        ↓
6. Recebe certificado da CA
        ↓
7. Armazena em Secret TLS
        ↓
8. Ingress usa Secret automaticamente
        ↓
9. HTTPS funcionando!
```

---

## Pré-requisitos

### 1. Cert-Manager Instalado

```bash
# Verificar cert-manager
kubectl get pods -n cert-manager

# Verificar CRDs
kubectl get crd | grep cert-manager
```

### 2. Ingress Controller Instalado

```bash
# Verificar Nginx Ingress Controller
kubectl get pods -n ingress-nginx

# Verificar service
kubectl get svc -n ingress-nginx
```

### 3. ClusterIssuer Configurado

```bash
# Verificar issuers
kubectl get clusterissuer

# Deve ter pelo menos um issuer configurado
# Exemplo: letsencrypt-prod, letsencrypt-staging, selfsigned-issuer
```

---

## Método 1: Annotation no Ingress (Mais Simples)

### 1.1 Ingress Básico com HTTPS

```yaml
# app-ingress-https.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    # Especificar qual ClusterIssuer usar
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    
    # Redirecionar HTTP para HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls  # Cert-Manager criará este secret
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

### 1.2 Aplicar e Verificar

```bash
# Aplicar Ingress
kubectl apply -f app-ingress-https.yaml

# Cert-Manager cria Certificate automaticamente
kubectl get certificate

# Output:
# NAME        READY   SECRET       AGE
# myapp-tls   True    myapp-tls    2m

# Ver detalhes do Certificate
kubectl describe certificate myapp-tls

# Ver processo de validação
kubectl get challenge
kubectl get order

# Ver secret criado
kubectl get secret myapp-tls
kubectl describe secret myapp-tls

# Testar HTTPS
curl https://myapp.example.com

# Verificar certificado
echo | openssl s_client -connect myapp.example.com:443 -servername myapp.example.com 2>/dev/null | openssl x509 -noout -dates
```

---

## Método 2: Certificate Explícito

### 2.1 Criar Certificate Manualmente

```yaml
# certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-certificate
  namespace: default
spec:
  # Nome do secret que será criado
  secretName: myapp-tls
  
  # Issuer a ser usado
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io
  
  # Domínios
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
  
  # Configurações do certificado
  duration: 2160h # 90 dias
  renewBefore: 360h # 15 dias antes
  
  # Subject
  subject:
    organizations:
    - MyCompany
  
  # Chave privada
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  
  # Usos
  usages:
  - server auth
  - client auth
```

### 2.2 Criar Ingress Usando o Secret

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    - www.myapp.example.com
    secretName: myapp-tls  # Usa o secret criado pelo Certificate
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
  - host: www.myapp.example.com
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
# Aplicar Certificate primeiro
kubectl apply -f certificate.yaml

# Aguardar certificado ficar pronto
kubectl get certificate myapp-certificate -w

# Aplicar Ingress
kubectl apply -f ingress.yaml

# Testar
curl https://myapp.example.com
curl https://www.myapp.example.com
```

---

## Exemplo Completo: Aplicação com HTTPS

### 1. Deploy da Aplicação

```yaml
# deployment.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: production

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: production
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
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi

---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: production
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### 2. Criar Ingress com HTTPS

```yaml
# ingress-https.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: production
  annotations:
    # Cert-Manager
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    
    # SSL/TLS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    
    # HSTS
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
    
    # Security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-XSS-Protection "1; mode=block" always;
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - webapp.example.com
    secretName: webapp-tls
  rules:
  - host: webapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-service
            port:
              number: 80
```

### 3. Aplicar e Monitorar

```bash
# Aplicar deployment
kubectl apply -f deployment.yaml

# Verificar pods
kubectl get pods -n production

# Aplicar Ingress
kubectl apply -f ingress-https.yaml

# Monitorar criação do certificado
kubectl get certificate -n production -w

# Ver detalhes
kubectl describe certificate webapp-tls -n production

# Ver challenge (validação)
kubectl get challenge -n production
kubectl describe challenge -n production

# Ver order
kubectl get order -n production

# Ver logs do cert-manager
kubectl logs -n cert-manager -l app=cert-manager -f

# Aguardar certificado ficar pronto (1-2 minutos)
# Status deve mudar para: READY=True

# Verificar secret
kubectl get secret webapp-tls -n production

# Testar HTTP (deve redirecionar para HTTPS)
curl -I http://webapp.example.com

# Testar HTTPS
curl https://webapp.example.com

# Verificar certificado
echo | openssl s_client -connect webapp.example.com:443 -servername webapp.example.com 2>/dev/null | openssl x509 -noout -text | grep -A 2 "Issuer"
```

---

## Múltiplos Domínios no Mesmo Ingress

### Opção 1: Múltiplos Hosts com Mesmo Secret

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    - www.app.example.com
    - api.example.com
    secretName: multi-host-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
  - host: www.app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

### Opção 2: Múltiplos Secrets (Certificados Separados)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-cert-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  - hosts:
    - api.example.com
    secretName: api-tls
  - hosts:
    - admin.example.com
    secretName: admin-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
  - host: admin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```

---

## Certificado Wildcard (*.example.com)

### 1. Configurar DNS-01 Issuer

```yaml
# letsencrypt-dns.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-dns
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

### 2. Criar Secret com Credenciais

```bash
# Criar secret AWS
kubectl create secret generic route53-credentials \
  --from-literal=secret-access-key=YOUR_AWS_SECRET_KEY \
  -n cert-manager

# Aplicar issuer
kubectl apply -f letsencrypt-dns.yaml
```

### 3. Criar Certificate Wildcard

```yaml
# wildcard-certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-certificate
  namespace: production
spec:
  secretName: wildcard-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  dnsNames:
  - "*.example.com"
  - example.com
```

### 4. Usar no Ingress

```yaml
# wildcard-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wildcard-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - "*.example.com"
    secretName: wildcard-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
  - host: blog.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80
```

```bash
# Aplicar certificate
kubectl apply -f wildcard-certificate.yaml

# Aguardar (DNS-01 demora mais, 2-5 minutos)
kubectl get certificate wildcard-certificate -n production -w

# Aplicar Ingress
kubectl apply -f wildcard-ingress.yaml

# Testar todos os subdomínios
curl https://app.example.com
curl https://api.example.com
curl https://blog.example.com
```

---

## Annotations Importantes

### Cert-Manager Annotations

```yaml
annotations:
  # Especificar ClusterIssuer
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
  
  # Ou Issuer (namespace-scoped)
  cert-manager.io/issuer: "my-issuer"
  
  # Tipo de issuer
  cert-manager.io/issuer-kind: "ClusterIssuer"
  
  # Grupo do issuer
  cert-manager.io/issuer-group: "cert-manager.io"
  
  # Duração do certificado
  cert-manager.io/duration: "2160h"
  
  # Renovar antes de expirar
  cert-manager.io/renew-before: "360h"
  
  # Algoritmo da chave privada
  cert-manager.io/private-key-algorithm: "RSA"
  
  # Tamanho da chave
  cert-manager.io/private-key-size: "2048"
  
  # Common Name
  cert-manager.io/common-name: "example.com"
```

### Nginx SSL/TLS Annotations

```yaml
annotations:
  # Redirecionar HTTP para HTTPS
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  
  # Protocolos TLS
  nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
  
  # Cipher suites
  nginx.ingress.kubernetes.io/ssl-ciphers: "HIGH:!aNULL:!MD5"
  
  # Preferir cipher do servidor
  nginx.ingress.kubernetes.io/ssl-prefer-server-ciphers: "true"
  
  # HSTS
  nginx.ingress.kubernetes.io/hsts: "true"
  nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
  nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
  nginx.ingress.kubernetes.io/hsts-preload: "true"
  
  # Passthrough (não terminar TLS no Ingress)
  nginx.ingress.kubernetes.io/ssl-passthrough: "true"
```

---

## Staging vs Production

### Usar Staging para Testes

```yaml
# ingress-staging.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress-staging
  namespace: default
  annotations:
    # Usar staging para testes (limites mais altos)
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-staging-tls
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

### Migrar para Production

```bash
# Testar com staging
kubectl apply -f ingress-staging.yaml

# Aguardar certificado
kubectl get certificate myapp-staging-tls -w

# Testar (navegador mostrará aviso - normal para staging)
curl -k https://myapp.example.com

# Se funcionar, mudar para production
kubectl delete ingress myapp-ingress-staging
kubectl delete certificate myapp-staging-tls
kubectl delete secret myapp-staging-tls

# Aplicar production
kubectl apply -f ingress-production.yaml
```

---

## Monitoramento e Troubleshooting

### Verificar Status do Certificado

```bash
# Listar certificates
kubectl get certificate -A

# Ver detalhes
kubectl describe certificate <name> -n <namespace>

# Ver condições
kubectl get certificate <name> -n <namespace> -o jsonpath='{.status.conditions[*]}'

# Ver quando expira
kubectl get certificate <name> -n <namespace> -o jsonpath='{.status.notAfter}'
```

### Verificar Processo de Validação

```bash
# Ver CertificateRequest
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>

# Ver Order (ACME)
kubectl get order -n <namespace>
kubectl describe order <name> -n <namespace>

# Ver Challenge
kubectl get challenge -n <namespace>
kubectl describe challenge <name> -n <namespace>

# Testar URL do challenge (HTTP-01)
CHALLENGE_URL=$(kubectl get challenge <name> -n <namespace> -o jsonpath='{.spec.url}')
curl -I http://<domain>/.well-known/acme-challenge/<token>
```

### Logs

```bash
# Logs do cert-manager
kubectl logs -n cert-manager -l app=cert-manager -f

# Filtrar por namespace
kubectl logs -n cert-manager -l app=cert-manager | grep "production/"

# Filtrar por certificate
kubectl logs -n cert-manager -l app=cert-manager | grep "myapp-tls"

# Ver apenas erros
kubectl logs -n cert-manager -l app=cert-manager | grep -i error
```

### Eventos

```bash
# Eventos do namespace
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp

# Eventos do certificate
kubectl describe certificate <name> -n <namespace> | grep -A 10 Events

# Eventos do Ingress
kubectl describe ingress <name> -n <namespace> | grep -A 10 Events
```

---

## Problemas Comuns e Soluções

### Problema 1: Certificate Fica Pending

```bash
# Ver status
kubectl describe certificate <name> -n <namespace>

# Verificar issuer
kubectl get clusterissuer <issuer-name>
kubectl describe clusterissuer <issuer-name>

# Ver CertificateRequest
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100

# Solução: Deletar e recriar
kubectl delete certificate <name> -n <namespace>
kubectl delete ingress <name> -n <namespace>
kubectl apply -f ingress.yaml
```

### Problema 2: Challenge Falha (HTTP-01)

```bash
# Ver challenge
kubectl describe challenge <name> -n <namespace>

# Testar URL manualmente
curl http://<domain>/.well-known/acme-challenge/test

# Verificar Ingress temporário
kubectl get ingress -A | grep cm-acme

# Verificar se porta 80 está acessível
curl -I http://<domain>

# Solução: Verificar firewall/security groups
# Porta 80 deve estar aberta para validação
```

### Problema 3: Certificado Expirado

```bash
# Ver data de expiração
kubectl get certificate <name> -n <namespace> -o jsonpath='{.status.notAfter}'

# Forçar renovação
kubectl delete certificaterequest <name> -n <namespace>

# Ou deletar secret (cert-manager recria)
kubectl delete secret <secret-name> -n <namespace>

# Aguardar renovação
kubectl get certificate <name> -n <namespace> -w
```

### Problema 4: Navegador Mostra Aviso de Segurança

```bash
# Verificar se é certificado staging
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer

# Se for staging, mudar para production
kubectl annotate ingress <name> -n <namespace> \
  cert-manager.io/cluster-issuer=letsencrypt-prod --overwrite

# Deletar secret antigo
kubectl delete secret <secret-name> -n <namespace>

# Aguardar novo certificado
kubectl get certificate -n <namespace> -w
```

---

## Renovação Automática

### Como Funciona

```
Cert-Manager verifica certificados a cada hora
    ↓
Se faltam menos de renewBefore dias (padrão: 30)
    ↓
Cria novo CertificateRequest
    ↓
Solicita novo certificado
    ↓
Atualiza Secret
    ↓
Ingress usa novo certificado automaticamente
```

### Configurar Renovação

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-cert
spec:
  secretName: myapp-tls
  duration: 2160h # 90 dias
  renewBefore: 720h # 30 dias antes (1/3 da duração)
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
```

### Monitorar Renovação

```bash
# Ver quando expira
kubectl get certificate -A -o custom-columns=\
NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
READY:.status.conditions[0].status,\
EXPIRES:.status.notAfter

# Alertar certificados próximos do vencimento
kubectl get certificate -A -o json | \
  jq -r '.items[] | select(.status.notAfter != null) | 
  "\(.metadata.namespace)/\(.metadata.name): \(.status.notAfter)"'
```

---

## Resumo dos Comandos

```bash
# Criar Ingress com HTTPS
kubectl apply -f ingress-https.yaml

# Verificar certificate
kubectl get certificate
kubectl describe certificate <name>

# Ver processo de validação
kubectl get challenge
kubectl get order

# Ver secret
kubectl get secret <secret-name>

# Testar HTTPS
curl https://domain.example.com

# Ver certificado
echo | openssl s_client -connect domain.example.com:443 -servername domain.example.com 2>/dev/null | openssl x509 -noout -text

# Logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Forçar renovação
kubectl delete certificaterequest <name>
```

---

## Conclusão

Com Ingress + Cert-Manager configurado, você tem:

✅ **HTTPS automático** - Certificados emitidos automaticamente  
✅ **Renovação automática** - Sem preocupação com expiração  
✅ **Múltiplos domínios** - Suporte a vários hosts  
✅ **Wildcard** - Certificados *.example.com  
✅ **Segurança** - TLS 1.2+, HSTS, headers de segurança  
✅ **Monitoramento** - Logs e eventos completos  

Suas aplicações agora têm HTTPS profissional e automático!
