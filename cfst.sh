export CF_Key="xxx" # 修改为CF密钥
export CF_Email="xxx" #修改为CF邮箱
export domain=xxx #修改为使用域名的主域名,例如:baidu.com,此参数用来获取zone_id
export yxdomain=xxx #修改为需要使用的域名,例如cfst.baidu.com,此参数就是指向优选的域名
export botkey="xxx" #修改为telegram的bot密钥
export chatid="xxx" #修改为接收消息的tg帐号或频道id,墙内可能发送失败,也可能成功
# 获取 Zone ID
curl_head=(
    "X-Auth-Email: ${CF_Email}"
    "X-Auth-Key: ${CF_Key}"
    "Content-Type: application/json"
)
zone_id=$(curl -sS --request GET "https://api.cloudflare.com/client/v4/zones?name=$domain" --header "${curl_head[0]}" --header "${curl_head[1]}" --header "${curl_head[2]}" | jq -r '.result[0].id')
echo "$zone_id"     
# 执行 cfst 命令并将结果保存到变量
cfst_output=$(./CloudflareST -sl 1 -tll 80 -tl 260 -dn 5)
v6cfst_output=$(./CloudflareST -sl 1 -tll 60 -tl 200 -dn 5 -f ipv6.txt)

ip_addresses=$(echo "$cfst_output" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\s+' | awk '{print $1}' | head -n 5)
ipv6_addresses=$(echo "$v6cfst_output" | grep -E '^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\s+' | awk '{print $1}' | head -n 5)

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
    echo "解析 IP 地址：$ip_address"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -H "X-Auth-Email: $CF_Email" \
      -H "X-Auth-Key: $CF_Key" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$yxdomain\",\"content\":\"$ip_address\",\"ttl\":1,\"proxied\":false}" > /dev/null;
done
for ipv6_address in $ipv6_addresses; do
    echo "解析 IP 地址：$ipv6_address"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -H "X-Auth-Email: $CF_Email" \
      -H "X-Auth-Key: $CF_Key" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"AAAA\",\"name\":\"$yxdomain\",\"content\":\"$ipv6_address\",\"ttl\":1,\"proxied\":false}" > /dev/null;
done

ip_message="优选 IP 地址:
$ip_addresses
$ipv6_addresses"

xaa=$(curl -sS -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A,AAAA&name=$yxdomain" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Email: $CF_Email" \
    -H "X-Auth-Key: $CF_Key")

nipv6_addresses=$(echo "$xaa" | grep -oE '([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}')
nipv4_addresses=$(echo "$xaa" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')

nmessage="已解析 IP 地址:
$nipv4_addresses
$nipv6_addresses"
# 发送消息到Telegram
curl -s -G "https://api.telegram.org/bot$botkey/sendMessage" \
  --data-urlencode "chat_id=$chatid" \
  --data-urlencode "text=$ip_message"$'\n'---------------------------------------------------------------------$'\n'"$nmessage"
