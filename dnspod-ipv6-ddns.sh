#!/bin/bash
# -------------------------------------------------------------------------------
# 2023-12更新：获取本地DNS的IPv6换成了host命令
# -------------------------------------------------------------------------------
# 进入https://console.dnspod.cn/account/token/token页面，创建API_ID和API_Token
# 确保子域名已经存在解析AAAA记录，如没有则手动去创建一个AAAA记录
# 获取自己的外网ip地址请详细查看https://www.ddnspod.com
# -------------------------------------------------------------------------------

#CONF START
API_ID="12345"  # 填写自己的API_ID
API_Token="abcdefgfikajhsbdemdcm172849409328"  # 填写自己的Token
domain="baidu.com"  # 填写自己的主域名
host="www"  # 填写自己的子域名
GETIPV6="https://ip.ddnspod.com"  # 互联网获取本机ipv6地址
#GETIPV6="https://ip.ddnspod.com/prefix/1:2:3:4"  # 互联网获取本机ipv6地址前缀+自定义的固定后缀
#GETIPV6="https://ip.ddnspod.com/prefix/:5"  # 互联网获取本机ipv6地址前缀，可拼接后缀
#CONF END

# 从互联网获取本机ipv6外网地址
URLIP=$(curl -6 -s $GETIPV6 -A 'DDnsPod-202312')
echo "[URL IP]:$URLIP"

# 使用host命令获取本地DNS解析的ipv6地址
if [ "$host" == "@" ];then
	# 使用host命令查询DNS
    DNSIP=$(host -t AAAA $domain | grep 'IPv6 address' | sed -n 1p | awk '{print $NF}')
    # 使用nslookup命令查询DNS
#    DNSIP=$(nslookup -type=AAAA $domain | grep 'Address' | tail -n 1 | awk '{print $NF}')
	echo "[DNS IP]:$DNSIP"
else
    # 使用host命令查询DNS
    DNSIP=$(host -t AAAA $host.$domain | grep 'IPv6 address' | sed -n 1p | awk '{print $NF}')
    # 使用nslookup命令查询DNS
#    DNSIP=$(nslookup -type=AAAA $host.$domain | grep 'Address' | tail -n 1 | awk '{print $NF}')
	echo "[DNS IP]:$DNSIP"
fi

# 对比本地DNS解析的ipv6地址和从外网获取的ipv6地址是否相同
if [ "$DNSIP" == "$URLIP" ];then
	echo "当前外网IPv6与本地DNS获取IPv6相同, 跳过更新操作."
	exit
fi

# 从腾讯云API接口获取域名解析的ipv6地址，如果不相同则更新腾讯云解析
token="login_token=${API_ID},${API_Token}&format=json&domain=${domain}&record_type=AAAA&sub_domain=${host}"
Record=$(curl -s -X POST https://dnsapi.ddnspod.com/Record.List -d "${token}")
iferr=$(echo ${Record#*code} | cut -d'"' -f3)
if [ "$iferr" == "1" ];then
	record_ip=$(echo ${Record#*value} | cut -d'"' -f3)
	echo "[API IP]:$record_ip"
	if [ "$record_ip" == "$URLIP" ];then
		echo "当前外网IPv6与腾讯云解析IPv6相同, 跳过更新操作."
		exit
	fi
	record_id=$(echo ${Record#*\"records\"\:\[\{\"id\"} | cut -d'"' -f2)
	record_line_id=$(echo ${Record#*line_id} | cut -d'"' -f3)
	echo Start DDNS update...
	ddns=$(curl -s -X POST https://dnsapi.ddnspod.com/Record.Modify -d "${token}&record_id=${record_id}&record_line_id=${record_line_id}&value=${URLIP}")
	ddns_result="$(echo -en ${ddns#*message\"} | cut -d'"' -f2)"
	echo -en "DDNS upadte result:$ddns_result \n "
	else echo -n Get $host.$domain error :
	echo $(echo -en ${Record#*message\"}) | cut -d'"' -f2
fi
