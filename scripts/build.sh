#!/usr/bin/env bash
# 构建脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 默认构建模式
BUILD_MODE="${1:-debug}"

echo -e "${GREEN}🔨 构建 ZigCMS (模式: $BUILD_MODE)...${NC}"

case "$BUILD_MODE" in
    debug)
        echo -e "${YELLOW}🐛 调试模式构建...${NC}"
        zig build
        ;;
    release)
        echo -e "${YELLOW}🚀 发布模式构建 (安全优化)...${NC}"
        zig build -Doptimize=ReleaseSafe
        ;;
    fast)
        echo -e "${YELLOW}⚡ 发布模式构建 (性能优化)...${NC}"
        zig build -Doptimize=ReleaseFast
        ;;
    small)
        echo -e "${YELLOW}📦 发布模式构建 (体积优化)...${NC}"
        zig build -Doptimize=ReleaseSmall
        ;;
    *)
        echo -e "${RED}❌ 未知的构建模式: $BUILD_MODE${NC}"
        echo -e "${YELLOW}用法: $0 [debug|release|fast|small]${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ 构建完成${NC}"
echo -e "${YELLOW}📂 输出目录: zig-out/bin/${NC}"
