<template>
  <div class="content-box">
    <a-card>
      <a-row :gutter="16">
        <!-- 左侧：字典分类 -->
        <a-col :span="5">
          <div class="category-section">
            <div class="section-header">
              <span>字典分类</span>
              <a-button type="text" size="mini" @click="handleAddCategory">
                <template #icon><icon-plus /></template>
              </a-button>
            </div>
            <a-menu
              :selected-keys="[selectedCategory]"
              size="small"
              @menu-item-click="handleCategoryClick"
            >
              <a-menu-item key="all">
                <template #icon><icon-apps /></template>
                全部字典
              </a-menu-item>
              <a-menu-item v-for="item in categoryList" :key="item.category_code">
                <template #icon><icon-folder /></template>
                <span>{{ item.category_name }}</span>
              </a-menu-item>
            </a-menu>
          </div>
        </a-col>

        <!-- 右侧：字典列表 -->
        <a-col :span="19">
          <div class="dict-section">
            <div class="section-toolbar">
              <a-space size="small">
                <a-input-search
                  v-model="searchKey"
                  placeholder="搜索字典名称或编码"
                  size="small"
                  style="width: 300px"
                  @search="fetchDictList"
                />
              </a-space>
              <a-button type="primary" size="small" @click="handleAddDict">
                <template #icon><icon-plus /></template>
                添加字典
              </a-button>
            </div>

            <a-table
              :data="dictList"
              :columns="dictColumns"
              :pagination="pagination"
              :loading="loading"
              size="small"
              @page-change="handlePageChange"
            >
              <template #category="{ record }">
                <a-tag color="arcoblue">{{ record.category_name }}</a-tag>
              </template>
              <template #status="{ record }">
                <a-switch
                  :model-value="record.status === 1"
                  size="small"
                  @change="handleStatusChange(record)"
                />
              </template>
              <template #action="{ record }">
                <a-space>
                  <a-button
                    type="text"
                    size="small"
                    @click="handleManageItems(record)"
                  >
                    字典项
                  </a-button>
                  <a-button
                    type="text"
                    size="small"
                    @click="handleEditDict(record)"
                  >
                    编辑
                  </a-button>
                  <a-popconfirm
                    content="确定删除该字典吗？"
                    @ok="handleDeleteDict(record)"
                  >
                    <a-button type="text" size="small" status="danger">
                      删除
                    </a-button>
                  </a-popconfirm>
                </a-space>
              </template>
            </a-table>
          </div>
        </a-col>
      </a-row>
    </a-card>

    <!-- 字典编辑弹窗 -->
    <a-modal
      v-model:visible="dictModalVisible"
      :title="dictModalTitle"
      width="600px"
      @before-ok="handleDictSave"
    >
      <a-form ref="dictFormRef" :model="dictForm" :rules="dictRules">
        <a-form-item label="字典分类" field="category_code">
          <a-select v-model="dictForm.category_code" placeholder="请选择分类">
            <a-option
              v-for="item in categoryList"
              :key="item.category_code"
              :value="item.category_code"
            >
              {{ item.category_name }}
            </a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="字典名称" field="dict_name">
          <a-input v-model="dictForm.dict_name" placeholder="请输入字典名称" />
        </a-form-item>
        <a-form-item label="字典编码" field="dict_code">
          <a-input v-model="dictForm.dict_code" placeholder="如：user_status" />
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea v-model="dictForm.remark" placeholder="请输入备注" />
        </a-form-item>
        <a-form-item label="状态">
          <a-switch v-model="dictForm.status" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 字典项管理弹窗 -->
    <a-modal
      v-model:visible="itemModalVisible"
      :title="`字典项管理 - ${currentDict.dict_name}`"
      width="900px"
      :footer="false"
    >
      <div style="margin-bottom: 16px">
        <a-space>
          <a-input-search
            v-model="itemSearchKey"
            placeholder="筛选字典项名称或值"
            size="small"
            style="width: 260px"
            @search="fetchItemList(currentDict.id)"
          />
          <a-button type="primary" size="small" @click="handleAddItem">
            <template #icon><icon-plus /></template>
            添加字典项
          </a-button>
        </a-space>
      </div>
      <a-table
        :data="itemList"
        :columns="itemColumns"
        :pagination="false"
        size="small"
      >
        <template #status="{ record }">
          <a-switch
            :model-value="record.status === 1"
            size="small"
            @change="handleItemStatusChange(record)"
          />
        </template>
        <template #action="{ record }">
          <a-space>
            <a-button type="text" size="mini" @click="handleEditItem(record)">
              编辑
            </a-button>
            <a-popconfirm
              content="确定删除该字典项吗？"
              @ok="handleDeleteItem(record)"
            >
              <a-button type="text" size="mini" status="danger">
                删除
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>
    </a-modal>

    <!-- 字典项编辑弹窗 -->
    <a-modal
      v-model:visible="itemEditModalVisible"
      :title="itemModalTitle"
      width="500px"
      @before-ok="handleItemSave"
    >
      <a-form ref="itemFormRef" :model="itemForm" :rules="itemRules">
        <a-form-item label="字典项名称" field="item_name">
          <a-input v-model="itemForm.item_name" placeholder="请输入名称" />
        </a-form-item>
        <a-form-item label="字典项值" field="item_value">
          <a-input v-model="itemForm.item_value" placeholder="请输入值" />
        </a-form-item>
        <a-form-item label="排序">
          <a-input-number v-model="itemForm.sort" :min="0" />
        </a-form-item>
        <a-form-item label="状态">
          <a-switch v-model="itemForm.status" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 分类编辑弹窗 -->
    <a-modal
      v-model:visible="categoryModalVisible"
      title="添加字典分类"
      width="500px"
      @before-ok="handleCategorySave"
    >
      <a-form :model="categoryForm">
        <a-form-item label="分类名称">
          <a-input v-model="categoryForm.category_name" placeholder="请输入分类名称" />
        </a-form-item>
        <a-form-item label="分类编码">
          <a-input v-model="categoryForm.category_code" placeholder="请输入分类编码" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import request, { METHOD } from '@/api/request';

  type CategoryItem = {
    id: number;
    category_name: string;
    category_code: string;
    sort?: number;
    status?: number;
  };

  // 分类相关
  const selectedCategory = ref('all');
  const categoryList = ref<CategoryItem[]>([]);

  // 字典列表相关
  const loading = ref(false);
  const searchKey = ref('');
  const dictList = ref<any[]>([]);
  const pagination = reactive({
    current: 1,
    pageSize: 10,
    total: 0,
  });

  const dictColumns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    { title: '分类', dataIndex: 'category', slotName: 'category', width: 100 },
    { title: '字典名称', dataIndex: 'dict_name', width: 150 },
    { title: '字典编码', dataIndex: 'dict_code', width: 150 },
    { title: '备注', dataIndex: 'remark', ellipsis: true },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
    { title: '操作', dataIndex: 'action', slotName: 'action', width: 200 },
  ];

  // 字典编辑相关
  const dictModalVisible = ref(false);
  const dictFormRef = ref();
  const dictForm = reactive({
    id: 0,
    category_code: '',
    dict_name: '',
    dict_code: '',
    remark: '',
    status: true,
  });
  const dictRules = {
    category_code: [{ required: true, message: '请选择字典分类' }],
    dict_name: [{ required: true, message: '请输入字典名称' }],
    dict_code: [{ required: true, message: '请输入字典编码' }],
  };
  const dictModalTitle = computed(() =>
    dictForm.id ? '编辑字典' : '添加字典'
  );

  // 字典项相关
  const itemModalVisible = ref(false);
  const itemEditModalVisible = ref(false);
  const currentDict = ref<any>({});
  const itemList = ref<any[]>([]);
  const itemSearchKey = ref('');
  const itemFormRef = ref();
  const itemForm = reactive({
    id: 0,
    dict_id: 0,
    item_name: '',
    item_value: '',
    sort: 0,
    status: true,
  });
  const itemRules = {
    item_name: [{ required: true, message: '请输入字典项名称' }],
    item_value: [{ required: true, message: '请输入字典项值' }],
  };
  const itemModalTitle = computed(() =>
    itemForm.id ? '编辑字典项' : '添加字典项'
  );

  // 分类编辑相关
  const categoryModalVisible = ref(false);
  const categoryForm = reactive({
    category_name: '',
    category_code: '',
  });

  const itemColumns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    { title: '字典项名称', dataIndex: 'item_name', width: 150 },
    { title: '字典项值', dataIndex: 'item_value', width: 150 },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
    { title: '操作', dataIndex: 'action', slotName: 'action', width: 150 },
  ];

  // 获取分类列表
  const fetchCategoryList = () => {
    request('/api/system/dict/list', { page: 1, page_size: 1000 }, undefined, METHOD.GET).then(
      (res: any) => {
        const list = res.data?.list || [];
        const categoryMap = new Map<string, CategoryItem>();
        list.forEach((item: any) => {
          const code = item.category_code;
          if (!code || categoryMap.has(code)) return;
          categoryMap.set(code, {
            id: 0,
            category_code: code,
            category_name: item.category_name || code,
          });
        });
        categoryList.value = Array.from(categoryMap.values());
        if (
          selectedCategory.value !== 'all' &&
          !categoryList.value.some(
            (item) => item.category_code === selectedCategory.value
          )
        ) {
          selectedCategory.value = 'all';
        }
      }
    );
  };

  // 获取字典列表
  const fetchDictList = () => {
    loading.value = true;
    const params: any = {
      page: pagination.current,
      page_size: pagination.pageSize,
      keyword: searchKey.value,
    };
    if (selectedCategory.value !== 'all') {
      params.category = selectedCategory.value;
    }

    request('/api/system/dict/list', params, undefined, METHOD.GET)
      .then((res: any) => {
        dictList.value = res.data?.list || [];
        pagination.total = res.data?.total || 0;
      })
      .finally(() => {
        loading.value = false;
      });
  };

  // 分类点击
  const handleCategoryClick = (key: string) => {
    selectedCategory.value = key;
    pagination.current = 1;
    fetchDictList();
  };

  // 添加分类
  const handleAddCategory = () => {
    categoryForm.category_name = '';
    categoryForm.category_code = '';
    categoryModalVisible.value = true;
  };

  const handleCategorySave = async () => {
    const category_name = categoryForm.category_name.trim();
    const category_code = categoryForm.category_code.trim();
    if (!category_name || !category_code) {
      Message.warning('请填写完整信息');
      return false;
    }
    const exists = categoryList.value.some(
      (item) => item.category_code === category_code
    );
    if (exists) {
      Message.warning('分类编码已存在');
      return false;
    }
    categoryList.value.push({
      id: 0,
      category_name,
      category_code,
    });
    selectedCategory.value = category_code;
    dictForm.category_code = category_code;
    Message.success('添加成功');
    return true;
  };

  // 添加字典
  const handleAddDict = () => {
    Object.assign(dictForm, {
      id: 0,
      category_code:
        selectedCategory.value === 'all' ? '' : selectedCategory.value,
      dict_name: '',
      dict_code: '',
      remark: '',
      status: true,
    });
    dictModalVisible.value = true;
  };

  // 编辑字典
  const handleEditDict = (record: any) => {
    Object.assign(dictForm, {
      ...record,
      status: record.status === 1,
    });
    dictModalVisible.value = true;
  };

  // 保存字典
  const handleDictSave = async () => {
    const valid = await dictFormRef.value?.validate();
    if (valid) return false;

    const params = {
      ...dictForm,
      status: dictForm.status ? 1 : 0,
    };

    await request('/api/system/dict/save', params, undefined, METHOD.POST);
    Message.success(dictForm.id ? '编辑成功' : '添加成功');
    fetchCategoryList();
    fetchDictList();
    return true;
  };

  // 删除字典
  const handleDeleteDict = async (record: any) => {
    await request('/api/system/dict/delete', { id: record.id }, undefined, METHOD.POST);
    Message.success('删除成功');
    fetchCategoryList();
    fetchDictList();
  };

  // 状态切换
  const handleStatusChange = (record: any) => {
    request(
      '/api/system/dict/set',
      {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
      },
      undefined,
      METHOD.POST
    ).then(() => {
      Message.success('状态更新成功');
      fetchDictList();
    });
  };

  // 分页
  const handlePageChange = (page: number) => {
    pagination.current = page;
    fetchDictList();
  };

  // 管理字典项
  const handleManageItems = (record: any) => {
    currentDict.value = record;
    itemSearchKey.value = '';
    itemModalVisible.value = true;
    fetchItemList(record.id);
  };

  // 获取字典项列表
  const fetchItemList = (dictId: number) => {
    request('/api/system/dict/items', {
      dict_id: dictId,
      keyword: itemSearchKey.value,
    }, undefined, METHOD.GET).then((res: any) => {
      itemList.value = res.data?.list || [];
    });
  };

  // 添加字典项
  const handleAddItem = () => {
    Object.assign(itemForm, {
      id: 0,
      dict_id: currentDict.value.id,
      item_name: '',
      item_value: '',
      sort: 0,
      status: true,
    });
    itemEditModalVisible.value = true;
  };

  // 编辑字典项
  const handleEditItem = (record: any) => {
    Object.assign(itemForm, {
      ...record,
      status: record.status === 1,
    });
    itemEditModalVisible.value = true;
  };

  // 保存字典项
  const handleItemSave = async () => {
    const valid = await itemFormRef.value?.validate();
    if (valid) return false;

    const params = {
      ...itemForm,
      status: itemForm.status ? 1 : 0,
    };

    await request('/api/system/dict/item/save', params, undefined, METHOD.POST);
    Message.success(itemForm.id ? '编辑成功' : '添加成功');
    fetchItemList(currentDict.value.id);
    return true;
  };

  // 删除字典项
  const handleDeleteItem = async (record: any) => {
    await request('/api/system/dict/item/delete', { id: record.id }, undefined, METHOD.POST);
    Message.success('删除成功');
    fetchItemList(currentDict.value.id);
  };

  // 字典项状态切换
  const handleItemStatusChange = (record: any) => {
    request(
      '/api/system/dict/item/set',
      {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
      },
      undefined,
      METHOD.POST
    ).then(() => {
      Message.success('状态更新成功');
      fetchItemList(currentDict.value.id);
    });
  };

  onMounted(() => {
    fetchCategoryList();
    fetchDictList();
  });
</script>

<style lang="less" scoped>
  .content-box {
    padding: 0;
  }

  .category-section {
    border-right: 1px solid var(--color-border-2);
    min-height: 600px;

    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 8px 12px;
      border-bottom: 1px solid var(--color-border-2);
      font-weight: 500;
      font-size: 13px;
      background: var(--color-fill-1);
    }

    :deep(.arco-menu) {
      border-right: none;
      padding: 4px;

      .arco-menu-item {
        margin-bottom: 2px;
        border-radius: 4px;
        height: 32px;
        line-height: 32px;
        font-size: 13px;
      }
    }

  }

  .dict-section {
    padding: 16px;

    .section-toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
    }
  }
</style>
