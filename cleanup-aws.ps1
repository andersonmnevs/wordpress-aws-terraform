# AWS Resource Cleanup Script - Para recursos órfãos do WordPress
param(
    [string]$ProjectName = "",
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "=== AWS WordPress Cleanup Tool ===" -ForegroundColor Red
Write-Host "⚠️ ATENÇÃO: Este script pode deletar recursos AWS permanentemente!" -ForegroundColor Yellow

function Write-CleanupLog {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        "Info" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Get-ProjectNameFromConfig {
    if ($ProjectName) { return $ProjectName }
    
    if (Test-Path "terraform.tfvars") {
        $content = Get-Content "terraform.tfvars"
        $projectLine = $content | Where-Object { $_ -match 'project_name\s*=' }
        if ($projectLine) {
            return ($projectLine -split '=')[1].Trim().Trim('"')
        }
    }
    
    Write-CleanupLog "❌ Nome do projeto não especificado e não encontrado em terraform.tfvars" "Error"
    Write-Host "Use: .\cleanup-aws.ps1 -ProjectName 'seu-projeto'" -ForegroundColor Yellow
    exit 1
}

function Test-AWSConnectivity {
    try {
        $identity = aws sts get-caller-identity | ConvertFrom-Json
        $region = aws configure get region
        Write-CleanupLog "✅ AWS conectado - Conta: $($identity.Account) | Região: $region" "Success"
        return $true
    } catch {
        Write-CleanupLog "❌ Erro de conectividade AWS. Verifique suas credenciais." "Error"
        return $false
    }
}

function Find-EC2Resources {
    param([string]$Project)
    
    Write-CleanupLog "🔍 Procurando instâncias EC2..." "Info"
    
    try {
        $instances = aws ec2 describe-instances --filters "Name=tag:Project,Values=$Project" "Name=instance-state-name,Values=running,stopped,stopping" --query "Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key=='Name']|[0].Value]" --output json | ConvertFrom-Json
        
        if ($instances -and $instances.Count -gt 0) {
            Write-CleanupLog "⚠️ Encontradas $($instances.Count) instância(s) EC2:" "Warning"
            foreach ($instance in $instances) {
                Write-Host "   • $($instance[0]) ($($instance[1])) - $($instance[2])" -ForegroundColor White
            }
            return $instances
        } else {
            Write-CleanupLog "✅ Nenhuma instância EC2 encontrada" "Success"
            return @()
        }
    } catch {
        Write-CleanupLog "❌ Erro ao buscar instâncias EC2: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Find-LoadBalancers {
    param([string]$Project)
    
    Write-CleanupLog "🔍 Procurando Load Balancers..." "Info"
    
    try {
        # ALBs/NLBs
        $albs = aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '$Project')].[LoadBalancerArn,LoadBalancerName,Type,State.Code]" --output json | ConvertFrom-Json
        
        if ($albs -and $albs.Count -gt 0) {
            Write-CleanupLog "⚠️ Encontrados $($albs.Count) Load Balancer(s):" "Warning"
            foreach ($alb in $albs) {
                Write-Host "   • $($alb[1]) ($($alb[2])) - Estado: $($alb[3])" -ForegroundColor White
            }
            return $albs
        } else {
            Write-CleanupLog "✅ Nenhum Load Balancer encontrado" "Success"
            return @()
        }
    } catch {
        Write-CleanupLog "❌ Erro ao buscar Load Balancers: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Find-RDSInstances {
    param([string]$Project)
    
    Write-CleanupLog "🔍 Procurando instâncias RDS..." "Info"
    
    try {
        $rdsInstances = aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, '$Project')].[DBInstanceIdentifier,DBInstanceStatus,Engine,DBInstanceClass]" --output json | ConvertFrom-Json
        
        if ($rdsInstances -and $rdsInstances.Count -gt 0) {
            Write-CleanupLog "⚠️ Encontradas $($rdsInstances.Count) instância(s) RDS:" "Warning"
            foreach ($rds in $rdsInstances) {
                Write-Host "   • $($rds[0]) ($($rds[2]) $($rds[3])) - Status: $($rds[1])" -ForegroundColor White
            }
            return $rdsInstances
        } else {
            Write-CleanupLog "✅ Nenhuma instância RDS encontrada" "Success"
            return @()
        }
    } catch {
        Write-CleanupLog "❌ Erro ao buscar instâncias RDS: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Find-EFSFileSystems {
    param([string]$Project)
    
    Write-CleanupLog "🔍 Procurando sistemas de arquivos EFS..." "Info"
    
    try {
        $efsFileSystems = aws efs describe-file-systems --query "FileSystems[?CreationToken=='$Project-efs'].[FileSystemId,CreationToken,LifeCycleState,SizeInBytes.Value]" --output json | ConvertFrom-Json
        
        if ($efsFileSystems -and $efsFileSystems.Count -gt 0) {
            Write-CleanupLog "⚠️ Encontrados $($efsFileSystems.Count) sistema(s) EFS:" "Warning"
            foreach ($efs in $efsFileSystems) {
                $sizeGB = [math]::Round($efs[3] / 1GB, 2)
                Write-Host "   • $($efs[0]) ($($efs[1])) - Estado: $($efs[2]) - Tamanho: ${sizeGB}GB" -ForegroundColor White
            }
            return $efsFileSystems
        } else {
            Write-CleanupLog "✅ Nenhum sistema EFS encontrado" "Success"
            return @()
        }
    } catch {
        Write-CleanupLog "❌ Erro ao buscar sistemas EFS: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Find-VPCResources {
    param([string]$Project)
    
    Write-CleanupLog "🔍 Procurando recursos VPC..." "Info"
    
    try {
        $vpcs = aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$Project" --query "Vpcs[].[VpcId,CidrBlock,State,Tags[?Key=='Name']|[0].Value]" --output json | ConvertFrom-Json
        
        if ($vpcs -and $vpcs.Count -gt 0) {
            Write-CleanupLog "⚠️ Encontradas $($vpcs.Count) VPC(s):" "Warning"
            foreach ($vpc in $vpcs) {
                Write-Host "   • $($vpc[0]) ($($vpc[1])) - $($vpc[3]) - Estado: $($vpc[2])" -ForegroundColor White
                
                # Buscar recursos dependentes na VPC
                Find-VPCDependentResources -VpcId $vpc[0]
            }
            return $vpcs
        } else {
            Write-CleanupLog "✅ Nenhuma VPC encontrada" "Success"
            return @()
        }
    } catch {
        Write-CleanupLog "❌ Erro ao buscar VPCs: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Find-VPCDependentResources {
    param([string]$VpcId)
    
    if ($Verbose) {
        Write-CleanupLog "   🔍 Verificando recursos dependentes da VPC $VpcId..." "Info"
        
        # Security Groups
        try {
            $securityGroups = aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VpcId" --query "SecurityGroups[?GroupName!='default'].[GroupId,GroupName]" --output json | ConvertFrom-Json
            if ($securityGroups -and $securityGroups.Count -gt 0) {
                Write-Host "     • Security Groups: $($securityGroups.Count)" -ForegroundColor Gray
            }
        } catch { }
        
        # Subnets
        try {
            $subnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VpcId" --query "Subnets[].[SubnetId,CidrBlock]" --output json | ConvertFrom-Json
            if ($subnets -and $subnets.Count -gt 0) {
                Write-Host "     • Subnets: $($subnets.Count)" -ForegroundColor Gray
            }
        } catch { }
        
        # Internet Gateways
        try {
            $igws = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VpcId" --query "InternetGateways[].[InternetGatewayId]" --output json | ConvertFrom-Json
            if ($igws -and $igws.Count -gt 0) {
                Write-Host "     • Internet Gateways: $($igws.Count)" -ForegroundColor Gray
            }
        } catch { }
    }
}

function Find-AutoScalingGroups {
    param([string]$Project)
    
    Write-CleanupLog "🔍 Procurando Auto Scaling Groups..." "Info"
    
    try {
        $asgs = aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName, '$Project')].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize]" --output json | ConvertFrom-Json
        
        if ($asgs -and $asgs.Count -gt 0) {
            Write-CleanupLog "⚠️ Encontrados $($asgs.Count) Auto Scaling Group(s):" "Warning"
            foreach ($asg in $asgs) {
                Write-Host "   • $($asg[0]) - Desired: $($asg[1]), Min: $($asg[2]), Max: $($asg[3])" -ForegroundColor White
            }
            return $asgs
        } else {
            Write-CleanupLog "✅ Nenhum Auto Scaling Group encontrado" "Success"
            return @()
        }
    } catch {
        Write-CleanupLog "❌ Erro ao buscar Auto Scaling Groups: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Find-LaunchTemplates {
    param([string]$Project)
    
    Write-CleanupLog "🔍 Procurando Launch Templates..." "Info"
    
    try {
        $templates = aws ec2 describe-launch-templates --query "LaunchTemplates[?contains(LaunchTemplateName, '$Project')].[LaunchTemplateId,LaunchTemplateName,DefaultVersionNumber]" --output json | ConvertFrom-Json
        
        if ($templates -and $templates.Count -gt 0) {
            Write-CleanupLog "⚠️ Encontrados $($templates.Count) Launch Template(s):" "Warning"
            foreach ($template in $templates) {
                Write-Host "   • $($template[1]) ($($template[0])) - Versão: $($template[2])" -ForegroundColor White
            }
            return $templates
        } else {
            Write-CleanupLog "✅ Nenhum Launch Template encontrado" "Success"
            return @()
        }
    } catch {
        Write-CleanupLog "❌ Erro ao buscar Launch Templates: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Remove-EC2Resources {
    param([array]$Instances)
    
    if ($Instances.Count -eq 0) { return }
    
    Write-CleanupLog "🗑️ Removendo instâncias EC2..." "Warning"
    
    foreach ($instance in $Instances) {
        $instanceId = $instance[0]
        $state = $instance[1]
        
        if ($DryRun) {
            Write-CleanupLog "   [DRY-RUN] Terminaria instância: $instanceId ($state)" "Info"
        } else {
            try {
                if ($state -ne "terminated") {
                    Write-CleanupLog "   Terminando instância: $instanceId..." "Warning"
                    aws ec2 terminate-instances --instance-ids $instanceId | Out-Null
                    Write-CleanupLog "   ✅ Instância $instanceId marcada para terminação" "Success"
                }
            } catch {
                Write-CleanupLog "   ❌ Erro ao terminar instância ${instanceId}: $($_.Exception.Message)" "Error"
            }
        }
    }
}

function Remove-LoadBalancers {
    param([array]$LoadBalancers)
    
    if ($LoadBalancers.Count -eq 0) { return }
    
    Write-CleanupLog "🗑️ Removendo Load Balancers..." "Warning"
    
    foreach ($lb in $LoadBalancers) {
        $lbArn = $lb[0]
        $lbName = $lb[1]
        
        if ($DryRun) {
            Write-CleanupLog "   [DRY-RUN] Deletaria Load Balancer: $lbName" "Info"
        } else {
            try {
                Write-CleanupLog "   Deletando Load Balancer: $lbName..." "Warning"
                aws elbv2 delete-load-balancer --load-balancer-arn $lbArn
                Write-CleanupLog "   ✅ Load Balancer $lbName deletado" "Success"
            } catch {
                Write-CleanupLog "   ❌ Erro ao deletar Load Balancer ${lbName}: $($_.Exception.Message)" "Error"
            }
        }
    }
}

function Remove-RDSInstances {
    param([array]$RDSInstances)
    
    if ($RDSInstances.Count -eq 0) { return }
    
    Write-CleanupLog "🗑️ Removendo instâncias RDS..." "Warning"
    
    foreach ($rds in $RDSInstances) {
        $dbId = $rds[0]
        $status = $rds[1]
        
        if ($DryRun) {
            Write-CleanupLog "   [DRY-RUN] Deletaria RDS: $dbId ($status)" "Info"
        } else {
            try {
                if ($status -ne "deleting") {
                    Write-CleanupLog "   Deletando RDS: $dbId..." "Warning"
                    aws rds delete-db-instance --db-instance-identifier $dbId --skip-final-snapshot --delete-automated-backups
                    Write-CleanupLog "   ✅ RDS $dbId marcado para deleção" "Success"
                }
            } catch {
                Write-CleanupLog "   ❌ Erro ao deletar RDS ${dbId}: $($_.Exception.Message)" "Error"
            }
        }
    }
}

function Remove-EFSFileSystems {
    param([array]$EFSFileSystems)
    
    if ($EFSFileSystems.Count -eq 0) { return }
    
    Write-CleanupLog "🗑️ Removendo sistemas EFS..." "Warning"
    
    foreach ($efs in $EFSFileSystems) {
        $efsId = $efs[0]
        $state = $efs[2]
        
        if ($DryRun) {
            Write-CleanupLog "   [DRY-RUN] Deletaria EFS: $efsId ($state)" "Info"
        } else {
            try {
                if ($state -ne "deleted" -and $state -ne "deleting") {
                    # Primeiro, remover mount targets
                    Write-CleanupLog "   Removendo mount targets do EFS: $efsId..." "Info"
                    $mountTargets = aws efs describe-mount-targets --file-system-id $efsId --query "MountTargets[].MountTargetId" --output json | ConvertFrom-Json
                    
                    foreach ($mountTarget in $mountTargets) {
                        aws efs delete-mount-target --mount-target-id $mountTarget
                    }
                    
                    # Aguardar mount targets serem removidos
                    Start-Sleep -Seconds 30
                    
                    Write-CleanupLog "   Deletando EFS: $efsId..." "Warning"
                    aws efs delete-file-system --file-system-id $efsId
                    Write-CleanupLog "   ✅ EFS $efsId deletado" "Success"
                }
            } catch {
                Write-CleanupLog "   ❌ Erro ao deletar EFS ${efsId}: $($_.Exception.Message)" "Error"
            }
        }
    }
}

function Remove-AutoScalingGroups {
    param([array]$ASGs)
    
    if ($ASGs.Count -eq 0) { return }
    
    Write-CleanupLog "🗑️ Removendo Auto Scaling Groups..." "Warning"
    
    foreach ($asg in $ASGs) {
        $asgName = $asg[0]
        
        if ($DryRun) {
            Write-CleanupLog "   [DRY-RUN] Deletaria ASG: $asgName" "Info"
        } else {
            try {
                # Primeiro, definir capacidade para 0
                Write-CleanupLog "   Definindo capacidade 0 para ASG: $asgName..." "Info"
                aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asgName --min-size 0 --desired-capacity 0 --max-size 0
                
                # Aguardar instâncias terminarem
                Start-Sleep -Seconds 60
                
                Write-CleanupLog "   Deletando ASG: $asgName..." "Warning"
                aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $asgName --force-delete
                Write-CleanupLog "   ✅ ASG $asgName deletado" "Success"
            } catch {
                Write-CleanupLog "   ❌ Erro ao deletar ASG ${asgName}: $($_.Exception.Message)" "Error"
            }
        }
    }
}

function Remove-LaunchTemplates {
    param([array]$Templates)
    
    if ($Templates.Count -eq 0) { return }
    
    Write-CleanupLog "🗑️ Removendo Launch Templates..." "Warning"
    
    foreach ($template in $Templates) {
        $templateId = $template[0]
        $templateName = $template[1]
        
        if ($DryRun) {
            Write-CleanupLog "   [DRY-RUN] Deletaria Launch Template: $templateName" "Info"
        } else {
            try {
                Write-CleanupLog "   Deletando Launch Template: $templateName..." "Warning"
                aws ec2 delete-launch-template --launch-template-id $templateId
                Write-CleanupLog "   ✅ Launch Template $templateName deletado" "Success"
            } catch {
                Write-CleanupLog "   ❌ Erro ao deletar Launch Template ${templateName}: $($_.Exception.Message)" "Error"
            }
        }
    }
}

function Show-CleanupSummary {
    param([hashtable]$Resources)
    
    Write-Host "`n📊 RESUMO DA LIMPEZA:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    
    $totalResources = 0
    foreach ($key in $Resources.Keys) {
        $count = $Resources[$key].Count
        $totalResources += $count
        if ($count -gt 0) {
            $status = if ($DryRun) { "[SIMULAÇÃO]" } else { "[REMOVIDO]" }
            Write-Host "$status $key`: $count" -ForegroundColor $(if ($DryRun) { "Yellow" } else { "Red" })
        }
    }
    
    if ($totalResources -eq 0) {
        Write-Host "✅ Nenhum recurso órfão encontrado!" -ForegroundColor Green
    } else {
        $action = if ($DryRun) { "seriam removidos" } else { "foram marcados para remoção" }
        Write-Host "`nTotal: $totalResources recursos $action" -ForegroundColor $(if ($DryRun) { "Yellow" } else { "Red" })
        
        if (-not $DryRun) {
            Write-Host "⏳ Aguarde alguns minutos para a remoção completa dos recursos" -ForegroundColor Yellow
        }
    }
}

# ============================================================================
# EXECUÇÃO PRINCIPAL
# ============================================================================

if (-not (Test-AWSConnectivity)) {
    exit 1
}

$project = Get-ProjectNameFromConfig

if ($DryRun) {
    Write-CleanupLog "🔍 MODO SIMULAÇÃO - Nenhum recurso será removido" "Info"
} else {
    Write-CleanupLog "⚠️ MODO DESTRUTIVO - Recursos serão PERMANENTEMENTE removidos!" "Warning"
    
    if (-not $Force) {
        Write-Host "`nRecursos do projeto '$project' serão DELETADOS PERMANENTEMENTE!" -ForegroundColor Red
        $confirm = Read-Host "Digite 'DELETAR' para confirmar"
        
        if ($confirm -ne "DELETAR") {
            Write-CleanupLog "❌ Operação cancelada" "Warning"
            exit 0
        }
    }
}

Write-CleanupLog "🔍 Iniciando varredura para projeto: $project" "Info"

# Buscar todos os recursos
$resources = @{
    "EC2 Instances" = Find-EC2Resources -Project $project
    "Load Balancers" = Find-LoadBalancers -Project $project
    "RDS Instances" = Find-RDSInstances -Project $project
    "EFS File Systems" = Find-EFSFileSystems -Project $project
    "Auto Scaling Groups" = Find-AutoScalingGroups -Project $project
    "Launch Templates" = Find-LaunchTemplates -Project $project
    "VPCs" = Find-VPCResources -Project $project
}

# Remover recursos (se não for dry-run)
if (-not $DryRun) {
    Write-CleanupLog "🗑️ Iniciando remoção de recursos..." "Warning"
    
    # Ordem específica para evitar dependências
    Remove-AutoScalingGroups -ASGs $resources["Auto Scaling Groups"]
    Start-Sleep -Seconds 30
    
    Remove-EC2Resources -Instances $resources["EC2 Instances"]
    Remove-LoadBalancers -LoadBalancers $resources["Load Balancers"]
    Remove-RDSInstances -RDSInstances $resources["RDS Instances"]
    Remove-EFSFileSystems -EFSFileSystems $resources["EFS File Systems"]
    Remove-LaunchTemplates -Templates $resources["Launch Templates"]
    
    # VPCs serão removidas por último pelo Terraform destroy
}

Show-CleanupSummary -Resources $resources

if ($DryRun) {
    Write-Host "`n💡 Para executar a limpeza real:" -ForegroundColor Cyan
    Write-Host "   .\cleanup-aws.ps1 -ProjectName '$project'" -ForegroundColor White
    Write-Host "   .\cleanup-aws.ps1 -ProjectName '$project' -Force  # Sem confirmação" -ForegroundColor Gray
}

Write-CleanupLog "✅ Varredura de limpeza concluída!" "Success"