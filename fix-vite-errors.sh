#!/bin/bash

# 修复 Vite 错误脚本
# 用于清除缓存和重启开发服务器

echo "=========================================="
echo "修复 Vite 开发服务器错误"
echo "=========================================="
echo ""

cd ecom-admin

echo "1. 停止开发服务器..."
# 查找并杀死 vite 进程
pkill -f "vite" || echo "没有运行中的 Vite 进程"
echo ""

echo "2. 清除 Vite 缓存..."
rm -rf node_modules/.vite
echo "✅ Vite 缓存已清除"
echo ""

echo "3. 清除浏览器缓存建议..."
echo "请在浏览器中执行以下操作："
echo "  - Chrome/Edge: Ctrl+Shift+Delete 或 Cmd+Shift+Delete"
echo "  - 选择 '缓存的图片和文件'"
echo "  - 点击 '清除数据'"
echo ""

echo "4. 重启开发服务器..."
echo "请手动执行以下命令："
echo "  cd ecom-admin && npm run dev"
echo ""

echo "=========================================="
echo "修复完成！"
echo "=========================================="
echo ""
echo "如果问题仍然存在，请尝试："
echo "  1. 完全关闭浏览器并重新打开"
echo "  2. 使用无痕模式访问"
echo "  3. 检查后端服务是否正常运行"
echo ""
