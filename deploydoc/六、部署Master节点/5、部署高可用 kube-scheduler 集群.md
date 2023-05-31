## 1、创建 kube-scheduler 证书和私钥
### 1.1：创建证书签名请求
```shell
[root@k8s-master1 work]# cat > kube-scheduler-csr.json <<EOF
{
    "CN": "system:kube-scheduler",
    "hosts": [
      "127.0.0.1",
      "192.168.66.62",
      "192.168.66.63",
      "192.168.66.64"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
      {
        "C": "CN",
        "ST": "ShangHai",
        "L": "ShangHai",
        "O": "system:kube-scheduler",
        "OU": "dqz"
      }
    ]
}
EOF
```
- hosts 列表包含所有 kube-scheduler 节点 IP；
- CN和O 均为`system:kube-scheduler，kubernetes` 内置的 `ClusterRoleBindings system:kube-scheduler` 将赋予 kube-scheduler 工作所需的权限；

### 1.2：生成证书和私钥
```shell
]# cfssl gencert -ca=/etc/kubernetes/cert/ca.pem \
  -ca-key=/etc/kubernetes/cert/ca-key.pem \
  -config=/etc/kubernetes/cert/ca-config.json \
  -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler

]# ls kube-scheduler*pem
kube-scheduler-key.pem  kube-scheduler.pem
```

### 1.3：将生成的证书和私钥分发到所有 master 节点
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-scheduler*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```

## 2、创建和分发 kubeconfig 文件
### 2.1：创建kuberconfig文件
```shell
]# kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/cert/ca.pem \
--embed-certs=true \
--server="${KUBE_APISERVER}" \
--kubeconfig=kube-scheduler.kubeconfig

]# kubectl config set-credentials system:kube-scheduler \
--client-certificate=kube-scheduler.pem \
--client-key=kube-scheduler-key.pem \
--embed-certs=true \
--kubeconfig=kube-scheduler.kubeconfig

]# kubectl config set-context system:kube-scheduler \
--cluster=kubernetes \
--user=system:kube-scheduler \
--kubeconfig=kube-scheduler.kubeconfig

]# kubectl config use-context system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
```
### 2.2：分发 kubeconfig 到所有 master 节点
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-scheduler.kubeconfig root@${node_ip}:/etc/kubernetes/kube-scheduler.kubeconfig
  done
```
## 3、创建 kube-scheduler 配置文件
### 3.1：创建kube-scheduler配置文件
```shell
cat >kube-scheduler.yaml <<EOF
apiVersion: kubescheduler.config.k8s.io/v1beta2
kind: KubeSchedulerConfiguration
clientConnection:
  burst: 200
  kubeconfig: "/etc/kubernetes/kube-scheduler.kubeconfig"
  qps: 100
enableContentionProfiling: false
enableProfiling: true
healthzBindAddress: ""
leaderElection:
  leaderElect: true
metricsBindAddress: ""
EOF
```
-	`--kubeconfig`：指定 kubeconfig 文件路径，kube-scheduler 使用它连接和验证 kube-apiserver；
-	`--leader-elect=true`：集群运行模式，启用选举功能；被选为 leader 的节点负责处理工作，其它节点为阻塞状态；

### 3.2：分发 kube-scheduler 配置文件到所有 master 节点
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-scheduler.yaml root@${node_ip}:/etc/kubernetes/
  done
```

## 4、创建 kube-scheduler systemd unit 模板文件
```shell
]# cat > kube-scheduler.service.template <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
[Service]
WorkingDirectory=${K8S_DIR}/kube-scheduler
ExecStart=/opt/k8s/bin/kube-scheduler \\
--config=/etc/kubernetes/kube-scheduler.yaml \\
--bind-address=0.0.0.0 \\
--leader-elect=true \\
--tls-cert-file=/etc/kubernetes/cert/kube-scheduler.pem \\
--tls-private-key-file=/etc/kubernetes/cert/kube-scheduler-key.pem \\
--authentication-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
--client-ca-file=/etc/kubernetes/cert/ca.pem \\
--requestheader-allowed-names="aggregator" \\
--requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
--requestheader-extra-headers-prefix="X-Remote-Extra-" \\
--requestheader-group-headers=X-Remote-Group \\
--requestheader-username-headers=X-Remote-User \\
--authorization-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
--v=4
Restart=always
RestartSec=5
StartLimitInterval=0
[Install]
WantedBy=multi-user.target
EOF
```
- `--leader-elect`：默认值：true，在执行主循环之前，开始领导者选举并选出领导者。 使用多副本来实现高可用性时，可启用此标志。
- `--authentication-kubeconfig`：指向具有足够权限以创建 `tokenaccessreviews.authentication.k8s.io` 的 Kubernetes 核心服务器的 kubeconfig 文件。 这是可选的。如果为空，则所有令牌请求均被视为匿名请求，并且不会在集群中查找任何客户端 CA。
- `--requestheader-allowed-names`：客户端证书通用名称列表，允许在 `--requestheader-username-headers` 指定的头部中提供用户名。如果为空，则允许任何由 `--requestheader-client-ca-file` 中证书机构验证的客户端证书
- `--requestheader-client-ca-file`：在信任 `--requestheader-username-headers` 指定的头部中的用户名之前 用于验证传入请求上的客户端证书的根证书包。 警告：通常不应假定传入请求已经完成鉴权

## 5、为各节点创建和分发 kube-scheduler systemd unit 文件
```shell
]# for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" -e "s/##NODE_IP##/${MASTER_IPS[i]}/" kube-scheduler.service.template > kube-scheduler-${MASTER_IPS[i]}.service 
  done

]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-scheduler-${node_ip}.service root@${node_ip}:/etc/systemd/system/kube-scheduler.service
  done
```

## 6、启动kube-scheduler 服务
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kube-scheduler"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-scheduler && systemctl restart kube-scheduler"
  done
```

## 7、检查服务运行状态
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-scheduler|grep Active"
  done
```
## 8、查看输出的 metrics
- 1.23+版本之后，kube-scheduler 只监听10259 端口：
- 10259：接收 https 请求，安全端口，需要认证授权；
- 两个接口都对外提供 /metrics 和 /healthz的访问。

```shell
netstat -lnpt |grep kube-sch
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/92a18d22-03cb-4e3b-9f17-3ae1bb5ff6c9" width="800px">

```shell
curl -s --cacert /etc/kubernetes/cert/ca.pem --cert /opt/k8s/work/certs/admin-cert/admin.pem --key /opt/k8s/work/certs/admin-cert/admin-key.pem https://192.168.66.62:10259/metrics |head
```
## 9、查看集群状态
```shell
]# kubectl get cs
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/375d9183-f298-49c2-a2d9-5e54614aa7c5" width="800px">
