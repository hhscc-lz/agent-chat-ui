# ============================================
# 多阶段构建 Dockerfile for Next.js 15
# 目标架构: Linux ARM64
# 优化: pnpm + standalone 模式
# ============================================

# ============================================
# 阶段 1: 依赖安装
# ============================================
FROM --platform=linux/arm64 node:20-alpine AS deps

# 安装 libc6-compat（Alpine 兼容性）
RUN apk add --no-cache libc6-compat

WORKDIR /app

# 安装 pnpm
RUN corepack enable && corepack prepare pnpm@10.5.1 --activate

# 复制依赖文件
COPY package.json pnpm-lock.yaml ./

# 安装生产依赖
# --frozen-lockfile 确保使用 lock 文件中的精确版本
# --prod 只安装 dependencies，不安装 devDependencies
RUN pnpm install --frozen-lockfile --prod

# ============================================
# 阶段 2: 构建应用
# ============================================
FROM --platform=linux/arm64 node:20-alpine AS builder

WORKDIR /app

# 安装 pnpm
RUN corepack enable && corepack prepare pnpm@10.5.1 --activate

# 复制依赖文件
COPY package.json pnpm-lock.yaml ./

# 安装所有依赖（包括 devDependencies，构建需要）
RUN pnpm install --frozen-lockfile

# 复制源代码
COPY . .

# 设置环境变量（构建时）
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# 构建 Next.js 应用
# standalone 模式会在 .next/standalone 目录生成最小化的运行时文件
RUN pnpm run build

# ============================================
# 阶段 3: 生产运行时
# ============================================
FROM --platform=linux/arm64 node:20-alpine AS runner

WORKDIR /app

# 设置环境变量
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# 创建非 root 用户（安全最佳实践）
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# 复制 public 文件夹（静态资源）
COPY --from=builder /app/public ./public

# 复制 standalone 输出
# Next.js standalone 模式会生成最小化的依赖
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# 切换到非 root 用户
USER nextjs

# 暴露端口
EXPOSE 3000

# 设置默认环境变量（可被运行时覆盖）
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# 健康检查（可选）
# HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
#   CMD node -e "require('http').get('http://localhost:3000', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# 启动应用
# standalone 模式会生成 server.js 作为入口
CMD ["node", "server.js"]
