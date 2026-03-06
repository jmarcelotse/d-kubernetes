# kubectl attach e kubectl exec

## kubectl exec

Comando usado para **executar comandos** dentro de um container em execução.

### Sintaxe básica

```bash
kubectl exec <nome-do-pod> -- <comando>
```

### Exemplos práticos

```bash
# Executar um comando simples
kubectl exec nginx-pod -- ls /usr/share/nginx/html

# Executar comando com argumentos
kubectl exec nginx-pod -- cat /etc/nginx/nginx.conf

# Modo interativo com shell
kubectl exec -it nginx-pod -- /bin/bash
kubectl exec -it nginx-pod -- /bin/sh

# Executar em um container específico (pod com múltiplos containers)
kubectl exec -it my-pod -c container-name -- /bin/bash

# Executar em namespace específico
kubectl exec -it nginx-pod -n production -- /bin/bash

# Executar comando e ver variáveis de ambiente
kubectl exec nginx-pod -- env

# Verificar processos em execução
kubectl exec nginx-pod -- ps aux
```

### Flags importantes

- `-i` ou `--stdin`: Mantém stdin aberto (modo interativo)
- `-t` ou `--tty`: Aloca um terminal TTY
- `-c` ou `--container`: Especifica o container (obrigatório em pods multi-container)
- `-n` ou `--namespace`: Define o namespace

### Casos de uso

- **Debug**: Investigar problemas dentro do container
- **Inspeção**: Verificar arquivos, configurações e logs internos
- **Manutenção**: Executar comandos administrativos
- **Testes**: Validar conectividade, DNS, variáveis de ambiente
- **Troubleshooting**: Diagnosticar problemas de aplicação

### Exemplos de troubleshooting

```bash
# Testar conectividade de rede
kubectl exec -it app-pod -- curl http://service-name:8080

# Verificar DNS
kubectl exec -it app-pod -- nslookup kubernetes.default

# Testar conectividade com outro pod
kubectl exec -it app-pod -- ping other-pod-ip

# Ver logs de aplicação dentro do container
kubectl exec -it app-pod -- tail -f /var/log/app.log

# Verificar espaço em disco
kubectl exec app-pod -- df -h
```

---

## kubectl attach

Comando usado para **conectar-se ao processo principal** (PID 1) de um container em execução, anexando stdin, stdout e stderr.

### Sintaxe básica

```bash
kubectl attach <nome-do-pod>
```

### Exemplos práticos

```bash
# Anexar ao processo principal do pod
kubectl attach nginx-pod

# Modo interativo
kubectl attach -it nginx-pod

# Anexar a um container específico
kubectl attach -it my-pod -c container-name

# Anexar em namespace específico
kubectl attach -it nginx-pod -n production
```

### Flags importantes

- `-i` ou `--stdin`: Passa stdin para o container
- `-t` ou `--tty`: Stdin é um TTY
- `-c` ou `--container`: Especifica o container

### Casos de uso

- **Aplicações interativas**: Conectar a aplicações que esperam entrada do usuário
- **Debug de processos**: Anexar ao processo principal para ver saída em tempo real
- **Monitoramento**: Ver stdout/stderr do processo principal
- **Sessões interativas**: Quando o container foi iniciado com um shell interativo

### Importante sobre attach

- Conecta apenas ao **processo principal** (PID 1) do container
- Não inicia um novo processo como o `exec`
- Se o processo principal não aceita entrada, o attach terá uso limitado
- Útil principalmente para containers que executam shells ou aplicações interativas

---

## Diferenças principais

| kubectl exec | kubectl attach |
|--------------|----------------|
| Executa um **novo processo** no container | Conecta ao **processo existente** (PID 1) |
| Pode executar qualquer comando | Apenas interage com o processo principal |
| Mais versátil para debug | Limitado ao processo em execução |
| Cria nova sessão | Anexa à sessão existente |
| Uso mais comum | Uso mais específico |

---

## Quando usar cada um

### Use kubectl exec quando:
- Precisa executar comandos específicos (ls, cat, curl, etc.)
- Quer abrir um shell interativo para debug
- Precisa inspecionar arquivos ou configurações
- Quer testar conectividade de rede
- Necessita executar scripts ou ferramentas de diagnóstico

### Use kubectl attach quando:
- O container executa uma aplicação interativa
- Quer ver a saída do processo principal em tempo real
- Precisa enviar entrada para o processo principal
- O container foi iniciado com um shell e você quer se conectar a ele
- Quer monitorar stdout/stderr do processo principal

---

## Exemplos comparativos

### Cenário 1: Debug geral

```bash
# Melhor usar exec - cria novo shell
kubectl exec -it app-pod -- /bin/bash
```

### Cenário 2: Ver saída do processo principal

```bash
# Melhor usar attach - conecta ao processo em execução
kubectl attach -it app-pod
```

### Cenário 3: Executar comando único

```bash
# Usar exec - executa comando específico
kubectl exec app-pod -- curl http://api:8080/health
```

### Cenário 4: Container com shell interativo rodando

```bash
# Usar attach - conecta ao shell existente
kubectl attach -it debug-pod
```

---

## Dicas práticas

### Para kubectl exec:
- Sempre use `-it` para sessões interativas
- Use `--` para separar flags do kubectl dos argumentos do comando
- Verifique se o shell existe no container (`/bin/bash` ou `/bin/sh`)
- Em pods multi-container, sempre especifique `-c container-name`

### Para kubectl attach:
- Menos usado que `exec` no dia a dia
- Útil para containers de debug temporários
- Para sair sem matar o processo, use `Ctrl+P` seguido de `Ctrl+Q`
- Se o processo principal terminar, o attach também termina

### Alternativa para logs:
```bash
# Para apenas ver saída, use logs ao invés de attach
kubectl logs -f pod-name
```
