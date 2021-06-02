#!/usr/bin/env bash
# node数量
nodesfile=".nodes"
## node节水地址
nodesaddress="address"

# bee文件夹
root="/bee"

# git加速
cnpmjs=“.cnpmjs.org”

# 支票兑换脚本URL
cashout=https://gist.githubusercontent.com/ralph-pichler/3b5ccd7a5c5cd0500e6428752b37e975/raw/aa576d6d28b523ea6f5d4a1ffb3c8cc0bbc2677f/cashout.sh
clef_url=https://github.com/ethersphere/bee-clef/releases/download
bee_url=https://github.com/ethersphere/bee/releases/download

# centos安装bee相关程序
install_centos() {
  yum install -y epel-release
  yum install -y screen jq wget net-tools tree chrony
  systemctl start chronyd.service && systemctl enable chronyd.service
  # install bee
  # 安装bee-clef
  if ! type bee-clef-service >/dev/null 2>&1; then
    # 安装版本控制，都是安装amd64版本
    clef_version="0.4.12"
    wget ${clef_url}/v${clef_version}/bee-clef_${clef_version}_amd64.rpm
    sudo rpm -i bee-clef_${clef_version}_amd64.rpm
  else
    echo "bee-clef 0.4.12已经安装"
  fi
  # 安装bee
  if ! type bee >/dev/null 2>&1; then
    # 安装版本控制，都是安装amd64版本
    bee_version=$1
    if [ -z ${bee_version} ]; then
      echo "缺少bee版本号，请确认后重新尝试"
      exit 2
    fi
    wget ${bee_url}/v${bee_version}/bee_${bee_version}_amd64.rpm
    sudo rpm -i bee_${bee_version}_amd64.rpm
  fi
  echo -n "bee 已安装版本: "
  bee version
  systemctl start bee-clef
  status=$(systemctl status bee-clef | awk 'NR==3{print $2}')
  if [ ${status} != "active" ]; then
    echo "bee clef 状态异常，请使用systemctl status bee-clef检测状态"
  fi
}

# 获取支票兑换脚本
get_cashout() {
  wget -O cashout.sh ${cashout} && chmod 777 cashout.sh
  sed -i 's/10000000000000000/1/g' cashout.sh
}

start() {
  screen -dmS node$i
  screen -x -S node$i -p 0 -X stuff "bee start --config ${root}/node${i}/config.yaml"
  screen -x -S node$i -p 0 -X stuff $'\n'
  echo "节点${i}已启动"
}

close() {
  screen -XS node$i quit >/dev/null 2>&1
  echo "节点$i已关闭"
}

node_start() {
  nodes=$(cat ${root}/.nodes)
  if [[ $1 -lt 0 ]] || [[ $1 -ge ${nodes} ]]; then
    echo "起始节点号有误"
    exit 2
  fi
  start=$1
  if [ -z $1 ]; then
    start=0
  fi
  return ${start}
}

node_end() {
  nodes=$(cat ${root}/.nodes)
  if [[ $1 -lt 0 ]] || [[ $1 -ge ${nodes} ]]; then
    echo "结束节点号有误"
    exit 2
  fi
  end=$1
  if [ -z $end ]; then
    end=$((${nodes} - 1))
  fi
  return ${end}
}

base_config() {
  echo 'cache-capacity: "2000000"' >>${root}/node$1/config.yaml
  echo 'block-time: "15"' >>${root}/node$1/config.yaml
  echo 'bootnode:' >>${root}/node$1/config.yaml
  echo '- /dnsaddr/bootnode.ethswarm.org' >>${root}/node$1/config.yaml
  echo 'debug-api-enable: true' >>${root}/node$1/config.yaml
  echo 'password-file: /var/lib/bee/password' >>${root}/node$1/config.yaml
  echo 'swap-initial-deposit: "10000000000000000"' >>${root}/node$1/config.yaml
  echo 'verbosity: 5' >>${root}/node$1/config.yaml
  echo 'full-node: true' >>${root}/node$1/config.yaml
}

case "$1" in
install)
  if [ -f /etc/redhat-release ]; then
    install_centos $2
  else
    echo "您的系统不支持自动安装，请确认后重新尝试！"
  fi
  ;;
pconfig)
  if [ ! -n "$2" ] || [ ! -n "$3" ]; then
    echo "请输入节点数量和endpoint地址信息"
    exit 2
  fi
  # 获取兑换支票程序
  get_cashout
  # 制作nodeX配置文件
  nodes=$2
  endpoint=$3
  echo ${nodes} >${root}/${nodesfile}
  echo ${root}/${nodesfile}
  for ((i = 0; i < ${nodes}; i++)); do
    path=${root}/node${i}
    config=${path}/config.yaml
    mkdir -p ${root}/node${i}/tmp

    # 基于端口做配置文件1633-1635，每三个一组。如有冲突请手动解决
    port=$(($i * 3))
    # 兑换支票脚本
    cp cashout.sh ${path}/cashout.sh
    sed -i "s/1635/$((1635 + ${port}))/g" ${path}/cashout.sh
    base_config $i
    echo "api-addr: 127.0.0.1:$((1633 + ${port}))" >>${root}/node$i/config.yaml
    echo "data-dir: ${root}/node${i}/tmp" >>${root}/node$i/config.yaml
    echo "debug-api-addr: 127.0.0.1:$((1635 + ${port}))" >>${root}/node$i/config.yaml
    echo "p2p-addr: 127.0.0.1:$((1634 + ${port}))" >>${root}/node$i/config.yaml
    echo "swap-endpoint: ${endpoint}" >>${root}/node$i/config.yaml
    echo "节点${i}配置文件生产完毕"
  done
  ;;
iconfig)
  endpoint=$2
  if [ -z ${endpoint} ]; then
    echo "请输入endpoint地址信息"
    exit 2
  fi
  get_cashout
  ips=$(ip a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:" | awk -F/ '{print $1}')
  i=0
  for ip in ${ips}; do
    path=${root}/node${i}
    config=${path}/config.yaml
    mkdir -p ${root}/node${i}/tmp
    >${root}/node$i/config.yaml
    base_config $i
    echo "api-addr: ${ip}:1633" >>${root}/node$i/config.yaml
    echo "data-dir: ${root}/node${i}/tmp" >>${root}/node$i/config.yaml
    echo "debug-api-addr: ${ip}:1635" >>${root}/node$i/config.yaml
    echo "p2p-addr: ${ip}:1634" >>${root}/node$i/config.yaml
    echo "swap-endpoint: ${endpoint}" >>${root}/node$i/config.yaml
    echo "节点${i}配置文件生产完毕"

    cp cashout.sh ${path}/cashout.sh
    sed -i "s/localhost/${ip}/g" ${path}/cashout.sh
    ((i++))
  done
  echo $i >${nodesfile}
  ;;
address)
  node_start $2
  s=$?
  node_end $3
  e=$?
  for ((i = $s; i < $(($e + 1)); i++)); do
    close $i
    start $i
  done
  nodes=$(cat ${root}/.nodes)
  >address
  for ((i = 0; i < ${nodes}; i++)); do
    sleep 5
    dip=$(cat node${i}/config.yaml | grep 'debug-api-addr' | awk '{print $2}')
    address=$(curl -s http://${dip}/addresses | jq .ethereum)
    echo "node$i地址: $address"
    echo "node$i地址: $address" >>${nodesaddress}
  done
  ;;
restart)
  node_start $2
  s=$?
  node_end $3
  e=$?
  for ((i = $s; i < $(($e + 1)); i++)); do
    close $i
    start $i
  done
  ;;
stop)
  node_start $2
  s=$?
  node_end $3
  e=$?
  for ((i = $s; i < $(($e + 1)); i++)); do
    close $i
  done
  ;;
show)
  if [ -z $2 ]; then
    s=0
    e=$(cat ${root}/${nodesfile})
  else
    s=$2
    e=$(($2 + 1))
  fi
  for ((i = $s; i < $e; i++)); do
    dip=$(cat ${root}/node${i}/config.yaml | grep 'debug-api-addr' | awk '{print $2}')
    address=$(curl -s ${dip}/addresses | jq .ethereum)
    chequebook=$(curl -s ${dip}/chequebook/address | jq .chequebookAddress)
    peers=$(curl -s http://localhost:1635/peers | jq '.peers | length')
    cheque=`curl -s http://localhost:1635/chequebook/cheque | jq .lastcheques`
    echo "节点${i}的合约地址: $address, 钱包地址: $chequebook, peer数量: ${peers}, 支票: ${cheque} "
  done
  ;;
ipadd)
  if [ -z $2 ]; then
    echo "请输入需要添加IP的接口"
    exit 2
  fi
  if [ ! -e iplist ]; then
    echo "请将IP/NETMASK写入${root}/iplist文件中"
    exit 2
  fi
  iplist=$(cat ${root}/iplist)
  for ip in $iplist; do
    ip address add $ip dev $2
  done
  ip a
  ;;
update)
  nodes=$(cat ${root}/.nodes)
  for ((i = 0; i < ${nodes}; i++)); do
    close $i
  done
  if [ -z $2 ]; then
    echo "请输入bee更新版本"
    exit 2
  fi
  wget ${bee_url}/v${2}/bee_${2}_amd64.rpm
  sudo rpm -U bee_${2}_amd64.rpm
  echo -n "bee 已安装版本: "
  bee version
  ;;
*)
  echo $"Usage: $0 {install|pconfig|iconfig|restart|stop}"
  exit 2
  ;;
esac
