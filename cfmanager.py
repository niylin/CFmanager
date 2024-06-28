import os
import requests
import json
from colorama import Fore, Style, init

init(autoreset=True)

# 获取用户的主目录
home_dir = os.path.expanduser('~')
config_path = os.path.join(home_dir, '.config', 'cfmanager', 'config.json')

# 检查配置文件是否存在
if not os.path.exists(config_path):
    raise FileNotFoundError(f"Configuration file not found at {config_path}")

# 读取配置文件
with open(config_path, 'r') as config_file:
    config_data = json.load(config_file)

CF_Key = config_data.get("CF_Key")
CF_Email = config_data.get("CF_Email")

if CF_Key is None or CF_Email is None:
    raise ValueError("Cloudflare API keys not found in config.json")




# 获取域名列表
response = requests.get(
    "https://api.cloudflare.com/client/v4/zones",
    headers={
        "X-Auth-Email": CF_Email,
        "X-Auth-Key": CF_Key,
        "Content-Type": "application/json"
    }
)
zones = response.json()["result"]
domain_list = [zone["name"] for zone in zones]

while True:
    # 列出所有域名，并将其显示为带有编号的菜单
    print("可供选择的域名列表, q退出：")
    for i, domain in enumerate(domain_list, start=1):
        print(f"{Fore.GREEN}{i}{Style.RESET_ALL}. {Fore.BLUE}{domain}{Style.RESET_ALL}")

    # 读取选项并获取对应的域名
    domain_choice = input("请输入选项编号： ")
    if domain_choice == "q":
        print("退出脚本")
        break

    domain_name = domain_list[int(domain_choice) - 1]
    
    # 获取 domain_name 的 Zone ID
    zone_id_response = requests.get(
        f"https://api.cloudflare.com/client/v4/zones?name={domain_name}",
        headers={
            "X-Auth-Email": CF_Email,
            "X-Auth-Key": CF_Key,
            "Content-Type": "application/json"
        }
    )
    zone_id = zone_id_response.json()["result"][0]["id"]

    while True:
        os.system('cls' if os.name == 'nt' else 'clear')
        print(f"您选择的域名为：{domain_name}")
        print("如果区域ID为空,则无法成功执行操作")
        print(f"域名: {Fore.GREEN}{domain_name}{Style.RESET_ALL} 的区域 ID 为：{Fore.GREEN}{zone_id}{Style.RESET_ALL}")
        print("-----------------")
        print("1. 添加解析记录")
        print("2. 删除解析记录")
        print("q. 返回上级菜单")
        print("-----------------")
        main_choice = input("请输入选项编号： ")

        if main_choice == "1":
            while True:
                cdn_choice = None
                print("(1: A, 2: AAAA, 3: CNAME, 4: NS, 5: TXT, q: 返回)：")
                parsing_type = input("请正确输入记录类型编号: ")
                record_types = {"1": "A", "2": "AAAA", "3": "CNAME", "4": "NS", "5": "TXT"}
                if parsing_type in record_types:
                    record_type = record_types[parsing_type]
                    print(f"你的选择为:{record_type}")
                elif parsing_type == "q":
                    break
                else:
                    print("无效的记录类型，请重新输入。")
                    continue
                
                if parsing_type in ["4", "5"]:
                    cdn = ""
                else:
                    cdn_choice = input("是否开启 CDN（1: 开启, 其他为不开启）： ")
                    cdn = ",\"proxied\":true" if cdn_choice == "1" else ",\"proxied\":false"

                prefix_name = input("输入域名前缀,空值即解析主域名： ")
                if prefix_name:
                    prefix_name = f"{prefix_name}."

                ip_address = input("请输入ip地址或CNAME地址输入+++解析本机地址： ")
                if ip_address == "+++":
                    if record_type == "A":
                        # ip_address = os.popen("ip -4 addr show | grep inet | awk '{print $2}' | cut -d '/' -f1 | grep -vE '^127\\. | ^10\\. | ^172\\.(1[6-9]|2[0-9]|3[0-1])\\. | ^192\\.168\\.' | head -n 1").read().strip()
                        ip_address = requests.get('http://ipv4.ping0.cc').text.strip()
                    elif record_type == "AAAA":
                        # ip_address = os.popen("ip -6 addr show | grep inet6 | grep -v fe80 | awk '{if($2!=\"::1/128\") print $2}' | cut -d'/' -f1 | head -n 1").read().strip()
                        ip_address = requests.get('http://ipv6.ping0.cc').text.strip()
                elif ip_address == "q":
                    break

                print(f"你的IP地址: {Fore.BLUE}{ip_address}{Style.RESET_ALL}")

                response = requests.post(
                    f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
                    headers={
                        "X-Auth-Email": CF_Email,
                        "X-Auth-Key": CF_Key,
                        "Content-Type": "application/json"
                    },
                    data=json.dumps({
                        "type": record_type,
                        "name": f"{prefix_name}{domain_name}",
                        "content": ip_address,
                        "ttl": 1,
                        "proxied": cdn_choice == "1"
                    })
                )

                if response.status_code == 200:
                    print("主机名解析成功！")
                else:
                    print("主机名解析添加失败，尝试手动添加。")
                print("-----------------------------------------------------------")
                print("-----------------------------------------------------------")

        elif main_choice == "2":
            while True:
                response = requests.get(
                    f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
                    headers={
                        "X-Auth-Email": CF_Email,
                        "X-Auth-Key": CF_Key,
                        "Content-Type": "application/json"
                    }
                )
                records = response.json()["result"]
        
                print("解析记录列表：")
                print("-----------------------")
                for i, record in enumerate(records, start=1):  # Start enumeration from index 1
                    print(f"[{i}] {Fore.GREEN}{record['name']}{Style.RESET_ALL} ({Fore.YELLOW}{record['type']}{Style.RESET_ALL}) -> {Fore.BLUE}{record['content']}{Style.RESET_ALL}")
                print("-----------------------")
        
                record_number = input(f"输入q返回,输入{Fore.GREEN}Delete all parsing records{Style.RESET_ALL}删除所有记录: ")
        
                if record_number == "q":
                    print("退出删除记录循环。")
                    break
                
                if record_number == "Delete all parsing records":
                    for record in records:
                        record_id = record["id"]
                        requests.delete(
                            f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}",
                            headers={
                                "X-Auth-Email": CF_Email,
                                "X-Auth-Key": CF_Key,
                                "Content-Type": "application/json"
                            }
                        )
                    print("所有记录已成功删除。")
                elif record_number.strip():  # 检查 record_number 不为空
                    try:
                        record_index = int(record_number) - 1
                        if 0 <= record_index < len(records):
                            record_id = records[record_index]["id"]
                            requests.delete(
                                f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}",
                                headers={
                                    "X-Auth-Email": CF_Email,
                                    "X-Auth-Key": CF_Key,
                                    "Content-Type": "application/json"
                                }
                            )
                            print("记录已成功删除。")
                        else:
                            print("输入的记录编号无效。")
                    except ValueError:
                        print("无效的输入，请输入有效的记录编号或指令。")
                else:
                    print("无效的输入，请输入有效的记录编号或指令。")

        elif main_choice == "q":
            break
        else:
            print("无效的选项")

