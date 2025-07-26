## 2.1: High Availability Solution for kube-apiserver Based on nginx Proxy
- The kube-controller-manager and kube-scheduler on control nodes are deployed in multi-instance mode and connect to the local kube-apiserver. As long as one instance is healthy, high availability is ensured.
- Pods in the cluster use the K8S service domain name `kubernetes` to access kube-apiserver; kube-dns automatically resolves multiple kube-apiserver node IPs, also providing high availability.
- Start an nginx process on each node, proxying multiple apiserver instances, with health checks and load balancing.
- kubelet, kube-proxy, controller-manager, scheduler access kube-apiserver via local nginx (listening on 127.0.0.1), achieving high availability.

## 2.2: Download and Compile nginx
- Official nginx download: https://nginx.org/download/nginx-1.21.0.tar.gz
- Huawei Cloud mirror: https://mirrors.huaweicloud.com/nginx/

```shell
cd /opt/k8s/work
export nginxVer=1.23.2
wget https://mirrors.huaweicloud.com/nginx/nginx-${nginxVer}.tar.gz
tar -zxvf nginx-${nginxVer}.tar.gz
mv nginx-${nginxVer} nginx && cd nginx
mkdir nginx-prefix
./configure --with-stream --without-http --prefix=$(pwd)/nginx-prefix --without-http_uwsgi_module --without-http_scgi_module --without-http_fastcgi_module
make && make install
```
- `--with-stream`: Enables Layer 4 transparent TCP proxy
- `--without-xxx`: Disables all other features for minimal dependencies

## 2.3: Verify Compiled Nginx
```shell
/opt/k8s/work/nginx/nginx-prefix/sbin/nginx -v
nginx version: nginx/1.23.1
```

## 2.4: Deploy nginx on Cluster Nodes
### 2.4.1: Create Directories on Cluster Nodes
```shell
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
  done
```
### 2.4.2: Copy Binary Files
- Rename the binary file to `kube-nginx` according to your compiled nginx installation path
