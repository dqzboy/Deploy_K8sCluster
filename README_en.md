<p align="right">
   <strong>English</strong> | <a href="./README.md">中文</a>
</p>

<div style="text-align: center"></div>
  <p align="center">
  <img src="https://user-images.githubusercontent.com/42825450/225513881-67ffbdf1-dcda-495d-8c19-d0c6fd9eccc9.png" width="250px" height="220px">
      <br>
      <i>Deploying Highly Available Kubernetes Cluster using Binary Installation.</i>
  </p>
</div>


[![image](https://img.shields.io/badge/CNCF-Kubernetes-blue)](https://kubernetes.io/) 
[![image](https://img.shields.io/badge/Containerd-containerd-orange)](https://containerd.io/)
[![image](https://img.shields.io/badge/Docker-Docker-brightgreen)](https://www.docker.com/) 
[![image](https://img.shields.io/badge/DistributedKV-ETCD-orange)](https://etcd.io/)
[![image](https://img.shields.io/badge/TCL-CFSSL-%2320a0ff)](https://github.com/cloudflare/cfssl)
[![image](https://img.shields.io/badge/Network-Calico-%23f68245)](https://github.com/projectcalico/calico)
> Follow this document to deploy a complete, highly available, production-ready K8s cluster from scratch using the raw binary approach, from 0 to 1. <br>

&nbsp; &nbsp; *[View My Blog](https://www.dqzboy.com/)* 
<br />

<div align="center">
 
[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Handlee&center=true&vCenter=true&width=500&height=60&lines=Deploying+Highly+Available+Kubernetes+Cluster)](https://git.io/typing-svg)
 
<img src="https://camo.githubusercontent.com/82291b0fe831bfc6781e07fc5090cbd0a8b912bb8b8d4fec0696c881834f81ac/68747470733a2f2f70726f626f742e6d656469612f394575424971676170492e676966"
width="800"  height="3">
</div>

## Deployment Instructions
This document is based on the deployment and update process using K8s version 1.25. If you are deploying with a different K8s version, please refer to the [K8s version update log](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.25.md) to ensure that the parameters used by the components in this document can operate on the version you are deploying!

- For image download issues in China:
  - Reference project: [Self-built Docker/K8s image acceleration service](https://github.com/dqzboy/Docker-Proxy)

## Chapter 1: Role Assignment and Division
- [Role Planning and Assignment](deploydoc-en/1-Role-Planning-and-Assignment.md)

## Chapter 2: System Initialization
- [System Initialization](deploydoc-en/2-System-Initialization.md)

## Chapter 3: CA Root Certificate Creation
- [Create CA root certificate and secret key](deploydoc-en/3-Create-CA-Root-Certificate-and-Key.md)

## Chapter 4: Deploying an etcd cluster
- [Deploying an etcd cluster](deploydoc-en/4-Deploy-ETCD-Cluster.md)

## Chapter 5: Deploying the kubectl command-line tool
- [Deploying the kubectl command-line tool](deploydoc-en/5-Deploy-kubectl-CLI.md)

## Chapter 6: Deploying the Master Node
- [Deploying the Master Node](deploydoc-en/6-Deploy-Master-Node)
  - [Deployment environment description](deploydoc-en/6-Deploy-Master-Node/1-Deployment-Environment-Description.md)
  - [Highly available access to the kube-apiserver from resource nodes](deploydoc-en/6-Deploy-Master-Node/2-HA-Access-to-kube-apiserver.md)
  - [Deploy a high-availability kube-apiserver cluster](deploydoc-en/6-Deploy-Master-Node/3-Deploy-HA-kube-apiserver-Cluster.md)
  - [Deploy a high-availability kube-controller-manager cluster](deploydoc-en/6-Deploy-Master-Node/4-Deploy-HA-kube-controller-manager-Cluster.md)
  - [Deploy a high-availability kube-scheduler cluster](deploydoc-en/6-Deploy-Master-Node/5-Deploy-HA-kube-scheduler-Cluster.md)

## Chapter 7: Deploy Worker Nodes
- [Deploy Worker Nodes](deploydoc-en/7-Deploy-Worker-Node)
  - [Deployment Environment Description](deploydoc-en/7-Deploy-Worker-Node/1-Deployment-Environment-Description.md)
  - [Deploy containerd](deploydoc-en/7-Deploy-Worker-Node/2-Deploy-containerd.md)
  - [Deploy kubelet Component](deploydoc-en/7-Deploy-Worker-Node/3-Deploy-kubelet.md)
  - [Deploy kube-proxy Component](deploydoc-en/7-Deploy-Worker-Node/4-Deploy-kube-proxy.md)
  - [Deploy docker runtime (for reference only)](deploydoc-en/7-Deploy-Worker-Node/Deploy-docker-runtime-(reference-only).md)

## Chapter 8: Deploy Network Plugins
- [Deploy Network Plugins](deploydoc-en/8-Deploy-Network-Plugins)
  - [Deploy Calico Network Plugin](deploydoc-en/8-Deploy-Network-Plugins/1-Deploy-Calico-Network-Plugin.md)
  - [Deploy Cilium as a replacement for kube-proxy](deploydoc-en/8-Deploy-Network-Plugins/2-Deploy-Cilium-to-Replace-kube-proxy.md)

## Chapter 9: Verify Cluster Status
- [Verify Cluster Status](deploydoc-en/9-Verify-Cluster-Status)
  - [Verify Cluster Status](deploydoc-en/9-Verify-Cluster-Status/Verify-Cluster-Status.md)

## Chapter 10: Deploy Cluster Plugins
- [Deploy Cluster Plugins](deploydoc-en/10-Deploy-Cluster-Plugins)
  - [Deploy Coredns Plugin](deploydoc-en/10-Deploy-Cluster-Plugins/1-Deploy-Coredns-Plugin.md)
  - [Deploy Dashboard Plugin](deploydoc-en/10-Deploy-Cluster-Plugins/2-Deploy-Dashboard-Plugin.md)

## Statement
This project is for learning and communication purposes only. Please do not use it for commercial purposes, and indicate the address of this project when reprinting.<br>
Due to my limited ability, there may be omissions or errors in the text. Please point them out and give advice. Thank you very much.<br>

## Promotion

<table>
  <thead>
    <tr>
      <th width="50%" align="center">Description</th>
      <th width="50%" align="center">Image Introduction</th>
    </tr>
  </thead>
  <tbody>
    <!-- RackNerd -->
    <tr>
      <td width="50%" align="left">
        <a href="https://dqzboy.github.io/proxyui/racknerd" target="_blank">High cost-effective overseas VPS, supports multiple operating systems, suitable for building Docker proxy services.</a>
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
        <a href="https://dqzboy.github.io/proxyui/CloudCone" target="_blank">CloudCone provides flexible cloud server solutions, supports pay-as-you-go, suitable for personal and enterprise users.</a>
      </td>
      <td width="50%" align="center">
        <a href="https://dqzboy.github.io/proxyui/CloudCone" target="_blank">
          <img src="https://cdn.jsdelivr.net/gh/dqzboy/Images/dqzboy-proxy/111.png?raw=true" alt="CloudCone" width="200" height="150">
        </a>
      </td>
    </tr>
  </tbody>
</table>

##### *Telegram Bot: [Contact](https://t.me/WiseAidBot) ｜ E-Mail: support@dqzboy.com*
**Only long-term stable and reputable merchants are accepted*

## Sponsor
If you find this project helpful, please give me a Star. If possible, you can support me a little, thank you very much 😊

<table>
    <tr>
      <td width="50%" align="center"><b> Alipay </b></td>
      <td width="50%" align="center"><b> WeChat </b></td>
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
