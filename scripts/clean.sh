#!/usr/bin/env bash
# 清理脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🧹 清理 ZigCMS 构建文件...${NC}"

# 清理 Zig 构建缓存
if [ -d ".zig-cache" ]; then
    echo -e "${YELLOW}  清理 .zig-cache...${NC}"
    rm -rf .zig-cache
fi

# 清理输出目录
if [ -d "zig-out" ]; then
    echo -e "${YELLOW}  清理 zig-out...${NC}"
    rm -rf zig-out
fi

# 清理测试数据库
if [ -f "test.db" ]; then
    echo -e "${YELLOW}  清理 test.db...${NC}"
    rm -f test.db
fi

# 清理日志文件
if [ -d "logs" ]; then
    echo -e "${YELLOW}  清理 logs...${NC}"
    rm -rf logs/*.log 2>/dev/null || true
fi

echo -e "${GREEN}✅ 清理完成${NC}"
