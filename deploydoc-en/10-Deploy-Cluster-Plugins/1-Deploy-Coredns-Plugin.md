## 1. Download and Configure CoreDNS
```shell
cd /opt/k8s/work
git clone https://github.com/coredns/deployment.git
mv deployment coredns-deployment
```

## 2. Create CoreDNS
```shell
cd coredns-deployment/kubernetes
./deploy.sh -i ${CLUSTER_DNS_SVC_IP} -d ${CLUSTER_DNS_DOMAIN} | kubectl apply -f -
```

## 3. Check CoreDNS Functionality
```shell
kubectl get all -n kube-system -l k8s-app=kube-dns
```

## 4. Check Pod DNS Resolution
### 4.1: Create an Nginx Pod Resource
```shell
cat > test-nginx.yaml <<EOF
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
EOF
```
