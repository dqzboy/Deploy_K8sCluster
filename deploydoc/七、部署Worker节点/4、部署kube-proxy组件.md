## 1、创建 kube-proxy 证书
### 1.1：创建证书签名请求
```shell
~]# cd /opt/k8s/work
]# cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "ShangHai",
      "L": "ShangHai",
      "O": "k8s",
      "OU": "dqz"
    }
  ]
}
EOF
```
### 1.2：生成证书和私钥
```shell
]# cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy

]# ls kube-proxy*
kube-proxy.csr  kube-proxy-csr.json  kube-proxy-key.pem  kube-proxy.pem
```

## 2、创建和分发 kubeconfig 文件
### 2.1：创建kubeconfig文件
```shell
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/cert/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig
  
kubectl config set-credentials kube-proxy \
  --client-certificate=/opt/k8s/work/kube-proxy/cert/kube-proxy.pem \
  --client-key=/opt/k8s/work/kube-proxy/cert/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```

### 2.2：分发kubeconfig文件
```shell
]# for node_name in ${NODE_NAMES[@]}
  do
    echo ">>> ${node_name}"
    scp kube-proxy.kubeconfig root@${node_name}:/etc/kubernetes/
  done
```

## 3、创建 kube-proxy 配置文件
### 3.1：创建 kube-proxy config 文件模板
```shell
]# cat > kube-proxy-config.yaml.template <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  burst: 200
  kubeconfig: "/etc/kubernetes/kube-proxy.kubeconfig"
  qps: 100
bindAddress: ##NODE_IP##
healthzBindAddress: ##NODE_IP##:10256
metricsBindAddress: ##NODE_IP##:10249
enableProfiling: true
clusterCIDR: ${CLUSTER_CIDR}
hostnameOverride: ##NODE_NAME##
mode: "ipvs"
portRange: ""
iptables:
  masqueradeAll: false
ipvs:
  scheduler: rr
  excludeCIDRs: []
EOF
```
- `clientConnection`: 字段给出代理服务器与 API 服务器通信时要使用的 kubeconfig 文件和客户端链接设置
  - `burst` [必需]：burst 字段允许客户端超出其速率限制时可以临时累积的额外查询个数。
  - `kubeconfig` [必需]：kubeconfig 字段是指向一个 KubeConfig 文件的路径。
  - `qps` [必需]：qps 字段控制此连接上每秒钟可以发送的查询请求个数。

### 3.2：为集群所有节点创建和分发 kube-proxy 配置文件
```shell
]# for (( i=0; i < 6; i++ ))
  do 
    echo ">>> ${NODE_NAMES[i]}"
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" -e "s/##NODE_IP##/${NODE_IPS[i]}/" kube-proxy-config.yaml.template > kube-proxy-config-${NODE_NAMES[i]}.yaml.template
    scp kube-proxy-config-${NODE_NAMES[i]}.yaml.template root@${NODE_NAMES[i]}:/etc/kubernetes/kube-proxy-config.yaml
  done
```

## 4、创建和分发 kube-proxy systemd unit 文件
```shell
]# cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=${K8S_DIR}/kube-proxy
ExecStart=/opt/k8s/bin/kube-proxy \\
  --config=/etc/kubernetes/kube-proxy-config.yaml \\
  --logtostderr=true \\
  --v=4
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

]# for node_name in ${NODE_NAMES[@]}
  do 
    echo ">>> ${node_name}"
    scp kube-proxy.service root@${node_name}:/etc/systemd/system/
  done
```

## 5、启动kube-proxy服务
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kube-proxy"
    ssh root@${node_ip} "modprobe ip_vs_rr"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-proxy && systemctl restart kube-proxy"
  done
```

## 6、检查启动结果
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-proxy|grep Active"
  done
```

## 7、查看监听端口
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} " netstat -lnpt|grep kube-prox"
  done
```

## 8、查看 ipvs 路由规则
```shell
]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "/usr/sbin/ipvsadm -ln"
  done

>>> 192.168.66.62
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0         
>>> 192.168.66.63
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0         
>>> 192.168.66.64
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0  
>>> 192.168.66.65
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0         
>>> 192.168.66.66
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0         
>>> 192.168.66.67
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0   
```
