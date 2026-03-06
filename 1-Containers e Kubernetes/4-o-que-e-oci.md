# O que é a OCI?

A **OCI (Open Container Initiative)** é um projeto open source criado para estabelecer padrões abertos da indústria para formatos de containers e runtimes. Foi fundada em junho de 2015 pela Linux Foundation.

## Objetivo

Criar especificações abertas e padronizadas para:
- Garantir que containers funcionem de forma consistente em diferentes plataformas
- Evitar vendor lock-in (dependência de fornecedor específico)
- Promover interoperabilidade entre ferramentas de container
- Estabelecer padrões mínimos para a indústria

## História

- **2015**: Docker doa a especificação runc e formato de imagem para criar a OCI
- **2017**: Lançamento da OCI Runtime Specification 1.0 e Image Specification 1.0
- **Hoje**: Mantida pela Linux Foundation com suporte de grandes empresas (Docker, Red Hat, Google, Microsoft, AWS, etc.)

## Especificações Principais

### 1. OCI Runtime Specification

Define como executar um "filesystem bundle" como container.

**Componentes:**
- **config.json**: Configuração do container (processo, ambiente, recursos)
- **Operações do ciclo de vida**: create, start, kill, delete
- **Configuração de recursos**: CPU, memória, I/O
- **Namespaces e cgroups**: Isolamento e limites

**Exemplo de config.json:**
```json
{
  "ociVersion": "1.0.0",
  "process": {
    "terminal": true,
    "user": {"uid": 0, "gid": 0},
    "args": ["/bin/sh"],
    "env": ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"],
    "cwd": "/"
  },
  "root": {
    "path": "rootfs",
    "readonly": false
  }
}
```

**Implementações:**
- runc (referência)
- crun
- Kata Containers
- gVisor (runsc)

### 2. OCI Image Specification

Define o formato de imagens de container.

**Componentes:**
- **Image Manifest**: Metadados da imagem
- **Image Index**: Lista de manifests para multi-plataforma
- **Filesystem Layers**: Camadas do sistema de arquivos
- **Image Configuration**: Configuração da imagem

**Estrutura de uma imagem:**
```
┌─────────────────────────┐
│   Image Index           │  ← Multi-arch support
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│   Image Manifest        │  ← Metadados
└───────────┬─────────────┘
            │
    ┌───────┴───────┐
    │               │
┌───▼────┐    ┌────▼─────┐
│ Config │    │  Layers  │  ← Filesystem
└────────┘    └──────────┘
```

**Formato de camadas:**
- Tar archives compactados (gzip, zstd)
- Cada camada representa mudanças no filesystem
- Imutáveis e reutilizáveis

### 3. OCI Distribution Specification

Define como distribuir imagens através de registries.

**Funcionalidades:**
- Push e pull de imagens
- APIs REST para registries
- Autenticação e autorização
- Content addressable storage (hash-based)

**Implementações:**
- Docker Registry
- Harbor
- Quay
- Amazon ECR
- Google Container Registry

## Benefícios da OCI

### Interoperabilidade
- Imagens criadas com Docker funcionam com Podman
- Runtimes podem ser trocados sem modificar imagens
- Ferramentas diferentes podem trabalhar juntas

### Portabilidade
- Mesma imagem roda em qualquer plataforma OCI-compliant
- Não há dependência de fornecedor específico
- Facilita migração entre clouds

### Inovação
- Padrões abertos permitem novas implementações
- Competição saudável entre ferramentas
- Comunidade pode contribuir

### Segurança
- Especificações incluem práticas de segurança
- Verificação de integridade via hashes
- Assinaturas digitais de imagens

## Ecossistema OCI

### Runtimes OCI-Compliant
- runc
- crun
- Kata Containers
- gVisor
- Railcar

### Ferramentas que Usam OCI
- Docker
- Podman
- containerd
- CRI-O
- Kubernetes
- Buildah
- Skopeo

### Registries OCI-Compliant
- Docker Hub
- Amazon ECR
- Google Artifact Registry
- Azure Container Registry
- Harbor
- Quay.io

## OCI vs Docker

| Aspecto | OCI | Docker |
|---------|-----|--------|
| Tipo | Especificação/Padrão | Implementação/Produto |
| Escopo | Define padrões | Fornece ferramentas completas |
| Governança | Linux Foundation | Docker Inc. |
| Objetivo | Interoperabilidade | Plataforma de containers |

**Relação:**
- Docker implementa as especificações OCI
- Docker doou tecnologias que formaram a base da OCI
- Imagens Docker são compatíveis com OCI Image Spec

## Verificando Conformidade OCI

### Validar Runtime Bundle
```bash
# Usando oci-runtime-tools
oci-runtime-tool validate
```

### Inspecionar Imagem OCI
```bash
# Usando skopeo
skopeo inspect oci:myimage

# Usando crane
crane manifest myimage
```

### Testar Runtime
```bash
# Criar bundle OCI
mkdir -p mycontainer/rootfs
cd mycontainer

# Gerar config.json
runc spec

# Executar com runtime OCI
runc run mycontainer
```

## Membros da OCI

Empresas e organizações que apoiam a OCI:
- Amazon Web Services (AWS)
- Google
- Microsoft
- Red Hat (IBM)
- Docker
- Oracle
- VMware
- Intel
- Cisco
- E muitas outras...

## Futuro da OCI

Áreas de desenvolvimento:
- **Artifacts**: Armazenar qualquer tipo de conteúdo em registries OCI
- **Referrers**: Associar metadados a imagens (assinaturas, SBOMs)
- **Wasm**: Suporte para WebAssembly containers
- **Confidential Computing**: Containers em ambientes seguros

## Recursos

- **Site oficial**: https://opencontainers.org
- **GitHub**: https://github.com/opencontainers
- **Especificações**:
  - Runtime Spec: https://github.com/opencontainers/runtime-spec
  - Image Spec: https://github.com/opencontainers/image-spec
  - Distribution Spec: https://github.com/opencontainers/distribution-spec

---

## Exemplos Práticos

### Exemplo 1: Criar Bundle OCI

```bash
# 1. Criar estrutura de diretórios
mkdir -p mycontainer/rootfs
cd mycontainer

# 2. Exportar filesystem de uma imagem
docker export $(docker create alpine) | tar -C rootfs -xf -

# 3. Gerar config.json (especificação OCI)
runc spec

# 4. Ver configuração gerada
cat config.json

# 5. Executar container com runtime OCI
runc run mycontainer
```

### Exemplo 2: Inspecionar Imagem OCI

```bash
# Usando skopeo para inspecionar imagem
skopeo inspect docker://nginx:alpine

# Ver manifest da imagem
skopeo inspect --raw docker://nginx:alpine

# Copiar imagem para formato OCI local
skopeo copy docker://nginx:alpine oci:nginx-oci:latest

# Inspecionar imagem OCI local
skopeo inspect oci:nginx-oci:latest
```

### Exemplo 3: Validar Conformidade OCI

```bash
# Instalar oci-runtime-tools
go install github.com/opencontainers/runtime-tools/cmd/oci-runtime-tool@latest

# Gerar config.json válido
oci-runtime-tool generate > config.json

# Validar bundle OCI
oci-runtime-tool validate

# Validar com detalhes
oci-runtime-tool validate --verbose
```

### Exemplo 4: Trabalhar com Layers OCI

```bash
# Usar crane para inspecionar layers
crane manifest nginx:alpine

# Ver configuração da imagem
crane config nginx:alpine

# Exportar layer específico
crane export nginx:alpine - | tar -xf -

# Ver digest de cada layer
crane manifest nginx:alpine | jq '.layers[].digest'
```

### Exemplo 5: Registry OCI Local

```bash
# Executar registry OCI local
docker run -d -p 5000:5000 --name registry registry:2

# Tag imagem para registry local
docker tag nginx:alpine localhost:5000/nginx:alpine

# Push para registry OCI
docker push localhost:5000/nginx:alpine

# Pull do registry OCI
docker pull localhost:5000/nginx:alpine

# Inspecionar via API
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/nginx/tags/list
```

---

## Estrutura de uma Imagem OCI

```
my-image/
├── blobs/
│   └── sha256/
│       ├── abc123...  (config)
│       ├── def456...  (layer 1)
│       ├── ghi789...  (layer 2)
│       └── jkl012...  (layer 3)
├── index.json
└── oci-layout

# index.json - Ponto de entrada
{
  "schemaVersion": 2,
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:abc123...",
      "size": 1234
    }
  ]
}

# manifest - Lista de layers
{
  "schemaVersion": 2,
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:def456...",
    "size": 5678
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:ghi789...",
      "size": 9012
    }
  ]
}
```

---

## Fluxo de Build e Execução OCI

```
┌─────────────────────────────────────────────────────┐
│              FLUXO OCI COMPLETO                     │
└─────────────────────────────────────────────────────┘

1. BUILD (Criar Imagem OCI)
   ├─> Dockerfile ou Containerfile
   ├─> docker build / buildah bud
   ├─> Gera layers (OCI Image Spec)
   ├─> Cria manifest e config
   └─> Imagem OCI criada

2. PUSH (Distribuir Imagem)
   ├─> docker push / skopeo copy
   ├─> Usa OCI Distribution Spec
   ├─> Upload de layers para registry
   ├─> Registry armazena blobs
   └─> Imagem disponível remotamente

3. PULL (Baixar Imagem)
   ├─> docker pull / skopeo copy
   ├─> Download de manifest
   ├─> Download de layers
   ├─> Verificação de checksums (SHA256)
   └─> Imagem local disponível

4. RUN (Executar Container)
   ├─> docker run / runc run
   ├─> Extrai layers
   ├─> Cria bundle OCI (rootfs + config.json)
   ├─> Runtime executa (OCI Runtime Spec)
   └─> Container rodando
```

---

## Exemplo Completo: Do Build ao Run

```bash
# 1. Criar Dockerfile
cat > Dockerfile << 'EOF'
FROM alpine:latest
RUN apk add --no-cache curl
COPY app.sh /app.sh
RUN chmod +x /app.sh
CMD ["/app.sh"]
EOF

# 2. Criar aplicação
cat > app.sh << 'EOF'
#!/bin/sh
echo "Hello from OCI container!"
curl -s https://api.github.com/repos/opencontainers/runc
EOF

# 3. Build da imagem (cria imagem OCI)
docker build -t myapp:v1 .

# 4. Inspecionar imagem OCI
docker inspect myapp:v1

# Ver layers
docker history myapp:v1

# 5. Exportar para formato OCI puro
skopeo copy docker-daemon:myapp:v1 oci:myapp-oci:v1

# 6. Ver estrutura OCI
ls -la myapp-oci/
cat myapp-oci/index.json
cat myapp-oci/oci-layout

# 7. Push para registry OCI
docker tag myapp:v1 localhost:5000/myapp:v1
docker push localhost:5000/myapp:v1

# 8. Pull e executar (usa OCI Runtime Spec)
docker pull localhost:5000/myapp:v1
docker run --rm localhost:5000/myapp:v1
```

---

## Ferramentas OCI

### Buildah - Build de imagens OCI

```bash
# Criar container base
buildah from alpine

# Executar comandos
buildah run alpine-working-container apk add curl

# Copiar arquivos
buildah copy alpine-working-container app.sh /app.sh

# Configurar
buildah config --cmd /app.sh alpine-working-container

# Commit para imagem OCI
buildah commit alpine-working-container myapp:v1
```

### Skopeo - Trabalhar com imagens OCI

```bash
# Copiar entre formatos
skopeo copy docker://nginx:alpine oci:nginx:latest

# Inspecionar sem pull
skopeo inspect docker://nginx:alpine

# Deletar imagem de registry
skopeo delete docker://registry.io/myapp:old

# Sincronizar imagens
skopeo sync --src docker --dest dir nginx:alpine /tmp/images
```

### Podman - Runtime OCI-compliant

```bash
# Executar container (usa OCI Runtime Spec)
podman run -d nginx:alpine

# Gerar especificação OCI
podman generate spec mycontainer > config.json

# Executar com runc diretamente
podman export mycontainer | tar -C rootfs -xf -
runc run mycontainer
```

---

## Verificando Conformidade

```bash
# Ver versão OCI do runtime
runc --version
# runc version 1.1.0
# spec: 1.0.2-dev

# Ver especificação no config.json
cat config.json | jq '.ociVersion'
# "1.0.2"

# Validar bundle
oci-runtime-tool validate

# Testar runtime com bundle de teste
git clone https://github.com/opencontainers/runtime-tools
cd runtime-tools
make
./oci-runtime-tool generate
runc run test-container
```

---

## Benefícios Práticos

### Interoperabilidade

```bash
# Imagem criada com Docker
docker build -t myapp:v1 .

# Executada com Podman
podman run myapp:v1

# Executada com containerd
ctr image pull docker.io/library/myapp:v1
ctr run docker.io/library/myapp:v1 myapp

# Todas funcionam porque seguem OCI!
```

### Portabilidade

```bash
# Build local
docker build -t myapp:v1 .

# Push para AWS ECR (OCI-compliant)
docker tag myapp:v1 123456.dkr.ecr.us-east-1.amazonaws.com/myapp:v1
docker push 123456.dkr.ecr.us-east-1.amazonaws.com/myapp:v1

# Pull e run em qualquer lugar
docker pull 123456.dkr.ecr.us-east-1.amazonaws.com/myapp:v1
docker run 123456.dkr.ecr.us-east-1.amazonaws.com/myapp:v1
```
