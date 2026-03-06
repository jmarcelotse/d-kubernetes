# Pod no Kubernetes

## O que é um Pod?

Um **Pod** é a menor unidade de implantação no Kubernetes. É um grupo de um ou mais containers que compartilham recursos e são executados juntos no mesmo nó do cluster.

## Características principais

- **Unidade atômica**: O Pod é a menor unidade que você pode criar e gerenciar no Kubernetes
- **Compartilhamento de recursos**: Containers dentro do mesmo Pod compartilham:
  - Endereço IP
  - Namespace de rede
  - Volumes de armazenamento
  - Porta de comunicação
- **Efêmero**: Pods são temporários e podem ser criados, destruídos e recriados conforme necessário
- **Co-localização**: Containers no mesmo Pod sempre são executados no mesmo nó

## Casos de uso

### Pod com um único container
O padrão mais comum - um Pod contém apenas um container da aplicação.

### Pod com múltiplos containers
Usado quando containers precisam trabalhar juntos de forma acoplada:
- Container principal da aplicação
- Containers auxiliares (sidecars) para logging, monitoramento ou proxy

## Ciclo de vida

1. **Pending**: Pod foi aceito mas containers ainda não foram criados
2. **Running**: Pod foi vinculado a um nó e pelo menos um container está em execução
3. **Succeeded**: Todos os containers terminaram com sucesso
4. **Failed**: Pelo menos um container terminou com erro
5. **Unknown**: Estado do Pod não pode ser determinado

## Exemplo básico

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

## Importante

- Pods não são projetados para serem duráveis
- Para aplicações em produção, use controladores como Deployment, StatefulSet ou DaemonSet
- Esses controladores gerenciam Pods automaticamente, garantindo disponibilidade e escalabilidade
