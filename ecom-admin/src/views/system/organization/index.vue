<template>
  <div class="content-box">
    <a-card>
      <a-row :gutter="16">
        <!-- 左侧：部门树 -->
        <a-col :span="6">
          <div class="dept-tree-section">
            <div class="section-header">
              <span>部门架构</span>
              <a-input-search
                v-model="deptSearchKey"
                placeholder="搜索部门"
                size="mini"
                style="width: 120px; margin: 0 8px"
                @search="fetchDeptTree"
              />
              <a-space size="mini">
                <a-button type="text" size="mini" @click="handleExpandAll">
                  <icon-expand v-if="!expandAll" />
                  <icon-shrink v-else />
                </a-button>
                <a-button type="text" size="mini" @click="handleAddDept">
                  <icon-plus />
                </a-button>
              </a-space>
            </div>
            <div class="tree-content">
              <a-tree
                :data="deptTreeData"
                :default-expand-all="expandAll"
                :selected-keys="selectedDeptKeys"
                size="small"
                @select="handleDeptSelect"
              >
                <template #title="nodeData">
                  <div class="tree-node-commercial">
                    <div class="node-content-wrapper">
                      <span class="node-title">{{ nodeData.title }}</span>
                      <span v-if="nodeData.dept_code" class="node-code-badge">{{ nodeData.dept_code }}</span>
                    </div>
                    
                    <div class="node-actions-dropdown">
                      <a-dropdown trigger="click" position="br">
                        <a-button
                          type="text"
                          size="mini"
                          class="more-action-btn"
                          @click.stop
                        >
                          <icon-more />
                        </a-button>
                        <template #content>
                          <a-doption @click="handleAddChildDept(nodeData)">
                            <template #icon><icon-plus-circle /></template>
                            新增下级
                          </a-doption>
                          <a-doption @click="handleEditDept(nodeData)">
                            <template #icon><icon-edit /></template>
                            编辑部门
                          </a-doption>
                          <a-divider style="margin: 4px 0" />
                          <a-doption class="danger-option" @click="handleDeleteDept(nodeData)">
                            <template #icon><icon-delete /></template>
                            删除部门
                          </a-doption>
                        </template>
                      </a-dropdown>
                    </div>
                  </div>
                </template>
              </a-tree>
            </div>
          </div>
        </a-col>

        <!-- 右侧：管理员列表 -->
        <a-col :span="18">
          <div class="admin-section">
            <div class="section-toolbar">
              <a-space size="small">
                <a-select
                  v-model="filterRoleId"
                  placeholder="筛选角色"
                  size="small"
                  style="width: 150px"
                  allow-clear
                  @change="handleRefresh"
                >
                  <a-option
                    v-for="role in uniqueRoleList"
                    :key="role.id"
                    :value="role.id"
                    :label="role.role_name"
                  />
                </a-select>
                <a-select
                  v-model="filterStatus"
                  placeholder="状态"
                  size="small"
                  style="width: 100px"
                  allow-clear
                  @change="handleRefresh"
                >
                  <a-option :value="1" label="启用" />
                  <a-option :value="0" label="禁用" />
                </a-select>
                <a-input-search
                  v-model="adminSearchKey"
                  placeholder="搜索用户名/昵称"
                  size="small"
                  style="width: 200px"
                  @search="handleRefresh"
                />
              </a-space>
              <a-space size="small">
                <a-button size="small" @click="handleRefresh">
                  <template #icon><icon-refresh /></template>
                  刷新
                </a-button>
                <a-button type="primary" size="small" @click="openModal({})">
                  <template #icon><icon-plus /></template>
                  添加管理员
                </a-button>
              </a-space>
            </div>

            <base-table
              ref="tableRef"
              v-model:loading="loading"
              :columns-config="columns"
              :data-config="getDataList"
              :send-params="sendParams"
            >
              <template #avatar="{ record }">
                <a-avatar :size="32" :image-url="record.avatar">
                  {{ record.username?.charAt(0) }}
                </a-avatar>
              </template>
              <template #gender="{ record }">
                <a-tag
                  :color="
                    record.gender === 1
                      ? 'blue'
                      : record.gender === 2
                      ? 'pink'
                      : 'gray'
                  "
                  size="small"
                >
                  {{ getGenderText(record.gender) }}
                </a-tag>
              </template>
              <template #role="{ record }">
                <div class="role-tags-cell">
                  <template v-if="record.role_text">
                    <a-tag
                      v-for="(tag, index) in record.role_text.split(',').slice(0, roleTagThreshold)"
                      :key="index"
                      size="small"
                      class="glass-role-tag"
                    >
                      {{ tag }}
                    </a-tag>
                    <a-popover v-if="record.role_text.split(',').length > roleTagThreshold" position="top">
                      <a-tag size="small" class="glass-role-tag plus-tag">
                        {{ roleI18n.morePrefix }}{{ record.role_text.split(',').length - roleTagThreshold }}
                      </a-tag>
                      <template #content>
                        <div class="role-popover-list">
                          <a-tag
                            v-for="(tag, index) in record.role_text.split(',').slice(roleTagThreshold)"
                            :key="index"
                            size="small"
                            class="glass-role-tag"
                            style="margin: 4px"
                          >
                            {{ tag }}
                          </a-tag>
                        </div>
                      </template>
                    </a-popover>
                  </template>
                  <span v-else class="empty-text">{{ roleI18n.empty }}</span>
                </div>
              </template>
              <template #status="{ record }">
                <a-switch
                  :model-value="record.status === 1"
                  :loading="record.loading"
                  size="small"
                  @click="changeStatus(record)"
                />
              </template>
              <template #action="{ record }">
                <a-space size="mini">
                  <a-button type="text" size="mini" @click="openModal(record)">
                    <icon-edit /> 编辑
                  </a-button>
                  <a-button type="text" size="mini" @click="resetPassword(record)">
                    <icon-lock /> 重置
                  </a-button>
                  <a-button type="text" size="mini" @click="handleAssignRole(record)">
                    <icon-user /> 角色
                  </a-button>
                  <a-popconfirm
                    content="确定要删除该管理员吗?"
                    position="left"
                    @ok="deleteAdmin(record)"
                  >
                    <a-button type="text" size="mini" status="danger">
                      <icon-delete /> 删除
                    </a-button>
                  </a-popconfirm>
                </a-space>
              </template>
            </base-table>
          </div>
        </a-col>
      </a-row>
    </a-card>

    <!-- 部门编辑弹窗 (Commercial Glass Style) -->
    <a-modal
      v-model:visible="deptModalVisible"
      :title="deptModalTitle"
      width="600px"
      :unmount-on-close="true"
      class="glass-modal dept-edit-modal"
      @before-ok="handleDeptSave"
    >
      <div class="modal-content-glass">
        <a-form ref="deptFormRef" :model="deptForm" :rules="deptRules" layout="vertical" class="modern-form">
          <a-row :gutter="24">
            <a-col :span="24">
              <a-form-item label="上级部门" field="parent_id">
                <a-tree-select
                  v-model="deptForm.parent_id"
                  :data="deptTreeData"
                  placeholder="选择所属上级部门 (为空则为顶级)"
                  allow-clear
                  class="glass-input"
                >
                  <template #prefix><icon-apps /></template>
                </a-tree-select>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="部门名称" field="dept_name">
                <a-input v-model="deptForm.dept_name" placeholder="请输入部门名称" class="glass-input">
                  <template #prefix><icon-tag /></template>
                </a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="部门编码" field="dept_code">
                <a-input v-model="deptForm.dept_code" placeholder="如：DEPT_001" class="glass-input">
                  <template #prefix><icon-code /></template>
                </a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="负责人" field="leader">
                <a-input v-model="deptForm.leader" placeholder="请输入姓名" class="glass-input">
                  <template #prefix><icon-user /></template>
                </a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="联系电话" field="phone">
                <a-input v-model="deptForm.phone" placeholder="请输入电话" class="glass-input">
                  <template #prefix><icon-phone /></template>
                </a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="显示排序" field="sort">
                <a-input-number v-model="deptForm.sort" :min="0" style="width: 100%" class="glass-input" />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="启用状态" field="status">
                <a-switch v-model="deptForm.status" type="round">
                  <template #checked>启用</template>
                  <template #unchecked>禁用</template>
                </a-switch>
              </a-form-item>
            </a-col>
          </a-row>
        </a-form>
      </div>
    </a-modal>

    <!-- 管理员编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑管理员' : '添加管理员'"
      :width="600"
      :unmount-on-close="true"
      :confirm-loading="saveLoading"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-form-item label="头像">
          <div class="avatar-upload">
            <a-avatar :size="64" :image-url="formData.avatar">
              {{ formData.username?.charAt(0) }}
            </a-avatar>
            <a-input
              v-model="formData.avatar"
              placeholder="请输入头像URL"
              style="flex: 1"
            />
          </div>
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="用户名" field="username">
              <a-input
                v-model="formData.username"
                placeholder="请输入用户名"
                :disabled="isEdit"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="昵称" field="nickname">
              <a-input v-model="formData.nickname" placeholder="请输入昵称" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row v-if="!isEdit" :gutter="16">
          <a-col :span="12">
            <a-form-item label="密码" field="password">
              <a-input-password
                v-model="formData.password"
                placeholder="请输入密码"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="确认密码" field="confirm_password">
              <a-input-password
                v-model="formData.confirm_password"
                placeholder="请确认密码"
              />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="手机号码" field="mobile">
              <a-input v-model="formData.mobile" placeholder="请输入手机号码" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="邮箱" field="email">
              <a-input v-model="formData.email" placeholder="请输入邮箱" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="所属部门" field="dept_id">
              <a-tree-select
                v-model="formData.dept_id"
                :data="deptTreeData"
                placeholder="请选择所属部门"
                allow-clear
                :field-names="{ key: 'key', title: 'title', children: 'children' }"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="性别" field="gender">
              <a-select v-model="formData.gender" placeholder="请选择性别">
                <a-option :value="0">未知</a-option>
                <a-option :value="1">男</a-option>
                <a-option :value="2">女</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="角色" field="role_ids">
              <a-select
                v-model="formData.role_ids"
                placeholder="请选择角色"
                multiple
                allow-clear
                :max-tag-count="3"
                class="glass-input custom-select"
              >
                <a-option
                  v-for="item in uniqueRoleList"
                  :key="item.id"
                  :value="item.id"
                >
                  {{ item.role_name }}
                </a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="备注" field="remark">
          <a-textarea v-model="formData.remark" placeholder="请输入备注" class="glass-input" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 重置密码弹窗 (Liquid Glassmorphism) -->
    <a-modal
      v-model:visible="pwdVisible"
      title="重置登录密码"
      :width="380"
      :unmount-on-close="true"
      class="glass-modal security-modal"
      @ok="handleResetPwdConfirm"
    >
      <div class="modal-content-glass compact">
        <div class="header-info-mini">
          <icon-lock class="mr-8" />
          <span>当前管理员：<strong>{{ pwdRecord.username }}</strong></span>
        </div>
        <a-form ref="pwdFormRef" :model="pwdForm" layout="vertical" class="modern-form">
          <a-form-item label="设置新密码" field="password" :rules="pwdRules.password">
            <a-input-password v-model="pwdForm.password" placeholder="请输入新密码" class="glass-input">
              <template #prefix><icon-lock /></template>
            </a-input-password>
          </a-form-item>
          <a-form-item label="确认新密码" field="confirm_password" :rules="pwdRules.confirm_password">
            <a-input-password v-model="pwdForm.confirm_password" placeholder="请再次输入以确认" class="glass-input">
              <template #prefix><icon-check-circle-fill /></template>
            </a-input-password>
          </a-form-item>
        </a-form>
      </div>
    </a-modal>

    <!-- 角色分配弹窗 -->
    <a-modal
      v-model:visible="roleVisible"
      title="分配权限角色"
      :width="440"
      :unmount-on-close="true"
      class="glass-modal"
      :confirm-loading="assignRoleLoading"
      @ok="confirmAssignRole"
    >
      <div v-if="roleVisible" class="modal-content-glass">
        <a-form layout="vertical" class="modern-form">
          <div class="header-info-mini">
            <icon-user-group class="mr-8" />
            <span>当前管理员：<strong>{{ roleRecord.username }}</strong></span>
          </div>
          <a-form-item label="授予角色权限 (支持多选)">
            <a-select
              v-model="selectedRoles"
              multiple
              allow-clear
              placeholder="请搜索并选择授权角色"
              class="glass-input custom-select"
              :scrollbar="true"
              :max-tag-count="3"
            >
              <a-option
                v-for="role in uniqueRoleList"
                :key="role.id"
                :value="String(role.id)"
              >
                {{ role.role_name }}
              </a-option>
            </a-select>
          </a-form-item>
        </a-form>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import request from '@/api/request';

  const ROLE_CACHE_KEY = 'org_role_list_cache_v1';

  const roleI18n = {
    empty: '无角色',
    morePrefix: '+',
  } as const;

  const isMobile = computed(() => window.innerWidth <= 768);
  const roleTagThreshold = computed(() => (isMobile.value ? 1 : 2));

  // ========== 状态定义与去重控制 ==========
  const roleList = ref<any[]>([]);
  const uniqueRoleList = computed(() => {
    const map = new Map();
    return roleList.value.filter((item) => !map.has(item.id) && map.set(item.id, 1));
  });

  // ========== 部门相关 ==========
  const deptSearchKey = ref('');
  const deptTreeData = ref<any[]>([]);
  const selectedDeptKeys = ref<string[]>([]);
  const selectedDeptId = ref<number>();
  const expandAll = ref(false);

  const deptModalVisible = ref(false);
  const deptFormRef = ref();
  const deptForm = reactive({
    id: 0,
    parent_id: null as number | null,
    dept_name: '',
    dept_code: '',
    leader: '',
    phone: '',
    sort: 0,
    status: true,
  });
  const deptRules = {
    dept_name: [{ required: true, message: '请输入部门名称' }],
    dept_code: [{ required: true, message: '请输入部门编码' }],
  };

  const persistRoleCache = (list: any[]) => {
    try {
      localStorage.setItem(ROLE_CACHE_KEY, JSON.stringify(list || []));
    } catch (_) {}
  };

  const loadRoleCache = (): any[] => {
    try {
      const raw = localStorage.getItem(ROLE_CACHE_KEY);
      if (!raw) return [];
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch (_) {
      return [];
    }
  };

  const emitOpLog = (action: string, payload?: Record<string, any>) => {
    // eslint-disable-next-line no-console
    console.info('[operation-log]', {
      action,
      at: new Date().toISOString(),
      payload: payload || {},
    });
  };
  const deptModalTitle = computed(() =>
    deptForm.id ? '编辑部门' : '添加部门'
  );

  // ========== 管理员相关 ==========
  const tableRef = ref();
  const loading = ref(false);
  const modalVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();
  const adminSearchKey = ref('');
  const filterRoleId = ref<number | undefined>();
  const filterStatus = ref<number | undefined>();
  const refreshTimer = ref<number | null>(null);
  const saveLoading = ref(false);
  const assignRoleLoading = ref(false);

  const formData = reactive({
    id: 0,
    username: '',
    nickname: '',
    password: '',
    confirm_password: '',
    mobile: '',
    email: '',
    avatar: '',
    gender: 0,
    dept_id: undefined as number | undefined,
    role_ids: [] as number[],
    remark: '',
  });

  const safeRequest = async (
    action: string,
    api: string,
    payload?: any
  ): Promise<any> => {
    try {
      return await request(api, payload);
    } catch (error: any) {
      Message.error(error?.msg || `${action}失败`);
      throw error;
    }
  };

  const rules = {
    username: [{ required: true, message: '请输入用户名' }],
    nickname: [{ required: true, message: '请输入昵称' }],
    password: [{ required: true, message: '请输入密码' }],
    confirm_password: [{ required: true, message: '请确认密码' }],
    mobile: [{ required: true, message: '请输入手机号码' }],
    email: [{ required: true, message: '请输入邮箱' }],
    role_ids: [{ required: true, message: '请选择角色' }],
  };

  const columns = [
    { title: '头像', dataIndex: 'avatar', width: 60, slotName: 'avatar' },
    { title: '用户名', dataIndex: 'username', width: 100 },
    { title: '昵称', dataIndex: 'nickname', width: 100 },
    { title: '手机号码', dataIndex: 'mobile', width: 120 },
    { title: '邮箱', dataIndex: 'email', ellipsis: true },
    { title: '性别', dataIndex: 'gender', width: 70, slotName: 'gender' },
    { title: '角色', dataIndex: 'role_text', width: 160, slotName: 'role' },
    { title: '最后登录', dataIndex: 'last_login', width: 150 },
    { title: '状态', dataIndex: 'status', width: 70, slotName: 'status' },
    { title: '操作', dataIndex: 'action', width: 200, slotName: 'action', fixed: 'right' },
  ];

  const sendParams = computed(() => ({
    keyword: adminSearchKey.value,
    role_id: filterRoleId.value,
    status: filterStatus.value,
    dept_id: selectedDeptId.value,
  }));

  const getDataList = (data: any) => {
    return request('/api/system/admin/list', data);
  };

  // ========== 部门方法 ==========
  const buildTree = (list: any[]) => {
    if (!Array.isArray(list)) return [];
    const map = new Map<number, any>();
    list.forEach((item) => {
      const id = Number(item.id);
      map.set(id, { ...item, id, key: id, value: id, children: [] });
    });
    const roots: any[] = [];
    list.forEach((item) => {
      const id = Number(item.id);
      const parentId = Number(item.parent_id || 0);
      const node = map.get(id);
      if (!node) return;
      if (parentId > 0 && map.has(parentId)) {
        map.get(parentId)!.children.push(node);
      } else {
        roots.push(node);
      }
    });
    return roots;
  };

  const fetchDeptTree = () => {
    safeRequest('获取部门树', '/api/system/dept/tree', {
      keyword: deptSearchKey.value,
    })
      .then((res: any) => {
        // 调试：打印完整响应
        // eslint-disable-next-line no-console
        console.log('[deptTree][full-res]', res);
        const raw = res?.data;
        const list = Array.isArray(raw)
          ? raw
          : Array.isArray(raw?.list)
            ? raw.list
            : Array.isArray(raw?.items)
              ? raw.items
              : [];
        // 调试：打印后端返回和构建结果
        // eslint-disable-next-line no-console
        console.log('[deptTree][resp]', res?.data);
        deptTreeData.value = buildTree(list);
        // eslint-disable-next-line no-console
        console.log('[deptTree][built]', deptTreeData.value);
      })
      .catch((err: any) => {
        // eslint-disable-next-line no-console
        console.error('[deptTree][error]', err);
        Message.error(err?.msg || '获取部门树失败');
      });
  };

  const handleExpandAll = () => {
    expandAll.value = !expandAll.value;
  };

  const handleDeptSelect = (selectedKeys: string[]) => {
    selectedDeptKeys.value = selectedKeys;
    selectedDeptId.value = selectedKeys[0]
      ? Number(selectedKeys[0])
      : undefined;
    handleRefresh();
  };

  const handleAddDept = () => {
    Object.assign(deptForm, {
      id: 0,
      parent_id: null,
      dept_name: '',
      dept_code: '',
      leader: '',
      phone: '',
      sort: 0,
      status: true,
    });
    deptModalVisible.value = true;
  };

  const handleAddChildDept = (nodeData: any) => {
    Object.assign(deptForm, {
      id: 0,
      parent_id: nodeData.key,
      dept_name: '',
      dept_code: '',
      leader: '',
      phone: '',
      sort: 0,
      status: true,
    });
    deptModalVisible.value = true;
  };

  const handleEditDept = (nodeData: any) => {
    // 逻辑修正：从 nodeData 及其挂载的属性中精确回显数据
    Object.assign(deptForm, {
      id: nodeData.id || nodeData.key,
      parent_id: nodeData.parent_id || null,
      dept_name: nodeData.dept_name || nodeData.title,
      dept_code: nodeData.dept_code || '',
      leader: nodeData.leader || '',
      phone: nodeData.phone || '',
      sort: nodeData.sort || 0,
      status: nodeData.status === 1 || nodeData.status === true,
    });
    deptModalVisible.value = true;
  };

  const handleDeptSave = async () => {
    const valid = await deptFormRef.value?.validate();
    if (valid) return false;

    await safeRequest('保存部门', '/api/system/dept/save', {
      ...deptForm,
      status: deptForm.status ? 1 : 0,
    });
    Message.success(deptForm.id ? '编辑成功' : '添加成功');
    fetchDeptTree();
    return true;
  };

  const handleDeleteDept = async (nodeData: any) => {
    await safeRequest('删除部门', '/api/system/dept/remove', {
      id: nodeData.key,
    });
    Message.success('删除成功');
    fetchDeptTree();
  };

  // ========== 管理员方法 ==========
  const fetchRoleList = () => {
    safeRequest('获取角色列表', '/api/role/list', { pageSize: 100 })
      .then((res: any) => {
        roleList.value = res.data?.list || [];
        persistRoleCache(roleList.value);
      })
      .catch(() => {
        Message.warning('获取角色列表失败，2秒后将自动重试');
        window.setTimeout(() => {
          safeRequest('重试获取角色列表', '/api/role/list', { pageSize: 100 })
            .then((res: any) => {
              roleList.value = res.data?.list || [];
              persistRoleCache(roleList.value);
            })
            .catch(() => {
              const cached = loadRoleCache();
              if (cached.length > 0) {
                roleList.value = cached;
                Message.warning('角色列表获取失败，已使用本地缓存');
              } else {
                roleList.value = [];
                Message.error('角色列表获取失败，已使用空列表占位');
              }
            });
        }, 2000);
      });
  };

  const handleRefresh = () => {
    if (refreshTimer.value) {
      window.clearTimeout(refreshTimer.value);
    }
    refreshTimer.value = window.setTimeout(() => {
      tableRef.value?.search();
      refreshTimer.value = null;
    }, 300);
  };

  const getGenderText = (gender: number) => {
    const texts = ['未知', '男', '女'];
    return texts[gender] || '未知';
  };

  const openModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, {
        ...record,
        role_ids: Array.isArray(record.role_ids) ? record.role_ids.map(Number) : [],
      });
    } else {
      isEdit.value = false;
      Object.assign(formData, {
        id: 0,
        username: '',
        nickname: '',
        password: '',
        confirm_password: '',
        mobile: '',
        email: '',
        avatar: '',
        gender: 0,
        dept_id: selectedDeptId.value,
        role_ids: [],
        remark: '',
      });
    }
    modalVisible.value = true;
  };

  const handleSave = async () => {
    if (saveLoading.value) return;
    const valid = await formRef.value?.validate();
    if (valid) return;

    if (!isEdit.value && formData.password !== formData.confirm_password) {
      Message.error('两次密码输入不一致');
      return;
    }

    if (formData.mobile && !/^1\d{10}$/.test(formData.mobile)) {
      Message.error('手机号格式不正确');
      return;
    }

    if (
      formData.email &&
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)
    ) {
      Message.error('邮箱格式不正确');
      return;
    }

    saveLoading.value = true;
    safeRequest('保存管理员', '/api/system/admin/save', {
      ...formData,
      dept_id: formData.dept_id ?? selectedDeptId.value,
      role_ids: formData.role_ids?.map(Number) ?? [],
    }).then(() => {
      emitOpLog('admin_save', { id: formData.id, role_ids: formData.role_ids });
      Message.success(isEdit.value ? '编辑成功' : '添加成功');
      modalVisible.value = false;
      handleRefresh();
    }).finally(() => {
      saveLoading.value = false;
    });
  };

  const changeStatus = (record: any) => {
    record.loading = true;
    safeRequest('更新管理员状态', '/api/system/admin/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    })
      .then(() => {
        Message.success('状态更新成功');
        handleRefresh();
      })
      .finally(() => {
        record.loading = false;
      });
  };

  // ========== 重置密码逻辑 (Liquid Glass Style) ==========
  const pwdVisible = ref(false);
  const pwdRecord = ref<any>({});
  const pwdFormRef = ref();
  const pwdForm = reactive({
    id: 0,
    password: '',
    confirm_password: '',
  });

  const pwdRules = {
    password: [
      { required: true, message: '请输入新密码' },
      { minLength: 6, message: '密码长度至少6位' }
    ],
    confirm_password: [
      { required: true, message: '请确认新密码' },
      {
        validator: (value: string, cb: any) => {
          if (value !== pwdForm.password) {
            cb('两次输入的密码不一致');
          } else {
            cb();
          }
        },
      },
    ],
  };

  const resetPassword = (record: any) => {
    pwdRecord.value = record;
    pwdForm.id = record.id;
    pwdForm.password = '';
    pwdForm.confirm_password = '';
    pwdVisible.value = true;
  };

  const handleResetPwdConfirm = async () => {
    const valid = await pwdFormRef.value?.validate();
    if (valid) return;

    safeRequest('重置管理员密码', '/api/system/admin/resetPassword', {
      id: pwdForm.id,
      password: pwdForm.password,
    }).then(() => {
      Message.success('密码重置成功');
      pwdVisible.value = false;
    });
  };

  const deleteAdmin = (record: any) => {
    safeRequest('删除管理员', '/api/system/admin/delete', {
      id: record.id,
    }).then(() => {
      Message.success('删除成功');
      handleRefresh();
    });
  };

  // 角色分配
  const roleVisible = ref(false);
  const roleRecord = ref<any>({});
  const selectedRoles = ref<string[]>([]);

  const handleAssignRole = (record: any) => {
    roleRecord.value = record;
    selectedRoles.value = (record.role_ids || []).map(String);
    roleVisible.value = true;
  };

  const confirmAssignRole = () => {
    if (assignRoleLoading.value) return;
    assignRoleLoading.value = true;
    safeRequest('分配管理员角色', '/api/system/admin/assignRoles', {
      id: roleRecord.value.id,
      role_ids: selectedRoles.value.map(Number),
    }).then(() => {
      emitOpLog('admin_assign_roles', { id: roleRecord.value.id, role_ids: selectedRoles.value.map(Number) });
      Message.success('角色分配成功');
      roleVisible.value = false;
      handleRefresh();
    }).finally(() => {
      assignRoleLoading.value = false;
    });
  };

  onMounted(() => {
    fetchDeptTree();
    fetchRoleList();
  });
</script>

<style lang="less" scoped>
  .content-box {
    padding: 0;
  }

  .dept-tree-section {
    background: rgba(255, 255, 255, 0.4);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(0, 0, 0, 0.05);
    border-radius: 12px;
    min-height: 720px;
    max-height: 720px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.03);
    transition: all 0.3s ease;

    &:hover {
      border-color: rgba(var(--primary-6), 0.2);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.06);
    }

    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 12px 16px;
      border-bottom: 1px solid rgba(0, 0, 0, 0.04);
      font-weight: 600;
      font-size: 14px;
      background: linear-gradient(135deg, rgba(255, 255, 255, 0.8), rgba(255, 255, 255, 0.4));
      color: var(--color-text-1);
    }

    .tree-content {
      padding: 8px;
      flex: 1;
      overflow-y: auto;

      // 深度定制 Arco Tree
      :deep(.arco-tree-node) {
        border-radius: 8px;
        margin-bottom: 2px;
        padding: 0;
        transition: all 0.2s ease;
        display: flex !important; // 强制 flex 布局
        width: 100% !important;   // 强制满宽

        // 核心修正：强制 title 容器占满剩余空间并允许收缩
        .arco-tree-node-title {
          flex: 1 !important;
          min-width: 0 !important;
          padding: 4px 8px;
          background-color: transparent !important;
          display: block;
          overflow: hidden;
          
          &:hover {
            background-color: transparent !important;
          }
        }

        &:hover {
          background: rgba(var(--primary-6), 0.04);
          .node-actions-dropdown { opacity: 1; }
        }

        &.arco-tree-node-selected {
          background: rgba(var(--primary-6), 0.08) !important;
          position: relative;
          
          &::before {
            content: '';
            position: absolute;
            left: 0;
            top: 20%;
            height: 60%;
            width: 3px;
            background: rgb(var(--primary-6));
            border-radius: 0 4px 4px 0;
          }

          .node-title { color: rgb(var(--primary-6)); font-weight: 600; }
        }
      }

      .tree-node-commercial {
        display: flex;
        align-items: center;
        width: 100%;
        gap: 8px;
        position: relative; // 建立绝对定位基准

        .node-content-wrapper {
          flex: 1;
          min-width: 0;
          display: flex;
          align-items: center;
          gap: 6px;
          overflow: hidden;
          padding-right: 28px; // 强制预留右侧按钮空间

          .node-title {
            font-size: 13px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            color: var(--color-text-1);
          }

          .node-code-badge {
            flex-shrink: 0;
            font-size: 10px;
            color: var(--color-text-3);
            background: rgba(0, 0, 0, 0.04);
            padding: 0 5px;
            border-radius: 3px;
            font-family: monospace;
            opacity: 0.8;
          }
        }

        .node-actions-dropdown {
          position: absolute; // 脱离文档流，锁定位置
          right: 0;
          top: 50%;
          transform: translateY(-50%);
          z-index: 10; // 确保置顶
          opacity: 0;
          transition: all 0.2s;
          display: flex;
          align-items: center;
          padding-left: 12px;
          // 增加更强的右侧遮罩，确保长文本被遮盖时不干扰按钮
          background: linear-gradient(to left, rgba(255, 255, 255, 1) 40%, rgba(255, 255, 255, 0.8) 70%, transparent 100%);
          backdrop-filter: blur(4px);
          height: 100%;
          border-radius: 0 8px 8px 0;

          .more-action-btn {
            width: 22px;
            height: 22px;
            padding: 0 !important;
            border-radius: 4px;
            color: var(--color-text-3);
            
            &:hover, &.arco-dropdown-open {
              background: var(--color-fill-3);
              color: var(--color-text-1);
            }
          }
        }

        &:hover .node-actions-dropdown {
          opacity: 1;
        }
      }
    }
  }

  // 下拉菜单全局覆盖
  :deep(.arco-dropdown) {
    border-radius: 8px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    border: 1px solid rgba(0, 0, 0, 0.05);
    background: rgba(255, 255, 255, 0.9) !important;
    backdrop-filter: blur(10px);

    .arco-dropdown-list {
      padding: 4px;
      
      .arco-dropdown-option {
        border-radius: 4px;
        font-size: 12px;
        padding: 5px 12px;
        margin-bottom: 2px;
        
        &:last-child { margin-bottom: 0; }

        &.danger-option {
          color: rgb(var(--danger-6));
          &:hover { background: rgba(var(--danger-6), 0.08); }
        }
      }
    }
  }

  .admin-section {
    padding: 12px 16px;

    .section-toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }
  }

  // ========== Liquid Glassmorphism 顶级 UI 样式 ==========
  :deep(.glass-modal) {
    .arco-modal {
      background: rgba(255, 255, 255, 0.65) !important;
      backdrop-filter: blur(25px) saturate(200%);
      border: 1px solid rgba(255, 255, 255, 0.4);
      border-radius: 20px;
      box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
      overflow: hidden;
    }

    .arco-modal-header {
      background: rgba(255, 255, 255, 0.3) !important;
      border-bottom: 1px solid rgba(0, 0, 0, 0.04);
      padding: 20px 24px;
    }

    .arco-modal-body {
      background: transparent !important;
      padding: 0; // 由内容自持 padding
    }

    .arco-modal-footer {
      background: rgba(255, 255, 255, 0.3) !important;
      border-top: 1px solid rgba(0, 0, 0, 0.04);
      padding: 16px 24px;
    }
  }

  .modal-content-glass {
    padding: 24px;
    display: flex;
    flex-direction: column;

    &.compact {
      padding: 16px 24px 24px;
    }

    .header-info-mini {
      display: flex;
      align-items: center;
      margin-bottom: 20px;
      padding: 10px 14px;
      background: rgba(var(--primary-6), 0.05);
      border-radius: 8px;
      font-size: 13px;
      color: var(--color-text-2);
      border: 1px dashed rgba(var(--primary-6), 0.2);
      
      .mr-8 { margin-right: 8px; color: rgb(var(--primary-6)); }
      strong { color: var(--color-text-1); margin-left: 4px; }
    }
  }

  .modern-form {
    .glass-input {
      background: rgba(255, 255, 255, 0.5) !important;
      border: 1px solid rgba(0, 0, 0, 0.08);
      border-radius: 8px;
      height: 36px;
      transition: all 0.3s;
      
      &:hover, &-focus {
        background: rgba(255, 255, 255, 0.8) !important;
        border-color: rgb(var(--primary-6)) !important;
      }

      // 修正 Prefix 图标位置
      :deep(.arco-input-prefix) {
        margin-left: 6px;
        margin-right: 10px;
        color: var(--color-text-3);
        font-size: 14px;
        display: flex;
        align-items: center;
      }

      :deep(.arco-input-inner-wrapper) {
        padding-left: 0;
      }
    }

    // 针对多选下拉列表的特殊优化
    .custom-select {
      height: auto !important;
      min-height: 36px;
      
      :deep(.arco-select-view-tag) {
        background: rgba(var(--primary-6), 0.1);
        border: 1px solid rgba(var(--primary-6), 0.1);
        color: rgb(var(--primary-6));
        border-radius: 4px;
        font-weight: 500;
      }
    }
  }

  // ========== 水晶角色标签展示样式 ==========
  .role-tags-cell {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    align-items: center;

    .glass-role-tag {
      background: rgba(var(--primary-6), 0.08) !important;
      border: 0.5px solid rgba(var(--primary-6), 0.2) !important;
      color: rgb(var(--primary-6)) !important;
      border-radius: 4px;
      font-weight: 500;
      font-size: 11px;
      padding: 0 6px;
      height: 20px;
      line-height: 19px;
      transition: all 0.2s;

      &:hover {
        background: rgba(var(--primary-6), 0.15) !important;
        transform: translateY(-1px);
        box-shadow: 0 2px 6px rgba(var(--primary-6), 0.1);
      }

      &.plus-tag {
        background: var(--color-fill-2) !important;
        border-color: var(--color-border-2) !important;
        color: var(--color-text-3) !important;
        cursor: pointer;
      }
    }

    .empty-text {
      color: var(--color-text-4);
      font-style: italic;
    }
  }

  .role-popover-list {
    max-width: 200px;
    display: flex;
    flex-wrap: wrap;
    padding: 4px;
  }

  @media (max-width: 768px) {
    .role-tags-cell {
      gap: 2px;

      .glass-role-tag {
        font-size: 10px;
        padding: 0 4px;
        height: 18px;
        line-height: 17px;
      }
    }
  }
</style>
