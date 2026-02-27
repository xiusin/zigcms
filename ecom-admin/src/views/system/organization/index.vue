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
                  <div class="tree-node">
                    <span class="node-title">{{ nodeData.title }}</span>
                    <a-space class="node-actions" size="mini">
                      <a-button
                        type="text"
                        size="mini"
                        @click.stop="handleAddChildDept(nodeData)"
                      >
                        <icon-plus />
                      </a-button>
                      <a-button
                        type="text"
                        size="mini"
                        @click.stop="handleEditDept(nodeData)"
                      >
                        <icon-edit />
                      </a-button>
                      <a-popconfirm
                        content="确定删除该部门吗？"
                        @ok="handleDeleteDept(nodeData)"
                      >
                        <a-button
                          type="text"
                          size="mini"
                          status="danger"
                          @click.stop
                        >
                          <icon-delete />
                        </a-button>
                      </a-popconfirm>
                    </a-space>
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
                    v-for="role in roleList"
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

    <!-- 部门编辑弹窗 -->
    <a-modal
      v-model:visible="deptModalVisible"
      :title="deptModalTitle"
      width="600px"
      @before-ok="handleDeptSave"
    >
      <a-form ref="deptFormRef" :model="deptForm" :rules="deptRules">
        <a-form-item label="上级部门">
          <a-tree-select
            v-model="deptForm.parent_id"
            :data="deptTreeData"
            placeholder="请选择上级部门（不选则为顶级部门）"
            allow-clear
          />
        </a-form-item>
        <a-form-item label="部门名称" field="dept_name">
          <a-input v-model="deptForm.dept_name" placeholder="请输入部门名称" />
        </a-form-item>
        <a-form-item label="部门编码" field="dept_code">
          <a-input v-model="deptForm.dept_code" placeholder="请输入部门编码" />
        </a-form-item>
        <a-form-item label="负责人">
          <a-input v-model="deptForm.leader" placeholder="请输入负责人" />
        </a-form-item>
        <a-form-item label="联系电话">
          <a-input v-model="deptForm.phone" placeholder="请输入联系电话" />
        </a-form-item>
        <a-form-item label="排序">
          <a-input-number
            v-model="deptForm.sort"
            :min="0"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="状态">
          <a-switch v-model="deptForm.status" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 管理员编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑管理员' : '添加管理员'"
      :width="600"
      :unmount-on-close="true"
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
            <a-form-item label="性别" field="gender">
              <a-select v-model="formData.gender" placeholder="请选择性别">
                <a-option :value="0">未知</a-option>
                <a-option :value="1">男</a-option>
                <a-option :value="2">女</a-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="角色" field="role_id">
              <a-select v-model="formData.role_id" placeholder="请选择角色">
                <a-option
                  v-for="item in roleList"
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
          <a-textarea v-model="formData.remark" placeholder="请输入备注" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 角色分配弹窗 -->
    <a-modal
      v-model:visible="roleVisible"
      title="分配角色"
      :width="500"
      @ok="confirmAssignRole"
    >
      <a-form layout="vertical">
        <a-form-item label="管理员">
          <a-input :model-value="roleRecord.username" disabled />
        </a-form-item>
        <a-form-item label="选择角色">
          <a-checkbox-group v-model="selectedRoles">
            <a-checkbox
              v-for="role in roleList"
              :key="role.id"
              :value="String(role.id)"
            >
              {{ role.role_name }}
            </a-checkbox>
          </a-checkbox-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, onMounted } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';
  import request from '@/api/request';

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
  const deptModalTitle = computed(() =>
    deptForm.id ? '编辑部门' : '添加部门'
  );

  // ========== 管理员相关 ==========
  const tableRef = ref();
  const loading = ref(false);
  const modalVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();
  const roleList = ref<any[]>([]);
  const adminSearchKey = ref('');
  const filterRoleId = ref<number | undefined>();
  const filterStatus = ref<number | undefined>();

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
    role_id: undefined as number | undefined,
    remark: '',
  });

  const rules = {
    username: [{ required: true, message: '请输入用户名' }],
    nickname: [{ required: true, message: '请输入昵称' }],
    password: [{ required: true, message: '请输入密码' }],
    confirm_password: [{ required: true, message: '请确认密码' }],
    mobile: [{ required: true, message: '请输入手机号码' }],
    email: [{ required: true, message: '请输入邮箱' }],
    role_id: [{ required: true, message: '请选择角色' }],
  };

  const columns = [
    { title: '头像', dataIndex: 'avatar', width: 60, slotName: 'avatar' },
    { title: '用户名', dataIndex: 'username', width: 100 },
    { title: '昵称', dataIndex: 'nickname', width: 100 },
    { title: '手机号码', dataIndex: 'mobile', width: 120 },
    { title: '邮箱', dataIndex: 'email', ellipsis: true },
    { title: '性别', dataIndex: 'gender', width: 70, slotName: 'gender' },
    { title: '角色', dataIndex: 'role_name', width: 100 },
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
  const fetchDeptTree = () => {
    request('/api/system/dept/tree', { keyword: deptSearchKey.value }).then(
      (res: any) => {
        deptTreeData.value = res.data || [];
      }
    );
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
    Object.assign(deptForm, {
      ...nodeData.raw,
      status: nodeData.raw.status === 1,
    });
    deptModalVisible.value = true;
  };

  const handleDeptSave = async () => {
    const valid = await deptFormRef.value?.validate();
    if (valid) return false;

    await request('/api/system/dept/save', {
      ...deptForm,
      status: deptForm.status ? 1 : 0,
    });
    Message.success(deptForm.id ? '编辑成功' : '添加成功');
    fetchDeptTree();
    return true;
  };

  const handleDeleteDept = async (nodeData: any) => {
    await request('/api/system/dept/delete', { id: nodeData.key });
    Message.success('删除成功');
    fetchDeptTree();
  };

  // ========== 管理员方法 ==========
  const fetchRoleList = () => {
    request('/api/role/list', { pageSize: 100 }).then((res: any) => {
      roleList.value = res.data?.list || [];
    });
  };

  const handleRefresh = () => {
    tableRef.value?.search();
  };

  const getGenderText = (gender: number) => {
    const texts = ['未知', '男', '女'];
    return texts[gender] || '未知';
  };

  const openModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, record);
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
        role_id: undefined,
        remark: '',
      });
    }
    modalVisible.value = true;
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return;

    if (!isEdit.value && formData.password !== formData.confirm_password) {
      Message.error('两次密码输入不一致');
      return;
    }

    request('/api/system/admin/save', formData).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '添加成功');
      modalVisible.value = false;
      handleRefresh();
    });
  };

  const changeStatus = (record: any) => {
    record.loading = true;
    request('/api/system/admin/set', {
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

  const resetPassword = (record: any) => {
    Modal.confirm({
      title: '重置密码',
      content: `确定要重置 ${record.username} 的密码吗？`,
      onOk: () => {
        request('/api/system/admin/resetPassword', { id: record.id })
          .then(() => {
            Message.success('密码已重置，新密码已发送至用户邮箱');
          })
          .catch(() => {
            Message.error('重置密码失败');
          });
      },
    });
  };

  const deleteAdmin = (record: any) => {
    request('/api/system/admin/delete', { id: record.id }).then(() => {
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
    request('/api/system/admin/assignRoles', {
      id: roleRecord.value.id,
      role_ids: selectedRoles.value.map(Number),
    }).then(() => {
      Message.success('角色分配成功');
      roleVisible.value = false;
      handleRefresh();
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
    border: 1px solid var(--color-border-2);
    border-radius: 5px;
    min-height: 700px;
    max-height: 700px;
    overflow: hidden;
    display: flex;
    flex-direction: column;

    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 8px 12px;
      border-bottom: 1px solid var(--color-border-2);
      font-weight: 500;
      font-size: 13px;
      background: var(--color-fill-1);
      flex-shrink: 0;
    }

    .tree-content {
      padding: 12px;
      flex: 1;
      overflow-y: auto;

      .tree-node {
        display: flex;
        justify-content: space-between;
        align-items: center;
        width: 100%;

        .node-title {
          flex: 1;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .node-actions {
          opacity: 0;
          transition: opacity 0.2s;
          flex-shrink: 0;
        }

        &:hover .node-actions {
          opacity: 1;
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

  .avatar-upload {
    display: flex;
    align-items: center;
    gap: 12px;
  }
</style>
