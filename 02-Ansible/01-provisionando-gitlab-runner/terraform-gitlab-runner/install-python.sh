#!/bin/bash
# set -e: para no primeiro erro, para o SSM reportar falha de verdade (e o apply
# do Terraform abortar) em vez de seguir e marcar 'Success' enganosamente.
set -euo pipefail

echo "== bootstrap do GitLab Runner: preparando Python/pip/awscli para o Ansible =="

export DEBIAN_FRONTEND=noninteractive
apt-get update -y

# Usamos o Python 3 NATIVO do Ubuntu 22.04 (3.10). Nao usamos mais o PPA deadsnakes
# nem python3.8: o virtualenv moderno nao suporta mais 3.8, e o python3 do SO ja
# atende o Ansible. So garantimos pip, venv e utilitarios.
apt-get install -y python3 python3-pip python3-venv python3-apt unzip curl

# AWS CLI v2 oficial (nao o awscli v1 do apt). O v1 do apt depende de um botocore
# antigo do sistema e quebra ('KeyError: opsworkscm') quando outra lib atualiza o
# botocore global. O v2 e um binario autocontido, sem essa fragilidade.
if ! command -v aws >/dev/null || ! aws --version 2>/dev/null | grep -q 'aws-cli/2'; then
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  AWS_ZIP="awscli-exe-linux-x86_64.zip" ;;
    aarch64) AWS_ZIP="awscli-exe-linux-aarch64.zip" ;;
    *) echo "ERRO: arquitetura $ARCH nao suportada para o AWS CLI v2." >&2; exit 1 ;;
  esac
  curl -sSL "https://awscli.amazonaws.com/$AWS_ZIP" -o /tmp/awscliv2.zip
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
fi

# Alias 'python' -> python3 do sistema, por conveniencia. Nao trocamos o python3
# default (faria apt_pkg quebrar): apenas adicionamos o comando 'python'.
update-alternatives --install /usr/bin/python python /usr/bin/python3 1

python --version
aws --version
echo "== bootstrap concluido =="
