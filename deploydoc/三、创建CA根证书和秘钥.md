> 为确保安全，kubernetes系统各组件需要使用x509证书对通信进行加密和认证。<br>
> CA (Certificate Authority) 是自签名的根证书，用来签名后续创建的其它证书。
CA 证书是集群所有节点共享的，只需要创建一次，后续用它签名其它所有证书。<br>
本文档使用 CloudFlare的 PKI 工具集cfssl创建所有证书。

## 1、安装cfssl工具集
- **注意：** 所有命令和文件在`k8s-master1`上在执行，然后将文件分发给其他节点
- 项目地址：https://github.com/cloudflare/cfssl

```shell
[root@k8s-master1 ~]# cd /opt/k8s

# 定义cfssl版本号
[root@k8s-master1 k8s]# export cfsslVer=1.6.3

# https://ghproxy.com/ 国内免费GitHub代理地址
[root@k8s-master1 k8s]# wget https://ghproxy.com/https://github.com/cloudflare/cfssl/releases/download/v${cfsslVer}/cfssl_${cfsslVer}_linux_amd64
[root@k8s-master1 k8s]# mv cfssl_${cfsslVer}_linux_amd64 /opt/k8s/bin/cfssl

[root@k8s-master1 k8s]# wget https://ghproxy.com/https://github.com/cloudflare/cfssl/releases/download/v${cfsslVer}/cfssljson_${cfsslVer}_linux_amd64
[root@k8s-master1 k8s]# mv cfssljson_${cfsslVer}_linux_amd64 /opt/k8s/bin/cfssljson

[root@k8s-master1 k8s]# wget https://ghproxy.com/https://github.com/cloudflare/cfssl/releases/download/v${cfsslVer}/cfssl-certinfo_${cfsslVer}_linux_amd64 
[root@k8s-master1 k8s]# mv cfssl-certinfo_${cfsslVer}_linux_amd64 /opt/k8s/bin/cfssl-certinfo

[root@k8s-master1 k8s]# chmod +x /opt/k8s/bin/*
[root@k8s-master1 k8s]# export PATH=/opt/k8s/bin:$PATH
```

## 2、创建根证书(CA)
### 2.1：创建配置文件
```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# mkdir -p ca && cd ca
[root@k8s-master1 ca]# cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      }
    }
  }
}
EOF
```
- `signing`：表示该证书可用于签名其它证书（生成的 ca.pem 证书中 CA=TRUE）；
- `server auth`：表示 client 可以用该该证书对 server 提供的证书进行验证；
- `client auth`：表示 server 可以用该该证书对 client 提供的证书进行验证；
- `"expiry": "876000h"`：证书有效期设置为 100 年；


### 2.2：创建证书签名请求文件
- CSR：证书签名请求文件，配置了一些域名、公司、单位、组织信息
```shell
[root@k8s-master1 ca]# cat > ca-csr.json <<EOF
{
  "CN": "kubernetes-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Beijing",
      "L": "Beijing",
      "O": "k8s",
      "OU": "dqz"
    }
  ],
  "ca": {
    "expiry": "876000h"
 }
}
EOF
```

### 2.3：生成CA证书和私钥
- CA证书用来颁发客户端证书的
```shell
[root@k8s-master1 ca]# cfssl gencert -initca ca-csr.json | cfssljson -bare ca

[root@k8s-master1 ca]# ls ca*
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```

## 3、分发证书文件
- 将生成的 CA 证书、秘钥文件、配置文件拷贝到所有节点(master和worker节点)的 `/etc/kubernetes/cert` 目录下
```shell
[root@k8s-master1 ca]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/kubernetes/cert"
    scp ca*.pem ca-config.json root@${node_ip}:/etc/kubernetes/cert
  done
  
[root@k8s-master1 ca]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "ls -lt /etc/kubernetes/cert"
  done
```
<table>
    <tr>
        <td width="50%" align="center"><img src="https://user-images.githubusercontent.com/42825450/224258390-ccd4ec66-0a47-48c2-9bf3-ed808510ad49.png"></td>
    </tr>
</table>




