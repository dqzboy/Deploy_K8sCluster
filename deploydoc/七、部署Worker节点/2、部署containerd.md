## containerd 简单描述
> containerd 实现了 kubernetes 的 Container Runtime Interface (CRI) 接口，提供容器运行时核心功能，如镜像管理、容器管理等，相比 dockerd 更加简单、健壮和可移植。

## 1、下载和分发二进制文件
- 所需组件下载地址：下载最新的二进制包
  - https://github.com/kubernetes-sigs/cri-tools/releases/ 
  - https://github.com/opencontainers/runc/releases/
  - https://github.com/containernetworking/plugins/releases/
  - https://github.com/containerd/containerd/releases/

### 1.1：下载程序包
```shell
~]# cd /opt/k8s/work/

]# wget https://github.com/containerd/containerd/releases/download/v1.6.9/containerd-1.6.9-linux-amd64.tar.gz
]# wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.25.0/crictl-v1.25.0-linux-amd64.tar.gz
]# wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
]# wget https://github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64


]# tar -xvf containerd-1.6.9-linux-amd64.tar.gz -C containerd
]# tar -xvf crictl-v1.25.0-linux-amd64.tar.gz
]# mkdir cni-plugins
]# tar -xvf cni-plugins-linux-amd64-v1.1.1.tgz -C cni-plugins
]# mv runc.amd64 runc

```
### 1.2：分发程序包
```shell
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp containerd/bin/*  crictl  cni-plugins/* runc root@${node_ip}:/opt/k8s/bin
    ssh root@${node_ip} "chmod a+x /opt/k8s/bin/* && mkdir -p /etc/cni/net.d"
  done
```
## 2、创建和分发 containerd 配置文件
### 2.1：创建
> 通过containerd命令生成，然后修改root和state对应的路径已经cni的配置；使用 **systemd cgroup** 驱动程序，将配置中的`SystemdCgroup`改为`true`

```shell
]# cat << EOF | sudo tee containerd-config.toml
version = 2
root = "/data/k8s/containerd/root"
state = "/data/k8s/containerd/state"

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "k8s.dockerproxy.com/pause"
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/k8s/bin"
      conf_dir = "/etc/cni/net.d"
    [plugins."io.containerd.grpc.v1.cri".registry]
       config_path = "/etc/containerd/certs.d"
  [plugins."io.containerd.runtime.v1.linux"]
    shim = "containerd-shim"
    runtime = "runc"
    runtime_root = ""
    no_shim = false
    shim_debug = false

[plugin."io.containerd.grpc.v1.cri".registry.mirrors]
  [plugin."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = [
      "https://docker.mirrors.ustc.edu.cn",
      "http://hub-mirror.c.163.com"
    ]
EOF
```

### 2.2：分发
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/containerd/certs.d ${CONTAINERD_DIR}/{root,state}"
    scp containerd-config.toml root@${node_ip}:/etc/containerd/config.toml
  done
```
## 3、创建 containerd systemd unit 文件
```shell
]# cat <<EOF | sudo tee containerd.service
[Unit]
Description=Lightweight Kubernetes
Documentation=https://containerd.io
After=network-online.target

[Service]
Environment="PATH=/opt/k8s/bin:/bin:/sbin:/usr/bin:/usr/sbin"
Environment="KUBELET_EXTRA_ARGS=--cgroup-driver=systemd"
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStartPre=-/bin/mkdir -p /run/containerd
ExecStart=/opt/k8s/bin/containerd \\
         -c /etc/containerd/config.toml \\
         -a /run/containerd/containerd.sock \\
         --state /data/k8s/containerd/state \\
         --root /data/k8s/containerd/root
KillMode=process
Delegate=yes
OOMScoreAdjust=-999
LimitNOFILE=1024000
LimitNPROC=1024000
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
```
## 4、分发 systemd unit 文件，启动 containerd 服务
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp containerd.service root@${node_ip}:/etc/systemd/system
    ssh root@${node_ip} "systemctl daemon-reload && systemctl restart containerd && systemctl enable containerd"
  done

# 检查containerd服务启动是否正常
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status containerd | grep -e active"
  done
```
#### 注意：如果在日志中看到以下的报错信息，这是因为还没有安装网络插件
```log
level=error msg="failed to load cni during init, please check CRI plugin status before setting up network for pods" error="cni config load failed: no network config found in /etc/cni/net.d: cni plugin not initialized: failed to load cni config"
```

## 5、创建和分发 crictl 配置文件
### 5.1：配置文件
```shell
# cat << EOF | sudo tee crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp crictl.yaml root@${node_ip}:/etc/crictl.yaml
  done
```
### 5.2：crictl命令
|  containerd 命令   | 备注 |
|  ----  | ----  |
| crictl image ls  | 获取image信息 |
| crictl image pull xxx  | pull image |
| crictl image tag name tag  | 添加tag |
| crictl run -d --env 111 xxx xxx  | 运行的一个容器|
| crictl ps  | 查看运行的容器 |
| ...  | ... |
> 其他的指令可查阅文档.

