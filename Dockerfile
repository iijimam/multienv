#ARG IMAGE=containers.intersystems.com/intersystems/irishealth:2024.1
#ARG IMAGE=containers.intersystems.com/intersystems/iris:2024.1
ARG IMAGE=irepo.intersystems.com/intersystems/iris:2024.1
FROM $IMAGE

# ビルド中に実行したいスクリプトがあるファイルをコンテナにコピーしています
COPY iris.script .
COPY instancerename.sh .
COPY iris.key ${ISC_PACKAGE_INSTALLDIR}/mgr/

# IRISを開始し、IRISにログインし、iris.scriptに記載のコマンドを実行しています
RUN iris start IRIS \
    && iris session IRIS < iris.script \
    && iris stop IRIS quietly

#USER root
#RUN chmod +x instancerename.sh
#USER ${ISC_PACKAGE_MGRUSER}

#以下シンタックスエラーになってた。 "./instancerename.sh iris2"　と書くとうまくいく
#ENTRYPOINT ["./instancerename.sh iris1"]