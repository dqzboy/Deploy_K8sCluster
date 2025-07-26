## containerd Overview
> containerd implements Kubernetes Container Runtime Interface (CRI), providing core container runtime functions such as image management and container management. Compared to dockerd, it is simpler, more robust, and portable.

## 1. Download and Distribute Binary Files
- Required components download addresses:
  - https://github.com/kubernetes-sigs/cri-tools/releases/
  - https://github.com/opencontainers/runc/releases/
  - https://github.com/containernetworking/plugins/releases/
  - https://github.com/containerd/containerd/releases/

### 1.1: Download Program Packages
```shell
cd /opt/k8s/work/
wget https://github.com/containerd/containerd/releases/download/v1.6.9/containerd-1.6.9-linux-amd64.tar.gz
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.25.0/crictl-v1.25.0-linux-amd64.tar.gz
wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
wget https://github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64

tar -xvf containerd-1.6.9-linux-amd64.tar.gz -C containerd
tar -xvf crictl-v1.25.0-linux-amd64.tar.gz
mkdir cni-plugins
tar -xvf cni-plugins-linux-amd64-v1.1.1.tgz -C cni-plugins
mv runc.amd64 runc
```
### 1.2: Distribute Program Packages
```shell
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp containerd/bin/*  crictl  cni-plugins/* runc root@${node_ip}:/opt/k8s/bin
    ssh root@${node_ip} "chmod a+x /opt/k8s/bin/* && mkdir -p /etc/cni/net.d"
  done
```
## 2. Create and Distribute containerd Configuration Files
### 2.1: Create
> Generate via containerd command, then modify root and state paths to match cni configuration; use **systemd cgroup** driver, set `SystemdCgroup` to `true` in config.

```shell
cat << EOF | sudo tee containerd-config.toml
version = 2
root = "/data/k8s/containerd/root"
state = "/data/k8s/containerd/state"

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "k8s.dockerproxy.com/pause"
    [plugins."io.containerd.grpc.v1.cri".cni]
EOF
```
