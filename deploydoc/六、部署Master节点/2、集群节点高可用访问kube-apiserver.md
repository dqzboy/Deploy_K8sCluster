## 2.1：基于 nginx 代理的 kube-apiserver 高可用方案
-	控制节点的 kube-controller-manager、kube-scheduler 是多实例部署且连接本机的 kube-apiserver，所以只要有一个实例正常，就可以保证高可用；
-	集群内的 Pod 使用 K8S 服务域名 kubernetes 访问 kube-apiserver；kube-dns 会自动解析出多个 kube-apiserver 节点的 IP，所以也是高可用的；
-	在每个节点起一个 nginx 进程，后端对接多个 apiserver 实例，nginx 对它们做健康检查和负载均衡；
-	kubelet、kube-proxy、controller-manager、scheduler 通过本地的 nginx（监听 127.0.0.1）访问 kube-apiserver，从而实现 kube-apiserver 的高可用；
## 2.2：下载和编译 nginx
-	官网nginx下载地址：https://nginx.org/download/nginx-1.21.0.tar.gz
-	国内华为Nginx地址：https://mirrors.huaweicloud.com/nginx/

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work

# 定义nginx版本号
[root@k8s-master1 work]# export nginxVer=1.23.2
[root@k8s-master1 work]# wget https://mirrors.huaweicloud.com/nginx/nginx-${nginxVer}.tar.gz

[root@k8s-master1 work]# tar -zxvf nginx-${nginxVer}.tar.gz

[root@k8s-master1 work]# mv nginx-${nginxVer} nginx && cd nginx

[root@k8s-master1 nginx]# mkdir nginx-prefix
[root@k8s-master1 nginx]# ./configure --with-stream --without-http --prefix=$(pwd)/nginx-prefix --without-http_uwsgi_module --without-http_scgi_module --without-http_fastcgi_module
```
-	`--with-stream`：开启 4 层透明转发(TCP Proxy)功能；
-	`--without-xxx`：关闭所有其他功能，这样生成的动态链接二进制程序依赖最小；

```shell
#进行编译并安装
[root@k8s-master1 nginx]# make && make install
```

## 2.3：验证编译的Nginx
```shell
[root@k8s-master1 nginx]# /opt/k8s/work/nginx/nginx-prefix/sbin/nginx -v
nginx version: nginx/1.23.1

```

## 2.4：集群节点部署 nginx
### 2.4.1：集群节点创建目录
```shell
[root@k8s-master1 nginx]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
  done
```
### 2.4.2：拷贝二进制程序
**注意：** 根据自己配置的nginx编译安装的路径进行填写下面的路径
- 重命名二进制文件为 `kube-nginx`
```shell
[root@k8s-master1 nginx]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
    scp /opt/k8s/work/nginx/nginx-prefix/sbin/nginx  root@${node_ip}:/opt/k8s/kube-nginx/sbin/kube-nginx
    ssh root@${node_ip} "chmod a+x /opt/k8s/kube-nginx/sbin/*"
  done
```

### 2.4.3: 配置 nginx，开启 4 层透明转发功能
**注意：** upstream backend中的 server 列表为集群中各 kube-apiserver 的节点 IP，需要根据实际情况修改；注意这里提前定义了代理的kube-apiserver的IP地址，后面在部署kube-apiserver时必须是下面upstream中代理的IP地址。

```shell
# 定义ApiServer访问地址
[root@k8s-master1 nginx]# export master01=192.168.66.62
[root@k8s-master1 nginx]# export master02=192.168.66.63
[root@k8s-master1 nginx]# export master03=192.168.66.64

[root@k8s-master1 nginx]# cat > kube-nginx.conf <<EOF
worker_processes  auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 65535;

events {
use epoll;
worker_connections 65535;
accept_mutex on;
multi_accept on;
}

stream {
    upstream backend {
        hash $remote_addr consistent;
        server ${master01}:6443        max_fails=3 fail_timeout=30s;
        server ${master02}:6443        max_fails=3 fail_timeout=30s;
        server ${master03}:6443        max_fails=3 fail_timeout=30s;
    }

    server {
        listen 127.0.0.1:8443;
        proxy_connect_timeout 1s;
        proxy_pass backend;
    }
}
EOF
```

**注意：** 需要根据集群 kube-apiserver 的实际情况，替换 backend 中 server 列表; `127.0.0.1:8443` 此端口为负载+反代apiserver的监听端口

### 2.4.4：分发配置文件
```shell
[root@k8s-master1 nginx]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-nginx.conf  root@${node_ip}:/opt/k8s/kube-nginx/conf/kube-nginx.conf
  done
```

## 2.5：配置 systemd unit 文件，启动服务
### 2.5.1：配置 kube-nginx systemd unit 文件
```shell
[root@k8s-master1 ~]# cd /opt/k8s/work/service-template/

[root@k8s-master1 service-template]# mkdir -p nginx && cd nginx
[root@k8s-master1 nginx]# cat > kube-nginx.service <<EOF
[Unit]
Description=kube-apiserver nginx proxy
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStartPre=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -t
ExecStart=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx
ExecReload=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -s reload
PrivateTmp=true
Restart=always
RestartSec=5
StartLimitInterval=0
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 2.5.2：分发 systemd unit 文件到集群所有节点
```shell
[root@k8s-master1 nginx]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-nginx.service  root@${node_ip}:/etc/systemd/system/
  done

```
### 2.5.3：启动 kube-nginx 服务
```shell
[root@k8s-master1 nginx]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-nginx && systemctl restart kube-nginx"
  done
```

## 2.6：检查 kube-nginx 服务运行状态
```shell
[root@k8s-master1 nginx]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-nginx |grep 'Active:'"
  done
```
