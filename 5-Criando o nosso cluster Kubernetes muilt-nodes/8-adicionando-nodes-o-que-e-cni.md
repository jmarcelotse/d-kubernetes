# Adicionando Nodes ao Cluster e O que é CNI

Este guia explica como adicionar workers ao cluster Kubernetes e o que é CNI (Container Network Interface).

## O que é CNI?

**CNI (Container Network Interface)** é uma especificação e conjunto de bibliotecas para configurar interfaces de rede em containers Linux.

```
┌─────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                  │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │  Pod 1   │  │  Pod 2   │  │  Pod 3   │         │
│  │10.244.1.5│  │10.244.2.3│  │10.244.3.7│         │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘         │
│       │             │             │                 │
│  ┌────▼─────────────▼─────────────▼─────┐         │
│  │         CNI Plugin (Calico)           │         │
│  │  - Atribui IPs aos pods               │         │
│  │  - Cria rotas entre nodes             │         │
│  │  - Implementa Network Policies        │         │
│  └───────────────────────────────────────┘         │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │ Worker 1 │  │ Worker 2 │  │ Worker 3 │         │
│  └──────────┘  └──────────┘  └──────────┘         │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Funções do CNI

1. **Atribuir IPs** aos pods
2. **Criar rotas** de rede entre pods
3. **Implementar Network Policies** (firewall)
4. **Gerenciar conectividade** entre nodes

### Plugins CNI Populares

| Plugin | Características | Uso |
|--------|----------------|-----|
| **Calico** | BGP, Network Policies avançadas | Produção |
| **Flannel** | Simples, overlay network | Dev/Simples |
| **Cilium** | eBPF, alta performance | Produção/Edge |
| **Weave** | Simples, criptografia | Dev |
| **Canal** | Calico + Flannel | Híbrido |

## 1. Instalar CNI no Cluster

### Por que Instalar CNI Primeiro?

Sem CNI, os nós ficam **NotReady** e os pods não conseguem se comunicar.

```bash
# Antes do CNI
kubectl get nodes
# NAME           STATUS     ROLES           AGE   VERSION
# k8s-master-1   NotReady   control-plane   5m    v1.28.0

# Depois do CNI
kubectl get nodes
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master-1   Ready    control-plane   5m    v1.28.0
```

### Instalar Calico (Recomendado)

```bash
# No master node
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Aguardar pods do Calico ficarem prontos
kubectl get pods -n kube-system -w

# Verificar pods do Calico
kubectl get pods -n kube-system | grep calico

# Saída esperada:
# calico-kube-controllers-xxx   1/1     Running   0          2m
# calico-node-xxx               1/1     Running   0          2m

# Verificar nó agora está Ready
kubectl get nodes
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master-1   Ready    control-plane   7m    v1.28.0
```

### Instalar Flannel (Alternativa)

```bash
# No master node
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Verificar
kubectl get pods -n kube-system | grep flannel
```

### Instalar Cilium (Avançado)

```bash
# Instalar Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz

# Instalar Cilium no cluster
cilium install

# Verificar status
cilium status
```

## 2. Obter Comando de Join

### No Master Node

```bash
# Gerar comando de join
kubeadm token create --print-join-command

# Saída:
# kubeadm join 10.0.1.10:6443 --token abcdef.0123456789abcdef \
#     --discovery-token-ca-cert-hash sha256:1234567890abcdef...

# Salvar em arquivo
kubeadm token create --print-join-command > ~/join-command.sh
chmod +x ~/join-command.sh

# Ver comando
cat ~/join-command.sh
```

### Componentes do Comando de Join

```bash
kubeadm join <MASTER-IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

- **MASTER-IP**: IP do control plane
- **TOKEN**: Token de autenticação (válido por 24h)
- **HASH**: Hash do certificado CA (segurança)

### Listar Tokens Existentes

```bash
# Ver tokens
kubeadm token list

# Saída:
# TOKEN                     TTL         EXPIRES                USAGES
# abcdef.0123456789abcdef   23h         2024-01-02T10:00:00Z   authentication,signing

# Criar novo token (se expirou)
kubeadm token create

# Criar token com TTL customizado
kubeadm token create --ttl 48h
```

### Obter Hash do CA

```bash
# Se perdeu o hash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | \
  sed 's/^.* //'
```

## 3. Adicionar Workers ao Cluster

### Preparar Worker Nodes

Antes de fazer join, garantir que os workers estão preparados:

```bash
# Em cada worker, verificar:

# 1. Swap desabilitado
free -h | grep Swap
# Deve mostrar: Swap: 0B

# 2. containerd rodando
sudo systemctl status containerd

# 3. kubelet instalado
kubelet --version

# 4. Módulos carregados
lsmod | grep br_netfilter
lsmod | grep overlay
```

### Executar Join em Cada Worker

```bash
# SSH no worker
ssh -i ~/.ssh/id_rsa ubuntu@<IP-WORKER>

# Executar comando de join (como root)
sudo kubeadm join 10.0.1.10:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef...

# Saída esperada:
# [preflight] Running pre-flight checks
# [preflight] Reading configuration from the cluster...
# [preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
# [kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
# [kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
# [kubelet-start] Starting the kubelet
# [kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...
#
# This node has joined the cluster:
# * Certificate signing request was sent to apiserver and a response was received.
# * The Kubelet was informed of the new secure connection details.
#
# Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

### Automatizar Join em Todos os Workers

```bash
# Na máquina local, com inventory.ini

# Obter comando de join do master
MASTER_IP=$(cat inventory.ini | grep k8s-master-1 | awk '{print $2}' | cut -d= -f2)
JOIN_CMD=$(ssh -i ~/.ssh/id_rsa ubuntu@$MASTER_IP "kubeadm token create --print-join-command")

echo "Comando de join: $JOIN_CMD"

# Executar em todos os workers
for ip in $(cat inventory.ini | grep k8s-worker | awk '{print $2}' | cut -d= -f2); do
    echo "Adicionando worker $ip ao cluster..."
    ssh -i ~/.ssh/id_rsa ubuntu@$ip "sudo $JOIN_CMD"
    echo "✅ Worker $ip adicionado"
done
```

### Script Completo

```bash
#!/bin/bash
# add-workers.sh - Adicionar todos os workers ao cluster

set -e

INVENTORY="inventory.ini"
SSH_KEY="~/.ssh/id_rsa"

echo "=== Adicionando Workers ao Cluster ==="

# Obter IP público do master
MASTER_IP=$(cat $INVENTORY | grep k8s-master-1 | awk '{print $2}' | cut -d= -f2)
echo "Master IP: $MASTER_IP"

# Obter comando de join
echo "Obtendo comando de join..."
JOIN_CMD=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubeadm token create --print-join-command")

if [ -z "$JOIN_CMD" ]; then
    echo "❌ Erro ao obter comando de join"
    exit 1
fi

echo "Comando de join: $JOIN_CMD"
echo ""

# Adicionar cada worker
for ip in $(cat $INVENTORY | grep k8s-worker | awk '{print $2}' | cut -d= -f2); do
    WORKER_NAME=$(cat $INVENTORY | grep $ip | awk '{print $1}')
    echo "Adicionando $WORKER_NAME ($ip)..."
    
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$ip "sudo $JOIN_CMD" && \
        echo "✅ $WORKER_NAME adicionado com sucesso" || \
        echo "❌ Erro ao adicionar $WORKER_NAME"
    
    echo ""
done

echo "=== Verificando nodes no cluster ==="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "kubectl get nodes"

echo ""
echo "=== Workers adicionados com sucesso! ==="
```

## 4. Verificar Workers no Cluster

### No Master Node

```bash
# Ver todos os nós
kubectl get nodes

# Saída esperada:
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master-1   Ready    control-plane   15m   v1.28.0
# k8s-worker-1   Ready    <none>          2m    v1.28.0
# k8s-worker-2   Ready    <none>          2m    v1.28.0
# k8s-worker-3   Ready    <none>          2m    v1.28.0

# Ver detalhes de um nó
kubectl describe node k8s-worker-1

# Ver com mais informações
kubectl get nodes -o wide

# Saída:
# NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION
# k8s-master-1   Ready    control-plane   15m   v1.28.0   10.0.1.10     <none>        Ubuntu 22.04.3 LTS   5.15.0-xxx
# k8s-worker-1   Ready    <none>          2m    v1.28.0   10.0.1.20     <none>        Ubuntu 22.04.3 LTS   5.15.0-xxx
# k8s-worker-2   Ready    <none>          2m    v1.28.0   10.0.1.21     <none>        Ubuntu 22.04.3 LTS   5.15.0-xxx
# k8s-worker-3   Ready    <none>          2m    v1.28.0   10.0.1.22     <none>        Ubuntu 22.04.3 LTS   5.15.0-xxx
```

### Ver Pods do Sistema

```bash
# Ver todos os pods do sistema
kubectl get pods -n kube-system -o wide

# Ver pods do CNI em cada nó
kubectl get pods -n kube-system -o wide | grep calico-node

# Saída:
# calico-node-xxxxx   1/1   Running   0   5m   10.0.1.10   k8s-master-1
# calico-node-yyyyy   1/1   Running   0   2m   10.0.1.20   k8s-worker-1
# calico-node-zzzzz   1/1   Running   0   2m   10.0.1.21   k8s-worker-2
# calico-node-wwwww   1/1   Running   0   2m   10.0.1.22   k8s-worker-3
```

## 5. Testar Conectividade entre Pods

### Criar Deployment de Teste

```bash
# Criar deployment com 4 réplicas
kubectl create deployment nginx --image=nginx --replicas=4

# Ver pods distribuídos nos workers
kubectl get pods -o wide

# Saída:
# NAME                     READY   STATUS    NODE
# nginx-7854ff8877-abc12   1/1     Running   k8s-worker-1
# nginx-7854ff8877-def34   1/1     Running   k8s-worker-2
# nginx-7854ff8877-ghi56   1/1     Running   k8s-worker-3
# nginx-7854ff8877-jkl78   1/1     Running   k8s-worker-1
```

### Testar Comunicação entre Pods

```bash
# Obter IP de um pod
POD_IP=$(kubectl get pod -l app=nginx -o jsonpath='{.items[0].status.podIP}')
echo "Pod IP: $POD_IP"

# Criar pod de teste
kubectl run test --image=busybox --rm -it --restart=Never -- sh

# Dentro do pod de teste
wget -qO- http://$POD_IP
# Deve retornar HTML do nginx

# Testar DNS
nslookup kubernetes.default
# Deve resolver o IP do service do Kubernetes
```

### Expor como Service

```bash
# Criar service NodePort
kubectl expose deployment nginx --port=80 --type=NodePort

# Ver service
kubectl get svc nginx

# Saída:
# NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# nginx   NodePort   10.96.123.456   <none>        80:30123/TCP   10s

# Testar acesso via NodePort (de qualquer worker)
WORKER_IP=$(kubectl get nodes -o jsonpath='{.items[1].status.addresses[0].address}')
NODE_PORT=$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')

curl http://$WORKER_IP:$NODE_PORT
# Deve retornar HTML do nginx
```

## 6. Entendendo a Rede do Cluster

### Ranges de IP

```
Pod Network (CNI):     10.244.0.0/16
  ├─> Node 1:          10.244.0.0/24
  ├─> Node 2:          10.244.1.0/24
  ├─> Node 3:          10.244.2.0/24
  └─> Node 4:          10.244.3.0/24

Service Network:       10.96.0.0/12
  ├─> ClusterIP:       10.96.0.1 (kubernetes)
  ├─> CoreDNS:         10.96.0.10
  └─> Outros services: 10.96.x.x
```

### Verificar Configuração de Rede

```bash
# Ver configuração do CNI
kubectl get configmap -n kube-system calico-config -o yaml

# Ver IP ranges
kubectl cluster-info dump | grep -m 1 service-cluster-ip-range
kubectl cluster-info dump | grep -m 1 cluster-cidr

# Ver rotas no node
ip route show

# Ver interfaces de rede
ip addr show
```

## 7. Remover Node do Cluster

### Drenar Node (Preparar para Remoção)

```bash
# Marcar node como não agendável
kubectl cordon k8s-worker-3

# Drenar pods do node
kubectl drain k8s-worker-3 --ignore-daemonsets --delete-emptydir-data

# Remover node do cluster
kubectl delete node k8s-worker-3
```

### No Worker que Será Removido

```bash
# SSH no worker
ssh -i ~/.ssh/id_rsa ubuntu@<IP-WORKER-3>

# Resetar kubeadm
sudo kubeadm reset -f

# Limpar iptables
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Remover arquivos
sudo rm -rf /etc/cni /etc/kubernetes /var/lib/etcd /var/lib/kubelet /var/lib/dockershim /var/run/kubernetes ~/.kube
```

## 8. Troubleshooting

### Worker Fica NotReady

```bash
# No master, ver detalhes do node
kubectl describe node k8s-worker-1

# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp' | grep k8s-worker-1

# No worker, ver logs do kubelet
sudo journalctl -u kubelet -f

# Verificar CNI
kubectl get pods -n kube-system -o wide | grep calico-node

# Reiniciar kubelet no worker
sudo systemctl restart kubelet
```

### Erro ao Fazer Join

```bash
# Erro: token inválido ou expirado
# Solução: Gerar novo token no master
kubeadm token create --print-join-command

# Erro: certificado inválido
# Solução: Verificar hash do CA
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex

# Erro: porta 10250 em uso
# Solução: Resetar kubeadm no worker
sudo kubeadm reset -f
sudo systemctl restart kubelet
```

### Pods Não Se Comunicam

```bash
# Verificar CNI está rodando
kubectl get pods -n kube-system | grep calico

# Verificar rotas
ip route show

# Verificar iptables
sudo iptables -L -n -v

# Verificar logs do CNI
kubectl logs -n kube-system -l k8s-app=calico-node
```

## 9. Labels e Taints

### Adicionar Labels aos Workers

```bash
# Adicionar label de ambiente
kubectl label node k8s-worker-1 environment=production
kubectl label node k8s-worker-2 environment=production
kubectl label node k8s-worker-3 environment=development

# Ver labels
kubectl get nodes --show-labels

# Filtrar por label
kubectl get nodes -l environment=production
```

### Adicionar Taints

```bash
# Adicionar taint (impede pods de serem agendados)
kubectl taint nodes k8s-worker-3 dedicated=special:NoSchedule

# Remover taint
kubectl taint nodes k8s-worker-3 dedicated=special:NoSchedule-

# Ver taints
kubectl describe node k8s-worker-3 | grep Taints
```

## Resumo

**Instalar CNI:**
```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

**Obter comando de join:**
```bash
kubeadm token create --print-join-command
```

**Adicionar worker:**
```bash
sudo kubeadm join 10.0.1.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

**Verificar:**
```bash
kubectl get nodes
kubectl get pods -A
```

Cluster completo e funcional! 🚀
