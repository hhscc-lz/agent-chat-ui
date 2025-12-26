#!/bin/bash

# ============================================
# 服务器部署脚本（Linux ARM64）
# 用途：在服务器上导入镜像并启动容器
# 作者：Claude Code
# 使用：./deploy-server.sh [镜像文件路径]
# ============================================

set -e  # 遇到错误立即退出

# ============================================
# 配置变量
# ============================================
IMAGE_NAME="agent-chat-ui"
VERSION="v0.0.1"
CONTAINER_NAME="agent-chat-ui"
PORT="8893"

# 镜像文件路径（可通过参数指定，默认查找最新的 tar.gz）
if [ -n "$1" ]; then
    IMAGE_FILE="$1"
else
    # 自动查找最新的 tar.gz 文件
    IMAGE_FILE=$(ls -t agent-chat-ui-*.tar.gz 2>/dev/null | head -n 1)
    if [ -z "$IMAGE_FILE" ]; then
        echo "❌ 错误: 未找到 agent-chat-ui-*.tar.gz 文件"
        echo "请确保镜像文件存在，或手动指定路径："
        echo "  ./deploy-server.sh /path/to/agent-chat-ui-v0.0.1.tar.gz"
        exit 1
    fi
    echo "🔍 自动检测到最新镜像: $IMAGE_FILE"
fi

echo "============================================"
echo "Agent Chat UI 服务器部署脚本"
echo "============================================"
echo "镜像文件: $IMAGE_FILE"
echo "容器名称: $CONTAINER_NAME"
echo "监听端口: $PORT"
echo "============================================"

# ============================================
# 检查 Docker 是否安装
# ============================================
echo ""
echo "1. 检查 Docker 环境..."

if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未找到 Docker"
    echo "请先安装 Docker: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

echo "✅ Docker 已安装: $(docker --version)"

# 检查 Docker 服务是否运行
if ! docker ps &> /dev/null; then
    echo "❌ 错误: Docker 服务未运行"
    echo "请启动 Docker 服务: sudo systemctl start docker"
    exit 1
fi

echo "✅ Docker 服务运行正常"

# ============================================
# 检查镜像文件是否存在
# ============================================
echo ""
echo "2. 检查镜像文件..."

if [ ! -f "$IMAGE_FILE" ]; then
    echo "❌ 错误: 镜像文件不存在: $IMAGE_FILE"
    echo ""
    echo "请确保已上传镜像文件到服务器，或指定正确路径："
    echo "  ./deploy-server.sh /path/to/agent-chat-ui-latest.tar.gz"
    exit 1
fi

echo "✅ 镜像文件存在"
echo "文件大小: $(du -h $IMAGE_FILE | cut -f1)"

# ============================================
# 解压镜像文件
# ============================================
echo ""
echo "3. 解压镜像文件..."

# 检查文件扩展名
if [[ "$IMAGE_FILE" == *.tar.gz ]]; then
    echo "⏳ 解压 gzip 文件..."
    TAR_FILE="${IMAGE_FILE%.gz}"
    gunzip -f -k "$IMAGE_FILE"
    IMAGE_FILE="$TAR_FILE"
    echo "✅ 解压完成: $IMAGE_FILE"
elif [[ "$IMAGE_FILE" == *.tar ]]; then
    echo "✅ tar 文件无需解压"
else
    echo "❌ 错误: 不支持的文件格式（仅支持 .tar 或 .tar.gz）"
    exit 1
fi

# ============================================
# 导入镜像
# ============================================
echo ""
echo "4. 导入 Docker 镜像..."
echo "⏳ 这可能需要 1-3 分钟，请耐心等待..."

docker load -i "$IMAGE_FILE"

echo "✅ 镜像导入成功"

# 验证镜像
echo ""
echo "验证导入的镜像:"
docker images | grep "$IMAGE_NAME" || {
    echo "❌ 错误: 未找到导入的镜像"
    exit 1
}

# ============================================
# 停止并删除旧容器
# ============================================
echo ""
echo "5. 清理旧容器..."

if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "发现旧容器，正在停止并删除..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    echo "✅ 旧容器已清理"
else
    echo "✅ 无需清理"
fi

# ============================================
# 启动容器
# ============================================
echo ""
echo "6. 启动容器..."

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "$PORT:3000" \
    "$IMAGE_NAME:$VERSION"

echo "✅ 容器已启动"

# ============================================
# 等待服务就绪
# ============================================
echo ""
echo "7. 等待服务启动..."
sleep 5

# 检查容器状态
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "✅ 容器运行正常"
else
    echo "❌ 错误: 容器未运行"
    echo "查看日志:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# ============================================
# 健康检查
# ============================================
echo ""
echo "8. 健康检查..."

# 尝试访问服务
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f -s http://localhost:$PORT > /dev/null; then
        echo "✅ 服务健康检查通过"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "⏳ 等待服务就绪... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 3
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "⚠️  警告: 服务未能在预期时间内响应"
    echo "请检查日志: docker logs $CONTAINER_NAME"
fi

# ============================================
# 显示部署信息
# ============================================
echo ""
echo "============================================"
echo "🎉 部署成功！"
echo "============================================"
echo ""
echo "容器信息:"
docker ps | grep "$CONTAINER_NAME"

echo ""
echo "访问地址:"
echo "  http://localhost:$PORT"
echo "  http://$(hostname -I | awk '{print $1}'):$PORT"

echo ""
echo "常用命令:"
echo "  查看日志:   docker logs -f $CONTAINER_NAME"
echo "  停止服务:   docker stop $CONTAINER_NAME"
echo "  启动服务:   docker start $CONTAINER_NAME"
echo "  重启服务:   docker restart $CONTAINER_NAME"
echo "  删除容器:   docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"

echo ""
echo "使用 docker-compose:"
echo "  如果你上传了 docker-compose.yml，可以使用:"
echo "  docker-compose up -d    # 启动"
echo "  docker-compose down     # 停止"
echo "  docker-compose logs -f  # 查看日志"

echo ""
echo "============================================"
