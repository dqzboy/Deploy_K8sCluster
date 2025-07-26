## 1. Configure Hostname
- Execute on all nodes
```shell
hostnamectl --static set-hostname k8s-master1
hostnamectl --static set-hostname k8s-master2
hostnamectl --static set-hostname k8s-master3
hostnamectl --static set-hostname k8s-worker1
hostnamectl --static set-hostname k8s-worker2
hostnamectl --static set-hostname k8s-worker3
```

## 2. Configure SSH Passwordless Login
- Configure hostname resolution, execute on master1
```shell
cat >> /etc/hosts <<EOF
192.168.66.62 k8s-master1
192.168.66.63 k8s-master2
192.168.66.64 k8s-master3
192.168.66.65 k8s-worker1
192.168.66.66 k8s-worker2
192.168.66.67 k8s-worker3
EOF
```
- Setup SSH key authentication
```shell
ssh-keygen -t rsa
ssh-copy-id root@192.168.66.62
ssh-copy-id root@192.168.66.63
ssh-copy-id root@192.168.66.64
ssh-copy-id root@192.168.66.65
ssh-copy-id root@192.168.66.66
ssh-copy-id root@192.168.66.67
```
- Distribute /etc/hosts to all nodes
```shell
for i in 192.168.66.{62..67}; do echo ">>> $i";scp /etc/hosts root@$i:/etc/; done
```
