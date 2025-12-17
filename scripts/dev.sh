#!/usr/bin/env bash
# 开发环境启动脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 启动 ZigCMS 开发环境...${NC}"

# 检查 Zig 是否安装
if ! command -v zig &> /dev/null; then
    echo -e "${RED}❌ Zig 未安装，请先安装 Zig${NC}"
    exit 1
fi

# 显示 Zig 版本
echo -e "${YELLOW}📦 Zig 版本:${NC}"
zig version

# 检查 .env 文件
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env 文件不存在，从 .env.example 复制...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ .env 文件已创建${NC}"
    else
        echo -e "${RED}❌ .env.example 文件不存在${NC}"
        exit 1
    fi
fi

# 清理旧的构建文件
echo -e "${YELLOW}🧹 清理旧的构建文件...${NC}"
rm -rf zig-out .zig-cache

# 构建项目
echo -e "${YELLOW}🔨 构建项目...${NC}"
zig build || {
    echo -e "${RED}❌ 构建失败${NC}"
    exit 1
}

echo -e "${GREEN}✅ 构建成功${NC}"

# 运行项目
echo -e "${GREEN}🎉 启动服务器...${NC}"
zig build run
