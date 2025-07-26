## 1. Components Running on Kubernetes Worker Node
- kubelet
- kube-proxy
- Container runtime: docker or containerd

## 2. Node Deployment Description
> **Note:** In this document, master nodes also act as worker nodes, so related components are deployed on master nodes as well.
#### If master is not used as a worker node:
- (1) Change the variable `NODE_IPS` to `WORK_IPS` when deploying components.
- (2) After cluster deployment, add taints to master nodes to prevent pods from being scheduled on them.

> **Recommendation:** Use the second method for tainting master nodes.
