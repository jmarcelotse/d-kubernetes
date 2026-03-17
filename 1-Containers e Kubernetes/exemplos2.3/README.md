# Exemplo 3: Gerenciamento de Rede

## Criar rede customizada

```bash
docker network create minha-rede
```

## Executar containers na mesma rede

```bash
# Container do banco de dados
docker run -d --name db --network minha-rede postgres

# Container da aplicação
docker run -d --name app --network minha-rede myapp
```

## Comunicação entre containers

Containers na mesma rede podem se comunicar pelo nome. O container `app` pode acessar o banco de dados usando:

```
postgresql://db:5432
```

## Comandos úteis

```bash
# Listar redes
docker network ls

# Inspecionar rede
docker network inspect minha-rede

# Remover rede
docker network rm minha-rede
```
