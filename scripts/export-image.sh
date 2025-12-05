#!/bin/bash

# ============================================
# Docker 镜像导出脚本
# 用途：将构建好的镜像导出为 tar.gz 文件，用于离线部署
# 作者：Claude Code
# ============================================

set -e  # 遇到错误立即退出

# ============================================
# 配置变量
# ============================================
IMAGE_NAME="agent-chat-ui"
VERSION="${1:-latest}"  # 默认版本 latest，可通过参数指定
OUTPUT_DIR="./docker-images"
TAR_FILE="$OUTPUT_DIR/$IMAGE_NAME-$VERSION.tar"
GZ_FILE="$TAR_FILE.gz"

echo "============================================"
echo "开始导出 Docker 镜像"
echo "镜像名称: $IMAGE_NAME:$VERSION"
echo "导出目录: $OUTPUT_DIR"
echo "============================================"

# ============================================
# 检查镜像是否存在
# ============================================
echo ""
echo "检查镜像是否存在..."

if ! docker images | grep -q "$IMAGE_NAME.*$VERSION"; then
    echo "❌ 错误: 镜像 $IMAGE_NAME:$VERSION 不存在"
    echo "请先运行构建脚本: ./scripts/build-arm.sh"
    exit 1
fi

echo "✅ 镜像存在"
docker images | grep "$IMAGE_NAME" | grep "$VERSION"

# ============================================
# 创建输出目录
# ============================================
echo ""
echo "创建输出目录..."
mkdir -p "$OUTPUT_DIR"
echo "✅ 目录已创建: $OUTPUT_DIR"

# ============================================
# 导出镜像为 tar 文件
# ============================================
echo ""
echo "导出镜像为 tar 文件..."
echo "⏳ 这可能需要 2-5 分钟，请耐心等待..."

# 删除旧文件（如果存在）
if [ -f "$TAR_FILE" ]; then
    echo "删除旧的 tar 文件..."
    rm -f "$TAR_FILE"
fi

if [ -f "$GZ_FILE" ]; then
    echo "删除旧的 gz 文件..."
    rm -f "$GZ_FILE"
fi

# 导出镜像
docker save -o "$TAR_FILE" "$IMAGE_NAME:$VERSION"

if [ -f "$TAR_FILE" ]; then
    echo "✅ tar 文件已生成"
    TAR_SIZE=$(du -h "$TAR_FILE" | cut -f1)
    echo "文件大小: $TAR_SIZE"
else
    echo "❌ 错误: tar 文件生成失败"
    exit 1
fi

# ============================================
# 压缩为 gzip 文件
# ============================================
echo ""
echo "压缩为 gzip 格式..."
echo "⏳ 这可能需要 1-3 分钟，请耐心等待..."

gzip -f "$TAR_FILE"

if [ -f "$GZ_FILE" ]; then
    echo "✅ gzip 文件已生成"
    GZ_SIZE=$(du -h "$GZ_FILE" | cut -f1)
    echo "压缩后大小: $GZ_SIZE"
else
    echo "❌ 错误: gzip 文件生成失败"
    exit 1
fi

# ============================================
# 生成 MD5 校验和（可选）
# ============================================
echo ""
echo "生成 MD5 校验和..."
if command -v md5sum &> /dev/null; then
    md5sum "$GZ_FILE" > "$GZ_FILE.md5"
    echo "✅ MD5 文件已生成"
    cat "$GZ_FILE.md5"
elif command -v md5 &> /dev/null; then
    md5 "$GZ_FILE" > "$GZ_FILE.md5"
    echo "✅ MD5 文件已生成"
    cat "$GZ_FILE.md5"
else
    echo "⚠️  跳过 MD5 生成（未找到 md5sum 或 md5 命令）"
fi

# ============================================
# 显示导出结果
# ============================================
echo ""
echo "============================================"
echo "🎉 镜像导出成功！"
echo "============================================"
echo ""
echo "导出文件:"
ls -lh "$OUTPUT_DIR"

echo ""
echo "文件路径:"
echo "  $GZ_FILE"

# ============================================
# 下一步提示
# ============================================
echo ""
echo "============================================"
echo "下一步操作："
echo "============================================"
echo ""
echo "1. 上传到服务器（使用 scp）:"
echo "   scp $GZ_FILE user@server:/opt/docker/"
echo ""
echo "2. 或使用 rsync（支持断点续传）:"
echo "   rsync -avz --progress $GZ_FILE user@server:/opt/docker/"
echo ""
echo "3. 或复制到 U 盘（完全离线）:"
echo "   cp $GZ_FILE /Volumes/USB/"
echo ""
echo "4. 服务器部署:"
echo "   - 将 $GZ_FILE 和 scripts/deploy-server.sh 上传到服务器"
echo "   - 在服务器上运行: ./deploy-server.sh"
echo ""
