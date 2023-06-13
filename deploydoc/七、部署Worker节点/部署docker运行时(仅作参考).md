## 1、下载和分发 docker 二进制文件
### 1.1：下载程序包
```shell
~]# cd /opt/k8s/work/
]# wget https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz
]# tar -xzvf docker-20.10.9.tgz
```

### 1.2：分发程序包
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp docker/*  root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```

## 2、创建和分发 systemd unit 文件
### 2.1：创建systemd unit 文件
```shell
]# cat > docker.service <<"EOF"
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
 
[Service]
WorkingDirectory=##DOCKER_DIR##
Environment="PATH=/opt/k8s/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=/opt/k8s/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
 
[Install]
WantedBy=multi-user.target
EOF
```
> docker 从 1.13 版本开始，可能将 iptables FORWARD chain的默认策略设置为DROP，从而导致 ping 其它 Node 上的 Pod IP 失败，遇到这种情况时，需要手动设置策略为 `ACCEPT`

```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "iptables -P FORWARD ACCEPT"
  done

]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "echo '/sbin/iptables -P FORWARD ACCEPT' >> /etc/rc.local"
  done
```
### 2.2：分发 systemd unit 文件到所有节点机器
```shell
]# sed -i -e "s|##DOCKER_DIR##|${DOCKER_DIR}|" docker.service

]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp docker.service root@${node_ip}:/etc/systemd/system/
  done
```

## 3、配置和分发 docker 配置文件
### 3.1：配置docker加速
```shell
]# cat > docker-daemon.json <<EOF
{
    "registry-mirrors": ["http://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn"],
    "insecure-registries": ["私有仓库地址"], 
    "max-concurrent-downloads": 20,
    "max-concurrent-uploads": 10,
"debug": true,
"live-restore": true,
    "data-root": "${DOCKER_DIR}/data",
    "log-opts": {
      "max-size": "100m",
      "max-file": "5"
    }
}
EOF
```
### 3.2：分发至所有节点
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p  /etc/docker/ ${DOCKER_DIR}/{data,exec}"
    scp docker-daemon.json root@${node_ip}:/etc/docker/daemon.json
  done
```
## 4、启动 docker 服务
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable docker && systemctl restart docker"
  done
```
## 5、检查镜像加速是否生效
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} docker info | grep -A 5 "Registry Mirrors"
  done
```

## 6、检查服务运行状态
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status docker|grep Active"
  done
```

## 7、检查 docker0 网桥
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "/usr/sbin/ip addr show docker0"
  done
```
