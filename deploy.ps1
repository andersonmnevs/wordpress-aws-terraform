# WordPress AWS Deploy Script - Versao Final Corrigida
param(
    [string]$Action = "help",
    [switch]$Force,
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

Write-Host "=== WordPress AWS - Deploy Otimizado v2.1 ===" -ForegroundColor Green

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        "Debug" { "Gray" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
    
    if ($Debug) {
        "[$timestamp] [$Level] $Message" | Out-File -FilePath "deploy-debug.log" -Append
    }
}

function Test-Prerequisites {
    Write-Log "Verificando pre-requisitos..." "Info"
    
    # Verificar Terraform
    try {
        $terraformVersion = terraform version
        Write-Log "Terraform: $($terraformVersion.Split("`n")[0])" "Success"
    } catch {
        Write-Log "Terraform nao encontrado!" "Error"
        exit 1
    }
    
    # Verificar AWS CLI
    try {
        $awsIdentity = aws sts get-caller-identity | ConvertFrom-Json
        $awsRegion = aws configure get region
        Write-Log "AWS CLI: Conta $($awsIdentity.Account) | Regiao: $awsRegion" "Success"
    } catch {
        Write-Log "AWS CLI nao configurado!" "Error"
        exit 1
    }
    
    # Verificar arquivo terraform.tfvars
    if (!(Test-Path "terraform.tfvars")) {
        Write-Log "Arquivo terraform.tfvars nao encontrado!" "Error"
        exit 1
    }
    
    Write-Log "Todos os pre-requisitos OK!" "Success"
}

function Show-EstimatedCosts {
    Write-Host "`nEstimativa de Custos Mensais:" -ForegroundColor Yellow
    Write-Host "   • EC2 t3.micro (1x):     ~`$8.50" -ForegroundColor White
    Write-Host "   • RDS db.t3.micro:       ~`$12.00" -ForegroundColor White
    Write-Host "   • EFS (5GB estimado):    ~`$1.50" -ForegroundColor White
    Write-Host "   • ALB:                   ~`$16.00" -ForegroundColor White
    Write-Host "   • Outros (VPC, etc):     ~`$3.00" -ForegroundColor White
    Write-Host "   ────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   Total estimado:          ~`$41/mes" -ForegroundColor Cyan
    Write-Host "   (Pode variar conforme uso)" -ForegroundColor DarkGray
}

function Backup-TerraformState {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = "backups"
    
    if (!(Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir | Out-Null
    }
    
    if (Test-Path "terraform.tfstate") {
        Copy-Item "terraform.tfstate" "$backupDir/terraform.tfstate.$timestamp"
        Write-Log "State backup criado: $backupDir/terraform.tfstate.$timestamp" "Info"
    }
    
    if (Test-Path "terraform.tfvars") {
        Copy-Item "terraform.tfvars" "$backupDir/terraform.tfvars.$timestamp"
        Write-Log "Config backup criado: $backupDir/terraform.tfvars.$timestamp" "Info"
    }
}

function Get-TerraformState {
    try {
        $state = terraform show -json 2>$null | ConvertFrom-Json
        return $state
    } catch {
        return $null
    }
}

function Show-ResourceStatus {
    Write-Log "Verificando status dos recursos..." "Info"
    
    try {
        $wordpressUrl = terraform output -raw wordpress_url 2>$null
        $healthUrl = terraform output -raw health_check_url 2>$null
        
        if ($wordpressUrl) {
            Write-Log "Infraestrutura: Ativa" "Success"
            Write-Log "WordPress: $wordpressUrl" "Info"
            Write-Log "Health Check: $healthUrl" "Info"
            
            # Teste de conectividade
            try {
                $healthResponse = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 10
                Write-Log "Health Check: OK ($($healthResponse.StatusCode))" "Success"
            } catch {
                Write-Log "Health Check: Inicializando..." "Warning"
            }
            
            try {
                $wpResponse = Invoke-WebRequest -Uri $wordpressUrl -UseBasicParsing -TimeoutSec 10
                Write-Log "WordPress: Respondendo ($($wpResponse.StatusCode))" "Success"
            } catch {
                Write-Log "WordPress: Ainda inicializando..." "Warning"
            }
        } else {
            Write-Log "Infraestrutura nao encontrada" "Warning"
            Write-Log "Execute 'deploy.ps1 apply' para criar" "Info"
        }
    } catch {
        Write-Log "Erro ao verificar status" "Error"
    }
}

function Remove-LocalFiles {
    $filesToRemove = @(
        ".terraform*",
        "terraform.tfstate*",
        "deploy-info.txt",
        ".terraform.lock.hcl"
    )
    
    foreach ($pattern in $filesToRemove) {
        try {
            Get-ChildItem -Path $pattern -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
            Write-Log "Removido: $pattern" "Debug"
        } catch {
            Write-Log "Nao foi possivel remover: $pattern" "Debug"
        }
    }
}

function Invoke-CompleteDestroy {
    param([bool]$SkipConfirmation = $false)
    
    Write-Log "ATENCAO: Iniciando destruicao COMPLETA da infraestrutura..." "Warning"
    
    if (-not $SkipConfirmation -and -not $Force) {
        Write-Host "`nESTA ACAO IRA:" -ForegroundColor Red
        Write-Host "   • DELETAR toda a infraestrutura AWS" -ForegroundColor Red
        Write-Host "   • REMOVER todos os dados do WordPress" -ForegroundColor Red
        Write-Host "   • ELIMINAR banco de dados e backups" -ForegroundColor Red
        Write-Host "   • LIMPAR arquivos locais do Terraform" -ForegroundColor Red
        
        $confirm = Read-Host "`nDigite 'DELETAR TUDO' para confirmar a destruicao completa"
        
        if ($confirm -ne "DELETAR TUDO") {
            Write-Log "Destruicao cancelada" "Warning"
            return $false
        }
    }
    
    Write-Log "Criando backup antes da destruicao..." "Info"
    Backup-TerraformState
    
    Write-Log "Executando terraform destroy..." "Warning"
    $startTime = Get-Date
    
    try {
        terraform destroy -var-file="terraform.tfvars" -auto-approve
        
        if ($LASTEXITCODE -eq 0) {
            $endTime = Get-Date
            $duration = $endTime - $startTime
            Write-Log "Infraestrutura destruida com sucesso!" "Success"
            Write-Log "Tempo total: $($duration.Minutes) minutos e $($duration.Seconds) segundos" "Info"
            
            Write-Log "Limpando arquivos locais..." "Info"
            Remove-LocalFiles
            
            Write-Log "Limpeza completa finalizada!" "Success"
            return $true
        } else {
            Write-Log "Falha na destruicao da infraestrutura!" "Error"
            Write-Log "Verifique recursos orfaos manualmente no AWS Console" "Warning"
            return $false
        }
    } catch {
        Write-Log "Erro durante a destruicao: $($_.Exception.Message)" "Error"
        return $false
    }
}

# ============================================================================
# COMANDOS PRINCIPAIS
# ============================================================================

switch ($Action.ToLower()) {
    "init" {
        Write-Log "Inicializando Terraform..." "Info"
        Test-Prerequisites
        terraform init
        Write-Log "Terraform inicializado!" "Success"
    }
    
    "validate" {
        Write-Log "Validando configuracao..." "Info"
        Test-Prerequisites
        terraform validate
        Write-Log "Configuracao valida!" "Success"
    }
    
    "plan" {
        Write-Log "Planejando infraestrutura..." "Info"
        Test-Prerequisites
        Show-EstimatedCosts
        terraform plan -var-file="terraform.tfvars"
        Write-Log "Execute 'deploy.ps1 apply' para criar a infraestrutura" "Info"
    }
    
    "apply" {
        Write-Log "Criando infraestrutura..." "Info"
        Test-Prerequisites
        Show-EstimatedCosts
        
        if (-not $Force) {
            Write-Host "`nTempo estimado: 15-20 minutos" -ForegroundColor Yellow
            $confirm = Read-Host "`nConfirma a criacao da infraestrutura? (sim/nao)"
            
            if ($confirm.ToLower() -ne "sim") {
                Write-Log "Deploy cancelado" "Warning"
                return
            }
        }
        
        $startTime = Get-Date
        
        Write-Log "Aplicando configuracao..." "Info"
        terraform apply -var-file="terraform.tfvars" -auto-approve
        
        if ($LASTEXITCODE -eq 0) {
            $endTime = Get-Date
            $duration = $endTime - $startTime
            
            Write-Log "Infraestrutura criada com sucesso!" "Success"
            Write-Log "Tempo total: $($duration.Minutes) minutos e $($duration.Seconds) segundos" "Info"
            
            try {
                $wordpressUrl = terraform output -raw wordpress_url
                $healthUrl = terraform output -raw health_check_url
                
                Write-Host "`nInformacoes importantes:" -ForegroundColor Cyan
                Write-Host "WordPress URL: $wordpressUrl" -ForegroundColor White
                Write-Host "Health Check: $healthUrl" -ForegroundColor White
                Write-Host "Admin Setup: $wordpressUrl/wp-admin/install.php" -ForegroundColor White
                
                Write-Host "`nAguarde 5-10 minutos para o WordPress inicializar completamente" -ForegroundColor Yellow
                Write-Host "Monitore via: $healthUrl" -ForegroundColor Gray
                
                $deployInfoContent = "WordPress AWS - Deploy Info`r`n"
                $deployInfoContent += "============================`r`n"
                $deployInfoContent += "Data: $(Get-Date)`r`n"
                $deployInfoContent += "WordPress: $wordpressUrl`r`n"
                $deployInfoContent += "Health Check: $healthUrl`r`n"
                $deployInfoContent += "Admin Setup: $wordpressUrl/wp-admin/install.php`r`n"
                $deployInfoContent += "Custo estimado: ~`$41/mes`r`n`r`n"
                $deployInfoContent += "Proximos passos:`r`n"
                $deployInfoContent += "1. Aguardar inicializacao (5-10 min)`r`n"
                $deployInfoContent += "2. Acessar $healthUrl para verificar status`r`n"
                $deployInfoContent += "3. Configurar WordPress em $wordpressUrl/wp-admin/install.php`r`n`r`n"
                $deployInfoContent += "Para destruir tudo: .\deploy.ps1 nuke`r`n"
                
                $deployInfoContent | Out-File -FilePath "deploy-info.txt" -Encoding UTF8
                Write-Log "Informacoes salvas em: deploy-info.txt" "Info"
                
            } catch {
                Write-Log "Erro ao obter outputs (infraestrutura criada, mas outputs indisponiveis)" "Warning"
            }
        } else {
            Write-Log "Falha na criacao da infraestrutura!" "Error"
        }
    }
    
    "status" {
        Show-ResourceStatus
    }
    
    "destroy" {
        Invoke-CompleteDestroy -SkipConfirmation $false
    }
    
    "nuke" {
        Write-Log "MODO NUCLEAR: Destruicao completa forcada" "Warning"
        Invoke-CompleteDestroy -SkipConfirmation $true
    }
    
    "clean" {
        Write-Log "Limpando apenas arquivos locais..." "Info"
        Backup-TerraformState
        Remove-LocalFiles
        Write-Log "Arquivos locais limpos (backups mantidos)" "Success"
    }
    
    "backup" {
        Write-Log "Criando backup manual..." "Info"
        Backup-TerraformState
        Write-Log "Backup criado com sucesso!" "Success"
    }
    
    default {
        Write-Host "WordPress AWS - Comandos Disponiveis:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "init           - Inicializar Terraform" -ForegroundColor White
        Write-Host "validate       - Validar configuracao" -ForegroundColor White
        Write-Host "plan          - Planejar mudancas" -ForegroundColor White
        Write-Host "apply         - Criar infraestrutura" -ForegroundColor White
        Write-Host "status        - Ver status detalhado" -ForegroundColor White
        Write-Host "destroy       - Destruir infraestrutura" -ForegroundColor White
        Write-Host "nuke          - Destruicao completa (sem confirmacao)" -ForegroundColor Red
        Write-Host "clean         - Limpar apenas arquivos locais" -ForegroundColor White
        Write-Host "backup        - Criar backup manual" -ForegroundColor White
        Write-Host ""
        Write-Host "Flags:" -ForegroundColor Yellow
        Write-Host "  -Force    : Pular confirmacoes" -ForegroundColor Gray
        Write-Host "  -Debug    : Log detalhado" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Exemplos:" -ForegroundColor Yellow
        Write-Host "  .\deploy.ps1 apply" -ForegroundColor Gray
        Write-Host "  .\deploy.ps1 nuke -Force" -ForegroundColor Gray
        Write-Host "  .\deploy.ps1 status -Debug" -ForegroundColor Gray
        Write-Host ""
        Show-EstimatedCosts
    }
}