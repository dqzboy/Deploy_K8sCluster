## 1、下载和修改配置文件
```shell
]# wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.1.0/aio/deploy/recommended.yaml
]# mv recommended.yaml dashboard-recommended.yaml
```

## 2、执行所有定义文件
```shell
]# kubectl apply -f  dashboard-recommended.yaml
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/57e3cc16-3ac2-48f6-88c9-d47d462db1df)

## 3、查看运行状态
```shell
]# kubectl get pods -n kubernetes-dashboard
NAME                                         READY   STATUS    RESTARTS   AGE
dashboard-metrics-scraper-6b4884c9d5-wsz5l   1/1     Running   0          16m
kubernetes-dashboard-7f99b75bf4-kbp7z        1/1     Running   0          16m
```
## 4、访问Dashboard
### 4.1：暴露服务
> 从 1.7 开始，dashboard 只允许通过 https 访问，如果使用 kube proxy 则必须监听 localhost 或 127.0.0.1。对于 NodePort 没有这个限制，但是仅建议在开发环境中使用。对于不满足这些条件的登录访问，在登录成功后浏览器不跳转，始终停在登录界面。
```shell
]# kubectl port-forward -n kubernetes-dashboard  svc/kubernetes-dashboard 4443:443 --address 0.0.0.0
```
- 浏览器访问 URL：https://192.168.66.62:4443

![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/7d0a0e7c-c43b-47d6-baed-9489df5e8baf)

### 4.2：创建登录 token
```shell
~]# kubectl create sa dashboard-admin -n kube-system
~]# kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
~]# ADMIN_SECRET=$(kubectl get secrets -n kube-system | grep dashboard-admin | awk '{print $1}')
~]# DASHBOARD_LOGIN_TOKEN=$(kubectl describe secret -n kube-system ${ADMIN_SECRET} | grep -E '^token' | awk '{print $2}')
~]# echo ${DASHBOARD_LOGIN_TOKEN}
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/3d0424cc-6718-4c2b-9a69-ca852714b9e7)
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/5c9a2f45-b29b-4918-b0a9-fff92cfdf85f)

### 4.3：创建使用 token 的 KubeConfig 文件
```shell
# 设置集群参数
~]# kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/cert/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=dashboard.kubeconfig
 
# 设置客户端认证参数，使用上面创建的 Token
~]# kubectl config set-credentials dashboard_user \
  --token=${DASHBOARD_LOGIN_TOKEN} \
  --kubeconfig=dashboard.kubeconfig
 
# 设置上下文参数
~]# kubectl config set-context default \
  --cluster=kubernetes \
  --user=dashboard_user \
  --kubeconfig=dashboard.kubeconfig
 
# 设置默认上下文
~]# kubectl config use-context default --kubeconfig=dashboard.kubeconfig
```
- 用生成的 dashboard.kubeconfig 登录 Dashboard

![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/3fa0e886-ef5b-4d21-9141-41ffcefb5bb4)
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/e872c6a2-05c8-43a4-8e23-ea6bdda3aaec)

