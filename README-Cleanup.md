# WordPress AWS - Guia de Limpeza Completa

## Visão Geral

Este guia documenta os comandos avançados de limpeza para sua infraestrutura WordPress na AWS, incluindo remoção de recursos órfãos e limpeza completa.

## Comandos Disponíveis

### 🚀 Deploy Principal (deploy.ps1)

#### Comandos Básicos
```powershell
# Aplicar infraestrutura
.\deploy.ps1 apply

# Ver status detalhado
.\deploy.ps1 status

# Destruição padrão
.\deploy.ps1 destroy
```

#### Comandos de Limpeza Avançada
```powershell
# 💥 DESTRUIÇÃO NUCLEAR - Remove tudo sem confirmação
.\deploy.ps1 nuke

# 💥 DESTRUIÇÃO NUCLEAR com modo forçado
.\deploy.ps1 nuke -Force

# 🧹 Limpeza apenas local (mantém AWS)
.\deploy.ps1 clean

# 🔍 Verificar recursos órfãos
.\deploy.ps1 check-orphans

# 💾 Criar backup manual
.\deploy.ps1 backup
```

#### Flags Úteis
```powershell
# Executar com logs detalhados
.\deploy.ps1 status -Debug

# Pular todas as confirmações
.\deploy.ps1 apply -Force
```

### 🧹 Limpeza Avançada AWS (cleanup-aws.ps1)

#### Verificação de Recursos Órfãos
```powershell
# Simulação - mostra o que seria removido
.\cleanup-aws.ps1 -ProjectName "viposa-wordpress" -DryRun

# Verificação com detalhes verbosos
.\cleanup-aws.ps1 -ProjectName "viposa-wordpress" -DryRun -Verbose

# Usar projeto do terraform.tfvars automaticamente
.\cleanup-aws.ps1 -DryRun
```

#### Remoção Real de Recursos
```powershell
# Limpeza interativa (pede confirmação)
.\cleanup-aws.ps1 -ProjectName "viposa-wordpress"

# Limpeza automática sem confirmação
.\cleanup-aws.ps1 -ProjectName "viposa-wordpress" -Force

# Limpeza com logs detalhados
.\cleanup-aws.ps1 -ProjectName "viposa-wordpress" -Verbose
```

## Tipos de Recursos Verificados

### 🔍 Recursos Principais
- **EC2 Instances**: Instâncias em execução, paradas ou sendo paradas
- **Load Balancers**: ALBs e NLBs relacionados ao projeto
- **RDS Instances**: Bancos de dados MySQL/MariaDB
- **EFS File Systems**: Sistemas de arquivos compartilhados
- **Auto Scaling Groups**: Grupos de auto scaling
- **Launch Templates**: Templates de lançamento de instâncias

### 🔍 Recursos de Rede
- **VPCs**: Redes virtuais privadas
- **Security Groups**: Grupos de segurança (exceto default)
- **Subnets**: Sub-redes públicas e privadas
- **Internet Gateways**: Gateways de internet
- **Route Tables**: Tabelas de roteamento

## Cenários de Uso

### 🎯 Cenário 1: Limpeza Completa Rápida
```powershell
# Destrói toda a infraestrutura Terraform + verifica órfãos
.\deploy.ps1 nuke -Force

# Se ainda houver recursos órfãos
.\cleanup-aws.ps1 -Force
```

### 🎯 Cenário 2: Verificação Cautelosa
```powershell
# 1. Verificar o que seria removido
.\cleanup-aws.ps1 -DryRun -Verbose

# 2. Backup antes de destruir
.\deploy.ps1 backup

# 3. Destruição controlada
.\deploy.ps1 destroy

# 4. Limpeza de órfãos se necessário
.\cleanup-aws.ps1 -DryRun
.\cleanup-aws.ps1  # Se houver recursos órfãos
```

### 🎯 Cenário 3: Falha no Terraform Destroy
```powershell
# Se terraform destroy falhou parcialmente
.\cleanup-aws.ps1 -DryRun  # Ver o que sobrou
.\cleanup-aws.ps1          # Limpar recursos órfãos
.\deploy.ps1 clean         # Limpar arquivos locais
```

## Ordem de Remoção de Recursos

O script segue uma ordem específica para evitar problemas de dependência:

1. **Auto Scaling Groups** (define capacidade 0 primeiro)
2. **EC2 Instances** (terminação)
3. **Load Balancers** (remove dependências de rede)
4. **RDS Instances** (remove bancos de dados)
5. **EFS File Systems** (remove mount targets primeiro)
6. **Launch Templates** (remove templates)
7. **VPCs e recursos de rede** (removidos pelo Terraform)

## Backups Automáticos

O sistema cria backups automáticos antes de operações destrutivas:

```
backups/
├── terraform.tfstate.20250118-143022
├── terraform.tfvars.20250118-143022
└── terraform.tfstate.20250118-151205
```

### Restaurar de Backup
```powershell
# Listar backups disponíveis
Get-ChildItem backups/

# Restaurar state específico
Copy-Item "backups/terraform.tfstate.20250118-143022" "terraform.tfstate"

# Verificar estado restaurado
terraform show
```

## Logs e Debugging

### Arquivos de Log
- `deploy-debug.log`: Logs detalhados quando usar `-Debug`
- `deploy-info.txt`: Informações da última implantação bem-sucedida

### Debugging Comum
```powershell
# Ver logs em tempo real durante deploy
.\deploy.ps1 apply -Debug

# Verificar status detalhado
.\deploy.ps1 status -Debug

# Ver recursos órfãos com detalhes
.\cleanup-aws.ps1 -DryRun -Verbose
```

## Estimativas de Custo

### Custos Durante Limpeza
- **Tempo**: 5-15 minutos para limpeza completa
- **Custo**: $0 (apenas tempo computacional para remoção)
- **Dados**: ⚠️ **PERDA PERMANENTE** de dados do WordPress e banco

### Prevenção de Custos Órfãos
```powershell
# Verificação regular de recursos órfãos
.\cleanup-aws.ps1 -DryRun

# Limpeza preventiva
.\deploy.ps1 check-orphans
```

## ⚠️ Avisos Importantes

### 🔥 Comandos Destrutivos
- `nuke`: Remove TUDO sem confirmação
- `cleanup-aws.ps1 -Force`: Remove recursos órfãos sem confirmação
- Estas operações são **IRREVERSÍVEIS**

### 💾 Dados Perdidos
- **WordPress**: Todas as postagens, páginas, mídia
- **Banco de dados**: Usuários, configurações, conteúdo
- **EFS**: Temas, plugins, uploads customizados

### 🛡️ Práticas Seguras
1. **SEMPRE** executar `-DryRun` primeiro
2. **SEMPRE** fazer backup antes de destruir
3. **VERIFICAR** o projeto correto antes de executar
4. **CONFIRMAR** URLs e recursos no AWS Console

## Solução de Problemas

### Problema: "Terraform destroy travou"
```powershell
# Solução: Limpeza manual
.\cleanup-aws.ps1 -DryRun  # Ver recursos restantes
.\cleanup-aws.ps1          # Limpar manualmente
```

### Problema: "Recursos órfãos custando dinheiro"
```powershell
# Solução: Verificação regular
.\cleanup-aws.ps1 -DryRun -Verbose
.\cleanup-aws.ps1 -Force  # Se confirmado
```

### Problema: "Erro de permissão AWS"
```powershell
# Verificar credenciais
aws sts get-caller-identity
aws configure list

# Verificar região
aws configure get region
```

## Scripts de Automação

### Limpeza Completa Automatizada
```powershell
# Criar script combo
@"
# Limpeza completa automatizada
.\deploy.ps1 backup
.\deploy.ps1 nuke -Force
.\cleanup-aws.ps1 -Force
Write-Host "Limpeza completa finalizada!" -ForegroundColor Green
"@ | Out-File -FilePath "limpeza-completa.ps1"

# Executar
.\limpeza-completa.ps1
```

### Verificação Programada
```powershell
# Verificação semanal de recursos órfãos
$script = @"
# Verificação automática de recursos órfãos
Write-Host "=== Verificação de Recursos Órfãos - $(Get-Date) ===" -ForegroundColor Cyan
.\cleanup-aws.ps1 -DryRun
"@

$script | Out-File -FilePath "verificacao-semanal.ps1"
```

---

## ✅ Checklist Final

Antes de executar limpeza completa:

- [ ] ✅ Backup de dados importantes
- [ ] ✅ Confirmação do projeto correto
- [ ] ✅ Verificação com `-DryRun` primeiro
- [ ] ✅ Confirmação de que não há dados críticos
- [ ] ✅ Acesso ao AWS Console para verificação manual
- [ ] ✅ Terraform e AWS CLI funcionando
- [ ] ✅ Permissões AWS adequadas

**🎯 Resultado esperado**: Infraestrutura AWS completamente limpa, custos zerados, sem recursos órfãos.