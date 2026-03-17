# Exemplo 4: Volumes Persistentes

## Criar volume
```bash
docker volume create app-data
```

## Usar volume
```bash
docker run -d -v app-data:/data --name myapp nginx
```

## Listar volumes
```bash
docker volume ls
```

## Inspecionar volume
```bash
docker volume inspect app-data
```
