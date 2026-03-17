# Exemplo Completo: Stack de Aplicação

Demonstra como montar uma stack completa (Frontend + API + Banco de Dados) usando containers Docker conectados por uma rede customizada.

## Arquitetura

```
[Frontend (Nginx)] ---> [API (Node.js)] ---> [PostgreSQL]
      :80                   :3000                :5432
                    app-network
```

## Pré-requisitos

- Docker instalado e rodando

## Passo a passo

### 1. Criar a rede

```bash
docker network create app-network
```

### 2. Executar o banco de dados

```bash
docker run -d \
  --name postgres \
  --network app-network \
  -e POSTGRES_PASSWORD=senha123 \
  -e POSTGRES_DB=mydb \
  -v pgdata:/var/lib/postgresql/data \
  postgres:14
```

### 3. Executar o backend (API)

```bash
docker run -d \
  --name api \
  --network app-network \
  -e DATABASE_URL=postgresql://postgres:senha123@postgres:5432/mydb \
  -p 3000:3000 \
  myapi:v1
```

> **Nota:** A imagem `myapi:v1` precisa ser construída previamente. Caso não tenha, substitua por uma imagem de teste como `nginx` para validar a rede.

### 4. Executar o frontend

```bash
docker run -d \
  --name frontend \
  --network app-network \
  -e API_URL=http://api:3000 \
  -p 80:80 \
  myfrontend:v1
```

> **Nota:** A imagem `myfrontend:v1` precisa ser construída previamente. Caso não tenha, substitua por `nginx` para validar.

### 5. Verificar os containers rodando

```bash
docker ps
```

Deve listar os 3 containers (`postgres`, `api`, `frontend`) com status `Up`.

### 6. Testar a comunicação

```bash
# Testar o frontend
curl http://localhost:80

# Testar a API
curl http://localhost:3000/health
```

### 7. Ver logs

```bash
# Logs de um serviço específico
docker logs -f api

# Logs do banco
docker logs postgres
```

### 8. Verificar a rede

```bash
docker network inspect app-network
```

Deve mostrar os 3 containers conectados à rede.

## Limpeza

```bash
docker stop frontend api postgres
docker rm frontend api postgres
docker network rm app-network
docker volume rm pgdata
```
