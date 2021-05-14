#!/bin/bash
# -------------------------------------------------------------------------------
#Dnspod Only-ipv6 DDNS with BashShell
#改编自https://github.com/kkkgo/dnspod-ddns-with-bashshell
#API_ID和API_Token在Dnspod的控制台 -> 账号中心 -> 密钥管理 -> 创建密钥
#确保子域名已经存在解析AAAA记录，如没有则手动去创建一个AAAA记录
#获取自己的外网ip地址请详细查看https://www.ddnspod.com
# -------------------------------------------------------------------------------

#CONF START
API_ID="12345" #填写自己的API_ID
API_Token="abcdefgfikajhsbdemdcm172849409328"  #填写自己的Token
domain="baidu.com"  #填写自己的主域名
host="www"  #填写自己的子域名
GETIPV6="https://ipv6.ddnspod.com"  #互联网获取本机ipv6地址
#GETIPV6="https://ipv6.ddnspod.com/prefix"  #互联网获取本机ipv6地址前缀，可拼接后缀
#GETIPV6="https://ipv6.ddnspod.com/prefix/1:2:3:4"  #互联网获取本机ipv6地址前缀+自定义的固定后缀
#CONF END

IPREX="((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))"

URLIP=$(curl -6 -k $(if [ -n "$OUT" ]; then echo "--interface $OUT"; fi) -s $GETIPV6|grep -Eo "$IPREX"|tail -n 1)
if (echo $URLIP |grep -qEvo "$IPREX");then
	URLIP="Get $DOMAIN URLIP Failed."
fi
echo "[URL IP]:$URLIP"

DNSTEST=$(nslookup -q=AAAA $host.$domain)
if (echo $DNSTEST | grep -qEvo "$IPREX");then
	echo "Get $host.$domain DNS Failed."
	exit
else DNSIP=$(echo $DNSTEST | grep -Eo "$IPREX" | tail -n 1)
fi
echo "[DNS IP]:$DNSIP"

if [ "$DNSIP" == "$URLIP" ];then
	echo "IP SAME IN DNS,SKIP UPDATE."
	exit
fi

token="login_token=${API_ID},${API_Token}&format=json&domain=${domain}&record_type=AAAA&sub_domain=${host}"
Record=$(curl -s -k -X POST https://dnsapi.cn/Record.List -d "${token}")
iferr=$(echo ${Record#*code} | cut -d'"' -f3)
if [ "$iferr" == "1" ];then
	record_ip=$(echo ${Record#*value} | cut -d'"' -f3)
	echo "[API IP]:$record_ip"
	if [ "$record_ip" == "$URLIP" ];then
		echo "IP SAME IN API,SKIP UPDATE."
		exit
	fi
	record_id=$(echo ${Record#*\"records\"\:\[\{\"id\"} | cut -d'"' -f2)
	record_line_id=$(echo ${Record#*line_id} | cut -d'"' -f3)
	echo Start DDNS update...
	ddns=$(curl -s -k -X POST https://dnsapi.cn/Record.Modify -d "${token}&record_type=AAAA&record_id=${record_id}&record_line_id=${record_line_id}&value=${URLIP}")
	ddns_result="$(echo ${ddns#*message\"} | cut -d'"' -f2)"
	echo -n "DDNS upadte result:$ddns_result "
	echo $ddns | grep -Eo "$IPREX" | tail -n 1
	else echo -n Get $host.$domain error :
	echo $(echo ${Record#*message\"}) | cut -d'"' -f2
fi
