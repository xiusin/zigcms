# Requirements Document

## Introduction

本需求文档定义了 ZigCMS 人力资源管理系统的功能需求，包括字典管理、部门管理、职位管理、员工管理等核心业务模块，以及数据库迁移工具和静态文件服务优化。系统采用整洁架构模式，使用 Zig 语言开发，SQLite 作为数据库驱动。

## Glossary

- **System**: ZigCMS 人力资源管理系统
- **Dict**: 字典实体，用于管理系统配置项和枚举值
- **Department**: 部门实体，表示企业组织架构中的部门
- **Position**: 职位实体，表示企业中的岗位信息
- **Employee**: 员工实体，表示企业员工信息
- **Migration Tool**: 数据库迁移工具，用于自动生成和执行建表语句
- **SQLite Driver**: SQLite 数据库驱动，用于数据持久化
- **Static File Service**: 静态文件服务，用于提供前端资源文件
- **CRUD**: 创建(Create)、读取(Read)、更新(Update)、删除(Delete)操作
- **UI**: 用户界面，包括前端页面和交互组件
- **API Endpoint**: HTTP API 接口端点
- **Memory Leak**: 内存泄漏，程序未正确释放已分配的内存

## Requirements

### Requirement 1: 字典管理模块

**User Story:** 作为系统管理员，我希望能够管理系统字典数据，以便统一维护系统中的配置项和枚举值。

#### Acceptance Criteria

1. WHEN 管理员访问字典列表页面 THEN THE System SHALL 显示所有字典类型和字典项的列表
2. WHEN 管理员创建新字典项 THEN THE System SHALL 验证字典类型、标签和值的唯一性并保存到数据库
3. WHEN 管理员编辑字典项 THEN THE System SHALL 更新字典项信息并记录更新时间
4. WHEN 管理员删除字典项 THEN THE System SHALL 从数据库中删除该字典项
5. WHEN 管理员按字典类型筛选 THEN THE System SHALL 返回该类型下的所有字典项
6. WHEN 前端请求字典数据 THEN THE System SHALL 提供按类型查询字典项的 API 接口
7. WHEN 字典数据被频繁访问 THEN THE System SHALL 使用缓存机制提高查询性能

### Requirement 2: 部门管理模块

**User Story:** 作为人力资源管理员，我希望能够管理企业部门信息，以便维护组织架构。

#### Acceptance Criteria

1. WHEN 管理员访问部门列表页面 THEN THE System SHALL 以树形结构显示所有部门
2. WHEN 管理员创建新部门 THEN THE System SHALL 验证部门编码唯一性并保存部门信息
3. WHEN 管理员编辑部门信息 THEN THE System SHALL 更新部门数据并维护父子关系
4. WHEN 管理员删除部门 THEN THE System SHALL 检查是否存在子部门或关联员工，若存在则拒绝删除
5. WHEN 管理员设置部门负责人 THEN THE System SHALL 验证负责人是否为有效员工
6. WHEN 管理员查询部门详情 THEN THE System SHALL 返回部门信息及其下属部门和员工数量
7. WHEN 部门状态被禁用 THEN THE System SHALL 同时禁用该部门下的所有子部门

### Requirement 3: 职位管理模块

**User Story:** 作为人力资源管理员，我希望能够管理企业职位信息，以便规范岗位设置。

#### Acceptance Criteria

1. WHEN 管理员访问职位列表页面 THEN THE System SHALL 显示所有职位及其所属部门
2. WHEN 管理员创建新职位 THEN THE System SHALL 验证职位编码唯一性并保存职位信息
3. WHEN 管理员编辑职位信息 THEN THE System SHALL 更新职位数据并记录更新时间
4. WHEN 管理员删除职位 THEN THE System SHALL 检查是否有员工关联该职位，若有则拒绝删除
5. WHEN 管理员按部门筛选职位 THEN THE System SHALL 返回该部门下的所有职位
6. WHEN 管理员设置职位职级 THEN THE System SHALL 验证职级范围在 1 到 10 之间
7. WHEN 职位状态被禁用 THEN THE System SHALL 阻止新员工分配到该职位

### Requirement 4: 员工管理模块

**User Story:** 作为人力资源管理员，我希望能够管理员工信息，以便维护员工档案。

#### Acceptance Criteria

1. WHEN 管理员访问员工列表页面 THEN THE System SHALL 显示所有员工及其部门、职位信息
2. WHEN 管理员创建新员工 THEN THE System SHALL 验证工号唯一性并保存员工信息
3. WHEN 管理员编辑员工信息 THEN THE System SHALL 更新员工数据并记录更新时间
4. WHEN 管理员删除员工 THEN THE System SHALL 执行软删除操作，设置 is_delete 标记为 1
5. WHEN 管理员按部门筛选员工 THEN THE System SHALL 返回该部门及其子部门的所有员工
6. WHEN 管理员按职位筛选员工 THEN THE System SHALL 返回该职位的所有员工
7. WHEN 管理员设置员工直属上级 THEN THE System SHALL 验证上级是否为有效员工且不能是自己
8. WHEN 管理员上传员工头像 THEN THE System SHALL 保存图片文件并更新员工头像 URL
9. WHEN 管理员查询员工详情 THEN THE System SHALL 返回员工完整信息及其部门、职位、角色名称

### Requirement 5: 数据库迁移工具

**User Story:** 作为开发人员，我希望有自动化的数据库迁移工具，以便快速初始化和更新数据库结构。

#### Acceptance Criteria

1. WHEN 开发人员运行迁移工具 THEN THE System SHALL 读取所有实体模型定义
2. WHEN 迁移工具分析实体模型 THEN THE System SHALL 生成对应的 SQLite 建表语句
3. WHEN 迁移工具执行迁移 THEN THE System SHALL 按依赖顺序创建数据库表
4. WHEN 表已存在 THEN THE Migration Tool SHALL 跳过该表的创建
5. WHEN 迁移工具创建表 THEN THE System SHALL 自动创建必要的索引以提高查询性能
6. WHEN 迁移工具创建表 THEN THE System SHALL 自动添加外键约束以维护数据完整性
7. WHEN 迁移失败 THEN THE Migration Tool SHALL 回滚所有更改并输出错误信息
8. WHEN 迁移成功 THEN THE Migration Tool SHALL 输出成功信息和创建的表列表

### Requirement 6: SQLite 数据库驱动集成

**User Story:** 作为开发人员，我希望系统使用 SQLite 作为数据库驱动，以便简化部署和提高开发效率。

#### Acceptance Criteria

1. WHEN 系统启动 THEN THE System SHALL 初始化 SQLite 数据库连接
2. WHEN 执行数据库查询 THEN THE System SHALL 使用 SQLite 驱动执行 SQL 语句
3. WHEN 执行事务操作 THEN THE System SHALL 支持事务的提交和回滚
4. WHEN 数据库文件不存在 THEN THE System SHALL 自动创建数据库文件
5. WHEN 系统关闭 THEN THE System SHALL 正确关闭所有数据库连接
6. WHEN 执行批量操作 THEN THE System SHALL 使用事务提高性能
7. WHEN 查询结果为空 THEN THE System SHALL 返回空列表而不是错误

### Requirement 7: 静态文件服务内存管理

**User Story:** 作为运维人员，我希望静态文件服务在关闭时不产生内存泄漏警告，以便确保系统资源正确释放。

#### Acceptance Criteria

1. WHEN 静态文件服务启动 THEN THE System SHALL 使用 arena allocator 管理文件缓存内存
2. WHEN 静态文件被请求 THEN THE System SHALL 读取文件内容并使用正确的 allocator 分配内存
3. WHEN 响应完成 THEN THE System SHALL 释放为该请求分配的所有内存
4. WHEN 服务器正常关闭 THEN THE System SHALL 释放所有静态文件服务相关的内存资源
5. WHEN 服务器被强制终止 THEN THE System SHALL 记录警告日志但不报告内存泄漏错误
6. WHEN 使用 GeneralPurposeAllocator THEN THE System SHALL 在 deinit 时检测并报告真实的内存泄漏
7. WHEN 文件读取失败 THEN THE System SHALL 确保已分配的内存被正确释放

### Requirement 8: 前端 UI 页面

**User Story:** 作为系统用户，我希望有友好的前端界面，以便方便地进行各项操作。

#### Acceptance Criteria

1. WHEN 用户访问字典管理页面 THEN THE System SHALL 显示字典列表表格和操作按钮
2. WHEN 用户访问部门管理页面 THEN THE System SHALL 显示树形结构的部门列表
3. WHEN 用户访问职位管理页面 THEN THE System SHALL 显示职位列表和部门筛选器
4. WHEN 用户访问员工管理页面 THEN THE System SHALL 显示员工列表和多维度筛选器
5. WHEN 用户点击新增按钮 THEN THE System SHALL 弹出表单对话框
6. WHEN 用户提交表单 THEN THE System SHALL 验证表单数据并调用后端 API
7. WHEN 用户点击编辑按钮 THEN THE System SHALL 加载数据并显示编辑表单
8. WHEN 用户点击删除按钮 THEN THE System SHALL 显示确认对话框
9. WHEN 操作成功 THEN THE System SHALL 显示成功提示并刷新列表
10. WHEN 操作失败 THEN THE System SHALL 显示错误提示信息

### Requirement 9: API 接口规范

**User Story:** 作为前端开发人员，我希望有统一规范的 API 接口，以便高效地进行前后端对接。

#### Acceptance Criteria

1. WHEN 前端请求列表数据 THEN THE System SHALL 返回包含 data、total、page、pageSize 的 JSON 响应
2. WHEN 前端请求详情数据 THEN THE System SHALL 返回包含完整实体信息的 JSON 响应
3. WHEN 前端提交创建请求 THEN THE System SHALL 验证数据并返回新创建实体的 ID
4. WHEN 前端提交更新请求 THEN THE System SHALL 验证数据并返回更新成功的状态
5. WHEN 前端提交删除请求 THEN THE System SHALL 执行删除并返回成功状态
6. WHEN 请求参数无效 THEN THE System SHALL 返回 400 状态码和错误详情
7. WHEN 资源不存在 THEN THE System SHALL 返回 404 状态码和错误信息
8. WHEN 服务器错误 THEN THE System SHALL 返回 500 状态码和错误信息
9. WHEN API 响应成功 THEN THE System SHALL 返回统一格式的 JSON 响应包含 code、message、data 字段

### Requirement 10: 数据验证和业务规则

**User Story:** 作为系统管理员，我希望系统能够验证数据的有效性，以便保证数据质量。

#### Acceptance Criteria

1. WHEN 创建或更新实体 THEN THE System SHALL 验证必填字段不为空
2. WHEN 创建实体 THEN THE System SHALL 验证唯一性约束字段不重复
3. WHEN 设置外键关联 THEN THE System SHALL 验证关联实体存在
4. WHEN 删除实体 THEN THE System SHALL 检查是否存在依赖关系
5. WHEN 输入字符串字段 THEN THE System SHALL 验证字符串长度不超过字段定义的最大长度
6. WHEN 输入数值字段 THEN THE System SHALL 验证数值在有效范围内
7. WHEN 输入邮箱字段 THEN THE System SHALL 验证邮箱格式正确
8. WHEN 输入手机号字段 THEN THE System SHALL 验证手机号格式正确
9. WHEN 输入身份证号字段 THEN THE System SHALL 验证身份证号格式正确
10. WHEN 验证失败 THEN THE System SHALL 返回具体的验证错误信息
