# Removendo o Nosso StatefulSet

## Introdução

Remover um StatefulSet é diferente de remover um Deployment. Por padrão, o Kubernetes **não deleta automaticamente** os PersistentVolumeClaims (PVCs) quando você remove um StatefulSet, para proteger seus dados.

## Comportamento Padrão

Quando você deleta um StatefulSet:

✅ **São deletados:**
- O objeto StatefulSet
- Os Pods gerenciados pelo StatefulSet

❌ **NÃO são deletados:**
- PersistentVolumeClaims (PVCs)
- PersistentVolumes (PVs)
- Services associados

## Formas de Remover StatefulSet

### 1. Deleção Padrão (Cascata)

Remove o StatefulSet e os Pods, mas mantém os PVCs.

```bash
kubectl delete statefulset <nome>
```

### 2. Deleção sem Cascata (Órfão)

Remove apenas o StatefulSet, mantém os Pods e PVCs rodando.

```bash
kubectl delete statefulset <nome> --cascade=orphan
```

### 3. Deleção Completa

Remove StatefulSet, Pods, PVCs e Services.

```bash
# Deletar StatefulSet
kubectl delete statefulset <nome>

# Deletar PVCs
kubectl delete pvc -l app=<label>

# Deletar Services
kubectl delete svc <service-name>
```

## Exemplo Prático 1: Deleção Padrão

### Cenário Inicial:

```bash
# Criar StatefulSet de exemplo
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  clusterIP: None
  ports:
  - port: 80
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-sts
spec:
  serviceName: "nginx-svc"
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
EOF

# Aguardar criação
kubectl get pods -w
```

### Verificar Recursos Criados:

```bash
# Ver StatefulSet
kubectl get statefulset nginx-sts

# Saída:
# NAME        READY   AGE
# nginx-sts   3/3     2m

# Ver Pods
kubectl get pods -l app=nginx

# Saída:
# NAME         READY   STATUS    RESTARTS   AGE
# nginx-sts-0  1/1     Running   0          2m
# nginx-sts-1  1/1     Running   0          2m
# nginx-sts-2  1/1     Running   0          2m

# Ver PVCs
kubectl get pvc

# Saída:
# NAME              STATUS   VOLUME                                     CAPACITY
# www-nginx-sts-0   Bound    pvc-abc123...                              1Gi
# www-nginx-sts-1   Bound    pvc-def456...                              1Gi
# www-nginx-sts-2   Bound    pvc-ghi789...                              1Gi
```

### Deletar StatefulSet (Padrão):

```bash
# Deletar StatefulSet
kubectl delete statefulset nginx-sts

# Saída:
# statefulset.apps "nginx-sts" deleted

# Observar deleção dos Pods em ORDEM REVERSA
kubectl get pods -w

# Saída:
# NAME         READY   STATUS        RESTARTS   AGE
# nginx-sts-2  1/1     Terminating   0          3m
# nginx-sts-2  0/1     Terminating   0          3m10s
# nginx-sts-1  1/1     Terminating   0          3m
# nginx-sts-1  0/1     Terminating   0          3m10s
# nginx-sts-0  1/1     Terminating   0          3m
# nginx-sts-0  0/1     Terminating   0          3m10s
```

### Verificar o que Restou:

```bash
# StatefulSet foi deletado
kubectl get statefulset nginx-sts

# Saída:
# Error from server (NotFound): statefulsets.apps "nginx-sts" not found

# Pods foram deletados
kubectl get pods -l app=nginx

# Saída:
# No resources found in default namespace.

# PVCs AINDA EXISTEM! ✅
kubectl get pvc

# Saída:
# NAME              STATUS   VOLUME                                     CAPACITY
# www-nginx-sts-0   Bound    pvc-abc123...                              1Gi
# www-nginx-sts-1   Bound    pvc-def456...                              1Gi
# www-nginx-sts-2   Bound    pvc-ghi789...                              1Gi

# Service ainda existe
kubectl get svc nginx-svc

# Saída:
# NAME        TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# nginx-svc   ClusterIP   None         <none>        80/TCP    5m
```

## Fluxo de Deleção Padrão

```
┌──────────────────────────────────────────────────────────────┐
│  kubectl delete statefulset nginx-sts                        │
└──────────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   StatefulSet Controller           │
        │   Inicia deleção em ordem reversa  │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Deleta nginx-sts-2               │
        │   (último Pod)                     │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Aguarda nginx-sts-2 terminar     │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Deleta nginx-sts-1               │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Aguarda nginx-sts-1 terminar     │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   Deleta nginx-sts-0               │
        │   (primeiro Pod)                   │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │   StatefulSet deletado             │
        │   Pods deletados                   │
        │   PVCs MANTIDOS ✅                 │
        │   Services MANTIDOS ✅             │
        └────────────────────────────────────┘
```

## Exemplo Prático 2: Deleção sem Cascata (Órfão)

Esta opção remove apenas o StatefulSet, mas mantém os Pods rodando.

```bash
# Criar StatefulSet novamente
kubectl apply -f statefulset.yaml

# Aguardar Pods
kubectl get pods -w

# Deletar StatefulSet SEM deletar Pods
kubectl delete statefulset nginx-sts --cascade=orphan

# Saída:
# statefulset.apps "nginx-sts" deleted

# Verificar StatefulSet foi deletado
kubectl get statefulset

# Saída:
# No resources found in default namespace.

# Pods AINDA ESTÃO RODANDO! ✅
kubectl get pods -l app=nginx

# Saída:
# NAME         READY   STATUS    RESTARTS   AGE
# nginx-sts-0  1/1     Running   0          3m
# nginx-sts-1  1/1     Running   0          3m
# nginx-sts-2  1/1     Running   0          3m

# PVCs ainda existem
kubectl get pvc

# Saída:
# NAME              STATUS   VOLUME        CAPACITY
# www-nginx-sts-0   Bound    pvc-abc...    1Gi
# www-nginx-sts-1   Bound    pvc-def...    1Gi
# www-nginx-sts-2   Bound    pvc-ghi...    1Gi
```

### Quando Usar `--cascade=orphan`?

✅ **Use quando:**
- Quiser atualizar o StatefulSet sem downtime
- Precisar fazer manutenção no StatefulSet
- Quiser migrar Pods para outro StatefulSet

❌ **Não use quando:**
- Quiser remover tudo
- Não precisar dos Pods rodando

### Limpando Pods Órfãos:

```bash
# Deletar Pods manualmente
kubectl delete pod nginx-sts-0 nginx-sts-1 nginx-sts-2

# Ou deletar por label
kubectl delete pods -l app=nginx
```

## Exemplo Prático 3: Deleção Completa

Remove tudo: StatefulSet, Pods, PVCs e Services.

```bash
# Criar StatefulSet novamente
kubectl apply -f statefulset.yaml

# Aguardar criação
kubectl get pods -w

# Passo 1: Deletar StatefulSet e Pods
kubectl delete statefulset nginx-sts

# Passo 2: Deletar PVCs
kubectl delete pvc www-nginx-sts-0 www-nginx-sts-1 www-nginx-sts-2

# Ou deletar todos PVCs com label
kubectl delete pvc -l app=nginx

# Passo 3: Deletar Service
kubectl delete svc nginx-svc

# Verificar que tudo foi removido
kubectl get statefulset,pods,pvc,svc -l app=nginx

# Saída:
# No resources found in default namespace.
```

## Exemplo Prático 4: Deleção com Arquivo YAML

Se você criou com arquivo YAML, pode deletar da mesma forma.

```bash
# Deletar tudo que está no arquivo
kubectl delete -f statefulset.yaml

# Isso deleta:
# - Service
# - StatefulSet
# - Pods
# Mas NÃO deleta PVCs!

# Verificar PVCs ainda existem
kubectl get pvc

# Deletar PVCs manualmente
kubectl delete pvc -l app=nginx
```

## Exemplo Prático 5: Escalar para Zero Antes de Deletar

Método mais controlado para remover StatefulSet.

```bash
# Ver replicas atuais
kubectl get statefulset nginx-sts

# Saída:
# NAME        READY   AGE
# nginx-sts   3/3     5m

# Escalar para 0 replicas
kubectl scale statefulset nginx-sts --replicas=0

# Observar deleção ordenada dos Pods
kubectl get pods -w

# Saída:
# NAME         READY   STATUS        RESTARTS   AGE
# nginx-sts-2  1/1     Terminating   0          5m
# nginx-sts-1  1/1     Terminating   0          5m
# nginx-sts-0  1/1     Terminating   0          5m

# Verificar que não há Pods
kubectl get pods -l app=nginx

# Saída:
# No resources found in default namespace.

# PVCs ainda existem
kubectl get pvc

# Agora deletar StatefulSet
kubectl delete statefulset nginx-sts

# Deletar PVCs se necessário
kubectl delete pvc -l app=nginx
```

## Exemplo Prático 6: Backup Antes de Deletar

Sempre faça backup dos dados antes de deletar PVCs.

```bash
# Ver PVCs
kubectl get pvc

# Saída:
# NAME              STATUS   VOLUME                                     CAPACITY
# www-nginx-sts-0   Bound    pvc-abc123...                              1Gi
# www-nginx-sts-1   Bound    pvc-def456...                              1Gi
# www-nginx-sts-2   Bound    pvc-ghi789...                              1Gi

# Criar Pod temporário para backup
kubectl run backup --image=busybox --restart=Never -- sleep 3600

# Montar PVC no Pod de backup
kubectl set volume pod/backup --add --name=data --type=pvc --claim-name=www-nginx-sts-0 --mount-path=/data

# Copiar dados do PVC
kubectl exec backup -- tar czf /tmp/backup.tar.gz /data

# Copiar backup para local
kubectl cp backup:/tmp/backup.tar.gz ./backup-nginx-sts-0.tar.gz

# Repetir para outros PVCs se necessário

# Deletar Pod de backup
kubectl delete pod backup

# Agora pode deletar PVCs com segurança
kubectl delete pvc www-nginx-sts-0 www-nginx-sts-1 www-nginx-sts-2
```

## Exemplo Prático 7: Verificar Dependências Antes de Deletar

```bash
# Ver todos os recursos relacionados
kubectl get all,pvc,pv -l app=nginx

# Ver eventos recentes
kubectl get events --sort-by=.metadata.creationTimestamp | grep nginx

# Ver se há outros recursos usando os PVCs
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName | contains("nginx-sts"))'

# Ver detalhes dos PVCs
kubectl describe pvc www-nginx-sts-0

# Verificar política de retenção do PV
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy
```

## Fluxo de Deleção Completa

```
┌──────────────────────────────────────────────────────────────┐
│              Deleção Completa do StatefulSet                 │
└──────────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
┌──────────────────┐            ┌──────────────────┐
│ Escalar para 0   │            │ Fazer Backup     │
│ (opcional)       │            │ dos PVCs         │
└──────────────────┘            └──────────────────┘
        │                                 │
        └────────────────┬────────────────┘
                         ▼
        ┌────────────────────────────────────┐
        │  kubectl delete statefulset        │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  Pods deletados em ordem reversa   │
        │  (2 → 1 → 0)                       │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  kubectl delete pvc                │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  PVCs deletados                    │
        │  PVs deletados (se Reclaim=Delete) │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  kubectl delete svc                │
        └────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  Tudo removido ✅                  │
        └────────────────────────────────────┘
```

## Políticas de Retenção de PV

Quando você deleta um PVC, o que acontece com o PV depende da política de retenção.

### Verificar Política:

```bash
# Ver política de retenção dos PVs
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy

# Saída:
# NAME                                       RECLAIM
# pvc-abc123...                              Delete
# pvc-def456...                              Retain
```

### Políticas Disponíveis:

**1. Delete (padrão)**
- PV é deletado automaticamente quando PVC é deletado
- Dados são perdidos permanentemente

**2. Retain**
- PV é mantido quando PVC é deletado
- Dados são preservados
- PV fica em estado "Released"
- Precisa ser limpo manualmente

**3. Recycle (deprecated)**
- Não use mais

### Alterar Política de Retenção:

```bash
# Ver PV atual
kubectl get pv

# Alterar política para Retain (preservar dados)
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

# Alterar política para Delete
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
```

## Comandos Úteis

```bash
# Deletar StatefulSet (mantém PVCs)
kubectl delete statefulset <nome>

# Deletar StatefulSet sem deletar Pods
kubectl delete statefulset <nome> --cascade=orphan

# Deletar StatefulSet e aguardar conclusão
kubectl delete statefulset <nome> --wait=true

# Deletar com timeout
kubectl delete statefulset <nome> --timeout=60s

# Deletar forçadamente (não recomendado)
kubectl delete statefulset <nome> --force --grace-period=0

# Deletar PVCs por nome
kubectl delete pvc www-nginx-sts-0 www-nginx-sts-1 www-nginx-sts-2

# Deletar PVCs por label
kubectl delete pvc -l app=nginx

# Deletar tudo de um arquivo
kubectl delete -f statefulset.yaml

# Deletar tudo com label
kubectl delete all,pvc -l app=nginx

# Escalar para zero
kubectl scale statefulset <nome> --replicas=0

# Ver status da deleção
kubectl get statefulset <nome> -w
kubectl get pods -l app=<label> -w
```

## Troubleshooting

### Pod não termina:

```bash
# Ver status do Pod
kubectl describe pod <pod-name>

# Ver logs
kubectl logs <pod-name>

# Forçar deleção (último recurso)
kubectl delete pod <pod-name> --force --grace-period=0
```

### PVC não deleta (stuck em Terminating):

```bash
# Ver status do PVC
kubectl describe pvc <pvc-name>

# Ver se há Pod usando o PVC
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == "<pvc-name>")'

# Remover finalizers (cuidado!)
kubectl patch pvc <pvc-name> -p '{"metadata":{"finalizers":null}}'
```

### StatefulSet não deleta:

```bash
# Ver status
kubectl describe statefulset <nome>

# Ver eventos
kubectl get events --sort-by=.metadata.creationTimestamp

# Remover finalizers (último recurso)
kubectl patch statefulset <nome> -p '{"metadata":{"finalizers":null}}'
```

## Boas Práticas

1. **Sempre faça backup** antes de deletar PVCs
2. **Escale para 0** antes de deletar (mais controlado)
3. **Verifique dependências** antes de deletar
4. **Use labels** para facilitar deleção em massa
5. **Configure política de retenção** adequada (Retain para produção)
6. **Documente** o processo de deleção
7. **Teste em ambiente de dev** primeiro
8. **Monitore** a deleção com `-w` (watch)
9. **Evite `--force`** a menos que absolutamente necessário
10. **Mantenha Services** se outros recursos os usam

## Checklist de Deleção

```bash
# ✅ Antes de deletar:
□ Fazer backup dos dados
□ Verificar dependências
□ Notificar equipe
□ Testar em ambiente de dev
□ Documentar motivo da deleção

# ✅ Durante a deleção:
□ Escalar para 0 (opcional)
□ Deletar StatefulSet
□ Aguardar Pods terminarem
□ Deletar PVCs (se necessário)
□ Deletar Services (se necessário)

# ✅ Após a deleção:
□ Verificar que tudo foi removido
□ Verificar PVs órfãos
□ Limpar recursos relacionados
□ Atualizar documentação
```

## Exemplo Completo: Script de Deleção Segura

```bash
#!/bin/bash

STATEFULSET_NAME="nginx-sts"
NAMESPACE="default"

echo "🔍 Verificando recursos..."
kubectl get statefulset $STATEFULSET_NAME -n $NAMESPACE

echo "📊 Recursos atuais:"
kubectl get all,pvc -l app=nginx -n $NAMESPACE

echo "⚠️  Deseja continuar? (yes/no)"
read CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Operação cancelada"
    exit 1
fi

echo "📦 Fazendo backup dos PVCs..."
# Adicione lógica de backup aqui

echo "📉 Escalando para 0..."
kubectl scale statefulset $STATEFULSET_NAME --replicas=0 -n $NAMESPACE

echo "⏳ Aguardando Pods terminarem..."
kubectl wait --for=delete pod -l app=nginx --timeout=300s -n $NAMESPACE

echo "🗑️  Deletando StatefulSet..."
kubectl delete statefulset $STATEFULSET_NAME -n $NAMESPACE

echo "🗑️  Deletando PVCs..."
kubectl delete pvc -l app=nginx -n $NAMESPACE

echo "🗑️  Deletando Services..."
kubectl delete svc nginx-svc -n $NAMESPACE

echo "✅ Deleção completa!"
kubectl get all,pvc -l app=nginx -n $NAMESPACE
```

## Resumo

**Deleção Padrão:**
```bash
kubectl delete statefulset <nome>
# Deleta: StatefulSet + Pods
# Mantém: PVCs + Services
```

**Deleção Órfã:**
```bash
kubectl delete statefulset <nome> --cascade=orphan
# Deleta: StatefulSet
# Mantém: Pods + PVCs + Services
```

**Deleção Completa:**
```bash
kubectl delete statefulset <nome>
kubectl delete pvc -l app=<label>
kubectl delete svc <service-name>
# Deleta: Tudo
```

**Sempre lembre:**
- PVCs não são deletados automaticamente
- Faça backup antes de deletar
- Use `--cascade=orphan` para manutenção sem downtime
- Verifique política de retenção dos PVs
