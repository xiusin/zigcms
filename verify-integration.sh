#!/bin/bash

# 安全告警/通知功能集成验证脚本
# 用于验证所有集成步骤是否正确完成

echo "=========================================="
echo "  安全告警/通知功能集成验证"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 计数器
PASS=0
FAIL=0

# 检查函数
check_file() {
    local file=$1
    local desc=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $desc"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $desc"
        echo -e "  ${YELLOW}文件不存在: $file${NC}"
        ((FAIL++))
        return 1
    fi
}

check_content() {
    local file=$1
    local pattern=$2
    local desc=$3
    
    if [ -f "$file" ] && grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} $desc"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $desc"
        echo -e "  ${YELLOW}未找到内容: $pattern${NC}"
        echo -e "  ${YELLOW}文件: $file${NC}"
        ((FAIL++))
        return 1
    fi
}

echo "1. 检查核心文件..."
echo "-------------------------------------------"
check_file "ecom-admin/src/api/security.ts" "API 客户端"
check_file "ecom-admin/src/types/security.d.ts" "类型定义"
check_file "ecom-admin/src/store/modules/security/index.ts" "Store 状态管理"
check_file "ecom-admin/src/components/security/AlertNotification.vue" "通知组件"
check_file "ecom-admin/src/views/security/events/index.vue" "事件列表页面"
check_file "ecom-admin/src/router/modules/security.ts" "安全路由"
echo ""

echo "2. 检查集成配置..."
echo "-------------------------------------------"
check_content "ecom-admin/src/router/routes/index.ts" "import security from './modules/security'" "路由导入"
check_content "ecom-admin/src/router/routes/index.ts" "security," "路由注册"
check_content "ecom-admin/src/components/navbar/index.vue" "import AlertNotification" "导航栏导入"
check_content "ecom-admin/src/components/navbar/index.vue" "<AlertNotification />" "导航栏组件"
check_content "ecom-admin/src/main.ts" "useSecurityStore" "Store 初始化"
check_content "ecom-admin/src/main.ts" "startRealtimePolling" "实时轮询启动"
echo ""

echo "3. 检查文档..."
echo "-------------------------------------------"
check_file "INTEGRATION_GUIDE.md" "集成指南"
check_file "BUSINESS_CLOSURE_COMPLETE.md" "业务闭合文档"
check_file "FINAL_SUMMARY.md" "最终总结"
check_file "INTEGRATION_COMPLETE.md" "集成完成文档"
check_file "ecom-admin/public/sounds/README.md" "声音文件说明"
echo ""

echo "4. 检查已存在的页面..."
echo "-------------------------------------------"
check_file "ecom-admin/src/views/security/dashboard/index.vue" "安全仪表板"
check_file "ecom-admin/src/views/security/alerts/index.vue" "告警管理"
check_file "ecom-admin/src/views/security/audit-log/index.vue" "审计日志"
echo ""

echo "=========================================="
echo "  验证结果"
echo "=========================================="
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ 所有检查通过！集成完成！${NC}"
    echo ""
    echo "下一步："
    echo "1. 启动后端：zig build run"
    echo "2. 启动前端：cd ecom-admin && npm run dev"
    echo "3. 访问系统：http://localhost:5173"
    echo ""
    exit 0
else
    echo -e "${RED}✗ 有 $FAIL 项检查失败，请检查上述错误${NC}"
    echo ""
    exit 1
fi
