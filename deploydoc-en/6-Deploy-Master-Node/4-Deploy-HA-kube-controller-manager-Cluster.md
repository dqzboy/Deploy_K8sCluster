## Description
> This cluster contains 3 nodes. After startup, a leader node is elected via a competition mechanism, and other nodes are in standby state. If the leader node becomes unavailable, a new leader is elected to ensure service availability.<br>
> For secure communication, x509 certificates and keys are generated first. kube-controller-manager uses this certificate for:
1. Secure communication with kube-apiserver
2. Outputting prometheus metrics on the secure port (https, 10257)

## 1. Create kube-controller-manager Certificate and Key
### 1.1: Create Certificate Signing Request
```shell
cd /opt/k8s/work
cat > kube-controller-manager-csr.json <<EOF
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
- hosts list includes all kube-controller-manager node IPs
- CN and O are both `system:kube-controller-manager`, which is required for Kubernetes built-in ClusterRoleBindings

### 1.2: Generate Certificate and Key
```shell
cfssl gencert -ca=/etc/kubernetes/cert/ca.pem \
  -ca-key=/etc/kubernetes/cert/ca-key.pem \
  -config=/etc/kubernetes/cert/ca-config.json \
  -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
ls kube-controller-manager*pem
kube-controller-manager-key.pem  kube-controller-manager.pem
```
### 1.3: Distribute the generated certificate and key to all master nodes
```shell
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-controller-manager*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```
