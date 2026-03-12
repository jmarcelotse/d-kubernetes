# Criando os Nossos Services LoadBalancer e ExternalName

## Introdução

Além dos tipos ClusterIP e NodePort, o Kubernetes oferece outros dois tipos importantes de Services: **LoadBalancer** e **ExternalName**. Cada um atende necessidades específicas de exposição e integração de aplicações.

## Service LoadBalancer

### O que é?

O Service do tipo **LoadBalancer** provisiona automaticamente um balanceador de carga externo (fornecido pelo provedor de nuvem) e expõe a aplicação para a internet ou rede externa.

### Características

- Cria automaticamente um balanceador de carga externo (AWS ELB, GCP Load Balancer, Azure Load Balancer)
- Atribui um IP público externo
- Distribui tráfego entre os Pods
- Funciona apenas em ambientes de nuvem que suportam provisionamento de Load Balancers
- Herda funcionalidades do NodePort (cria NodePort automaticamente)

### Quando Usar?

- Expor aplicações para internet
- Ambientes de produção em nuvem
- Necessidade de alta disponibilidade com balanceamento de carga gerenciado
- Aplicações que precisam de IP público estável

### Fluxo de Funcionamento

```
Internet/Cliente Externo
         ↓
   Load Balancer (IP Público)
         ↓
    NodePort (gerado automaticamente)
         ↓
    ClusterIP (Service)
         ↓
      Pods (Endpoints)
```

## Service ExternalName

### O que é?

O Service do tipo **ExternalName** mapeia um Service para um nome DNS externo, permitindo que aplicações dentro do cluster acessem recursos externos usando nomes internos do Kubernetes.

### Características

- Não cria proxy ou encaminhamento de porta
- Retorna um registro CNAME para o DNS externo
- Não possui ClusterIP
- Não possui seletores (não aponta para Pods)
- Útil para integração com serviços externos

### Quando Usar?

- Acessar bancos de dados externos (RDS, Cloud SQL)
- Integrar com APIs externas
- Migração gradual de serviços (abstração de localização)
- Ambientes híbridos (on-premise + cloud)

### Fluxo de Funcionamento

```
Pod no Cluster
     ↓
Service ExternalName (CNAME)
     ↓
DNS Externo
     ↓
Serviço Externo (database.example.com)
```

## Exemplo Prático 1: Service LoadBalancer

### Cenário

Vamos expor uma aplicação Nginx para internet usando LoadBalancer.

### 1. Criar Deployment Nginx

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-lb
  labels:
    app: nginx-lb
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-lb
  template:
    metadata:
      labels:
        app: nginx-lb
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
```

Aplicar o Deployment:

```bash
kubectl apply -f nginx-deployment-lb.yaml
```

**Saída esperada:**
```
deployment.apps/nginx-lb created
```

### 2. Criar Service LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb-service
spec:
  type: LoadBalancer
  selector:
    app: nginx-lb
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

Aplicar o Service:

```bash
kubectl apply -f nginx-service-lb.yaml
```

**Saída esperada:**
```
service/nginx-lb-service created
```

### 3. Verificar o Service

```bash
kubectl get service nginx-lb-service
```

**Saída esperada (em nuvem):**
```
NAME                TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)        AGE
nginx-lb-service    LoadBalancer   10.96.150.23    a1b2c3d4e5f6g7h8.us-east-1.elb.amazonaws.com                           80:32456/TCP   2m
```

**Saída esperada (Kind/Minikube - sem suporte):**
```
NAME                TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx-lb-service    LoadBalancer   10.96.150.23    <pending>     80:32456/TCP   2m
```

### 4. Detalhes do Service

```bash
kubectl describe service nginx-lb-service
```

**Saída esperada:**
```
Name:                     nginx-lb-service
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 app=nginx-lb
Type:                     LoadBalancer
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.150.23
IPs:                      10.96.150.23
LoadBalancer Ingress:     a1b2c3d4e5f6g7h8.us-east-1.elb.amazonaws.com
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
NodePort:                 <unset>  32456/TCP
Endpoints:                10.244.1.5:80,10.244.2.3:80,10.244.3.7:80
Session Affinity:         None
External Traffic Policy:  Cluster
Events:
  Type    Reason                Age   From                Message
  ----    ------                ----  ----                -------
  Normal  EnsuringLoadBalancer  2m    service-controller  Ensuring load balancer
  Normal  EnsuredLoadBalancer   1m    service-controller  Ensured load balancer
```

### 5. Testar Acesso (em ambiente cloud)

```bash
# Obter o EXTERNAL-IP
EXTERNAL_IP=$(kubectl get service nginx-lb-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Testar acesso
curl http://$EXTERNAL_IP
```

**Saída esperada:**
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

### 6. Testando em Kind (usando MetalLB)

Para testar LoadBalancer localmente, instale o MetalLB:

```bash
# Instalar MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml

# Aguardar pods ficarem prontos
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```

Criar configuração de IP pool:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
```

```bash
kubectl apply -f metallb-config.yaml
```

Agora o Service LoadBalancer receberá um IP externo do pool configurado.

## Exemplo Prático 2: Service ExternalName

### Cenário

Vamos criar um Service que aponta para um banco de dados RDS externo, permitindo que os Pods acessem usando um nome interno.

### 1. Criar Service ExternalName

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-external
  namespace: default
spec:
  type: ExternalName
  externalName: mydb.c9akciq32.us-east-1.rds.amazonaws.com
```

Aplicar o Service:

```bash
kubectl apply -f mysql-external-service.yaml
```

**Saída esperada:**
```
service/mysql-external created
```

### 2. Verificar o Service

```bash
kubectl get service mysql-external
```

**Saída esperada:**
```
NAME             TYPE           CLUSTER-IP   EXTERNAL-IP                                      PORT(S)   AGE
mysql-external   ExternalName   <none>       mydb.c9akciq32.us-east-1.rds.amazonaws.com      <none>    10s
```

### 3. Detalhes do Service

```bash
kubectl describe service mysql-external
```

**Saída esperada:**
```
Name:              mysql-external
Namespace:         default
Labels:            <none>
Annotations:       <none>
Selector:          <none>
Type:              ExternalName
IP Families:       <none>
IP:                
IPs:               <none>
External Name:     mydb.c9akciq32.us-east-1.rds.amazonaws.com
Session Affinity:  None
Events:            <none>
```

### 4. Testar Resolução DNS

Criar um Pod de teste:

```bash
kubectl run test-dns --image=busybox:1.36 --rm -it --restart=Never -- sh
```

Dentro do Pod, testar a resolução DNS:

```bash
nslookup mysql-external
```

**Saída esperada:**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      mysql-external
Address 1: mydb.c9akciq32.us-east-1.rds.amazonaws.com
```

### 5. Usar em Aplicação

Exemplo de Pod que conecta ao banco usando o Service:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-mysql
spec:
  containers:
  - name: app
    image: mysql:8.0
    env:
    - name: MYSQL_HOST
      value: "mysql-external"
    - name: MYSQL_PORT
      value: "3306"
    - name: MYSQL_USER
      valueFrom:
        secretKeyRef:
          name: mysql-credentials
          key: username
    - name: MYSQL_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysql-credentials
          key: password
    command:
    - sh
    - -c
    - |
      mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1"
```

## Exemplo Prático 3: ExternalName para API Externa

### Cenário

Integrar com uma API externa (exemplo: api.github.com).

### 1. Criar Service ExternalName

```yaml
apiVersion: v1
kind: Service
metadata:
  name: github-api
spec:
  type: ExternalName
  externalName: api.github.com
  ports:
  - port: 443
    protocol: TCP
```

```bash
kubectl apply -f github-api-service.yaml
```

### 2. Testar Acesso

```bash
kubectl run curl-test --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- sh
```

Dentro do Pod:

```bash
curl -k https://github-api/users/octocat
```

**Saída esperada:**
```json
{
  "login": "octocat",
  "id": 583231,
  "node_id": "MDQ6VXNlcjU4MzIzMQ==",
  "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4",
  ...
}
```

## Exemplo Prático 4: LoadBalancer com Anotações AWS

### Service com Configurações Específicas AWS

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb-advanced
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-east-1:123456789012:certificate/abc123"
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
spec:
  type: LoadBalancer
  selector:
    app: nginx-lb
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  - name: https
    protocol: TCP
    port: 443
    targetPort: 80
```

### Anotações Comuns AWS

| Anotação | Descrição |
|----------|-----------|
| `aws-load-balancer-type` | Tipo de LB: `nlb` (Network) ou `elb` (Classic) |
| `aws-load-balancer-internal` | `"true"` para LB interno |
| `aws-load-balancer-cross-zone-load-balancing-enabled` | Balanceamento entre zonas |
| `aws-load-balancer-ssl-cert` | ARN do certificado SSL |
| `aws-load-balancer-backend-protocol` | Protocolo backend: `http`, `https`, `tcp` |

## Comparação dos Tipos de Service

| Característica | ClusterIP | NodePort | LoadBalancer | ExternalName |
|----------------|-----------|----------|--------------|--------------|
| **Acesso Interno** | ✅ | ✅ | ✅ | ✅ |
| **Acesso Externo** | ❌ | ✅ (IP:Porta) | ✅ (IP Público) | ❌ |
| **IP do Cluster** | ✅ | ✅ | ✅ | ❌ |
| **Seletor de Pods** | ✅ | ✅ | ✅ | ❌ |
| **Balanceamento** | ✅ | ✅ | ✅ | ❌ |
| **Custo** | Gratuito | Gratuito | Pago (Cloud) | Gratuito |
| **Uso Principal** | Interno | Dev/Test | Produção | Integração Externa |

## Comandos Úteis

### Listar Services por Tipo

```bash
# Todos os Services
kubectl get services

# Apenas LoadBalancer
kubectl get services --field-selector spec.type=LoadBalancer

# Apenas ExternalName
kubectl get services --field-selector spec.type=ExternalName
```

### Obter EXTERNAL-IP do LoadBalancer

```bash
# Hostname (AWS)
kubectl get service nginx-lb-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# IP (GCP/Azure)
kubectl get service nginx-lb-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Verificar Endpoints

```bash
kubectl get endpoints nginx-lb-service
```

### Logs de Eventos do Service

```bash
kubectl get events --field-selector involvedObject.name=nginx-lb-service
```

## Troubleshooting

### LoadBalancer com EXTERNAL-IP <pending>

**Problema:** Service LoadBalancer fica com `<pending>` no EXTERNAL-IP.

**Causas:**
- Cluster local (Kind, Minikube) sem suporte a LoadBalancer
- Provedor de nuvem não configurado corretamente
- Quotas de Load Balancer atingidas

**Solução:**
```bash
# Verificar eventos
kubectl describe service nginx-lb-service

# Para ambientes locais, usar MetalLB ou NodePort
kubectl patch service nginx-lb-service -p '{"spec":{"type":"NodePort"}}'
```

### ExternalName não resolve DNS

**Problema:** Pods não conseguem resolver o ExternalName.

**Causas:**
- DNS externo não acessível do cluster
- CoreDNS não configurado corretamente
- Firewall bloqueando DNS

**Solução:**
```bash
# Testar DNS do cluster
kubectl run test-dns --image=busybox:1.36 --rm -it --restart=Never -- nslookup kubernetes.default

# Verificar logs do CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns

# Testar resolução externa
kubectl run test-external --image=busybox:1.36 --rm -it --restart=Never -- nslookup google.com
```

### LoadBalancer não distribui tráfego

**Problema:** Tráfego não chega aos Pods.

**Verificações:**
```bash
# Verificar Endpoints
kubectl get endpoints nginx-lb-service

# Verificar Pods
kubectl get pods -l app=nginx-lb

# Verificar Health Checks
kubectl describe service nginx-lb-service | grep -A 5 "Health"

# Testar conectividade direta ao Pod
kubectl port-forward pod/nginx-lb-xxx 8080:80
curl localhost:8080
```

## Limpeza dos Recursos

```bash
# Remover Services
kubectl delete service nginx-lb-service
kubectl delete service mysql-external
kubectl delete service github-api

# Remover Deployments
kubectl delete deployment nginx-lb

# Remover MetalLB (se instalado)
kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
```

## Boas Práticas

### LoadBalancer

1. **Custos:** Cada LoadBalancer gera custo no provedor de nuvem
2. **Consolidação:** Use Ingress para expor múltiplos serviços com um único LoadBalancer
3. **Health Checks:** Configure readiness probes para health checks corretos
4. **Anotações:** Use anotações específicas do provedor para otimizações
5. **Segurança:** Configure Security Groups/Firewalls adequadamente

### ExternalName

1. **DNS Válido:** Certifique-se que o DNS externo é acessível
2. **Abstração:** Use para facilitar migração de serviços
3. **Documentação:** Documente dependências externas
4. **Monitoramento:** Monitore disponibilidade do serviço externo
5. **Secrets:** Não exponha credenciais no externalName

## Resumo

- **LoadBalancer:** Expõe aplicações para internet com IP público gerenciado pelo provedor de nuvem
- **ExternalName:** Mapeia Services internos para DNS externos, facilitando integração
- **LoadBalancer** é ideal para produção em nuvem com alta disponibilidade
- **ExternalName** é útil para abstrair serviços externos e facilitar migrações
- Ambos têm casos de uso específicos e complementam os tipos ClusterIP e NodePort
- Em ambientes locais, use MetalLB para simular LoadBalancer
- ExternalName não cria proxy, apenas retorna CNAME DNS

## Próximos Passos

- Estudar **Ingress Controllers** para gerenciar múltiplos Services com um único LoadBalancer
- Explorar **Service Mesh** (Istio, Linkerd) para controle avançado de tráfego
- Implementar **Network Policies** para segurança de rede
- Configurar **External DNS** para automação de registros DNS
