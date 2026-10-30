/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    // AI 生成可能超過預設 30 秒代理逾時；需大於前端 120 秒逾時
    proxyTimeout: 130_000,
  },
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${process.env.NEXT_PUBLIC_API_BASE || "http://localhost:8000"}/api/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
