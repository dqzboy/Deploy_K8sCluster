## 3.1、创建 kubernetes-master 证书和私钥
```shell
[root@k8s-master1 ~]# cd /opt/k8s/work/
[root@k8s-master1 work]# cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes-master",
  "hosts": [
    "127.0.0.1",
    "192.168.66.62",
    "192.168.66.63",
    "192.168.66.64",
    "10.254.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local.",
    "kubernetes.default.svc.cluster.local."
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
- 生成证书和私钥
```shell
[root@k8s-master1 work]# cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes

[root@k8s-master1 work]# ls kubernetes*pem
kubernetes-key.pem  kubernetes.pem
```
- 将生成的证书和私钥文件拷贝到集群Master节点
```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/kubernetes/cert"
    scp kubernetes*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```

## 3.2：创建加密配置文件
- 官网介绍：https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- `encryption`：静态数据加密；Secret数据在写入 etcd 时会被加密，如无此配置数据写入etcd则是明文
- `EncryptionConfiguration` 的引入是为了能够使用本地管理的密钥来在本地加密 Secret数据。
- 使用本地管理的密钥来加密 Secret 能够保护数据免受 etcd 破坏的影响，不过无法针

```shell
[root@k8s-master1 work]# cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
      - configmaps
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

- 将加密配置文件拷贝到 master 节点的 `/etc/kubernetes` 目录下
```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp encryption-config.yaml root@${node_ip}:/etc/kubernetes/
  done
```
## 3.3: 创建审计策略文件
- 官方文档：https://kubernetes.io/zh/docs/tasks/debug-application-cluster/audit/
```shell
[root@k8s-master1 apiserver-cert]# cat > audit-policy.yaml <<EOF
apiVersion: audit.k8s.io/v1 # This is required.
kind: Policy
# Don't generate audit events for all requests in RequestReceived stage.
omitStages:
  - "RequestReceived"
rules:
  # Log pod changes at RequestResponse level
  - level: RequestResponse
    resources:
    - group: ""
      # Resource "pods" doesn't match requests to any subresource of pods,
      # which is consistent with the RBAC policy.
      resources: ["pods"]
  # Log "pods/log", "pods/status" at Metadata level
  - level: Metadata
    resources:
    - group: ""
      resources: ["pods/log", "pods/status"]

  # Don't log requests to a configmap called "controller-leader"
  - level: None
    resources:
    - group: ""
      resources: ["configmaps"]
      resourceNames: ["controller-leader"]

  # Don't log watch requests by the "system:kube-proxy" on endpoints or services
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
    - group: "" # core API group
      resources: ["endpoints", "services"]

  # Don't log authenticated requests to certain non-resource URL paths.
  - level: None
    userGroups: ["system:authenticated"]
    nonResourceURLs:
    - "/api*" # Wildcard matching.
    - "/version"

  # Log the request body of configmap changes in kube-system.
  - level: Request
    resources:
    - group: "" # core API group
      resources: ["configmaps"]
    # This rule only applies to resources in the "kube-system" namespace.
    # The empty string "" can be used to select non-namespaced resources.
    namespaces: ["kube-system"]

  # Log configmap and secret changes in all other namespaces at the Metadata level.
  - level: Metadata
    resources:
    - group: "" # core API group
      resources: ["secrets", "configmaps"]

  # Log all other resources in core and extensions at the Request level.
  - level: Request
    resources:
    - group: "" # core API group
    - group: "extensions" # Version of group should NOT be included.

  # A catch-all rule to log all other requests at the Metadata level.
  - level: Metadata
    # Long-running requests like watches that fall under this rule will not
    # generate an audit event in RequestReceived.
    omitStages:
      - "RequestReceived"
EOF
```
- 分发审计策略文件至所有Mater节点
```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp audit-policy.yaml root@${node_ip}:/etc/kubernetes/audit-policy.yaml
  done
```
## 3.4、创建后续访问 metrics-server 或 kube-prometheus 使用的证书
### 3.4.1：创建证书签名请求
- `proxy-client-csr.json` 文件是用于生成Kubernetes Proxy客户端的证书签名请求（CSR）文件的JSON格式文件
```shell
[root@k8s-master1 work]# cat > proxy-client-csr.json <<EOF
{
  "CN": "aggregator",
  "hosts": [],
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
### 3.4.2：生成证书和私钥
```shell
cfssl gencert -ca=/etc/kubernetes/cert/ca.pem \
  -ca-key=/etc/kubernetes/cert/ca-key.pem  \
  -config=/etc/kubernetes/cert/ca-config.json  \
  -profile=kubernetes proxy-client-csr.json | cfssljson -bare proxy-client

ls proxy-client*.pem
proxy-client-key.pem  proxy-client.pem
```
### 3.4.3：将生成的证书和私钥文件拷贝到所有 master 节点
```shell
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp proxy-client*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```
## 3.5、为各节点创建和分发 kube-apiserver systemd unit 文件
### 3.5.1、创建 kube-apiserver systemd unit 模板文件
```shell
cat > kube-apiserver.service.template <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=${K8S_DIR}/kube-apiserver
ExecStart=/opt/k8s/bin/kube-apiserver \\
  --advertise-address=##MASTER_IP## \\
  --default-not-ready-toleration-seconds=360 \\
  --default-unreachable-toleration-seconds=360 \\
  --max-mutating-requests-inflight=2000 \\
  --max-requests-inflight=4000 \\
  --default-watch-cache-size=200 \\
  --delete-collection-workers=2 \\
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
  --etcd-cafile=/etc/kubernetes/cert/ca.pem \\
  --etcd-certfile=/etc/kubernetes/cert/kubernetes.pem \\
  --etcd-keyfile=/etc/kubernetes/cert/kubernetes-key.pem \\
  --etcd-servers=${ETCD_ENDPOINTS} \\
  --bind-address=##MASTER_IP## \\
  --secure-port=6443 \\
  --tls-cert-file=/etc/kubernetes/cert/kubernetes.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kubernetes-key.pem \\
  --audit-log-maxage=15 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-truncate-enabled \\
  --audit-log-path=${K8S_DIR}/kube-apiserver/audit.log \\
  --audit-policy-file=/etc/kubernetes/audit-policy.yaml \\
  --profiling \\
  --anonymous-auth=false \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --enable-bootstrap-token-auth \\
  --requestheader-allowed-names="aggregator" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --service-account-key-file=/etc/kubernetes/cert/ca.pem \\
  --service-account-issuer=kubernetes.default.svc \\
  --service-account-signing-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --authorization-mode=Node,RBAC \\
  --runtime-config=api/all=true \\
  --enable-admission-plugins=NodeRestriction \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --event-ttl=168h \\
  --kubelet-certificate-authority=/etc/kubernetes/cert/ca.pem \\
  --kubelet-client-certificate=/etc/kubernetes/cert/kubernetes.pem \\
  --kubelet-client-key=/etc/kubernetes/cert/kubernetes-key.pem \\
  --kubelet-timeout=10s \\
  --proxy-client-cert-file=/etc/kubernetes/cert/proxy-client.pem \\
  --proxy-client-key-file=/etc/kubernetes/cert/proxy-client-key.pem \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=${NODE_PORT_RANGE} \\
  --enable-aggregator-routing=true \\
  --v=4
Restart=on-failure
RestartSec=10
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

```

#### 参数介绍
- `--default-not-ready-toleration-seconds`：默认值：300，对污点 NotReady:NoExecute 的容忍时长（以秒计）。 默认情况下这一容忍度会被添加到尚未具有此容忍度的每个 pod 中。
- `--default-unreachable-toleration-seconds`：默认值：300，对污点 Unreachable:NoExecute 的容忍时长（以秒计） 默认情况下这一容忍度会被添加到尚未具有此容忍度的每个 pod 中。
- `--max-mutating-requests-inflight`：默认值：200，如果 `--enable-priority-and-fairness` 为 true，那么此值和 `--max-requests-inflight` 的和将确定服务器的总并发限制（必须是正数）。 否则，该值限制进行中变更类型请求的最大个数，零表示无限制
- `--max-requests-inflight`：默认值：400，如果 `--enable-priority-and-fairness` 为 `true`，那么此值和 `--max-mutating-requests-inflight` 的和将确定服务器的总并发限制（必须是正数）。 否则，该值限制进行中非变更类型请求的最大个数，零表示无限制。
- `--delete-collection-workers`：默认值：1，为 DeleteCollection 调用而产生的工作线程数。 这些用于加速名字空间清理。
- `--encryption-provider-config`：包含加密提供程序配置信息的文件，用在 etcd 中所存储的 Secret 上
- `--advertise-address`：apiserver 对外通告的 IP（kubernetes 服务后端节点 IP）；
- `--default--toleration-seconds`：设置节点异常相关的阈值；
- `--max--requests-inflight`：请求相关的最大阈值；
- `--etcd`：访问 etcd 的证书和 etcd 服务器地址；
- `--bind-address`： https 监听的 IP，不能为 127.0.0.1，否则外界不能访问它的安全端口 6443；
- `--secret-port`：https 监听端口；
- `--insecure-port=0`：关闭监听 http 非安全端口(8080)；该参数在1.24版本中正式被移除，相关Issiue：https://github.com/kubernetes/kubernetes/issues/91506
- `--tls--file`：指定 apiserver 使用的证书、私钥和 CA 文件；
- `--audit-`：配置审计策略和审计日志文件相关的参数；
- `--client-ca-file`：验证 client (**kue-controller-manager**、**kube-scheduler**、**kubelet**、**kube-proxy** 等)请求所带的证书；
- `--enable-bootstrap-token-auth`：启用 kubelet bootstrap 的 token 认证；
- `--requestheader-`：kube-apiserver 的 aggregator layer 相关的配置参数，proxy-client & HPA 需要使用；
- `--requestheader-client-ca-file`：用于签名 --proxy-client-cert-file 和 --proxy-client-key-file 指定的证书；在启用了 metric aggregator 时使用；
- `--requestheader-allowed-names`：不能为空，值为逗号分割的 --proxy-client-cert-file 证书的 CN 名称，这里设置为` "aggregator"`；
- `--service-account-key-file`：签名 ServiceAccount Token 的公钥文件，kube-controller-manager 的 --service-account-private-key-file 指定私钥文件，两者配对使用；
- `--service-account-signing-key-file`：签名 ServiceAccount Token 的私钥文件；
- `--service-account-issuer=kubernetes.default.svc`
- `--runtime-config=api/all=true`：启用所有版本的 APIs，如 autoscaling/v2alpha1；
- `--authorization-mode=Node,RBAC、--anonymous-auth=false`：开启 Node 和 RBAC 授权模式，拒绝未授权的请求；
- `--enable-admission-plugins`：启用一些默认关闭的 plugins；
- `--allow-privileged`：运行执行 privileged 权限的容器；
- `--apiserver-count=3`：指定 apiserver 实例的数量；
- `--event-ttl`：指定 events 的保存时间；
- `--kubelet-`：如果指定，则使用 https 访问 kubelet APIs；需要为证书对应的用户(上面 `kubernetes*.pem` 证书的用户为 kubernetes) 用户定义 RBAC 规则，否则访问 kubelet API 时提示未授权；
- `--proxy-client-`：apiserver 访问 metrics-server 使用的证书；
- `--service-cluster-ip-range`： 指定 Service Cluster IP 地址段；
- `--service-node-port-range`： 指定 NodePort 的端口范围；
- `--v=4`：--v表示Kubectl 日志输出详细程度是通过 -v 或者 --v 来控制的，参数后跟了一个数字表示日志的级别；2表示有关服务的有用稳定状态信息以及可能与系统中的重大更改相关的重要日志消息。这是大多数系统的建议默认日志级别。

### 3.5.2：重新命名systemd unit 文件
```shell
[root@k8s-master1 work]# for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" -e "s/##MASTER_IP##/${MASTER_IPS[i]}/" kube-apiserver.service.template > kube-apiserver-${MASTER_IPS[i]}.service 
  done

[root@k8s-master1 work]# ls kube-apiserver*.service
kube-apiserver-192.168.66.62.service  kube-apiserver-192.168.66.64.service
kube-apiserver-192.168.66.63.service
```
### 3.5.3：分发生成的 systemd unit 文件到所有Master节点
```shell
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-apiserver-${node_ip}.service root@${node_ip}:/etc/systemd/system/kube-apiserver.service
  done
```

## 3.6、启动 kube-apiserver 服务
```shell
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kube-apiserver"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-apiserver && systemctl restart kube-apiserver"
  done

```

## 3.7、检查 kube-apiserver 运行状态
```shell
 for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-apiserver |grep 'Active:'"
  done
```

## 3.8、检查集群状态
```shell
kubectl cluster-info
```
