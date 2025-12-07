#!/bin/bash

# SQLite 测试脚本
# 运行所有 SQLite 相关测试

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║          ZigCMS SQLite 测试套件                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. interface.zig 单元测试
echo -e "${BLUE}[1/4] 运行 interface.zig 单元测试...${NC}"
zig test src/services/sql/interface.zig -lc -lsqlite3
echo -e "${GREEN}✓ interface.zig 测试通过${NC}"
echo ""

# 2. SQLite 基础集成测试
echo -e "${BLUE}[2/4] 运行 SQLite 基础集成测试...${NC}"
zig build-exe src/services/sql/sqlite_test.zig -lc -lsqlite3 -femit-bin=zig-out/sqlite-test
./zig-out/sqlite-test
echo -e "${GREEN}✓ SQLite 基础测试通过${NC}"
echo ""

# 3. ORM 集成测试
echo -e "${BLUE}[3/4] 运行 ORM 集成测试...${NC}"
zig build-exe src/services/sql/orm_test.zig -lc -lsqlite3 -femit-bin=zig-out/orm-test
./zig-out/orm-test
echo -e "${GREEN}✓ ORM 测试通过${NC}"
echo ""

# 4. QueryBuilder 高级功能测试
echo -e "${BLUE}[4/4] 运行 QueryBuilder 高级功能测试...${NC}"
zig build-exe src/services/sql/querybuilder_sqlite_test.zig -lc -lsqlite3 -femit-bin=zig-out/querybuilder-test
./zig-out/querybuilder-test
echo -e "${GREEN}✓ QueryBuilder 高级测试通过${NC}"
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║          ✅ 所有 SQLite 测试通过!                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
