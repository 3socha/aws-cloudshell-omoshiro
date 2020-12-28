#!/bin/bash -eu
BIN_DIR="$HOME/bin"
GO_BIN_DIR="$HOME/go/bin"
mkdir -p "$BIN_DIR"

# prompt
PS1='[\[\e[36m\]\u@\h \[\e[32m\]\W\[\e[m\]]\$ '
grep 'export PS1=' "$HOME/.bashrc" >& /dev/null || {
  echo "export PS1='$PS1'" >> "$HOME/.bashrc"
}

# GOBIN
grep -E "export PATH=\$PATH:$GO_BIN_DIR" "$HOME/.bashrc" >& /dev/null || {
  echo "export PATH=\$PATH:$GO_BIN_DIR" >> "$HOME/.bashrc"
}

# glibc-langpack-ja
rpm -qa | grep glibc-langpack-ja >& /dev/null || {
  sudo yum install -y glibc-langpack-ja
}

# cowsay
rpm -qa | grep cowsay >& /dev/null || {
  sudo yum install -y cowsay
}

# saizeriya
[ -e "$BIN_DIR/saizeriya" ] || {
  curl -sfSL https://raw.githubusercontent.com/3socha/saizeriya/master/saizeriya -o "$BIN_DIR/saizeriya"
  chmod +x "$BIN_DIR/saizeriya"
}

# echo-sd
[ -e "$BIN_DIR/echo-sd" ] || {
  curl -sfSL https://raw.githubusercontent.com/fumiyas/home-commands/master/echo-sd -o "$BIN_DIR/echo-sd"
  chmod +x "$BIN_DIR/echo-sd"
}

# nyancat
[ -e "$BIN_DIR/nyancat" ] || {
  sudo yum install -y gcc
  git clone --depth 1 https://github.com/klange/nyancat.git
  (cd nyancat && make)
  install --mode 755 nyancat/src/nyancat "$BIN_DIR/nyancat"
  rm -rf nyancat
}

# golang
rpm -qa | grep golang >& /dev/null || {
  sudo amazon-linux-extras install -y golang1.11
}

# ojichat
[ -e "$GO_BIN_DIR/ojichat" ] || {
  go get -u github.com/greymd/ojichat
}

# ojichatrix
[ -e "$GO_BIN_DIR/ojichatrix" ] || {
  go get -u github.com/greymd/ojichatrix
}

# owari
[ -e "$GO_BIN_DIR/owari" ] || {
  go get -u github.com/xztaityozx/owari
}
