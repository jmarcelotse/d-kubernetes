#!/bin/bash

# User data script para preparar instâncias para Kubernetes

# Atualizar sistema
apt-get update
apt-get upgrade -y

# Instalar pacotes básicos
apt-get install -y \
    curl \
    wget \
    vim \
    git \
    apt-transport-https \
    ca-certificates \
    software-properties-common

# Configurar timezone
timedatectl set-timezone America/Sao_Paulo

# Desabilitar swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Carregar módulos do kernel
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configurar parâmetros sysctl
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Log de conclusão
echo "$(date) - Instância preparada para Kubernetes" >> /var/log/user-data.log
