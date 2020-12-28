---
marp: true
title: AWS CloudShell で SSM Agent を動かす
theme: default
# footer: ''
style: |
  img[alt~="center"] {
    display: block;
    margin: 0 auto;
  }

# https://marpit.marp.app/image-syntax

---

# <!--fit--> AWS CloudShell で SSM Agent を動かす

## 2020.12.29 AWS CloudShell おもしろ選手権

## so

---

<!-- paginate: true -->

# `$ whoami`

![bg h:300px](./imgs/icon.png)
![bg h:300px right:50%](./imgs/sbslogo.png)

- so ([@3socha](https://twitter.com/3socha))
- シェル芸人
    - [シェル芸bot 用の Dockerfile](https://github.com/theoremoon/ShellgeiBot-Image) をちまちまとメンテナンス
- 好きな AWS のサービス
    - AWS CloudFormation
    - [Simple Beer Service](https://aws.amazon.com/jp/blogs/startups/internet-of-beer-introducing-simple-beer-service/)

---

# シェルたのしい

```sh
$ python3 -m this \
  | tail -n+3 \
  | shuf -n1 \
  | cowsay -f $(cowsay -l | tail -n+2 | tr ' ' '\n' | shuf -n1)
```

```sh
$ sed -E ':a;p;s/(.)(.*)/\2\1/;/ll$/!ba' <<< 'AWS CloudShell '
```

```sh
$ saizeriya -la \
  | shuf -n4 \
  | awk -F, '{print "'\''"$1"'\''";p+=$4;c+=$5}END{print p"円", c"kcal"}' \
  | xargs echo-sd --stress
```

<!-- CloudShell じゃなくて良いけど -->

---

# [ojichat](https://github.com/greymd/ojichat)

[ハイパーシェル芸キュアエンジニアさん](https://twitter.com/grethlen)が作成された、*おじさんがLINEやメールで送ってきそうな文を生成するコマンド*

```sh
$ sudo amazon-linux-extras install -y golang1.11
$ go get -u github.com/greymd/ojichat
$ export PATH=$PATH:$HOME/go/bin
$ ojichat so
```

---

# [ojichatrix](https://github.com/greymd/ojichatrix)

cmatrix 風に ojichat の文言で端末を埋め尽くしてくれる

```sh
$ go get -u github.com/greymd/ojichatrix
$ ojichatrix
```

---

# ローカル端末から AWS CloudShell に接続したい

- 試行錯誤しているうちに、普段使い慣れているローカルの端末から AWS CloudShell に接続したくなった
- が、AWS CloudShell は外部ネットワークから接続できない

---

# SSM Session Manager を使ってみよう

- Systems Manager Session Manager
    - EC2 インスタンスへのセキュアなリモートアクセスを提供する
- AWS CloudShell は EC2 インスタンスではないため、マネージドインスタンスとして登録する
    - オンプレミスのサーバーも EC2 インスタンスと同様に Systems Manager で扱えるようにするためのもの
    - マネージドインスタンスに Session Manager で接続するためには、リージョンレベルの設定でオンプレミスインスタンスティアを[アドバンスドに変更](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/systems-manager-managedinstances-advanced.html)する必要があり、[1時間あたり 0.00695 USD の費用が発生](https://aws.amazon.com/jp/systems-manager/pricing/)する（2020.12時点）

---

# こんな感じ

![center](./imgs/SessionManager.png)

- 参考: [ハイブリッド環境で AWS Systems Manager を設定する](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/systems-manager-managedinstances.html)

---
# SSM Agent をインストール

```sh
$ sudo yum install -y amazon-ssm-agent
```

- AL2 の EC2 インスタンスだと ssm agent が自動的に起動するが、コンテナでは起動しない

---

# マネージドインスタンスをアクティベート

```sh
$ aws ssm create-activation \
    --default-instance-name cloudshell \
    --iam-role service-role/AmazonEC2RunCommandRoleForManagedInstances \
    --registration-limit 1 \
  | jq -cr '.ActivationId, .ActivationCode' \
  | tr '\n' ' ' \
  | awk -v r=$AWS_REGION '{print "sudo amazon-ssm-agent -register -id '\''"$1"'\'' -code", $2, "-region", r }' \
  | sh
```

- 必要な権限
    - `ssm:CreateActivation`
    - `iam:PassRole`

- `/var/lib/amazon/ssm` 以下に SSM Agent の設定が配置されるため、再利用する場合は `$HOME` にコピーして永続化

---

# SSM Agent を起動して接続

```sh
(CloudShell) $ sudo amazon-ssm-agent &
```

- 20分程度？放っておくと AWS CloudShell のセッションが終了されるため、適当にリフレッシュ

```sh
(Local) $ aws ssm start-session --target mi-xxxxxxxxxxxxxxxxx
```

---
# SSM Session Manager 経由で SSH 接続したい

- SSH Server が入っていないため、設定する

```sh
$ sudo yum install -y openssh-server
```

```sh
$ sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key
```

```sh
$ sudo /usr/sbin/sshd -D &
```

- SSH 公開鍵設定

```sh
$ mkdir -m 700 .ssh
$ curl -s https://github.com/$GITHUB_USERNAME.keys > ~/.ssh/authorized_keys
$ chmod 600 ~/.ssh/authorized_keys
```

---

# SSM Session Manager のポートフォワードを利用

```sh
$ ssh cloudshell-user@mi-xxxxxxxxxxxxxxxxx \
  -oProxyCommand="aws ssm start-session \
    --region ap-northeast-1 \
    --target %h \
    --document-name AWS-StartSSHSession \
    --parameters 'portNumber=%p'"
```

- `~/.ssh/config` に書くなら

```
Host cloudshell
    HostName      mi-xxxxxxxxxxxxxxxxx
    User          cloudshell-user
    ProxyCommand  sh -c "aws ssm start-session --region ap-northeast-1 --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```

---

# だいたいできた
## 日本語が化ける場合

```sh
$ sudo yum install -y glibc-langpack-ja
```

---

# CloudShell での SSM Agent 使いどころ?

1. ファイルを scp で直接転送したい
    - tar で固めて S3 使えば良いのでは 🤔
2. SSH Agent を転送して、プライベート Git リポジトリから Clone
    - AWS CloudShell にはクレデンシャルが付くし、git-remote-codecommit が入っているので CodeCommit を使った方が良いような 😦
3. 将来的に CloudShell から VPC に接続できるようになれば、SSH Proxy として
    - ローカルの RDB クライアントから、ポートフォワードで RDS に接続するための一時的な踏み台になる? 😮

---

# おわり

```
$ owari kan -g -a so

|￣￣￣￣￣￣￣￣￣|
|        終        |
|    制作・著作    |
|  ￣￣￣￣￣￣￣  |
|        so        |
|＿＿＿＿＿＿＿＿＿|
    ∧∧ ||
   ( ﾟдﾟ)||
    /   づΦ
```

---

# おまけ - 細かな設定手順など

---

# nyancat

```sh
$ git clone --depth 1 https://github.com/klange/nyancat.git
$ sudo yum install -y gcc
$ (cd nyancat && make)
$ install --mode 755 nyancat/src/nyancat $HOME/bin/nyancat
$ rm -rf nyancat
$ nyancat
```

---

---

# アドバンストインスタンス層の有効化

```sh
$ aws ssm update-service-setting \
  --setting-id "arn:aws:ssm:$AWS_REGION:$(
      aws sts get-caller-identity --output text --query Account
    ):servicesetting/ssm/managed-instance/activation-tier" \
  --setting-value advanced
```

```sh
$ aws ssm get-service-setting \
  --setting-id "arn:aws:ssm:$AWS_REGION:$(
      aws sts get-caller-identity --output text --query Account
    ):servicesetting/ssm/managed-instance/activation-tier" \
  --query 'ServiceSetting.SettingValue'
```

- 必要な権限
    - `ssm:GetServiceSetting`
    - `ssm:UpdateServiceSetting`
- 参考: [アドバンストインスタンス層の有効化 (AWS CLI)](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/systems-manager-managedinstances-advanced.html#systems-manager-managedinstances-advanced-enabling-cli)
---

# IAM サービスロールを作成（なければ）


```sh
$ aws iam create-role \
  --role-name AmazonEC2RunCommandRoleForManagedInstances \
  --path /service-role/ \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": {
      "Effect": "Allow",
      "Principal": { "Service": "ssm.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  }'
```

- 必要な権限
    - `iam:CreateRole`

- 参考: [ハイブリッド環境の IAM サービスロールを作成する](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/sysman-service-role.html)

---

# IAM サービスロールにポリシーをアタッチ

```sh
$ aws iam attach-role-policy \
  --role-name AmazonEC2RunCommandRoleForManagedInstances \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

- 必要な権限
    - `iam:AttacheRolePolicy`
