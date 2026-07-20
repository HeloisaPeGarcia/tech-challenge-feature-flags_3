# ToggleMaster - Feature Flags Tech Challenge

Este repositório contém a implementação completa do **Tech Challenge (Fase 3)** do ToggleMaster. O projeto engloba 5 microsserviços integrados a uma infraestrutura automatizada na nuvem via **Terraform (IaC)**, esteiras seguras de **DevSecOps (CI/CD)** e sincronização via **GitOps (ArgoCD)**.

---

## 🏗️ Arquitetura do Projeto

O projeto é composto por 5 microsserviços integrados:
1.  **`auth-service`** (Go): Serviço de autenticação e geração de tokens.
2.  **`flag-service`** (Python): Gerenciamento do ciclo de vida das flags de recursos.
3.  **`targeting-service`** (Python): Regras de segmentação de usuários.
4.  **`evaluation-service`** (Go): Avaliação em tempo real se uma flag está ativa para um determinado usuário. Consome cache do Redis e envia eventos para o SQS.
5.  **`analytics-service`** (Python): Consome eventos da fila SQS e persiste métricas analíticas no DynamoDB.

---

## 🛠️ Recursos de Infraestrutura (Terraform)

Toda a infraestrutura necessária para suportar a aplicação na AWS foi automatizada utilizando Terraform na pasta [`terraform/`](./terraform/). Os recursos provisionados são:

*   **Rede (Networking):** VPC isolada com 2 subnets públicas, 2 subnets privadas, Internet Gateway e NAT Gateway.
*   **Kubernetes (EKS):** Cluster Kubernetes gerenciado com Node Groups escaláveis (1 a 3 instâncias `t3.medium`).
*   **Bancos de Dados:**
    *   3 Instâncias RDS PostgreSQL (para `auth`, `flags` e `targeting`).
    *   1 Cluster ElastiCache Redis (para cache de flags do `evaluation`).
    *   1 Tabela DynamoDB (`ToggleMasterAnalytics` para telemetria do `analytics`).
*   **Mensageria:** 1 Fila SQS (`ToggleMasterEvents`).
*   **Repositórios de Imagens:** 5 Repositórios privados no Amazon ECR.
*   **Estado Remoto:** Configuração de S3 Bucket para armazenamento centralizado e seguro do `terraform.tfstate`.

> [!IMPORTANT]
> **Compatibilidade AWS Academy:** A infraestrutura possui suporte nativo ao ambiente educacional. O Terraform detecta e utiliza a `LabRole` preexistente automaticamente quando a flag `use_aws_academy` estiver ativada, evitando erros de permissão de IAM.

---

## 🛡️ Pipeline DevSecOps & CI/CD (GitHub Actions)

O arquivo de pipeline principal [`.github/workflows/main.yml`](./.github/workflows/main.yml) roda automaticamente a cada Push ou Pull Request na branch `main` e cobre os seguintes estágios de segurança:

1.  **Build & Unit Test:** Valida compilação e sintaxe do código por linguagem (Go e Python).
2.  **Linter/Static Analysis:** Executa `go vet` para Go e `flake8` para Python.
3.  **Security Scan (SAST & SCA):**
    *   **SCA:** `Trivy fs` analisa vulnerabilidades conhecidas nas dependências de bibliotecas.
    *   **SAST:** `gosec` (Go) e `bandit` (Python) escaneiam o código-fonte em busca de falhas de segurança e segredos expostos.
    *   **Regra de Bloqueio:** O pipeline falha imediatamente se qualquer vulnerabilidade com severidade **CRÍTICA** for encontrada.
4.  **Docker Build & Scan:** Constrói a imagem Docker, roda escaneamento de segurança na imagem gerada com `Trivy image` e realiza o push para o AWS ECR com a tag do commit hash correspondente.
5.  **Atualização GitOps Automática:** Atualiza a tag da nova imagem diretamente no manifesto correspondente dentro da pasta [`k8s/`](./k8s/) e envia um commit de volta ao repositório sinalizado com `[skip ci]` para evitar loops.

---

## 🎛️ Como Implantar e Validar o Projeto

### Opção A: Executando o Terraform pelo Console Local

Para facilitar a criação da infraestrutura na nuvem localmente, criamos scripts automatizados dentro do diretório [`terraform/`](./terraform/):

*   **No Windows (PowerShell):**
    ```powershell
    cd terraform
    
    # Planejar a infraestrutura (Visualizar o que será criado)
    .\deploy-infra.ps1 -Action "plan" -UseAcademy "true"

    # Criar todos os recursos na AWS
    .\deploy-infra.ps1 -Action "apply" -UseAcademy "true"

    # Destruir a infraestrutura após validação para evitar custos
    .\deploy-infra.ps1 -Action "destroy" -UseAcademy "true"
    ```
*   **No Linux / macOS / Git Bash:**
    ```bash
    cd terraform
    chmod +x deploy-infra.sh

    # Planejar
    ./deploy-infra.sh plan true

    # Aplicar
    ./deploy-infra.sh apply true

    # Destruir
    ./deploy-infra.sh destroy true
    ```

---

### Opção B: Executando Manualmente pelo GitHub Actions (Sem Gatilhos)

Criamos o workflow manual [`terraform-infra.yml`](./.github/workflows/terraform-infra.yml) para que você gerencie a nuvem diretamente da interface do GitHub:
1.  Acesse a aba **Actions** no seu repositório.
2.  Selecione a esteira **Terraform Infrastructure IaC**.
3.  Clique em **Run workflow** (no menu lateral direito).
4.  Configure as entradas (Ação: `plan`/`apply`/`destroy` | Usar AWS Academy: `true`/`false`).
5.  Clique em **Run workflow** para iniciar o provisionamento na nuvem.

---

### Sincronização de Entrega Contínua (GitOps com ArgoCD)

1.  Os manifestos Kubernetes de cada serviço estão estruturados na pasta [`k8s/`](./k8s/).
2.  Configure o ArgoCD para apontar para este repositório Git, definindo o caminho de sincronização na pasta `k8s/`.
3.  Sempre que a pipeline de CI empacotar uma nova versão, o arquivo `deployment.yaml` correspondente será alterado com a nova tag de imagem do ECR. O ArgoCD detectará a modificação e aplicará a atualização de forma transparente no cluster.
