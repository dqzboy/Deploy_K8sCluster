## 1、下载和分发 kubectl 二进制文件

> 将下载好二进制包上传至Master1服务器节点中，然后拷贝至其他节点 <br>
> 这里部署的是k8s 1.25版本  <br>
> 下载地址：https://github.com/kubernetes/kubernetes/releases

- **注意：** 这里我是NODE_IPS这个变量，这个变量中包含了master和worker节点地址
```shell
[root@k8s-master1 k8s]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kubernetes/client/bin/kubectl root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```

## 2、创建admin证书和私钥
> kubectl 使用 https 协议与 kube-apiserver 进行安全通信，kube-apiserver 对 kubectl 请求包含的证书进行认证和授权。<br>
> kubectl 后续用于集群管理，所以这里创建具有最高权限的 admin 证书。

### 2.1：创建证书签名请求
```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# mkdir -p certs && cd certs/

[root@k8s-master1 certs]# mkdir -p admin-cert && cd admin-cert/

[root@k8s-master1 admin-cert]# cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Beijing",
      "L": "Beijing",
      "O": "system:masters",
      "OU": "dqz"
    }
  ]
}
EOF
```
-	O: system:masters：kube-apiserver 收到使用该证书的客户端请求后，为请求添加组（Group）认证标识 system:masters；
-	预定义的 ClusterRoleBinding cluster-admin 将 Group system:masters 与 Role cluster-admin 绑定，该 Role 授予操作集群所需的最高权限；
-	该证书只会被 kubectl 当做 client 证书使用，所以 hosts 字段为空；

### 2.2：生成证书和私钥
```shell
[root@k8s-master1 admin-cert]# cfssl gencert -ca=/etc/kubernetes/cert/ca.pem \
  -ca-key=/etc/kubernetes/cert/ca-key.pem \
  -config=/etc/kubernetes/cert/ca-config.json \
  -profile=kubernetes admin-csr.json | cfssljson -bare admin

[root@k8s-master1 admin-cert]# ls admin*
admin.csr  admin-csr.json  admin-key.pem  admin.pem
```

## 3、创建 kubeconfig 文件
> kubectl 使用 kubeconfig 文件访问 apiserver，该文件包含 kube-apiserver 的地址和认证信息（CA 证书和客户端证书）
- 设置集群参数

```shell
[root@k8s-master1 admin-cert]# kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/cert/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kubectl.kubeconfig
```
- 设置客户端参数
```shell
[root@k8s-master1 admin-cert]# kubectl config set-credentials admin \
  --client-certificate=/opt/k8s/work/certs/admin-cert/admin.pem \
  --client-key=/opt/k8s/work/certs/admin-cert/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=kubectl.kubeconfig 
```
- 设置上下文参数
```shell
[root@k8s-master1 admin-cert]# kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin \
  --kubeconfig=kubectl.kubeconfig 
```
- 设置默认上下文
```shell
[root@k8s-master1 admin-cert]# kubectl config use-context kubernetes --kubeconfig=kubectl.kubeconfig 
```
-	`--certificate-authority`：验证 kube-apiserver 证书的根证书；
-	`--client-certificate`、`--client-key`：刚生成的 admin 证书和私钥，与 kube-apiserver https 通信时使用；
-	`--embed-certs=true`：将 ca.pem 和 admin.pem 证书内容嵌入到生成的 kubectl.kubeconfig 文件中(否则，写入的是证书文件路径，后续拷贝 kubeconfig 到其它机器时，还需要单独拷贝证书文件，不方便。)；
-	`--server`：指定 kube-apiserver 的地址，这里指向本地部署的kube-nginx的服务实现高可用访问kube-apiserver； 

## 4、分发kubeconfig文件
- 分发文件至所有Master和Work节点,并将`kubectl.kubeconfig`更名为`config`
```shell
[root@k8s-master1 admin-cert]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ~/.kube"
    scp kubectl.kubeconfig root@${node_ip}:~/.kube/config
  done 
```

## 5、确认kubectl已经可以使用
- 确保Master节点和Work节点的kubectl命令都可以使用
```shell
[root@k8s-worker2 ~]# kubectl --help
```
<table>
    <tr>
        <td width="50%" align="center"><img src="https://user-images.githubusercontent.com/42825450/225511256-15b9792d-9ea9-467f-9d3b-751b13a8761f.png?raw=true"></td>
    </tr>
</table>

## 6、配置kubectl命令补全
- 所有节点执行
```shell
yum install -y bash-completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

