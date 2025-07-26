## 1. Create kubelet bootstrap kubeconfig File
> **Bootstrapping:** Automatically issues certificates for Node nodes, used by kubelet. Since K8S master nodes are usually fixed, but Node nodes may be added, removed, or recovered, kubelet certificates are bound to hostnames. Manual management is cumbersome, so bootstrapping is recommended.

### 1.1: Generate kubelet-bootstrap configuration for each node
```shell
for node_name in ${NODE_NAMES[@]}
  do
    echo ">>> ${node_name}"
    # Create token
    export BOOTSTRAP_TOKEN=$(kubeadm token create \
      --description kubelet-bootstrap-token \
      --groups system:bootstrappers:${node_name} \
      --kubeconfig ~/.kube/config)
    # Set cluster parameters
    kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/cert/ca.pem \
      --embed-certs=true \
      --server=${KUBE_APISERVER} \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
    # Set client authentication parameters
    kubectl config set-credentials kubelet-bootstrap \
      --token=${BOOTSTRAP_TOKEN} \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
    # Set context parameters
    kubectl config set-context default \
      --cluster=kubernetes \
      --user=kubelet-bootstrap \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
    # Set default context
    kubectl config use-context default --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
  done
```

### 1.2: View kubeadm tokens for each node
- Token validity is 1 day; expired tokens cannot be used for bootstrap kubelet and will be cleaned by kube-controller-manager's tokencleaner
- kube-apiserver receives kubelet bootstrap token, sets user as `system:bootstrap:<Token ID>`, group as `system:bootstrappers`, and binds this group to ClusterRoleBinding
```shell
kubeadm token list --kubeconfig ~/.kube/config
```
### 1.3: View Secrets associated with each token
```shell
kubectl get secrets -n kube-system | grep bootstrap-token
```
