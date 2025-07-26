## 1. Create kube-scheduler Certificate and Key
### 1.1: Create Certificate Signing Request
```shell
cat > kube-scheduler-csr.json <<EOF
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
- hosts list includes all kube-scheduler node IPs
- CN and O are both `system:kube-scheduler`, required for Kubernetes built-in ClusterRoleBindings

### 1.2: Generate Certificate and Key
```shell
cfssl gencert -ca=/etc/kubernetes/cert/ca.pem \
  -ca-key=/etc/kubernetes/cert/ca-key.pem \
  -config=/etc/kubernetes/cert/ca-config.json \
  -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler
ls kube-scheduler*pem
kube-scheduler-key.pem  kube-scheduler.pem
```
### 1.3: Distribute the generated certificate and key to all master nodes
```shell
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-scheduler*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```
