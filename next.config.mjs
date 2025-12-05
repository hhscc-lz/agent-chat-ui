/** @type {import('next').NextConfig} */
const nextConfig = {
  // 启用 standalone 输出模式（Docker 部署必需）
  // 会在 .next/standalone 生成最小化的运行时文件
  output: "standalone",

  experimental: {
    serverActions: {
      bodySizeLimit: "10mb",
    },
  },
};

export default nextConfig;
