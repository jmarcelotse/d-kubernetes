# Lição de Casa - StatefulSets e Services

## Objetivo

Praticar a criação e gerenciamento de StatefulSets e Services no Kubernetes, explorando diferentes tipos de Services e comportamentos de resiliência.

## Exercícios

### Exercício 1: Criar e Gerenciar StatefulSet

**Tarefas:**
1. Criar um StatefulSet simples com 2 Pods
2. Escalar para 4 Pods
3. Deletar um Pod e observar o comportamento de recriação
4. Verificar identidade estável dos Pods
5. Escalar de volta para 2 Pods

**Arquivo:** `1-statefulset-nginx.yaml`

**Comandos esperados:**
```bash
# Aplicar StatefulSet
kubectl apply -f 1-statefulset-nginx.yaml

# Verificar Pods
kubectl get pods -l app=nginx-sts -w

# Escalar para 4 réplicas
kubectl scale statefulset nginx-sts --replicas=4

# Deletar um Pod
kubectl delete pod nginx-sts-2

# Observar recriação
kubectl get pods -l app=nginx-sts -w

# Escalar de volta
kubectl scale statefulset nginx-sts --replicas=2
```

---

### Exercício 2: Expor StatefulSet com ClusterIP

**Tarefas:**
1. Criar Service ClusterIP para o StatefulSet
2. Testar conectividade interna
3. Verificar DNS dos Pods
4. Testar balanceamento de carga

**Arquivo:** `2-service-clusterip.yaml`

**Comandos esperados:**
```bash
# Aplicar Service
kubectl apply -f 2-service-clusterip.yaml

# Testar conectividade
kubectl run test-client --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl http://nginx-service

# Verificar DNS
kubectl run test-dns --image=busybox:1.36 --rm -it --restart=Never -- nslookup nginx-service

# Verificar Endpoints
kubectl get endpoints nginx-service
```

---

### Exercício 3: Mudar para NodePort

**Tarefas:**
1. Modificar Service para tipo NodePort
2. Testar acesso externo via Node IP
3. Verificar porta alocada
4. Documentar diferenças de comportamento

**Arquivo:** `3-service-nodeport.yaml`

**Comandos esperados:**
```bash
# Aplicar Service NodePort
kubectl apply -f 3-service-nodeport.yaml

# Obter NodePort
kubectl get service nginx-service

# Obter IP do Node
kubectl get nodes -o wide

# Testar acesso (substitua NODE_IP e NODE_PORT)
curl http://NODE_IP:NODE_PORT
```

---

### Exercício 4: Mudar para LoadBalancer

**Tarefas:**
1. Modificar Service para tipo LoadBalancer
2. Aguardar provisionamento do Load Balancer
3. Testar acesso via IP externo
4. Comparar com NodePort

**Arquivo:** `4-service-loadbalancer.yaml`

**Comandos esperados:**
```bash
# Aplicar Service LoadBalancer
kubectl apply -f 4-service-loadbalancer.yaml

# Verificar EXTERNAL-IP
kubectl get service nginx-service -w

# Testar acesso (em ambiente cloud)
curl http://EXTERNAL_IP

# Se em ambiente local (Kind), instalar MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
```

---

### Exercício 5: Service ExternalName

**Tarefas:**
1. Criar Service ExternalName apontando para serviço externo
2. Testar resolução DNS
3. Testar conectividade ao serviço externo
4. Documentar casos de uso

**Arquivo:** `5-service-externalname.yaml`

**Comandos esperados:**
```bash
# Aplicar Service ExternalName
kubectl apply -f 5-service-externalname.yaml

# Testar resolução DNS
kubectl run test-dns --image=busybox:1.36 --rm -it --restart=Never -- nslookup github-api

# Testar conectividade
kubectl run test-curl --image=curlimages/curl:8.6.0 --rm -it --restart=Never -- curl -k https://github-api/users/octocat

# Verificar Service
kubectl describe service github-api
```

---

## Critérios de Avaliação

### StatefulSet (30 pontos)
- [ ] StatefulSet criado corretamente (10 pontos)
- [ ] Escalonamento funcional (10 pontos)
- [ ] Compreensão do comportamento de recriação (10 pontos)

### Services (50 pontos)
- [ ] ClusterIP funcionando (10 pontos)
- [ ] NodePort funcionando (10 pontos)
- [ ] LoadBalancer configurado (10 pontos)
- [ ] ExternalName funcionando (10 pontos)
- [ ] Testes de conectividade realizados (10 pontos)

### Documentação (20 pontos)
- [ ] Comandos documentados (5 pontos)
- [ ] Outputs capturados (5 pontos)
- [ ] Observações e aprendizados (5 pontos)
- [ ] Troubleshooting documentado (5 pontos)

---

## Entrega

Crie um arquivo `RESPOSTAS.md` com:

1. **Comandos executados** e suas saídas
2. **Screenshots** ou outputs dos comandos
3. **Observações** sobre o comportamento
4. **Problemas encontrados** e como resolveu
5. **Aprendizados** principais

---

## Dicas

### Para StatefulSet
- Use `kubectl get pods -w` para observar criação/recriação em tempo real
- Verifique os nomes dos Pods (devem ter índice numérico)
- Observe a ordem de criação e deleção

### Para Services
- Use `kubectl describe service` para ver detalhes
- Verifique Endpoints com `kubectl get endpoints`
- Teste DNS com `nslookup` ou `dig`

### Para Troubleshooting
- Verifique logs: `kubectl logs <pod-name>`
- Descreva recursos: `kubectl describe <resource> <name>`
- Verifique eventos: `kubectl get events --sort-by='.lastTimestamp'`

---

## Recursos Adicionais

- [Documentação StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Documentação Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

---

## Bônus (Opcional)

### Exercício Bônus 1: Headless Service
Crie um Headless Service para o StatefulSet e teste o DNS de cada Pod individualmente.

**Arquivo:** `bonus-1-headless-service.yaml`

### Exercício Bônus 2: Service com SessionAffinity
Configure um Service com SessionAffinity e teste se as requisições vão sempre para o mesmo Pod.

**Arquivo:** `bonus-2-session-affinity.yaml`

### Exercício Bônus 3: Multi-Port Service
Crie um Service que exponha múltiplas portas (HTTP, HTTPS, Metrics).

**Arquivo:** `bonus-3-multi-port.yaml`

---

## Limpeza

Após concluir os exercícios:

```bash
# Remover StatefulSet
kubectl delete statefulset nginx-sts

# Remover Services
kubectl delete service nginx-service github-api

# Remover PVCs (se criados)
kubectl delete pvc -l app=nginx-sts

# Verificar limpeza
kubectl get all
```

---

**Boa sorte e bons estudos! 🚀**
