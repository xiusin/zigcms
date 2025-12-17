#!/usr/bin/env bash
# 测试脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🧪 运行 ZigCMS 测试套件...${NC}"

# 检查测试类型参数
TEST_TYPE="${1:-all}"

case "$TEST_TYPE" in
    unit)
        echo -e "${YELLOW}📝 运行单元测试...${NC}"
        zig build test -- lib
        ;;
    integration)
        echo -e "${YELLOW}🔗 运行集成测试...${NC}"
        zig build test -- integration
        ;;
    all)
        echo -e "${YELLOW}🎯 运行所有测试...${NC}"
        zig build test
        ;;
    *)
        echo -e "${RED}❌ 未知的测试类型: $TEST_TYPE${NC}"
        echo -e "${YELLOW}用法: $0 [unit|integration|all]${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ 测试完成${NC}"
