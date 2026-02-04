/** @type {import('next').NextConfig} */
const nextConfig = {
  // Disable React strict mode for SSE compatibility
  reactStrictMode: false,

  // Experimental features for better serverless performance
  experimental: {
    // Optimize serverless function size
    outputFileTracingIncludes: {
      '/api/**/*': ['./src/prompts/**/*'],
    },
  },
};

module.exports = nextConfig;
