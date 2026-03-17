# Exemplo 3: Executar e Testar Gerenciamento de Rede

## 1. Criar a rede

```bash
docker network create minha-rede
```

## 2. Subir o container do PostgreSQL

```bash
docker run -d --name db --network minha-rede -e POSTGRES_PASSWORD=senha123 postgres
```

## 3. Testar a comunicação entre containers

```bash
# Conectar ao PostgreSQL a partir de outro container na mesma rede
docker run -it --rm --network minha-rede postgres psql -h db -U postgres
```

Senha: `senha123`

Se aparecer o prompt `postgres=#`, a comunicação pela rede está funcionando.

## 4. Verificar a rede

```bash
# Listar redes
docker network ls

# Ver containers conectados à rede
docker network inspect minha-rede
```

## 5. Limpar tudo

```bash
docker stop db
docker rm db
docker network rm minha-rede
```
