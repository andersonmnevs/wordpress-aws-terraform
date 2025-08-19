#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== WordPress DEV Setup Started - $(date) ==="

# Verificar conectividade
echo "=== Testing connectivity ==="
curl -s --connect-timeout 10 http://www.google.com > /dev/null || {
    echo "ERROR: No internet connectivity"
    exit 1
}
echo "Internet connectivity OK"

# Atualizar sistema
echo "=== Updating system packages ==="
dnf update -y

# Instalar nginx e PHP
echo "=== Installing nginx and PHP ==="
dnf install -y nginx php php-fpm php-mysqlnd php-gd php-xml php-mbstring php-curl

# Configurar PHP-FPM
echo "=== Configuring PHP-FPM ==="
sed -i 's/user = apache/user = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/;listen.owner = nobody/listen.owner = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/;listen.group = nobody/listen.group = nginx/' /etc/php-fpm.d/www.conf

# Configuração nginx com PHP
echo "=== Configuring nginx with PHP ==="
cat > /etc/nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    root /var/www/html;
    index index.php index.html;

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_connect_timeout 60;
        fastcgi_send_timeout 120;
        fastcgi_read_timeout 120;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        access_log off;
    }
}
EOF

# Criar estrutura web básica
echo "=== Creating web structure ==="
mkdir -p /var/www/html

# Download WordPress
echo "=== Downloading WordPress ==="
cd /var/www/html
curl -L -o latest.tar.gz https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz --strip-components=1
rm latest.tar.gz

# Configuração WordPress para DESENVOLVIMENTO (sem URL fixa)
echo "=== Configuring WordPress for DEVELOPMENT ==="
cat > wp-config.php << 'WPEOF'
<?php
define('DB_NAME', '${db_name}');
define('DB_USER', '${db_user}');
define('DB_PASSWORD', '${db_password}');
define('DB_HOST', '${db_host}');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// CONFIGURAÇÃO PARA DESENVOLVIMENTO - URL DINÂMICA
// Remove URLs fixas para permitir acesso via ALB durante desenvolvimento
// define('WP_HOME', 'http://viposa.com.br');
// define('WP_SITEURL', 'http://viposa.com.br');

// WordPress Salt Keys
define('AUTH_KEY', '${auth_key}');
define('SECURE_AUTH_KEY', '${secure_auth_key}');
define('LOGGED_IN_KEY', '${logged_in_key}');
define('NONCE_KEY', '${nonce_key}');
define('AUTH_SALT', '${auth_salt}');
define('SECURE_AUTH_SALT', '${secure_auth_salt}');
define('LOGGED_IN_SALT', '${logged_in_salt}');
define('NONCE_SALT', '${nonce_salt}');

// WordPress Database Table prefix
$table_prefix = 'wp_';

// WordPress debugging mode
define('WP_DEBUG', false);
define('WP_MEMORY_LIMIT', '256M');
define('DISALLOW_FILE_EDIT', true);

// Permitir acesso via qualquer domínio durante desenvolvimento
define('WP_AUTO_UPDATE_CORE', false);

// WordPress absolute path
if (!defined('ABSPATH'))
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
WPEOF

# Configurar permissões
echo "=== Setting permissions ==="
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/wp-content

# Iniciar serviços
echo "=== Starting services ==="
systemctl enable nginx php-fpm
systemctl start php-fpm
systemctl start nginx

# Aguardar serviços
sleep 15

# Testes finais
echo "=== Final tests ==="
if systemctl is-active --quiet nginx && systemctl is-active --quiet php-fpm; then
    echo "✅ All services running"
    if curl -f http://localhost/health; then
        echo "✅ Health check OK"
    fi
    if curl -f http://localhost/ >/dev/null; then
        echo "✅ WordPress responding"
    fi
else
    echo "❌ Service startup failed"
    systemctl status nginx
    systemctl status php-fpm
fi

echo "=== WordPress DEV Setup finished - $(date) ==="
echo "🎉 WordPress ready for installation via ALB!"
echo "📝 Access /wp-admin/install.php to configure"