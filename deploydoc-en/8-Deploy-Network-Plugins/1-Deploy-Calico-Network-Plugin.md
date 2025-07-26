## 1. Introduction to Calico Network Plugin
- Kubernetes requires all nodes (including master nodes) in the cluster to be able to communicate with each other via Pod network segments.
- Calico uses IPIP or BGP technology (default is IPIP) to create an interconnectable Pod network for all nodes.
- Since v3.13, Calico integrates eBPF dataplane (system kernel 5.3+ required).
> Official website: https://www.tigera.io/project-calico/
> Documentation: https://projectcalico.docs.tigera.io/about/about-calico

## 2. Install Calico Network Plugin
```shell
cd /opt/k8s/work
curl https://docs.projectcalico.org/manifests/calico.yaml -O
```
### 2.1: Modify Calico Configuration
```shell
vim calico.yaml
...
typha_service_name: "calico-typha"
# IP automatic detection
- name: IP_AUTODETECTION_METHOD
  value: "interface=ens33"   # Match actual NIC name
- name: CALICO_IPV4POOL_IPIP
  value: "Never"
- name: CALICO_IPV4POOL_CIDR
  value: "10.68.0.0/16"
- name: cni-bin-dir
  hostPath:
    path: /opt/k8s/bin
...
```
- Change Pod network segment to `10.68.0.0/16`; keep consistent with the global variable value in kubelet config `CLUSTER_CIDR`.

### 2.2: Run Calico Plugin
```shell
kubectl apply -f calico.yaml
```
## 3. Check Calico Running Status
```shell
kubectl get pods -n kube-system -o wide
```

## 4. Install calicoctl Tool
```shell
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "cd /opt/k8s/work && curl -L https://github.com/projectcalico/calico/releases/download/v3.24.3/calicoctl-linux-amd64 -o calicoctl && chmod +x calicoctl && mv calicoctl /usr/local/bin"
  done
calicoctl version
```
