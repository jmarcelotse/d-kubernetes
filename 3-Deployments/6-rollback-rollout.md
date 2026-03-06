# Fazendo Rollback e Conhecendo o Comando Rollout

## Visão Geral

O comando `kubectl rollout` gerencia o ciclo de vida de atualizações de Deployments, permitindo:
- Verificar status de atualizações
- Ver histórico de revisões
- Fazer rollback para versões anteriores
- Pausar e retomar atualizações
- Reiniciar deployments

---

## Comando kubectl rollout

### Subcomandos Principais

```bash
kubectl rollout status      # Ver status da atualização
kubectl rollout history     # Ver histórico de revisões
kubectl rollout undo        # Fazer rollback
kubectl rollout pause       # Pausar atualização
kubectl rollout resume      # Retomar atualização
kubectl rollout restart     # Reiniciar deployment
```

---

## 1. kubectl rollout status

Verifica o status de uma atualização em andamento.

### Exemplo 1: Ver Status de Atualização

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx:1.21 --replicas=5

# Iniciar atualização
kubectl set image deployment/nginx nginx=nginx:1.22

# Ver status (aguarda conclusão)
kubectl rollout status deployment/nginx

# Saída:
# Waiting for deployment "nginx" rollout to finish: 2 out of 5 new replicas have been updated...
# Waiting for deployment "nginx" rollout to finish: 3 out of 5 new replicas have been updated...
# Waiting for deployment "nginx" rollout to finish: 4 out of 5 new replicas have been updated...
# deployment "nginx" successfully rolled out

# Ver status sem aguardar
kubectl rollout status deployment/nginx --watch=false
```

### Exemplo 2: Status de Múltiplos Deployments

```bash
# Criar vários deployments
kubectl create deployment web --image=nginx:1.21 --replicas=3
kubectl create deployment api --image=node:18 --replicas=2
kubectl create deployment cache --image=redis:7 --replicas=1

# Atualizar todos
kubectl set image deployment/web web=nginx:1.22
kubectl set image deployment/api api=node:19
kubectl set image deployment/cache cache=redis:7.2

# Ver status de cada um
kubectl rollout status deployment/web
kubectl rollout status deployment/api
kubectl rollout status deployment/cache

# Script para ver todos
for deploy in web api cache; do
  echo "=== $deploy ==="
  kubectl rollout status deployment/$deploy --watch=false
done
```

---

## 2. kubectl rollout history

Mostra o histórico de revisões de um Deployment.

### Exemplo 3: Ver Histórico

```bash
# Criar deployment
kubectl create deployment webapp --image=nginx:1.21 --replicas=3

# Fazer várias atualizações
kubectl set image deployment/webapp webapp=nginx:1.22
kubectl rollout status deployment/webapp

kubectl set image deployment/webapp webapp=nginx:1.23
kubectl rollout status deployment/webapp

kubectl set image deployment/webapp webapp=nginx:1.24
kubectl rollout status deployment/webapp

# Ver histórico completo
kubectl rollout history deployment/webapp

# Saída:
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>
# 3         <none>
# 4         <none>
```

### Exemplo 4: Histórico com Anotações

```bash
# Criar deployment
kubectl create deployment webapp --image=nginx:1.21 --replicas=3

# Atualizar com --record (deprecated mas útil)
kubectl set image deployment/webapp webapp=nginx:1.22 --record

# Ou adicionar anotação manualmente
kubectl annotate deployment/webapp kubernetes.io/change-cause="Atualizado para nginx 1.23"
kubectl set image deployment/webapp webapp=nginx:1.23

# Ver histórico (agora com descrições)
kubectl rollout history deployment/webapp

# Saída:
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         kubectl set image deployment/webapp webapp=nginx:1.22 --record=true
# 3         Atualizado para nginx 1.23
```

### Exemplo 5: Ver Detalhes de uma Revisão

```bash
# Ver histórico
kubectl rollout history deployment/webapp

# Ver detalhes da revisão 2
kubectl rollout history deployment/webapp --revision=2

# Saída mostra:
# - Labels
# - Annotations
# - Containers
# - Image
# - Environment variables
# - Volumes
```

---

## 3. kubectl rollout undo (Rollback)

Reverte o Deployment para uma versão anterior.

### Exemplo 6: Rollback Simples

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx:1.21 --replicas=3

# Atualizar para versão com problema
kubectl set image deployment/nginx nginx=nginx:broken-tag

# Ver que falhou
kubectl get pods -l app=nginx
# Pods em ImagePullBackOff

# Fazer rollback para versão anterior
kubectl rollout undo deployment/nginx

# Verificar
kubectl rollout status deployment/nginx
kubectl get pods -l app=nginx
# Pods voltaram para nginx:1.21
```

### Exemplo 7: Rollback para Revisão Específica

```bash
# Criar deployment
kubectl create deployment webapp --image=nginx:1.21 --replicas=3

# Fazer várias atualizações
kubectl set image deployment/webapp webapp=nginx:1.22
kubectl rollout status deployment/webapp

kubectl set image deployment/webapp webapp=nginx:1.23
kubectl rollout status deployment/webapp

kubectl set image deployment/webapp webapp=nginx:broken
# Falhou

# Ver histórico
kubectl rollout history deployment/webapp
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>
# 3         <none>
# 4         <none>

# Fazer rollback para revisão 2 (nginx:1.22)
kubectl rollout undo deployment/webapp --to-revision=2

# Verificar
kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
# nginx:1.22
```

### Exemplo 8: Rollback com Dry-run

```bash
# Ver o que aconteceria sem aplicar
kubectl rollout undo deployment/webapp --dry-run=client

# Ver para qual revisão voltaria
kubectl rollout history deployment/webapp

# Fazer rollback de verdade
kubectl rollout undo deployment/webapp
```

---

## 4. kubectl rollout pause/resume

Pausa e retoma atualizações em andamento.

### Exemplo 9: Pausar Atualização

```bash
# Criar deployment
kubectl create deployment webapp --image=nginx:1.21 --replicas=10

# Iniciar atualização
kubectl set image deployment/webapp webapp=nginx:1.22

# Pausar imediatamente
kubectl rollout pause deployment/webapp

# Ver status (alguns pods atualizados, outros não)
kubectl get pods -l app=webapp -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# Ver deployment
kubectl get deployment webapp
# Mostra que está pausado

# Testar se nova versão está ok
kubectl port-forward deployment/webapp 8080:80
curl http://localhost:8080

# Se ok, retomar
kubectl rollout resume deployment/webapp

# Se não ok, fazer rollback
kubectl rollout undo deployment/webapp
```

### Exemplo 10: Canary com Pause

```bash
# Criar deployment
kubectl create deployment webapp --image=nginx:1.21 --replicas=10

# Configurar para atualizar apenas 2 pods por vez
kubectl patch deployment webapp -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":2,"maxUnavailable":0}}}}'

# Iniciar atualização
kubectl set image deployment/webapp webapp=nginx:1.22

# Pausar após primeiros pods
sleep 5
kubectl rollout pause deployment/webapp

# Verificar quantos foram atualizados
kubectl get pods -l app=webapp -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image | grep 1.22 | wc -l

# Monitorar logs dos novos pods
kubectl logs -l app=webapp -l version=new -f

# Se ok após 5 minutos, retomar
kubectl rollout resume deployment/webapp

# Acompanhar conclusão
kubectl rollout status deployment/webapp
```

---

## 5. kubectl rollout restart

Reinicia todos os pods do Deployment sem mudar a imagem.

### Exemplo 11: Restart Básico

```bash
# Criar deployment
kubectl create deployment webapp --image=nginx:alpine --replicas=3

# Ver pods atuais
kubectl get pods -l app=webapp

# Reiniciar deployment (recria todos os pods)
kubectl rollout restart deployment/webapp

# Ver novos pods sendo criados
kubectl get pods -l app=webapp -w

# Uso: útil para:
# - Aplicar mudanças de ConfigMap/Secret
# - Forçar pull de imagem :latest
# - Resolver problemas temporários
```

### Exemplo 12: Restart Após Atualizar ConfigMap

```bash
# Criar ConfigMap
kubectl create configmap app-config --from-literal=ENV=production

# Criar deployment que usa ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
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
      - name: webapp
        image: nginx:alpine
        envFrom:
        - configMapRef:
            name: app-config
EOF

# Atualizar ConfigMap
kubectl create configmap app-config --from-literal=ENV=staging --dry-run=client -o yaml | kubectl apply -f -

# Reiniciar deployment para aplicar mudanças
kubectl rollout restart deployment/webapp

# Verificar nova variável
kubectl exec deployment/webapp -- env | grep ENV
```

---

## Fluxo de Rollback

```
┌─────────────────────────────────────────────────────────┐
│         FLUXO DE ROLLBACK                               │
└─────────────────────────────────────────────────────────┘

1. ATUALIZAÇÃO FALHA
   ├─> kubectl set image deployment/app app=broken:tag
   └─> Pods em CrashLoopBackOff ou ImagePullBackOff

2. DETECTAR PROBLEMA
   ├─> kubectl get pods -l app=app
   ├─> kubectl describe pod <pod-name>
   └─> kubectl logs <pod-name>

3. VER HISTÓRICO
   └─> kubectl rollout history deployment/app

4. FAZER ROLLBACK
   ├─> kubectl rollout undo deployment/app
   └─> Ou: kubectl rollout undo deployment/app --to-revision=N

5. KUBERNETES EXECUTA
   ├─> Deployment Controller detecta mudança
   ├─> Escala ReplicaSet antigo (versão boa)
   ├─> Escala ReplicaSet novo (versão ruim) para 0
   └─> Rolling update reverso

6. VERIFICAR
   ├─> kubectl rollout status deployment/app
   ├─> kubectl get pods -l app=app
   └─> kubectl get deployment app -o jsonpath='{.spec.template.spec.containers[0].image}'

7. APLICAÇÃO RESTAURADA
   └─> Pods rodando versão anterior (estável)
```

---

## Exemplo Prático Completo

```bash
# 1. Criar deployment inicial
kubectl create deployment webapp --image=nginx:1.21 --replicas=5

# 2. Verificar
kubectl get deployment webapp
kubectl get pods -l app=webapp

# 3. Primeira atualização (sucesso)
kubectl set image deployment/webapp webapp=nginx:1.22
kubectl rollout status deployment/webapp
echo "Atualização 1 concluída"

# 4. Segunda atualização (sucesso)
kubectl set image deployment/webapp webapp=nginx:1.23
kubectl rollout status deployment/webapp
echo "Atualização 2 concluída"

# 5. Ver histórico até agora
kubectl rollout history deployment/webapp

# 6. Terceira atualização (falha)
kubectl set image deployment/webapp webapp=nginx:broken-tag
sleep 10

# 7. Verificar que falhou
kubectl get pods -l app=webapp
kubectl describe pod -l app=webapp | grep -A 5 Events

# 8. Ver histórico
kubectl rollout history deployment/webapp

# 9. Fazer rollback para versão anterior (1.23)
kubectl rollout undo deployment/webapp

# 10. Acompanhar rollback
kubectl rollout status deployment/webapp

# 11. Verificar que voltou
kubectl get pods -l app=webapp
kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

# 12. Ver histórico atualizado
kubectl rollout history deployment/webapp

# 13. Simular outro problema e fazer rollback para revisão específica
kubectl set image deployment/webapp webapp=nginx:another-broken
sleep 10

# 14. Rollback para revisão 2 (nginx:1.22)
kubectl rollout undo deployment/webapp --to-revision=2

# 15. Verificar
kubectl rollout status deployment/webapp
kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

# 16. Ver histórico final
kubectl rollout history deployment/webapp

# 17. Limpar
kubectl delete deployment webapp
```

---

## Exemplo com Pause e Resume

```bash
# 1. Criar deployment
kubectl create deployment webapp --image=nginx:1.21 --replicas=10

# 2. Configurar estratégia conservadora
kubectl patch deployment webapp -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'

# 3. Iniciar atualização
kubectl set image deployment/webapp webapp=nginx:1.22

# 4. Pausar após 3 segundos
sleep 3
kubectl rollout pause deployment/webapp

# 5. Ver estado (parcialmente atualizado)
echo "=== Pods atuais ==="
kubectl get pods -l app=webapp -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# 6. Contar pods de cada versão
echo "=== Contagem ==="
echo "Pods v1.21: $(kubectl get pods -l app=webapp -o jsonpath='{.items[*].spec.containers[0].image}' | tr ' ' '\n' | grep 1.21 | wc -l)"
echo "Pods v1.22: $(kubectl get pods -l app=webapp -o jsonpath='{.items[*].spec.containers[0].image}' | tr ' ' '\n' | grep 1.22 | wc -l)"

# 7. Testar nova versão
echo "=== Testando nova versão ==="
POD=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}' | grep 1.22)
kubectl exec $POD -- nginx -v

# 8. Decidir: retomar ou rollback
read -p "Retomar atualização? (s/n): " resposta

if [ "$resposta" = "s" ]; then
  echo "Retomando..."
  kubectl rollout resume deployment/webapp
  kubectl rollout status deployment/webapp
else
  echo "Fazendo rollback..."
  kubectl rollout undo deployment/webapp
  kubectl rollout status deployment/webapp
fi

# 9. Ver resultado final
kubectl get pods -l app=webapp -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
```

---

## Comandos Úteis

### Status e Histórico

```bash
# Ver status
kubectl rollout status deployment/<name>
kubectl rollout status deployment/<name> --watch=false

# Ver histórico
kubectl rollout history deployment/<name>

# Ver detalhes de revisão
kubectl rollout history deployment/<name> --revision=<number>

# Ver todas as revisões com detalhes
for rev in $(kubectl rollout history deployment/<name> | tail -n +2 | awk '{print $1}'); do
  echo "=== Revision $rev ==="
  kubectl rollout history deployment/<name> --revision=$rev
done
```

### Rollback

```bash
# Rollback para versão anterior
kubectl rollout undo deployment/<name>

# Rollback para revisão específica
kubectl rollout undo deployment/<name> --to-revision=<number>

# Dry-run
kubectl rollout undo deployment/<name> --dry-run=client
```

### Controle

```bash
# Pausar
kubectl rollout pause deployment/<name>

# Retomar
kubectl rollout resume deployment/<name>

# Reiniciar
kubectl rollout restart deployment/<name>
```

### Monitoramento

```bash
# Ver pods durante rollout
kubectl get pods -l app=<name> -w

# Ver eventos
kubectl get events --sort-by='.lastTimestamp' | grep <name>

# Ver ReplicaSets
kubectl get rs -l app=<name>

# Ver imagem atual
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## Configuração de Histórico

### Exemplo 13: Limitar Revisões Mantidas

```yaml
# deployment-history-limit.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  revisionHistoryLimit: 5    # Mantém apenas 5 revisões
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
# Aplicar
kubectl apply -f deployment-history-limit.yaml

# Fazer várias atualizações
for i in {1..10}; do
  kubectl set image deployment/webapp webapp=nginx:1.2$i
  kubectl rollout status deployment/webapp
done

# Ver histórico (apenas últimas 5)
kubectl rollout history deployment/webapp

# Ver ReplicaSets (apenas 6: 5 antigas + 1 atual)
kubectl get rs -l app=webapp
```

---

## Troubleshooting

### Rollback não Funciona

```bash
# Verificar se há histórico
kubectl rollout history deployment/<name>

# Se não houver histórico, não pode fazer rollback
# Solução: aplicar versão anterior manualmente
kubectl set image deployment/<name> container=image:old-tag
```

### Rollout Travado

```bash
# Ver status
kubectl rollout status deployment/<name>

# Ver pods
kubectl get pods -l app=<name>

# Ver eventos
kubectl describe deployment <name>

# Forçar rollback
kubectl rollout undo deployment/<name>
```

### Histórico Perdido

```bash
# Histórico é mantido em ReplicaSets antigos
kubectl get rs -l app=<name>

# Se ReplicaSets foram deletados, histórico é perdido
# Solução: não deletar ReplicaSets manualmente
```

---

## Boas Práticas

### 1. Sempre Monitore Rollouts

```bash
# ✅ BOM
kubectl set image deployment/app app=new:tag
kubectl rollout status deployment/app
```

### 2. Use Anotações para Histórico

```bash
# ✅ BOM
kubectl annotate deployment/app kubernetes.io/change-cause="Atualizado para v2.0"
kubectl set image deployment/app app=new:tag
```

### 3. Configure revisionHistoryLimit

```yaml
# ✅ BOM
spec:
  revisionHistoryLimit: 10    # Mantém 10 revisões
```

### 4. Teste Antes de Produção

```bash
# ✅ BOM
# Testar em dev/staging primeiro
kubectl set image deployment/app app=new:tag -n staging
kubectl rollout status deployment/app -n staging
# Se ok, aplicar em produção
```

### 5. Use Pause para Canary

```bash
# ✅ BOM
kubectl set image deployment/app app=new:tag
sleep 5
kubectl rollout pause deployment/app
# Monitorar, testar
kubectl rollout resume deployment/app
```

---

## Resumo

**kubectl rollout status:**
- Ver progresso de atualização
- Aguarda conclusão

**kubectl rollout history:**
- Ver histórico de revisões
- Ver detalhes de cada revisão

**kubectl rollout undo:**
- Fazer rollback para versão anterior
- Ou para revisão específica

**kubectl rollout pause/resume:**
- Pausar atualização em andamento
- Retomar quando pronto

**kubectl rollout restart:**
- Reiniciar pods sem mudar imagem
- Útil para aplicar ConfigMaps/Secrets

**Fluxo típico:**
1. Atualizar deployment
2. Monitorar com `rollout status`
3. Se falhar, fazer `rollout undo`
4. Verificar com `rollout history`
