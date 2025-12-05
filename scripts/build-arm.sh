#!/bin/bash

# ============================================
# Docker ARM64 镜像构建脚本
# 用途：在 Mac 上构建适用于 Linux ARM 服务器的镜像
# 作者：Claude Code
# ============================================

set -e  # 遇到错误立即退出

# ============================================
# 配置变量
# ============================================
IMAGE_NAME="agent-chat-ui"
VERSION="${1:-latest}"  # 默认版本 latest，可通过参数指定
PLATFORM="linux/arm64"

echo "============================================"
echo "开始构建 Docker 镜像"
echo "镜像名称: $IMAGE_NAME"
echo "版本标签: $VERSION"
echo "目标平台: $PLATFORM"
echo "============================================"

# ============================================
# 检查 Docker 是否安装
# ============================================
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未找到 Docker，请先安装 Docker Desktop"
    exit 1
fi

echo "✅ Docker 已安装: $(docker --version)"

# ============================================
# 检查并设置 Docker Buildx
# ============================================
echo ""
echo "检查 Docker Buildx..."

# 检查 buildx 是否可用
if ! docker buildx version &> /dev/null; then
    echo "❌ 错误: Docker Buildx 不可用，请更新 Docker Desktop"
    exit 1
fi

echo "✅ Docker Buildx 已安装: $(docker buildx version)"

# 创建并使用 buildx builder（如果不存在）
if ! docker buildx inspect arm-builder &> /dev/null; then
    echo "创建 buildx builder: arm-builder"
    docker buildx create --name arm-builder --use --platform $PLATFORM
else
    echo "使用现有 builder: arm-builder"
    docker buildx use arm-builder
fi

# ============================================
# 构建镜像
# ============================================
echo ""
echo "开始构建镜像..."
echo "⏳ 这可能需要 5-10 分钟，请耐心等待..."

docker buildx build \
    --platform $PLATFORM \
    --tag $IMAGE_NAME:$VERSION \
    --tag $IMAGE_NAME:latest \
    --load \
    --progress=plain \
    .

# ============================================
# 验证镜像
# ============================================
echo ""
echo "============================================"
echo "构建完成！验证镜像信息..."
echo "============================================"

# 检查镜像是否存在
if docker images | grep -q "$IMAGE_NAME"; then
    echo "✅ 镜像已创建:"
    docker images | grep "$IMAGE_NAME" | head -n 2
else
    echo "❌ 错误: 镜像创建失败"
    exit 1
fi

# 验证镜像架构
echo ""
echo "验证镜像架构..."
ARCH=$(docker inspect $IMAGE_NAME:$VERSION | grep -A 5 '"Architecture"' | grep '"Architecture"' | awk '{print $2}' | tr -d '",')
echo "镜像架构: $ARCH"

if [ "$ARCH" = "arm64" ]; then
    echo "✅ 架构验证通过！"
else
    echo "⚠️  警告: 镜像架构为 $ARCH，不是预期的 arm64"
fi

# 显示镜像详细信息
echo ""
echo "镜像详细信息:"
docker inspect $IMAGE_NAME:$VERSION | grep -E '"Architecture"|"Os"|"Size"' | head -n 3

# ============================================
# 下一步提示
# ============================================
echo ""
echo "============================================"
echo "🎉 镜像构建成功！"
echo "============================================"
echo ""
echo "下一步操作："
echo "1. 导出镜像为 tar 包:"
echo "   ./scripts/export-image.sh $VERSION"
echo ""
echo "2. 或直接测试镜像（仅限 Mac M1/M2）:"
echo "   docker run -p 3000:3000 --env-file .env $IMAGE_NAME:$VERSION"
echo ""
echo "3. 或使用 docker-compose 启动:"
echo "   docker-compose up -d"
echo ""
