# Instalando o Ingress Nginx Controller

## Introdução

O **Nginx Ingress Controller** é a implementação mais popular de Ingress Controller para Kubernetes. Ele usa o Nginx como proxy reverso e load balancer para rotear tráfego HTTP/HTTPS para os Services do cluster.

## O que é o Nginx Ingress Controller?

### Conceito

É um componente que:
- Monitora recursos Ingress no cluster
- Configura dinamicamente o Nginx baseado nas regras
- Expõe Services através de um único ponto de entrada
- Gerencia SSL/TLS, roteamento, balanceamento de carga

### Componentes

- **Nginx:** Proxy reverso e load balancer
- **Controller:** Lógica que lê Ingress e configura Nginx
- **LoadBalancer Service:** Expõe o controller externamente
- **ConfigMaps:** Configurações globais do Nginx

## Fluxo de Funcionamento

```
1. Instalar Nginx Ingress Controller
   ↓
2. Controller cria Deployment + Service (LoadBalancer)
   ↓
3. Controller monitora recursos Ingress
   ↓
4. Quando Ingress é criado, controller atualiza Nginx
   ↓
5. Nginx roteia tráfego baseado nas regras
   ↓
6. Tráfego chega aos Services corretos
```

## Métodos de Instalação

### Comparação

| Método | Vantagens | Desvantagens |
|--------|-----------|--------------|
| **Helm** | Fácil, customizável, gerenciável | Requer Helm instalado |
| **Manifesto YAML** | Simples, sem dependências | Menos flexível |
| **Operator** | Automação avançada | Mais complexo |

## Método 1: Instalação via Helm (Recomendado)

### 1. Instalar Helm

```bash
# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# macOS
brew install helm

# Verificar instalação
helm version
```

**Saída esperada:**
```
version.BuildInfo{Version:"v3.14.0", GitCommit:"...", GitTreeState:"clean", GoVersion:"go1.21.5"}
```

### 2. Adicionar Repositório Helm

```bash
# Adicionar repositório do Nginx Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Atualizar repositórios
helm repo update
```

**Saída esperada:**
```
"ingress-nginx" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "ingress-nginx" chart repository
```

### 3. Instalar Nginx Ingress Controller

```bash
# Instalação básica
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

**Saída esperada:**
```
NAME: ingress-nginx
LAST DEPLOYED: Wed Mar 11 11:35:00 2026
NAMESPACE: ingress-nginx
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The ingress-nginx controller has been installed.
```

### 4. Verificar Instalação

```bash
# Ver recursos criados
kubectl get all -n ingress-nginx

# Ver Pods
kubectl get pods -n ingress-nginx

# Ver Services
kubectl get service -n ingress-nginx
```

**Saída esperada:**
```
NAME                                            READY   STATUS    RESTARTS   AGE
pod/ingress-nginx-controller-xxxxx              1/1     Running   0          2m

NAME                                         TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
service/ingress-nginx-controller             LoadBalancer   10.96.100.50    203.0.113.10    80:30080/TCP,443:30443/TCP
service/ingress-nginx-controller-admission   ClusterIP      10.96.100.51    <none>          443/TCP
```

### 5. Aguardar Controller Ficar Pronto

```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

**Saída esperada:**
```
pod/ingress-nginx-controller-xxxxx condition met
```

### 6. Obter IP Externo

```bash
kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Saída esperada:**
```
203.0.113.10
```

## Método 2: Instalação via Manifesto YAML

### Para Provedores de Nuvem (AWS, GCP, Azure)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
```

**Saída esperada:**
```
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
serviceaccount/ingress-nginx-admission created
role.rbac.authorization.k8s.io/ingress-nginx created
...
deployment.apps/ingress-nginx-controller created
```

### Para Kind

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

### Para Bare Metal

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/baremetal/deploy.yaml
```

### Verificar Instalação

```bash
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx
```

## Método 3: Instalação Customizada com Helm

### 1. Criar Arquivo de Valores

```yaml
# ingress-values.yaml
controller:
  # Número de réplicas
  replicaCount: 2
  
  # Recursos
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  # Service
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  
  # Configurações do Nginx
  config:
    use-forwarded-headers: "true"
    compute-full-forwarded-for: "true"
    proxy-body-size: "50m"
    client-max-body-size: "50m"
  
  # Métricas
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
  
  # Logs
  admissionWebhooks:
    enabled: true

# Default backend (opcional)
defaultBackend:
  enabled: true
  replicaCount: 1
```

### 2. Instalar com Valores Customizados

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values ingress-values.yaml
```

**Saída esperada:**
```
NAME: ingress-nginx
NAMESPACE: ingress-nginx
STATUS: deployed
```

### 3. Verificar Configuração

```bash
# Ver valores aplicados
helm get values ingress-nginx -n ingress-nginx

# Ver todas as configurações
helm get values ingress-nginx -n ingress-nginx --all
```

## Instalação por Provedor

### AWS (EKS)

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true"
```

### GCP (GKE)

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### Azure (AKS)

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"="/healthz"
```

### Bare Metal (NodePort)

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443
```

## Exemplo Prático 1: Testar Instalação

### 1. Criar Aplicação de Teste

```yaml
# test-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  labels:
    app: test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:1.0
        args:
        - "-text=Nginx Ingress Controller is working!"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  selector:
    app: test
  ports:
  - port: 80
    targetPort: 5678
```

```bash
kubectl apply -f test-app.yaml
```

**Saída esperada:**
```
deployment.apps/test-app created
service/test-service created
```

### 2. Criar Ingress

```yaml
# test-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
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
            name: test-service
            port:
              number: 80
```

```bash
kubectl apply -f test-ingress.yaml
```

**Saída esperada:**
```
ingress.networking.k8s.io/test-ingress created
```

### 3. Obter IP do Ingress

```bash
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

### 4. Testar

```bash
# Testar com curl
curl -H "Host: test.example.com" http://$INGRESS_IP

# Ou adicionar ao /etc/hosts
echo "$INGRESS_IP test.example.com" | sudo tee -a /etc/hosts
curl http://test.example.com
```

**Saída esperada:**
```
Nginx Ingress Controller is working!
```

## Exemplo Prático 2: Configuração Avançada

### ConfigMap Global

```yaml
# nginx-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  # Tamanho máximo do body
  proxy-body-size: "100m"
  
  # Timeouts
  proxy-connect-timeout: "60"
  proxy-send-timeout: "60"
  proxy-read-timeout: "60"
  
  # Headers
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
  
  # SSL
  ssl-protocols: "TLSv1.2 TLSv1.3"
  ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
  
  # Logs
  log-format-upstream: '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_length $request_time [$proxy_upstream_name] [$proxy_alternative_upstream_name] $upstream_addr $upstream_response_length $upstream_response_time $upstream_status $req_id'
```

```bash
kubectl apply -f nginx-config.yaml
```

### Atualizar Helm com ConfigMap

```bash
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.config.proxy-body-size="100m" \
  --set controller.config.proxy-connect-timeout="60"
```

## Verificação e Monitoramento

### Verificar Status

```bash
# Status do Helm release
helm status ingress-nginx -n ingress-nginx

# Pods
kubectl get pods -n ingress-nginx -w

# Services
kubectl get service -n ingress-nginx

# Ingress Class
kubectl get ingressclass
```

**Saída esperada (IngressClass):**
```
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       5m
```

### Ver Logs

```bash
# Logs do controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Logs em tempo real
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f

# Logs de um Pod específico
kubectl logs -n ingress-nginx <pod-name>
```

### Ver Configuração do Nginx

```bash
# Entrar no Pod
kubectl exec -n ingress-nginx -it <pod-name> -- bash

# Ver nginx.conf
kubectl exec -n ingress-nginx <pod-name> -- cat /etc/nginx/nginx.conf

# Testar configuração
kubectl exec -n ingress-nginx <pod-name> -- nginx -t
```

### Métricas

```bash
# Expor métricas
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 10254:10254

# Acessar métricas
curl http://localhost:10254/metrics
```

## Atualização

### Atualizar via Helm

```bash
# Atualizar repositório
helm repo update

# Ver versões disponíveis
helm search repo ingress-nginx --versions

# Atualizar para versão específica
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --version 4.10.0

# Atualizar para última versão
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx
```

**Saída esperada:**
```
Release "ingress-nginx" has been upgraded. Happy Helming!
```

### Atualizar via Manifesto

```bash
# Aplicar nova versão
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
```

### Verificar Atualização

```bash
# Ver versão atual
kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.containers[0].image}'

# Ver histórico
helm history ingress-nginx -n ingress-nginx
```

## Desinstalação

### Desinstalar via Helm

```bash
# Desinstalar release
helm uninstall ingress-nginx -n ingress-nginx

# Deletar namespace
kubectl delete namespace ingress-nginx
```

**Saída esperada:**
```
release "ingress-nginx" uninstalled
namespace "ingress-nginx" deleted
```

### Desinstalar via Manifesto

```bash
# Deletar recursos
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

# Deletar namespace
kubectl delete namespace ingress-nginx
```

## Troubleshooting

### Controller não Inicia

```bash
# Ver eventos
kubectl describe pod -n ingress-nginx <pod-name>

# Ver logs
kubectl logs -n ingress-nginx <pod-name>

# Verificar recursos
kubectl top pod -n ingress-nginx
```

### LoadBalancer Pending

```bash
# Verificar Service
kubectl describe service -n ingress-nginx ingress-nginx-controller

# Ver eventos
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'

# Para Kind/Minikube, usar NodePort
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=NodePort
```

### Ingress não Funciona

```bash
# Verificar IngressClass
kubectl get ingressclass

# Verificar Ingress
kubectl describe ingress <name>

# Ver logs do controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep <ingress-name>

# Verificar configuração do Nginx
kubectl exec -n ingress-nginx <pod-name> -- nginx -t
```

### Erro de Certificado

```bash
# Verificar admission webhook
kubectl get validatingwebhookconfigurations

# Deletar webhook se necessário
kubectl delete validatingwebhookconfigurations ingress-nginx-admission

# Reinstalar
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.admissionWebhooks.enabled=true
```

## Comandos Úteis

### Helm

```bash
# Listar releases
helm list -n ingress-nginx

# Ver valores padrão
helm show values ingress-nginx/ingress-nginx

# Ver valores aplicados
helm get values ingress-nginx -n ingress-nginx

# Rollback
helm rollback ingress-nginx -n ingress-nginx
```

### Kubectl

```bash
# Ver todos os recursos
kubectl get all -n ingress-nginx

# Descrever deployment
kubectl describe deployment -n ingress-nginx ingress-nginx-controller

# Escalar controller
kubectl scale deployment -n ingress-nginx ingress-nginx-controller --replicas=3

# Reiniciar controller
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
```

## Boas Práticas

### 1. Use Helm para Gerenciamento

```bash
# ✅ Recomendado
helm install ingress-nginx ingress-nginx/ingress-nginx

# ❌ Evite manifesto direto em produção
kubectl apply -f deploy.yaml
```

### 2. Configure Recursos

```yaml
controller:
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
```

### 3. Habilite Métricas

```yaml
controller:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
```

### 4. Configure Réplicas

```yaml
controller:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
```

### 5. Use Namespace Dedicado

```bash
# Sempre use namespace separado
--namespace ingress-nginx --create-namespace
```

### 6. Documente Configurações

```yaml
# Mantenha arquivo de valores versionado
# ingress-values-prod.yaml
controller:
  replicaCount: 3
  # ... outras configurações
```

## Resumo

- **Nginx Ingress Controller** é a implementação mais popular
- **Helm é o método recomendado** de instalação
- **Namespace dedicado** (ingress-nginx) para organização
- **LoadBalancer Service** expõe o controller externamente
- **IngressClass** identifica qual controller usar
- **ConfigMap** para configurações globais do Nginx
- **Métricas e logs** para monitoramento
- **Customização** via Helm values ou annotations

## Próximos Passos

- Configurar **SSL/TLS** com Cert-Manager
- Implementar **rate limiting** e **WAF**
- Configurar **autenticação** (Basic Auth, OAuth)
- Habilitar **monitoramento** com Prometheus
- Explorar **annotations** avançadas
- Configurar **default backend** customizado
