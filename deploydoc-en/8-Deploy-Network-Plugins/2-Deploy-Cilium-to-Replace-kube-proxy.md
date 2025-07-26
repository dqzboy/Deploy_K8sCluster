## 1. Introduction to Cilium
Cilium is an open-source software and a CNCF incubating project. Cilium provides transparent networking and API connectivity and security for services deployed on Kubernetes Linux container management platforms.<br>
Cilium is based on a new Linux kernel technology called eBPF, which supports dynamic insertion of powerful security visibility and control logic into the Linux kernel. Because eBPF runs in the kernel, Cilium security policies can be applied and updated without changing application code or container configuration.

## 2. Component Overview
Cilium deployment includes the following components, running on each Linux container node in the cluster:
- **Cilium Agent (Daemon):** User-space daemon that interacts with container runtime and orchestration systems (e.g., Kubernetes) via plugins, configuring networking and security for containers on the local server. Provides APIs for configuring network security policies and extracting network visibility data.
- **Cilium CLI Client:** Simple CLI client for communicating with the local Cilium Agent, e.g., for configuring network security or visibility policies.
- **Linux Kernel BPF:** Integrated kernel functionality for running compiled bytecode at various hooks/tracing points. Cilium compiles BPF programs and runs them at key points in the network stack for visibility and control of all container network traffic.
- **Container Platform Network Plugin:** Each container platform (e.g., Docker, Kubernetes) has its own plugin model for integrating with external network platforms. For Docker, each Linux node runs a process (`cilium-docker`) to handle each `Docker libnetwork` call and pass data/requests to the main Cilium Agent.

## 3. Cilium Deployment
### 1. Cilium Deployment Requirements
#### K8s Version
- Newer Kubernetes versions provide backward compatibility. (e.g. 1.16-1.25)
#### Kernel Version
- Cilium leverages and builds on kernel eBPF features and various subsystems. Host OS must run Linux kernel version `4.9.17` or higher to run Cilium agent.
- For `eBPF Host-Routing`, ensure Linux kernel `>= 5.10`.
- To enable eBPF features, the following kernel config options must be enabled:
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
# Check current kernel config
egrep "^CONFIG_BPF=|^CONFIG_BPF_SYSCALL=|^CONFIG_NET_CLS_BPF=|^CONFIG_BPF_JIT=|^CONFIG_NET_CLS_ACT=|^CONFIG_NET_SCH_INGRESS=|^CONFIG_CRYPTO_SHA1=|^CONFIG_CRYPTO_USER_API_HASH=|^CONFIG_CGROUPS=|^CONFIG_CGROUP_BPF=" /boot/config-<Your kernel version>
```
#### systemd cgroup
- Confirm your system's cgroup version. If using cgroup v2, your container runtime and kubelet must also be configured for cgroup v2.
```shell
stat -fc %T /sys/fs/cgroup/
# cgroup v2: output is cgroup2fs
# cgroup v1: output is tmpfs
```
#### Mount eBPF Filesystem
- Some distributions automatically mount the bpf filesystem. Check if bpf is installed:
```shell
mount | grep bpf
```
