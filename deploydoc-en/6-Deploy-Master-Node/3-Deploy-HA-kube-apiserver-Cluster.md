## 3.1: Create kubernetes-master Certificate and Key
```shell
cd /opt/k8s/work/
cat > kubernetes-csr.json <<EOF
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
- Generate certificate and key
```shell
cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
ls kubernetes*pem
kubernetes-key.pem  kubernetes.pem
```
- Copy the generated certificate and key files to all Master nodes
```shell
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kubernetes*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```
