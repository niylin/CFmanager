#!/bin/bash
read -p "请输入您的 Cloudflare API 密钥: " api_key
read -p "请输入您的 Cloudflare 邮件地址: " email
export CF_Key="$api_key"
export CF_Email="$email"

# 定义颜色代码
green_color="\e[1;32m"  # 绿色
blue_color="\e[1;34m"   # 蓝色
orange_color="\e[1;33m"  #橙色
reset_color="\e[0m"     # 重置颜色为默认值
# 获取域名列表并存储到数组中
domain_list=()
while read -r domain; do
  domain_list+=("$domain")
done < <(curl -sX GET "https://api.cloudflare.com/client/v4/zones" \
         -H "X-Auth-Email: $CF_Email" \
         -H "X-Auth-Key: $CF_Key" \
         -H "Content-Type:application/json" | \
         jq -r '.result[] | .name')

while true; do
  # 列出所有域名，并将其显示为带有编号的菜单
  echo "可供选择的域名列表, q退出："
  i=1
  for domain in "${domain_list[@]}"; do
    echo -e "${green_color}$i${reset_color}. ${blue_color}$domain${reset_color}" 
    ((i++))
  done
# 读取选项并获取对应的域名
read -p "请输入选项编号： " domain_choice
    if [ "$domain_choice" = "q" ]; then
        echo "退出脚本"
        break  # 跳出循环，结束脚本执行
    fi
domain_name=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones" \
                -H "X-Auth-Email: $CF_Email" \
                -H "X-Auth-Key: $CF_Key" \
                -H "Content-Type:application/json" | \
                jq -r --argjson choice "$domain_choice" \
                  '.result[$choice-1] | .name')
            
            # 获取 domain_name 的 Zone ID
            curl_head=(
                "X-Auth-Email: ${CF_Email}"
                "X-Auth-Key: ${CF_Key}"
                "Content-Type: application/json"
            )
            
            zone_id=$(curl -sS --request GET "https://api.cloudflare.com/client/v4/zones?name=$domain_name" --header "${curl_head[0]}" --header "${curl_head[1]}" --header "${curl_head[2]}" | jq -r '.result[0].id')
            
    # 执行具体域
    case $domain_name in
        *)
            while true; do
                clear
                echo "您选择的域名为：$domain_name"
                echo "如果区域ID为空,则无法成功执行操作"
                echo -e "域名: ${green_color}$domain_name${reset_color} 的区域 ID 为：${green_color}$zone_id${reset_color}"
                echo "-----------------"
                echo "1. 添加解析记录"
                echo "2. 删除解析记录"
                echo "q. 返回上级菜单"
                echo "-----------------"
                read -p "请输入选项编号： " main_choice
            
                case $main_choice in
                    1)
                    while true; do
                        echo "(1: A, 2: AAAA, 3: CNAME, 4: NS, 5: TXT, q: 返回)："
                        read -p "请正确输入记录类型编号: " parsing_type
                        if [ "$parsing_type" = "1" ]; then
                            record_type="A"
                            echo "你的选择为:$record_type"
                        elif [ "$parsing_type" = "2" ]; then
                            record_type="AAAA"
                            echo "你的选择为:$record_type"
                        elif [ "$parsing_type" = "3" ]; then
                            record_type="CNAME"
                            echo "你的选择为:$record_type"
                        elif [ "$parsing_type" = "4" ]; then
                            record_type="NS"
                            echo "你的选择为:$record_type"
                        elif [ "$parsing_type" = "5" ]; then
                            record_type="TXT"
                            echo "你的选择为:$record_type"
                        elif [ "$parsing_type" = "q" ]; then
                            break  # 退出循环
                        else
                            echo "无效的记录类型，请重新输入。"
                            continue  # 继续循环
                        fi
                        
                        if [ "$parsing_type" = "4" ] || [ "$parsing_type" = "5" ]; then
                            # NS 或 TXT 记录类型，不需要 CDN 选项
                            cdn=""
                        else
                            # 其他记录类型，需要询问 CDN 选项
                            read -p "是否开启 CDN（1: 开启, 其他为不开启）： " cdn_choice
                            if [ "$cdn_choice" == "1" ]; then
                                cdn=,\"proxied\":true
                            elif [ "$cdn_choice" == "q" ]; then
                                break  # 退出循环
                            else
                                cdn=,\"proxied\":false
                            fi
                        fi
                        read -p "输入域名前缀,空值即解析主域名： " prefix_name
                        if [ ! -z "$prefix_name" ]; then
                        prefix_name="${prefix_name}."
                        fi
                        echo "解析到本机输入+++"
                        read -p "请输入ip地址或CNAME地址： " ip_address
                        if [ "$ip_address" = "+++" ]; then
                        
                            if [ "$parsing_type" = "1" ]; then
                                # 获取本机IPv4地址
                                ip_address=$(ip -4 addr show | grep inet | awk '{print $2}' | cut -d "/" -f1 | grep -vE '^127\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.' | head -n 1)
                            elif [ "$parsing_type" = "2" ]; then
                                # 获取本机IPv6地址
                                ip_address=$(ip -6 addr show | grep inet6 | grep -v fe80 | awk '{if($2!="::1/128") print $2}' | cut -d"/" -f1 | head -n 1)
                            fi
                        elif [ "$ip_address" = "q" ]; then
                            break  # 退出循环
                        fi
                        echo -e "你的IP地址: ${blue_color}${ip_address}${reset_color}"
                        if curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
                            -H "X-Auth-Email: $CF_Email" \
                            -H "X-Auth-Key: $CF_Key" \
                            -H "Content-Type: application/json" \
                            --data "{\"type\":\"$record_type\",\"name\":\"$prefix_name$domain_name\",\"content\":\"$ip_address\",\"ttl\":1$cdn}" > /dev/null; then
                            echo "主机名解析成功！"
                        else
                            echo "主机名解析添加失败，尝试手动添加。"
                        fi
                        echo "-----------------------------------------------------------"
                        echo "-----------------------------------------------------------"
                    done
                    ;;
                    2)
                    while true; do
                        # 获取域名的解析记录列表
                        curl_url="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"
                        response_json_str=$(curl -sS --request GET "${curl_url}" --header "${curl_head[0]}" --header "${curl_head[1]}" --header "${curl_head[2]}")
                        record_count=$(echo "${response_json_str}" | jq -r '.result | length')
                        
                        # 显示解析记录列表及其编号
                        echo "解析记录列表："
                        echo "-----------------------"
                        for i in $(seq 0 $(($record_count-1))); do
                            record_id=$(echo "${response_json_str}" | jq -r ".result[$i].id")
                            record_name=$(echo "${response_json_str}" | jq -r ".result[$i].name")
                            record_type=$(echo "${response_json_str}" | jq -r ".result[$i].type")
                            record_content=$(echo "${response_json_str}" | jq -r ".result[$i].content")
                        echo -e "[$((i+1))] ${green_color}${record_name}${reset_color} (${orange_color}${record_type}${reset_color}) -> ${blue_color}${record_content}${reset_color}"
                        done
                        echo "-----------------------"
                        
                            # 提示输入要删除的记录编号
                            echo -e "输入q返回,输入${green_color}Delete all parsing records${reset_color}删除所有记录"
                            read -p "请输入要删除的记录编号： " record_number
                        
                            if [ "$record_number" = "q" ]; then
                                echo "退出删除记录循环。"
                                break  # 退出循环
                            fi
                            if [ "$record_number" = "Delete all parsing records" ]; then
                                 # 删除所有记录
                                for i in $(seq 0 $(($record_count-1))); do
                                    record_id=$(echo "${response_json_str}" | jq -r ".result[$i].id")
                                    curl -sS --request DELETE "${curl_url}/${record_id}" --header "${curl_head[0]}" --header "${curl_head[1]}" --header "${curl_head[2]}"
                                done
                                echo "所有记录已成功删除。"
                            fi
                            # 获取域名的解析记录列表
                            response_json_str=$(curl -sS --request GET "${curl_url}" --header "${curl_head[0]}" --header "${curl_head[1]}" --header "${curl_head[2]}")
                            record_count=$(echo "${response_json_str}" | jq -r '.result | length')
                        
                            if [ "$record_number" -le "$record_count" ]; then
                                # 获取要删除的记录 ID
                                record_id=$(echo "${response_json_str}" | jq -r ".result[$(($record_number-1))].id")
                                
                                # 删除指定的记录
                                curl -sS --request DELETE "${curl_url}/${record_id}" --header "${curl_head[0]}" --header "${curl_head[1]}" --header "${curl_head[2]}"
                                
                                echo "记录已成功删除。"
                            else
                                echo "输入的记录编号无效。"
                            fi
                        done
                            ;;
                    q)
                        echo "选择操作"
                        break 
                        ;;
                    *)
                        echo "无效的选项"
                        ;;
                esac
            done
            ;;
        q)
            break
            ;;
    esac
done

