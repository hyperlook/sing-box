
# Alpine 配置为网关旁路由

> tun板 官方为处理路由本机 output 链，路由本机上网需要自己手动添加 chain 来处理。
> 为效率放弃 也是可以的，似乎ruleset 里的 srs 下载又是正常的，挺奇怪

### 网络配置
- setup-alpine 按步骤配置好 IP 和下级网关 DNS
  > resolve.conf 可以写172.18.0.2 对应 tun 配置的 ip
    ```
    /etc/network/interfaces
    /etc/resolv.conf
    ```

### 开启转发
- 临时开启（重启后失效）
  ```bash
  sysctl -w net.ipv4.ip_forward=1
  ```

- 永久开启方法
  ```bash
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf 
  sysctl -p
  ```
### tun模块
- 临时开启（重启后失效）
  ```bash
  modprobe tun
  ```
- 永久开启方法
  ```bash
  echo "tun" >> /etc/modules
  ```

### 安装 sing-box
```bash
wget https://github.com/SagerNet/sing-box/releases/download/v1.11.9/sing-box-1.11.9-linux-amd64.tar.gz
tar -zxvf sing-box-1.1.0-linux-amd64.tar.gz
mv sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box
sing-box version
```

### 添加 sing-box 服务
```bash
rc-update add sing-box default
rc-service sing-box start
rc-service sing-box status
rc-service sing-box stop
```

### 添加 singbox 用户
> tun 版没用到 skgid 来过滤，可选，为后续手动添加output 备着


因为 nft 需要用到 skgid 来过滤 sing-box 发出的流量，防止 lo 死循环。为方便 sing-box 用 root id，直接编辑 /etc/passwd：
```bash
echo "singbox:x:0:7893:::" >> /etc/passwd
```

## 配置 nft

### 安装 nftables
```bash
apk add nftables
```

### nft 大致思路
> tun 板 路由策略 以及nft 部分已经由 sing-box 完成
#### 路由策略

额外标记引导被 tproxy 的数据包 到 sing-box 端口
> 没有路由策略，默认目标地址为远程，tproxy 会被丢弃
> redirect 可跳过这步
```bash
# 0x1ed4 与 nft 保持一致
ip rule add fwmark 0x1ed4 lookup 100 prio 32765

# 添加路由策略
route add local default dev lo scope host table 100 
```

#### DNS 配置
DNS 优先单独配置
 
  > 直接修改 sing-box 1053 端口为 53 端口省去redirect 步骤
  见 inbound.json


#### 流量转发规则
> 经tproxy 转发至 sing-box 的数据，如果经 sing-box 判断为不需要代理（比如 direct）
> 会丢回 lo 网卡，再次出现在 prerouting 引起死循环
> 必须过滤 skgid 避免死循环
**Prerouting 阶段**
- 排除不需要转发的流量：
  - 内网流量
  - Singbox 发出的流量
  - 不需要代理的端口流量
  - 国内流量（可选）
- TPROXY 处理：
  - 添加标记配合路由策略引导到 sing-box 端口


**Output 阶段**
> Output 无法直接 tproxy，添加标记后由路由策略引导至 prerouting
> 主要用于本机，如本机无需求可跳过提升效率
- 排除不需要转发的流量：
  - 内网流量
  - Singbox 发出的流量
  - 不需要代理的端口流量
  - 国内流量
- 添加标记 或使用 redirect 到 sing-box 端口


### 配置规则
- 具体规则见 s.nft、tun.nft(由 sing-box 生成)
- 添加方式随 sing-box 服务，见 /etc/init.d/sing-box

## filebrowser
可选装装 filebrowser 方便编辑json 和重启服务
wget https://github.com/filebrowser/filebrowser/releases/download/v2.32.0/linux-amd64-filebrowser.tar.gz 