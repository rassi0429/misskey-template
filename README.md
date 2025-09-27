# misskey-template

簡単お手軽 Misskey テンプレート

docker があれば簡単に Misskey を立ち上げられます。

## 使い方
1. リポジトリをクローン
```bash
git clone https://github.com/rassi0429/misskey-template.git
```
2. ディレクトリに移動
```bash
cd misskey-template
```

3.0 SSLもとるとき
```bash
DOMAIN=YOUR_DOMAIN EMAIL=YOUR_EMAIL ./setup-ssl.sh
```

3. docker-compose で起動 (1分ぐらいかかるよ)
```bash
docker compose up -d
```

4. ブラウザでアクセス

### シャットダウン
```bash
docker compose down
```

sslの自動更新
```bash
(crontab -l 2>/dev/null; echo "0 2 * * * cd $(pwd) && docker-compose run --rm certbot && docker-compose restart nginx") | crontab -
```

