## 1. Role Assignment
| Role | IP | Components | Installation Method | OS Version |
| :----: | :----: | :---: | :---: | :---: |
| K8s-master1 | 192.168.66.62 | kube-apiserver <br> kube-controller-manager<br>kube-scheduler<br>etcd<br>calico<br>kubelet<br>kube-proxy<br>containerd | Binary Installation | CentOS 7.6 |
| K8s-master2 | 192.168.66.63 | kube-apiserver <br> kube-controller-manager<br>kube-scheduler<br>etcd<br>calico<br>kubelet<br>kube-proxy<br>containerd | Binary Installation | CentOS 7.6 |
| K8s-master3 | 192.168.66.64 | kube-apiserver <br> kube-controller-manager<br>kube-scheduler<br>etcd<br>calico<br>kubelet<br>kube-proxy<br>containerd | Binary Installation | CentOS 7.6 |
| K8s-worker1 | 192.168.66.65 | calico<br>kubelet<br>kube-proxy<br>containerd  | Binary Installation | CentOS 7.6 |
| K8s-worker2 | 192.168.66.66 | calico<br>kubelet<br>kube-proxy<br>containerd  | Binary Installation | CentOS 7.6 |
| K8s-worker3 | 192.168.66.67 | calico<br>kubelet<br>kube-proxy<br>containerd  | Binary Installation | CentOS 7.6 |

## 2. Configuration Planning
| Environment | Role | CPU | Memory | Disk |
| :----: | :----: | :---: | :---: | :---: |
| Production | Master| 8C | 16G | 100G |
| ---    | Worker | 16C | 32 G | 500G |

## 3. Required Packages
### (1) K8S Binary Packages
- Project address: https://github.com/kubernetes/kubernetes

### (2) ETCD Binary Packages
- Project address: https://github.com/etcd-io/etcd/releases

### (3) containerd Related Packages
- [cri-tools](https://github.com/kubernetes-sigs/cri-tools/releases/)
- [runc](https://github.com/opencontainers/runc/releases/)
- [cni-plugins](https://github.com/containernetworking/plugins/releases/)
- [containerd](https://github.com/containerd/containerd/releases/)
