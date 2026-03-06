# O que é um Container Engine?

Um **container engine** (motor de containers) é o software responsável por gerenciar o ciclo de vida completo dos containers - desde a criação até a execução e remoção.

## Função Principal

O container engine atua como intermediário entre o usuário e o sistema operacional, fornecendo uma interface para:
- Criar containers a partir de imagens
- Iniciar e parar containers
- Gerenciar recursos (CPU, memória, rede)
- Construir imagens de container
- Gerenciar volumes e redes

## Componentes de um Container Engine

### 1. Interface de Alto Nível
- CLI (Command Line Interface) para interação do usuário
- API REST para integração com outras ferramentas
- Gerenciamento de imagens e registries

### 2. Container Runtime
- **High-level runtime**: Gerencia imagens e fornece APIs (ex: containerd, CRI-O)
- **Low-level runtime**: Executa containers usando recursos do kernel (ex: runc, crun)

### 3. Gerenciamento de Recursos
- Configuração de namespaces e cgroups
- Isolamento de processos
- Controle de rede e armazenamento

## Principais Container Engines

### Docker Engine
- Container engine mais popular e completo
- Inclui Docker daemon, CLI e APIs
- Usa containerd como runtime padrão
- Oferece Docker Compose para multi-containers

### Podman
- Alternativa ao Docker sem daemon
- Compatível com comandos Docker
- Execução rootless (sem privilégios de root)
- Integração nativa com systemd

### containerd
- Runtime de containers de alto nível
- Usado pelo Docker e Kubernetes
- Foco em simplicidade e performance
- Padrão da Cloud Native Computing Foundation (CNCF)

### CRI-O
- Container runtime otimizado para Kubernetes
- Implementa a Container Runtime Interface (CRI)
- Leve e focado em produção

## Arquitetura Típica

```
┌─────────────────────────────────────┐
│   CLI / API (Interface do Usuário)  │
├─────────────────────────────────────┤
│   Container Engine (Docker/Podman)  │
├─────────────────────────────────────┤
│   High-level Runtime (containerd)   │
├─────────────────────────────────────┤
│   Low-level Runtime (runc)          │
├─────────────────────────────────────┤
│   Kernel Linux (namespaces/cgroups) │
└─────────────────────────────────────┘
```

## Container Engine vs Container Runtime

| Container Engine | Container Runtime |
|------------------|-------------------|
| Interface completa de gerenciamento | Execução de containers |
| Build de imagens | Não constrói imagens |
| Gerenciamento de rede e volumes | Foco em isolamento e recursos |
| Exemplo: Docker, Podman | Exemplo: containerd, runc |

## Casos de Uso

- **Desenvolvimento local**: Docker Desktop, Podman Desktop
- **CI/CD**: Docker Engine em pipelines de build
- **Produção**: containerd com Kubernetes
- **Edge computing**: Engines leves como containerd

## Escolhendo um Container Engine

Considere:
- **Facilidade de uso**: Docker oferece melhor experiência para iniciantes
- **Segurança**: Podman permite execução rootless
- **Integração**: containerd é ideal para Kubernetes
- **Recursos**: Docker tem ecossistema mais rico (Compose, Swarm)

---

## Exemplos Práticos

### Exemplo 1: Docker Engine - Comandos básicos

```bash
# Verificar versão do Docker Engine
docker version

# Ver informações do sistema
docker info

# Executar container
docker run -d -p 80:80 nginx

# Listar containers
docker ps

# Parar container
docker stop <container-id>
```

### Exemplo 2: Build de imagem

```bash
# Criar Dockerfile
cat > Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "app.js"]
EOF

# Build da imagem
docker build -t myapp:v1 .

# Ver imagens
docker images

# Executar
docker run -d -p 3000:3000 myapp:v1
```

### Exemplo 3: Gerenciamento de rede

```bash
# Criar rede customizada
docker network create minha-rede

# Executar containers na mesma rede
docker run -d --name db --network minha-rede postgres
docker run -d --name app --network minha-rede myapp

# Containers podem se comunicar pelo nome
# app pode acessar: postgresql://db:5432
```

### Exemplo 4: Volumes persistentes

```bash
# Criar volume
docker volume create app-data

# Usar volume
docker run -d -v app-data:/data --name myapp nginx

# Listar volumes
docker volume ls

# Inspecionar volume
docker volume inspect app-data
```

### Exemplo 5: Docker Compose (multi-container)

```yaml
# docker-compose.yml
version: '3.8'
services:
  web:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
  
  api:
    image: node:18
    working_dir: /app
    volumes:
      - ./api:/app
    command: node server.js
    ports:
      - "3000:3000"
  
  db:
    image: postgres:14
    environment:
      POSTGRES_PASSWORD: senha123
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

```bash
# Iniciar todos os serviços
docker-compose up -d

# Ver status
docker-compose ps

# Ver logs
docker-compose logs -f

# Parar tudo
docker-compose down
```

### Exemplo 6: Podman (alternativa ao Docker)

```bash
# Comandos são compatíveis com Docker
podman run -d -p 80:80 nginx

# Executar sem root (rootless)
podman run --rm -it alpine sh

# Gerar arquivo systemd
podman generate systemd --name myapp > myapp.service

# Listar containers
podman ps
```

---

## Fluxo de Trabalho do Container Engine

```
┌────────────────────────────────────────────────────────┐
│           FLUXO DO CONTAINER ENGINE                    │
└────────────────────────────────────────────────────────┘

1. USUÁRIO EXECUTA COMANDO
   └─> docker run nginx

2. CONTAINER ENGINE (Docker)
   ├─> Verifica se imagem existe localmente
   ├─> Se não, faz pull do registry
   ├─> Cria configuração do container
   └─> Chama high-level runtime

3. HIGH-LEVEL RUNTIME (containerd)
   ├─> Gerencia imagem e snapshots
   ├─> Prepara filesystem do container
   ├─> Configura rede
   └─> Chama low-level runtime

4. LOW-LEVEL RUNTIME (runc)
   ├─> Cria namespaces (PID, NET, MNT, etc)
   ├─> Configura cgroups (CPU, memória)
   ├─> Monta filesystem
   └─> Executa processo do container

5. CONTAINER EM EXECUÇÃO
   └─> Aplicação rodando isolada
```

---

## Arquitetura Detalhada

```
┌─────────────────────────────────────────────────────┐
│                    USUÁRIO                          │
│              docker run / podman run                │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│              CONTAINER ENGINE                       │
│  ┌──────────────────────────────────────────────┐  │
│  │  CLI / API                                   │  │
│  ├──────────────────────────────────────────────┤  │
│  │  Image Management (pull, build, push)       │  │
│  ├──────────────────────────────────────────────┤  │
│  │  Network Management                          │  │
│  ├──────────────────────────────────────────────┤  │
│  │  Volume Management                           │  │
│  └──────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│         HIGH-LEVEL RUNTIME (containerd)             │
│  - Gerencia lifecycle de containers                 │
│  - Gerencia imagens e snapshots                     │
│  - Fornece APIs (gRPC)                              │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│         LOW-LEVEL RUNTIME (runc)                    │
│  - Cria namespaces                                  │
│  - Configura cgroups                                │
│  - Executa processo do container                    │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│              KERNEL LINUX                           │
│  - Namespaces (isolamento)                          │
│  - Cgroups (recursos)                               │
│  - Capabilities (segurança)                         │
└─────────────────────────────────────────────────────┘
```

---

## Comandos de Gerenciamento

### Imagens

```bash
# Listar imagens
docker images

# Baixar imagem
docker pull nginx:alpine

# Remover imagem
docker rmi nginx:alpine

# Build de imagem
docker build -t myapp:v1 .

# Tag de imagem
docker tag myapp:v1 registry.io/myapp:v1

# Push para registry
docker push registry.io/myapp:v1

# Histórico da imagem
docker history nginx

# Inspecionar imagem
docker inspect nginx
```

### Containers

```bash
# Executar container
docker run -d --name web nginx

# Listar containers rodando
docker ps

# Listar todos (incluindo parados)
docker ps -a

# Parar container
docker stop web

# Iniciar container
docker start web

# Reiniciar container
docker restart web

# Remover container
docker rm web

# Remover todos os containers parados
docker container prune
```

### Rede

```bash
# Listar redes
docker network ls

# Criar rede
docker network create minha-rede

# Inspecionar rede
docker network inspect minha-rede

# Conectar container à rede
docker network connect minha-rede web

# Remover rede
docker network rm minha-rede
```

### Volumes

```bash
# Listar volumes
docker volume ls

# Criar volume
docker volume create dados

# Inspecionar volume
docker volume inspect dados

# Remover volume
docker volume rm dados

# Remover volumes não utilizados
docker volume prune
```

---

## Exemplo Completo: Stack de Aplicação

```bash
# 1. Criar rede
docker network create app-network

# 2. Executar banco de dados
docker run -d \
  --name postgres \
  --network app-network \
  -e POSTGRES_PASSWORD=senha123 \
  -e POSTGRES_DB=mydb \
  -v pgdata:/var/lib/postgresql/data \
  postgres:14

# 3. Executar backend API
docker run -d \
  --name api \
  --network app-network \
  -e DATABASE_URL=postgresql://postgres:senha123@postgres:5432/mydb \
  -p 3000:3000 \
  myapi:v1

# 4. Executar frontend
docker run -d \
  --name frontend \
  --network app-network \
  -e API_URL=http://api:3000 \
  -p 80:80 \
  myfrontend:v1

# 5. Verificar tudo rodando
docker ps

# 6. Ver logs
docker logs -f api

# 7. Testar
curl http://localhost:80
curl http://localhost:3000/health

# 8. Limpar tudo
docker stop frontend api postgres
docker rm frontend api postgres
docker network rm app-network
docker volume rm pgdata
```

---

## Monitoramento e Debug

```bash
# Ver uso de recursos em tempo real
docker stats

# Ver processos de um container
docker top <container-id>

# Inspecionar detalhes do container
docker inspect <container-id>

# Ver logs
docker logs <container-id>
docker logs -f <container-id>  # seguir logs
docker logs --tail 100 <container-id>  # últimas 100 linhas

# Executar comando no container
docker exec <container-id> ps aux
docker exec -it <container-id> bash

# Ver eventos do Docker
docker events

# Ver informações do sistema
docker system df  # uso de disco
docker system info  # informações gerais
```
