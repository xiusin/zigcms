zig build -Doptimize=ReleaseSafe run // 可发行命令

https://y-admin.yijianku.com/#

https://gitee.com/nbnat/layui-filemanage

<script src="https://cdn.jsdelivr.net/gh/kirakiray/ofa.js/dist/ofa.min.js"></script>  前端mvvm组件

https://admin.demo.ulthon.com/admin/Index/index.html#/admin/system.auth/index.html

https://dev.layuion.com/extend/selectplus/ 组件


## zig fetch 要取消代理
```
git config --global --unset http.proxy
git config --global --unset https.proxy

unset http_proxy https_proxy

git config --global http.version HTTP/1.1 //w变更协议
```


## 数据库测试

每种驱动都有完整测试覆盖：
- **CRUD 操作** - 创建、读取、更新、删除及结果验证
- **QueryBuilder** - SQL 构造器测试
- **事务** - 提交/回滚/自动事务
- **高级查询** - 子查询、EXISTS、NOT EXISTS
- **JOIN 查询** - INNER/LEFT/多表关联
- **边界条件** - NULL 值、特殊字符、Unicode、大数据量
- **内存安全** - GPA 检测内存泄漏
- **连接池** - MySQL 连接池特性（仅 MySQL）

### SQLite 测试
```bash
cd src/services/sql
zig build-exe sqlite_complete_test.zig -lc -lsqlite3
./sqlite_complete_test
```

### MySQL 测试
```bash
cd src/services/sql

# macOS (Homebrew - ARM)
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /opt/homebrew/include \
  -L /opt/homebrew/lib

# macOS (Homebrew - Intel / MariaDB)
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /usr/local/include \
  -L /usr/local/lib

# macOS (MySQL 官方安装)
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /usr/local/mysql/include \
  -L /usr/local/mysql/lib

# Linux
zig build-exe mysql_complete_test.zig -lc -lmysqlclient

# 运行测试（需要先创建测试数据库）
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS test_zigcms;"
./mysql_complete_test
```

### PostgreSQL 测试
```bash
# 需要通过 build.zig 编译（因为依赖 pg 模块）
# 1. 确保 PostgreSQL 运行
brew services start postgresql@14
# 或
sudo systemctl start postgresql

# 2. 创建测试数据库
psql -U postgres -c "CREATE DATABASE test_zigcms;"

# 3. 编译运行（通过主程序）
zig build

# 或者单独运行测试（需要配置）
# 查看 PGSQL_TEST_GUIDE.md 获取详细说明
```

