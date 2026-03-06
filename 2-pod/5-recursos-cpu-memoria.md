# Limitando Recursos de CPU e Memória

## Por que limitar recursos?

- **Estabilidade**: Evita que um Pod consuma todos os recursos do nó
- **Previsibilidade**: Garante recursos mínimos para a aplicação funcionar
- **Eficiência**: Permite melhor distribuição de Pods nos nós
- **Custo**: Otimiza uso de recursos e reduz custos
- **Isolamento**: Protege outros Pods de aplicações com vazamento de memória ou CPU

## Conceitos fundamentais

### Requests (Solicitações)
Quantidade **mínima** de recursos que o container precisa para funcionar.

- Usado pelo **scheduler** para decidir em qual nó colocar o Pod
- Garante que o container terá pelo menos essa quantidade disponível
- O container pode usar mais que o request se houver recursos disponíveis no nó

### Limits (Limites)
Quantidade **máxima** de recursos que o container pode usar.

- Impede que o container ultrapasse esse valor
- **CPU**: Container é throttled (limitado) se tentar usar mais
- **Memória**: Container é **terminado (OOMKilled)** se ultrapassar o limite

---

## Sintaxe básica

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-com-recursos
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

---

## Unidades de medida

### CPU

**Milicores (m)**:
- `1000m` = 1 CPU core completo
- `500m` = meio core (50% de 1 CPU)
- `250m` = um quarto de core (25% de 1 CPU)
- `100m` = 10% de 1 CPU

**Cores inteiros**:
- `1` = 1 CPU core
- `0.5` = meio core (equivalente a 500m)
- `2` = 2 CPU cores

```yaml
cpu: "1"      # 1 core completo
cpu: "0.5"    # meio core
cpu: "500m"   # meio core (mesma coisa que 0.5)
cpu: "100m"   # 10% de um core
```

### Memória

**Unidades suportadas**:
- `Ki` = Kibibyte (1024 bytes)
- `Mi` = Mebibyte (1024 Ki)
- `Gi` = Gibibyte (1024 Mi)
- `Ti` = Tebibyte (1024 Gi)

**Também aceita (base 10)**:
- `K` = Kilobyte (1000 bytes)
- `M` = Megabyte (1000 K)
- `G` = Gigabyte (1000 M)

```yaml
memory: "128Mi"   # 128 Mebibytes
memory: "1Gi"     # 1 Gibibyte
memory: "512Mi"   # 512 Mebibytes
memory: "64Mi"    # 64 Mebibytes
```

**Conversões úteis**:
- 1 Mi = 1.048576 MB
- 1 Gi = 1.073741824 GB
- Prefira usar `Mi` e `Gi` (mais preciso no Kubernetes)

---

## Exemplos práticos

### Exemplo 1: Aplicação web simples

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
```

**Interpretação:**
- Garante mínimo de 128Mi RAM e 10% de CPU
- Pode usar até 256Mi RAM e 20% de CPU
- Se ultrapassar 256Mi, será terminado (OOMKilled)
- Se tentar usar mais de 200m CPU, será throttled

### Exemplo 2: Aplicação com banco de dados

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-db
spec:
  containers:
  - name: app
    image: myapp:v1
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  - name: postgres
    image: postgres:14
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
```

### Exemplo 3: Aplicação de alta performance

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: high-performance-app
spec:
  containers:
  - name: app
    image: compute-intensive:v1
    resources:
      requests:
        memory: "2Gi"
        cpu: "2000m"
      limits:
        memory: "4Gi"
        cpu: "4000m"
```

### Exemplo 4: Microserviço leve

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lightweight-service
spec:
  containers:
  - name: api
    image: node:18-alpine
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
```

---

## QoS Classes (Quality of Service)

O Kubernetes classifica Pods em 3 categorias baseado nos recursos definidos:

### 1. Guaranteed (Garantido)
**Quando:** Requests = Limits para CPU e memória em todos os containers.

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

**Características:**
- Maior prioridade
- Último a ser removido em caso de pressão de recursos
- Melhor para aplicações críticas

### 2. Burstable (Expansível)
**Quando:** Requests < Limits ou apenas requests definido.

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "250m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

**Características:**
- Prioridade média
- Pode usar mais recursos quando disponível
- Bom para aplicações com carga variável

### 3. BestEffort (Melhor Esforço)
**Quando:** Nenhum request ou limit definido.

```yaml
# Sem resources definido
containers:
- name: app
  image: nginx
```

**Características:**
- Menor prioridade
- Primeiro a ser removido em caso de pressão de recursos
- Não recomendado para produção

---

## Verificando QoS Class

```bash
# Ver QoS Class de um pod
kubectl get pod <pod-name> -o jsonpath='{.status.qosClass}'

# Ver detalhes completos
kubectl describe pod <pod-name> | grep "QoS Class"
```

---

## Comportamento quando limites são ultrapassados

### CPU (Throttling)
Quando o container tenta usar mais CPU que o limit:
- Container é **throttled** (limitado)
- Aplicação fica mais lenta
- Container **NÃO é terminado**
- Pode causar timeouts e degradação de performance

### Memória (OOMKilled)
Quando o container tenta usar mais memória que o limit:
- Container é **terminado** (OOMKilled - Out Of Memory Killed)
- Pod pode ser reiniciado dependendo do `restartPolicy`
- Dados em memória são perdidos
- Evento registrado: `OOMKilled`

```bash
# Ver se pod foi OOMKilled
kubectl describe pod <pod-name> | grep -i oom

# Ver eventos
kubectl get events --sort-by='.lastTimestamp' | grep -i oom
```

---

## Boas práticas

### 1. Sempre defina requests e limits

```yaml
# ✅ BOM
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"

# ❌ RUIM (BestEffort)
# Sem resources definido
```

### 2. Comece conservador e ajuste

```yaml
# Fase 1: Começar com valores baixos
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

# Fase 2: Monitorar e ajustar baseado no uso real
```

### 3. Requests realistas

```yaml
# Requests devem refletir o uso NORMAL da aplicação
# Não o pico máximo
resources:
  requests:
    memory: "256Mi"  # Uso médio observado
    cpu: "250m"
```

### 4. Limits com margem de segurança

```yaml
# Limits devem ter margem para picos
# Geralmente 1.5x a 2x o request
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"   # 2x o request
    cpu: "500m"       # 2x o request
```

### 5. Considere o tipo de aplicação

```yaml
# Aplicação stateless (pode ser reiniciada facilmente)
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

# Aplicação stateful (banco de dados)
resources:
  requests:
    memory: "1Gi"
    cpu: "1000m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

### 6. Use Guaranteed para aplicações críticas

```yaml
# Aplicação crítica - Guaranteed QoS
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "512Mi"  # Igual ao request
    cpu: "500m"      # Igual ao request
```

---

## Monitorando uso de recursos

### Ver uso atual de recursos

```bash
# Uso de recursos de todos os pods
kubectl top pods

# Uso de recursos de um pod específico
kubectl top pod <pod-name>

# Uso de recursos por container
kubectl top pod <pod-name> --containers

# Uso de recursos dos nós
kubectl top nodes
```

### Ver recursos definidos

```bash
# Ver requests e limits de um pod
kubectl describe pod <pod-name> | grep -A 5 "Limits\|Requests"

# Ver em formato JSON
kubectl get pod <pod-name> -o json | jq '.spec.containers[].resources'
```

### Verificar se pod está sendo throttled

```bash
# Ver métricas detalhadas (requer metrics-server)
kubectl top pod <pod-name> --containers

# Se CPU estiver sempre no limite, pode estar sendo throttled
```

---

## LimitRange - Definindo padrões no namespace

LimitRange permite definir valores padrão e restrições para recursos no namespace.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: development
spec:
  limits:
  - max:
      memory: "1Gi"
      cpu: "1000m"
    min:
      memory: "64Mi"
      cpu: "50m"
    default:
      memory: "256Mi"
      cpu: "250m"
    defaultRequest:
      memory: "128Mi"
      cpu: "100m"
    type: Container
```

**Aplicar:**
```bash
kubectl apply -f limitrange.yaml
```

**Efeito:**
- Pods sem resources definidos recebem os valores `default` e `defaultRequest`
- Pods não podem solicitar mais que `max` ou menos que `min`

---

## ResourceQuota - Limitando recursos do namespace

ResourceQuota limita o total de recursos que podem ser usados em um namespace.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: development
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "10Gi"
    limits.cpu: "20"
    limits.memory: "20Gi"
    pods: "50"
```

**Aplicar:**
```bash
kubectl apply -f resourcequota.yaml

# Ver quotas
kubectl get resourcequota -n development

# Ver uso detalhado
kubectl describe resourcequota namespace-quota -n development
```

---

## Troubleshooting

### Pod em estado Pending

```bash
# Verificar eventos
kubectl describe pod <pod-name>

# Procurar por:
# - "Insufficient cpu" - Nó não tem CPU suficiente
# - "Insufficient memory" - Nó não tem memória suficiente
```

**Solução:**
- Reduzir requests
- Adicionar mais nós ao cluster
- Remover pods não essenciais

### Pod sendo OOMKilled

```bash
# Verificar eventos
kubectl describe pod <pod-name> | grep -i oom

# Ver último estado do container
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].lastState}'
```

**Solução:**
- Aumentar memory limits
- Investigar vazamento de memória na aplicação
- Otimizar uso de memória

### CPU Throttling

```bash
# Monitorar uso de CPU
kubectl top pod <pod-name> --containers

# Se CPU estiver sempre no limite
```

**Solução:**
- Aumentar CPU limits
- Otimizar código da aplicação
- Escalar horizontalmente (mais réplicas)

### Verificar se requests/limits estão adequados

```bash
# Monitorar por um período
kubectl top pod <pod-name> --containers

# Comparar com os valores definidos
kubectl describe pod <pod-name> | grep -A 5 "Limits\|Requests"
```

---

## Exemplo completo com múltiplos containers

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fullstack-app
  labels:
    app: fullstack
spec:
  containers:
  # Frontend
  - name: frontend
    image: nginx:alpine
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  
  # Backend API
  - name: backend
    image: node:18-alpine
    ports:
    - containerPort: 3000
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  # Database
  - name: database
    image: postgres:14-alpine
    ports:
    - containerPort: 5432
    env:
    - name: POSTGRES_PASSWORD
      value: "senha123"
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
  
  # Sidecar - Monitoring
  - name: metrics
    image: prom/node-exporter:latest
    ports:
    - containerPort: 9100
    resources:
      requests:
        memory: "32Mi"
        cpu: "25m"
      limits:
        memory: "64Mi"
        cpu: "50m"
```

**Total de recursos do Pod:**
- Requests: 864Mi RAM, 825m CPU
- Limits: 1.7Gi RAM, 1650m CPU

---

## Comandos úteis

```bash
# Ver recursos de todos os pods
kubectl top pods --all-namespaces

# Ver recursos de um namespace
kubectl top pods -n production

# Ver recursos dos nós
kubectl top nodes

# Ver capacidade total do cluster
kubectl describe nodes | grep -A 5 "Capacity\|Allocatable"

# Ver pods ordenados por uso de memória
kubectl top pods --sort-by=memory

# Ver pods ordenados por uso de CPU
kubectl top pods --sort-by=cpu

# Ver recursos definidos em todos os pods
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory

# Verificar QoS de todos os pods
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

---

## Resumo

**Requests:**
- Recursos **garantidos** para o container
- Usado pelo scheduler para alocação
- Container pode usar mais se disponível

**Limits:**
- Recursos **máximos** permitidos
- CPU: throttling se ultrapassar
- Memória: OOMKilled se ultrapassar

**Unidades:**
- CPU: `m` (milicores) - 1000m = 1 core
- Memória: `Mi`, `Gi` (base 1024)

**QoS Classes:**
- Guaranteed: requests = limits (maior prioridade)
- Burstable: requests < limits (prioridade média)
- BestEffort: sem resources (menor prioridade)

**Boas práticas:**
- Sempre defina requests e limits
- Requests = uso normal, Limits = picos
- Monitore e ajuste baseado no uso real
- Use Guaranteed para aplicações críticas
