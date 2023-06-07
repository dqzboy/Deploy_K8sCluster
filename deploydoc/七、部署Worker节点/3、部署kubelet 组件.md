## 1、创建 kubelet bootstrap kubeconfig 文件
> **Bootstrappong**：为Node节点自动颁发证书，也就是给kubelet颁发所使用的证书；由于K8S主节点一般为固定的，而Node节点会做增加、删除或者故障恢复等操作需要证书，而kubelet证书是与主机名进行绑定的，如果手动管理证书会十分麻烦。

### 1.1：生成各节点对应的kubelet-bootstrap配置
```shell
]# for node_name in ${NODE_NAMES[@]}
  do
    echo ">>> ${node_name}"

    # 创建 token
    export BOOTSTRAP_TOKEN=$(kubeadm token create \
      --description kubelet-bootstrap-token \
      --groups system:bootstrappers:${node_name} \
      --kubeconfig ~/.kube/config)

    # 设置集群参数
    kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/cert/ca.pem \
      --embed-certs=true \
      --server=${KUBE_APISERVER} \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig

    # 设置客户端认证参数
    kubectl config set-credentials kubelet-bootstrap \
      --token=${BOOTSTRAP_TOKEN} \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig

    # 设置上下文参数
    kubectl config set-context default \
      --cluster=kubernetes \
      --user=kubelet-bootstrap \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig

    # 设置默认上下文
    kubectl config use-context default --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
  done
```

### 1.2：查看 kubeadm 为各节点创建的 token

- token 有效期为 1 天，**超期后将不能再被用来 boostrap kubelet**，且会被 kube-controller-manager 的 tokencleaner 清理
- kube-apiserver 接收 kubelet 的 bootstrap token 后，将请求的 user 设置为 `system:bootstrap:<Token ID>`，group 设置为 `system:bootstrappers`，后续将为这个 group 设置 `ClusterRoleBinding`

```shell
]# kubeadm token list --kubeconfig ~/.kube/config
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/c604062c-603a-47fa-becf-4d57b98d839b" width="800px">

### 1.3：查看各 token 关联的 Secret
```shell
]# kubectl get secrets  -n kube-system|grep bootstrap-token
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/7a76bad3-735d-493d-8420-95cda0b2a6f8" width="800px">

## 2、分发 bootstrap kubeconfig 文件到所有节点
```shell
]# for node_name in ${NODE_NAMES[@]}
  do
    echo ">>> ${node_name}"
    scp kubelet-bootstrap-${node_name}.kubeconfig root@${node_name}:/etc/kubernetes/kubelet-bootstrap.kubeconfig
  done
```
## 3、创建和分发 kubelet 参数配置文件
### 3.1：创建 kubelet 参数配置模板文件
> 从 **v1.10** 开始，部分 kubelet 参数需在配置文件中配置，kubelet --help会提示：
`DEPRECATED: This parameter should be set via the config file specified by the Kubelet's --config flag`

```shell
]# cat > kubelet-config.yaml.template <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: "##NODE_IP##"
staticPodPath: ""
syncFrequency: 1m
fileCheckFrequency: 20s
httpCheckFrequency: 20s
staticPodURL: ""
port: 10250
readOnlyPort: 0
rotateCertificates: true
serverTLSBootstrap: true
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/etc/kubernetes/cert/ca.pem"
authorization:
  mode: Webhook
registryPullQPS: 0
registryBurst: 20
eventRecordQPS: 0
eventBurst: 20
enableDebuggingHandlers: true
enableContentionProfiling: true
healthzPort: 10248
healthzBindAddress: "##NODE_IP##"
clusterDomain: "${CLUSTER_DNS_DOMAIN}"
clusterDNS:
  - "${CLUSTER_DNS_SVC_IP}"
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 1m
imageMinimumGCAge: 2m
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
volumeStatsAggPeriod: 1m
kubeletCgroups: ""
systemCgroups: ""
cgroupRoot: ""
cgroupsPerQOS: true
cgroupDriver: cgroupfs
runtimeRequestTimeout: 10m
hairpinMode: promiscuous-bridge
maxPods: 220
podCIDR: "${CLUSTER_CIDR}"
podPidsLimit: -1
resolvConf: /etc/resolv.conf
maxOpenFiles: 1000000
kubeAPIQPS: 1000
kubeAPIBurst: 2000
serializeImagePulls: false
evictionHard:
  memory.available:  "100Mi"
  nodefs.available:  "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft: {}
enableControllerAttachDetach: true
failSwapOn: true
containerLogMaxSize: 20Mi
containerLogMaxFiles: 10
systemReserved: {}
kubeReserved: {}
systemReservedCgroup: ""
kubeReservedCgroup: ""
enforceNodeAllocatable: ["pods"]
EOF
```

- `address`：kubelet 安全端口（https，10250）监听的地址，不能为 127.0.0.1，否则 kube-apiserver、heapster 等不能调用 kubelet 的 API；
- `readOnlyPort=0`：关闭只读端口(**默认 10255**)，等效为未指定；
- `authentication.anonymous.enabled`：设置为 false，不允许匿名访问 10250 端口；
- `authentication.x509.clientCAFile`：指定签名客户端证书的 CA 证书，开启 HTTP 证书认证；
- `authentication.webhook.enabled=true`：开启 HTTPs bearer token 认证；
- 对于未通过 x509 证书和 webhook 认证的请求(kube-apiserver 或其他客户端)，将被拒绝，提示 `Unauthorized`；
- `authroization.mode=Webhook`：kubelet 使用 SubjectAccessReview API 查询 kube-apiserver 某 user、group 是否具有操作资源的权限(RBAC)；
- `featureGates.RotateKubeletClientCertificate`、`featureGates.RotateKubeletServerCertificate`：自动 rotate 证书，证书的有效期取决于 kube-controller-manager 的 `--experimental-cluster-signing-duration` 参数，该参数1.25版本之后已经删除，替换标志为`--cluster-signing-duration`；
- 需要 **root** 账户运行；

### 3.2：为各节点创建和分发 kubelet 配置文件
```shell
]# for node_ip in ${NODE_IPS[@]}
  do 
    echo ">>> ${node_ip}"
    sed -e "s/##NODE_IP##/${node_ip}/" kubelet-config.yaml.template > kubelet-config-${node_ip}.yaml.template
    scp kubelet-config-${node_ip}.yaml.template root@${node_ip}:/etc/kubernetes/kubelet-config.yaml
  done
```

## 4、创建和分发 kubelet systemd unit 文件
### 4.1：创建 kubelet systemd unit 文件模板
```shell
]# cat > kubelet.service.template <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
WorkingDirectory=${K8S_DIR}/kubelet
ExecStart=/opt/k8s/bin/kubelet \\
  --bootstrap-kubeconfig=/etc/kubernetes/kubelet-bootstrap.kubeconfig \\
  --cert-dir=/etc/kubernetes/cert \\
  --container-runtime-endpoint=unix:///run/containerd/containerd.sock \\
  --root-dir=${K8S_DIR}/kubelet \\
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\
  --config=/etc/kubernetes/kubelet-config.yaml \\
  --hostname-override=##NODE_NAME## \\
  --authentication-token-webhook=true \\
  --authorization-mode=Webhook \\
  --cgroup-driver=systemd \\
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF
```
### 4.2：为各节点创建和分发 kubelet systemd unit 文件
```shell
]# for node_name in ${NODE_NAMES[@]}
  do 
    echo ">>> ${node_name}"
    sed -e "s/##NODE_NAME##/${node_name}/" kubelet.service.template > kubelet-${node_name}.service
    scp kubelet-${node_name}.service root@${node_name}:/etc/systemd/system/kubelet.service
  done
```
## 5、授予 kube-apiserver 访问 kubelet API 的权限
- 在执行 kubectl exec、run、logs 等命令时，apiserver 会将请求转发到 kubelet 的 https 端口。这里定义 RBAC 规则，授权 apiserver 使用的证书（kubernetes.pem）用户名（CN：kuberntes-master）访问 kubelet API 的权限
```shell
]# kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes-master
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/aa636424-af31-4859-9aef-787a3c8d2e08" width="800px">

## 6、Bootstrap Token Auth 和授予权限
```shell
]# kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --group=system:bootstrappers
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/a013a046-7b46-423d-b7a1-81df962efe32" width="800px">

## 7、自动 approve CSR 请求，生成 kubelet client 证书
- CSR 被 approve 后，kubelet 向 kube-controller-manager 请求创建 client 证书，kube-controller-manager 中的 csrapproving controller 使用 SubjectAccessReview API 来检查 kubelet 请求（对应的 group 是 system:bootstrappers）是否具有相应的权限。
- 创建三个 ClusterRoleBinding，分别授予 `group system:bootstrappers` 和 `group system:nodes` 进行 approve client、renew client、renew server 证书的权限
```shell
]# cat > csr-crb.yaml <<EOF
 # Approve all CSRs for the group "system:bootstrappers"
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: auto-approve-csrs-for-group
 subjects:
 - kind: Group
   name: system:bootstrappers
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
   apiGroup: rbac.authorization.k8s.io
---
 # To let a node of the group "system:nodes" renew its own credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-client-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
   apiGroup: rbac.authorization.k8s.io
---
# A ClusterRole which instructs the CSR approver to approve a node requesting a
# serving cert matching its client cert.
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: approve-node-server-renewal-csr
rules:
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests/selfnodeserver"]
  verbs: ["create"]
---
 # To let a node of the group "system:nodes" renew its own server credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-server-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: approve-node-server-renewal-csr
   apiGroup: rbac.authorization.k8s.io
EOF

]# kubectl apply -f csr-crb.yaml
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/407dba1a-997e-498e-a359-c16c952647f7" width="800px">

## 8、启动 kubelet 服务
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/"
    ssh root@${node_ip} "/usr/sbin/swapoff -a"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kubelet && systemctl restart kubelet"
  done
```

## 9、查看kubelet情况
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kubelet |grep Active"
  done
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/c599f801-070b-4ef9-93cc-08620ac064bd" width="800px">
- 稍等一会，集群所有节点(Master和Worker)的 CSR 都被自动 approved：
- **Pending** 的 CSR 用于创建 kubelet server 证书

```shell
]# kubectl get csr
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/01016b6a-7127-4633-b8ec-f7692527dcb1" width="800px">

- 所有节点均注册（Ready 状态是预期的，现在查看状态显示为**NotReady** 正常，因为没有部署网络插件，后续安装了网络插件后就好）
```shell
]# kubectl get node
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/6c7877da-74c2-4f48-b2da-2147f73d0de6" width="800px">

## 10、手动 approve server cert csr
基于**安全性考虑**，`CSR approving controllers` 不会自动 approve kubelet server 证书签名请求，需要手动 approve
```shell
]# kubectl get csr | grep Pending | awk '{print $1}' | xargs kubectl certificate approve
```
<img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/841b37ef-efe6-43eb-a720-dd9d296088b7" width="800px">

## 11、bear token 认证和授权
**注意**：在 Kubernetes 1.23 之前，在集群中创建服务帐户会导致 Kubernetes 自动为该服务帐户创建一个带有令牌的 `Secret`。此令牌永不过期，这可能很有用，但也是一个安全问题。从 Kubernetes 1.24 开始，这些 `Secret` 将不再自动创建。
```shell
# 手动创建token
~]# vim kubelet-api-test-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: kubelet-api-test
  annotations:
    kubernetes.io/service-account.name: "kubelet-api-test"
type: kubernetes.io/service-account-token

[root@k8s-master1 ~]# kubectl apply -f kubelet-api-test-secret.yaml
[root@k8s-master1 ~]# SECRET=$(kubectl get secrets | grep kubelet-api-test | awk '{print $1}')
[root@k8s-master1 ~]# TOKEN=$(kubectl describe secret ${SECRET} | grep -E '^token' | awk '{print $2}')
[root@k8s-master1 ~]# echo ${TOKEN}

~]# curl -s --cacert /etc/kubernetes/cert/ca.pem -H "Authorization: Bearer ${TOKEN}" https://192.168.66.65:10250/metrics |head
```
