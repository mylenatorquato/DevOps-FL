#!/bin/bash

# Atualiza os pacotes
sudo yum update -y

# Instala dependências
sudo yum install -y wget fontconfig java-17-amazon-corretto
java -version

# Adiciona a chave e o repositório do Jenkins
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Instala o Jenkins
sudo yum install -y jenkins

# Inicia e habilita o serviço do Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Verifica o status do Jenkins
sudo systemctl status jenkins