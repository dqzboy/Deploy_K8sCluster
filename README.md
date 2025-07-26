<p align="right">
   <strong>中文</strong> | <a href="./README_en.md">English</a>
</p>

<div style="text-align: center"></div>
  <p align="center">
  <img src="https://user-images.githubusercontent.com/42825450/225513881-67ffbdf1-dcda-495d-8c19-d0c6fd9eccc9.png" width="250px" height="220px">
      <br>
      <i>二进制高可用Kubernetes集群部署</i>
  </p>
</div>



[![image](https://img.shields.io/badge/CNCF-Kubernetes-blue)](https://kubernetes.io/) 
[![image](https://img.shields.io/badge/容器运行时-containerd-orange)](https://containerd.io/)
[![image](https://img.shields.io/badge/容器运行时-Docker-brightgreen)](https://www.docker.com/) 
[![image](https://img.shields.io/badge/分布式KV存储系统-ETCD-orange)](https://etcd.io/)
[![image](https://img.shields.io/badge/TCL-CFSSL-%2320a0ff)](https://github.com/cloudflare/cfssl)
[![image](https://img.shields.io/badge/网络-Calico-%23f68245)](https://github.com/projectcalico/calico)
> 跟着本文档带你通过原始二进制方式，从0到1部署一套完整的、高可用、生产可用的K8s集群<br>


&nbsp; &nbsp; *[我的博客](https://www.dqzboy.com/)* 
<br />


<div align="center">
 
[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Handlee&center=true&vCenter=true&width=500&height=60&lines=Kubernetes+高可用集群二进制部署)](https://git.io/typing-svg)
 
<img src="https://camo.githubusercontent.com/82291b0fe831bfc6781e07fc5090cbd0a8b912bb8b8d4fec0696c881834f81ac/68747470733a2f2f70726f626f742e6d656469612f394575424971676170492e676966"
width="800"  height="3">
</div>


## 部署说明
本文档基于K8s 1.25版本进行部署和更新整理，如果你部署的是其他K8s版本，请阅读K8s的[版本更新日志](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.25.md)，确保本文档中组件参数在你所部署的版本上可用！<br>

- 关于国内镜像下载问题：
  - 推荐项目：[自建Docker、K8s镜像加速服务](https://github.com/dqzboy/Docker-Proxy)


## 目录

### 第一章：角色分配划分
- [一、角色规划和分配](deploydoc/一、角色规划和分配.md)

### 第二章：系统初始化
- [二、系统初始化](deploydoc/二、系统初始化.md)

### 第三章：CA根证书创建
- [三、创建CA根证书和秘钥](deploydoc/三、创建CA根证书和秘钥.md)

### 第四章：部署ETCD集群
- [四、部署ETCD集群](deploydoc/四、部署ETCD集群.md)

### 第五章：部署kubectl命令行工具
- [五、部署kubectl命令行工具](deploydoc/五、部署kubectl命令行工具.md)

### 第六章：部署Master节点
- [六、部署Master节点](deploydoc/六、部署Master节点)
  - [1、部署环境说明](deploydoc/六、部署Master节点/1、部署环境说明.md)
  - [2、集群节点高可用访问kube-apiserver](deploydoc/六、部署Master节点/2、集群节点高可用访问kube-apiserver.md)
  - [3、部署高可用kube-apiserver集群](deploydoc/六、部署Master节点/3、部署高可用kube-apiserver集群.md)
  - [4、部署高可用kube-controller-manager集群](deploydoc/六、部署Master节点/4、部署高可用kube-controller-manager集群.md)
  - [5、部署高可用kube-scheduler集群](deploydoc/六、部署Master节点/5、部署高可用kube-scheduler集群.md)

### 第七章：部署Worker节点
- [七、部署Worker节点](deploydoc/七、部署Worker节点)
  - [1、部署环境说明](deploydoc/七、部署Worker节点/1、部署环境说明.md)
  - [2、部署containerd](deploydoc/七、部署Worker节点/2、部署containerd.md)
  - [3、部署kubelet组件](deploydoc/七、部署Worker节点/3、部署kubelet组件.md)
  - [4、部署kube-proxy组件](deploydoc/七、部署Worker节点/4、部署kube-proxy组件.md)
  - [部署docker运行时(仅作参考)](deploydoc/七、部署Worker节点/部署docker运行时(仅作参考).md)

### 第八章：部署网络插件
- [八、部署网络插件](deploydoc/八、部署网络插件)
  - [八、部署网络插件](deploydoc/八、部署网络插件/八、部署网络插件.md)
  - [部署Cilium替代kube-proxy](deploydoc/八、部署网络插件/部署Cilium替代kube-proxy.md)

### 第九章：验证集群状态
- [九、验证集群状态](deploydoc/九、验证集群状态)
  - [验证集群状态](deploydoc/九、验证集群状态/验证集群状态.md)

### 第十章：部署集群插件
- [十、部署集群插件](deploydoc/十、部署集群插件)
  - [1、部署Coredns插件](deploydoc/十、部署集群插件/1、部署Coredns插件.md)
  - [2、部署Dashboard插件](deploydoc/十、部署集群插件/2、部署Dashboard插件.md)


## 说明
本项目仅供学习和交流使用，请勿用于商业用途，转载请注明本项目地址。<br>
由于个人水平有限，文中可能存在遗漏或错误，欢迎指正和交流，非常感谢！<br>

## 💌 推广

<table>
  <thead>
    <tr>
      <th width="50%" align="center">描述信息</th>
      <th width="50%" align="center">图文介绍</th>
    </tr>
  </thead>
  <tbody>
    <!-- RackNerd -->
    <tr>
      <td width="50%" align="left">
        <a href="https://dqzboy.github.io/proxyui/racknerd" target="_blank">高性价比海外VPS，支持多种操作系统，适合搭建Docker代理服务。</a>
      </td>
      <td width="50%" align="center">
        <a href="https://dqzboy.github.io/proxyui/racknerd" target="_blank">
          <img src="https://cdn.jsdelivr.net/gh/dqzboy/Images/dqzboy-proxy/Image_2025-07-07_16-14-49.png?raw=true" alt="RackNerd" width="200" height="150">
        </a>
      </td>
    </tr>
    <!-- CloudCone -->
    <tr>
      <td width="50%" align="left">
        <a href="https://dqzboy.github.io/proxyui/CloudCone" target="_blank">CloudCone 提供灵活的云服务器方案，支持按需付费，适合个人和企业用户。</a>
      </td>
      <td width="50%" align="center">
        <a href="https://dqzboy.github.io/proxyui/CloudCone" target="_blank">
          <img src="https://cdn.jsdelivr.net/gh/dqzboy/Images/dqzboy-proxy/111.png?raw=true" alt="CloudCone" width="200" height="150">
        </a>
      </td>
    </tr>
  </tbody>
</table>

##### *Telegram Bot: [点击联系](https://t.me/WiseAidBot) ｜ 邮箱: support@dqzboy.com*
**仅接受长期稳定运营、信誉良好的商家*

## 赞助
如果你觉得这个项目对你有帮助，请给我点个Star。如果条件允许，也欢迎赞助支持，感谢！😊

<table>
    <tr>
      <td width="50%" align="center"><b> 支付宝 </b></td>
      <td width="50%" align="center"><b> 微信 </b></td>
    </tr>
    <tr>
        <td width="50%" align="center">
            <img src="https://cdn.jsdelivr.net/gh/dqzboy/Images@main/picture/alpay.png?raw=true" width="300" />
        </td>
        <td width="50%" align="center">
            <img src="https://cdn.jsdelivr.net/gh/dqzboy/Images@main/picture/WeChatpay.png?raw=true" width="300" />
        </td>
    </tr>
</table>
