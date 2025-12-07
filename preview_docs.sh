#!/bin/bash

# ZigCMS SQL ORM 文档预览脚本

echo "🚀 启动 ZigCMS SQL ORM 文档预览..."
echo ""

# 检查是否有 Python
if command -v python3 &> /dev/null; then
    echo "✓ 使用 Python 启动服务器"
    echo "📖 文档地址: http://localhost:8000"
    echo ""
    echo "按 Ctrl+C 停止服务器"
    echo ""
    cd docs && python3 -m http.server 8000
# 检查是否有 Node.js
elif command -v npx &> /dev/null; then
    echo "✓ 使用 Node.js 启动服务器"
    echo "📖 文档地址: http://localhost:8000"
    echo ""
    echo "按 Ctrl+C 停止服务器"
    echo ""
    npx http-server docs -p 8000
else
    echo "❌ 未找到 Python 或 Node.js"
    echo ""
    echo "请安装以下任一工具："
    echo "  • Python 3: brew install python3"
    echo "  • Node.js: brew install node"
    echo ""
    echo "或直接在浏览器中打开: docs/index.html"
    open docs/index.html 2>/dev/null || echo "无法自动打开浏览器"
fi
