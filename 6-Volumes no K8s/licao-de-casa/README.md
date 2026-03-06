# Lição de Casa - Nginx com Volumes

Diferentes implementações de Nginx com volumes persistentes.

## Cenários

### 1. hostPath (Desenvolvimento)
```bash
kubectl apply -f 1-nginx-hostpath.yaml
kubectl port-forward deployment/nginx-hostpath 8081:80
```

### 2. NFS (Compartilhado)
```bash
# Ajustar IP do servidor NFS no arquivo
kubectl apply -f 2-nginx-nfs.yaml
kubectl port-forward deployment/nginx-nfs 8082:80
```

### 3. Local Path Provisioner (Dinâmico)
```bash
# Instalar provisioner primeiro
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

kubectl apply -f 3-nginx-dynamic.yaml
kubectl port-forward deployment/nginx-dynamic 8083:80
```

### 4. StatefulSet (Estado por Pod)
```bash
kubectl apply -f 4-nginx-statefulset.yaml
kubectl port-forward nginx-stateful-0 8084:80
```

## Testar

```bash
# Ver PVCs
kubectl get pvc

# Ver PVs
kubectl get pv

# Ver pods
kubectl get pods -o wide

# Testar persistência
kubectl exec <pod-name> -- sh -c 'echo "Teste" > /usr/share/nginx/html/test.txt'
kubectl delete pod <pod-name>
# Verificar se arquivo persiste após pod recriar
```

## Limpar

```bash
kubectl delete -f .
kubectl delete pvc --all
```

## Comparação

| Cenário | Tipo | Multi-Node | Produção |
|---------|------|------------|----------|
| hostPath | Estático | ❌ | ❌ |
| NFS | Estático | ✅ | ✅ |
| Dynamic | Dinâmico | ❌ | ⚠️ |
| StatefulSet | Dinâmico | ❌ | ✅ |
