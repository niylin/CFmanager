## CFmanager
cloud flare domain manager

#### 通过调用cf api来快捷管理你托管在cloud flare的域  
------------------------------------------
####  添加记录 :  A   ,AAAA , CANME , NS  , TXT   
####  可删除所有记录 
-------------------------------------------
#### 密钥配置位于 ~/.config/cfmanager/config.json    




<div>
  <button class="btn" data-clipboard-target="#code"></button>
  <pre><code id="code" class="language-python">
  {
    "CF_Key": "密钥",
    "CF_Email": "账户"
  }

  </code></pre>
</div>

----------------------------------------------------------------------  

----------------------------------------------------------------------  

## 基于[CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) 的自动优选
#### 将脚本放在和CloudflareSpeedTest同目录下即可,会将测速结果解析到指定域名,修改脚本中相关参数,将将需要优选节点中的server改为指定域名,即实现优选
#### 将脚本添加为crontab定时任务,定时运行即可.同样依赖jq和curl,CloudflareSpeedTest和此脚本均可在termux中运行,利用闲置手机来运行
### crontab任务示例,每天8点运行一次
#### 0 8 * * * ~/CloudflareST/cfst.sh
#### 每两小时运行一次
#### 0 */2 * * * ~/CloudflareST/cfst.sh
<div>
  <button class="btn" data-clipboard-target="#code"></button>
  <pre><code id="code" class="language-python">
wget https://raw.githubusercontent.com/niylin/CFmanager/main/cfst.sh
  </code></pre>
</div>
