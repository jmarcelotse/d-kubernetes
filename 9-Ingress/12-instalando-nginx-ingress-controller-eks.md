# Instalando o Ingress Nginx Controller no EKS

## Introdução

O Nginx Ingress Controller no EKS funciona de forma diferente de clusters locais (Kind, Minikube). No EKS, o Ingress Controller cria automaticamente um AWS Network Load Balancer (NLB) para receber tráfego externo, integrando-se nativamente com a infraestrutura AWS.

## Arquitetura no EKS

```
Internet
    ↓
AWS Network Load Balancer (NLB)
    ↓
Nginx Ingress Controller (Pods)
    ↓
Ingress Resources (Regras)
    ↓
Services (ClusterIP)
    ↓
Pods (Aplicações)
```

### Diferenças entre EKS e Clusters Locais

| Aspecto | Cluster Local (Kind) | EKS |
|---------|---------------------|-----|
| Load Balancer | NodePort ou HostPort | AWS NLB |
| IP Externo | localhost | DNS público AWS |
| Custo | Gratuito | ~$18/mês (NLB) |
| SSL/TLS | Self-signed | ACM ou Let's Encrypt |
| Escalabilidade | Limitada | Auto-scaling |

---

## Pré-requisitos

### 1. Cluster EKS Funcionando

```bash
# Verificar cluster
kubectl get nodes
kubectl cluster-info

# Ver contexto atual
kubectl config current-context

# Deve mostrar algo como: arn:aws:eks:us-east-1:123456789012:cluster/meu-cluster-eks
```

### 2. Ferramentas Instaladas

```bash
# Verificar
kubectl version --client
helm version
aws --version

# Instalar Helm (se necessário)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## Método 1: Instalação via Helm (Recomendado)

### 1.1 Adicionar Repositório Helm

```bash
# Adicionar repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Atualizar repos
helm repo update

# Verificar versões disponíveis
helm search repo ingress-nginx
```

### 1.2 Instalar Nginx Ingress Controller

```bash
# Instalação básica
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Aguardar instalação
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 1.3 Verificar Instalação

```bash
# Ver pods
kubectl get pods -n ingress-nginx

# Ver service
kubectl get svc -n ingress-nginx

# Output esperado:
# NAME                                 TYPE           EXTERNAL-IP
# ingress-nginx-controller             LoadBalancer   a1b2c3...elb.amazonaws.com

# Ver detalhes do LoadBalancer
kubectl describe svc ingress-nginx-controller -n ingress-nginx
```

### 1.4 Obter URL do Load Balancer

```bash
# Obter hostname do NLB
export INGRESS_HOST=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Ingress URL: http://$INGRESS_HOST"

# Testar (deve retornar 404 - normal, sem Ingress configurado ainda)
curl http://$INGRESS_HOST
```

---

## Método 2: Instalação com Configurações Customizadas

### 2.1 Criar Arquivo de Valores

Crie o arquivo `ingress-nginx-values.yaml`:

```yaml
controller:
  # Service Configuration
  service:
    type: LoadBalancer
    annotations:
      # Network Load Balancer (melhor performance)
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      # Cross-zone load balancing
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      # Backend protocol
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
      # Proxy protocol (opcional)
      service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
    
    # Portas
    ports:
      http: 80
      https: 443
    
    targetPorts:
      http: http
      https: https

  # Recursos
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Réplicas
  replicaCount: 2

  # Anti-affinity (distribuir pods em nodes diferentes)
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - ingress-nginx
          topologyKey: kubernetes.io/hostname

  # Métricas
  metrics:
    enabled: true
    serviceMonitor:
      enabled: false

  # Logs
  config:
    use-forwarded-headers: "true"
    compute-full-forwarded-for: "true"
    use-proxy-protocol: "true"

# Admission Webhooks
admissionWebhooks:
  enabled: true
```

### 2.2 Instalar com Valores Customizados

```bash
# Instalar
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values ingress-nginx-values.yaml

# Verificar
kubectl get all -n ingress-nginx
```

---

## Método 3: Instalação com AWS Load Balancer Controller

### 3.1 Instalar AWS Load Balancer Controller (Pré-requisito)

```bash
# Criar IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Criar service account
eksctl create iamserviceaccount \
  --cluster=meu-cluster-eks \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Instalar controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=meu-cluster-eks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verificar
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 3.2 Instalar Nginx Ingress com NLB

```bash
# Instalar com annotations para NLB
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true"

# Verificar
kubectl get svc -n ingress-nginx
```

---

## Configuração de DNS

### Opção 1: Route 53 (Recomendado para Produção)

```bash
# Obter hostname do NLB
INGRESS_HOST=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo $INGRESS_HOST

# Criar registro no Route 53 (via Console ou CLI)
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "*.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$INGRESS_HOST'"}]
      }
    }]
  }'

# Testar DNS
nslookup app.example.com
dig app.example.com
```

### Opção 2: /etc/hosts (Apenas para Testes)

```bash
# Obter IP do NLB
INGRESS_IP=$(nslookup $INGRESS_HOST | grep Address | tail -1 | awk '{print $2}')

# Adicionar ao /etc/hosts
sudo bash -c "cat >> /etc/hosts << EOF
$INGRESS_IP app.example.com
$INGRESS_IP api.example.com
$INGRESS_IP blog.example.com
EOF"

# Verificar
cat /etc/hosts | grep example.com
```

---

## Testar o Ingress Controller

### 1. Deploy de Aplicação de Teste

Crie o arquivo `test-app.yaml`:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
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
  name: nginx-test-service
  namespace: default
spec:
  selector:
    app: nginx-test
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

```bash
# Aplicar
kubectl apply -f test-app.yaml

# Verificar
kubectl get pods -l app=nginx-test
kubectl get svc nginx-test-service
```

### 2. Criar Ingress Resource

Crie o arquivo `test-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test-ingress
  namespace: default
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
            name: nginx-test-service
            port:
              number: 80
```

```bash
# Aplicar
kubectl apply -f test-ingress.yaml

# Verificar
kubectl get ingress nginx-test-ingress
kubectl describe ingress nginx-test-ingress

# Aguardar ADDRESS ser preenchido
kubectl get ingress nginx-test-ingress -w
```

### 3. Testar Acesso

```bash
# Via hostname do NLB
curl -H "Host: app.example.com" http://$INGRESS_HOST

# Via DNS (se configurado)
curl http://app.example.com

# Testar múltiplas vezes (load balancing)
for i in {1..10}; do
  curl -s http://app.example.com | grep -i welcome
done
```

---

## Configurar HTTPS com Cert-Manager

### 1. Instalar Cert-Manager

```bash
# Adicionar repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Instalar CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml

# Instalar cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0

# Verificar
kubectl get pods -n cert-manager
```

### 2. Configurar Let's Encrypt

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

### 3. Ingress com TLS Automático

Crie o arquivo `test-ingress-tls.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test-ingress-tls
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
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
            name: nginx-test-service
            port:
              number: 80
```

```bash
# Aplicar
kubectl apply -f test-ingress-tls.yaml

# Ver certificado sendo criado
kubectl get certificate
kubectl describe certificate app-example-com-tls

# Ver challenge (validação)
kubectl get challenge

# Aguardar certificado ficar pronto
kubectl get certificate -w

# Testar HTTPS
curl https://app.example.com
```

---

## Configurar HTTPS com AWS ACM

### 1. Criar Certificado no ACM

```bash
# Via Console AWS:
# 1. ACM → Request Certificate
# 2. Request public certificate
# 3. Domain: *.example.com
# 4. Validation: DNS
# 5. Adicionar CNAME no Route 53
# 6. Aguardar validação

# Via CLI
aws acm request-certificate \
  --domain-name "*.example.com" \
  --validation-method DNS \
  --region us-east-1

# Obter ARN do certificado
aws acm list-certificates --region us-east-1
```

### 2. Configurar Ingress com ACM

Crie o arquivo `ingress-acm.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test-ingress-acm
  namespace: default
  annotations:
    # ACM Certificate
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-east-1:123456789012:certificate/abc123..."
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
    # Nginx annotations
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
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
            name: nginx-test-service
            port:
              number: 80
```

```bash
# Aplicar
kubectl apply -f ingress-acm.yaml

# Testar
curl https://app.example.com
```

---

## Monitoramento e Logs

### Ver Logs do Ingress Controller

```bash
# Logs em tempo real
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f

# Logs de um pod específico
kubectl logs -n ingress-nginx <pod-name> -f

# Filtrar por host
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep "app.example.com"

# Ver apenas erros
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep -i error
```

### Métricas do Ingress

```bash
# Port-forward para métricas
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller-metrics 10254:10254

# Acessar métricas
curl http://localhost:10254/metrics

# Métricas específicas
curl http://localhost:10254/metrics | grep nginx_ingress_controller_requests
```

### Dashboard do Nginx

```bash
# Port-forward
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80

# Acessar status
curl http://localhost:8080/nginx_status
```

---

## Escalar o Ingress Controller

### Horizontal Pod Autoscaler (HPA)

```bash
# Criar HPA
kubectl autoscale deployment ingress-nginx-controller \
  -n ingress-nginx \
  --cpu-percent=70 \
  --min=2 \
  --max=10

# Verificar
kubectl get hpa -n ingress-nginx

# Ver detalhes
kubectl describe hpa ingress-nginx-controller -n ingress-nginx
```

### Escalar Manualmente

```bash
# Aumentar réplicas
kubectl scale deployment ingress-nginx-controller \
  -n ingress-nginx \
  --replicas=4

# Verificar
kubectl get pods -n ingress-nginx
```

---

## Troubleshooting

### Problema 1: LoadBalancer Fica em Pending

```bash
# Verificar service
kubectl describe svc ingress-nginx-controller -n ingress-nginx

# Ver eventos
kubectl get events -n ingress-nginx --sort-by=.metadata.creationTimestamp

# Verificar IAM permissions
aws iam get-role --role-name <node-role>

# Solução: Verificar se nodes têm permissões para criar ELB
```

### Problema 2: Ingress Retorna 503

```bash
# Verificar endpoints
kubectl get endpoints nginx-test-service

# Verificar pods
kubectl get pods -l app=nginx-test

# Ver logs do Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50

# Testar service diretamente
kubectl run curl-test --rm -it --image=curlimages/curl -- curl http://nginx-test-service
```

### Problema 3: DNS Não Resolve

```bash
# Verificar hostname do NLB
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Testar DNS
nslookup app.example.com
dig app.example.com

# Testar com IP direto
curl -H "Host: app.example.com" http://<nlb-ip>

# Solução: Verificar Route 53 ou /etc/hosts
```

### Problema 4: Certificado TLS Não Funciona

```bash
# Verificar certificate
kubectl get certificate
kubectl describe certificate app-example-com-tls

# Ver challenge
kubectl get challenge

# Logs do cert-manager
kubectl logs -n cert-manager -l app=cert-manager

# Verificar secret
kubectl get secret app-example-com-tls -o yaml

# Solução: Verificar DNS e firewall para porta 80 (HTTP-01 challenge)
```

---

## Atualizar o Ingress Controller

```bash
# Ver versão atual
helm list -n ingress-nginx

# Atualizar repo
helm repo update

# Ver novas versões
helm search repo ingress-nginx

# Atualizar
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --values ingress-nginx-values.yaml

# Verificar
kubectl get pods -n ingress-nginx
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

---

## Desinstalar

```bash
# Deletar Ingresses
kubectl delete ingress --all

# Desinstalar via Helm
helm uninstall ingress-nginx -n ingress-nginx

# Deletar namespace
kubectl delete namespace ingress-nginx

# Verificar LoadBalancer foi deletado
aws elb describe-load-balancers --region us-east-1

# Deletar manualmente se necessário
aws elb delete-load-balancer --load-balancer-name <name>
```

---

## Custos no EKS

### Estimativa Mensal

```
Network Load Balancer:
- $0.0225/hora = ~$16.20/mês
- $0.006/LCU-hora (variável)

Data Transfer:
- Inbound: Gratuito
- Outbound: $0.09/GB (primeiros 10TB)

Pods do Ingress Controller:
- Incluído no custo dos nodes

Total estimado: ~$20-30/mês
```

### Otimização de Custos

```bash
# 1. Usar um único Ingress Controller para múltiplas aplicações
# 2. Configurar idle timeout
# 3. Usar NLB em vez de CLB (mais barato)
# 4. Compartilhar entre namespaces
```

---

## Resumo dos Comandos

```bash
# Instalar
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Verificar
kubectl get all -n ingress-nginx
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Obter URL
kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f

# Atualizar
helm upgrade ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx

# Desinstalar
helm uninstall ingress-nginx -n ingress-nginx
```

---

## Conclusão

O Nginx Ingress Controller no EKS oferece:

✅ **Integração AWS** - NLB automático  
✅ **Alta disponibilidade** - Multi-AZ  
✅ **Escalabilidade** - HPA e múltiplas réplicas  
✅ **SSL/TLS** - Cert-Manager ou ACM  
✅ **Monitoramento** - Métricas e logs  
✅ **Produção-ready** - Configurações otimizadas  

Com o Ingress Controller instalado, você pode expor múltiplas aplicações através de um único LoadBalancer, economizando custos e simplificando o gerenciamento!
