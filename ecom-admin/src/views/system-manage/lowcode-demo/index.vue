<template>
  <div class="lowcode-demo-container">
    <!-- 
      Amis CRUD 组件使用示例
      通过简单的配置即可生成完整的增删改查功能
      包括：筛选表单、列表表格、新增/编辑表单、字典数据自动加载
    -->
    <AmisCrud :config="userCrudConfig" />
  </div>
</template>

<script setup lang="ts">
  import AmisCrud from '@/components/amis-crud/index.vue';
  import type { CrudConfig } from '@/utils/amis-crud-generator';

  /**
   * 用户管理 CRUD 配置
   *
   * 配置说明：
   * - title: 页面标题，会显示在页面顶部和弹窗标题中
   * - api: API 基础路径，组件会自动拼接 CRUD 操作的完整路径
   *   - 列表: GET {api}?page=1&perPage=10
   *   - 新增: POST {api}
   *   - 编辑: PUT {api}/{id}
   *   - 删除: DELETE {api}/{id}
   * - fields: 字段配置数组，定义表格列、表单项、筛选项
   * - editMode: 编辑模式 ('modal' | 'drawer' | 'inline')
   * - columnSettings: 启用列配置管理
   * - export: 导出配置
   * - import: 导入配置
   */
  const userCrudConfig: CrudConfig = {
    title: '用户',
    api: '/api/mock/users',
    editMode: 'drawer', // 使用抽屉模式编辑
    columnSettings: true, // 启用列配置

    // 导出配置
    export: {
      enabled: true,
      formats: ['excel', 'csv'], // 支持多种格式
      filename: '用户列表_{date}',
    },

    // 导入配置
    import: {
      enabled: true,
      template: '/api/template/users.xlsx', // 模板下载地址
    },

    /**
     * 字段配置
     * 每个字段会自动生成：
     * 1. 表格列（除非 hidden: true）
     * 2. 表单项（除非 hideInForm: true）
     * 3. 筛选项（如果 searchable: true 且不是 hideInFilter: true）
     */
    fields: [
      {
        name: 'id',
        label: 'ID',
        type: 'number',
        width: 60,
        hideInForm: true, // 表单中隐藏（ID 由后端生成）
      },
      {
        name: 'username',
        label: '用户名',
        type: 'text', // 文本输入框
        required: true, // 必填
        searchable: true, // 可在筛选表单中搜索
        editable: true, // 支持行内编辑 ⭐ 新功能
        width: 120,
        placeholder: '请输入用户名',
        maxLength: 20, // 最大长度
      },
      {
        name: 'email',
        label: '邮箱',
        type: 'email', // 邮箱输入框（自动验证邮箱格式）
        required: true,
        searchable: true,
        editable: true, // 支持行内编辑 ⭐ 新功能
        width: 180,
        placeholder: '请输入邮箱地址',
      },
      {
        name: 'phone',
        label: '手机号',
        type: 'phone', // 手机号输入框（自动验证手机号格式）
        required: true,
        editable: true, // 支持行内编辑 ⭐ 新功能
        width: 130,
        placeholder: '请输入手机号',
      },
      {
        name: 'role',
        label: '角色',
        type: 'select', // 下拉选择框
        dict: 'user_role', // 字典编码，会自动从 /api/system/dict/items?dict_code=user_role 获取选项
        required: true,
        searchable: true, // 可在筛选表单中选择
        editable: true, // 支持行内编辑 ⭐ 新功能
        width: 100,
        /**
         * 字典数据处理流程：
         * 1. 组件初始化时自动调用字典接口获取选项
         * 2. 表单中显示为下拉框，选项为字典项
         * 3. 列表中自动将字典值映射为显示文本
         * 4. 编辑时自动回显选中的字典值
         * 5. 行内编辑时也支持字典下拉选择 ⭐ 新功能
         *
         * 无需手动编写任何字典加载、映射、回显逻辑！
         */
      },
      {
        name: 'status',
        label: '状态',
        type: 'switch', // 开关组件
        required: true,
        searchable: true,
        quickEdit: true, // 支持快速编辑（在列表中直接切换开关）
        width: 80,
        defaultValue: 1, // 默认值：启用
        /**
         * switch 类型说明：
         * - trueValue: 1（开启时的值）
         * - falseValue: 0（关闭时的值）
         * - quickEdit: true 时，可在列表中直接切换，无需打开编辑弹窗
         */
      },
      {
        name: 'created_at',
        label: '创建时间',
        type: 'datetime', // 日期时间显示
        hideInForm: true, // 表单中隐藏（由后端自动生成）
        width: 180,
        format: 'YYYY-MM-DD HH:mm:ss', // 日期格式
      },
    ],

    /**
     * 功能开关
     * 可根据业务需求灵活控制功能的启用/禁用
     */
    enableAdd: true, // 启用新增功能（显示"新增用户"按钮）
    enableEdit: true, // 启用编辑功能（显示"编辑"按钮）
    enableDelete: true, // 启用删除功能（显示"删除"按钮）
    enableBulk: true, // 启用批量操作（显示批量删除按钮）
    enableFilter: true, // 启用筛选功能（显示筛选表单）

    /**
     * 分页配置
     */
    pageSize: 10, // 每页显示条数
    perPageAvailable: [10, 20, 50, 100], // 可选的每页条数
  };

  /**
   * 使用说明：
   *
   * 1. 字段类型支持：
   *    - text: 文本输入框
   *    - number: 数字输入框
   *    - email: 邮箱输入框（自动验证）
   *    - phone: 手机号输入框（自动验证）
   *    - select: 下拉选择框（支持字典）
   *    - radio: 单选框（支持字典）
   *    - checkbox: 多选框（支持字典）
   *    - date: 日期选择器
   *    - datetime: 日期时间选择器
   *    - switch: 开关
   *    - textarea: 多行文本
   *    - image: 图片上传
   *    - file: 文件上传
   *
   * 2. 第一阶段新功能 ⭐：
   *    a. 行内编辑 (editable: true)
   *       - 点击单元格即可编辑
   *       - 失焦或回车自动保存
   *       - 支持 text、number、email、phone、select、date、datetime、switch
   *
   *    b. 编辑模式 (editMode)
   *       - 'modal': 弹窗编辑（默认）
   *       - 'drawer': 抽屉编辑
   *       - 'inline': 行内编辑（未来支持）
   *
   *    c. 列配置管理 (columnSettings: true)
   *       - 显示/隐藏列
   *       - 固定列
   *       - 调整列顺序
   *       - 用户偏好自动保存
   *
   *    d. 数据导出 (export)
   *       - 支持 Excel、CSV、PDF 格式
   *       - 自定义文件名
   *       - 导出可见列或全部列
   *
   *    e. 数据导入 (import)
   *       - 下载模板
   *       - 上传文件
   *       - 数据验证
   *
   * 3. 字典数据自动处理：
   *    - 配置 dict 属性后，组件会自动：
   *      a. 从接口获取字典选项
   *      b. 在表单中显示为下拉框/单选框/多选框
   *      c. 在列表中将值映射为显示文本
   *      d. 编辑时自动回显选中值
   *      e. 行内编辑时支持字典选择 ⭐ 新功能
   *    - 字典数据会自动缓存，避免重复请求
   *
   * 4. 快速编辑：
   *    - switch 类型支持 quickEdit: true
   *    - 可在列表中直接切换，无需打开编辑弹窗
   *    - 切换后自动保存到后端
   *
   * 5. 字段显示控制：
   *    - hidden: true - 完全隐藏（不在列表、表单、筛选中显示）
   *    - hideInForm: true - 仅在表单中隐藏
   *    - hideInFilter: true - 仅在筛选中隐藏
   *
   * 6. API 接口规范：
   *    - 列表接口: GET /api/mock/users?page=1&perPage=10
   *      返回格式: { code: 0, data: { items: [], total: 0 } }
   *    - 新增接口: POST /api/mock/users
   *      请求体: { username, email, phone, role, status }
   *    - 编辑接口: PUT /api/mock/users/{id}
   *      请求体: { username, email, phone, role, status }
   *    - 删除接口: DELETE /api/mock/users/{id}
   *    - 批量删除: DELETE /api/mock/users/batch
   *      请求体: { ids: [1, 2, 3] }
   *    - 导出接口: GET /api/mock/users/export?format=excel
   *    - 导入接口: POST /api/mock/users/import
   *
   * 7. 字典接口规范：
   *    - 接口: GET /api/system/dict/items?dict_code={code}
   *    - 返回格式: {
   *        code: 0,
   *        data: {
   *          list: [
   *            { item_name: '管理员', item_value: 'admin' },
   *            { item_name: '普通用户', item_value: 'user' }
   *          ]
   *        }
   *      }
   */
</script>

<style scoped>
  .lowcode-demo-container {
    padding: 20px;
    background: var(--color-bg-1);
    min-height: calc(100vh - 60px);
  }
</style>
