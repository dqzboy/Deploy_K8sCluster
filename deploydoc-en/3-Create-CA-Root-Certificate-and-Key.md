> For security, all Kubernetes components use x509 certificates for encrypted communication and authentication.<br>
> CA (Certificate Authority) is a self-signed root certificate used to sign other certificates.

## 1. Install cfssl Toolkit
- **Note:** All commands and files are executed on `k8s-master1`, then distributed to other nodes
- Project address: https://github.com/cloudflare/cfssl

```shell
cd /opt/k8s
export cfsslVer=1.6.3
wget https://github.com/cloudflare/cfssl/releases/download/v${cfsslVer}/cfssl_${cfsslVer}_linux_amd64
mv cfssl_${cfsslVer}_linux_amd64 /opt/k8s/bin/cfssl
wget https://github.com/cloudflare/cfssl/releases/download/v${cfsslVer}/cfssljson_${cfsslVer}_linux_amd64
mv cfssljson_${cfsslVer}_linux_amd64 /opt/k8s/bin/cfssljson
wget https://github.com/cloudflare/cfssl/releases/download/v${cfsslVer}/cfssl-certinfo_${cfsslVer}_linux_amd64 
mv cfssl-certinfo_${cfsslVer}_linux_amd64 /opt/k8s/bin/cfssl-certinfo
chmod +x /opt/k8s/bin/*
export PATH=/opt/k8s/bin:$PATH
```

## 2. Create CA Certificate
### 2.1: Create Configuration File
```shell
cd /opt/k8s/work
mkdir -p ca && cd ca
cat > ca-config.json <<EOF
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
