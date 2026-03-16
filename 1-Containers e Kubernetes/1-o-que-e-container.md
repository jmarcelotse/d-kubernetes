# O que é um Container?

Um **container** é uma unidade padronizada de software que empacota código e todas as suas dependências para que a aplicação execute de forma rápida e confiável em diferentes ambientes computacionais.

## Características Principais

- **Isolamento**: Cada container roda isolado do sistema host e de outros containers, com seu próprio sistema de arquivos, processos e rede.

- **Leveza**: Containers compartilham o kernel do sistema operacional host, tornando-os muito mais leves que máquinas virtuais (MBs vs GBs).

- **Portabilidade**: Um container funciona da mesma forma em qualquer ambiente - desenvolvimento, teste ou produção - independente da infraestrutura.

- **Eficiência**: Iniciam em segundos e consomem menos recursos que VMs, permitindo maior densidade de aplicações por servidor.

## Como Funciona

Containers utilizam recursos do kernel Linux como:
- **Namespaces**: Isolam processos, rede, usuários e sistema de arquivos
- **Cgroups**: Limitam e controlam recursos (CPU, memória, I/O)
- **Union File Systems**: Permitem camadas de sistema de arquivos sobrepostas

## Container vs Máquina Virtual

| Aspecto | Container | Máquina Virtual |
|---------|-----------|-----------------|
| Tamanho | MBs | GBs |
| Inicialização | Segundos | Minutos |
| Isolamento | Nível de processo | Nível de hardware |
| Sistema Operacional | Compartilha kernel do host | SO completo por VM |

## Casos de Uso

- Microserviços
- CI/CD (Integração e Deploy Contínuos)
- Ambientes de desenvolvimento consistentes
- Aplicações cloud-native
- Escalabilidade horizontal

## Tecnologias Relacionadas

- **Docker**: Plataforma mais popular para criar e executar containers
- **Kubernetes**: Orquestrador de containers para gerenciar aplicações em escala
- **containerd, CRI-O**: Runtimes de container alternativos

---

## Exemplos Práticos

### Exemplo 1: Executar primeiro container

```bash
# Executar container nginx
docker run -d -p 8080:80 --name meu-nginx nginx

# Verificar container em execução
docker ps

# Acessar no navegador
# http://localhost:8080
```

### Exemplo 2: Container interativo

```bash
# Executar container Ubuntu interativo
docker run -it ubuntu bash

# Dentro do container
apt-get update
apt-get install -y curl
curl https://example.com
exit
```

### Exemplo 3: Container com volume

```bash
# Criar container com volume montado
docker run -d -v "$(pwd)/data:/data" --name app-data nginx

# Criar arquivo no host (sudo porque o Docker cria o diretório como root)
sudo bash -c 'echo "Hello from host" > data/test.txt'

# Ver arquivo dentro do container
docker exec app-data cat /data/test.txt
```

### Exemplo 4: Container com variáveis de ambiente

```bash
# Executar container com variáveis
docker run -d \
  -e DB_HOST=localhost \
  -e DB_PORT=5432 \
  -e APP_ENV=production \
  --name myapp nginx

# Verificar variáveis
docker exec myapp env | grep -E "DB_|APP_"
```

---

## Fluxo de Trabalho com Containers

```
┌─────────────────────────────────────────────────────────┐
│                  FLUXO DE CONTAINER                     │
└─────────────────────────────────────────────────────────┘

1. CRIAR IMAGEM
   ├─ Escrever Dockerfile
   ├─ docker build -t myapp:v1 .
   └─ Imagem criada localmente

2. EXECUTAR CONTAINER
   ├─ docker run -d -p 8080:80 myapp:v1
   ├─ Container iniciado
   └─ Aplicação rodando

3. GERENCIAR CONTAINER
   ├─ docker ps (listar)
   ├─ docker logs <id> (ver logs)
   ├─ docker exec -it <id> bash (acessar)
   └─ docker stop <id> (parar)

4. DISTRIBUIR
   ├─ docker tag myapp:v1 registry/myapp:v1
   ├─ docker push registry/myapp:v1
   └─ Imagem disponível para outros

5. LIMPAR
   ├─ docker stop <id>
   ├─ docker rm <id>
   └─ docker rmi myapp:v1
```

---

## Comandos Essenciais

```bash
# Listar containers em execução
docker ps

# Listar todos os containers (incluindo parados)
docker ps -a

# Ver logs de um container
docker logs <container-id>
docker logs -f <container-id>  # seguir logs em tempo real

# Executar comando em container
docker exec <container-id> <comando>
docker exec -it <container-id> bash

# Parar container
docker stop <container-id>

# Iniciar container parado
docker start <container-id>

# Remover container
docker rm <container-id>
docker rm -f <container-id>  # forçar remoção

# Ver uso de recursos
docker stats

# Inspecionar container
docker inspect <container-id>

# Ver processos do container
docker top <container-id>
```

---

## Exemplo Completo: Aplicação Web

```bash
# 1. Criar Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
EOF

# 2. Criar arquivo HTML
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Minha App</title></head>
<body><h1>Hello from Container!</h1></body>
</html>
EOF

# 3. Build da imagem
docker build -t minha-webapp:v1 .

# 4. Executar container
docker run -d -p 8080:80 --name webapp minha-webapp:v1

# 5. Testar
curl http://localhost:8080

# 6. Ver logs
docker logs webapp

# 7. Parar e remover
docker stop webapp
docker rm webapp
```

---

## Verificando Isolamento

```bash
# Terminal 1: Executar container 1
docker run -it --name container1 ubuntu bash
# Dentro: hostname
# Saída: <id-do-container1>

# Terminal 2: Executar container 2
docker run -it --name container2 ubuntu bash
# Dentro: hostname
# Saída: <id-do-container2> (diferente!)

# Cada container tem seu próprio hostname, processos, rede
```

---

## Comparando com VM (Prático)

```bash
# Container: Inicia em segundos
time docker run --rm alpine echo "Hello"
# real    0m0.5s

# VM: Levaria minutos para boot completo

# Container: Tamanho pequeno
docker images alpine
# alpine    latest    5.6MB

# VM: Imagem de vários GB
```
