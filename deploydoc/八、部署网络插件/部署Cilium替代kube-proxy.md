## 一、Cilium介绍
Cilium 是一款开源软件，也是 CNCF 的孵化项目。Cilium 为基于 Kubernetes 的 Linux 容器管理平台上部署的服务，透明地提供服务间的网络和 API 连接及安全。<br>
Cilium 的基础是一种名为 eBPF 的新 Linux 内核技术，它支持在 Linux 本身内动态插入强大的安全可见性和控制逻辑。由于 eBPF 在 Linux 内核中运行，因此可以应用和更新 Cilium 安全策略，而无需对应用程序代码或容器配置进行任何更改。

## 二、组件概况
Cilium的部署包括以下组件，运行在容器集群中的每个Linux容器节点上：
- **Cilium Agent (Daemon)**: 用户空间守护程序，通过插件与容器运行时和编排系统（如Kubernetes）交互，以便为在本地服务器上运行的容器设置网络和安全性。提供用于配置网络安全策略，提取网络可见性数据等的API。
- **Cilium CLI Client**: 用于与本地Cilium Agent通信的简单CLI客户端，例如，用于配置网络安全性或可见性策略。
- **Linux Kernel BPF**: 集成Linux内核的功能，用于接受内核中在各种钩子/跟踪点运行的已编译字节码。Cilium编译`BPF`程序，并让内核在网络堆栈的关键点运行它们，以便可以查看和控制进出所有容器中的所有网络流量。
- **容器平台网络插件**: 每个容器平台（例如，Docker，Kubernetes）都有自己的插件模型，用于外部网络平台集成。对于Docker，每个Linux节点都运行一个进程`（cilium-docker）`来处理每个`Docker libnetwork`调用，并将数据/请求传递给主要的Cilium Agent。

## 三、Cilium部署
### 1、部署Cilium环境要求
#### K8s版本
- 新的 Kubernetes 版本提供的向后兼容性。
> 1.16、1.17、1.18、1.19、1.20、1.21、1.22、1.23、1.24、1.25(目前我使用的版本)

#### 内核版本
- Cilium 利用和构建内核 eBPF 功能以及与 eBPF 集成的各种子系统。因此，主机系统需要运行 Linux 内核版本`4.9.17`或更高版本才能运行 Cilium 代理。
- 如果要使用`eBPF Host-Routing`，那么确保linux 内核版本 `Kernel >= 5.10`，不然无法启用 `eBPF Host-Routing`
- 为了正确启用 eBPF 功能，必须启用以下内核配置选项。

```shell
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_BPF=y
CONFIG_BPF_JIT=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y
CONFIG_CRYPTO_SHA1=y
CONFIG_CRYPTO_USER_API_HASH=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_BPF=y
 
# 通过以下命令检查当前使用的内核配置
egrep "^CONFIG_BPF=|^CONFIG_BPF_SYSCALL=|^CONFIG_NET_CLS_BPF=|^CONFIG_BPF_JIT=|^CONFIG_NET_CLS_ACT=|^CONFIG_NET_SCH_INGRESS=|^CONFIG_CRYPTO_SHA1=|^CONFIG_CRYPTO_USER_API_HASH=|^CONFIG_CGROUPS=|^CONFIG_CGROUP_BPF=" /boot/config-<Your kernel version>
```

#### systemd cgroup
- 确认自己系统当前使用的cgroup版本，如果当前使用的系统发行版使用的是Cgroup v2，那么你使用的容器运行时跟kubelet也必须配置使用Cgroup v2版本。相关配置K8s官方文档都有教程步骤，可自行根据自己的系统版本进行替换修改！
```shell
# stat -fc %T /sys/fs/cgroup/
 
对于 cgroup v2，输出为 cgroup2fs
对于 cgroup v1，输出为 tmpfs
```

#### 挂载 eBPF文件系统
一些发行版会自动挂载 bpf 文件系统。通过运行命令检查是否安装了 bpf 文件系统。
```shell
~]# mount | grep /sys/fs/bpf
/sys/fs/bpf on /sys/fs/bpf type bpf (rw,relatime)
 
# 如果没有挂载，请执行下面的命令手动挂载
mount bpffs /sys/fs/bpf -t bpf
echo 'bpffs      /sys/fs/bpf           bpf     defaults 0 0' >> /etc/fstab
```

### 2、停用kube-proxy
- **注意**：停用kube-proxy，现有的服务连接会断开，以及与服务相关的流量，直到 Cilium 部署运行正常之后，服务流量才可恢复正常。所以该操作请确保在不影响业务的情况下执行；或者将该步骤放到Cilium部署完成之后再执行也是可以的。
```shell
# 二进制部署的kube-proxy 执行下面的命令
systemctl disable kube-proxy && systemctl stop kube-proxy && systemctl status kube-proxy | grep Active
 
# kube-proxy以Pod方式运行(kubeadm)安装的方式
kubectl -n kube-system delete ds kube-proxy
kubectl -n kube-system delete cm kube-proxy

# 删除 kube-proxy在每台节点生成的 iptables 配置
iptables-save | grep -v KUBE | iptables-restore
```

### 3、安装部署Cilium CLI
```shell
# 下载Cilium CLI工具
[root@k8s-master1 ~]# curl -LO https://ghproxy.com/https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
 
# 将可执行文件解压
[root@k8s-master1 ~]# tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
```

### 4、安装部署Cilium
```shell
[root@k8s-master1 ~]# helm repo add cilium https://helm.cilium.io/
[root@k8s-master1 ~]# helm search repo cilium
[root@k8s-master1 ~]# helm pull cilium/cilium
[root@k8s-master1 ~]# tar -xf cilium-1.12.3.tgz -C /opt/k8s/work/
 
# 自定义部署参数
[root@k8s-master1 ~]# cd /opt/k8s/work/cilium/
[root@k8s-master1 cilium]# cp values.yaml{,_bak}
[root@k8s-master1 cilium]# vim values.yaml
k8sServiceHost: xx.xx.xx.xx   # 指定API Server的IP，在禁用kube-proxy的情况下需显式指定
k8sServicePort: 6443            # 指定API Server的端口，在禁用kube-proxy的情况下需显式指定
clusterPoolIPv4PodCIDR: "10.68.0.0/16"    # 与kube-controller-manager配置文件中的--cluster-cidr参数配置保持一致
kubeProxyReplacement: "strict"   #配置kubeProxyReplacement模式，strict表示完全取代kube-proxy


[root@k8s-master1 cilium]# helm install cilium -f values.yaml . --namespace kube-system --set hubble.relay.enabled=true --set hubble.ui.enabled=true

# 检查Cilium Pod资源创建状态
[root@k8s-master1 cilium]# kubectl get po -n kube-system
```
### 5、查看集群状态
```shell
[root@k8s-master1 ~]# cilium status --wait
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/93e23713-3a10-463c-9a2c-4a7f1918af51)

### 6、确认是否取代kube-proxy
```shell
[root@k8s-master1 cilium]# kubectl exec -it -n kube-system ds/cilium -- cilium status | grep KubeProxyReplacement
```
![image](https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/31442ff8-aa85-49d8-9b87-cf57a26edc82)

### 推荐
> 更多学习教程请关注 [浅时光博客](https://www.dqzboy.com/) www.dqzboy.com
