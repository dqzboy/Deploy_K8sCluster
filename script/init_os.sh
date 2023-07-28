#!/bin/bash

# 函数：读取用户输入并验证输入不能为空
read_input() {
    local message=$1
    local input

    while true; do
        read -p "${message}" input
        if [[ -z "${input}" ]]; then
            echo "输入不能为空，请重新输入！"
        else
            break
        fi
    done

    echo "${input}"
}

# 函数：设置所有节点的主机名
set_hostnames() {
    local nodes=("k8s-master1" "k8s-master2" "k8s-master3" "k8s-worker1" "k8s-worker2" "k8s-worker3")

    for node in "${nodes[@]}"; do
        echo "设置 ${node} 节点的主机名："
        local new_hostname=$(read_input "请输入 ${node} 节点的主机名：")
        ssh root@${node} "hostnamectl --static set-hostname ${new_hostname}"
    done
}

# 函数：配置SSH免密码登录
configure_ssh_passwordless() {
    local nodes=("k8s-master1" "k8s-master2" "k8s-master3" "k8s-worker1" "k8s-worker2" "k8s-worker3")

    echo "配置主机名称解析："
    cat >> /etc/hosts <<EOF
$(cat)
EOF

    echo "配置 K8S-master1 节点通过主机名实现免密登入其他节点"
    ssh-keygen -t rsa
    for node in "${nodes[@]}"; do
        ssh-copy-id root@${node}
    done

    echo "传给各节点，实现免密认证"
    for node in "${nodes[@]}"; do
        echo ">>> ${node}"
        scp /etc/hosts root@${node}:/etc/
    done

    echo "配置 K8S-Master1 节点通过主机名实现免密登入认证"
    for node in "${nodes[@]}"; do
        echo ">>> ${node}"
        ssh-copy-id root@${node}
    done

    # 关闭DNS反向查询，加快SSH连接速度
    for node in "${nodes[@]}"; do
        echo ">>> ${node}"
        ssh root@${node} "sed -ri '/#UseDNS yes/a\UseDNS no' /etc/ssh/sshd_config && systemctl restart sshd"
    done
}

# 函数：配置全局环境变量
configure_env_vars() {
    echo "配置全局环境变量："

    echo "请输入节点的IP地址，用空格分隔（例如：192.168.66.62 192.168.66.63 ...）："
    read -a node_ips

    echo "请输入节点的主机名，用空格分隔（例如：k8s-master1 k8s-master2 ...）："
    read -a node_names

    cat >> /etc/profile <<EOF
# ----------------------------K8S-----------------------------
# 生成 EncryptionConfig 所需的加密 key
export ENCRYPTION_KEY=\$(head -c 32 /dev/urandom | base64)
# 各机器 IP 数组包含Master与Node节点
export NODE_IPS=(${node_ips[@]})
export NODE_NAMES=(${node_names[@]})
# Master集群节点IP
export MASTER_IPS=(${node_ips[@]:0:3})
export MASTER_NAMES=(${node_names[@]:0:3})
# WORK集群数组IP
export WORK_IPS=(${node_ips[@]:3:3})
export WORK_NAMES=(${node_names[@]:3:3})
# ETCD集群IP数组
export ETCD_IPS=(${node_ips[@]:0:3})
export ETCD_NAMES=(${node_names[@]:0:3})

# etcd 集群服务地址列表；注意IP地址根据自己的ETCD集群服务器地址填写
export ETCD_ENDPOINTS="https://${ETCD_IPS[0]}:2379,https://${ETCD_IPS[1]}:2379,https://${ETCD_IPS[2]}:2379"
# etcd 集群间通信的 IP 和端口；注意此处改为自己的实际ETCD所在服务器主机名
export ETCD_NODES="k8s-master1=https://${ETCD_IPS[0]}:2380,k8s-master2=https://${ETCD_IPS[1]}:2380,k8s-master3=https://${ETCD_IPS[2]}:2380"
# kube-apiserver 的反向代理(kube-nginx)地址端口
export KUBE_APISERVER="https://127.0.0.1:8443"
# 节点间互联网络接口名称；根据自己服务器网卡实际名称进行修改
export IFACE="ens33"
# etcd 数据目录
export ETCD_DATA_DIR="/data/k8s/etcd/data"
# etcd WAL 目录，建议是 SSD 磁盘分区，或者和 ETCD_DATA_DIR 不同的磁盘分区
export ETCD_WAL_DIR="/data/k8s/etcd/wal"
# k8s 各组件数据目录
export K8S_DIR="/data/k8s/k8s"
## DOCKER_DIR 和 CONTAINERD_DIR 二选一
# docker 数据目录
export DOCKER_DIR="/data/k8s/docker"
# containerd 数据目录
export CONTAINERD_DIR="/data/k8s/containerd"
## 以下参数一般不需要修改
# TLS Bootstrapping 使用的 Token，可以使用命令 head -c 16 /dev/urandom | od -An -t x | tr -d ' ' 生成
export BOOTSTRAP_TOKEN="41f7e4ba8b7be874fcff18bf5cf41a7c"
# 最好使用 当前未用的网段 来定义服务网段和 Pod 网段
# 服务网段，部署前路由不可达，部署后集群内路由可达(kube-proxy 保证)
export SERVICE_CIDR="10.254.0.0/16"
# Pod 网段，建议 /16 段地址，部署前路由不可达，部署后集群内路由可达(flanneld 保证)
export CLUSTER_CIDR="10.68.0.0/16"
# 服务端口范围 (NodePort Range)，默认范围是30000-32767 
export NODE_PORT_RANGE="30000-32767"
# kubernetes 服务 IP (一般是 SERVICE_CIDR 中第一个IP)
export CLUSTER_KUBERNETES_SVC_IP="10.254.0.1"
# 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配)
export CLUSTER_DNS_SVC_IP="10.254.0.2"
# 集群 DNS 域名（末尾不带点号）
export CLUSTER_DNS_DOMAIN="cluster.local"
# 将二进制目录 /opt/k8s/bin 加到 PATH 中
export PATH=/opt/k8s/bin:\$PATH
EOF

    # 生效环境变量
    source /etc/profile
    for node in "${node_ips[@]}"; do
        echo ">>> ${node}"
        ssh root@${node} "source /etc/profile"
    done
}

# 函数：禁用SELinux
disable_selinux() {
    local nodes=("k8s-master1" "k8s-master2" "k8s-master3" "k8s-worker1" "k8s-worker2" "k8s-worker3")

    for node in "${nodes[@]}"; do
        echo ">>> ${node}"
        ssh root@${node} "setenforce 0 && sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config"
    done
}

# 函数：禁用NetworkManager
disable_network_manager() {
    local nodes=("k8s-master1" "k8s-master2" "k8s-master3" "k8s-worker1" "k8s-worker2" "k8s-worker3")

    for node in "${nodes[@]}"; do
        echo ">>> ${node}"
        ssh root@${node} "systemctl stop NetworkManager && systemctl disable NetworkManager && systemctl status NetworkManager"
    done
}

# 函数：配置时间同步
configure_time_sync() {
    local nodes=("k8s-master1" "k8s-master2" "k8s-master3" "k8s-worker1" "k8s-worker2" "k8s-worker3")

    # Master1节点同步互联网时间
    echo "设置主节点与互联网时间同步："
    ssh root@k8s-master1 "yum install -y chrony"
    ssh root@k8s-master1 "ntpdate time.windows.com"
    ssh root@k8s-master1 "systemctl enable chronyd && systemctl restart chronyd"

    # 其他节点通过主节点进行时间同步
    echo "配置其他节点通过主节点进行时间同步："
    for node in "${nodes[@]}"; do
        echo ">>> ${node}"
        ssh root@${node} "yum install -y chrony"
        ssh root@${node} "sed -i '/^server/d' /etc/chrony.conf"
        ssh root@${node} "echo 'server k8s-master1 iburst' >> /etc/chrony.conf"
        ssh root@${node} "systemctl enable chronyd && systemctl restart chronyd"
    done
}

# 主脚本
set_hostnames
configure_ssh_passwordless
configure_env_vars
disable_selinux
disable_network_manager
configure_time_sync

echo "配置完成！"
