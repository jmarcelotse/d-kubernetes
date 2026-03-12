# Instalando um Cluster EKS para os Nossos Testes

## Introdução

Amazon EKS (Elastic Kubernetes Service) é o serviço gerenciado de Kubernetes da AWS. Ele elimina a necessidade de instalar, operar e manter o control plane do Kubernetes, permitindo focar apenas nas aplicações.

## O que é EKS?

### Conceito

```
┌─────────────────────────────────────────┐
│         AWS Gerencia (Control Plane)    │
│  ┌────────────┐  ┌────────────┐        │
│  │ API Server │  │   etcd     │        │
│  └────────────┘  └────────────┘        │
│  ┌────────────┐  ┌────────────┐        │
│  │ Scheduler  │  │ Controller │        │
│  └────────────┘  └────────────┘        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│      Você Gerencia (Worker Nodes)       │
│  ┌──────┐  ┌──────┐  ┌──────┐          │
│  │ EC2  │  │ EC2  │  │ EC2  │          │
│  │ Node │  │ Node │  │ Node │          │
│  └──────┘  └──────┘  └──────┘          │
└─────────────────────────────────────────┘
```

### Vantagens do EKS

- **Control Plane Gerenciado**: AWS cuida da alta disponibilidade
- **Integração AWS**: IAM, VPC, ELB, EBS, etc.
- **Atualizações Automáticas**: Kubernetes sempre atualizado
- **Segurança**: Integração com AWS Security Services
- **Escalabilidade**: Auto Scaling Groups integrado

---

## Pré-requisitos

### 1. Ferramentas Necessárias

```bash
# Verificar versões
aws --version      # AWS CLI v2
kubectl version    # kubectl
eksctl version     # eksctl
```

### 2. Instalar AWS CLI

```bash
# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# macOS
brew install awscli

# Verificar
aws --version
```

### 3. Instalar kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# macOS
brew install kubectl

# Verificar
kubectl version --client
```

### 4. Instalar eksctl

```bash
# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Verificar
eksctl version
```

### 5. Configurar AWS CLI

```bash
# Configurar credenciais
aws configure

# Informações necessárias:
# AWS Access Key ID: [sua-access-key]
# AWS Secret Access Key: [sua-secret-key]
# Default region name: us-east-1
# Default output format: json

# Verificar configuração
aws sts get-caller-identity

# Output esperado:
# {
#     "UserId": "AIDAXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/seu-usuario"
# }
```

---

## Método 1: Criar Cluster com eksctl (Recomendado)

### 1.1 Cluster Básico

```bash
# Criar cluster simples
eksctl create cluster \
  --name meu-cluster-eks \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# Tempo estimado: 15-20 minutos
```

### 1.2 Verificar Criação

```bash
# Ver status do cluster
eksctl get cluster --name meu-cluster-eks --region us-east-1

# Ver nodes
kubectl get nodes

# Ver pods do sistema
kubectl get pods -n kube-system

# Ver informações do cluster
kubectl cluster-info
```

### 1.3 Cluster com Arquivo de Configuração

Crie o arquivo `eks-cluster.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: meu-cluster-eks
  region: us-east-1
  version: "1.28"

# VPC Configuration
vpc:
  cidr: 10.0.0.0/16
  nat:
    gateway: Single

# IAM Configuration
iam:
  withOIDC: true

# Node Groups
managedNodeGroups:
  - name: workers-general
    instanceType: t3.medium
    minSize: 2
    maxSize: 4
    desiredCapacity: 2
    volumeSize: 20
    ssh:
      allow: false
    labels:
      role: worker
      environment: test
    tags:
      nodegroup-role: worker
    iam:
      withAddonPolicies:
        imageBuilder: true
        autoScaler: true
        ebs: true
        efs: true
        albIngress: true
        cloudWatch: true

# CloudWatch Logging
cloudWatch:
  clusterLogging:
    enableTypes:
      - api
      - audit
      - authenticator
      - controllerManager
      - scheduler
```

### 1.4 Criar Cluster com Arquivo

```bash
# Criar cluster
eksctl create cluster -f eks-cluster.yaml

# Verificar
kubectl get nodes
kubectl get pods --all-namespaces
```

---

## Método 2: Criar Cluster com AWS Console

### 2.1 Fluxo no Console

```
1. AWS Console → EKS → Create Cluster
2. Configure cluster:
   - Name: meu-cluster-eks
   - Kubernetes version: 1.28
   - Cluster service role: Criar novo
3. Configure networking:
   - VPC: Criar novo ou usar existente
   - Subnets: Selecionar pelo menos 2
   - Security groups: Default
4. Configure logging: Habilitar logs
5. Review and create
6. Aguardar criação (15-20 min)
7. Adicionar Node Group:
   - Name: workers
   - Instance type: t3.medium
   - Scaling: Min 2, Max 4
```

### 2.2 Configurar kubectl

```bash
# Atualizar kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name meu-cluster-eks

# Verificar
kubectl get svc
kubectl get nodes
```

---

## Método 3: Criar Cluster com Terraform

### 3.1 Estrutura de Arquivos

```
terraform-eks/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

### 3.2 main.tf

Crie o arquivo `main.tf`:

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    workers = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      labels = {
        role        = "worker"
        environment = "test"
      }

      tags = {
        Name = "${var.cluster_name}-worker"
      }
    }
  }

  tags = {
    Environment = "test"
    Terraform   = "true"
  }
}
```

### 3.3 variables.tf

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "meu-cluster-eks"
}
```

### 3.4 outputs.tf

```hcl
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
```

### 3.5 Aplicar Terraform

```bash
# Inicializar
terraform init

# Planejar
terraform plan

# Aplicar
terraform apply -auto-approve

# Configurar kubectl
aws eks update-kubeconfig --region us-east-1 --name meu-cluster-eks

# Verificar
kubectl get nodes
```

---

## Configuração Pós-Instalação

### 1. Instalar AWS Load Balancer Controller

```bash
# Criar IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Criar service account
eksctl create iamserviceaccount \
  --cluster=meu-cluster-eks \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Instalar via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=meu-cluster-eks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verificar
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 2. Instalar EBS CSI Driver

```bash
# Criar IAM role
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster meu-cluster-eks \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole

# Instalar addon
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster meu-cluster-eks \
  --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole \
  --force

# Verificar
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

### 3. Instalar Metrics Server

```bash
# Instalar
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verificar
kubectl get deployment metrics-server -n kube-system

# Testar
kubectl top nodes
kubectl top pods -A
```

### 4. Instalar Nginx Ingress Controller

```bash
# Instalar via Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Verificar
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Obter LoadBalancer URL
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## Testar o Cluster

### 1. Deploy de Aplicação de Teste

```bash
# Criar deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expor via LoadBalancer
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Aguardar LoadBalancer
kubectl get svc nginx -w

# Obter URL
NGINX_URL=$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "http://$NGINX_URL"

# Testar
curl http://$NGINX_URL
```

### 2. Testar Ingress

Crie o arquivo `test-ingress.yaml`:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: app-test-service
spec:
  selector:
    app: test
  ports:
  - port: 80
    targetPort: 80

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-test-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-test-service
            port:
              number: 80
```

```bash
# Aplicar
kubectl apply -f test-ingress.yaml

# Verificar
kubectl get ingress app-test-ingress

# Obter endereço do Ingress
INGRESS_URL=$(kubectl get ingress app-test-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Testar
curl -H "Host: test.example.com" http://$INGRESS_URL
```

---

## Gerenciamento do Cluster

### Escalar Node Group

```bash
# Via eksctl
eksctl scale nodegroup \
  --cluster=meu-cluster-eks \
  --name=workers \
  --nodes=4 \
  --nodes-min=2 \
  --nodes-max=6

# Via AWS CLI
aws eks update-nodegroup-config \
  --cluster-name meu-cluster-eks \
  --nodegroup-name workers \
  --scaling-config minSize=2,maxSize=6,desiredSize=4
```

### Atualizar Versão do Cluster

```bash
# Verificar versão atual
kubectl version --short

# Atualizar control plane
eksctl upgrade cluster \
  --name=meu-cluster-eks \
  --version=1.29 \
  --approve

# Atualizar node group
eksctl upgrade nodegroup \
  --name=workers \
  --cluster=meu-cluster-eks \
  --kubernetes-version=1.29
```

### Ver Logs do Cluster

```bash
# Via AWS CLI
aws eks describe-cluster \
  --name meu-cluster-eks \
  --query cluster.logging

# Via CloudWatch
aws logs tail /aws/eks/meu-cluster-eks/cluster --follow
```

---

## Monitoramento e Observabilidade

### 1. CloudWatch Container Insights

```bash
# Instalar
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/meu-cluster-eks/;s/{{region_name}}/us-east-1/" | kubectl apply -f -

# Verificar
kubectl get pods -n amazon-cloudwatch
```

### 2. Prometheus e Grafana

```bash
# Adicionar repo Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Instalar Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Verificar
kubectl get pods -n monitoring

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Acessar: http://localhost:3000
# User: admin
# Password: prom-operator
```

---

## Custos e Otimização

### Estimativa de Custos

```
EKS Control Plane: $0.10/hora = ~$73/mês
EC2 t3.medium (2 nodes): $0.0416/hora × 2 × 730h = ~$61/mês
EBS (40GB): $0.10/GB × 40 = $4/mês
LoadBalancer: $0.025/hora = ~$18/mês
Data Transfer: Variável

Total estimado: ~$156/mês
```

### Dicas de Economia

```bash
# 1. Usar Spot Instances
eksctl create nodegroup \
  --cluster=meu-cluster-eks \
  --name=workers-spot \
  --node-type=t3.medium \
  --nodes=2 \
  --spot

# 2. Usar Fargate (serverless)
eksctl create fargateprofile \
  --cluster meu-cluster-eks \
  --name fp-default \
  --namespace default

# 3. Auto Scaling com Cluster Autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# 4. Deletar recursos não utilizados
kubectl delete svc nginx
kubectl delete deployment nginx
```

---

## Troubleshooting

### Problema 1: Nodes Não Aparecem

```bash
# Verificar node group
eksctl get nodegroup --cluster=meu-cluster-eks

# Ver logs do node
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=meu-cluster-eks" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'

# Verificar IAM roles
aws eks describe-cluster --name meu-cluster-eks --query cluster.roleArn
```

### Problema 2: kubectl Não Conecta

```bash
# Reconfigurar kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name meu-cluster-eks

# Verificar contexto
kubectl config current-context

# Testar conectividade
kubectl get svc
```

### Problema 3: Pods em Pending

```bash
# Ver eventos
kubectl get events --sort-by=.metadata.creationTimestamp

# Verificar recursos
kubectl describe nodes

# Ver logs do scheduler
kubectl logs -n kube-system -l component=kube-scheduler
```

### Problema 4: LoadBalancer Não Cria

```bash
# Verificar AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# Ver logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verificar IAM permissions
aws iam get-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy
```

---

## Deletar o Cluster

### Método 1: eksctl

```bash
# Deletar cluster completo
eksctl delete cluster --name meu-cluster-eks --region us-east-1

# Verificar
aws eks list-clusters --region us-east-1
```

### Método 2: Terraform

```bash
# Destruir infraestrutura
terraform destroy -auto-approve

# Verificar
aws eks list-clusters --region us-east-1
```

### Método 3: Manual

```bash
# 1. Deletar node groups
eksctl delete nodegroup --cluster=meu-cluster-eks --name=workers

# 2. Deletar cluster
aws eks delete-cluster --name meu-cluster-eks --region us-east-1

# 3. Deletar VPC e recursos associados (via Console)
```

---

## Resumo dos Comandos

```bash
# Criar cluster
eksctl create cluster --name meu-cluster-eks --region us-east-1

# Configurar kubectl
aws eks update-kubeconfig --region us-east-1 --name meu-cluster-eks

# Verificar
kubectl get nodes
kubectl get pods --all-namespaces

# Instalar addons
eksctl create addon --name aws-ebs-csi-driver --cluster meu-cluster-eks

# Escalar
eksctl scale nodegroup --cluster=meu-cluster-eks --name=workers --nodes=4

# Deletar
eksctl delete cluster --name meu-cluster-eks --region us-east-1
```

---

## Próximos Passos

1. **Configurar CI/CD** com AWS CodePipeline ou GitHub Actions
2. **Implementar GitOps** com ArgoCD ou Flux
3. **Configurar Service Mesh** com Istio ou AWS App Mesh
4. **Adicionar Segurança** com Falco, OPA, Kyverno
5. **Backup e Disaster Recovery** com Velero
6. **Cost Management** com Kubecost

---

## Conclusão

Você agora tem um cluster EKS completo e funcional com:

✅ Control Plane gerenciado pela AWS  
✅ Worker nodes escaláveis  
✅ Load Balancer Controller configurado  
✅ EBS CSI Driver para volumes  
✅ Metrics Server para monitoramento  
✅ Nginx Ingress Controller  
✅ Integração completa com AWS  

O cluster está pronto para receber suas aplicações e testes de Ingress!
