# Explorando as Annotations no Kubernetes

## Introdução

Annotations são metadados flexíveis que armazenam informações arbitrárias sobre objetos do Kubernetes. Diferente das labels, não são usadas para seleção, mas sim para configuração, documentação e integração com ferramentas externas. Este guia explora usos avançados e práticos.

## Anatomia de uma Annotation

### Estrutura

```yaml
metadata:
  annotations:
    chave: "valor"
    prefixo.dominio.com/chave: "valor"
    chave-json: '{"key": "value", "number": 123}'
    chave-multilinha: |
      Linha 1
      Linha 2
      Linha 3
```

### Regras

**Chave:**
- Prefixo (opcional): até 253 caracteres
- Nome: até 63 caracteres
- Formato: `[prefixo/]nome`

**Valor:**
- Até 256KB (total de todas annotations)
- Qualquer string (texto, JSON, YAML, XML, etc.)
- Sem restrições de caracteres

---

## Annotations do Nginx Ingress Controller

### SSL/TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    # Redirecionamento HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    
    # Protocolos TLS
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    
    # Cipher suites
    nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384"
    
    # Preferir cipher do servidor
    nginx.ingress.kubernetes.io/ssl-prefer-server-ciphers: "true"
    
    # HSTS
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
    nginx.ingress.kubernetes.io/hsts-preload: "true"
    
    # Passthrough (não terminar TLS)
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: nginx
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

### Rewrite e Redirect

```yaml
annotations:
  # Rewrite target
  nginx.ingress.kubernetes.io/rewrite-target: /$2
  
  # Redirect permanente
  nginx.ingress.kubernetes.io/permanent-redirect: "https://newdomain.com"
  
  # Redirect temporário
  nginx.ingress.kubernetes.io/temporal-redirect: "https://maintenance.example.com"
  
  # App root
  nginx.ingress.kubernetes.io/app-root: "/app"
  
  # Use regex
  nginx.ingress.kubernetes.io/use-regex: "true"
```

### Rate Limiting

```yaml
annotations:
  # Limite de requisições por segundo
  nginx.ingress.kubernetes.io/limit-rps: "10"
  
  # Limite de conexões
  nginx.ingress.kubernetes.io/limit-connections: "5"
  
  # Limite de requisições por minuto
  nginx.ingress.kubernetes.io/limit-rpm: "100"
  
  # Whitelist de IPs (não aplicar rate limit)
  nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8,172.16.0.0/12"
```

### CORS

```yaml
annotations:
  # Habilitar CORS
  nginx.ingress.kubernetes.io/enable-cors: "true"
  
  # Origens permitidas
  nginx.ingress.kubernetes.io/cors-allow-origin: "https://example.com, https://app.example.com"
  
  # Métodos permitidos
  nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
  
  # Headers permitidos
  nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
  
  # Expor headers
  nginx.ingress.kubernetes.io/cors-expose-headers: "Content-Length,Content-Range"
  
  # Credenciais
  nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
  
  # Max age
  nginx.ingress.kubernetes.io/cors-max-age: "3600"
```

### Authentication

```yaml
annotations:
  # Basic Auth
  nginx.ingress.kubernetes.io/auth-type: "basic"
  nginx.ingress.kubernetes.io/auth-secret: "basic-auth"
  nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
  
  # OAuth
  nginx.ingress.kubernetes.io/auth-url: "https://oauth.example.com/auth"
  nginx.ingress.kubernetes.io/auth-signin: "https://oauth.example.com/signin"
  
  # Snippet de autenticação customizada
  nginx.ingress.kubernetes.io/auth-snippet: |
    if ($http_x_api_key != "secret") {
      return 403;
    }
```

### Proxy e Backend

```yaml
annotations:
  # Timeouts
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "30"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
  
  # Body size
  nginx.ingress.kubernetes.io/proxy-body-size: "10m"
  
  # Buffer
  nginx.ingress.kubernetes.io/proxy-buffer-size: "8k"
  nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
  
  # Protocol
  nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
  
  # Upstream hash
  nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
  
  # Session affinity
  nginx.ingress.kubernetes.io/affinity: "cookie"
  nginx.ingress.kubernetes.io/session-cookie-name: "route"
  nginx.ingress.kubernetes.io/session-cookie-expires: "172800"
  nginx.ingress.kubernetes.io/session-cookie-max-age: "172800"
```

### Custom Configuration

```yaml
annotations:
  # Snippet de configuração
  nginx.ingress.kubernetes.io/configuration-snippet: |
    add_header X-Custom-Header "MyValue" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Bloquear user agents
    if ($http_user_agent ~* (bot|crawler|spider)) {
      return 403;
    }
  
  # Snippet de servidor
  nginx.ingress.kubernetes.io/server-snippet: |
    location /health {
      access_log off;
      return 200 "healthy\n";
    }
```

### Whitelist e Blacklist

```yaml
annotations:
  # Whitelist de IPs
  nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
  
  # Blacklist (via snippet)
  nginx.ingress.kubernetes.io/configuration-snippet: |
    deny 1.2.3.4;
    deny 5.6.7.0/24;
    allow all;
```

---

## Annotations do Cert-Manager

### Básico

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    # Especificar ClusterIssuer
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    
    # Ou Issuer (namespace-scoped)
    cert-manager.io/issuer: "my-issuer"
    
    # Tipo de issuer
    cert-manager.io/issuer-kind: "ClusterIssuer"
    
    # Grupo do issuer
    cert-manager.io/issuer-group: "cert-manager.io"
spec:
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

### Configurações Avançadas

```yaml
annotations:
  # Duração do certificado
  cert-manager.io/duration: "2160h"  # 90 dias
  
  # Renovar antes de expirar
  cert-manager.io/renew-before: "360h"  # 15 dias
  
  # Algoritmo da chave privada
  cert-manager.io/private-key-algorithm: "RSA"
  
  # Tamanho da chave
  cert-manager.io/private-key-size: "2048"
  
  # Rotação da chave privada
  cert-manager.io/private-key-rotation-policy: "Always"
  
  # Common Name
  cert-manager.io/common-name: "myapp.example.com"
  
  # Subject
  cert-manager.io/subject-organizations: "MyCompany"
  cert-manager.io/subject-countries: "US"
  
  # Usos
  cert-manager.io/usages: "server auth,client auth"
```

### ACME Challenge

```yaml
annotations:
  # Tipo de challenge
  acme.cert-manager.io/http01-edit-in-place: "true"
  
  # Classe do Ingress para challenge
  acme.cert-manager.io/http01-ingress-class: "nginx"
  
  # Override de solver
  cert-manager.io/acme-challenge-type: "http01"
```

---

## Annotations do Prometheus

### Service Monitoring

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  annotations:
    # Habilitar scraping
    prometheus.io/scrape: "true"
    
    # Porta das métricas
    prometheus.io/port: "9090"
    
    # Path das métricas
    prometheus.io/path: "/metrics"
    
    # Scheme (http ou https)
    prometheus.io/scheme: "http"
    
    # Intervalo de scraping
    prometheus.io/scrape-interval: "30s"
    
    # Timeout
    prometheus.io/scrape-timeout: "10s"
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    name: http
  - port: 9090
    name: metrics
```

### Pod Monitoring

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/actuator/prometheus"
spec:
  containers:
  - name: myapp
    image: myapp:latest
    ports:
    - containerPort: 8080
```

---

## Annotations AWS (EKS)

### Load Balancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  annotations:
    # Tipo de Load Balancer
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"  # ou "external"
    
    # Scheme (internet-facing ou internal)
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    
    # Cross-zone load balancing
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    
    # Backend protocol
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    
    # Proxy protocol
    service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
    
    # SSL Certificate ARN
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-east-1:123456789012:certificate/abc123"
    
    # SSL Ports
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    
    # Connection draining
    service.beta.kubernetes.io/aws-load-balancer-connection-draining-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-connection-draining-timeout: "60"
    
    # Health check
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "HTTP"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8080"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "30"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
    
    # Subnets
    service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-abc123,subnet-def456"
    
    # Security groups
    service.beta.kubernetes.io/aws-load-balancer-security-groups: "sg-abc123,sg-def456"
    
    # Tags
    service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "Environment=production,Team=backend"
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

### EBS Volumes

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-pvc
  annotations:
    # Storage class
    volume.beta.kubernetes.io/storage-class: "gp3"
    
    # Volume type
    volume.beta.kubernetes.io/storage-provisioner: "ebs.csi.aws.com"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

---

## Annotations de Documentação

### Informações Descritivas

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    # Descrição
    description: "Main application backend API"
    
    # Documentação
    documentation: "https://docs.example.com/myapp"
    documentation.wiki: "https://wiki.example.com/myapp"
    
    # Contato
    contact.email: "team-backend@example.com"
    contact.slack: "#team-backend"
    contact.pagerduty: "https://example.pagerduty.com/services/ABC123"
    
    # Responsável
    owner: "john-doe"
    team: "backend-team"
    squad: "payments"
    
    # SLA
    sla.availability: "99.9%"
    sla.response-time: "200ms"
    
    # Manutenção
    maintenance.window: "Sunday 02:00-04:00 UTC"
    maintenance.contact: "ops-team@example.com"
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
      - name: myapp
        image: myapp:latest
```

---

## Annotations de Build e Deploy

### CI/CD Information

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    # Build
    build.date: "2024-03-13T16:00:00Z"
    build.number: "1234"
    build.url: "https://jenkins.example.com/job/myapp/1234"
    
    # Git
    git.commit: "abc123def456"
    git.commit.short: "abc123"
    git.branch: "main"
    git.tag: "v2.0.0"
    git.repository: "https://github.com/company/myapp"
    git.author: "john-doe"
    git.message: "feat: add new feature"
    
    # Docker
    docker.image: "myapp:2.0.0"
    docker.registry: "docker.io/company"
    docker.digest: "sha256:abc123..."
    
    # Deploy
    deployed.by: "jenkins"
    deployed.at: "2024-03-13T16:15:00Z"
    deployed.from: "jenkins-agent-1"
    
    # Change Management
    change.ticket: "JIRA-1234"
    change.type: "feature"
    change.description: "Add payment gateway integration"
    change.approver: "jane-smith"
    change.approved-at: "2024-03-13T15:00:00Z"
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
      - name: myapp
        image: myapp:2.0.0
```

---

## Annotations de Configuração

### Application Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  annotations:
    # Configuração em JSON
    config.json: |
      {
        "database": {
          "host": "db.example.com",
          "port": 5432,
          "name": "myapp"
        },
        "cache": {
          "host": "redis.example.com",
          "port": 6379
        },
        "features": {
          "new-ui": true,
          "beta-api": false
        }
      }
    
    # Configuração em YAML
    config.yaml: |
      database:
        host: db.example.com
        port: 5432
        name: myapp
      cache:
        host: redis.example.com
        port: 6379
      features:
        new-ui: true
        beta-api: false
    
    # Versão da configuração
    config.version: "2.0"
    config.last-updated: "2024-03-13T16:00:00Z"
    config.updated-by: "devops-team"
data:
  app.properties: |
    database.host=db.example.com
    database.port=5432
```

---

## Annotations de Backup e Restore

### Velero Backup

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
  annotations:
    # Backup
    backup.velero.io/backup-volumes: "data"
    
    # Snapshot
    snapshot.storage.kubernetes.io/is-default-class: "true"
    
    # Retention
    backup.velero.io/retention-period: "720h"  # 30 dias
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### Backup Schedule

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  annotations:
    # Backup schedule
    backup.schedule: "0 2 * * *"  # Diariamente às 2am
    backup.retention: "7d"
    backup.destination: "s3://backups/database"
    
    # Restore point
    restore.point: "2024-03-13T02:00:00Z"
    restore.source: "s3://backups/database/2024-03-13"
spec:
  serviceName: database
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:14
```

---

## Annotations de Segurança

### Security Policies

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  annotations:
    # AppArmor
    container.apparmor.security.beta.kubernetes.io/myapp: "runtime/default"
    
    # Seccomp
    seccomp.security.alpha.kubernetes.io/pod: "runtime/default"
    
    # SELinux
    selinux.kubernetes.io/level: "s0:c123,c456"
    
    # Security scanning
    security.scan.date: "2024-03-13"
    security.scan.tool: "trivy"
    security.scan.result: "passed"
    security.vulnerabilities: "0"
spec:
  containers:
  - name: myapp
    image: myapp:latest
```

---

## Annotations Customizadas

### Exemplo: Sistema de Notificações

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    # Notificações
    notify.slack.channel: "#deployments"
    notify.slack.on-success: "true"
    notify.slack.on-failure: "true"
    
    notify.email.recipients: "team@example.com,ops@example.com"
    notify.email.on-failure: "true"
    
    notify.pagerduty.service-key: "abc123"
    notify.pagerduty.severity: "critical"
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
      - name: myapp
        image: myapp:latest
```

### Exemplo: Feature Flags

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    # Feature flags
    features.new-ui: "enabled"
    features.new-ui.rollout: "50%"
    features.new-ui.enabled-for: "beta-users,premium-users"
    
    features.beta-api: "disabled"
    features.beta-api.reason: "Under development"
    
    features.experimental: "canary"
    features.experimental.percentage: "5%"
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
      - name: myapp
        image: myapp:latest
```

---

## Gerenciamento de Annotations

### Adicionar Annotations

```bash
# Adicionar annotation simples
kubectl annotate pod mypod description="Main application pod"

# Adicionar annotation com JSON
kubectl annotate pod mypod config='{"timeout":30,"retries":3}'

# Adicionar a múltiplos recursos
kubectl annotate pods -l app=myapp maintainer="team@example.com"

# Adicionar annotation multilinha
kubectl annotate pod mypod notes="Line 1
Line 2
Line 3"
```

### Modificar Annotations

```bash
# Modificar (requer --overwrite)
kubectl annotate pod mypod description="Updated description" --overwrite

# Modificar múltiplas
kubectl annotate pods -l app=myapp version="2.0" --overwrite
```

### Remover Annotations

```bash
# Remover annotation (sufixo -)
kubectl annotate pod mypod description-

# Remover múltiplas
kubectl annotate pod mypod description- maintainer- version-

# Remover de múltiplos recursos
kubectl annotate pods -l app=myapp deprecated-
```

### Ver Annotations

```bash
# Ver todas annotations
kubectl get pod mypod -o jsonpath='{.metadata.annotations}'

# Ver annotation específica
kubectl get pod mypod -o jsonpath='{.metadata.annotations.description}'

# Formato YAML
kubectl get pod mypod -o yaml | grep -A 20 annotations

# Formato JSON formatado
kubectl get pod mypod -o json | jq '.metadata.annotations'

# Listar annotations de múltiplos recursos
kubectl get pods -o custom-columns=NAME:.metadata.name,ANNOTATIONS:.metadata.annotations
```

---

## Validação e Auditoria

### Script: Validar Annotations Obrigatórias

```bash
#!/bin/bash
# validate-annotations.sh

REQUIRED_ANNOTATIONS=("description" "owner" "team")

kubectl get deployments --all-namespaces -o json | \
  jq -r '.items[] | 
    {
      name: .metadata.name,
      namespace: .metadata.namespace,
      annotations: .metadata.annotations
    }' | \
  jq -c '.' | while read deployment; do
    name=$(echo $deployment | jq -r '.name')
    namespace=$(echo $deployment | jq -r '.namespace')
    
    for annotation in "${REQUIRED_ANNOTATIONS[@]}"; do
      value=$(echo $deployment | jq -r ".annotations.\"$annotation\" // empty")
      if [ -z "$value" ]; then
        echo "WARNING: $namespace/$name missing annotation: $annotation"
      fi
    done
  done
```

### Script: Extrair Informações de Build

```bash
#!/bin/bash
# extract-build-info.sh

kubectl get deployments --all-namespaces -o json | \
  jq -r '.items[] | 
    {
      name: .metadata.name,
      namespace: .metadata.namespace,
      build_date: .metadata.annotations."build.date",
      git_commit: .metadata.annotations."git.commit",
      deployed_by: .metadata.annotations."deployed.by"
    }' | \
  jq -c '.' | while read deployment; do
    echo $deployment | jq '.'
  done
```

---

## Boas Práticas

### ✅ Fazer

```yaml
# Usar prefixos para evitar conflitos
annotations:
  company.com/owner: "team-backend"
  company.com/cost-center: "engineering"

# Documentar propósito
annotations:
  description: "Main API service for customer management"
  documentation: "https://docs.example.com/api"

# Informações de build
annotations:
  build.date: "2024-03-13T16:00:00Z"
  git.commit: "abc123"

# Configurações de ferramentas
annotations:
  prometheus.io/scrape: "true"
  nginx.ingress.kubernetes.io/rate-limit: "100"
```

### ❌ Evitar

```yaml
# Não usar para seleção (use labels)
annotations:
  app: myapp  # Deveria ser label

# Não armazenar dados muito grandes
annotations:
  large-data: "..." # Use ConfigMap ou Secret

# Não armazenar dados sensíveis
annotations:
  password: "secret123"  # Use Secret

# Não usar caracteres especiais desnecessários
annotations:
  "my@annotation#with$special%chars": "value"
```

---

## Resumo dos Comandos

```bash
# Adicionar
kubectl annotate pod mypod key="value"
kubectl annotate pods -l app=myapp key="value"

# Modificar
kubectl annotate pod mypod key="new-value" --overwrite

# Remover
kubectl annotate pod mypod key-

# Ver
kubectl get pod mypod -o jsonpath='{.metadata.annotations}'
kubectl get pod mypod -o yaml | grep -A 10 annotations

# Queries
kubectl get pods -o custom-columns=NAME:.metadata.name,ANNOTATIONS:.metadata.annotations
kubectl get pods -o json | jq '.items[].metadata.annotations'
```

---

## Conclusão

Annotations são poderosas para:

✅ **Configuração** - Nginx, Cert-Manager, Prometheus  
✅ **Documentação** - Descrições, contatos, SLAs  
✅ **CI/CD** - Build info, git commits, deploy tracking  
✅ **Integração** - AWS, GCP, Azure services  
✅ **Segurança** - Policies, scanning results  
✅ **Operações** - Backup, monitoring, alerting  
✅ **Metadados** - Qualquer informação não-identificadora  

Use annotations para **configurar, documentar e integrar** seus recursos Kubernetes!
