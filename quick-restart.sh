#!/bin/bash

echo "========================================="
echo "快速重启前端（清除缓存）"
echo "========================================="
echo ""

cd ecom-admin || exit 1

echo "✅ 清除 Vite 缓存..."
rm -rf node_modules/.vite

echo "✅ 清除 dist 目录..."
rm -rf dist

echo ""
echo "========================================="
echo "缓存已清除！"
echo "========================================="
echo ""
echo "现在请手动重启开发服务器："
echo "  cd ecom-admin"
echo "  npm run dev"
echo ""
echo "然后访问系统，检查安全管理菜单："
echo "  ✅ 安全监控"
echo "  ✅ 告警管理"
echo "  ✅ 审计日志"
echo "  ✅ 日志管理 ← 应该显示"
echo "  ✅ 黑名单管理 ← 应该显示"
echo ""
