FROM ubuntu:latest
# sshサーバー、その他インストール
RUN apt-get update && apt-get install -y vim sudo openssh-server
# このディレクトリがsshd起動に必要
RUN mkdir /var/run/sshd
# rootのパスワード設定
# RUN echo 'root:root' | chpasswd
# sshのrootでのアクセスを許可します。ただし、パスワードでのアクセスは無効
# RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# testユーザー追加
RUN useradd -m -s /bin/bash test && \
echo "test:test" | chpasswd && \
gpasswd -a test sudo

# sshのポートを22 => [番号] に変更します
# RUN sed -i 's/#Port 22/Port [番号]/' /etc/ssh/sshd_config
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]