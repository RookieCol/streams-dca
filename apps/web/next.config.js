/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  webpack: (config) => {
    config.externals.push('pino-pretty', 'lokijs', 'encoding')
    // RainbowKit's connectors index eagerly pulls in the Base Account
    // connector, which drags in @coinbase/cdp-sdk's x402 payment code and
    // its (unpublished-to-npm) @x402/evm/* subpath exports. We only use the
    // injected-wallet connector, so this branch is dead code — stub it out
    // rather than chase each missing subpath individually.
    config.resolve.alias['@coinbase/cdp-sdk'] = false
    return config
  },
};

module.exports = nextConfig;
