# Lição de Casa - Deployments

Esta pasta contém 3 exemplos práticos de Deployments com diferentes configurações.

## 1. Deployment com Limites de Recursos

**Arquivo:** `1-deployment-limites-recursos.yaml`

Define limites de CPU e memória para os containers:
- **Requests:** Recursos mínimos garantidos (250m CPU, 64Mi RAM)
- **Limits:** Recursos máximos permitidos (500m CPU, 128Mi RAM)

```bash
kubectl apply -f 1-deployment-limites-recursos.yaml
kubectl get deployment nginx-limites
kubectl describe deployment nginx-limites
```

## 2. Deployment com Probes

**Arquivo:** `2-deployment-probes.yaml`

Implementa as 3 probes do Kubernetes:
- **startupProbe:** Verifica se a aplicação iniciou (5s delay, 5s período)
- **livenessProbe:** Verifica se o container está vivo (10s delay, 10s período)
- **readinessProbe:** Verifica se o container está pronto para receber tráfego (5s delay, 5s período)

```bash
kubectl apply -f 2-deployment-probes.yaml
kubectl get pods -l app=nginx-probes
kubectl describe pod <pod-name>
```

## 3. Deployment com Estratégia de Rollout

**Arquivo:** `3-deployment-estrategia-rollout.yaml`

Configura estratégia RollingUpdate customizada:
- **maxSurge: 2** - Permite até 2 pods extras durante atualização
- **maxUnavailable: 1** - Permite no máximo 1 pod indisponível

```bash
kubectl apply -f 3-deployment-estrategia-rollout.yaml
kubectl get deployment nginx-rollout
kubectl rollout status deployment/nginx-rollout

# Testar rollout
kubectl set image deployment/nginx-rollout nginx=nginx:1.25
kubectl rollout status deployment/nginx-rollout
kubectl rollout history deployment/nginx-rollout

# Rollback se necessário
kubectl rollout undo deployment/nginx-rollout
```

## Comandos Úteis

```bash
# Aplicar todos os deployments
kubectl apply -f .

# Ver todos os deployments
kubectl get deployments

# Ver todos os pods
kubectl get pods

# Deletar todos os recursos
kubectl delete -f .
```
