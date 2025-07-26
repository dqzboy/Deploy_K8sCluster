## 1. Download and Distribute docker Binary Files
### 1.1: Download Program Packages
```shell
cd /opt/k8s/work/
wget https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz
tar -xzvf docker-20.10.9.tgz
```
### 1.2: Distribute Program Packages
```shell
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp docker/*  root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```

## 2. Create and Distribute systemd unit File
### 2.1: Create systemd unit File
```shell
cat > docker.service <<"EOF"
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
 
[Service]
WorkingDirectory=##DOCKER_DIR##
Environment="PATH=/opt/k8s/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=/opt/k8s/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
 
[Install]
WantedBy=multi-user.target
EOF
```
> Since Docker 1.13, the default iptables FORWARD chain policy may be set to DROP, causing pod IP ping failures between nodes. If this occurs, manually set the policy to `ACCEPT`.

```shell
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "iptables -P FORWARD ACCEPT"
  done
```
