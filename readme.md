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
docker-compose ps
```
ps コマンドで全インスタンスが開始できてることを確認する。

この時、IRISコンテナのインスタンス名は全部iris。

テスト用にIRISのインスタンス名を変更するため、コンテナ開始後以下実行

```
./renameAll.sh
```
これでインスタンス名が変わる

注意：コンテナを新規で開始した場合必ずこのシェルを動かさないとApache上のWebGatewayコンテナから接続できない


## 1.ミラー設定

### ミラーセットとMACHINEAの設定
![](/assets/machineA.png)

コンテナ内ネットワークでは、IRIS1インスタンスのサーバは server1、IRIS2インスタンスのサーバは server2、IRIS3インスタンスのサーバはserver3　でpingが通ります。

この設定では、server3をアービターとしています。

### MACHINEBの設定

最初に、MACHINEAで作成したミラーセット：TESTMIRRORに接続します。

![](/assets/connect-TESTMIRROR.png)

MachineBの設定は以下の通り。
![](/assets/machineB.png)

## 2.ミラー対象のDB作成

MIRRORDATAという名称で、ネームスペース、データベースを作成
![](/assets/MIRRORDATA.png)

MACHINEA(IRIS1インスタンス)の環境でミラーセットのTESTMIRRORに接続します。
![](/assets/JOIN-TESTMIRROR.png)


## 3.MACHINEAのMIRRORDATAデータベースバックアップ

ExternalFreeze()またはオンラインバックアップでMIRRORDATAをバックアップします。

バックアップファイルは [/src1](/src1/) 以下に配置します。

1. server1コンテナにログイン
    ```
    docker exec -it server1 bash
    ```
2. %SYSネームスペースにログイン
    ```
    iris session iris1 -U %SYS
    ```
3. ExternalFreeze()実行（**ここから10分以内にExternalThaw()を実行すること！！**）
    ```
    write ##class(Backup.General).ExternalFreeze()
    ```
4. MIRRORDATAデータベースのIRIS.datを [/src1](/src1/)に退避
    ```
    cp /usr/irissys/mgr/mirrordata/IRIS.DAT /src1/IRIS.DAT
    ```
5. コピーが完了したら以下実行
    ```
    write ##class(Backup.General).ExternalThaw()
    ```

## 4.MACHINEBでMIRRORDATAデータベースリストア

server1で退避したMIRRORDATAのIRIS.DATをserver2にリストアする

1. src1/IRIS.DAT をローカルの src2/IRIS.DATにコピー

    ```
    sudo cp ./src1/IRIS.DAT ./src2
    ```

2. インスタンスIRIS2のMIRRORDATAデータベースをディスマウント

   http://localhost:8082/iris2/csp/sys/op/%25CSP.UI.Portal.OpDatabases.zen?$NAMESPACE=%25SYS

    MIRRORDATAを選択し「ディスマウント」ボタンクリック

3. server2コンテナにrootでログインし、IRIS.DATの所有者を変更する

    他コンテナからコピーしたIRIS.DATの所有者がirisowner以外になっている場合、所有者を変更したいためrootでログインします

    ```
    docker exec -u root -it server2 bash
    chown irisowner /src2/IRIS.DAT
    exit
    ```
4. /src2/IRIS.DATをIRIS2インスタンスのMIRRORDATAデータベースディレクトリにコピー

    通常ユーザでコンテナにログインし、IRIS.DATをコピー
    ```
    docker exec -it server2 bash
    cp /src2/IRIS.DAT /usr/irissys/mgr/mirrordata/IRIS.DAT
    ```

5. IRIS2インスタンスの管理ポータルでMIRRORDATAデータベースのマウント実行

    http://localhost:8082/iris2/csp/sys/op/%25CSP.UI.Portal.OpDatabases.zen?$NAMESPACE=%25SYS

    MIRRORDATAを選択し「マウント」ボタンクリック

6. IRIS1、IRIS2インスタンスのミラーモニタ画面を開く

    管理ポータル > システムオペレーション > ミラーモニタ

    IRIS2インスタンス（server2でミラー設定ではMACHINEBの設定をしたインスタンス）のミラーモニタでは、「ミラーされたデータベース」行に「有効化」のリンクが表示されます。

    ![](/assets/MachineB-PreEnabled.png)

    ここで「有効化」をクリックします。次に「キャッチアップ」が表示されます。
    
    ![](/assets/MachineB-PreCatchup.png)

    「キャッチアップ」を実行します。これで設定は完了です。

    ![](/assets/MachineB-Catchup.png)

## 5. テスト

IRIS1インスタンスのMIRRORDATAネームスペースで1秒毎に1件グローバルの添え字を追加するスクリプトを記述します。

```
docker exec -it server1 bash
iris session iris1 -U MIRRORDATA
set i=1
for { set ^Glo(i)="",i=i+1 write i,"-" hang 1}
```

IRIS2インスタンスでは、IRIS1インスタンスのグローバルが引き継げているか確認します。
```
docker exec -it server2 bash
iris session iris2 -U MIRRORDATA
for { write $order(^Glo(""),-1),"-" hang 1}
```

## 6.フェイルオーバーテスト

MACHINEAのIRISを停止するとMACHINEBがプライマリになることを確認します。

MACHINEA(server1コンテナのIRIS1インスタンス)を停止します。

```
docker exec -it server1 bash
iris stop iris1
```
MACHINEBではミラーモニタを参照します。

MACHINEBがプライマリになったところで、MACHINEAのIRISを開始します。

```
iris start iris1
```

MACHINEBがプライマリ、MACHINEAがバックアップになったことを確認します。

MACHINEAのMIRRORDATAデータベースがREADONLYに代わるため、MIRRORDATAネームスペースでSET文でグローバル変数の更新ができません。

```
MIRRORDATA>set ^A=1

SET ^A=1
^
<PROTECT> ^A,/usr/irissys/mgr/mirrordata/
MIRRORDATA>
```

## 7. ミラー設定解除

### 1. バックアップメンバ側から設定解除

バックアップメンバのミラー設定画面を開きます。（管理ポータル > システム管理 > 構成 > ミラー設定 > ミラーの編集）

「ミラーの構成を削除」ボタンをクリックします。
![](/assets/MIrrorConfigDelete.png)

ミラー属性を削除／ミラージャーナルファイルを削除　をはいに設定して削除します。
![](/assets/MIRRORDATA-ConfigDelete.png)

IRISを再起動して終了です。（実行例：IRIS1インスタンスの再起動）

```
iris restart iris1
```

### 2. プライマリで設定解除

バックアップメンバのミラー設定画面を開きます。（管理ポータル > システム管理 > 構成 > ミラー設定 > ミラーの編集）

ミラーの構成を削除ボタンをクリックします。JoinMirrorフラグをクリアする・・とあるので「JoinMirrorフラグをクリア」ボタンをクリックし、IRISを再起動します。
![](/assets/Clear-JoinMirrorFlg.png)

例はIRIS2の再起動
```
iris restart iris2
```

この後再度、管理ポータル > システム管理 > 構成 > ミラー設定 > ミラーの編集、を開き「ミラーの構成削除」ボタンをクリックします。

ミラー属性を削除／ミラージャーナルファイルを削除　をはいに設定して削除します。
![](/assets/MIRRORDATA-ConfigDelete.png)

IRISを再起動して終了です。
```
iris restart iris1
```
