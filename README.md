#Swarm 部署脚本
## 前言
该脚本可以安装、配置脚本、获取地址、启动和重启swarm程序。
欢迎大家使用~如有问题可以与我联系。

## 环境
CentOS 7，使用root用户运行。
bee-clef使用0.4.12版本。bee版本可手动输入。

## 用法
下载脚本后，初次使用可以按照以下步骤进行配置

### 安装
最新bee版本号：0.6.2
```shell
mkdir /bee
cd /bee
sh bee.sh install [bee版本号]
```

### 生产配置脚本
#### 基于端口
大部分个人用户没有多余IP地址，又想多开的话可以使用多端口进行配置。
```shell
sh bee.sh pconfig [节点数量] [swap-endpoint地址]
```

#### 基于IP地址
ip地址可以自己手动添加，也可以使用脚本添加，将IP/掩码写道iplist中
```shell
sh bee.sh ipadd [网卡名称]
```
再使用脚本生成配置文件
```shell
sh bee.sh iconfig [swap-endpoint地址]
```

### 获取以太坊地址
执行命令后会写道address文件中，屏幕也有输出
```shell
sh bee.sh address
```

### 启动和停止
领水后启动，启动和停止也可以选择节点范围，节点号从0开始。
启动节点前会先关闭节点，避免重复启动
```shell
sh bee.sh restart [起始节点] [结束节点]
sh bee.sh stop [起始节点] [结束节点]
```

### 查看
可以查看节点以太坊地址、钱包地址、peer数量、支票信息。可以选择起始范围，不写默认为所有节点
```shell
sh bee.sh show [起始节点] [结束节点]
```

### 升级
由于测试网络官方升级频繁，可以使用该脚本升级。升级前会关闭所有节点。
```shell
sh bee.sh update [bee版本号]
```