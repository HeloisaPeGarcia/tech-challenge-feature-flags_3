# Guia de Implantação Completo — AWS Academy

Este guia descreve o passo a passo **completo e em ordem** para provisionar a infraestrutura e implantar os 5 microsserviços do **ToggleMaster** no ambiente da **AWS Academy (Learner Lab)**.

---

## ⚠️ Restrições do Learner Lab da AWS Academy

| Restrição | Como está contornada |
|-----------|---------------------|
| ❌ Não pode criar IAM Roles/Policies | ✅ Terraform usa a `LabRole` existente via flag `use_aws_academy=true` |
| ❌ Credenciais expiram a cada 4h | ✅ Guia inclui passo de atualização dos Secrets do GitHub |
| ❌ Precisa de `AWS_SESSION_TOKEN` obrigatório | ✅ Todas as pipelines já incluem essa variável |
| ❌ Pods não podem criar roles de IAM (IRSA) | ✅ Pods herdam permissões da `LabRole` via Node Group |
| ❌ Alguns serviços regionais podem estar indisponíveis | ✅ Tudo configurado em `us-east-1` (região padrão do Lab) |

---

## 📋 Passo a Passo Completo

### Passo 1 — Obter as credenciais do Learner Lab

1. Acesse **AWS Academy → Learner Lab**
2. Clique em **Start Lab** e aguarde o ícone ficar verde
3. Clique em **AWS Details → Show** e copie o bloco:
   ```
   [default]
   aws_access_key_id=ASIA...
   aws_secret_access_key=xxxxxxxx
   aws_session_token=xxxxxxxx (longa)
   ```

> [!WARNING]
> Essas credenciais **expiram em 4 horas**. Se qualquer pipeline ou comando falhar com `ExpiredTokenException`, repita este passo e atualize os Secrets do GitHub (Passo 3).

---

### Passo 2 — Criar o bucket S3 para o estado do Terraform (uma vez só, no console)

Este é o **único recurso manual** que precisa existir antes de rodar o Terraform:

1. No console da AWS (dentro do Learner Lab), vá em **S3**
2. Clique em **Create bucket**
3. Nome sugerido: `togglemaster-tfstate-[seu-nome]` (deve ser globalmente único)
4. Região: `us-east-1`
5. **Desabilite** o bloqueio público: Deixe marcado "Block all public access" ✅
6. Clique em **Create bucket**
7. Abra o arquivo `terraform/backend.tf` e substitua o campo `bucket` pelo nome que você escolheu:
   ```hcl
   backend "s3" {
     bucket = "togglemaster-tfstate-[seu-nome]"  # ← altere aqui
     key    = "dev/terraform.tfstate"
     region = "us-east-1"
   }
   ```

---

### Passo 3 — Cadastrar os Secrets no GitHub

Acesse seu repositório no GitHub → **Settings → Secrets and variables → Actions → New repository secret** e adicione:

| Secret | Onde Buscar o Valor |
|--------|---------------------|
| `AWS_ACCESS_KEY_ID` | Copiado no Passo 1 |
| `AWS_SECRET_ACCESS_KEY` | Copiado no Passo 1 |
| `AWS_SESSION_TOKEN` | Copiado no Passo 1 (string longa) |
| `AWS_ACCOUNT_ID` | No console AWS → canto superior direito (formato `123456789012`) |

> [!NOTE]
> **Aviso sobre GitOps:** O workflow foi atualizado para utilizar o token nativo do GitHub (`GITHUB_TOKEN`) com permissão de escrita (`contents: write`). Não é necessário criar nem configurar a variável `GITOPS_PAT` nos Secrets!

> [!IMPORTANT]
> Toda vez que o Lab reiniciar e as credenciais expirarem, você precisará atualizar apenas os 3 secrets `AWS_*` no GitHub (Passo 3).

---

### Passo 4 — Provisionar a infraestrutura com Terraform

#### Opção A: Pelo GitHub Actions (recomendado para o vídeo)
1. Vá na aba **Actions** do repositório
2. Selecione o workflow **Terraform Infrastructure IaC**
3. Clique em **Run workflow**
4. Escolha a ação: **`plan`** primeiro (para verificar o que será criado)
5. AWS Academy: **`true`**
6. Clique em **Run workflow** e aguarde o log
7. Se o plan estiver correto, repita com ação **`apply`** (leva ~15 minutos)

#### Opção B: Pelo Terminal Local (Windows PowerShell)
```powershell
# Configure as credenciais como variáveis de ambiente
$env:AWS_ACCESS_KEY_ID = "ASIA..."
$env:AWS_SECRET_ACCESS_KEY = "..."
$env:AWS_SESSION_TOKEN = "..."

# Entre na pasta terraform e rode
cd terraform
.\deploy-infra.ps1 -Action "plan" -UseAcademy "true"
.\deploy-infra.ps1 -Action "apply" -UseAcademy "true"
```

#### Opção B: Pelo Terminal Local (Linux/macOS/Git Bash)
```bash
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

cd terraform
./deploy-infra.sh plan true
./deploy-infra.sh apply true
```

---

### Passo 5 — Conectar o kubectl ao cluster EKS criado

Após o `terraform apply` terminar, execute:
```bash
aws eks update-kubeconfig --region us-east-1 --name dev-cluster
```

Verifique se os nós estão prontos:
```bash
kubectl get nodes
# Espere todos os nós com STATUS: Ready
```

---

### Passo 6 — Instalar o ArgoCD no cluster EKS

```bash
# Criar namespace
kubectl create namespace argocd

# Instalar o ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar todos os pods ficarem prontos (pode levar 2-3 minutos)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Expor via LoadBalancer (AWS cria um ALB automaticamente)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Aguardar o endereço externo aparecer (pode levar 2-5 minutos)
kubectl get svc argocd-server -n argocd --watch
```

Após o EXTERNAL-IP aparecer, anote o endereço (usado para acessar a interface do ArgoCD no browser).

Obtenha a senha inicial do admin:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
```

---

### Passo 7 — Atualizar o ConfigMap com os endpoints reais do Terraform

Após o `terraform apply`, verifique os outputs para copiar os endereços reais:
```bash
cd terraform
terraform output
```

Você verá algo como:
```
rds_auth_endpoint       = "dev-auth-db.abc123.us-east-1.rds.amazonaws.com:5432"
rds_flags_endpoint      = "dev-flags-db.abc123.us-east-1.rds.amazonaws.com:5432"
rds_targeting_endpoint  = "dev-targeting-db.abc123.us-east-1.rds.amazonaws.com:5432"
redis_primary_endpoint  = "dev-redis.abc123.0001.use1.cache.amazonaws.com"
sqs_queue_url           = "https://sqs.us-east-1.amazonaws.com/123456789012/ToggleMasterEvents"
```

Edite o arquivo `k8s/shared-resources.yaml` substituindo os valores placeholder:
```yaml
data:
  AUTH_DB_HOST: "dev-auth-db.abc123.us-east-1.rds.amazonaws.com"   # ← sem a porta :5432
  FLAGS_DB_HOST: "dev-flags-db.abc123.us-east-1.rds.amazonaws.com" # ← sem a porta :5432
  TARGETING_DB_HOST: "dev-targeting-db.abc123.us-east-1.rds.amazonaws.com"
  REDIS_HOST: "dev-redis.abc123.0001.use1.cache.amazonaws.com"
  AWS_SQS_URL: "https://sqs.us-east-1.amazonaws.com/123456789012/ToggleMasterEvents"
```

Aplique o ConfigMap no cluster:
```bash
kubectl apply -f k8s/shared-resources.yaml
```

---

### Passo 8 — Aplicar os manifestos do ArgoCD no cluster

```bash
# Criar namespace dos serviços
kubectl create namespace togglemaster

# Aplicar todos os ArgoCD Applications de uma vez
kubectl apply -f argocd/
```

O ArgoCD começará a sincronizar automaticamente todos os serviços. Acesse a interface no browser pelo endereço do LoadBalancer obtido no Passo 6.

---

### Passo 9 — Verificar o estado no ArgoCD

Na interface do ArgoCD (browser):
- Login: `admin` / senha obtida no Passo 6
- Verifique que os 5 serviços aparecem como **Healthy** + **Synced**

Se algum aparecer como **OutOfSync** ou **Degraded**, verifique os logs:
```bash
kubectl logs -n togglemaster deployment/<nome-do-servico>
kubectl describe pod -n togglemaster -l app=<nome-do-servico>
```

---

### Passo 10 — Testar o fluxo completo de CI/CD + GitOps (para o vídeo)

#### Cena "Pipeline falhando" (vulnerabilidade intencional):
1. Edite o arquivo `requirements.txt` de qualquer serviço Python e adicione uma dependência vulnerável:
   ```
   # Versão antiga do Django com vulnerabilidades críticas conhecidas
   Django==3.0.0
   ```
2. Faça commit e push — a pipeline vai **falhar** no step do Trivy com `exit-code: 1` ✅

#### Cena "Pipeline passando" (corrigindo):
1. Remova a dependência vulnerável adicionada
2. Faça commit e push — a pipeline passará por todos os gates de segurança ✅
3. Ao final, o ArgoCD detectará o novo deployment e sincronizará automaticamente ✅

---

### Passo 11 — Limpeza dos recursos ao terminar

Para evitar consumir todos os créditos do Learner Lab:

```powershell
# Windows
.\deploy-infra.ps1 -Action "destroy" -UseAcademy "true"
```
```bash
# Linux/macOS
./deploy-infra.sh destroy true
```

Ou pelo GitHub Actions: selecione o workflow **Terraform Infrastructure IaC** → ação **`destroy`**.

> [!CAUTION]
> **Não esqueça de destruir os recursos ao terminar!** O ElastiCache e o EKS são os recursos mais caros. Um cluster EKS ativo pode consumir os créditos rapidamente.
