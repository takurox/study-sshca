# 証明書を使用したSSH認証

OpenSSHはUNIX系サーバーへのリモートログインの手段として使用されています。
OpenSSHの認証によく使われる認証方式としてはパスワード認証と公開鍵認証が知られていると思います。

今回はOpenSSHの認証方式の一つである証明書認証をハンズオン形式で触っていきます。
この方式はバージョン5.4からサポートされています。

※本ハンズオンではDockerを使用してサーバーを起動しています。  
Dockerが使用できない。または、自身でサーバーを構築する方は本手順を一部スキップしてください。

## 各認証方式と設定の違い

|認証方式|クライアント側のユーザー設定|リモートのユーザーの設定|サーバー側で必要なもの|認証局|
|:---:|:---:|:---:|:---:|:---:|
|パスワード認証|不要|不要|パスワード認証の許可|不要|
|公開鍵認証|鍵ペアの作成|authorized_keysの設定|公開鍵認証の許可|不要|
|証明書認証|鍵ペア作成、認証局に署名された公開鍵|不要|認証局の公開鍵設定|不要|

## 証明書認証のメリット
- authorized_keysの設定が不要でユーザーの鍵交換も容易  
- 証明書の執行により、ユーザーのログインを禁止する  
- 証明書の有効期限を設定することで、ユーザーの有効期限を設定する  

## 準備

### CA(認証局)側の鍵ペア作成
任意の場所で下記のコマンドを実行  
※今回はパスフレーズ未設定(Enterでスキップしています)
```
ssh-keygen -f ca.key
```
下記のファイルが作成される。  
ca.key: CAの秘密鍵  
ca.pub: CAの公開鍵

### ユーザーの鍵ペア作成
任意の場所で下記のコマンドを実行  
CAの鍵ペアは一つで良いが、ユーザーの鍵ペアはユーザーごとに必要です。  
※今回はパスフレーズ未設定(Enterでスキップしています)
```
ssh-keygen -f user.key
```
下記のファイルが作成される。  
user.key: ユーザーの秘密鍵  
user.pub: ユーザーの公開鍵

### 証明書の作成

CAの秘密鍵でユーザーの公開鍵へ署名し、証明書を発行させる。  
※プロジェクト内のdockerを使用する場合は「test」ユーザーを必ず指定してください。  
自身のサーバーを使用する場合は、そのユーザーを指定してください。
```
ssh-keygen -s <CA秘密鍵> -I <証明書の説明> -n <sshログインを許可するユーザ名(カンマ区切り)> -V <証明書の期限(+XXXdでXXX日 まで)> ユーザの公開鍵

# 実際に試したコマンド
ssh-keygen -s ca.key -I test-certificate -n test -V +3650d user.key.pub
```
下記のファイルが作成される。  
user.key-cert.pub

ちなみに証明書の情報は下記のコマンドで確認できる。
```
ssh-keygen -L -f 証明書ファイル

# 出力
ssh-keygen -L -f ./user.key-cert.pub
./user.key-cert.pub:
        Type: ssh-rsa-cert-v01@openssh.com user certificate
        Public key: RSA-CERT SHA256:Kg9CrF37Cx4Nj7lN8iYmvEm7KuXW59p/AX5bT9HLuAc
        Signing CA: RSA SHA256:oLDWH5RqOvOsixGYXvLZKgyMNe1uiU3mrYPN0DJUqQY (using rsa-sha2-512)
        Key ID: "test-certificate"
        Serial: 0
        Valid: from 2023-07-15T12:23:00 to 2033-07-12T12:24:05
        Principals:
                test
        Critical Options: (none)
        Extensions:
                permit-X11-forwarding
                permit-agent-forwarding
                permit-port-forwarding
                permit-pty
                permit-user-rc
```

※複数人が使用するサーバーでは、この作業を人数分行う。

### サーバー起動
※自身で用意したサーバーを使用する場合はこの手順をスキップ

プロジェクト直下で下記コマンド実行
```
docker image build -t sshca:v1 .
```

下記コマンドでイメージの確認
```
docker images
```

下記コマンドでコンテナを起動する。
```
docker run --name sshca-container -it -p 20022:22 sshca:v1
```

### CAの公開鍵をサーバーに配置
証明書認証でssh接続するために、CAの公開鍵をssh接続先サーバーに配置する必要があります。

`/etc/ssh/`にCAの公開鍵(ca.pub)を配置します。  
※docker利用者は下記コマンド
```
# コンテナID確認
docker ps
CONTAINER ID   IMAGE      COMMAND               CREATED          STATUS          PORTS                   NAMES
xxxxxxxxxxxx   sshca:v1   "/usr/sbin/sshd -D"   38 minutes ago   Up 38 minutes   0.0.0.0:20022->22/tcp   sshca-container

# コンテナにファイルコピー (CA公開鍵のパスやコンテナid部分は読み替えてください)
docker cp /path/to/ca.key.pub [conteiner-id]:/etc/ssh
```

コンテナに入る
```
docker container exec -it [container ID] bash
```

`/etc/ssh/sshd_config`に下記の記述を追加する。
```
TrustedUserCAKeys /etc/ssh/ca.key.pub
```

記述後、sshdを再起動しておきます。  
※docker利用者は下記コマンド
```
service ssh restart
```

※dockerが停止した場合はdocker startで立ち上げる。

### 証明書によるssh接続
証明書認証をするために手元にユーザーの秘密鍵と証明書が必要になります。  
秘密鍵と証明書を同じディレクトリに置いておけば、ssh実行時に秘密鍵を指定することで自動的に証明書も読み込んでくれます。  `~/.ssh/`配下に配置することを推奨します。

下記コマンドで接続
```
ssh -v -i user.key user@target
```

※Docker利用者はこちら
```
ssh -i /path/to/user.key -p 20022 test@localhost
```

### おまけ: docker コマンド
起動コンテナ確認
```
docker ps
```

停止コンテナ確認
```
docker ps -a
```

コンテナ起動
```
docker start [container ID]
```

ホストからコンテナにファイルをコピーする
```
docker cp hoge.txt conteiner-id:/tmp
```

コンテナに入る
```
docker container exec -it [container ID] bash
```

コンテナ停止
```
docker stop [container ID]
```

コンテナ削除
```
docker rm [container ID]
```

イメージ確認
```
docker images
```

イメージ削除
```
docker rmi　[imageId]
```

Build Cache削除
```
docker builder prune
```