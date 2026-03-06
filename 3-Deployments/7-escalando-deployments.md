# Escalando Deployments no Kubernetes

## Visão Geral

Escalar no Kubernetes significa ajustar o número de réplicas de pods para atender à demanda. Existem três tipos principais:

1. **Escalonamento Manual** - `kubectl scale`
2. **Escalonamento Horizontal Automático** - HPA (Horizontal Pod Autoscaler)
3. **Escalonamento Vertical** - VPA (Vertical Pod Autoscaler)

---

## 1. Escalonamento Manual (kubectl scale)

Ajusta manualmente o número de réplicas.

### Exemplo 1: Scale Básico

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Ver réplicas atuais
kubectl get deployment nginx

# Escalar para 5 réplicas
kubectl scale deployment nginx --replicas=5

# Verificar
kubectl get deployment nginx
kubectl get pods -l app=nginx

# Escalar para baixo
kubectl scale deployment nginx --replicas=2

# Verificar
kubectl get pods -l app=nginx -w
```

### Exemplo 2: Escalar Múltiplos Deployments

```bash
# Criar vários deployments
kubectl create deployment web --image=nginx --replicas=2
kubectl create deployment api --image=node:18 --replicas=2
kubectl create deployment cache --image=redis --replicas=1

# Escalar todos para 3 réplicas
kubectl scale deployment web api cache --replicas=3

# Verificar
kubectl get deployments
```

### Exemplo 3: Escalar com Condição

```bash
# Escalar apenas se tiver 3 réplicas atualmente
kubectl scale deployment nginx --replicas=5 --current-replicas=3

# Se não tiver 3, não escala
# Útil para evitar conflitos em scripts
```

### Exemplo 4: Escalar via Manifesto

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 10    # Alterar este número
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
```

```bash
# Editar replicas no arquivo
sed -i 's/replicas: 10/replicas: 20/' deployment.yaml

# Aplicar
kubectl apply -f deployment.yaml

# Verificar
kubectl get deployment webapp
```

---

## 2. Horizontal Pod Autoscaler (HPA)

Escala automaticamente baseado em métricas (CPU, memória, custom).

### Pré-requisitos

```bash
# Instalar metrics-server (necessário para HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verificar
kubectl get deployment metrics-server -n kube-system

# Testar métricas
kubectl top nodes
kubectl top pods
```

### Exemplo 5: HPA Básico (CPU)

```yaml
# deployment-hpa.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m      # IMPORTANTE: HPA precisa de requests
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
```

```bash
# Aplicar deployment
kubectl apply -f deployment-hpa.yaml

# Criar HPA (escala entre 2-10 réplicas quando CPU > 50%)
kubectl autoscale deployment webapp --cpu-percent=50 --min=2 --max=10

# Verificar HPA
kubectl get hpa

# Ver detalhes
kubectl describe hpa webapp
```

### Exemplo 6: HPA com Manifesto

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

```bash
# Aplicar
kubectl apply -f hpa.yaml

# Verificar
kubectl get hpa webapp-hpa

# Ver em tempo real
kubectl get hpa webapp-hpa -w
```

### Exemplo 7: HPA com CPU e Memória

```yaml
# hpa-cpu-memory.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300    # Aguarda 5min antes de reduzir
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 4
        periodSeconds: 30
      selectPolicy: Max
```

```bash
# Aplicar
kubectl apply -f hpa-cpu-memory.yaml

# Monitorar
kubectl get hpa webapp-hpa -w
```

### Exemplo 8: Testar HPA com Carga

```bash
# Criar deployment com HPA
kubectl create deployment php-apache --image=registry.k8s.io/hpa-example --replicas=1

# Configurar resources
kubectl set resources deployment php-apache --requests=cpu=200m --limits=cpu=500m

# Criar HPA
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

# Expor serviço
kubectl expose deployment php-apache --port=80

# Gerar carga (em outro terminal)
kubectl run -it load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"

# Monitorar HPA (em outro terminal)
kubectl get hpa php-apache -w

# Ver pods sendo criados
kubectl get pods -l app=php-apache -w

# Parar carga (Ctrl+C no terminal do load-generator)
# Aguardar scale down (5 minutos por padrão)
```

---

## 3. Vertical Pod Autoscaler (VPA)

Ajusta automaticamente requests e limits de CPU/memória.

### Exemplo 9: VPA Básico

```yaml
# vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  updatePolicy:
    updateMode: "Auto"    # Auto, Recreate, Initial, Off
  resourcePolicy:
    containerPolicies:
    - containerName: webapp
      minAllowed:
        cpu: 100m
        memory: 64Mi
      maxAllowed:
        cpu: 1000m
        memory: 512Mi
```

```bash
# Instalar VPA (se não estiver instalado)
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh

# Aplicar VPA
kubectl apply -f vpa.yaml

# Ver recomendações
kubectl describe vpa webapp-vpa
```

---

## 4. Cluster Autoscaler

Adiciona ou remove nodes do cluster baseado na demanda.

### Exemplo 10: Cluster Autoscaler (Cloud)

```yaml
# cluster-autoscaler.yaml (exemplo para AWS)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.27.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
```

---

## Estratégias de Escalabilidade

### Exemplo 11: Escalonamento Baseado em Horário

```bash
# Script para escalar baseado em horário
cat > scale-schedule.sh <<'EOF'
#!/bin/bash

HOUR=$(date +%H)

if [ $HOUR -ge 8 ] && [ $HOUR -lt 18 ]; then
  # Horário comercial: 10 réplicas
  kubectl scale deployment webapp --replicas=10
else
  # Fora do horário: 2 réplicas
  kubectl scale deployment webapp --replicas=2
fi
EOF

chmod +x scale-schedule.sh

# Adicionar ao cron
# 0 * * * * /path/to/scale-schedule.sh
```

### Exemplo 12: Escalonamento por Fila

```yaml
# hpa-queue.yaml (usando custom metrics)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: worker-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: worker
  minReplicas: 1
  maxReplicas: 50
  metrics:
  - type: External
    external:
      metric:
        name: queue_messages_ready
        selector:
          matchLabels:
            queue_name: tasks
      target:
        type: AverageValue
        averageValue: "30"    # 30 mensagens por pod
```

---

## Fluxo de Escalonamento

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE ESCALONAMENTO AUTOMÁTICO               │
└─────────────────────────────────────────────────────────┘

1. MÉTRICAS COLETADAS
   ├─> Metrics Server coleta CPU/memória dos pods
   ├─> Custom Metrics Adapter coleta métricas customizadas
   └─> Métricas disponíveis via API

2. HPA AVALIA MÉTRICAS
   ├─> A cada 15 segundos (padrão)
   ├─> Compara com target definido
   └─> Calcula número desejado de réplicas

3. DECISÃO DE ESCALONAMENTO
   ├─> Se métrica > target: scale up
   ├─> Se métrica < target: scale down
   └─> Respeita min/max replicas

4. ATUALIZA DEPLOYMENT
   ├─> HPA atualiza spec.replicas do Deployment
   └─> Deployment Controller detecta mudança

5. DEPLOYMENT ESCALA
   ├─> Scale up: cria novos pods
   ├─> Scale down: remove pods (respeitando PDB)
   └─> Rolling update se necessário

6. PODS CRIADOS/REMOVIDOS
   ├─> Scheduler atribui novos pods a nodes
   ├─> Kubelet inicia/para containers
   └─> Pods ficam Ready

7. CICLO CONTINUA
   └─> HPA continua monitorando e ajustando

FÓRMULA DE CÁLCULO:
desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]

EXEMPLO:
- currentReplicas: 3
- currentMetric: 80% CPU
- targetMetric: 50% CPU
- desiredReplicas = ceil[3 * (80 / 50)] = ceil[4.8] = 5
```

---

## Exemplo Prático Completo

```bash
# 1. Criar deployment com resources
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        ports:
        - containerPort: 80
EOF

# 2. Verificar deployment
kubectl get deployment webapp
kubectl get pods -l app=webapp

# 3. Escalar manualmente
kubectl scale deployment webapp --replicas=5
kubectl get pods -l app=webapp

# 4. Voltar para 2
kubectl scale deployment webapp --replicas=2

# 5. Criar HPA
kubectl autoscale deployment webapp --cpu-percent=50 --min=2 --max=10

# 6. Ver HPA
kubectl get hpa webapp

# 7. Expor serviço
kubectl expose deployment webapp --port=80 --type=NodePort

# 8. Gerar carga
kubectl run load-generator --image=busybox --restart=Never -it --rm -- /bin/sh -c "while true; do wget -q -O- http://webapp; done"

# 9. Em outro terminal, monitorar
kubectl get hpa webapp -w
kubectl get pods -l app=webapp -w
kubectl top pods -l app=webapp

# 10. Parar carga (Ctrl+C)
# Aguardar scale down

# 11. Ver histórico de eventos
kubectl describe hpa webapp

# 12. Limpar
kubectl delete hpa webapp
kubectl delete service webapp
kubectl delete deployment webapp
```

---

## Comandos Úteis

### Scale Manual

```bash
# Escalar deployment
kubectl scale deployment <name> --replicas=<number>

# Escalar múltiplos
kubectl scale deployment <name1> <name2> --replicas=<number>

# Escalar com condição
kubectl scale deployment <name> --replicas=<number> --current-replicas=<current>

# Escalar ReplicaSet
kubectl scale replicaset <name> --replicas=<number>

# Escalar StatefulSet
kubectl scale statefulset <name> --replicas=<number>
```

### HPA

```bash
# Criar HPA
kubectl autoscale deployment <name> --cpu-percent=<percent> --min=<min> --max=<max>

# Listar HPAs
kubectl get hpa

# Ver detalhes
kubectl describe hpa <name>

# Deletar HPA
kubectl delete hpa <name>

# Ver métricas
kubectl top pods
kubectl top nodes
```

### Monitoramento

```bash
# Ver uso de recursos
kubectl top pods -l app=<name>
kubectl top nodes

# Ver eventos de scale
kubectl get events --sort-by='.lastTimestamp' | grep -i scale

# Ver histórico de réplicas
kubectl describe deployment <name> | grep -A 10 Events
```

---

## Boas Práticas

### 1. Sempre Defina Resources

```yaml
# ✅ ESSENCIAL para HPA
resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

### 2. Configure Limites Adequados

```yaml
# ✅ BOM
minReplicas: 2     # Mínimo para HA
maxReplicas: 50    # Limite razoável
```

### 3. Use PodDisruptionBudget

```yaml
# pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: webapp-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: webapp
```

### 4. Configure Behavior do HPA

```yaml
# ✅ BOM - evita flapping
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300
  scaleUp:
    stabilizationWindowSeconds: 0
```

### 5. Monitore Métricas

```bash
# ✅ BOM
kubectl top pods -l app=webapp
kubectl get hpa -w
```

---

## Troubleshooting

### HPA não Escala

```bash
# Verificar metrics-server
kubectl get deployment metrics-server -n kube-system

# Verificar métricas disponíveis
kubectl top pods

# Verificar HPA
kubectl describe hpa <name>

# Ver eventos
kubectl get events | grep -i hpa
```

### Pods não Iniciam (Scale Up)

```bash
# Verificar recursos dos nodes
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Verificar eventos
kubectl get events --sort-by='.lastTimestamp'

# Pode precisar de Cluster Autoscaler
```

### Scale Down Muito Lento

```bash
# Verificar configuração
kubectl describe hpa <name> | grep -A 10 Behavior

# Ajustar stabilizationWindowSeconds
kubectl patch hpa <name> -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":60}}}}'
```

---

## Resumo

**Escalonamento Manual:**
- `kubectl scale` - Rápido e simples
- Bom para ajustes pontuais

**HPA (Horizontal Pod Autoscaler):**
- Escala automaticamente baseado em métricas
- Requer resources definidos
- Ideal para cargas variáveis

**VPA (Vertical Pod Autoscaler):**
- Ajusta resources automaticamente
- Complementa HPA
- Útil para otimização

**Cluster Autoscaler:**
- Adiciona/remove nodes
- Trabalha com HPA
- Necessário em clouds

**Fórmula HPA:**
```
desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]
```

**Comandos principais:**
- `kubectl scale` - Manual
- `kubectl autoscale` - Criar HPA
- `kubectl top` - Ver métricas
- `kubectl get hpa` - Ver autoscalers
