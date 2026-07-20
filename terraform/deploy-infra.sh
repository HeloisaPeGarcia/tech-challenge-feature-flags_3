#!/usr/bin/env bash

# Script para facilitar a execução local do Terraform
# Uso: ./deploy-infra.sh [plan|apply|destroy] [true|false (use_aws_academy)]

ACTION=${1:-"plan"}
USE_ACADEMY=${2:-"true"}
AWS_REGION="us-east-1"

# Nome do bucket derivado do usuário local — deve ser único globalmente
GIT_USER=$(git config user.name 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-' || echo "user")
TF_STATE_BUCKET="togglemaster-tfstate-${GIT_USER}"
TF_LOCK_TABLE="terraform-lock-table"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}===================================================${NC}"
echo -e "${YELLOW} Executando Terraform para o Tech Challenge ${NC}"
echo -e "${YELLOW} Ação: $ACTION | AWS Academy (LabRole): $USE_ACADEMY ${NC}"
echo -e "${YELLOW} Bucket S3: $TF_STATE_BUCKET ${NC}"
echo -e "${YELLOW}===================================================${NC}"

# Verificar se o terraform está instalado
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Erro: Terraform não encontrado no path. Por favor instale-o.${NC}"
    exit 1
fi

# Criar bucket S3 se não existir
echo -e "\n${GREEN}[0/4] Verificando bucket S3 para o Terraform State...${NC}"
if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
  echo -e "${GREEN}✅ Bucket $TF_STATE_BUCKET já existe.${NC}"
else
  echo -e "${YELLOW}🪣 Criando bucket S3: $TF_STATE_BUCKET ...${NC}"
  aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION"
  aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" \
    --versioning-configuration Status=Enabled
  echo -e "${GREEN}✅ Bucket criado com versionamento ativo.${NC}"
fi

# Criar tabela DynamoDB de lock se não existir
if ! aws dynamodb describe-table --table-name "$TF_LOCK_TABLE" 2>/dev/null; then
  echo -e "${YELLOW}🔒 Criando tabela DynamoDB de lock: $TF_LOCK_TABLE ...${NC}"
  aws dynamodb create-table \
    --table-name "$TF_LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
  aws dynamodb wait table-exists --table-name "$TF_LOCK_TABLE"
  echo -e "${GREEN}✅ Tabela de lock criada.${NC}"
fi

# Inicializar
echo -e "\n${GREEN}[1/4] Inicializando Terraform (init)...${NC}"
terraform init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="dynamodb_table=$TF_LOCK_TABLE"

# Validar
echo -e "\n${GREEN}[2/4] Validando sintaxe e arquivos...${NC}"
terraform validate
if [ $? -ne 0 ]; then
    echo -e "${RED}Erro de validação detectado! Corrija os arquivos antes de prosseguir.${NC}"
    exit 1
fi

# Executar Ação
echo -e "\n${GREEN}[3/4] Executando ação: $ACTION...${NC}"
if [ "$ACTION" == "plan" ]; then
    terraform plan -var="use_aws_academy=$USE_ACADEMY"
elif [ "$ACTION" == "apply" ]; then
    terraform apply -auto-approve -var="use_aws_academy=$USE_ACADEMY"

    # Após o apply, exibir os outputs para facilitar a configuração manual
    echo -e "\n${GREEN}[4/4] Outputs do Terraform (copie para o ConfigMap se necessário):${NC}"
    terraform output
elif [ "$ACTION" == "destroy" ]; then
    terraform destroy -auto-approve -var="use_aws_academy=$USE_ACADEMY"
else
    echo -e "${RED}Erro: Ação inválida '$ACTION'. Use 'plan', 'apply' ou 'destroy'.${NC}"
    exit 1
fi
