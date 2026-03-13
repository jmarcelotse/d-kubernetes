# Instalando e Configurando o Cert-Manager

## Introdução

Este guia mostra o processo completo de instalação e configuração do Cert-Manager, desde a preparação do ambiente até a emissão do primeiro certificado. Vamos cobrir diferentes métodos de instalação e configurações para diversos cenários.

## Pré-requisitos

### Verificar Cluster

```bash
# Verificar cluster está funcionando
kubectl cluster-info
kubectl get nodes

# Verificar versão do Kubernetes (mínimo 1.22)
kubectl version --short

# Verificar se há recursos suficientes
kubectl top nodes
```

### Ferramentas Necessárias

```bash
# kubectl
kubectl version --client

# Helm (recomendado)
helm version

# Instalar Helm se necessário
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## Método 1: Instalação via kubectl (Simples)

### 1.1 Instalar CRDs

```bash
# Baixar e aplicar CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml

# Verificar CRDs instalados
kubectl get crd | grep cert-manager

# Output esperado:
# certificaterequests.cert-manager.io
# certificates.cert-manager.io
# challenges.acme.cert-manager.io
# clusterissuers.cert-manager.io
# issuers.cert-manager.io
# orders.acme.cert-manager.io
```

### 1.2 Instalar Cert-Manager

```bash
# Aplicar manifesto completo
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=120s
```

### 1.3 Verificar Instalação

```bash
# Ver namespace
kubectl get namespace cert-manager

# Ver pods
kubectl get pods -n cert-manager

# Output esperado:
# NAME                                       READY   STATUS    RESTARTS   AGE
# cert-manager-7d9f8c8d4-xxxxx              1/1     Running   0          2m
# cert-manager-cainjector-5c5695c4b-xxxxx   1/1     Running   0          2m
# cert-manager-webhook-7b8c8c8d4-xxxxx      1/1     Running   0          2m

# Ver services
kubectl get svc -n cert-manager

# Ver deployments
kubectl get deployment -n cert-manager
```

---

## Método 2: Instalação via Helm (Recomendado)

### 2.1 Adicionar Repositório

```bash
# Adicionar repositório Jetstack
helm repo add jetstack https://charts.jetstack.io

# Atualizar repositórios
helm repo update

# Verificar versões disponíveis
helm search repo cert-manager
```

### 2.2 Instalação Básica

```bash
# Instalar cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true

# Verificar instalação
helm list -n cert-manager
kubectl get pods -n cert-manager
```

### 2.3 Instalação com Valores Customizados

Crie o arquivo `cert-manager-values.yaml`:

```yaml
# Configurações globais
global:
  leaderElection:
    namespace: cert-manager
  
  # Log level (1-6, sendo 6 o mais verboso)
  logLevel: 2

# Controller principal
replicaCount: 1

resources:
  requests:
    cpu: 10m
    memory: 32Mi
  limits:
    cpu: 100m
    memory: 128Mi

# Prometheus metrics
prometheus:
  enabled: true
  servicemonitor:
    enabled: false
    prometheusInstance: default
    interval: 60s
    scrapeTimeout: 30s

# Webhook
webhook:
  replicaCount: 1
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi
  
  # Timeout para validação
  timeoutSeconds: 10
  
  # Host network (útil em alguns ambientes)
  hostNetwork: false

# CA Injector
cainjector:
  replicaCount: 1
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 128Mi

# Instalar CRDs via Helm
installCRDs: true

# Security context
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

# Node selector (opcional)
nodeSelector: {}

# Tolerations (opcional)
tolerations: []

# Affinity (opcional)
affinity: {}
```

```bash
# Instalar com valores customizados
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --values cert-manager-values.yaml

# Verificar
kubectl get all -n cert-manager
```

---

## Método 3: Instalação em Ambientes Específicos

### 3.1 EKS (AWS)

```bash
# Instalar com configurações para EKS
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true \
  --set securityContext.fsGroup=1001

# Verificar
kubectl get pods -n cert-manager
```

### 3.2 GKE (Google Cloud)

```bash
# Instalar com configurações para GKE
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager

# Verificar
kubectl get pods -n cert-manager
```

### 3.3 AKS (Azure)

```bash
# Instalar com configurações para AKS
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true

# Verificar
kubectl get pods -n cert-manager
```

### 3.4 Kind (Local)

```bash
# Instalar para Kind
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true \
  --set webhook.hostNetwork=true

# Verificar
kubectl get pods -n cert-manager
```

---

## Configuração Inicial

### 1. Criar Namespace para Aplicações

```bash
# Criar namespace de produção
kubectl create namespace production

# Criar namespace de staging
kubectl create namespace staging

# Verificar
kubectl get namespaces
```

### 2. Configurar RBAC (se necessário)

```yaml
# rbac.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager-user
  namespace: production

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cert-manager-user-role
  namespace: production
rules:
- apiGroups: ["cert-manager.io"]
  resources: ["certificates", "certificaterequests"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cert-manager-user-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cert-manager-user-role
subjects:
- kind: ServiceAccount
  name: cert-manager-user
  namespace: production
```

```bash
# Aplicar RBAC
kubectl apply -f rbac.yaml

# Verificar
kubectl get sa -n production
kubectl get role -n production
kubectl get rolebinding -n production
```

---

## Configurar Issuers

### 1. Self-Signed Issuer (Desenvolvimento)

```yaml
# selfsigned-issuer.yaml
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

### 2. Let's Encrypt Staging (Testes)

```yaml
# letsencrypt-staging.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # Servidor staging (limites mais altos para testes)
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    
    # Email para notificações de expiração
    email: admin@example.com
    
    # Secret para armazenar chave privada da conta ACME
    privateKeySecretRef:
      name: letsencrypt-staging
    
    # Solvers (métodos de validação)
    solvers:
    # HTTP-01 challenge
    - http01:
        ingress:
          class: nginx
```

```bash
# Aplicar
kubectl apply -f letsencrypt-staging.yaml

# Verificar
kubectl get clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-staging

# Ver secret criado
kubectl get secret letsencrypt-staging -n cert-manager
```

### 3. Let's Encrypt Production

```yaml
# letsencrypt-prod.yaml
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
# Aplicar
kubectl apply -f letsencrypt-prod.yaml

# Verificar
kubectl get clusterissuer letsencrypt-prod
kubectl describe clusterissuer letsencrypt-prod
```

### 4. Issuer com DNS-01 (Wildcard)

#### Route 53 (AWS)

```yaml
# letsencrypt-dns-route53.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns-route53
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-dns-route53
    solvers:
    - dns01:
        route53:
          region: us-east-1
          # Opcional: especificar hosted zone
          hostedZoneID: Z1234567890ABC
          # Credenciais AWS
          accessKeyID: AKIAIOSFODNN7EXAMPLE
          secretAccessKeySecretRef:
            name: route53-credentials
            key: secret-access-key
```

Criar secret com credenciais:

```bash
# Criar secret com AWS credentials
kubectl create secret generic route53-credentials \
  --from-literal=secret-access-key=YOUR_AWS_SECRET_KEY \
  -n cert-manager

# Aplicar issuer
kubectl apply -f letsencrypt-dns-route53.yaml

# Verificar
kubectl get clusterissuer letsencrypt-dns-route53
```

#### CloudFlare

```yaml
# letsencrypt-dns-cloudflare.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns-cloudflare
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-dns-cloudflare
    solvers:
    - dns01:
        cloudflare:
          email: admin@example.com
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

Criar secret:

```bash
# Criar secret com CloudFlare API token
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=YOUR_CLOUDFLARE_API_TOKEN \
  -n cert-manager

# Aplicar
kubectl apply -f letsencrypt-dns-cloudflare.yaml
```

---

## Testar Instalação

### 1. Criar Certificate de Teste

```yaml
# test-certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: default
spec:
  secretName: test-tls-secret
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: test.example.com
  dnsNames:
  - test.example.com
```

```bash
# Aplicar
kubectl apply -f test-certificate.yaml

# Ver status
kubectl get certificate test-certificate
kubectl describe certificate test-certificate

# Aguardar ficar pronto
kubectl get certificate test-certificate -w

# Ver secret criado
kubectl get secret test-tls-secret
kubectl describe secret test-tls-secret

# Ver certificado
kubectl get secret test-tls-secret -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

### 2. Verificar Logs

```bash
# Logs do controller
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Logs do webhook
kubectl logs -n cert-manager -l app=webhook --tail=50

# Logs do cainjector
kubectl logs -n cert-manager -l app=cainjector --tail=50

# Seguir logs em tempo real
kubectl logs -n cert-manager -l app=cert-manager -f
```

### 3. Verificar Eventos

```bash
# Eventos do namespace
kubectl get events -n default --sort-by=.metadata.creationTimestamp

# Eventos do cert-manager
kubectl get events -n cert-manager --sort-by=.metadata.creationTimestamp

# Eventos de um Certificate específico
kubectl describe certificate test-certificate | grep -A 10 Events
```

---

## Configurações Avançadas

### 1. Habilitar Métricas Prometheus

```yaml
# prometheus-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cert-manager
  namespace: cert-manager
  labels:
    app: cert-manager
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: cert-manager
  endpoints:
  - port: tcp-prometheus-servicemonitor
    interval: 60s
    scrapeTimeout: 30s
```

```bash
# Aplicar (requer Prometheus Operator)
kubectl apply -f prometheus-servicemonitor.yaml

# Ver métricas
kubectl port-forward -n cert-manager svc/cert-manager 9402:9402
curl http://localhost:9402/metrics
```

### 2. Configurar Webhook com TLS Customizado

```yaml
# webhook-tls.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cert-manager-webhook-tls
  namespace: cert-manager
spec:
  secretName: cert-manager-webhook-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
  - cert-manager-webhook
  - cert-manager-webhook.cert-manager
  - cert-manager-webhook.cert-manager.svc
```

### 3. Configurar Resource Limits

```bash
# Atualizar via Helm
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --reuse-values \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=64Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi

# Verificar
kubectl get deployment cert-manager -n cert-manager -o yaml | grep -A 10 resources
```

---

## Exemplo Completo: Aplicação com HTTPS

### 1. Deploy da Aplicação

```yaml
# app-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: production
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
```

### 2. Criar Ingress com Cert-Manager

```yaml
# app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    # Especificar issuer
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Redirecionar HTTP para HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
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

### 3. Aplicar e Monitorar

```bash
# Aplicar recursos
kubectl apply -f app-deployment.yaml
kubectl apply -f app-ingress.yaml

# Cert-Manager cria Certificate automaticamente
kubectl get certificate -n production

# Ver processo de emissão
kubectl describe certificate myapp-tls -n production

# Ver challenge (validação HTTP-01)
kubectl get challenge -n production
kubectl describe challenge -n production

# Ver order
kubectl get order -n production
kubectl describe order -n production

# Aguardar certificado ficar pronto (1-2 minutos)
kubectl get certificate myapp-tls -n production -w

# Verificar secret
kubectl get secret myapp-tls -n production
kubectl describe secret myapp-tls -n production

# Testar HTTPS
curl https://myapp.example.com

# Verificar certificado
echo | openssl s_client -connect myapp.example.com:443 -servername myapp.example.com 2>/dev/null | openssl x509 -noout -text
```

---

## Troubleshooting

### Problema 1: Pods Não Iniciam

```bash
# Ver status dos pods
kubectl get pods -n cert-manager

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100

# Ver eventos
kubectl get events -n cert-manager --sort-by=.metadata.creationTimestamp

# Verificar recursos
kubectl describe pod -n cert-manager -l app=cert-manager

# Solução comum: Aumentar recursos
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --reuse-values \
  --set resources.limits.memory=256Mi
```

### Problema 2: Webhook Não Responde

```bash
# Testar webhook
kubectl run test-webhook --rm -it --image=curlimages/curl -- \
  curl -k https://cert-manager-webhook.cert-manager.svc:443/validate

# Ver logs do webhook
kubectl logs -n cert-manager -l app=webhook --tail=100

# Verificar service
kubectl get svc cert-manager-webhook -n cert-manager

# Recriar webhook
kubectl rollout restart deployment cert-manager-webhook -n cert-manager
```

### Problema 3: Certificate Fica Pending

```bash
# Ver status detalhado
kubectl describe certificate <name> -n <namespace>

# Ver CertificateRequest
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager | grep <certificate-name>

# Verificar issuer
kubectl get clusterissuer <issuer-name>
kubectl describe clusterissuer <issuer-name>

# Deletar e recriar
kubectl delete certificate <name> -n <namespace>
kubectl apply -f certificate.yaml
```

### Problema 4: Challenge Falha

```bash
# Ver challenge
kubectl get challenge -n <namespace>
kubectl describe challenge <name> -n <namespace>

# Testar URL do challenge (HTTP-01)
curl http://<domain>/.well-known/acme-challenge/test

# Ver Ingress temporário
kubectl get ingress -n <namespace> | grep cm-acme

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager | grep challenge

# Verificar firewall/security groups (porta 80 deve estar aberta)
```

---

## Atualizar Cert-Manager

### Via Helm

```bash
# Ver versão atual
helm list -n cert-manager

# Atualizar repositório
helm repo update

# Ver novas versões
helm search repo cert-manager

# Atualizar
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.14.0 \
  --reuse-values

# Verificar
kubectl get pods -n cert-manager
kubectl rollout status deployment cert-manager -n cert-manager
```

### Via kubectl

```bash
# Atualizar CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.crds.yaml

# Atualizar cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Verificar
kubectl get pods -n cert-manager
```

---

## Desinstalar Cert-Manager

### Via Helm

```bash
# Desinstalar
helm uninstall cert-manager -n cert-manager

# Deletar namespace
kubectl delete namespace cert-manager

# Deletar CRDs (cuidado: remove todos os certificates)
kubectl delete crd certificaterequests.cert-manager.io
kubectl delete crd certificates.cert-manager.io
kubectl delete crd challenges.acme.cert-manager.io
kubectl delete crd clusterissuers.cert-manager.io
kubectl delete crd issuers.cert-manager.io
kubectl delete crd orders.acme.cert-manager.io

# Ou deletar todos de uma vez
kubectl get crd | grep cert-manager | awk '{print $1}' | xargs kubectl delete crd
```

### Via kubectl

```bash
# Deletar cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Deletar CRDs
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml

# Verificar
kubectl get namespace cert-manager
kubectl get crd | grep cert-manager
```

---

## Resumo dos Comandos

```bash
# Instalar via Helm
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Verificar instalação
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager

# Criar ClusterIssuer
kubectl apply -f clusterissuer.yaml

# Criar Certificate
kubectl apply -f certificate.yaml

# Verificar status
kubectl get certificate
kubectl describe certificate <name>

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Atualizar
helm upgrade cert-manager jetstack/cert-manager -n cert-manager

# Desinstalar
helm uninstall cert-manager -n cert-manager
```

---

## Conclusão

Com o Cert-Manager instalado e configurado, você tem:

✅ **Automação completa** - Emissão e renovação de certificados  
✅ **Múltiplos issuers** - Self-signed, Let's Encrypt, CA, etc.  
✅ **Validação flexível** - HTTP-01, DNS-01  
✅ **Integração nativa** - Funciona automaticamente com Ingress  
✅ **Monitoramento** - Logs, eventos e métricas  
✅ **Produção-ready** - Configurações otimizadas  

Agora você pode emitir certificados TLS automaticamente para todas as suas aplicações!
