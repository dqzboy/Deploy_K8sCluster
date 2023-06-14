## 1、下载和配置 coredns
```shell
~]# cd /opt/k8s/work
]# git clone https://github.com/coredns/deployment.git
]# mv deployment coredns-deployment
```

## 2、创建CoreDNS
```shell
]# cd coredns-deployment/kubernetes
]# ./deploy.sh -i ${CLUSTER_DNS_SVC_IP} -d ${CLUSTER_DNS_DOMAIN} | kubectl apply -f -
```

## 3、检查CoreDNS功能
```shell
]# kubectl get all -n kube-system -l k8s-app=kube-dns
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/bf1a6f00-156f-42c1-9680-6165090742cf)

## 4、检查Pod之间是否可以解析
### 4.1：创建一个Nginx Pod资源
```shell
]# cat > test-nginx.yaml <<EOF
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: test-nginx
  name: test-nginx
  namespace: k8s-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      k8s-app: test-nginx
  template:
    metadata:
      labels:
        k8s-app: test-nginx
      namespace: k8s-demo
      name: test-nginx
    spec:
      containers:
      - name: test-nginx
        image: nginx
        imagePullPolicy: Always
        ports:
        - containerPort: 80
          name: web
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: test-nginx
  name: test-nginx-svc
  namespace: k8s-demo
spec:
  ports:
  - name: http
    port: 80
    targetPort: 80
  selector:
    k8s-app: test-nginx
EOF


]# kubectl create ns k8s-demo
]# kubectl apply -f test-nginx.yaml
]# kubectl get svc -n k8s-demo test-nginx-svc -o wide
```
### 4.2：创建dns工具测试Pod资源
```shell
]# cat > dnsutils-ds.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: dnsutils-ds
  name: dnsutils-ds
  namespace: k8s-demo
spec:
  type: NodePort
  selector:
    app: dnsutils-ds
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
  name: dnsutils-ds
  namespace: k8s-demo
spec:
  selector:
    matchLabels:
      app: dnsutils-ds
  template:
    metadata:
      labels:
        app: dnsutils-ds
    spec:
      containers:
      - name: my-dnsutils
        image: tutum/dnsutils:latest
        command:
          - sleep
          - "3600"
        ports:
        - containerPort: 80
EOF

#创建Pod资源
]# kubectl apply -f dnsutils-ds.yml
 
#查看Pod资源
]# kubectl get po -n k8s-demo -l app=dnsutils-ds -o wide
```
### 4.3：测试Pod资源的解析情况
```shell
]# kubectl -it exec -n k8s-demo dnsutils-ds-n9vfg -- cat /etc/resolv.conf

#检查Pod内部是否可以解析外部域名
]# kubectl -it exec -n k8s-demo dnsutils-ds-n9vfg -- nslookup www.baidu.com
```
- 查看同一个名称空间下不同的deployments下2个Pod资源是否可以正常解析svc的IP地址
```shell
]# kubectl exec -it -n k8s-demo dnsutils-ds-n9vfg -- nslookup test-nginx-svc
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/460b604a-6657-43dc-9afd-28f49e9dfc78)
