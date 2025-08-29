#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== WordPress EFS Diagnostics - $(date) ==="

# Instalar pacotes
dnf update -y
dnf install -y nginx php php-fpm php-mysqlnd php-gd php-xml php-mbstring php-curl amazon-efs-utils telnet

# Configurar serviços básicos
sed -i 's/user = apache/user = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/' /etc/php-fpm.d/www.conf

# Nginx config básico
cat > /etc/nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    root /var/www/html;
    index index.php index.html;
    location /health { return 200 "healthy\n"; add_header Content-Type text/plain; }
    location / { try_files $uri $uri/ /index.php?$args; }
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# WordPress básico
mkdir -p /var/www/html
cd /var/www/html
curl -L -o latest.tar.gz https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz --strip-components=1
rm latest.tar.gz

# DIAGNÓSTICO COMPLETO EFS
echo "=== INICIANDO DIAGNÓSTICO EFS ==="

# 1. Testar resolução DNS
echo "1. Testando resolução DNS do EFS..."
nslookup fs-02c93541a5c6253d5.efs.us-east-2.amazonaws.com
dig fs-02c93541a5c6253d5.efs.us-east-2.amazonaws.com

# 2. Testar conectividade de rede
echo "2. Testando conectividade TCP porta 2049..."
timeout 10 telnet fs-02c93541a5c6253d5.efs.us-east-2.amazonaws.com 2049

# 3. Verificar mount targets
echo "3. Informações da instância:"
curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone
curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(curl -s http://169.254.169.254/latest/meta-data/mac)/subnet-id

# 4. Tentar montagem de teste
echo "4. Testando montagem EFS..."
mkdir -p /tmp/efs-test
for i in {1..5}; do
    echo "Tentativa $i de montagem..."
    if timeout 30 mount -t efs fs-02c93541a5c6253d5.efs.us-east-2.amazonaws.com:/ /tmp/efs-test; then
        echo "SUCCESS: EFS montado na tentativa $i"
        ls -la /tmp/efs-test/
        umount /tmp/efs-test
        EFS_WORKING=1
        break
    else
        echo "FAILED: Tentativa $i falhou"
        dmesg | tail -5
    fi
    sleep 10
done

# Aplicar correção baseada no diagnóstico
if [ "$EFS_WORKING" = "1" ]; then
    echo "=== EFS FUNCIONANDO - APLICANDO CONFIGURAÇÃO ==="
    rm -rf /var/www/html/wp-content
    mkdir -p /var/www/html/wp-content
    
    # Aguardar e montar EFS com verificação
    sleep 10
    if mount -t efs fs-02c93541a5c6253d5.efs.us-east-2.amazonaws.com:/ /var/www/html/wp-content; then
        echo "EFS mounted as wp-content"
        mkdir -p /var/www/html/wp-content/{themes,plugins,uploads}
        echo "fs-02c93541a5c6253d5.efs.us-east-2.amazonaws.com:/ /var/www/html/wp-content nfs4 defaults,_netdev" >> /etc/fstab
        
        # Verificar montagem
        if mountpoint -q /var/www/html/wp-content; then
            echo "SUCCESS: wp-content is on EFS"
        else
            echo "ERROR: wp-content mount failed"
        fi
    else
        echo "ERROR: EFS mount failed, creating local wp-content"
        mkdir -p /var/www/html/wp-content/{themes,plugins,uploads}
        chmod -R 777 /var/www/html/wp-content/uploads
    fi
    echo "EFS CONFIGURADO COM SUCESSO"
else
    echo "=== EFS COM PROBLEMA - USANDO DISCO LOCAL ==="
    mkdir -p /var/www/html/wp-content/{themes,plugins,uploads}
    chmod -R 777 /var/www/html/wp-content/uploads
    echo "USANDO DISCO LOCAL TEMPORARIAMENTE"
fi

# WordPress config
cat > wp-config.php << 'EOF'
<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'wpuser');
define('DB_PASSWORD', 'P4ssW0rd-987Strong!');
define('DB_HOST', 'viposa-wordpress-database.cvxbvg4mkdj5.us-east-2.rds.amazonaws.com');
define('DB_CHARSET', 'utf8mb4');
$table_prefix = 'wp_';
define('WP_DEBUG', false);
if (!defined('ABSPATH')) define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOF

# Permissões
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html

# Iniciar serviços
systemctl enable nginx php-fpm
systemctl start php-fpm
systemctl start nginx

echo "=== Setup concluído - $(date) ==="