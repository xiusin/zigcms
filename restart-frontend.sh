#!/bin/bash

# 重启前端开发服务器脚本
# 用于清除缓存并重启 Vite 开发服务器

echo "========================================="
echo "重启前端开发服务器"
echo "========================================="
echo ""

# 进入前端目录
cd ecom-admin || exit 1

echo "1. 清除 Vite 缓存..."
rm -rf node_modules/.vite
echo "✅ Vite 缓存已清除"
echo ""

echo "2. 清除 dist 目录..."
rm -rf dist
echo "✅ dist 目录已清除"
echo ""

echo "3. 重启开发服务器..."
echo "提示：按 Ctrl+C 停止服务器"
echo ""

# 启动开发服务器
npm run dev
