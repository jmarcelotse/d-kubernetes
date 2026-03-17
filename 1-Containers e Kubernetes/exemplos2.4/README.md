# Exemplo 4: Volumes Persistentes

Demonstra como criar e usar volumes Docker para persistir dados entre containers.

## Pré-requisitos

- Docker instalado e rodando

## Passo a passo

### 1. Criar o volume

```bash
docker volume create app-data
```

### 2. Rodar um container usando o volume

```bash
docker run -d -v app-data:/data --name myapp nginx
```

### 3. Testar a persistência

Escreva um arquivo dentro do volume:

```bash
docker exec myapp sh -c "echo 'dados persistentes' > /data/teste.txt"
```

Verifique o conteúdo:

```bash
docker exec myapp cat /data/teste.txt
```

### 4. Comprovar que os dados persistem

Pare e remova o container:

```bash
docker stop myapp
docker rm myapp
```

Crie um novo container com o mesmo volume:

```bash
docker run -d -v app-data:/data --name myapp2 nginx
```

Verifique que o arquivo ainda existe:

```bash
docker exec myapp2 cat /data/teste.txt
```

O conteúdo `dados persistentes` deve aparecer, comprovando que o volume mantém os dados.

### 5. Comandos úteis

```bash
# Listar volumes
docker volume ls

# Inspecionar volume
docker volume inspect app-data
```

## Limpeza

```bash
docker stop myapp2
docker rm myapp2
docker volume rm app-data
```
