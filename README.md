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

3. docker-compose で起動
```bash
docker compose up -d
```

4. ブラウザで `http://127.0.0.1:3000` にアクセス

### シャットダウン
```bash
docker compose down
```

## 情報
- 連合できなくなっています。連合する場合は`.config/default.yml`の151行目をコメントアウトしてください。