# WordPress AWS Infrastructure with Terraform

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-623CE4?style=for-the-badge&logo=terraform&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)

Infraestrutura completa e escalável para WordPress na AWS utilizando Terraform, com foco em alta disponibilidade e custos otimizados.

## 🏗️ Arquitetura

```
Internet Gateway
       │
   ┌───▼───┐
   │  ALB  │ (Application Load Balancer)
   └───┬───┘
       │
   ┌───▼────────▼───┐
   │  Auto Scaling  │ (1-3 instances)
   │     Group      │
   └───┬────────┬───┘
       │        │
   ┌───▼───┐ ┌──▼───┐
   │ EC2-1 │ │ EC2-2│ (t3.micro)
   └───┬───┘ └──┬───┘
       │        │
   ┌───▼────────▼───┐
   │      EFS       │ (Shared Storage)
   └────────────────┘
           │
   ┌───────▼────────┐
   │   RDS MySQL    │ (Database)
   └────────────────┘
```

## 📋 Recursos Provisionados

### Networking
- **VPC**: 10.0.0.0/16
- **Public Subnets**: 2 AZs para ALB e EC2
- **Private Subnets**: 2 AZs para RDS e EFS
- **Internet Gateway**: Acesso à internet
- **Route Tables**: Roteamento configurado

### Compute
- **Application Load Balancer**: Distribuição de carga
- **Auto Scaling Group**: 1-3 instâncias t3.micro
- **Launch Template**: Amazon Linux 2023 + WordPress
- **Target Groups**: Health checks configurados

### Storage & Database
- **RDS MySQL 8.0**: db.t3.micro com backup automático
- **EFS**: Storage compartilhado com lifecycle policy
- **EBS**: Volumes otimizados gp3

### Security
- **Security Groups**: Regras de firewall específicas
- **IAM Roles**: Permissões mínimas necessárias
- **Systems Manager**: Acesso seguro às instâncias

## 💰 Custos Estimados

| Recurso | Tipo | Custo Mensal |
|---------|------|--------------|
| EC2 | t3.micro | ~$8.50 |
| RDS | db.t3.micro | ~$12.00 |
| EFS | 5GB + IA | ~$1.50 |
| ALB | Standard | ~$16.00 |
| Outros | VPC, etc | ~$3.00 |
| **Total** | | **~$41.00** |

## 🚀 Início Rápido

### Pré-requisitos

- **Terraform** >= 1.0
- **AWS CLI** configurado
- **PowerShell** (Windows) ou Bash (Linux/Mac)
- **Conta AWS** com permissões administrativas

### 1. Clonar o Repositório

```bash
git clone https://github.com/seu-usuario/wordpress-aws-terraform.git
cd wordpress-aws-terraform
```

### 2. Configurar Variáveis

Edite o arquivo `terraform.tfvars`:

```hcl
# Configurações essenciais
project_name = "seu-projeto-wordpress"
domain_name  = "seudominio.com.br"
db_password  = "SuaSenhaSegura123!"
owner        = "SeuNome"

# Configurações técnicas
aws_region   = "us-east-2"
environment  = "producao"
```

### 3. Inicializar e Aplicar

```powershell
# Windows (PowerShell)
.\deploy.ps1 init
.\deploy.ps1 validate
.\deploy.ps1 plan
.\deploy.ps1 apply

# Linux/Mac (Bash)
chmod +x deploy.sh
./deploy.sh init
./deploy.sh validate
./deploy.sh plan
./deploy.sh apply
```

### 4. Acessar WordPress

Após 15-20 minutos:

- **Site**: `http://seu-alb-dns.elb.amazonaws.com`
- **Admin**: `http://seu-alb-dns.elb.amazonaws.com/wp-admin/install.php`
- **Health Check**: `http://seu-alb-dns.elb.amazonaws.com/health`

## 🔧 Comandos Úteis

### Gerenciamento da Infraestrutura

```powershell
# Verificar status
.\deploy.ps1 status

# Criar backup
.\deploy.ps1 backup

# Destruir tudo (CUIDADO!)
.\deploy.ps1 destroy

# Limpeza de emergência
.\deploy.ps1 nuke
```

### Monitoramento

```powershell
# Status do Target Group
aws elbv2 describe-target-health --target-group-arn [ARN]

# Logs da instância
aws ec2 get-console-output --instance-id [ID]

# Métricas do Auto Scaling
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names [NAME]
```

## 📁 Estrutura do Projeto

```
wordpress-aws-terraform/
├── main.tf                 # Recursos principais
├── variables.tf            # Definições de variáveis
├── outputs.tf             # Outputs do Terraform
├── terraform.tfvars       # Configurações do projeto
├── user-data.sh           # Script de inicialização
├── deploy.ps1             # Script de automação (Windows)
├── deploy.sh              # Script de automação (Linux/Mac)
├── cleanup-aws.ps1        # Limpeza de recursos órfãos
├── README.md              # Este arquivo
├── .gitignore             # Arquivos ignorados pelo Git
└── backups/               # Backups automáticos
```

## 🛡️ Segurança

### Boas Práticas Implementadas

- ✅ **IAM Roles**: Permissões mínimas necessárias
- ✅ **Security Groups**: Regras restritivas
- ✅ **VPC Isolada**: Rede privada
- ✅ **RDS Privado**: Banco em subnet privada
- ✅ **EFS Encriptado**: Storage com encriptação
- ✅ **Backups Automáticos**: RDS com retenção de 7 dias

### Configurações de Segurança

```hcl
# Security Groups configurados para:
- ALB: Porta 80 (HTTP) aberta para internet
- EC2: Porta 80 apenas do ALB
- RDS: Porta 3306 apenas do EC2
- EFS: Porta 2049 apenas do EC2
```

## 🔄 Escalabilidade

### Auto Scaling Configurado

- **Min**: 1 instância
- **Max**: 3 instâncias
- **Desired**: 1 instância
- **Scale Up**: CPU > 80% por 10 minutos
- **Scale Down**: CPU < 25% por 10 minutos

### Load Balancer

- **Health Check**: `/health` endpoint
- **Healthy Threshold**: 3 checks consecutivos
- **Unhealthy Threshold**: 3 checks consecutivos
- **Timeout**: 10 segundos
- **Interval**: 30 segundos

## 📊 Monitoramento

### CloudWatch Alarms

- **High CPU**: CPU > 80% → Scale Up
- **Low CPU**: CPU < 25% → Scale Down
- **Target Health**: Monitoring do ALB

### Logs Disponíveis

- **User Data**: `/var/log/user-data.log`
- **Nginx**: `/var/log/nginx/`
- **PHP-FPM**: `/var/log/php-fpm/`
- **WordPress**: `/var/www/html/wp-content/debug.log`

## 🚧 Troubleshooting

### Problemas Comuns

#### Target Group Unhealthy
```bash
# Verificar health check
curl http://localhost/health

# Verificar nginx
systemctl status nginx

# Verificar logs
tail -f /var/log/user-data.log
```

#### Erro de Conexão com Banco
```bash
# Verificar conectividade RDS
mysql -h [RDS_ENDPOINT] -u wpuser -p

# Verificar security groups
aws ec2 describe-security-groups
```

#### WordPress não carrega
```bash
# Verificar permissões
ls -la /var/www/html/

# Verificar PHP-FPM
systemctl status php-fpm

# Verificar configuração
cat /var/www/html/wp-config.php
```

## 🔄 Atualizações

### Atualizar Infraestrutura

```powershell
# Aplicar mudanças
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Forçar nova instância
terraform taint aws_launch_template.main
terraform apply -var-file="terraform.tfvars"
```

### Atualizar WordPress

```bash
# Via WP-CLI (se instalado)
wp core update

# Via Admin Dashboard
# Acesse /wp-admin/ → Dashboard → Updates
```

## 🗑️ Limpeza

### Destruir Infraestrutura

```powershell
# Backup antes de destruir
.\deploy.ps1 backup

# Destruir recursos
.\deploy.ps1 destroy

# Limpeza completa (emergência)
.\deploy.ps1 nuke
```

### Verificar Recursos Órfãos

```powershell
# Verificar recursos não removidos
.\cleanup-aws.ps1 -DryRun

# Remover recursos órfãos
.\cleanup-aws.ps1 -Force
```

## 📚 Referências

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [WordPress Codex](https://codex.wordpress.org/)
- [Nginx Documentation](https://nginx.org/en/docs/)

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

## ✨ Autor

**Anderson Viposa**
- GitHub: [@seu-usuario](https://github.com/seu-usuario)
- LinkedIn: [Seu LinkedIn](https://linkedin.com/in/seu-linkedin)
- Email: seu.email@viposa.com.br

---

⭐ **Se este projeto foi útil, considere dar uma estrela!**