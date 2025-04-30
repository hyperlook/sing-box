#!/bin/sh

# 检查文件是否存在
[ ! -f "ip.txt" ] && { echo "错误：ip.txt 不存在"; exit 1; }

# 读取IP列表并格式化为nftables元素格式
CN_IP=$(awk '{printf "%s, ",$1}' ip.txt | sed 's/, $//')

# 创建或更新nftables配置
cat > "cnlist.nft" << EOF
#!/usr/sbin/nft -f
table ip xray {
	set china_ips {
		flags interval
		type ipv4_addr
		elements = { $CN_IP }
	}
}
EOF

echo "已成功创建nftables配置文件"