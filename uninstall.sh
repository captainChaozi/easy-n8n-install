#!/bin/bash

# N8N 一键卸载脚本
# 用于完全清理N8N相关的Docker容器、存储卷和文件

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

# 确认卸载
confirm_uninstall() {
    echo -e "${RED}"
    echo "=================================="
    echo "     N8N 一键卸载脚本 v1.0"
    echo "=================================="
    echo -e "${NC}"
    
    print_warning "此操作将完全删除N8N相关的所有数据，包括："
    echo "  • 所有Docker容器（n8n、postgres、redis、nginx）"
    echo "  • 所有数据存储卷（数据库、工作流、Redis缓存）"
    echo "  • nginx配置文件和SSL证书"
    echo "  • 环境变量文件"
    echo ""
    print_error "注意：此操作不可逆，所有数据将永久丢失！"
    echo ""
    
    while true; do
        read -p "确认要卸载N8N吗？(yes/no): " confirm
        case $confirm in
            yes|YES ) break;;
            no|NO ) 
                print_info "卸载操作已取消"
                exit 0;;
            * ) print_warning "请输入 yes 或 no";;
        esac
    done
}

# 停止N8N相关容器
stop_n8n_containers() {
    print_info "正在停止N8N相关容器..."
    
    # 检查是否在项目目录
    if [[ -d "n8n-start" ]]; then
        cd n8n-start
        
        # 停止docker-compose服务
        if [[ -f "docker-compose.yml" ]]; then
            docker compose down 2>/dev/null || true
            print_success "N8N服务容器已停止"
        else
            print_warning "未找到docker-compose.yml文件"
        fi
        
        cd ..
    else
        print_warning "未找到n8n-start目录"
    fi
}

# 停止nginx容器
stop_nginx_container() {
    print_info "正在停止nginx容器..."
    
    # 停止gateway容器
    if docker ps -a --format "table {{.Names}}" | grep -q "^gateway$"; then
        docker stop gateway 2>/dev/null || true
        docker rm gateway 2>/dev/null || true
        print_success "nginx容器已停止并删除"
    else
        print_info "nginx容器不存在或已停止"
    fi
}

# 删除Docker存储卷
remove_docker_volumes() {
    print_info "正在删除Docker存储卷..."
    
    # 获取项目名称（通常是目录名）
    local project_name=$(basename "$(pwd)")
    
    # 删除相关的存储卷
    local volumes_to_remove=(
        "${project_name}_db_storage"
        "${project_name}_n8n_storage" 
        "${project_name}_redis_storage"
        "n8n-start_db_storage"
        "n8n-start_n8n_storage"
        "n8n-start_redis_storage"
    )
    
    for volume in "${volumes_to_remove[@]}"; do
        if docker volume ls --format "{{.Name}}" | grep -q "^${volume}$"; then
            docker volume rm "$volume" 2>/dev/null || true
            print_success "已删除存储卷: $volume"
        fi
    done
    
    # 删除所有未使用的卷
    print_info "清理未使用的Docker卷..."
    docker volume prune -f 2>/dev/null || true
}

# 删除Docker镜像（可选）
remove_docker_images() {
    echo ""
    while true; do
        read -p "是否要删除N8N相关的Docker镜像？(y/n): " remove_images
        case $remove_images in
            [Yy]* ) 
                print_info "正在删除Docker镜像..."
                
                # 删除N8N镜像
                docker rmi chaozi/n8n:1.109.2-chinese 2>/dev/null || true
                docker rmi postgres:16 2>/dev/null || true
                docker rmi redis:6-alpine 2>/dev/null || true
                docker rmi nginx 2>/dev/null || true
                
                print_success "Docker镜像清理完成"
                break;;
            [Nn]* ) 
                print_info "保留Docker镜像"
                break;;
            * ) print_warning "请输入 y 或 n";;
        esac
    done
}

# 清理文件和目录
cleanup_files() {
    print_info "正在清理配置文件和目录..."
    
    # 删除nginx配置目录
    if [[ -d "/root/nginx" ]]; then
        rm -rf /root/nginx
        print_success "已删除nginx配置目录: /root/nginx"
    fi
    
    # 删除环境变量文件
    if [[ -f "n8n-start/.env" ]]; then
        rm -f n8n-start/.env
        print_success "已删除环境变量文件: n8n-start/.env"
    fi
    
    # 询问是否删除整个项目目录
    echo ""
    while true; do
        read -p "是否要删除整个项目目录？(y/n): " remove_project
        case $remove_project in
            [Yy]* )
                local current_dir=$(pwd)
                cd ..
                rm -rf "$current_dir"
                print_success "已删除项目目录: $current_dir"
                print_info "卸载完成，脚本将退出"
                exit 0;;
            [Nn]* )
                print_info "保留项目目录"
                break;;
            * ) print_warning "请输入 y 或 n";;
        esac
    done
}

# 最终清理Docker系统
cleanup_docker_system() {
    print_info "正在清理Docker系统..."
    
    # 清理未使用的容器
    docker container prune -f 2>/dev/null || true
    
    # 清理未使用的网络
    docker network prune -f 2>/dev/null || true
    
    print_success "Docker系统清理完成"
}

# 主函数
main() {
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，无需卸载"
        exit 1
    fi
    
    # 确认卸载
    confirm_uninstall
    
    print_info "开始卸载N8N..."
    
    # 步骤1: 停止所有容器
    stop_n8n_containers
    stop_nginx_container
    
    # 步骤2: 删除存储卷
    remove_docker_volumes
    
    # 步骤3: 清理文件
    cleanup_files
    
    
    # 步骤5: 最终清理
    cleanup_docker_system
    
    echo ""
    print_success "N8N卸载完成！"
    echo -e "${GREEN}所有相关容器、存储卷和配置文件已删除${NC}"
    echo ""
    print_info "如需重新安装，请运行: bash start_n8n.sh"
}

# 运行主函数
main "$@"
