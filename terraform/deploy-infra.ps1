# PowerShell script para facilitar a execução local do Terraform no Windows
# Uso: .\deploy-infra.ps1 -Action "plan" -UseAcademy "true"

param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action = "plan",

    [Parameter(Mandatory=$false)]
    [ValidateSet("true", "false")]
    [string]$UseAcademy = "true"
)

Write-Host "===================================================" -ForegroundColor Yellow
Write-Host " Executando Terraform para o Tech Challenge " -ForegroundColor Yellow
Write-Host " Ação: $Action | AWS Academy (LabRole): $UseAcademy " -ForegroundColor Yellow
Write-Host "===================================================" -ForegroundColor Yellow

# Verificar se o terraform está instalado
if ((Get-Command "terraform" -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host "Erro: Terraform não encontrado. Por favor instale o Terraform e adicione-o ao PATH." -ForegroundColor Red
    exit 1
}

# Inicializar
Write-Host "`n[1/3] Inicializando Terraform (init)..." -ForegroundColor Green
terraform init

# Validar
Write-Host "`n[2/3] Validando sintaxe e arquivos..." -ForegroundColor Green
terraform validate
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro de validação detectado! Corrija os arquivos antes de prosseguir." -ForegroundColor Red
    exit 1
}

# Executar Ação
Write-Host "`n[3/3] Executando ação: $Action..." -ForegroundColor Green
if ($Action -eq "plan") {
    terraform plan -var="use_aws_academy=$UseAcademy"
} elseif ($Action -eq "apply") {
    terraform apply -auto-approve -var="use_aws_academy=$UseAcademy"
} elseif ($Action -eq "destroy") {
    terraform destroy -auto-approve -var="use_aws_academy=$UseAcademy"
}
