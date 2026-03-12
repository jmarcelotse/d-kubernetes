# Configurando um Domínio Válido para o Nosso Ingress no EKS

## Introdução

Configurar um domínio válido no EKS envolve integrar o Ingress Controller com o AWS Route 53 (DNS) e, opcionalmente, com o AWS Certificate Manager (ACM) para SSL/TLS. Este guia mostra o processo completo do registro do domínio até a aplicação funcionando com HTTPS.

## Fluxo Completo

```
1. Registrar/Ter Domínio
        ↓
2. Criar Hosted Zone no Route 53
        ↓
3. Instalar Ingress Controller no EKS
        ↓
4. Obter LoadBalancer DNS
        ↓
5. Criar Registro DNS (A/CNAME)
        ↓
6. Configurar Ingress Resource
        ↓
7. (Opcional) Configurar SSL/TLS
        ↓
8. Testar Aplicação
```

---

## Pré-requisitos

### 1. Cluster EKS Funcionando

```bash
# Verificar cluster
kubectl get nodes
kubectl cluster-info

# Ver contexto
kubectl config current-context
```

### 2. Domínio Registrado

Você precisa de um domínio. Opções:

- **Registrar na AWS Route 53**: $12-15/ano
- **Usar domínio existente**: Transferir DNS para Route 53
- **Domínio gratuito para testes**: Freenom, No-IP (não recomendado para produção)

### 3. Ferramentas Instaladas

```bash
# Verificar
aws --version
kubectl version --client
helm version
```

---

## Passo 1: Configurar Route 53

### 1.1 Criar Hosted Zone

```bash
# Via AWS CLI
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s) \
  --hosted-zone-config Comment="EKS Ingress Domain"

# Obter Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name example.com \
  --query "HostedZones[0].Id" \
  --output text)

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# Ver nameservers
aws route53 get-hosted-zone --id $HOSTED_ZONE_ID \
  --query "DelegationSet.NameServers" \
  --output table
```

**Via Console AWS:**
1. Route 53 → Hosted zones → Create hosted zone
2. Domain name: `example.com`
3. Type: Public hosted zone
4. Create hosted zone
5. Anotar os 4 nameservers (ns-xxx.awsdns-xx.com)

### 1.2 Atualizar Nameservers no Registrador

Se o domínio foi registrado fora da AWS:

1. Acessar painel do registrador (GoDaddy, Namecheap, etc)
2. Encontrar configurações de DNS/Nameservers
3. Substituir pelos nameservers do Route 53
4. Aguardar propagação (até 48h, geralmente 1-2h)

### 1.3 Verificar Propagação DNS

```bash
# Verificar nameservers
dig NS example.com +short

# Deve retornar os nameservers do Route 53:
# ns-1234.awsdns-12.org.
# ns-5678.awsdns-56.com.
# ...

# Verificar de diferentes servidores
dig @8.8.8.8 NS example.com +short
dig @1.1.1.1 NS example.com +short
```

---

## Passo 2: Instalar Ingress Controller

### 2.1 Instalar Nginx Ingress Controller

```bash
# Adicionar repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Instalar
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"

# Aguardar LoadBalancer
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Verificar
kubectl get svc -n ingress-nginx
```

### 2.2 Obter DNS do LoadBalancer

```bash
# Obter hostname do NLB
export LB_HOSTNAME=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "LoadBalancer DNS: $LB_HOSTNAME"

# Exemplo: a1b2c3d4e5f6g7h8-1234567890.us-east-1.elb.amazonaws.com

# Testar conectividade
curl -I http://$LB_HOSTNAME
# Deve retornar 404 (normal, sem Ingress configurado ainda)
```

---

## Passo 3: Configurar DNS no Route 53

### 3.1 Criar Registro Wildcard (Recomendado)

```bash
# Criar registro *.example.com apontando para o LoadBalancer
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "*.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$LB_HOSTNAME'"}]
      }
    }]
  }'

# Verificar
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query "ResourceRecordSets[?Name=='*.example.com.']"
```

### 3.2 Criar Registros Específicos (Alternativa)

```bash
# Criar registro para app.example.com
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$LB_HOSTNAME'"}]
      }
    }]
  }'

# Criar registro para api.example.com
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$LB_HOSTNAME'"}]
      }
    }]
  }'
```

### 3.3 Criar Registro Apex (example.com)

```bash
# Para domínio raiz, usar Alias Record
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z1234567890ABC",
          "DNSName": "'$LB_HOSTNAME'",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'

# Nota: Substituir Z1234567890ABC pelo Hosted Zone ID do ELB
# Para us-east-1: Z26RNL4JYFTOTI
# Lista completa: https://docs.aws.amazon.com/general/latest/gr/elb.html
```

### 3.4 Verificar DNS

```bash
# Testar resolução DNS
dig app.example.com +short
dig api.example.com +short
dig example.com +short

# Deve retornar IPs do LoadBalancer

# Testar de diferentes servidores
dig @8.8.8.8 app.example.com +short
dig @1.1.1.1 app.example.com +short

# Verificar propagação global
# https://www.whatsmydns.net/#A/app.example.com
```

---

## Passo 4: Deploy de Aplicação de Teste

### 4.1 Criar Aplicação

Crie o arquivo `app-deployment.yaml`:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: production

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 3
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
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      initContainers:
      - name: setup
        image: busybox
        command:
        - sh
        - -c
        - |
          cat > /html/index.html <<EOF
          <!DOCTYPE html>
          <html>
          <head><title>My App on EKS</title></head>
          <body>
            <h1>Hello from EKS!</h1>
            <p>Domain: app.example.com</p>
            <p>Pod: $(hostname)</p>
          </body>
          </html>
          EOF
        volumeMounts:
        - name: html
          mountPath: /html
      volumes:
      - name: html
        emptyDir: {}

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
  type: ClusterIP
```

```bash
# Aplicar
kubectl apply -f app-deployment.yaml

# Verificar
kubectl get all -n production
kubectl get pods -n production
```

### 4.2 Criar Ingress Resource

Crie o arquivo `app-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
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
kubectl apply -f app-ingress.yaml

# Verificar
kubectl get ingress -n production
kubectl describe ingress myapp-ingress -n production

# Aguardar ADDRESS ser preenchido
kubectl get ingress myapp-ingress -n production -w
```

### 4.3 Testar Aplicação

```bash
# Testar HTTP
curl http://app.example.com

# Deve retornar:
# <!DOCTYPE html>
# <html>
# <head><title>My App on EKS</title></head>
# ...

# Testar múltiplas vezes (load balancing)
for i in {1..10}; do
  curl -s http://app.example.com | grep "Pod:"
done

# Testar de navegador
# http://app.example.com
```

---

## Passo 5: Configurar HTTPS com Cert-Manager

### 5.1 Instalar Cert-Manager

```bash
# Instalar CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml

# Adicionar repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Instalar
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0

# Verificar
kubectl get pods -n cert-manager
```

### 5.2 Configurar Let's Encrypt

Crie o arquivo `letsencrypt-issuer.yaml`:

```yaml
---
# Staging (para testes)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: seu-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx

---
# Production
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: seu-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
# Aplicar
kubectl apply -f letsencrypt-issuer.yaml

# Verificar
kubectl get clusterissuer
```

### 5.3 Atualizar Ingress com TLS

Crie o arquivo `app-ingress-tls.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-example-com-tls
  rules:
  - host: app.example.com
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
kubectl apply -f app-ingress-tls.yaml

# Ver certificado sendo criado
kubectl get certificate -n production
kubectl describe certificate app-example-com-tls -n production

# Ver challenge (validação HTTP-01)
kubectl get challenge -n production

# Ver logs do cert-manager
kubectl logs -n cert-manager -l app=cert-manager -f

# Aguardar certificado ficar pronto (1-2 minutos)
kubectl get certificate -n production -w

# Verificar secret criado
kubectl get secret app-example-com-tls -n production
```

### 5.4 Testar HTTPS

```bash
# Testar HTTPS
curl https://app.example.com

# Verificar certificado
openssl s_client -connect app.example.com:443 -servername app.example.com < /dev/null 2>/dev/null | openssl x509 -noout -text | grep -A 2 "Issuer"

# Deve mostrar: Issuer: C = US, O = Let's Encrypt

# Testar redirecionamento HTTP → HTTPS
curl -I http://app.example.com
# Deve retornar: 308 Permanent Redirect

# Testar no navegador
# https://app.example.com
```

---

## Passo 6: Múltiplos Subdomínios

### 6.1 Criar Múltiplas Aplicações

```bash
# App 1: Blog
kubectl create deployment blog --image=nginx:alpine --replicas=2 -n production
kubectl expose deployment blog --port=80 --name=blog-service -n production

# App 2: API
kubectl create deployment api --image=kennethreitz/httpbin --replicas=2 -n production
kubectl expose deployment api --port=80 --name=api-service -n production

# App 3: Admin
kubectl create deployment admin --image=httpd:alpine --replicas=2 -n production
kubectl expose deployment admin --port=80 --name=admin-service -n production

# Verificar
kubectl get all -n production
```

### 6.2 Criar Ingress Multi-Host

Crie o arquivo `multi-host-ingress.yaml`:

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
    - blog.example.com
    - api.example.com
    - admin.example.com
    secretName: multi-host-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
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

```bash
# Aplicar
kubectl apply -f multi-host-ingress.yaml

# Verificar certificado
kubectl get certificate -n production -w

# Testar todos os subdomínios
curl https://app.example.com
curl https://blog.example.com
curl https://api.example.com/get
curl https://admin.example.com
```

---

## Passo 7: Configurar External DNS (Automação)

### 7.1 Criar IAM Policy

```bash
# Criar policy
cat > external-dns-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF

# Criar policy na AWS
aws iam create-policy \
  --policy-name ExternalDNSPolicy \
  --policy-document file://external-dns-policy.json
```

### 7.2 Criar Service Account

```bash
# Criar service account com IAM role
eksctl create iamserviceaccount \
  --cluster=meu-cluster-eks \
  --namespace=kube-system \
  --name=external-dns \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ExternalDNSPolicy \
  --override-existing-serviceaccounts \
  --approve

# Verificar
kubectl get sa external-dns -n kube-system
```

### 7.3 Instalar External DNS

Crie o arquivo `external-dns.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.0
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=example.com
        - --provider=aws
        - --policy=upsert-only
        - --aws-zone-type=public
        - --registry=txt
        - --txt-owner-id=meu-cluster-eks
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
```

```bash
# Aplicar
kubectl apply -f external-dns.yaml

# Verificar
kubectl get pods -n kube-system -l app=external-dns
kubectl logs -n kube-system -l app=external-dns -f
```

### 7.4 Testar External DNS

```bash
# Criar Ingress com annotation
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-external-dns
  namespace: production
  annotations:
    external-dns.alpha.kubernetes.io/hostname: test.example.com
spec:
  ingressClassName: nginx
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
EOF

# Aguardar External DNS criar registro (1-2 minutos)
kubectl logs -n kube-system -l app=external-dns -f

# Verificar no Route 53
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query "ResourceRecordSets[?Name=='test.example.com.']"

# Testar
curl http://test.example.com
```

---

## Monitoramento e Troubleshooting

### Verificar DNS

```bash
# Testar resolução
dig app.example.com +short
nslookup app.example.com

# Verificar TTL
dig app.example.com +noall +answer

# Testar de diferentes locais
# https://www.whatsmydns.net/
```

### Verificar Ingress

```bash
# Ver Ingress
kubectl get ingress -n production
kubectl describe ingress myapp-ingress -n production

# Ver eventos
kubectl get events -n production --sort-by=.metadata.creationTimestamp

# Logs do Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

### Verificar Certificado

```bash
# Ver certificado
kubectl get certificate -n production
kubectl describe certificate app-example-com-tls -n production

# Ver challenge
kubectl get challenge -n production

# Logs do cert-manager
kubectl logs -n cert-manager -l app=cert-manager -f

# Testar certificado
echo | openssl s_client -connect app.example.com:443 -servername app.example.com 2>/dev/null | openssl x509 -noout -dates
```

### Problemas Comuns

**1. DNS não resolve**
```bash
# Verificar nameservers
dig NS example.com +short

# Verificar registro
dig app.example.com +short

# Aguardar propagação (até 48h)
```

**2. Certificado não é emitido**
```bash
# Verificar challenge
kubectl get challenge -n production
kubectl describe challenge -n production

# Verificar se porta 80 está acessível
curl -I http://app.example.com/.well-known/acme-challenge/test

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager
```

**3. 503 Service Unavailable**
```bash
# Verificar pods
kubectl get pods -n production

# Verificar service
kubectl get svc -n production
kubectl get endpoints myapp-service -n production

# Testar service internamente
kubectl run curl-test --rm -it --image=curlimages/curl -- curl http://myapp-service.production
```

---

## Custos

### Estimativa Mensal

```
Route 53:
- Hosted Zone: $0.50/mês
- Queries: $0.40/milhão (primeiros 1 bilhão)

Network Load Balancer:
- $0.0225/hora = ~$16.20/mês
- LCU: ~$5-10/mês (variável)

Certificados Let's Encrypt:
- Gratuito

Total estimado: ~$22-27/mês
```

---

## Resumo dos Comandos

```bash
# Criar Hosted Zone
aws route53 create-hosted-zone --name example.com

# Instalar Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

# Obter LoadBalancer DNS
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Criar registro DNS
aws route53 change-resource-record-sets --hosted-zone-id <id> --change-batch <json>

# Instalar Cert-Manager
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace

# Verificar certificado
kubectl get certificate -n production

# Testar
curl https://app.example.com
```

---

## Conclusão

Com domínio válido configurado, você tem:

✅ **DNS gerenciado** - Route 53 integrado  
✅ **HTTPS automático** - Let's Encrypt via Cert-Manager  
✅ **Múltiplos subdomínios** - Wildcard ou específicos  
✅ **Automação** - External DNS (opcional)  
✅ **Produção-ready** - Configuração profissional  
✅ **Escalável** - Suporta múltiplas aplicações  

Sua aplicação agora está acessível via domínio real com HTTPS válido!
