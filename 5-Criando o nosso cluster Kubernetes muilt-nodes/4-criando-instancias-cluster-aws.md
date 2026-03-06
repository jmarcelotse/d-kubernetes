# Criando Instâncias para o Cluster Kubernetes na AWS

Este guia mostra como criar e configurar instâncias EC2 na AWS para montar um cluster Kubernetes multi-nós usando kubeadm.

## Arquitetura do Cluster

```
┌─────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │         Subnet Pública (10.0.1.0/24)           │    │
│  ├────────────────────────────────────────────────┤    │
│  │                                                 │    │
│  │  ┌──────────────┐  ┌──────────────┐           │    │
│  │  │ k8s-master-1 │  │ k8s-master-2 │           │    │
│  │  │ 10.0.1.10    │  │ 10.0.1.11    │           │    │
│  │  │ t3.medium    │  │ t3.medium    │           │    │
│  │  └──────────────┘  └──────────────┘           │    │
│  │                                                 │    │
│  │  ┌──────────────┐  ┌──────────────┐           │    │
│  │  │ k8s-worker-1 │  │ k8s-worker-2 │           │    │
│  │  │ 10.0.1.20    │  │ 10.0.1.21    │           │    │
│  │  │ t3.medium    │  │ t3.medium    │           │    │
│  │  └──────────────┘  └──────────────┘           │    │
│  │                                                 │    │
│  │  ┌──────────────┐                              │    │
│  │  │ k8s-worker-3 │                              │    │
│  │  │ 10.0.1.22    │                              │    │
│  │  │ t3.medium    │                              │    │
│  │  └──────────────┘                              │    │
│  │                                                 │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  Security Group: k8s-cluster-sg                         │
│  - SSH (22)                                              │
│  - API Server (6443)                                     │
│  - etcd (2379-2380)                                      │
│  - Kubelet (10250)                                       │
│  - NodePort (30000-32767)                                │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Especificações das Instâncias

### Control Plane (Masters)

```
Quantidade: 2 instâncias
Tipo: t3.medium
vCPUs: 2
RAM: 4 GB
Disco: 30 GB gp3
SO: Ubuntu 22.04 LTS
```

### Worker Nodes

```
Quantidade: 3 instâncias
Tipo: t3.medium
vCPUs: 2
RAM: 4 GB
Disco: 50 GB gp3
SO: Ubuntu 22.04 LTS
```

## Pré-requisitos

```bash
# Instalar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verificar instalação
aws --version

# Configurar credenciais
aws configure
# AWS Access Key ID: <sua-access-key>
# AWS Secret Access Key: <sua-secret-key>
# Default region name: us-east-1
# Default output format: json

# Verificar configuração
aws sts get-caller-identity
```

## 1. Criar VPC e Subnet

### Via AWS CLI

```bash
# Criar VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=k8s-vpc}]' \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC criada: $VPC_ID"

# Habilitar DNS
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames

aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support

# Criar Subnet
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=k8s-subnet}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Subnet criada: $SUBNET_ID"

# Habilitar IP público automático
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch

# Criar Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=k8s-igw}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

echo "Internet Gateway criado: $IGW_ID"

# Anexar IGW à VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

# Criar Route Table
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=k8s-rtb}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

echo "Route Table criada: $RTB_ID"

# Adicionar rota para internet
aws ec2 create-route \
  --route-table-id $RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associar Route Table à Subnet
aws ec2 associate-route-table \
  --subnet-id $SUBNET_ID \
  --route-table-id $RTB_ID
```

### Via Terraform (Alternativa)

```hcl
# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "k8s-vpc"
  }
}

# Subnet
resource "aws_subnet" "k8s_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-igw"
  }
}

# Route Table
resource "aws_route_table" "k8s_rtb" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }

  tags = {
    Name = "k8s-rtb"
  }
}

# Route Table Association
resource "aws_route_table_association" "k8s_rta" {
  subnet_id      = aws_subnet.k8s_subnet.id
  route_table_id = aws_route_table.k8s_rtb.id
}

# Outputs
output "vpc_id" {
  value = aws_vpc.k8s_vpc.id
}

output "subnet_id" {
  value = aws_subnet.k8s_subnet.id
}
```

```bash
# Aplicar Terraform
terraform init
terraform plan
terraform apply -auto-approve

# Obter outputs
VPC_ID=$(terraform output -raw vpc_id)
SUBNET_ID=$(terraform output -raw subnet_id)
```

## 2. Criar Security Group

```bash
# Criar Security Group
SG_ID=$(aws ec2 create-security-group \
  --group-name k8s-cluster-sg \
  --description "Security group for Kubernetes cluster" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=k8s-cluster-sg}]' \
  --query 'GroupId' \
  --output text)

echo "Security Group criado: $SG_ID"

# Regra: SSH (22)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Regra: API Server (6443)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 6443 \
  --cidr 0.0.0.0/0

# Regra: etcd (2379-2380)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 2379-2380 \
  --source-group $SG_ID

# Regra: Kubelet API (10250)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 10250 \
  --source-group $SG_ID

# Regra: kube-scheduler (10259)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 10259 \
  --source-group $SG_ID

# Regra: kube-controller-manager (10257)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 10257 \
  --source-group $SG_ID

# Regra: NodePort Services (30000-32767)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 30000-32767 \
  --cidr 0.0.0.0/0

# Regra: Calico BGP (179)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 179 \
  --source-group $SG_ID

# Regra: Calico VXLAN (4789)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol udp \
  --port 4789 \
  --source-group $SG_ID

# Regra: Todo tráfego interno do cluster
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol all \
  --source-group $SG_ID

# Verificar regras
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions'
```

### Tabela de Portas Kubernetes

| Porta | Protocolo | Componente | Descrição |
|-------|-----------|------------|-----------|
| 6443 | TCP | API Server | Acesso à API do Kubernetes |
| 2379-2380 | TCP | etcd | Comunicação do etcd |
| 10250 | TCP | Kubelet | API do Kubelet |
| 10259 | TCP | kube-scheduler | Scheduler |
| 10257 | TCP | kube-controller-manager | Controller Manager |
| 30000-32767 | TCP | NodePort | Serviços NodePort |
| 179 | TCP | Calico | BGP |
| 4789 | UDP | Calico | VXLAN |


## 3. Criar Key Pair para SSH

```bash
# Criar key pair
aws ec2 create-key-pair \
  --key-name k8s-cluster-key \
  --query 'KeyMaterial' \
  --output text > k8s-cluster-key.pem

# Ajustar permissões
chmod 400 k8s-cluster-key.pem

# Verificar
ls -l k8s-cluster-key.pem
```

## 4. Obter AMI do Ubuntu 22.04

```bash
# Buscar AMI mais recente do Ubuntu 22.04
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

echo "AMI ID: $AMI_ID"

# Verificar detalhes da AMI
aws ec2 describe-images \
  --image-ids $AMI_ID \
  --query 'Images[0].[ImageId,Name,CreationDate]' \
  --output table
```

## 5. Criar Instâncias EC2

### Script para Criar Todas as Instâncias

```bash
#!/bin/bash
# create-k8s-instances.sh

# Variáveis (ajustar conforme necessário)
VPC_ID="vpc-xxxxxxxxx"
SUBNET_ID="subnet-xxxxxxxxx"
SG_ID="sg-xxxxxxxxx"
AMI_ID="ami-xxxxxxxxx"
KEY_NAME="k8s-cluster-key"

# Função para criar instância
create_instance() {
    local NAME=$1
    local PRIVATE_IP=$2
    local INSTANCE_TYPE=${3:-t3.medium}
    local VOLUME_SIZE=${4:-30}
    
    echo "Criando instância: $NAME"
    
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --subnet-id $SUBNET_ID \
        --security-group-ids $SG_ID \
        --private-ip-address $PRIVATE_IP \
        --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$VOLUME_SIZE,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=Cluster,Value=k8s-cluster}]" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    echo "Instância criada: $INSTANCE_ID"
    
    # Aguardar instância ficar running
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
    echo "Instância $NAME está running"
}

# Criar Control Planes
create_instance "k8s-master-1" "10.0.1.10" "t3.medium" "30"
create_instance "k8s-master-2" "10.0.1.11" "t3.medium" "30"

# Criar Workers
create_instance "k8s-worker-1" "10.0.1.20" "t3.medium" "50"
create_instance "k8s-worker-2" "10.0.1.21" "t3.medium" "50"
create_instance "k8s-worker-3" "10.0.1.22" "t3.medium" "50"

echo "Todas as instâncias foram criadas!"
```

```bash
# Executar script
chmod +x create-k8s-instances.sh
./create-k8s-instances.sh
```

### Criar Instâncias Individualmente

```bash
# Master 1
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name k8s-cluster-key \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --private-ip-address 10.0.1.10 \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k8s-master-1}]'

# Master 2
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name k8s-cluster-key \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --private-ip-address 10.0.1.11 \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k8s-master-2}]'

# Worker 1
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name k8s-cluster-key \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --private-ip-address 10.0.1.20 \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k8s-worker-1}]'

# Worker 2
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name k8s-cluster-key \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --private-ip-address 10.0.1.21 \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k8s-worker-2}]'

# Worker 3
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name k8s-cluster-key \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --private-ip-address 10.0.1.22 \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k8s-worker-3}]'
```

## 6. Verificar Instâncias Criadas

```bash
# Listar todas as instâncias do cluster
aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=k8s-cluster" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name,PrivateIpAddress,PublicIpAddress]' \
  --output table

# Saída esperada:
# ------------------------------------------------
# |              DescribeInstances               |
# +---------------+-------------+--------+-------+
# |  k8s-master-1 | i-xxxxx... | running| 10.0.1.10 | 54.xxx.xxx.xxx |
# |  k8s-master-2 | i-xxxxx... | running| 10.0.1.11 | 54.xxx.xxx.xxx |
# |  k8s-worker-1 | i-xxxxx... | running| 10.0.1.20 | 54.xxx.xxx.xxx |
# |  k8s-worker-2 | i-xxxxx... | running| 10.0.1.21 | 54.xxx.xxx.xxx |
# |  k8s-worker-3 | i-xxxxx... | running| 10.0.1.22 | 54.xxx.xxx.xxx |
# +---------------+-------------+--------+-------+

# Obter apenas IPs públicos
aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=k8s-cluster" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
  --output text
```

## 7. Criar Arquivo de Inventário

```bash
# Script para gerar inventário Ansible
cat > generate-inventory.sh <<'EOF'
#!/bin/bash

echo "[masters]" > inventory.ini

aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=k8s-master-*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress]' \
  --output text | while read name public_ip private_ip; do
    echo "$name ansible_host=$public_ip private_ip=$private_ip" >> inventory.ini
done

echo "" >> inventory.ini
echo "[workers]" >> inventory.ini

aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=k8s-worker-*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress]' \
  --output text | while read name public_ip private_ip; do
    echo "$name ansible_host=$public_ip private_ip=$private_ip" >> inventory.ini
done

echo "" >> inventory.ini
echo "[all:vars]" >> inventory.ini
echo "ansible_user=ubuntu" >> inventory.ini
echo "ansible_ssh_private_key_file=./k8s-cluster-key.pem" >> inventory.ini
echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> inventory.ini

cat inventory.ini
EOF

chmod +x generate-inventory.sh
./generate-inventory.sh
```

**Arquivo gerado (inventory.ini):**

```ini
[masters]
k8s-master-1 ansible_host=54.xxx.xxx.xxx private_ip=10.0.1.10
k8s-master-2 ansible_host=54.xxx.xxx.xxx private_ip=10.0.1.11

[workers]
k8s-worker-1 ansible_host=54.xxx.xxx.xxx private_ip=10.0.1.20
k8s-worker-2 ansible_host=54.xxx.xxx.xxx private_ip=10.0.1.21
k8s-worker-3 ansible_host=54.xxx.xxx.xxx private_ip=10.0.1.22

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=./k8s-cluster-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

## 8. Criar Arquivo de Hosts

```bash
# Script para gerar /etc/hosts
cat > generate-hosts.sh <<'EOF'
#!/bin/bash

echo "# Kubernetes Cluster Hosts" > hosts-k8s.txt

aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=k8s-cluster" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output text | while read ip name; do
    echo "$ip $name" >> hosts-k8s.txt
done

cat hosts-k8s.txt
EOF

chmod +x generate-hosts.sh
./generate-hosts.sh
```

**Arquivo gerado (hosts-k8s.txt):**

```
# Kubernetes Cluster Hosts
10.0.1.10 k8s-master-1
10.0.1.11 k8s-master-2
10.0.1.20 k8s-worker-1
10.0.1.21 k8s-worker-2
10.0.1.22 k8s-worker-3
```

## 9. Testar Conectividade SSH

```bash
# Script para testar SSH em todas as instâncias
cat > test-ssh.sh <<'EOF'
#!/bin/bash

KEY_FILE="k8s-cluster-key.pem"

aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=k8s-cluster" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
  --output text | while read name ip; do
    echo "Testando SSH em $name ($ip)..."
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$ip "echo 'Conectado com sucesso!'" && echo "✅ $name OK" || echo "❌ $name FALHOU"
done
EOF

chmod +x test-ssh.sh
./test-ssh.sh
```

## 10. Configurar Hostnames nas Instâncias

```bash
# Script para configurar hostname em cada instância
cat > setup-hostnames.sh <<'EOF'
#!/bin/bash

KEY_FILE="k8s-cluster-key.pem"

# Função para configurar hostname
setup_hostname() {
    local NAME=$1
    local IP=$2
    
    echo "Configurando hostname em $NAME..."
    
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ubuntu@$IP << ENDSSH
        sudo hostnamectl set-hostname $NAME
        echo "127.0.0.1 localhost" | sudo tee /etc/hosts
        echo "$IP $NAME" | sudo tee -a /etc/hosts
        
        # Adicionar outros hosts do cluster
        $(cat hosts-k8s.txt | grep -v "^#" | while read line; do echo "echo '$line' | sudo tee -a /etc/hosts"; done)
        
        hostname
ENDSSH
    
    echo "✅ Hostname configurado em $NAME"
}

# Configurar em todas as instâncias
aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=k8s-cluster" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
  --output text | while read name ip; do
    setup_hostname $name $ip
done

echo "Todos os hostnames foram configurados!"
EOF

chmod +x setup-hostnames.sh
./setup-hostnames.sh
```

## 11. Atualizar Sistema em Todas as Instâncias

```bash
# Script para atualizar sistema
cat > update-systems.sh <<'EOF'
#!/bin/bash

KEY_FILE="k8s-cluster-key.pem"

aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=k8s-cluster" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
  --output text | while read name ip; do
    echo "Atualizando $name..."
    
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ubuntu@$ip << 'ENDSSH'
        sudo apt-get update
        sudo apt-get upgrade -y
        sudo apt-get install -y curl wget vim git
ENDSSH
    
    echo "✅ $name atualizado"
done

echo "Todos os sistemas foram atualizados!"
EOF

chmod +x update-systems.sh
./update-systems.sh
```

