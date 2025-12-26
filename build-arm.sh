#!/bin/bash

# ============================================
# Docker ARM64 镜像构建与导出脚本
# 用途：在 Mac 上构建适用于 Linux ARM 服务器的镜像并导出
# 使用：./build-arm.sh [版本号]
# ============================================

set -e  # 遇到错误立即退出

# ============================================
# 配置变量
# ============================================
IMAGE_NAME="agent-chat-ui"
VERSION="${1:-v0.0.1}"  # 默认版本 v0.0.1，可通过参数指定
PLATFORM="linux/arm64"
OUTPUT_DIR="./docker-images"
TAR_FILE="$OUTPUT_DIR/$IMAGE_NAME-$VERSION.tar"
GZ_FILE="$TAR_FILE.gz"

echo "============================================"
echo "Docker 镜像构建与导出"
echo "============================================"
echo "镜像名称: $IMAGE_NAME:$VERSION"
echo "目标平台: $PLATFORM"
echo "导出目录: $OUTPUT_DIR"
echo "============================================"

# ============================================
# 1. 检查 Docker 环境
# ============================================
echo ""
echo "1. 检查 Docker 环境..."

if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未找到 Docker，请先安装 Docker Desktop"
    exit 1
fi
echo "✅ Docker 已安装: $(docker --version)"

if ! docker buildx version &> /dev/null; then
    echo "❌ 错误: Docker Buildx 不可用，请更新 Docker Desktop"
    exit 1
fi
echo "✅ Docker Buildx 已安装"

# ============================================
# 2. 设置 Buildx Builder
# ============================================
echo ""
echo "2. 设置 Buildx Builder..."

if ! docker buildx inspect arm-builder &> /dev/null; then
    echo "创建 buildx builder: arm-builder"
    docker buildx create --name arm-builder --use --platform $PLATFORM
else
    echo "使用现有 builder: arm-builder"
    docker buildx use arm-builder
fi

# ============================================
# 3. 构建镜像
# ============================================
echo ""
echo "3. 构建镜像..."
echo "⏳ 这可能需要 5-10 分钟，请耐心等待..."

docker buildx build \
    --platform $PLATFORM \
    --tag $IMAGE_NAME:$VERSION \
    --load \
    --progress=plain \
    .

# 验证镜像
if docker images | grep -q "$IMAGE_NAME"; then
    echo "✅ 镜像构建成功"
    docker images | grep "$IMAGE_NAME" | head -n 2
else
    echo "❌ 错误: 镜像创建失败"
    exit 1
fi

# 验证架构
ARCH=$(docker inspect $IMAGE_NAME:$VERSION | grep -A 5 '"Architecture"' | grep '"Architecture"' | awk '{print $2}' | tr -d '",')
if [ "$ARCH" = "arm64" ]; then
    echo "✅ 架构验证通过: $ARCH"
else
    echo "⚠️  警告: 镜像架构为 $ARCH，不是预期的 arm64"
fi

# ============================================
# 4. 导出镜像
# ============================================
echo ""
echo "4. 导出镜像为 tar.gz..."

mkdir -p "$OUTPUT_DIR"

# 删除旧文件
[ -f "$TAR_FILE" ] && rm -f "$TAR_FILE"
[ -f "$GZ_FILE" ] && rm -f "$GZ_FILE"

echo "⏳ 导出中..."
docker save -o "$TAR_FILE" "$IMAGE_NAME:$VERSION"

echo "⏳ 压缩中..."
gzip -f "$TAR_FILE"

if [ -f "$GZ_FILE" ]; then
    GZ_SIZE=$(du -h "$GZ_FILE" | cut -f1)
    echo "✅ 导出成功: $GZ_FILE ($GZ_SIZE)"
else
    echo "❌ 错误: 导出失败"
    exit 1
fi

# 生成 MD5
if command -v md5sum &> /dev/null; then
    md5sum "$GZ_FILE" > "$GZ_FILE.md5"
elif command -v md5 &> /dev/null; then
    md5 "$GZ_FILE" > "$GZ_FILE.md5"
fi

# ============================================
# 完成
# ============================================
echo ""
echo "============================================"
echo "🎉 构建并导出成功！"
echo "============================================"
echo ""
echo "导出文件:"
ls -lh "$OUTPUT_DIR" | grep "$VERSION"
echo ""
echo "部署步骤:"
echo "1. 上传到服务器:"
echo "   scp $GZ_FILE deploy-server.sh user@server:/opt/"
echo ""
echo "2. 服务器执行:"
echo "   ./deploy-server.sh"
echo ""
echo "注意: .env 环境变量已打包到镜像中，无需单独上传"
echo ""
