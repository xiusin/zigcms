#!/bin/bash

# 安全告警/通知集成测试脚本
# 用途：快速测试安全模块是否正确集成
# 使用：chmod +x test-security-integration.sh && ./test-security-integration.sh

set -e

echo "=========================================="
echo "  安全告警/通知集成测试"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试计数
total_tests=0
passed_tests=0
failed_tests=0

# 测试函数
test_file() {
    local file=$1
    local desc=$2
    total_tests=$((total_tests + 1))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $desc"
        passed_tests=$((passed_tests + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $desc ${RED}(文件不存在: $file)${NC}"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

test_content() {
    local file=$1
    local pattern=$2
    local desc=$3
    total_tests=$((total_tests + 1))
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} $desc ${RED}(文件不存在: $file)${NC}"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
    
    if grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} $desc"
        passed_tests=$((passed_tests + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $desc ${RED}(未找到: $pattern)${NC}"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# 测试 1: 检查核心文件
echo -e "${BLUE}[测试 1/6]${NC} 检查核心文件..."
echo ""

test_file "ecom-admin/src/api/security.ts" "安全 API 客户端"
test_file "ecom-admin/src/types/security.d.ts" "安全类型定义"
test_file "ecom-admin/src/store/modules/security/index.ts" "安全 Store"
test_file "ecom-admin/src/components/security/AlertNotification.vue" "通知组件"
test_file "ecom-admin/src/views/security/events/index.vue" "事件列表页面"
test_file "ecom-admin/src/router/modules/security.ts" "安全路由配置"

echo ""

# 测试 2: 检查路由集成
echo -e "${BLUE}[测试 2/6]${NC} 检查路由集成..."
echo ""

test_content "ecom-admin/src/router/index.ts" "from './modules/security'" "安全路由导入"
test_content "ecom-admin/src/router/index.ts" "securityRoutes" "安全路由注册"

echo ""

# 测试 3: 检查 Store 初始化
echo -e "${BLUE}[测试 3/6]${NC} 检查 Store 初始化..."
echo ""

test_content "ecom-admin/src/main.ts" "useSecurityStore" "Store 导入"
test_content "ecom-admin/src/main.ts" "startRealtimePolling" "实时轮询启动"

echo ""

# 测试 4: 检查 Header 集成
echo -e "${BLUE}[测试 4/6]${NC} 检查 Header 集成..."
echo ""

# 查找 Header 文件
header_file=""
if [ -f "ecom-admin/src/layout/components/Header.vue" ]; then
    header_file="ecom-admin/src/layout/components/Header.vue"
elif [ -f "ecom-admin/src/layouts/components/Header.vue" ]; then
    header_file="ecom-admin/src/layouts/components/Header.vue"
elif [ -f "ecom-admin/src/components/layout/Header.vue" ]; then
    header_file="ecom-admin/src/components/layout/Header.vue"
fi

if [ -n "$header_file" ]; then
    test_content "$header_file" "AlertNotification" "通知组件导入"
else
    echo -e "${YELLOW}⚠${NC} 未找到 Header.vue，跳过测试"
fi

echo ""

# 测试 5: 检查声音文件
echo -e "${BLUE}[测试 5/6]${NC} 检查声音文件..."
echo ""

if [ -d "ecom-admin/public/sounds" ]; then
    echo -e "${GREEN}✓${NC} sounds 目录存在"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${YELLOW}⚠${NC} sounds 目录不存在"
fi
total_tests=$((total_tests + 1))

if [ -f "ecom-admin/public/sounds/alert.mp3" ]; then
    echo -e "${GREEN}✓${NC} 告警声音文件存在"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${YELLOW}⚠${NC} 告警声音文件不存在（可选）"
fi
total_tests=$((total_tests + 1))

echo ""

# 测试 6: 检查后端路由
echo -e "${BLUE}[测试 6/6]${NC} 检查后端路由..."
echo ""

test_content "src/api/bootstrap.zig" "/api/quality/statistics/overview" "质量中心路由"
test_content "src/api/bootstrap.zig" "registerSecurityRoutes" "安全路由注册函数"

echo ""

# 测试总结
echo "=========================================="
echo "  测试结果总结"
echo "=========================================="
echo ""
echo "总测试数: $total_tests"
echo -e "通过: ${GREEN}$passed_tests${NC}"
echo -e "失败: ${RED}$failed_tests${NC}"
echo ""

# 计算通过率
pass_rate=$((passed_tests * 100 / total_tests))

if [ $failed_tests -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    echo ""
    echo "下一步："
    echo "1. 启动后端: zig build run"
    echo "2. 启动前端: cd ecom-admin && npm run dev"
    echo "3. 访问: http://localhost:5173/security/dashboard"
    exit 0
elif [ $pass_rate -ge 80 ]; then
    echo -e "${YELLOW}⚠ 大部分测试通过 ($pass_rate%)${NC}"
    echo ""
    echo "建议："
    echo "1. 检查失败的测试项"
    echo "2. 参考 INTEGRATION_GUIDE.md 完成集成"
    echo "3. 重新运行测试"
    exit 1
else
    echo -e "${RED}✗ 测试失败 ($pass_rate%)${NC}"
    echo ""
    echo "请执行以下步骤："
    echo "1. 运行集成脚本: ./integrate-security-frontend.sh"
    echo "2. 参考 INTEGRATION_GUIDE.md 手动完成集成"
    echo "3. 重新运行测试"
    exit 1
fi
