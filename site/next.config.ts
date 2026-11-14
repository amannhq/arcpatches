import type { NextConfig } from "next";

// Static export for GitHub Pages: https://amannhq.github.io/arcpatches/
const nextConfig: NextConfig = {
  output: "export",
  basePath: "/arcpatches",
  trailingSlash: true,
  images: { unoptimized: true },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
