#!/bin/bash

# SSL自動セットアップスクリプト
set -e

# 環境変数の確認
if [ -z "$DOMAIN" ]; then
    echo "エラー: DOMAIN環境変数が設定されていません"
    echo "使用例: DOMAIN=your-subdomain.example.com EMAIL=you@example.com ./setup-ssl.sh"
    exit 1
fi

if [ -z "$EMAIL" ]; then
    echo "エラー: EMAIL環境変数が設定されていません"
    echo "使用例: DOMAIN=your-subdomain.example.com EMAIL=you@example.com ./setup-ssl.sh"
    exit 1
fi

echo "=== SSL自動セットアップ開始 ==="
echo "ドメイン: $DOMAIN"
echo "メールアドレス: $EMAIL"

# 必要なディレクトリの作成
echo "必要なディレクトリを作成中..."
mkdir -p nginx/conf.d
mkdir -p certbot/www
mkdir -p certbot/conf

# nginx設定ファイルの配置
echo "nginx設定ファイルを作成中..."
cat > nginx/conf.d/default.template << 'EOF'
server {
    listen 80;
    server_name ${DOMAIN};

    # Let's Encrypt challenge用
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # HTTPからHTTPSへリダイレクト
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    # SSL設定
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    # SSL強化設定
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # セキュリティヘッダー
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # クライアントの最大リクエストサイズ
    client_max_body_size 100M;

    # リバースプロキシ設定
    location / {
        proxy_pass http://web:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
        
        # WebSocket サポート
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # タイムアウト設定
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# .envファイルの作成
echo "環境変数ファイルを作成中..."
cat > .env << EOF
DOMAIN=$DOMAIN
EMAIL=$EMAIL
EOF

echo "=== 初期SSL証明書の取得 ==="
# 初期証明書取得用の一時的なnginx設定
cat > nginx/conf.d/default.template << 'EOF'
server {
    listen 80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://web:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Docker Composeサービスの起動（nginxとwebのみ）
echo "一時的にHTTPサーバーを起動中..."
docker compose up -d nginx web redis db

# 少し待機
sleep 10

# SSL証明書の取得
echo "SSL証明書を取得中..."
docker compose run --rm certbot

# SSL対応の完全なnginx設定に切り替え
echo "SSL対応設定に切り替え中..."
cat > nginx/conf.d/default.template << 'EOF'
server {
    listen 80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    client_max_body_size 100M;

    location / {
        proxy_pass http://web:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# nginxを再起動してSSL設定を適用
echo "nginxを再起動してSSL設定を適用中..."
docker compose restart nginx

echo "=== SSL証明書自動更新設定 ==="
# cronジョブの設定例を表示
cat << 'EOF'

SSL証明書の自動更新を設定するために、以下のcronジョブを追加してください：

# 毎日午前2時に証明書の更新をチェック
0 2 * * * cd /path/to/your/project && docker compose run --rm certbot && docker compose restart nginx

または、以下のコマンドでcronジョブを追加できます：
(crontab -l 2>/dev/null; echo "0 2 * * * cd $(pwd) && docker compose run --rm certbot && docker compose restart nginx") | crontab -

EOF

echo "=== セットアップ完了 ==="
echo "✅ SSL証明書が取得されました"
echo "✅ HTTPS (443) でリバースプロキシが稼働しています"
echo "✅ HTTP (80) からHTTPSへの自動リダイレクトが設定されました"
echo ""
echo "ブラウザで https://$DOMAIN にアクセスして確認してください"
echo ""
echo "注意: 証明書の自動更新を設定することを忘れずに！"
