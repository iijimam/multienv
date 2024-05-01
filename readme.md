# 複数インスタンステスト用Repo
Webサーバ：Apacheコンテナ（multienvwg）

IRISは3コンテナ

コンテナ名|インスタンス名
--|--
server1|iris1
server2|iris2
server3|iris3

## 開始手順

※コンテナ初期開始後、手動でインスタンス名変えます！

**コンテナビルド前にiris.keyをgit cloneしたディレクトリに配置します。（ファイル名もiris.key）**

コンテナビルド
```
docker compose build
```
コンテナ開始
```
docker-compose up -d
```
この時、IRISコンテナのインスタンス名は全部iris

テスト用にIRISのインスタンス名を変更するため、コンテナ開始後以下実行

```
./renameAll.sh
```
これでインスタンス名が変わる

注意：コンテナを新規で開始した場合必ずこのシェルを動かさないとApache上のWebGatewayコンテナから接続できない
