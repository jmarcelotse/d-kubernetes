# kubectl get pods e kubectl describe pods

## kubectl get pods

Comando usado para **listar** os Pods em execução no cluster Kubernetes.

### Sintaxe básica

```bash
kubectl get pods
```

### Saída padrão

```
NAME                     READY   STATUS    RESTARTS   AGE
nginx-pod                1/1     Running   0          5m
app-deployment-abc123    2/2     Running   1          2h
```

### Opções úteis

```bash
# Listar pods em um namespace específico
kubectl get pods -n <namespace>

# Listar pods de todos os namespaces
kubectl get pods --all-namespaces
kubectl get pods -A

# Mostrar mais informações (IP, nó)
kubectl get pods -o wide

# Formato JSON
kubectl get pods -o json

# Formato YAML
kubectl get pods -o yaml

# Filtrar por label
kubectl get pods -l app=nginx

# Monitorar em tempo real
kubectl get pods --watch
kubectl get pods -w

# Mostrar apenas nomes
kubectl get pods -o name
```

### Colunas da saída

- **NAME**: Nome do Pod
- **READY**: Containers prontos / Total de containers
- **STATUS**: Estado atual (Running, Pending, Failed, etc.)
- **RESTARTS**: Número de vezes que o container foi reiniciado
- **AGE**: Tempo desde a criação do Pod

---

## kubectl describe pods

Comando usado para obter **informações detalhadas** sobre um Pod específico.

### Sintaxe básica

```bash
kubectl describe pod <nome-do-pod>
```

### O que mostra

#### 1. Informações básicas
- Nome, namespace, labels, annotations
- Status e IP do Pod
- Nó onde está executando

#### 2. Containers
- Imagens utilizadas
- Portas expostas
- Comandos e argumentos
- Variáveis de ambiente
- Montagens de volumes

#### 3. Condições
- PodScheduled
- Initialized
- ContainersReady
- Ready

#### 4. Recursos
- Requests e limits de CPU/memória
- QoS Class

#### 5. Eventos
- Histórico de eventos do Pod
- Erros de pull de imagem
- Problemas de agendamento
- Reinicializações

### Exemplo de uso

```bash
# Descrever um pod específico
kubectl describe pod nginx-pod

# Descrever pod em namespace específico
kubectl describe pod nginx-pod -n production

# Descrever todos os pods
kubectl describe pods
```

### Quando usar

- **Troubleshooting**: Investigar por que um Pod não está funcionando
- **Debug**: Ver logs de eventos e erros
- **Verificação**: Confirmar configurações aplicadas
- **Análise**: Entender o estado completo do Pod

---

## Diferenças principais

| kubectl get pods | kubectl describe pods |
|------------------|----------------------|
| Visão resumida | Visão detalhada |
| Lista múltiplos Pods | Foco em um Pod específico |
| Informações tabulares | Informações descritivas |
| Rápido para overview | Completo para troubleshooting |
| Mostra status atual | Mostra histórico e eventos |

---

## Fluxo típico de diagnóstico

```bash
# 1. Listar todos os pods
kubectl get pods

# 2. Identificar pod com problema
kubectl get pods | grep -i error

# 3. Ver detalhes do pod problemático
kubectl describe pod <nome-do-pod>

# 4. Ver logs do container (se necessário)
kubectl logs <nome-do-pod>
```

## Dicas

- Use `kubectl get pods -w` para monitorar mudanças em tempo real
- `kubectl describe` é essencial para debug - sempre verifique a seção "Events"
- Combine com `grep` para filtrar informações específicas
- Use `-o wide` para ver em qual nó o Pod está executando
