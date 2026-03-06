# Terraform K8s Cluster AWS (Modular)

Infraestrutura como código para criar cluster Kubernetes na AWS usando módulos.

## Estrutura

```
terraform/
├── main.tf                  # Orquestração dos módulos
├── variables.tf             # Variáveis globais
├── outputs.tf               # Outputs globais
├── terraform.tfvars.example # Exemplo de configuração
├── README.md                # Este arquivo
└── modules/
    ├── network/             # Módulo de rede (VPC, Subnet, IGW)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security/            # Módulo de segurança (Security Group)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── compute/             # Módulo de compute (EC2)
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── user-data.sh
```

## Pré-requisitos

```bash
# Instalar Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verificar
terraform version

# Configurar AWS CLI
aws configure
```

## Configuração

### 1. Gerar chave SSH (se não tiver)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### 2. Criar arquivo terraform.tfvars (opcional)

```hcl
# terraform.tfvars
aws_region           = "us-east-1"
cluster_name         = "meu-k8s"
master_count         = 2
worker_count         = 3
master_instance_type = "t3.medium"
worker_instance_type = "t3.medium"
public_key_path      = "~/.ssh/id_rsa.pub"
```

## Uso

### Inicializar Terraform

```bash
terraform init
```

### Validar configuração

```bash
terraform validate
```

### Ver plano de execução

```bash
terraform plan
```

### Aplicar (criar infraestrutura)

```bash
terraform apply

# Ou sem confirmação
terraform apply -auto-approve
```

### Ver outputs

```bash
# Todos os outputs
terraform output

# Output específico
terraform output master_public_ips
terraform output worker_public_ips

# Formato JSON
terraform output -json all_instances | jq
```

### Gerar inventário Ansible

```bash
cat > inventory.ini <<EOF
[masters]
$(terraform output -json master_public_ips | jq -r '.[]' | awk '{print "k8s-master-" NR " ansible_host=" $1}')

[workers]
$(terraform output -json worker_public_ips | jq -r '.[]' | awk '{print "k8s-worker-" NR " ansible_host=" $1}')

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
```

### Conectar via SSH

```bash
# Master 1
terraform output -raw ssh_command_master_1 | bash

# Ou manualmente
ssh -i ~/.ssh/id_rsa ubuntu@$(terraform output -raw master_public_ips | jq -r '.[0]')
```

### Destruir infraestrutura

```bash
terraform destroy

# Ou sem confirmação
terraform destroy -auto-approve
```

## Recursos Criados

- **VPC** (10.0.0.0/16)
- **Subnet** pública (10.0.1.0/24)
- **Internet Gateway**
- **Route Table**
- **Security Group** com portas do Kubernetes
- **Key Pair** para SSH
- **2 instâncias Master** (t3.medium, 30GB)
- **3 instâncias Worker** (t3.medium, 50GB)

## Portas Configuradas

| Porta | Protocolo | Descrição |
|-------|-----------|-----------|
| 22 | TCP | SSH |
| 6443 | TCP | Kubernetes API |
| 2379-2380 | TCP | etcd |
| 10250 | TCP | Kubelet API |
| 10257 | TCP | kube-controller-manager |
| 10259 | TCP | kube-scheduler |
| 30000-32767 | TCP | NodePort Services |
| 179 | TCP | Calico BGP |
| 4789 | UDP | Calico VXLAN |

## Customização

### Alterar número de nós

```bash
terraform apply -var="master_count=3" -var="worker_count=5"
```

### Alterar tipo de instância

```bash
terraform apply -var="master_instance_type=t3.large" -var="worker_instance_type=t3.large"
```

### Alterar região

```bash
terraform apply -var="aws_region=us-west-2"
```

## Estimativa de Custos (us-east-1)

```
Instâncias:
- 2x t3.medium (masters): ~$60/mês
- 3x t3.medium (workers): ~$90/mês

Armazenamento:
- 2x 30GB + 3x 50GB: ~$17/mês

Total: ~$167/mês
```

## Troubleshooting

### Erro: InvalidKeyPair.NotFound

```bash
# Verificar se a chave pública existe
ls -l ~/.ssh/id_rsa.pub

# Gerar nova chave
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Erro: VPC limit exceeded

```bash
# Listar VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table

# Deletar VPCs não utilizadas
aws ec2 delete-vpc --vpc-id vpc-xxxxx
```

### Ver logs do user-data

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<IP>
sudo cat /var/log/user-data.log
sudo cat /var/log/cloud-init-output.log
```

## Próximos Passos

Após criar a infraestrutura:

1. Instalar containerd em todos os nós
2. Instalar kubeadm, kubelet, kubectl
3. Inicializar control plane no master-1
4. Instalar CNI (Calico)
5. Adicionar workers ao cluster

## Comandos Úteis

```bash
# Ver estado do Terraform
terraform show

# Listar recursos
terraform state list

# Ver recurso específico
terraform state show aws_instance.k8s_masters[0]

# Importar recurso existente
terraform import aws_instance.k8s_masters[0] i-xxxxx

# Formatar código
terraform fmt

# Atualizar providers
terraform init -upgrade
```
