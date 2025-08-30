/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: ['@scout/ui'],
  experimental: {
    optimizeCss: true,
  },
}

module.exports = nextConfig
