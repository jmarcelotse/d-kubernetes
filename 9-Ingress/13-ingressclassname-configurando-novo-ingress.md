# Conhecendo o ingressClassName e Configurando um Novo Ingress

## Introdução

O `ingressClassName` é um campo que define qual Ingress Controller deve processar um recurso Ingress específico. Isso permite ter múltiplos Ingress Controllers no mesmo cluster, cada um com responsabilidades diferentes.

## O que é ingressClassName?

### Conceito

```
Cluster Kubernetes
    ↓
┌─────────────────────────────────────────┐
│  Ingress Controller 1 (nginx)          │
│  IngressClass: nginx                    │
└─────────────────────────────────────────┘
    ↓
Ingress com ingressClassName: nginx

┌─────────────────────────────────────────┐
│  Ingress Controller 2 (traefik)        │
│  IngressClass: traefik                  │
└─────────────────────────────────────────┘
    ↓
Ingress com ingressClassName: traefik

┌─────────────────────────────────────────┐
│  Ingress Controller 3 (haproxy)        │
│  IngressClass: haproxy                  │
└─────────────────────────────────────────┘
    ↓
Ingress com ingressClassName: haproxy
```

### Por Que Usar?

- **Múltiplos Controllers**: Diferentes controllers no mesmo cluster
- **Separação de Responsabilidades**: Interno vs Externo, Público vs Privado
- **Diferentes Funcionalidades**: Nginx para web, Traefik para APIs
- **Ambientes Isolados**: Dev, Staging, Prod com controllers separados
- **Migração Gradual**: Testar novo controller sem afetar o existente

---

## IngressClass Resource

### Estrutura Básica

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
```

### Componentes

- **metadata.name**: Nome da IngressClass (usado no Ingress)
- **spec.controller**: Identificador do controller
- **annotations**: Definir como padrão (opcional)

---

## Verificar IngressClasses Existentes

```bash
# Listar IngressClasses
kubectl get ingressclass

# Output exemplo:
# NAME      CONTROLLER                     PARAMETERS   AGE
# nginx     k8s.io/ingress-nginx          <none>       5d

# Ver detalhes
kubectl describe ingressclass nginx

# Ver YAML
kubectl get ingressclass nginx -o yaml
```

---

## Cenário 1: Nginx Ingress Controller (Padrão)

### 1.1 Verificar IngressClass do Nginx

```bash
# Ver IngressClass criada automaticamente
kubectl get ingressclass nginx -o yaml
```

Output:
```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
```

### 1.2 Criar Ingress Usando ingressClassName

Crie o arquivo `ingress-with-classname.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: default
spec:
  ingressClassName: nginx  # Especifica qual controller usar
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
```

```bash
# Aplicar
kubectl apply -f ingress-with-classname.yaml

# Verificar
kubectl get ingress app-ingress
kubectl describe ingress app-ingress
```

### 1.3 Ingress Sem ingressClassName (Usa o Padrão)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress-default
  namespace: default
spec:
  # Sem ingressClassName - usa o default (nginx)
  rules:
  - host: default.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

---

## Cenário 2: Múltiplos Ingress Controllers

### 2.1 Instalar Segundo Controller (Traefik)

```bash
# Adicionar repo Helm
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Instalar Traefik
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=false

# Verificar
kubectl get pods -n traefik
kubectl get svc -n traefik
```

### 2.2 Verificar IngressClasses

```bash
# Listar
kubectl get ingressclass

# Output:
# NAME      CONTROLLER                     PARAMETERS   AGE
# nginx     k8s.io/ingress-nginx          <none>       5d
# traefik   traefik.io/ingress-controller <none>       1m

# Ver detalhes do Traefik
kubectl get ingressclass traefik -o yaml
```

### 2.3 Criar Aplicações de Teste

```bash
# App 1: Para Nginx
kubectl create deployment app-nginx --image=nginx:alpine --replicas=2
kubectl expose deployment app-nginx --port=80 --name=app-nginx-service

# App 2: Para Traefik
kubectl create deployment app-traefik --image=httpd:alpine --replicas=2
kubectl expose deployment app-traefik --port=80 --name=app-traefik-service

# Verificar
kubectl get all
```

### 2.4 Ingress para Nginx Controller

Crie o arquivo `ingress-nginx-controller.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-nginx-controller
  namespace: default
  labels:
    controller: nginx
spec:
  ingressClassName: nginx
  rules:
  - host: nginx.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-nginx-service
            port:
              number: 80
```

### 2.5 Ingress para Traefik Controller

Crie o arquivo `ingress-traefik-controller.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-traefik-controller
  namespace: default
  labels:
    controller: traefik
spec:
  ingressClassName: traefik
  rules:
  - host: traefik.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-traefik-service
            port:
              number: 80
```

### 2.6 Aplicar e Testar

```bash
# Aplicar ambos
kubectl apply -f ingress-nginx-controller.yaml
kubectl apply -f ingress-traefik-controller.yaml

# Verificar
kubectl get ingress

# Output:
# NAME                        CLASS      HOSTS                 ADDRESS
# ingress-nginx-controller    nginx      nginx.example.com     192.168.1.100
# ingress-traefik-controller  traefik    traefik.example.com   192.168.1.101

# Configurar /etc/hosts
NGINX_IP=$(kubectl get ingress ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
TRAEFIK_IP=$(kubectl get ingress ingress-traefik-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

sudo bash -c "cat >> /etc/hosts << EOF
$NGINX_IP nginx.example.com
$TRAEFIK_IP traefik.example.com
EOF"

# Testar
curl http://nginx.example.com
curl http://traefik.example.com
```

---

## Cenário 3: Controllers Interno e Externo

### 3.1 Arquitetura

```
Internet → Nginx External (Public) → Aplicações Públicas
    ↓
Rede Interna → Nginx Internal (Private) → Aplicações Internas
```

### 3.2 Instalar Nginx Externo (Público)

```bash
# Instalar com LoadBalancer
helm install nginx-external ingress-nginx/ingress-nginx \
  --namespace ingress-external \
  --create-namespace \
  --set controller.ingressClassResource.name=nginx-external \
  --set controller.ingressClassResource.controllerValue=k8s.io/ingress-nginx-external \
  --set controller.ingressClass=nginx-external \
  --set controller.service.type=LoadBalancer

# Verificar
kubectl get pods -n ingress-external
kubectl get svc -n ingress-external
```

### 3.3 Instalar Nginx Interno (Privado)

```bash
# Instalar com ClusterIP ou LoadBalancer interno
helm install nginx-internal ingress-nginx/ingress-nginx \
  --namespace ingress-internal \
  --create-namespace \
  --set controller.ingressClassResource.name=nginx-internal \
  --set controller.ingressClassResource.controllerValue=k8s.io/ingress-nginx-internal \
  --set controller.ingressClass=nginx-internal \
  --set controller.service.type=ClusterIP

# Verificar
kubectl get pods -n ingress-internal
kubectl get svc -n ingress-internal
```

### 3.4 Verificar IngressClasses

```bash
# Listar
kubectl get ingressclass

# Output:
# NAME              CONTROLLER                           AGE
# nginx-external    k8s.io/ingress-nginx-external       1m
# nginx-internal    k8s.io/ingress-nginx-internal       1m
```

### 3.5 Ingress Público

Crie o arquivo `ingress-public.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: public-app-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx-external
  rules:
  - host: public.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: public-app-service
            port:
              number: 80
```

### 3.6 Ingress Privado

Crie o arquivo `ingress-private.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: private-app-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
spec:
  ingressClassName: nginx-internal
  rules:
  - host: internal.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: internal-app-service
            port:
              number: 80
```

---

## Cenário 4: Criar IngressClass Customizada

### 4.1 Criar IngressClass Manualmente

Crie o arquivo `custom-ingressclass.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: custom-nginx
  labels:
    app: custom-ingress
  annotations:
    ingressclass.kubernetes.io/is-default-class: "false"
spec:
  controller: k8s.io/custom-ingress-nginx
  parameters:
    apiGroup: k8s.example.com
    kind: IngressParameters
    name: custom-params
```

```bash
# Aplicar
kubectl apply -f custom-ingressclass.yaml

# Verificar
kubectl get ingressclass custom-nginx
kubectl describe ingressclass custom-nginx
```

### 4.2 Usar IngressClass Customizada

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: custom-ingress
  namespace: default
spec:
  ingressClassName: custom-nginx
  rules:
  - host: custom.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

---

## Migração: Annotation para ingressClassName

### Método Antigo (Deprecated)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: old-style-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"  # Método antigo
spec:
  rules:
  - host: old.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### Método Novo (Recomendado)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: new-style-ingress
spec:
  ingressClassName: nginx  # Método novo
  rules:
  - host: new.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### Script de Migração

```bash
#!/bin/bash

# Listar Ingresses com annotation antiga
kubectl get ingress -A -o json | \
  jq -r '.items[] | select(.metadata.annotations["kubernetes.io/ingress.class"] != null) | 
  "\(.metadata.namespace)/\(.metadata.name)"'

# Migrar um Ingress específico
NAMESPACE="default"
INGRESS_NAME="old-style-ingress"

# Obter classe da annotation
INGRESS_CLASS=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE \
  -o jsonpath='{.metadata.annotations.kubernetes\.io/ingress\.class}')

# Adicionar ingressClassName
kubectl patch ingress $INGRESS_NAME -n $NAMESPACE --type=merge \
  -p "{\"spec\":{\"ingressClassName\":\"$INGRESS_CLASS\"}}"

# Remover annotation antiga (opcional)
kubectl annotate ingress $INGRESS_NAME -n $NAMESPACE \
  kubernetes.io/ingress.class-

echo "Migrated $NAMESPACE/$INGRESS_NAME to ingressClassName: $INGRESS_CLASS"
```

---

## Definir IngressClass Padrão

### Método 1: Via Annotation

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
```

### Método 2: Via kubectl

```bash
# Definir como padrão
kubectl annotate ingressclass nginx \
  ingressclass.kubernetes.io/is-default-class=true

# Remover padrão
kubectl annotate ingressclass nginx \
  ingressclass.kubernetes.io/is-default-class-

# Verificar qual é o padrão
kubectl get ingressclass -o json | \
  jq -r '.items[] | select(.metadata.annotations["ingressclass.kubernetes.io/is-default-class"]=="true") | .metadata.name'
```

### Testar Padrão

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-default
spec:
  # Sem ingressClassName - usa o padrão
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

```bash
# Aplicar
kubectl apply -f test-default.yaml

# Verificar qual classe foi usada
kubectl get ingress test-default -o jsonpath='{.spec.ingressClassName}'
```

---

## Gerenciamento de IngressClasses

### Listar e Filtrar

```bash
# Listar todas
kubectl get ingressclass

# Com labels
kubectl get ingressclass --show-labels

# Filtrar por controller
kubectl get ingressclass -o json | \
  jq -r '.items[] | select(.spec.controller=="k8s.io/ingress-nginx") | .metadata.name'

# Ver qual é padrão
kubectl get ingressclass -o custom-columns=\
NAME:.metadata.name,\
CONTROLLER:.spec.controller,\
DEFAULT:.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class
```

### Ver Ingresses por Classe

```bash
# Listar Ingresses com suas classes
kubectl get ingress -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
CLASS:.spec.ingressClassName,\
HOSTS:.spec.rules[*].host

# Filtrar por classe específica
kubectl get ingress -A -o json | \
  jq -r '.items[] | select(.spec.ingressClassName=="nginx") | 
  "\(.metadata.namespace)/\(.metadata.name)"'
```

---

## Troubleshooting

### Problema 1: Ingress Não Funciona

```bash
# Verificar se IngressClass existe
kubectl get ingressclass

# Ver qual classe o Ingress está usando
kubectl get ingress <name> -o jsonpath='{.spec.ingressClassName}'

# Verificar se controller está rodando
kubectl get pods -n ingress-nginx

# Ver eventos
kubectl describe ingress <name>
```

### Problema 2: IngressClass Não Encontrada

```bash
# Listar classes disponíveis
kubectl get ingressclass

# Criar IngressClass se não existir
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
EOF

# Verificar
kubectl get ingressclass nginx
```

### Problema 3: Múltiplos Controllers Conflitando

```bash
# Ver todos os controllers
kubectl get pods -A | grep ingress

# Ver IngressClasses
kubectl get ingressclass

# Garantir que cada Ingress tem ingressClassName específico
kubectl get ingress -A -o json | \
  jq -r '.items[] | select(.spec.ingressClassName==null) | 
  "\(.metadata.namespace)/\(.metadata.name) - NO CLASS"'

# Adicionar ingressClassName aos Ingresses sem classe
kubectl patch ingress <name> -n <namespace> --type=merge \
  -p '{"spec":{"ingressClassName":"nginx"}}'
```

### Problema 4: Padrão Não Funciona

```bash
# Verificar se há IngressClass padrão
kubectl get ingressclass -o json | \
  jq -r '.items[] | select(.metadata.annotations["ingressclass.kubernetes.io/is-default-class"]=="true")'

# Se não houver, definir uma
kubectl annotate ingressclass nginx \
  ingressclass.kubernetes.io/is-default-class=true

# Verificar
kubectl get ingressclass nginx -o yaml | grep is-default-class
```

---

## Stack Completa - Múltiplos Controllers

Crie o arquivo `multi-controller-stack.yaml`:

```yaml
---
# Namespace para apps
apiVersion: v1
kind: Namespace
metadata:
  name: multi-ingress

---
# App 1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: multi-ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
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
  name: app1-service
  namespace: multi-ingress
spec:
  selector:
    app: app1
  ports:
  - port: 80

---
# App 2
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: multi-ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: httpd
        image: httpd:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: app2-service
  namespace: multi-ingress
spec:
  selector:
    app: app2
  ports:
  - port: 80

---
# Ingress 1 - Nginx Controller
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app1-ingress
  namespace: multi-ingress
spec:
  ingressClassName: nginx
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

---
# Ingress 2 - Traefik Controller
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app2-ingress
  namespace: multi-ingress
spec:
  ingressClassName: traefik
  rules:
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

```bash
# Aplicar
kubectl apply -f multi-controller-stack.yaml

# Verificar
kubectl get all,ingress -n multi-ingress

# Testar
curl http://app1.example.com
curl http://app2.example.com
```

---

## Resumo dos Comandos

```bash
# Listar IngressClasses
kubectl get ingressclass

# Ver detalhes
kubectl describe ingressclass <name>

# Criar IngressClass
kubectl apply -f ingressclass.yaml

# Definir como padrão
kubectl annotate ingressclass <name> \
  ingressclass.kubernetes.io/is-default-class=true

# Ver Ingresses por classe
kubectl get ingress -A -o custom-columns=NAME:.metadata.name,CLASS:.spec.ingressClassName

# Migrar annotation para ingressClassName
kubectl patch ingress <name> --type=merge \
  -p '{"spec":{"ingressClassName":"nginx"}}'

# Deletar IngressClass
kubectl delete ingressclass <name>
```

---

## Conclusão

O `ingressClassName` oferece:

✅ **Flexibilidade** - Múltiplos controllers no mesmo cluster  
✅ **Isolamento** - Separar tráfego público e privado  
✅ **Organização** - Controllers por ambiente ou função  
✅ **Migração** - Testar novos controllers sem impacto  
✅ **Padrão Moderno** - Substitui annotations antigas  
✅ **Controle Granular** - Escolher controller por Ingress  

Com `ingressClassName`, você tem controle total sobre qual controller processa cada Ingress, permitindo arquiteturas complexas e flexíveis!
