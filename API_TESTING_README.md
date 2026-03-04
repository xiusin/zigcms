# 质量中心 API 测试工具包

## 概述

本工具包提供了完整的质量中心 API 测试解决方案，包括自动化测试脚本、测试数据准备、健康检查和测试文档。

## 文件说明

| 文件 | 说明 |
|------|------|
| `check_api_health.sh` | API 健康检查脚本 |
| `prepare_test_data.sh` | 测试数据准备脚本 |
| `test_quality_center_api.sh` | 完整 API 测试脚本 |
| `API_TEST_GUIDE.md` | API 测试指南 |
| `API_TEST_CHECKLIST.md` | API 测试检查清单 |
| `quality_center_api.postman_collection.json` | Postman 测试集合 |

## 快速开始

### 1. 准备环境

确保后端服务已启动：

```bash
# 启动后端服务
zig build run
```

### 2. 健康检查

```bash
# 赋予执行权限
chmod +x check_api_health.sh

# 运行健康检查
./check_api_health.sh

# 或指定 URL
./check_api_health.sh http://localhost:3000
```

### 3. 准备测试数据

```bash
# 赋予执行权限
chmod +x prepare_test_data.sh

# 准备测试数据
./prepare_test_data.sh

# 或指定 URL
./prepare_test_data.sh http://localhost:3000
```

### 4. 运行自动化测试

```bash
# 赋予执行权限
chmod +x test_quality_center_api.sh

# 运行测试
./test_quality_center_api.sh

# 或指定 URL
./test_quality_center_api.sh http://localhost:3000
```

## 测试流程

```
┌─────────────────┐
│  1. 健康检查     │
│  check_api_     │
│  health.sh      │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  2. 准备数据     │
│  prepare_test_  │
│  data.sh        │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  3. 运行测试     │
│  test_quality_  │
│  center_api.sh  │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  4. 查看结果     │
│  分析失败用例    │
└─────────────────┘
```

## 测试覆盖

### API 端点覆盖

- **项目管理**：8 个端点
- **模块管理**：7 个端点
- **需求管理**：7 个端点
- **测试用例管理**：9 个端点
- **AI 生成**：3 个端点
- **反馈管理**：8 个端点
- **统计分析**：5 个端点
- **错误处理**：5 个测试

**总计：52 个测试用例**

### 功能覆盖

- ✅ 请求体解析验证
- ✅ 响应格式验证
- ✅ 错误处理验证
- ✅ 业务逻辑验证
- ✅ 性能验证
- ✅ 安全性验证

## 使用 Postman 测试

### 导入集合

1. 打开 Postman
2. 点击 Import
3. 选择 `quality_center_api.postman_collection.json`
4. 导入成功

### 配置环境变量

1. 创建新环境（例如：Quality Center Dev）
2. 添加变量：
   - `base_url`: `http://localhost:3000`
   - `api_prefix`: `/api/quality`
3. 保存并激活环境

### 运行测试

1. 选择集合
2. 点击 Run
3. 选择要运行的测试
4. 点击 Run Quality Center API

## 测试结果分析

### 成功标准

- ✅ 所有测试通过
- ✅ 响应时间符合要求
- ✅ 错误处理正确
- ✅ 数据一致性正确

### 失败处理

如果测试失败：

1. 查看失败的端点
2. 检查错误信息
3. 查看后端日志
4. 修复问题
5. 重新运行测试

### 常见问题

#### 连接被拒绝

```
错误：curl: (7) Failed to connect to localhost port 3000
解决：确认后端服务已启动
```

#### 404 错误

```
错误：所有请求返回 404
解决：确认路由已正确注册
```

#### 500 错误

```
错误：请求返回 500 内部错误
解决：查看后端日志，检查数据库连接
```

## 性能基准

| 操作类型 | 预期响应时间 |
|---------|-------------|
| 列表查询 | < 500ms |
| 详情查询 | < 200ms |
| 创建操作 | < 300ms |
| 更新操作 | < 300ms |
| 删除操作 | < 200ms |
| 批量操作 | < 1s (100 条) |
| 统计查询 | < 1s |

## 测试报告

测试完成后，填写 `API_TEST_CHECKLIST.md` 生成测试报告。

## 持续集成

### 集成到 CI/CD

```yaml
# .github/workflows/api-test.yml
name: API Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Start Backend
        run: zig build run &
      - name: Wait for Service
        run: sleep 10
      - name: Run Health Check
        run: ./check_api_health.sh
      - name: Prepare Test Data
        run: ./prepare_test_data.sh
      - name: Run API Tests
        run: ./test_quality_center_api.sh
```

## 下一步

测试通过后，可以继续：

1. **前端开发**：实现前端页面（任务 21-28）
2. **单元测试**：编写单元测试（任务 31）
3. **集成测试**：编写集成测试（任务 35）
4. **性能优化**：优化慢查询（任务 36）

## 支持

如有问题，请查看：
- `API_TEST_GUIDE.md` - 详细测试指南
- `API_TEST_CHECKLIST.md` - 测试检查清单
- 后端日志文件
- 数据库日志

## 许可证

MIT License
