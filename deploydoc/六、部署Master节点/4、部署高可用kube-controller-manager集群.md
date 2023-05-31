## 说明
> 该集群包含 3 个节点，启动后将通过竞争选举机制产生一个 leader 节点，其它节点为阻塞状态。当 leader 节点不可用时，阻塞的节点将再次进行选举产生新的 leader 节点，从而保证服务的可用性。<br>

> 为保证通信安全，本文档先生成 x509 证书和私钥，kube-controller-manager 在如下两种情况下使用该证书：<br>
1、与 kube-apiserver 的安全端口通信;<br>
2、在安全端口(https，10257) 输出 prometheus 格式的 metrics；

## 1、创建 kube-controller-manager 证书和私钥
### 1.1：创建证书签名请求
```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "192.168.66.62",
      "192.168.66.63",
      "192.168.66.64"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "Beijing",
        "L": "Beijing",
        "O": "system:kube-controller-manager",
        "OU": "dqz"
      }
    ]
}
EOF
```
- hosts 列表包含所有 `kube-controller-manager` 节点 IP；
- CN 和 O 均为 `system:kube-controller-manager`，kubernetes 内置的 `ClusterRoleBindings system:kube-controller-manager` 赋予 kube-controller-manager 工作所需的权限。

### 1.2：生成证书和私钥
```shell
]# cfssl gencert -ca=/etc/kubernetes/cert/ca.pem \
  -ca-key=/etc/kubernetes/cert/ca-key.pem \
  -config=/etc/kubernetes/cert/ca-config.json \
  -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
  
]# ls kube-controller-manager*pem
kube-controller-manager-key.pem  kube-controller-manager.pem
```
### 1.3：将生成的证书和私钥分发到所有 master 节点
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-controller-manager*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```

## 2、创建和分发 kubeconfig 文件
### 2.1：创建kubeconfig 文件
> kube-controller-manager 使用 kubeconfig 文件访问 apiserver，该文件提供了 apiserver 地址、嵌入的 CA 证书和 kube-controller-manager 证书等信息：
```shell
]# kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/cert/ca.pem \
  --embed-certs=true \
  --server="${KUBE_APISERVER}" \
  --kubeconfig=kube-controller-manager.kubeconfig
  
]# kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

]# kubectl config set-context system:kube-controller-manager \
  --cluster=kubernetes \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
```
- kube-controller-manager 与 kube-apiserver 混部，故直接通过节点 IP访问 kube-apiserver；

### 2.2：分发 kubeconfig 到所有 master 节点
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-controller-manager.kubeconfig root@${node_ip}:/etc/kubernetes/kube-controller-manager.kubeconfig
  done
```

## 3、创建 kube-controller-manager systemd unit 模板文件
```shell
]# cat > kube-controller-manager.service.template <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
WorkingDirectory=${K8S_DIR}/kube-controller-manager
ExecStart=/opt/k8s/bin/kube-controller-manager \\
  --profiling \\
  --cluster-name=kubernetes \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --kube-api-qps=1000 \\
  --kube-api-burst=2000 \\
  --leader-elect=true \\
  --use-service-account-credentials=true \\
  --concurrent-service-syncs=2 \\
  --tls-cert-file=/etc/kubernetes/cert/kube-controller-manager.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kube-controller-manager-key.pem \\
  --authentication-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-allowed-names="aggregator" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --authorization-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --cluster-signing-cert-file=/etc/kubernetes/cert/ca.pem \\
  --cluster-signing-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --cluster-signing-duration=876000h \\
  --horizontal-pod-autoscaler-sync-period=10s \\
  --concurrent-deployment-syncs=10 \\
  --concurrent-gc-syncs=30 \\
  --node-cidr-mask-size=24 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --pod-eviction-timeout=6m \\
  --terminated-pod-gc-threshold=10000 \\
  --root-ca-file=/etc/kubernetes/cert/ca.pem \\
  --service-account-private-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --v=4
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```
- `--profiling`：开启性能分析，通过host:port/debug/pprof/查看
- `--kube-api-qps`：默认值：20，与 API 服务器通信时每秒请求数（QPS）限制。
- `--kube-api-burst`：默认值：30，与 Kubernetes API 服务器通信时突发峰值请求个数上限。
- `--leader-elect`：默认值：true，在执行主循环之前，启动领导选举（Leader Election）客户端，并尝试获得领导者身份。 在运行多副本组件时启用此标志有助于提高可用性。
- `--use-service-account-credentials`：当此标志为 true 时，为每个控制器单独使用服务账号凭据。
- `--concurrent-service-syncs`：默认值：1，可以并发同步的 Service 对象个数。数值越大，服务管理的响应速度越快， 不过对 CPU （和网络）的占用也越高。
- `--port=0`：关闭监听非安全端口（http），同时 `--address` 参数无效，`--bind-address` 参数有效； 注意：`--port 和--address`在1.24版本中删除
- `--secure-port=10257`；默认为10257接收https请求该参数已移除
- `--bind-address=0.0.0.0`: 在所有网络接口监听 10252 端口的 https /metrics 请求；（不添加该参数，默认是所有网络接口监听）
- `--kubeconfig`：指定 kubeconfig 文件路径，kube-controller-manager 使用它连接和验证 kube-apiserver；
- `--authentication-kubeconfig` 和 `--authorization-kubeconfig`：kube-controller-manager 使用它连接 apiserver，对 client 的请求进行认证和授权。kube-controller-manager 不再使用 `--tls-ca-file` 对请求 https metrics 的 Client 证书进行校验。如果没有配置这两个 kubeconfig 参数，则 client 连接 kube-controller-manager https 端口的请求会被拒绝(提示权限不足)。
- `--cluster-signing--file`：签名 TLS Bootstrap 创建的证书；
- `--cluster-signing-duration`：指定 TLS Bootstrap 证书的有效期；19之前版本是 --experimental-cluster-signing-duration 参数，该参数1.25版本之后已经删除，替换标志为--cluster-signing-duration；
- `--horizontal-pod-autoscaler-sync-period`: 默认值：15s，水平 Pod 扩缩器对 Pod 数目执行同步操作的周期
- `--concurrent-deployment-syncs`:默认值5, 可以并发同步的 Deployment 对象个数。数值越大意味着对 Deployment 的响应越及时， 同时也意味着更大的 CPU（和网络带宽）压力。
- `--concurrent-gc-syncs`: 默认值：20，并发同步的垃圾收集工作线程个数
- `--terminated-pod-gc-threshold`: 默认值：12500，在 Pod 个数超出所配置的阈值时，删除已终止的 Pod（阶段值为 Succeeded 或 Failed）。 这一行为可以避免随着时间演进不断创建和终止 Pod 而引起的资源泄露问题。
- `--root-ca-file`：放置到容器 ServiceAccount 中的 CA 证书，用来对 kube-apiserver 的证书进行校验；
- `--service-account-private-key-file`：签名 ServiceAccount 中 Token 的私钥文件，必须和 kube-apiserver 的 --service-account-key-file 指定的公钥文件配对使用；
- `--service-cluster-ip-range` ：指定 Service Cluster IP 网段，必须和 kube-apiserver 中的同名参数一致；
- `--leader-elect=true`：集群运行模式，启用选举功能；被选为 leader 的节点负责处理工作，其它节点为阻塞状态；
- `--controllers=,bootstrapsigner,tokencleaner`：启用的控制器列表，tokencleaner 用于自动清理过期的 Bootstrap token；
- `--horizontal-pod-autoscaler-`：custom metrics 相关参数，支持 autoscaling/v2alpha1；
- `--tls-cert-file`、`--tls-private-key-file`：使用 https 输出 metrics 时使用的 Server 证书和秘钥；
- `--use-service-account-credentials=true`: kube-controller-manager 中各 controller 使用 serviceaccount 访问 kube-apiserver；

### 3.1：为各Master节点创建和分发 kube-controller-mananger systemd unit 文件
- **注意**：这里为i < 3表示3台master节点，参数根据实际的master节点数定义
```shell
]# for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" -e "s/##NODE_IP##/${MASTER_IPS[i]}/" kube-controller-manager.service.template > kube-controller-manager-${NODE_IPS[i]}.service 
  done

]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-controller-manager-${node_ip}.service root@${node_ip}:/etc/systemd/system/kube-controller-manager.service
  done
```

## 4、启动kube-controller-manager服务
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kube-controller-manager"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-controller-manager && systemctl restart kube-controller-manager"
  done

```

## 5、检查服务运行状态
```shell
]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-controller-manager|grep Active"
  done

]# netstat -lnpt | grep kube-cont
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/0a5631c8-575c-41cd-9d4f-d2e857298fe0" width="800px">

## 6、查看输出的 metrics
- 在K8S 1.22版本中，kube-controller-manager默认强制使用https进行访问，并且访问的端口为10257
```shell
curl -s --cacert /etc/kubernetes/cert/ca.pem --cert /opt/k8s/work/certs/admin-cert/admin.pem --key /opt/k8s/work/certs/admin-cert/admin-key.pem https://192.168.66.62:10257/metrics |head
```

## 7、检查集群状态
```shell
]# kubectl get cs
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/cbd16271-31a5-4bd4-885e-c83769d66df9" width="800px">
