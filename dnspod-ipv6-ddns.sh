#!/bin/bash
# -------------------------------------------------------------------------------
#Dnspod Only-ipv6 DDNS with BashShell
#进入https://console.dnspod.cn/account/token/token页面，创建API_ID和API_Token
#确保子域名已经存在解析AAAA记录，如没有则手动去创建一个AAAA记录
#获取自己的外网ip地址请详细查看https://www.ddnspod.com
# -------------------------------------------------------------------------------

#CONF START
API_ID="12345" #填写自己的API_ID
API_Token="abcdefgfikajhsbdemdcm172849409328"  #填写自己的Token
domain="baidu.com"  #填写自己的主域名
host="www"  #填写自己的子域名
GETIPV6="https://ip.ddnspod.com"  #互联网获取本机ipv6地址
#GETIPV6="https://ip.ddnspod.com/prefix/1:2:3:4"  #互联网获取本机ipv6地址前缀+自定义的固定后缀
#GETIPV6="https://ip.ddnspod.com/prefix/:5"  #互联网获取本机ipv6地址前缀，可拼接后缀
#CONF END

URLIP=$(curl -6 -s $GETIPV6)
echo "[URL IP]:$URLIP"

if [ "$host" == "@" ];then
	DNSIP=$(nslookup -q=AAAA $domain)
	echo "[DNS IP]:$DNSIP"
else
	DNSIP=$(nslookup -q=AAAA $host.$domain)
	echo "[DNS IP]:$DNSIP"
fi


if [ "$DNSIP" == "$URLIP" ];then
	echo "当前IP与DNS地址相同, 跳过修改操作."
	exit
fi

token="login_token=${API_ID},${API_Token}&format=json&domain=${domain}&record_type=AAAA&sub_domain=${host}"
Record=$(curl -s -X POST https://dnsapi.ddnspod.com/Record.List -d "${token}")
iferr=$(echo ${Record#*code} | cut -d'"' -f3)
if [ "$iferr" == "1" ];then
	record_ip=$(echo ${Record#*value} | cut -d'"' -f3)
	echo "[API IP]:$record_ip"
	if [ "$record_ip" == "$URLIP" ];then
		echo "当前IP与腾讯云域名解析地址相同, 跳过修改操作."
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
