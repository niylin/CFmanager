export CF_Key="xxx" # 修改为CF密钥
export CF_Email="xxx" #修改为CF邮箱
export domain=xxx #修改为使用域名的主域名,例如:baidu.com,此参数用来获取zone_id
export yxdomain=xxx #修改为需要使用的域名,例如cfst.baidu.com,此参数就是指向优选的域名
export botkey=xxx #修改为telegram的bot密钥
export chatid=xxx #修改为接收消息的tg帐号或频道id,墙内可能发送失败,也可能成功
# 获取 Zone ID
curl_head=(
    "X-Auth-Email: ${CF_Email}"
    "X-Auth-Key: ${CF_Key}"
    "Content-Type: application/json"
)
zone_id=$(curl -sS --request GET "https://api.cloudflare.com/client/v4/zones?name=$domain" --header "${curl_head[0]}" --header "${curl_head[1]}" --header "${curl_head[2]}" | jq -r '.result[0].id')
echo "$zone_id"     
# 执行 cfst 命令并将结果保存到变量
cfst_output=$(./CloudflareST -sl 1 -tll 100 -tl 260 -dn 5)

ip_addresses=$(echo "$cfst_output" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+' | awk '{print $1}' | head -n 5)

# 获取指定域名的所有解析记录
records=$(curl -sS -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$yxdomain" \
  -H "Content-Type: application/json" \
  -H "X-Auth-Email: $CF_Email" \
  -H "X-Auth-Key: $CF_Key")

# 提取解析记录的 ID，并逐个删除
record_ids=$(echo "$records" | jq -r '.result[].id')

for record_id in $record_ids; do
  curl -sS -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Email: $CF_Email" \
    -H "X-Auth-Key: $CF_Key"
done
# 遍历每个 IP 地址进行解析
for ip_address in $ip_addresses; do
    # 执行解析操作，将 ip_address 作为参数使用
    # 例如：curl 或其他操作
    echo "解析 IP 地址：$ip_address"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -H "X-Auth-Email: $CF_Email" \
      -H "X-Auth-Key: $CF_Key" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$yxdomain\",\"content\":\"$ip_address\",\"ttl\":1,\"proxied\":false}" > /dev/null;
done

# ip_addresses是包含5个IP地址的数组
ip_message="优选 IP 地址："$'\n'
for ((i=0; i<5; i++)); do
    ip_message+=" ${ip_addresses[$i]},"
done
# 去除最后一个逗号
ip_message=${ip_message%,}

xaa=$(curl -sS -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$yxdomain" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Email: $CF_Email" \
    -H "X-Auth-Key: $CF_Key")
# 定义空数组来存储IP地址
ips=()
# 提取IP地址，并将它们添加到数组中
for record in $(echo "$xaa" | jq -c '.result[]'); do
    ip=$(echo "$record" | jq -r '.content')
    ips+=("$ip")
done
# 构建IP地址消息字符串
nmessage="已解析 IP 地址："$'\n'
for ip in "${ips[@]}"; do
    nmessage+=" $ip"$'\n'
done
# 去除最后一个逗号
nmessage=${nmessage%,}

# 发送消息到Telegram
curl -s -G "https://api.telegram.org/bot$botkey/sendMessage" \
  --data-urlencode "chat_id=$chatid" \
  --data-urlencode "text=$ip_message"$'\n'"$nmessage"
