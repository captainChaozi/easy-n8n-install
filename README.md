# N8N 汉化版一键安装脚本

> 🚀 专为Linux小白用户设计的N8N自动化部署方案  
> 支持一键安装、域名配置、HTTPS证书、证书更新和完整卸载

## 📦 包含脚本

| 脚本名称 | 功能描述 | 使用场景 |
|---------|---------|---------|
| `start_n8n.sh` | 一键安装和启动N8N | 首次部署 |
| `update_https.sh` | 更新HTTPS证书 | 证书续期 |
| `uninstall.sh` | 完全卸载N8N | 清理系统 |

## ✨ 功能特点

✅ **一键部署**: 自动生成随机密码和加密密钥  
✅ **智能配置**: 自动获取公网IP，提供访问地址  
✅ **域名支持**: 可选配置域名代理，自动更新nginx配置  
✅ **HTTPS支持**: 可选配置SSL证书，支持证书更新  
✅ **安全卸载**: 完整清理所有相关数据和配置  
✅ **小白友好**: 全中文界面，交互式操作，防误操作  
✅ **生产就绪**: 包含PostgreSQL数据库和Redis队列  

## 🚀 快速开始

### 1. 系统要求

- **操作系统**: Linux (Ubuntu/CentOS/Debian等)
- **内存**: 建议 2GB 以上
- **磁盘**: 建议 10GB 以上可用空间
- **网络**: 需要能访问Docker Hub

### 2. 安装Docker

```bash
# 一键安装Docker
curl -fsSL https://get.docker.com | bash

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到docker组（避免每次使用sudo）
sudo usermod -aG docker $USER

# 重新登录使权限生效
exit
```

### 3. 下载和运行

```bash
# 克隆项目（或下载压缩包）
git clone <项目地址>
cd easy-n8n-install

# 给脚本执行权限
chmod +x *.sh

# 运行安装脚本
bash start_n8n.sh
```

### 4. 安装流程

脚本会依次执行以下步骤：

1. **🔍 环境检查** - 验证Docker和Docker Compose是否正常
2. **⚙️ 生成配置** - 自动创建`.env`文件并填入随机密码
3. **🚀 启动服务** - 启动N8N、PostgreSQL、Redis等服务
4. **🌐 显示地址** - 显示访问地址（公网IP:5678）
5. **🔗 域名配置** - 询问是否需要配置域名代理（输入y/n，不能直接回车）
6. **🔒 SSL证书** - 询问是否需要配置HTTPS（输入y/n，不能直接回车）

> ⚠️ **注意**: 域名和SSL配置必须明确输入`y`或`n`，不能通过按回车跳过

## 🌍 访问方式

### 方式一：直接IP访问（默认）
```
http://你的公网IP:5678
```
- ✅ 无需额外配置
- ✅ 安装完成即可使用
- ⚠️ 需要开放5678端口

### 方式二：域名访问（推荐）
```
http://你的域名        # HTTP访问
https://你的域名       # HTTPS访问（需配置SSL证书）
```
- ✅ 使用标准80/443端口
- ✅ 支持HTTPS安全访问
- ✅ 更专业的访问方式
- ⚠️ 需要域名解析到服务器IP

## 📋 管理命令

### 服务管理
```bash
# 查看服务状态
cd n8n-start && docker compose ps

# 查看实时日志
cd n8n-start && docker compose logs -f

# 停止服务
cd n8n-start && docker compose down

# 重启服务  
cd n8n-start && docker compose restart

# 重新启动（重新读取配置）
cd n8n-start && docker compose down && docker compose up -d
```

### 脚本管理
```bash
# 更新HTTPS证书
bash update_https.sh

# 完全卸载N8N
bash uninstall.sh
```

## 🔒 SSL证书管理

### 首次配置HTTPS

在运行`start_n8n.sh`时选择配置HTTPS，需要准备：

1. **证书文件** (`*.crt` 或 `*.pem`) - SSL证书文件
2. **私钥文件** (`*.key`) - 私钥文件

脚本会自动：
- 验证证书格式和匹配性
- 复制证书到正确位置
- 更新nginx配置
- 重启nginx服务

### 更新证书

使用专用的证书更新脚本：

```bash
bash update_https.sh
```

功能包括：
- 🔍 **查看证书信息** - 显示当前证书详情和有效期
- 🔄 **更新证书** - 安全更新SSL证书
- 🧪 **测试连接** - 验证HTTPS是否正常工作
- 💾 **自动备份** - 更新前自动备份旧证书

## 🔧 故障排除

### 常见问题

#### 1. 端口占用
```bash
# 检查5678端口占用
sudo netstat -tlnp | grep :5678

# 检查80/443端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# 杀死占用进程
sudo kill -9 <进程ID>
```

#### 2. Docker权限问题
```bash
# 添加用户到docker组
sudo usermod -aG docker $USER

# 重新登录生效（或重启系统）
exit
```

#### 3. 服务启动失败
```bash
# 查看详细日志
cd n8n-start && docker compose logs

# 查看特定服务日志
cd n8n-start && docker compose logs n8n
cd n8n-start && docker compose logs postgres
```

#### 4. 域名无法访问
- ✅ 确认域名解析到服务器IP
- ✅ 检查防火墙开放80/443端口
- ✅ 确认nginx容器正常运行：`docker ps | grep gateway`

#### 5. HTTPS证书问题
```bash
# 使用证书更新脚本检查
bash update_https.sh

# 手动测试证书
openssl x509 -in /root/nginx/cert/cert.crt -text -noout
```

### 完全重置

如果遇到无法解决的问题：

```bash
# 完全卸载
bash uninstall.sh

# 重新安装
bash start_n8n.sh
```

## 🛡️ 安全建议

### 生产环境配置

1. **使用HTTPS** - 强烈建议配置SSL证书
2. **设置防火墙** - 仅开放必要端口（80, 443）
3. **定期备份** - 备份数据库和工作流数据
4. **更新证书** - 定期更新SSL证书，避免过期

### 防火墙配置示例

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

### 数据备份

```bash
# 备份数据库
docker exec n8n-start-postgres-1 pg_dump -U postgres n8n > n8n_backup.sql

# 备份工作流数据
docker run --rm -v n8n-start_n8n_storage:/data -v $(pwd):/backup ubuntu tar czf /backup/n8n_data.tar.gz -C /data .
```

## 📞 获取帮助

如遇问题，请检查：
- ✅ Docker服务是否正常运行
- ✅ 防火墙是否正确配置
- ✅ 系统资源是否充足（内存、磁盘）
- ✅ 网络连接是否正常

---

> 💡 **提示**: 这个脚本适用于个人和小团队使用。如需企业级部署，建议咨询专业运维人员。
