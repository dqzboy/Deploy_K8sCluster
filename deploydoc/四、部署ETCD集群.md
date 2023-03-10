> etcd 是基于 Raft 的分布式 KV 存储系统，由 CoreOS 开发，常用于服务发现、共享配置以及并发控制（如 leader 选举、分布式锁等）
kubernetes 使用 etcd 集群持久化存储所有 API 对象、运行数据。
- etcd 集群节点名称和 IP 如下：

| 主机名  | IP |
| :---: | :---: |
| k8s-master1 | 192.168.66.62 |
| k8s-master2 | 192.168.66.63 |
| k8s-master3 | 192.168.66.64 |


## 1、下载和分发 etcd 二进制文件
- ETCD仓库地址：https://github.com/etcd-io/etcd/releases
- 如果网络原因，请在本地下载好安装包并上传至服务器

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work/
[root@k8s-master1 work]# mkdir -p etcd && cd etcd

[root@k8s-master1 work]# export etcdVer=3.5.5
# https://ghproxy.com为国内免费GitHub代理
[root@k8s-master1 etcd]# wget https://ghproxy.com/https://github.com/etcd-io/etcd/releases/download/v${etcdVer}/etcd-v${etcdVer}-linux-amd64.tar.gz

[root@k8s-master1 etcd]# tar -zxvf etcd-v${etcdVer}-linux-amd64.tar.gz

[root@k8s-master1 etcd]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp etcd-v${etcdVer}-linux-amd64/etcd* root@${node_ip}:/opt/k8s/bin
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```

## 2、创建 etcd 证书和私钥
### 2.1：创建证书签名请求
- **注意：** 这里的IP地址一定要根据自己的实际ETCD集群IP填写；不然有可能会出现`error "remote error: tls: bad certificate", ServerName ""`的错误

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work/etcd
[root@k8s-master1 etcd]# mkdir -p cert && cd cert/

# 定义etcd节点IP地址
[root@k8s-master1 ~]# export etcd01=192.168.66.62
[root@k8s-master1 ~]# export etcd02=192.168.66.63
[root@k8s-master1 ~]# export etcd03=192.168.66.64

[root@k8s-master1 cert]# cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "${etcd01}",
    "${etcd02}",
    "${etcd03}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Beijing",
      "L": "Beijing",
      "O": "k8s",
      "OU": "dqz"
    }
  ]
}
EOF
```


### 2.2：生成证书和私钥
```shell
[root@k8s-master1 cert]# cfssl gencert -ca=/opt/k8s/work/ca/ca.pem \
    -ca-key=/opt/k8s/work/ca/ca-key.pem \
    -config=/opt/k8s/work/ca/ca-config.json \
    -profile=kubernetes etcd-csr.json | cfssljson -bare etcd

[root@k8s-master1 work]# ls etcd*pem
etcd-key.pem  etcd.pem
```

### 2.3：分发证书和私钥至各etcd节点
```shell
[root@k8s-master1 cert]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/etcd/cert"
    scp etcd*.pem root@${node_ip}:/etc/etcd/cert/
  done
```

## 3、创建 etcd 的 systemd unit 模板文件
```shell
[root@k8s-master1 ~]# mkdir -p /opt/k8s/work/service-template
[root@k8s-master1 ~]# cd /opt/k8s/work/service-template
[root@k8s-master1 service-template]# mkdir -p etcd && cd etcd
[root@k8s-master1 etcd]# cat > etcd.service.template <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=${ETCD_DATA_DIR}
ExecStart=/opt/k8s/bin/etcd \\
  --data-dir=${ETCD_DATA_DIR} \\
  --wal-dir=${ETCD_WAL_DIR} \\
  --name=##ETCD_NAME## \\
  --cert-file=/etc/etcd/cert/etcd.pem \\
  --key-file=/etc/etcd/cert/etcd-key.pem \\
  --trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-cert-file=/etc/etcd/cert/etcd.pem \\
  --peer-key-file=/etc/etcd/cert/etcd-key.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --listen-peer-urls=https://##ETCD_IP##:2380 \\
  --initial-advertise-peer-urls=https://##ETCD_IP##:2380 \\
  --listen-client-urls=https://##ETCD_IP##:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=https://##ETCD_IP##:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=${ETCD_NODES} \\
  --initial-cluster-state=new \\
  --auto-compaction-mode=periodic \\
  --auto-compaction-retention=1 \\
  --max-request-bytes=33554432 \\
  --quota-backend-bytes=6442450944 \\
  --heartbeat-interval=250 \\
  --election-timeout=2000
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```
- `WorkingDirectory`、`--data-dir`：指定工作目录和数据目录为 ${ETCD_DATA_DIR}，需在启动服务前创建这个目录；
- `--wal-dir`：指定 wal 目录，为了提高性能，一般使用 SSD 或者和 --data-dir 不同的磁盘；
- `--name`：指定节点名称，当 `--initial-cluster-state` 值为 new 时，--name 的参数值必须位于 --initial-cluster 列表中；
- `--cert-file`、`--key-file`：etcd server 与 client 通信时使用的证书和私钥；
- `--trusted-ca-file`：签名 client 证书的 CA 证书，用于验证 client 证书；
- `--peer-cert-file`、`--peer-key-file`：etcd 与 peer 通信使用的证书和私钥；
- `--peer-trusted-ca-file`：签名 peer 证书的 CA 证书，用于验证 peer 证书


## 4、为各ETCD节点创建和分发 etcd systemd unit 文件
### 4.1：替换模板文件中的变量
```shell
[root@k8s-master1 etcd]# for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##ETCD_NAME##/${ETCD_NAMES[i]}/" -e "s/##ETCD_IP##/${ETCD_IPS[i]}/" etcd.service.template > etcd-${ETCD_IPS[i]}.service 
  done

[root@k8s-master1 etcd]# ls *.service
etcd-192.168.66.62.service  etcd-192.168.66.63.service  etcd-192.168.66.64.service
```
### 4.2：分发生成的 systemd unit 文件
```shell
[root@k8s-master1 etcd]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp etcd-${node_ip}.service root@${node_ip}:/etc/systemd/system/etcd.service
  done
```

### 4.3：检查配置文件

```shell
[root@k8s-master1 etcd]# ls /etc/systemd/system/etcd.service 
/etc/systemd/system/etcd.service
[root@k8s-master1 etcd]# vim /etc/systemd/system/etcd.service
```
- 确认脚本文件中的IP地址和数据存储地址是否都正确

## 5、启动ETCD服务
- etcd 进程首次启动时会等待其它节点的 etcd 加入集群，命令 `systemctl start etcd` 会卡住一段时间，为正常现象。
- **注意：** 有可能ETCD节点1启动失败，而另外2个节点启动成功，这是正常情况，请重启ETCD节点1即可
```shell
[root@k8s-master1 etcd]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${ETCD_DATA_DIR} ${ETCD_WAL_DIR} && chmod 0700 /data/k8s/etcd/data"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable etcd && systemctl restart etcd"
  done
```

<table>
    <tr>
        <td width="50%" align="center"><img src="https://user-images.githubusercontent.com/42825450/224274785-b5bed5b3-918a-4b40-8474-2dfd3d5ad972.png?raw=true"></td>
    </tr>
</table>

- 手动在master1节点运行启动ETCD服务

```shell
[root@k8s-master1 etcd]# systemctl daemon-reload && systemctl enable etcd && systemctl restart etcd
```

## 6、检查启动结果
```shell
[root@k8s-master1 etcd]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status etcd|grep Active"
  done

[root@k8s-master1 etcd]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status etcd"
  done
```

## 7、验证服务状态
### 7.1：任一etcd节点执行以下命令
```shell
[root@k8s-master1 etcd]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    /opt/k8s/bin/etcdctl \
    --endpoints=https://${node_ip}:2379 \
    --cacert=/etc/kubernetes/cert/ca.pem \
    --cert=/etc/etcd/cert/etcd.pem \
    --key=/etc/etcd/cert/etcd-key.pem endpoint health
  done
```

<table>
    <tr>
        <td width="50%" align="center"><img src="https://user-images.githubusercontent.com/42825450/224275166-43f83d4a-6555-45db-a57d-90ef6eda98f2.png?raw=true"></td>
    </tr>
</table>

### 7.2：查看当前leader
```shell
[root@k8s-master1 etcd]# /opt/k8s/bin/etcdctl \
  -w table --cacert=/etc/kubernetes/cert/ca.pem \
  --cert=/etc/etcd/cert/etcd.pem \
  --key=/etc/etcd/cert/etcd-key.pem \
  --endpoints=${ETCD_ENDPOINTS} endpoint status
```

<table>
    <tr>
        <td width="50%" align="center"><img src="https://user-images.githubusercontent.com/42825450/224275347-f0281e04-90f6-498f-a301-c79625d916c8.png?raw=true"></td>
    </tr>
</table>
