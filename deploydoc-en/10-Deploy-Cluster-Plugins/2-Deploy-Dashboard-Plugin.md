## 1. Download and Edit Configuration File
```shell
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.1.0/aio/deploy/recommended.yaml
mv recommended.yaml dashboard-recommended.yaml
```

## 2. Apply All Defined Files
```shell
kubectl apply -f dashboard-recommended.yaml
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/57e3cc16-3ac2-48f6-88c9-d47d462db1df)

## 3. Check Running Status
```shell
kubectl get pods -n kubernetes-dashboard
NAME                                         READY   STATUS    RESTARTS   AGE
dashboard-metrics-scraper-6b4884c9d5-wsz5l   1/1     Running   0          16m
kubernetes-dashboard-7f99b75bf4-kbp7z        1/1     Running   0          16m
```
## 4. Access Dashboard
### 4.1: Expose Service
> Since v1.7, dashboard only allows access via HTTPS. If using kube proxy, it must listen on localhost or 127.0.0.1. NodePort does not have this limitation, but is recommended only for development environments. For login access not meeting these conditions, the browser may not redirect after login and remain on the login page.
```shell
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 4443:443 --address 0.0.0.0
```
- Browser access URL: https://192.168.66.62:4443

![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/7d0a0e7c-c43b-47d6-baed-9489df5e8baf)

### 4.2: Create Login Token
```shell
kubectl create sa dashboard-admin -n kube-system
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
ADMIN_SECRET=$(kubectl get secrets -n kube-system | grep dashboard-admin | awk '{print $1}')
DASHBOARD_LOGIN_TOKEN=$(kubectl describe secret -n kube-system ${ADMIN_SECRET} | grep -E '^token' | awk '{print $2}')
echo ${DASHBOARD_LOGIN_TOKEN}
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/3d0424cc-6718-4c2b-9a69-ca852714b9e7)
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/5c9a2f45-b29b-4918-b0a9-fff92cfdf85f)

### 4.3: Create KubeConfig File Using Token
```shell
# Set cluster parameters
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/cert/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=dashboard.kubeconfig
# Set client authentication parameters using the token above
```
