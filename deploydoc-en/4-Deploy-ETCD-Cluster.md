> etcd is a distributed KV storage system based on Raft, commonly used for service discovery, shared configuration, and distributed locking.
Kubernetes uses etcd cluster to persist all API objects and runtime data.
- etcd cluster node names and IPs:

| Hostname  | IP |
| :---: | :---: |
| k8s-master1 | 192.168.66.62 |
| k8s-master2 | 192.168.66.63 |
| k8s-master3 | 192.168.66.64 |

## 1. Download and Distribute etcd Binary Files
- ETCD repository: https://github.com/etcd-io/etcd/releases
- If network issues, download locally and upload to server

```shell
cd /opt/k8s/work/
mkdir -p etcd && cd etcd
export etcdVer=3.5.5
wget https://github.com/etcd-io/etcd/releases/download/v${etcdVer}/etcd-v${etcdVer}-linux-amd64.tar.gz

tar -zxvf etcd-v${etcdVer}-linux-amd64.tar.gz
for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp etcd-v${etcdVer}-linux-amd64/etcd* root@${node_ip}:/opt/k8s/bin
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```
