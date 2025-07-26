## 1. Check Node Status
```shell
kubectl get nodes
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/0ad3828d-5398-4a36-932c-4ee51b83582f)

## 2. Deploy Pod for Testing
```shell
cd /opt/k8s/work
cat > nginx-test.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: demo-ns
  labels:
    app: nginx
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx
  namespace: demo-ns
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx
        ports:
        - containerPort: 80
EOF

kubectl create ns demo-ns
```
