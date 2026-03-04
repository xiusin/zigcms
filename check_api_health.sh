#!/bin/bash

# API 健康检查脚本
# 使用方法: ./check_api_health.sh [BASE_URL]

BASE_URL="${1:-http://localhost:3000}"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "质量中心 API 健康检查"
echo "Base URL: $BASE_URL"
echo "=========================================="
echo ""

# 检查服务是否运行
echo -n "检查服务连接... "
if curl -s -f -o /dev/null "$BASE_URL" 2>/dev/null; then
    echo -e "${GREEN}✓ 服务正常运行${NC}"
else
    echo -e "${RED}✗ 无法连接到服务${NC}"
    echo "请确保后端服务已启动在 $BASE_URL"
    exit 1
fi

# 检查数据库连接
echo -n "检查数据库连接... "
response=$(curl -s "$BASE_URL/api/quality/projects?page=1&page_size=1" 2>/dev/null)
if echo "$response" | grep -q '"code"'; then
    echo -e "${GREEN}✓ 数据库连接正常${NC}"
else
    echo -e "${RED}✗ 数据库连接失败${NC}"
    echo "响应: $response"
    exit 1
fi

# 检查路由注册
echo -n "检查路由注册... "
status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/quality/projects")
if [ "$status" != "404" ]; then
    echo -e "${GREEN}✓ 路由已正确注册${NC}"
else
    echo -e "${RED}✗ 路由未注册或配置错误${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}所有健康检查通过！可以开始 API 测试。${NC}"
echo ""
echo "运行完整测试："
echo "  ./test_quality_center_api.sh $BASE_URL"
echo ""
