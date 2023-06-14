<div style="text-align: center"></div>
  <p align="center">
  <img src="https://user-images.githubusercontent.com/42825450/225513881-67ffbdf1-dcda-495d-8c19-d0c6fd9eccc9.png" width="250px" height="220px">
      <br>
      <i>Deploying Highly Available Kubernetes Cluster using Binary Installation.</i>
  </p>
</div>


[![image](https://img.shields.io/badge/CNCF-Kubernetes-blue)](https://kubernetes.io/) 
[![image](https://img.shields.io/badge/%E5%AE%B9%E5%99%A8%E8%BF%90%E8%A1%8C%E6%97%B6-containerd-orange)](https://containerd.io/)
[![image](https://img.shields.io/badge/%E5%AE%B9%E5%99%A8%E8%BF%90%E8%A1%8C%E6%97%B6-Docker-brightgreen)](https://www.docker.com/) 
[![image](https://img.shields.io/badge/%E5%88%86%E5%B8%83%E5%BC%8FKV%E5%AD%98%E5%82%A8%E7%B3%BB%E7%BB%9F-ETCD-orange)](https://etcd.io/)
[![image](https://img.shields.io/badge/TCL-CFSSL-%2320a0ff)](https://github.com/cloudflare/cfssl)
[![image](https://img.shields.io/badge/Network-Calico-%23f68245)](https://github.com/projectcalico/calico)
> 跟着本文档带你通过原始二进制方式，从0到1部署一套完整的、高可用、生产可用的K8s集群<br>
> Follow this document to deploy a complete, highly available, production-ready K8s cluster from scratch using the raw binary approach, from 0 to 1. <br>

&nbsp; &nbsp; *[View My Blog](https://www.dqzboy.com/)*
<br />

<div align="center">
 
[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Handlee&center=true&vCenter=true&width=500&height=60&lines=Deploying+Highly+Available+Kubernetes+Cluster)](https://git.io/typing-svg)
 
<img src="https://camo.githubusercontent.com/82291b0fe831bfc6781e07fc5090cbd0a8b912bb8b8d4fec0696c881834f81ac/68747470733a2f2f70726f626f742e6d656469612f394575424971676170492e676966"
width="800"  height="3">
</div>

## 部署说明
目前本文档是基于K8s 1.25 版本进行部署和更新梳理，如果你部署是其他K8s版本，请阅读K8s的版本更新日志，确保与本文档中组件所使用的参数可以在你所部署的版本之上运行！

## 第一章：角色分配划分
- [一、角色规划和分配 ](deploydoc/一、角色规划和分配.md)


## 第二章：系统初始化
- [二、系统初始化.md ](deploydoc/二、系统初始化.md)


## 第三章：CA根证书创建
- [三、创建CA根证书和秘钥 ](deploydoc/三、创建CA根证书和秘钥.md)


## 第四章：部署ETCD集群
- [四、部署ETCD集群 ](deploydoc/四、部署ETCD集群.md)


## 第五章：部署kubectl命令行工具
- [五、部署kubectl命令行工具 ](deploydoc/五、部署kubectl命令行工具.md)


## 第六章：部署Master节点
- [六、部署Master节点 ](deploydoc/六、部署Master节点)
  - [1、部署环境说明 ](deploydoc/六、部署Master节点/1、部署环境说明.md)
  - [2、集群节点高可用访问kube-apiserver ](deploydoc/六、部署Master节点/2、集群节点高可用访问kube-apiserver.md)
  - [3、部署高可用kube-apiserver集群 ](deploydoc/六、部署Master节点/3、部署高可用kube-apiserver集群.md)
  - [4、部署高可用kube-controller-manager集群 ](deploydoc/六、部署Master节点/4、部署高可用kube-controller-manager集群.md)
  - [5、部署高可用kube-scheduler 集群 ](deploydoc/六、部署Master节点/5、部署高可用kube-scheduler集群.md)

## 第七章：部署Worker节点
- [七、部署Worker节点 ](deploydoc/七、部署Worker节点)
  - [1、部署环境说明 ](deploydoc/七、部署Worker节点/1、部署环境说明.md)
  - [2、部署containerd ](deploydoc/七、部署Worker节点/2、部署containerd.md)
  - [3、部署kubelet组件 ](deploydoc/七、部署Worker节点/3、部署kubelet组件.md)
  - [4、部署kube-proxy组件 ](deploydoc/七、部署Worker节点/4、部署kube-proxy组件.md)
  - [部署docker运行时(仅作参考) ](deploydoc/七、部署Worker节点/部署docker运行时(仅作参考).md)

## 第八章：部署网络插件
- [八、部署网络插件 ](deploydoc/八、部署网络插件)
  -  [部署网络插件 ](deploydoc/八、部署网络插件/八、部署网络插件.md)


## 说明
本专题仅供学习和交流使用，请勿用于商业用途，并在转载时注明本专题地址。<br>
由于本人水平有限，文中可能存在遗漏或错误之处，敬请指正并不吝赐教，感激不尽。<br>

## 赞助
如果你觉得这个项目对你有帮助，请给我点个Star。并且情况允许的话，可以给我一点点支持，总之非常感谢支持😊

<table>
    <tr>
      <td width="50%" align="center"><b> Alipay </b></td>
      <td width="50%" align="center"><b> WeChat Pay </b></td>
    </tr>
    <tr>
        <td width="50%" align="center"><img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/223fd099-9433-468b-b490-f9807bdd2035?raw=true"></td>
        <td width="50%" align="center"><img src="https://github.com/dqzboy/Deploy_K8sCluster/assets/42825450/9404460f-ea1b-446c-a0ae-6da96eb459e3?raw=true"></td>
    </tr>
</table>
