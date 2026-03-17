# Exemplo 5: Docker Compose (Multi-Container)

Demonstra como orquestrar múltiplos containers com Docker Compose: Nginx (web), Node.js (API) e PostgreSQL (banco de dados).

## Pré-requisitos

- Docker e Docker Compose instalados

## Estrutura

```
exemplos2.5/
├── docker-compose.yml
├── html/
│   └── index.html
├── api/
│   └── server.js
└── README.md
```

## Passo a passo

### 1. Iniciar todos os serviços

```bash
cd exemplos2.5
docker-compose up -d
```

### 2. Verificar status dos containers

```bash
docker-compose ps
```

Os 3 serviços devem estar com status `Up`:
- `web` (Nginx) — porta 80
- `api` (Node.js) — porta 3000
- `db` (PostgreSQL) — porta 5432 (interna)

### 3. Testar o serviço web (Nginx)

```bash
curl http://localhost:80
```

Deve retornar o HTML da página `index.html`.

### 4. Testar a API (Node.js)

```bash
curl http://localhost:3000
```

Deve retornar:

```json
{"message":"API funcionando!"}
```

### 5. Testar o banco de dados (PostgreSQL)

```bash
docker-compose exec db psql -U postgres -c "SELECT version();"
```

Deve retornar a versão do PostgreSQL.

### 6. Ver logs dos serviços

```bash
# Todos os serviços
docker-compose logs -f

# Serviço específico
docker-compose logs -f api
```

## Limpeza

```bash
docker-compose down

# Para remover também o volume do banco:
docker-compose down -v
```
