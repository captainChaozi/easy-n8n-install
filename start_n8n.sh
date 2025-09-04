#!/bin/bash

# N8N 一键启动脚本
# 适用于Linux小白用户

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 生成随机字符串函数
generate_random_string() {
    local length=$1
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        print_info "安装命令: curl -fsSL https://get.docker.com | bash"
        exit 1
    fi
    

}

# 获取公网IP
get_public_ip() {
    local ip=""
    
    # 尝试多个服务获取公网IP
    for service in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ident.me"; do
        ip=$(curl -s --connect-timeout 5 "$service" 2>/dev/null | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -n1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return
        fi
    done
    
    # 如果都失败了，返回本地IP
    print_warning "无法获取公网IP，使用本地IP"
    ip=$(hostname -I | awk '{print $1}')
    echo "$ip"
}

# 创建.env文件
create_env_file() {
    print_info "正在生成环境变量文件..."
    
    # 生成随机密码和加密密钥
    local postgres_password=$(generate_random_string 32)
    local non_root_password=$(generate_random_string 32)
    local encryption_key=$(generate_random_string 64)
    
    # 复制模板并替换变量
    cp env.template n8n-start/.env
    
    sed -i "s/REPLACE_POSTGRES_PASSWORD/$postgres_password/g" n8n-start/.env
    sed -i "s/REPLACE_NON_ROOT_PASSWORD/$non_root_password/g" n8n-start/.env
    sed -i "s/REPLACE_ENCRYPTION_KEY/$encryption_key/g" n8n-start/.env
    
    print_success "环境变量文件已生成"
}

# 启动N8N服务
start_n8n() {
    print_info "正在启动N8N服务..."
    
    cd n8n-start
    
    # 停止可能存在的容器
    docker compose down 2>/dev/null || true
    
    # 启动服务
    docker compose up -d
    
    print_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker compose ps | grep -q "Up"; then
        print_success "N8N服务启动成功！"
        return 0
    else
        print_error "N8N服务启动失败，请检查日志"
        docker compose logs
        return 1
    fi
}

# 配置nginx
setup_nginx() {
    print_info "正在启动Nginx代理..."
    
    # 创建nginx配置目录
    mkdir -p /root/nginx/cert
    
    # 复制nginx配置文件
    cp ../nginx/80.conf /root/nginx/
    
    # 启动nginx容器
    cd ..
    bash nginx/start.sh
    
    print_success "Nginx代理已启动"
}

# 配置SSL证书
setup_ssl() {
    print_info "请提供SSL证书文件路径："
    
    read -p "请输入证书文件(.crt)的完整路径: " cert_path
    read -p "请输入私钥文件(.key)的完整路径: " key_path
    
    if [[ ! -f "$cert_path" ]]; then
        print_error "证书文件不存在: $cert_path"
        return 1
    fi
    
    if [[ ! -f "$key_path" ]]; then
        print_error "私钥文件不存在: $key_path"
        return 1
    fi
    
    # 复制证书文件
    cp "$cert_path" /root/nginx/cert/cert.crt
    cp "$key_path" /root/nginx/cert/cert.key
    
    # 重启nginx
    docker restart gateway
    
    print_success "SSL证书配置完成，Nginx已重启"
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "=================================="
    echo "     N8N 一键启动脚本 v1.0"
    echo "=================================="
    echo -e "${NC}"
    
    # 检查Docker
    print_info "检查系统环境..."
    check_docker
    
    # 检查是否在项目目录
    if [[ ! -f "env.template" ]]; then
        print_error "请在项目根目录运行此脚本"
        exit 1
    fi
    
    # 步骤1: 创建环境变量文件
    create_env_file
    
    # 步骤2: 启动N8N
    if ! start_n8n; then
        exit 1
    fi
    
    # 获取访问地址
    local public_ip=$(get_public_ip)
    local n8n_port="5678"
    
    print_success "N8N已成功启动！"
    echo -e "${GREEN}访问地址: http://${public_ip}:${n8n_port}${NC}"
    
    # 步骤3: 询问是否需要配置域名
    echo ""
    while true; do
        read -p "是否需要配置域名代理？(y/n): " setup_domain
        case $setup_domain in
            [Yy]* ) break;;
            [Nn]* ) break;;
            * ) print_warning "请输入 y 或 n";;
        esac
    done
    
    if [[ "$setup_domain" =~ ^[Yy]$ ]]; then
        # 步骤4: 启动nginx
        setup_nginx
        
        echo ""
        read -p "请输入您的域名 (例如: example.com): " domain_name
        
        if [[ -n "$domain_name" ]]; then
            # 更新nginx配置文件中的server_name
            print_info "正在更新nginx配置文件..."
            sed -i "s/server_name localhost;/server_name $domain_name;/g" /root/nginx/80.conf
            
            # 重启nginx容器以应用新配置
            docker restart gateway
            
            print_success "域名配置完成！"
            echo -e "${GREEN}HTTP访问地址: http://${domain_name}${NC}"
            
            # 步骤5: 询问是否配置HTTPS
            echo ""
            while true; do
                read -p "是否需要配置HTTPS证书？(y/n): " setup_https
                case $setup_https in
                    [Yy]* ) break;;
                    [Nn]* ) break;;
                    * ) print_warning "请输入 y 或 n";;
                esac
            done
            
            if [[ "$setup_https" =~ ^[Yy]$ ]]; then
                # 复制HTTPS配置文件
                print_info "正在配置HTTPS..."
                cp nginx/443.conf /root/nginx/
                sed -i "s/server_name localhost;/server_name $domain_name;/g" /root/nginx/443.conf
                
                if setup_ssl; then
                    echo -e "${GREEN}HTTPS访问地址: https://${domain_name}${NC}"
                else
                    print_warning "SSL配置失败，您仍可以使用HTTP访问"
                fi
            fi
        fi
    else
        print_info "脚本执行完成"
        echo -e "${YELLOW}请使用以下地址访问N8N:${NC}"
        echo -e "${GREEN}http://${public_ip}:${n8n_port}${NC}"
    fi
    
    echo ""
    print_success "所有配置已完成！"
    echo -e "${BLUE}使用提示:${NC}"
    echo "1. 首次访问需要创建管理员账户"
    echo "2. 如需停止服务，请运行: cd n8n-start && docker compose down"
    echo "3. 如需查看日志，请运行: cd n8n-start && docker compose logs -f"
}

# 运行主函数
main "$@"
