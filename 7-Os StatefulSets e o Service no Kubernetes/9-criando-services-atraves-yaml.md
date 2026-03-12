# Criando os Services Através de YAML

## Introdução

A criação de Services através de arquivos YAML é a forma **declarativa** e recomendada para ambientes de produção. Este método oferece versionamento, reprodutibilidade e facilita a automação via CI/CD.

## Por Que Usar YAML?

### Vantagens

- **Versionamento:** Controle de versão com Git
- **Reprodutibilidade:** Mesmo resultado em qualquer ambiente
- **Documentação:** Código como documentação
- **Automação:** Integração com pipelines CI/CD
- **Revisão:** Code review antes de aplicar
- **Rollback:** Fácil reverter mudanças

### Comparação: Imperativo vs Declarativo

| Aspecto | Imperativo (kubectl create) | Declarativo (YAML) |
|---------|----------------------------|-------------------|
| **Comando** | `kubectl create service` | `kubectl apply -f` |
| **Versionamento** | ❌ Difícil | ✅ Git |
| **Reprodução** | ❌ Manual | ✅ Automática |
| **Modificação** | ❌ Recriar | ✅ Atualizar |
| **Auditoria** | ❌ Limitada | ✅ Completa |
| **Produção** | ❌ Não recomendado | ✅ Recomendado |

## Estrutura Básica de um Service YAML

```yaml
apiVersion: v1                    # Versão da API
kind: Service                     # Tipo do recurso
metadata:                         # Metadados
  name: my-service               # Nome do Service
  namespace: default             # Namespace (opcional)
  labels:                        # Labels (opcional)
    app: myapp
  annotations:                   # Anotações (opcional)
    description: "My service"
spec:                            # Especificação
  type: ClusterIP                # Tipo do Service
  selector:                      # Seletor de Pods
    app: myapp
  ports:                         # Portas
  - protocol: TCP
    port: 80                     # Porta do Service
    targetPort: 8080             # Porta do Pod
```

## Campos Principais

### metadata

```yaml
metadata:
  name: my-service              # Obrigatório: nome único no namespace
  namespace: production         # Opcional: default se omitido
  labels:                       # Opcional: para organização
    app: myapp
    tier: backend
    environment: prod
  annotations:                  # Opcional: metadados não identificadores
    description: "Backend API service"
    owner: "platform-team"
    version: "1.0.0"
```

### spec.type

```yaml
spec:
  type: ClusterIP    # Padrão: acesso interno
  # type: NodePort   # Expõe em porta do Node
  # type: LoadBalancer  # Provisiona Load Balancer externo
  # type: ExternalName  # CNAME para DNS externo
```

### spec.selector

```yaml
spec:
  selector:          # Seleciona Pods com estas labels
    app: myapp
    version: v1
```

### spec.ports

```yaml
spec:
  ports:
  - name: http              # Opcional: nome da porta
    protocol: TCP           # TCP (padrão) ou UDP
    port: 80                # Porta do Service (obrigatório)
    targetPort: 8080        # Porta do container (obrigatório)
    nodePort: 30080         # Porta do Node (apenas NodePort/LoadBalancer)
```

## Exemplo 1: Service ClusterIP Básico

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
```

### Service ClusterIP

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  labels:
    app: webapp
spec:
  type: ClusterIP
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

### Aplicar

```bash
# Salvar em arquivo
cat > webapp.yaml << 'EOF'
# Cole o conteúdo acima
EOF

# Aplicar
kubectl apply -f webapp.yaml
```

**Saída esperada:**
```
deployment.apps/webapp created
service/webapp-service created
```

### Verificar

```bash
kubectl get service webapp-service
```

**Saída esperada:**
```
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
webapp-service   ClusterIP   10.96.100.50    <none>        80/TCP    30s
```

### Testar

```bash
kubectl run test --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://webapp-service
```

## Exemplo 2: Service NodePort

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-nodeport
  labels:
    app: webapp
    type: nodeport
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080    # Porta específica (30000-32767)
```

### Aplicar

```bash
kubectl apply -f webapp-nodeport.yaml
```

**Saída esperada:**
```
service/webapp-nodeport created
```

### Verificar

```bash
kubectl get service webapp-nodeport
```

**Saída esperada:**
```
NAME              TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
webapp-nodeport   NodePort   10.96.150.100   <none>        80:30080/TCP   20s
```

### Testar

```bash
# Obter IP do Node
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Testar acesso
curl http://$NODE_IP:30080
```

## Exemplo 3: Service LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-lb
  labels:
    app: webapp
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: webapp
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

### Aplicar

```bash
kubectl apply -f webapp-lb.yaml
```

**Saída esperada:**
```
service/webapp-lb created
```

### Verificar

```bash
kubectl get service webapp-lb -w
```

**Saída esperada:**
```
NAME        TYPE           CLUSTER-IP     EXTERNAL-IP                                                              PORT(S)                      AGE
webapp-lb   LoadBalancer   10.96.200.50   <pending>                                                                80:31234/TCP,443:31235/TCP   5s
webapp-lb   LoadBalancer   10.96.200.50   a1b2c3d4.us-east-1.elb.amazonaws.com                                    80:31234/TCP,443:31235/TCP   45s
```

## Exemplo 4: Service ExternalName

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-database
  namespace: default
spec:
  type: ExternalName
  externalName: mydb.c9akciq32.us-east-1.rds.amazonaws.com
  ports:
  - port: 3306
    protocol: TCP
```

### Aplicar

```bash
kubectl apply -f external-db.yaml
```

**Saída esperada:**
```
service/external-database created
```

### Verificar

```bash
kubectl get service external-database
```

**Saída esperada:**
```
NAME                TYPE           CLUSTER-IP   EXTERNAL-IP                                      PORT(S)    AGE
external-database   ExternalName   <none>       mydb.c9akciq32.us-east-1.rds.amazonaws.com      3306/TCP   10s
```

## Exemplo 5: Service com Múltiplas Portas

```yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-port-service
spec:
  selector:
    app: myapp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
  - name: https
    protocol: TCP
    port: 443
    targetPort: 8443
  - name: metrics
    protocol: TCP
    port: 9090
    targetPort: 9090
```

### Aplicar

```bash
kubectl apply -f multi-port-service.yaml
```

### Verificar

```bash
kubectl describe service multi-port-service
```

**Saída esperada:**
```
Name:              multi-port-service
Namespace:         default
Selector:          app=myapp
Type:              ClusterIP
IP:                10.96.150.200
Port:              http  80/TCP
TargetPort:        8080/TCP
Port:              https  443/TCP
TargetPort:        8443/TCP
Port:              metrics  9090/TCP
TargetPort:        9090/TCP
Endpoints:         <none>
```

## Exemplo 6: Service Headless (StatefulSet)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  clusterIP: None    # Headless Service
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
```

### Aplicar

```bash
kubectl apply -f mysql-headless.yaml
```

### Verificar

```bash
kubectl get service mysql-headless
```

**Saída esperada:**
```
NAME             TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
mysql-headless   ClusterIP   None         <none>        3306/TCP   15s
```

## Exemplo 7: Service com SessionAffinity

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sticky-service
spec:
  selector:
    app: webapp
  sessionAffinity: ClientIP    # Mantém cliente no mesmo Pod
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600     # 1 hora
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

### Aplicar

```bash
kubectl apply -f sticky-service.yaml
```

### Verificar

```bash
kubectl describe service sticky-service | grep -A 3 "Session Affinity"
```

**Saída esperada:**
```
Session Affinity:         ClientIP
Session Affinity Config:  ClientIP:
                           TimeoutSeconds: 3600
```

## Exemplo 8: Service sem Selector (Endpoints Manuais)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9376
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-service    # Mesmo nome do Service
subsets:
- addresses:
  - ip: 192.168.1.100
  - ip: 192.168.1.101
  ports:
  - port: 9376
```

### Aplicar

```bash
kubectl apply -f external-service.yaml
```

### Verificar

```bash
kubectl get endpoints external-service
```

**Saída esperada:**
```
NAME               ENDPOINTS                         AGE
external-service   192.168.1.100:9376,192.168.1.101:9376   20s
```

## Exemplo 9: Service com Anotações AWS

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-aws-lb
  annotations:
    # Tipo de Load Balancer
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    
    # Load Balancer interno
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    
    # Cross-zone load balancing
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    
    # Certificado SSL
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-east-1:123456789012:certificate/abc123"
    
    # Portas SSL
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    
    # Backend protocol
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
    
    # Health check
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "30"
    
    # Subnets
    service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-abc123,subnet-def456"
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8080
```

## Exemplo 10: Service Completo com Todas as Opções

```yaml
apiVersion: v1
kind: Service
metadata:
  name: complete-service
  namespace: production
  labels:
    app: myapp
    tier: backend
    environment: prod
  annotations:
    description: "Complete service example"
    owner: "platform-team"
    version: "2.0.0"
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
spec:
  type: LoadBalancer
  
  # Seletor de Pods
  selector:
    app: myapp
    version: v2
  
  # Portas
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: http-port
    nodePort: 30080
  - name: https
    protocol: TCP
    port: 443
    targetPort: 8443
  - name: metrics
    protocol: TCP
    port: 9090
    targetPort: 9090
  
  # Session Affinity
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
  
  # IP do Cluster (opcional, geralmente auto-atribuído)
  # clusterIP: 10.96.100.100
  
  # IPs externos adicionais
  externalIPs:
  - 192.168.1.50
  
  # Traffic Policy
  externalTrafficPolicy: Local
  
  # Health check node port
  healthCheckNodePort: 30081
  
  # IP Families
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  
  # Load Balancer IP (se suportado)
  # loadBalancerIP: 203.0.113.100
  
  # Source ranges permitidos
  loadBalancerSourceRanges:
  - 10.0.0.0/8
  - 172.16.0.0/12
  
  # Publish not ready addresses
  publishNotReadyAddresses: false
```

## Organizando Services em Arquivos

### Opção 1: Um Arquivo por Recurso

```bash
# Estrutura de diretórios
app/
├── deployment.yaml
├── service-clusterip.yaml
├── service-nodeport.yaml
└── configmap.yaml

# Aplicar todos
kubectl apply -f app/
```

### Opção 2: Múltiplos Recursos em Um Arquivo

```yaml
# app-complete.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  # ... deployment spec
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  # ... service spec
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
data:
  # ... config data
```

```bash
kubectl apply -f app-complete.yaml
```

### Opção 3: Kustomize

```bash
# Estrutura
base/
├── kustomization.yaml
├── deployment.yaml
└── service.yaml

overlays/
├── dev/
│   └── kustomization.yaml
└── prod/
    └── kustomization.yaml
```

**base/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

commonLabels:
  app: myapp
```

**overlays/prod/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

namePrefix: prod-

replicas:
- name: myapp
  count: 5

patches:
- target:
    kind: Service
    name: myapp-service
  patch: |-
    - op: replace
      path: /spec/type
      value: LoadBalancer
```

```bash
# Aplicar com Kustomize
kubectl apply -k overlays/prod/
```

## Comandos Úteis

### Criar YAML a partir de Recurso Existente

```bash
# Exportar Service existente
kubectl get service webapp-service -o yaml > webapp-service.yaml

# Limpar campos desnecessários
kubectl get service webapp-service -o yaml --export > webapp-service-clean.yaml
```

### Dry-run para Gerar YAML

```bash
# Gerar YAML sem criar recurso
kubectl create service clusterip my-service --tcp=80:8080 --dry-run=client -o yaml

# Salvar em arquivo
kubectl create service clusterip my-service --tcp=80:8080 --dry-run=client -o yaml > my-service.yaml
```

### Validar YAML

```bash
# Validar sintaxe
kubectl apply -f service.yaml --dry-run=client

# Validar no servidor (sem aplicar)
kubectl apply -f service.yaml --dry-run=server

# Validar com diff
kubectl diff -f service.yaml
```

### Aplicar e Atualizar

```bash
# Aplicar (cria ou atualiza)
kubectl apply -f service.yaml

# Aplicar múltiplos arquivos
kubectl apply -f service1.yaml -f service2.yaml

# Aplicar diretório
kubectl apply -f ./services/

# Aplicar recursivamente
kubectl apply -f ./app/ -R
```

### Visualizar YAML Aplicado

```bash
# Ver configuração atual
kubectl get service my-service -o yaml

# Ver apenas spec
kubectl get service my-service -o jsonpath='{.spec}'

# Ver em formato JSON
kubectl get service my-service -o json
```

## Boas Práticas

### 1. Versionamento

```yaml
metadata:
  name: myapp-service
  labels:
    version: "1.0.0"
  annotations:
    kubernetes.io/change-cause: "Update to version 1.0.0"
```

### 2. Documentação

```yaml
metadata:
  annotations:
    description: "Backend API service for user management"
    owner: "backend-team@example.com"
    documentation: "https://wiki.example.com/services/myapp"
    runbook: "https://runbook.example.com/myapp"
```

### 3. Labels Consistentes

```yaml
metadata:
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ecommerce
    app.kubernetes.io/managed-by: helm
```

### 4. Naming Convention

```yaml
# Padrão: <app>-<type>-<environment>
metadata:
  name: user-api-service-prod
  namespace: production
```

### 5. Separação de Ambientes

```bash
# Estrutura de diretórios
k8s/
├── base/
│   ├── deployment.yaml
│   └── service.yaml
├── dev/
│   └── service-dev.yaml
├── staging/
│   └── service-staging.yaml
└── prod/
    └── service-prod.yaml
```

### 6. Validação de Schema

```bash
# Instalar kubeval
kubeval service.yaml

# Validar com kube-score
kube-score score service.yaml
```

## Troubleshooting

### YAML Inválido

```bash
# Erro comum: indentação
Error from server (BadRequest): error when creating "service.yaml": 
Service in version "v1" cannot be handled as a Service: 
json: cannot unmarshal string into Go value of type int32

# Solução: verificar indentação e tipos
```

### Service não Cria Endpoints

```bash
# Verificar selector
kubectl get service my-service -o yaml | grep -A 5 selector

# Verificar labels dos Pods
kubectl get pods --show-labels

# Verificar endpoints
kubectl get endpoints my-service
```

### Porta Incorreta

```bash
# Verificar portas do container
kubectl get pods my-pod -o jsonpath='{.spec.containers[*].ports}'

# Verificar targetPort do Service
kubectl get service my-service -o jsonpath='{.spec.ports[*].targetPort}'
```

## Exemplo Prático Completo

### Aplicação Web com Frontend e Backend

**backend.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:1.0
        args: ["-text=Backend API"]
        ports:
        - name: http
          containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  labels:
    app: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - name: http
    port: 8080
    targetPort: http
```

**frontend.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - name: http
          containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  labels:
    app: frontend
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: http
```

### Aplicar

```bash
# Aplicar backend
kubectl apply -f backend.yaml

# Aplicar frontend
kubectl apply -f frontend.yaml

# Verificar
kubectl get all
```

**Saída esperada:**
```
NAME                            READY   STATUS    RESTARTS   AGE
pod/backend-xxx                 1/1     Running   0          30s
pod/backend-yyy                 1/1     Running   0          30s
pod/backend-zzz                 1/1     Running   0          30s
pod/frontend-aaa                1/1     Running   0          25s
pod/frontend-bbb                1/1     Running   0          25s

NAME                       TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/backend-service    ClusterIP      10.96.100.50    <none>        8080/TCP       30s
service/frontend-service   LoadBalancer   10.96.150.100   <pending>     80:30080/TCP   25s
```

## Limpeza

```bash
# Remover por arquivo
kubectl delete -f service.yaml

# Remover múltiplos arquivos
kubectl delete -f backend.yaml -f frontend.yaml

# Remover diretório
kubectl delete -f ./services/

# Remover por label
kubectl delete service -l app=myapp
```

## Resumo

- **YAML é a forma declarativa e recomendada** para criar Services
- Oferece **versionamento, reprodutibilidade e automação**
- Estrutura básica: `apiVersion`, `kind`, `metadata`, `spec`
- Campos principais: `type`, `selector`, `ports`
- Use **labels e annotations** para organização
- **Dry-run** para gerar e validar YAML
- **Kustomize** para gerenciar múltiplos ambientes
- Sempre **versione** seus arquivos YAML no Git

## Próximos Passos

- Estudar **Helm** para gerenciamento de pacotes
- Explorar **Kustomize** para customização
- Implementar **GitOps** com ArgoCD ou Flux
- Criar **templates** reutilizáveis
- Automatizar com **CI/CD pipelines**
