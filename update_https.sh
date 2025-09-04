#!/bin/bash

# N8N HTTPS证书更新脚本
# 用于更新SSL证书并重启nginx服务

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

# 检查nginx容器是否运行
check_nginx_container() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^gateway$"; then
        print_error "nginx容器(gateway)未运行"
        print_info "请先运行 bash start_n8n.sh 启动服务"
        exit 1
    fi
    print_info "nginx容器运行正常"
}

# 检查证书目录是否存在
check_cert_directory() {
    if [[ ! -d "/root/nginx/cert" ]]; then
        print_error "证书目录不存在: /root/nginx/cert"
        print_info "请先运行 bash start_n8n.sh 并配置域名"
        exit 1
    fi
    print_info "证书目录存在"
}

# 备份现有证书
backup_existing_certs() {
    local backup_dir="/root/nginx/cert/backup_$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "/root/nginx/cert/cert.crt" ]] && [[ -f "/root/nginx/cert/cert.key" ]]; then
        print_info "正在备份现有证书..."
        mkdir -p "$backup_dir"
        cp /root/nginx/cert/cert.crt "$backup_dir/" 2>/dev/null || true
        cp /root/nginx/cert/cert.key "$backup_dir/" 2>/dev/null || true
        print_success "证书已备份到: $backup_dir"
    else
        print_info "未找到现有证书，跳过备份"
    fi
}

# 验证证书文件
validate_certificate() {
    local cert_path=$1
    local key_path=$2
    
    # 检查文件是否存在
    if [[ ! -f "$cert_path" ]]; then
        print_error "证书文件不存在: $cert_path"
        return 1
    fi
    
    if [[ ! -f "$key_path" ]]; then
        print_error "私钥文件不存在: $key_path"
        return 1
    fi
    
    # 检查证书格式
    if ! openssl x509 -in "$cert_path" -text -noout &>/dev/null; then
        print_error "证书文件格式无效: $cert_path"
        return 1
    fi
    
    # 检查私钥格式
    if ! openssl rsa -in "$key_path" -check -noout &>/dev/null 2>&1 && ! openssl ec -in "$key_path" -check -noout &>/dev/null 2>&1; then
        print_error "私钥文件格式无效: $key_path"
        return 1
    fi
    
    # 检查证书和私钥是否匹配
    local cert_modulus=$(openssl x509 -noout -modulus -in "$cert_path" 2>/dev/null | openssl md5)
    local key_modulus=""
    
    # 尝试RSA私钥
    if openssl rsa -noout -modulus -in "$key_path" &>/dev/null; then
        key_modulus=$(openssl rsa -noout -modulus -in "$key_path" 2>/dev/null | openssl md5)
    # 尝试EC私钥
    elif openssl ec -noout -in "$key_path" &>/dev/null; then
        # EC证书验证方式不同，这里简化处理
        print_info "检测到EC证书，跳过模数匹配验证"
        return 0
    fi
    
    if [[ -n "$key_modulus" ]] && [[ "$cert_modulus" != "$key_modulus" ]]; then
        print_error "证书和私钥不匹配"
        return 1
    fi
    
    print_success "证书验证通过"
    return 0
}

# 显示证书信息
show_certificate_info() {
    local cert_path=$1
    
    print_info "证书信息："
    echo "----------------------------------------"
    
    # 显示证书基本信息
    local subject=$(openssl x509 -noout -subject -in "$cert_path" 2>/dev/null | sed 's/subject=//')
    local issuer=$(openssl x509 -noout -issuer -in "$cert_path" 2>/dev/null | sed 's/issuer=//')
    local not_before=$(openssl x509 -noout -startdate -in "$cert_path" 2>/dev/null | sed 's/notBefore=//')
    local not_after=$(openssl x509 -noout -enddate -in "$cert_path" 2>/dev/null | sed 's/notAfter=//')
    
    echo "主体: $subject"
    echo "颁发者: $issuer"
    echo "有效期开始: $not_before"
    echo "有效期结束: $not_after"
    
    # 检查证书是否即将过期
    local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
    local current_date=$(date +%s)
    local days_left=$(( (expiry_date - current_date) / 86400 ))
    
    if [[ $days_left -lt 0 ]]; then
        print_error "证书已过期！"
    elif [[ $days_left -lt 30 ]]; then
        print_warning "证书将在 $days_left 天后过期"
    else
        print_success "证书有效期还剩 $days_left 天"
    fi
    
    echo "----------------------------------------"
}

# 更新证书文件
update_certificates() {
    local cert_path=$1
    local key_path=$2
    
    print_info "正在更新证书文件..."
    
    # 复制新证书文件
    cp "$cert_path" /root/nginx/cert/cert.crt
    cp "$key_path" /root/nginx/cert/cert.key
    
    # 设置正确的权限
    chmod 644 /root/nginx/cert/cert.crt
    chmod 600 /root/nginx/cert/cert.key
    
    print_success "证书文件更新完成"
}

# 测试nginx配置
test_nginx_config() {
    print_info "正在测试nginx配置..."
    
    if docker exec gateway nginx -t &>/dev/null; then
        print_success "nginx配置测试通过"
        return 0
    else
        print_error "nginx配置测试失败"
        return 1
    fi
}

# 重启nginx服务
restart_nginx() {
    print_info "正在重启nginx服务..."
    
    # 先测试配置
    if ! test_nginx_config; then
        print_error "配置测试失败，不执行重启"
        return 1
    fi
    
    # 重新加载nginx配置
    if docker exec gateway nginx -s reload &>/dev/null; then
        print_success "nginx配置已重新加载"
    else
        print_warning "配置重新加载失败，尝试重启容器..."
        docker restart gateway
        print_success "nginx容器已重启"
    fi
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep "gateway" | grep -q "Up"; then
        print_success "nginx服务运行正常"
        return 0
    else
        print_error "nginx服务启动失败"
        return 1
    fi
}

# 检查HTTPS连接
check_https_connection() {
    print_info "正在检查HTTPS连接..."
    
    # 从nginx配置中获取域名
    local domain=$(grep "server_name" /root/nginx/443.conf 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/;//')
    
    if [[ -z "$domain" ]] || [[ "$domain" == "localhost" ]]; then
        print_warning "未配置域名或使用localhost，跳过HTTPS连接测试"
        return 0
    fi
    
    print_info "正在测试域名: $domain"
    
    # 测试HTTPS连接
    if curl -k -s -o /dev/null -w "%{http_code}" "https://$domain" | grep -q "200\|301\|302"; then
        print_success "HTTPS连接测试成功"
        echo -e "${GREEN}访问地址: https://$domain${NC}"
    else
        print_warning "HTTPS连接测试失败，请检查域名解析和防火墙设置"
        print_info "您仍可以通过IP地址访问: https://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP')"
    fi
}

# 主菜单
show_menu() {
    echo -e "${BLUE}"
    echo "=================================="
    echo "    N8N HTTPS证书更新脚本 v1.0"
    echo "=================================="
    echo -e "${NC}"
    
    echo "请选择操作："
    echo "1) 更新证书文件"
    echo "2) 查看当前证书信息"
    echo "3) 测试HTTPS连接"
    echo "4) 退出"
    echo ""
}

# 处理证书更新
handle_certificate_update() {
    echo ""
    print_info "请粘贴SSL证书内容："
    print_warning "粘贴完成后，在新行输入 'END' 并按回车结束"
    echo ""
    echo "请粘贴证书内容（包含 -----BEGIN CERTIFICATE----- 和 -----END CERTIFICATE-----）："
    
    local cert_content=""
    local line=""
    while IFS= read -r line; do
        if [[ "$line" == "END" ]]; then
            break
        fi
        cert_content+="$line"$'\n'
    done
    
    if [[ -z "$cert_content" ]]; then
        print_error "证书内容为空"
        return 1
    fi
    
    echo ""
    print_info "请粘贴私钥内容："
    print_warning "粘贴完成后，在新行输入 'END' 并按回车结束"
    echo ""
    echo "请粘贴私钥内容（包含 -----BEGIN PRIVATE KEY----- 和 -----END PRIVATE KEY-----）："
    
    local key_content=""
    while IFS= read -r line; do
        if [[ "$line" == "END" ]]; then
            break
        fi
        key_content+="$line"$'\n'
    done
    
    if [[ -z "$key_content" ]]; then
        print_error "私钥内容为空"
        return 1
    fi
    
    # 创建临时文件进行验证
    local temp_cert=$(mktemp)
    local temp_key=$(mktemp)
    
    echo "$cert_content" > "$temp_cert"
    echo "$key_content" > "$temp_key"
    
    # 验证证书
    if ! validate_certificate "$temp_cert" "$temp_key"; then
        print_error "证书验证失败，更新已取消"
        rm -f "$temp_cert" "$temp_key"
        return 1
    fi
    
    # 显示证书信息
    show_certificate_info "$temp_cert"
    
    # 确认更新
    echo ""
    while true; do
        read -p "确认要更新证书吗？(y/n): " confirm
        case $confirm in
            [Yy]* ) break;;
            [Nn]* ) 
                print_info "证书更新已取消"
                rm -f "$temp_cert" "$temp_key"
                return 0;;
            * ) print_warning "请输入 y 或 n";;
        esac
    done
    
    # 备份现有证书
    backup_existing_certs
    
    # 更新证书
    update_certificates "$temp_cert" "$temp_key"
    
    # 清理临时文件
    rm -f "$temp_cert" "$temp_key"
    
    # 重启nginx
    if restart_nginx; then
        print_success "证书更新完成！"
        check_https_connection
    else
        print_error "nginx重启失败，请检查配置"
        return 1
    fi
}

# 查看当前证书信息
view_current_certificate() {
    local current_cert="/root/nginx/cert/cert.crt"
    
    if [[ ! -f "$current_cert" ]]; then
        print_warning "未找到当前证书文件"
        return 1
    fi
    
    show_certificate_info "$current_cert"
}

# 主函数
main() {
    # 检查系统环境
    print_info "检查系统环境..."
    check_nginx_container
    check_cert_directory
    
    # 显示菜单并处理用户选择
    while true; do
        show_menu
        read -p "请选择操作 (1-4): " choice
        
        case $choice in
            1)
                handle_certificate_update
                ;;
            2)
                view_current_certificate
                ;;
            3)
                check_https_connection
                ;;
            4)
                print_info "退出脚本"
                exit 0
                ;;
            *)
                print_warning "无效选择，请输入 1-4"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..." 
        clear
    done
}

# 运行主函数
main "$@"
