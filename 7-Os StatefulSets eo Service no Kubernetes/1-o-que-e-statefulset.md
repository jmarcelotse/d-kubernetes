# O que é um StatefulSet?

## Conceito

**StatefulSet** é um objeto do Kubernetes usado para gerenciar aplicações **stateful** (com estado), ou seja, aplicações que precisam manter dados persistentes e identidade estável entre reinicializações.

Diferente dos Deployments, que são ideais para aplicações stateless, os StatefulSets garantem:

- **Identidade de rede estável e única** para cada Pod
- **Armazenamento persistente** vinculado a cada Pod
- **Ordem garantida** de deploy e scaling
- **Ordem garantida** de rolling updates e rollbacks

## Quando Usar StatefulSets?

Use StatefulSets para aplicações que requerem:

- ✅ Identificadores de rede estáveis e únicos
- ✅ Armazenamento persistente
- ✅ Ordem de deploy e scaling
- ✅ Ordem de rolling updates

### Exemplos de Casos de Uso:

- **Bancos de dados**: MySQL, PostgreSQL, MongoDB
- **Sistemas de mensageria**: Kafka, RabbitMQ
- **Sistemas distribuídos**: Elasticsearch, Cassandra, ZooKeeper
- **Aplicações que precisam de identidade única**: sistemas de cache, filas

## Características Principais

### 1. Identidade Estável

Cada Pod em um StatefulSet recebe um nome único e previsível:

```
<statefulset-name>-<ordinal-index>
```

**Exemplo:**
- `mysql-0`
- `mysql-1`
- `mysql-2`

Mesmo se o Pod for deletado e recriado, ele manterá o mesmo nome.

### 2. Ordem de Criação e Deleção

**Criação**: Os Pods são criados sequencialmente (0, 1, 2...)
- `mysql-0` é criado primeiro
- Só depois que `mysql-0` estiver Running, `mysql-1` é criado
- E assim por diante

**Deleção**: Os Pods são deletados em ordem reversa (2, 1, 0...)
- `mysql-2` é deletado primeiro
- Depois `mysql-1`
- Por último `mysql-0`

### 3. Armazenamento Persistente

Cada Pod pode ter seu próprio PersistentVolumeClaim (PVC), que permanece mesmo se o Pod for deletado.

### 4. Headless Service

StatefulSets geralmente usam um **Headless Service** para fornecer identidade de rede estável para cada Pod.

## Fluxo de Funcionamento

```
┌─────────────────────────────────────────────────────────────┐
│                    StatefulSet: mysql                        │
│                    Replicas: 3                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │     Criação Sequencial dos Pods         │
        └─────────────────────────────────────────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌────────┐           ┌────────┐           ┌────────┐
   │mysql-0 │           │mysql-1 │           │mysql-2 │
   │Running │──espera──▶│Pending │──espera──▶│Pending │
   └────────┘           └────────┘           └────────┘
        │                     │                     │
        ▼                     ▼                     ▼
   ┌────────┐           ┌────────┐           ┌────────┐
   │ PVC-0  │           │ PVC-1  │           │ PVC-2  │
   │  10Gi  │           │  10Gi  │           │  10Gi  │
   └────────┘           └────────┘           └────────┘
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ Headless Service │
                    │   mysql-svc      │
                    └──────────────────┘
                              │
                    DNS Entries Criados:
                    • mysql-0.mysql-svc.default.svc.cluster.local
                    • mysql-1.mysql-svc.default.svc.cluster.local
                    • mysql-2.mysql-svc.default.svc.cluster.local
```

## Exemplo Prático 1: StatefulSet Básico (Nginx)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None  # Headless Service
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx
spec:
  serviceName: "nginx-svc"  # Nome do Headless Service
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
          name: web
```

### Aplicando o Exemplo:

```bash
# Criar o StatefulSet
kubectl apply -f nginx-statefulset.yaml

# Verificar os Pods sendo criados sequencialmente
kubectl get pods -w

# Saída esperada:
# NAME      READY   STATUS    RESTARTS   AGE
# nginx-0   0/1     Pending   0          0s
# nginx-0   0/1     ContainerCreating   0          1s
# nginx-0   1/1     Running   0          3s
# nginx-1   0/1     Pending   0          0s
# nginx-1   0/1     ContainerCreating   0          1s
# nginx-1   1/1     Running   0          3s
# nginx-2   0/1     Pending   0          0s
# nginx-2   0/1     ContainerCreating   0          1s
# nginx-2   1/1     Running   0          3s

# Ver detalhes do StatefulSet
kubectl get statefulset nginx

# Ver os Pods
kubectl get pods -l app=nginx

# Verificar DNS dos Pods
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup nginx-0.nginx-svc
```

## Exemplo Prático 2: StatefulSet com Volumes Persistentes

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-svc
spec:
  ports:
  - port: 3306
  clusterIP: None
  selector:
    app: mysql
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: "mysql-svc"
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "senha123"
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:  # Template para criar PVCs automaticamente
  - metadata:
      name: mysql-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```

### Testando o Exemplo:

```bash
# Aplicar o StatefulSet
kubectl apply -f mysql-statefulset.yaml

# Verificar StatefulSet
kubectl get statefulset mysql

# Verificar Pods
kubectl get pods -l app=mysql

# Verificar PVCs criados automaticamente
kubectl get pvc

# Saída esperada:
# NAME               STATUS   VOLUME    CAPACITY   ACCESS MODES
# mysql-data-mysql-0   Bound    pvc-xxx   10Gi       RWO
# mysql-data-mysql-1   Bound    pvc-yyy   10Gi       RWO
# mysql-data-mysql-2   Bound    pvc-zzz   10Gi       RWO

# Conectar ao primeiro Pod
kubectl exec -it mysql-0 -- mysql -uroot -psenha123

# Criar um banco de dados
mysql> CREATE DATABASE teste;
mysql> USE teste;
mysql> CREATE TABLE usuarios (id INT, nome VARCHAR(50));
mysql> INSERT INTO usuarios VALUES (1, 'João');
mysql> SELECT * FROM usuarios;
mysql> exit;

# Deletar o Pod mysql-0
kubectl delete pod mysql-0

# Aguardar recriação
kubectl get pods -w

# Conectar novamente ao mysql-0 (recriado)
kubectl exec -it mysql-0 -- mysql -uroot -psenha123

# Verificar que os dados persistiram
mysql> USE teste;
mysql> SELECT * FROM usuarios;
# Os dados ainda estão lá!
```

## Exemplo Prático 3: Escalando StatefulSet

```bash
# Ver replicas atuais
kubectl get statefulset mysql

# Escalar para 5 replicas
kubectl scale statefulset mysql --replicas=5

# Observar criação sequencial
kubectl get pods -w

# Saída:
# mysql-3   0/1     Pending   0          0s
# mysql-3   1/1     Running   0          5s
# mysql-4   0/1     Pending   0          0s
# mysql-4   1/1     Running   0          5s

# Reduzir para 2 replicas
kubectl scale statefulset mysql --replicas=2

# Observar deleção em ordem reversa
kubectl get pods -w

# Saída:
# mysql-4   1/1     Terminating   0          2m
# mysql-3   1/1     Terminating   0          3m
# mysql-2   1/1     Terminating   0          5m

# Verificar PVCs (eles NÃO são deletados automaticamente)
kubectl get pvc

# Os PVCs mysql-data-mysql-2, mysql-data-mysql-3, mysql-data-mysql-4 ainda existem!
```

## Exemplo Prático 4: Acessando Pods Individualmente

```bash
# Criar um Pod temporário para testar DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Dentro do Pod, testar resolução DNS
nslookup mysql-0.mysql-svc.default.svc.cluster.local
nslookup mysql-1.mysql-svc.default.svc.cluster.local
nslookup mysql-2.mysql-svc.default.svc.cluster.local

# Cada Pod tem seu próprio endereço DNS estável!

# Testar conectividade
wget -qO- http://nginx-0.nginx-svc.default.svc.cluster.local
wget -qO- http://nginx-1.nginx-svc.default.svc.cluster.local
```

## Comparação: Deployment vs StatefulSet

| Característica | Deployment | StatefulSet |
|----------------|------------|-------------|
| **Nome dos Pods** | Aleatório (nginx-7d8f-xyz) | Ordenado (nginx-0, nginx-1) |
| **Ordem de criação** | Paralela | Sequencial |
| **Ordem de deleção** | Aleatória | Reversa (2, 1, 0) |
| **Identidade de rede** | Não garantida | Estável e única |
| **DNS individual** | Não | Sim (pod-0.service) |
| **Volumes** | Compartilhados ou efêmeros | Persistentes por Pod |
| **Caso de uso** | Apps stateless | Apps stateful |

## Comandos Úteis

```bash
# Criar StatefulSet
kubectl apply -f statefulset.yaml

# Listar StatefulSets
kubectl get statefulset
kubectl get sts  # Forma abreviada

# Detalhes do StatefulSet
kubectl describe statefulset <nome>

# Ver Pods do StatefulSet
kubectl get pods -l app=<label>

# Escalar StatefulSet
kubectl scale statefulset <nome> --replicas=5

# Deletar StatefulSet (mantém PVCs)
kubectl delete statefulset <nome>

# Deletar StatefulSet e Pods (mantém PVCs)
kubectl delete statefulset <nome> --cascade=orphan

# Ver PVCs
kubectl get pvc

# Deletar PVC específico
kubectl delete pvc <nome-pvc>

# Ver eventos do StatefulSet
kubectl get events --sort-by=.metadata.creationTimestamp

# Logs de um Pod específico
kubectl logs mysql-0

# Executar comando em Pod específico
kubectl exec -it mysql-0 -- bash
```

## Fluxo de Update de StatefulSet

```
┌──────────────────────────────────────────────────────────┐
│         kubectl set image statefulset/mysql              │
│              mysql=mysql:8.1                             │
└──────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  Rolling Update (Ordem Reversa)    │
        └────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
   mysql-2 deletado              mysql-1 aguarda
   mysql-2 recriado (nova imagem)       │
        │                                 │
        └─────────────▶ mysql-2 Running  │
                                         ▼
                              mysql-1 deletado
                              mysql-1 recriado
                                         │
                              mysql-1 Running
                                         │
                                         ▼
                              mysql-0 deletado
                              mysql-0 recriado
                                         │
                              mysql-0 Running
                                         │
                                         ▼
                            ┌──────────────────┐
                            │  Update Completo │
                            └──────────────────┘
```

## Exemplo Prático 5: Update de StatefulSet

```bash
# Ver versão atual da imagem
kubectl get statefulset mysql -o jsonpath='{.spec.template.spec.containers[0].image}'

# Atualizar imagem
kubectl set image statefulset/mysql mysql=mysql:8.1

# Observar update em ordem reversa
kubectl rollout status statefulset/mysql

# Ver histórico
kubectl rollout history statefulset/mysql

# Rollback se necessário
kubectl rollout undo statefulset/mysql
```

## Boas Práticas

1. **Sempre use Headless Service** com StatefulSets para DNS estável
2. **Use volumeClaimTemplates** para armazenamento persistente
3. **Configure readiness probes** para garantir ordem correta de inicialização
4. **Não delete PVCs manualmente** a menos que tenha certeza
5. **Use podManagementPolicy: Parallel** apenas se não precisar de ordem
6. **Configure recursos (CPU/memória)** adequadamente
7. **Implemente backups** dos volumes persistentes
8. **Teste rollback** antes de fazer updates em produção

## Limitações

- ❌ Deleção de StatefulSet não deleta PVCs automaticamente
- ❌ Reduzir replicas não deleta PVCs dos Pods removidos
- ❌ Requer um Headless Service para funcionar corretamente
- ❌ Updates são mais lentos (sequenciais)
- ❌ Mais complexo que Deployments

## Resumo

**StatefulSet** é essencial para aplicações que precisam de:
- Identidade estável
- Armazenamento persistente por Pod
- Ordem de deploy/scaling
- DNS individual por Pod

Use para bancos de dados, sistemas distribuídos e qualquer aplicação stateful que precise manter estado entre reinicializações.
