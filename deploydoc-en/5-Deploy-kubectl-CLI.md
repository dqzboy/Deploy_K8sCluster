## 1. Download and Distribute kubectl Binary Files
> Download the binary package and upload to Master1, then copy to other nodes <br>
> This deployment uses k8s 1.25 version  <br>
> Download address: https://github.com/kubernetes/kubernetes/releases

- **Note:** Here NODE_IPS is a variable containing master and worker node addresses
```shell
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kubernetes/client/bin/kubectl root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```

## 2. Create admin Certificate and Key
> kubectl uses HTTPS to communicate securely with kube-apiserver, which authenticates and authorizes requests using certificates.<br>
> The admin certificate grants the highest privileges for cluster management.

### 2.1: Create Certificate Signing Request
```shell
cd /opt/k8s/work
mkdir -p certs && cd certs/
mkdir -p admin-cert && cd admin-cert/
cat > admin-csr.json <<EOF
{
  "CN": "admin",
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
      "O": "system:masters",
      "OU": "dqz"
    }
  ]
}
EOF
```
