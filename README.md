# 汉化n8n小白服务器安装脚本

# N8N 一键启动脚本使用说明

## 功能特点

✅ **一键启动**: 自动生成随机密码和加密密钥  
✅ **智能配置**: 自动获取公网IP，提供访问地址  
✅ **域名支持**: 可选配置域名代理  
✅ **HTTPS支持**: 可选配置SSL证书  
✅ **小白友好**: 全中文界面，步骤清晰  

## 使用方法

### 1. 基础要求

确保系统已安装 Docker 和 Docker Compose：

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | bash

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到 docker 组（可选）
sudo usermod -aG docker $USER
```

### 2. 运行脚本

在项目根目录执行：

```bash
./start_n8n.sh
```

### 3. 按提示操作

脚本会依次执行以下步骤：

1. **检查环境** - 验证 Docker 是否正常
2. **生成配置** - 自动创建 `.env` 文件并填入随机密码
3. **启动服务** - 启动 N8N 及相关服务
4. **显示地址** - 显示访问地址（公网IP:5678）
5. **域名配置** - 询问是否需要配置域名（可选）
6. **SSL证书** - 询问是否需要配置HTTPS（可选）

## 访问方式

### 直接访问（默认）
- 地址：`http://你的公网IP:5678`
- 端口：5678

### 通过域名访问（可选）
- HTTP：`http://你的域名`
- HTTPS：`https://你的域名`（需配置SSL证书）

## 常用命令

```bash
# 查看服务状态
cd n8n-start && docker-compose ps

# 查看日志
cd n8n-start && docker-compose logs -f

# 停止服务
cd n8n-start && docker-compose down

# 重启服务
cd n8n-start && docker-compose restart
```

## SSL证书配置

如果选择配置HTTPS，需要准备：

1. **证书文件** (*.crt) - SSL证书文件
2. **私钥文件** (*.key) - 私钥文件

脚本会自动将证书复制到正确位置并重启Nginx。

## 故障排除

### 常见问题

1. **端口占用**
   ```bash
   # 检查端口占用
   sudo netstat -tlnp | grep :5678
   ```

2. **Docker权限问题**
   ```bash
   # 添加用户到docker组
   sudo usermod -aG docker $USER
   # 重新登录生效
   ```

3. **服务启动失败**
   ```bash
   # 查看详细日志
   cd n8n-start && docker-compose logs
   ```

### 获取帮助

如遇问题，请检查：
- Docker 服务是否正常运行
- 防火墙是否开放相应端口
- 系统资源是否充足

## 安全建议

1. **修改默认端口** - 可在 `docker-compose.yml` 中修改端口映射
2. **设置防火墙** - 仅开放必要端口
3. **定期备份** - 备份 N8N 数据和配置文件
4. **使用HTTPS** - 生产环境建议配置SSL证书
