## 1.1: Components Running on Kubernetes Master Node
- kube-apiserver
- kube-scheduler
- kube-controller-manager
> kube-apiserver, kube-scheduler, and kube-controller-manager all run in multi-instance mode:
- kube-scheduler and kube-controller-manager automatically elect a leader instance, others are in standby mode. If the leader fails, a new leader is elected to ensure service availability.
- kube-apiserver is stateless and can be accessed via kube-nginx proxy for high availability.

**Note:** If the three Master nodes are only used for cluster management, there is no need to deploy containerd, kubelet, kube-proxy. However, if you plan to deploy metrics-server or istio later, you need to deploy containerd, kubelet, kube-proxy on master nodes.

## 1.2: Download and Extract Program Packages
- Upload the k8s-server archive to `/opt/k8s/work` and extract:
```shell
cd /opt/k8s/work/k8s
tar -zxvf kubernetes-server-linux-amd64.tar.gz
tar -zxvf kubernetes/kubernetes-src.tar.gz
```

## 1.3: Distribute Binary Files
- (1) Copy the extracted binaries to all K8S-Master nodes
- (2) Distribute kubelet and kube-proxy to all worker nodes, store in /opt/k8s/bin
```shell
# Copy all binaries under kubernetes to Master nodes
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kubernetes/server/bin/{apiextensions-apiserver,kube-apiserver,kube-controller-manager,kube-proxy,kube-scheduler,kubeadm,kubectl,kubelet,mounter} root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done

# Copy kubelet and kube-proxy to all worker nodes
for node_ip in ${WORK_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kubernetes/server/bin/{kube-proxy,kubelet} root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```
