<template>
  <div class="tag-container">
    <a-card :bordered="false">
      <div class="header-actions">
        <a-button type="primary" @click="handleAdd">
          <template #icon><icon-plus /></template>
          新增标签
        </a-button>
        <a-input-search
          v-model="searchKey"
          placeholder="搜索标签名称"
          style="width: 300px"
          allow-clear
          @search="fetchData"
        />
      </div>

      <a-table
        :data="tableData"
        :loading="loading"
        :pagination="pagination"
        @page-change="handlePageChange"
      >
        <template #columns>
          <a-table-column title="ID" data-index="id" :width="80" />
          <a-table-column title="标签名称" data-index="name">
            <template #cell="{ record }">
              <a-tag :color="record.color">{{ record.name }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="标识" data-index="slug" />
          <a-table-column title="颜色" data-index="color">
            <template #cell="{ record }">
              <div style="display: flex; align-items: center; gap: 8px">
                <div
                  :style="{
                    width: '20px',
                    height: '20px',
                    backgroundColor: record.color,
                    borderRadius: '4px',
                  }"
                />
                <span>{{ record.color }}</span>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="使用次数" data-index="count" :width="100" />
          <a-table-column title="状态" data-index="status" :width="100">
            <template #cell="{ record }">
              <a-tag v-if="record.status === 0" color="red">禁用</a-tag>
              <a-tag v-else color="green">启用</a-tag>
            </template>
          </a-table-column>
          <a-table-column
            title="创建时间"
            data-index="created_at"
            :width="180"
          />
          <a-table-column title="操作" :width="200" fixed="right">
            <template #cell="{ record }">
              <a-space>
                <a-button type="text" size="small" @click="handleEdit(record)">
                  编辑
                </a-button>
                <a-popconfirm
                  content="确定删除该标签吗？"
                  @ok="handleDelete(record.id)"
                >
                  <a-button type="text" size="small" status="danger">
                    删除
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>

    <!-- 编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="modalTitle"
      width="500px"
      @before-ok="handleSubmit"
      @cancel="handleCancel"
    >
      <a-form :model="formData" :rules="rules" ref="formRef" layout="vertical">
        <a-form-item label="标签名称" field="name" required>
          <a-input v-model="formData.name" placeholder="请输入标签名称" />
        </a-form-item>
        <a-form-item label="标签标识" field="slug" required>
          <a-input
            v-model="formData.slug"
            placeholder="英文标识，如：hot"
            :disabled="isEdit"
          />
        </a-form-item>
        <a-form-item label="标签颜色" field="color" required>
          <div style="display: flex; gap: 12px; align-items: center">
            <input
              type="color"
              v-model="formData.color"
              style="width: 60px; height: 36px; border: none; cursor: pointer"
            />
            <a-input
              v-model="formData.color"
              placeholder="#1890ff"
              style="flex: 1"
            />
          </div>
          <div
            style="margin-top: 12px; display: flex; gap: 8px; flex-wrap: wrap"
          >
            <div
              v-for="color in presetColors"
              :key="color"
              :style="{
                width: '32px',
                height: '32px',
                backgroundColor: color,
                borderRadius: '4px',
                cursor: 'pointer',
                border: formData.color === color ? '2px solid #000' : 'none',
              }"
              @click="formData.color = color"
            />
          </div>
        </a-form-item>
        <a-form-item label="状态" field="status">
          <a-radio-group v-model="formData.status">
            <a-radio :value="1">启用</a-radio>
            <a-radio :value="0">禁用</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import { IconPlus } from '@arco-design/web-vue/es/icon';
  import { getTagList, createTag, updateTag, deleteTag } from '@/api/cms';
  import type { Tag } from '@/types/cms';

  const loading = ref(false);
  const tableData = ref<Tag[]>([]);
  const searchKey = ref('');
  const pagination = reactive({
    current: 1,
    pageSize: 20,
    total: 0,
    showTotal: true,
  });

  // 预设颜色
  const presetColors = [
    '#f5222d',
    '#fa541c',
    '#fa8c16',
    '#faad14',
    '#fadb14',
    '#a0d911',
    '#52c41a',
    '#13c2c2',
    '#1890ff',
    '#2f54eb',
    '#722ed1',
    '#eb2f96',
  ];

  // 表单
  const modalVisible = ref(false);
  const modalTitle = ref('');
  const isEdit = ref(false);
  const formRef = ref();
  const formData = ref<Partial<Tag>>({
    name: '',
    slug: '',
    color: '#1890ff',
    status: 1,
  });

  const rules = {
    name: [{ required: true, message: '请输入标签名称' }],
    slug: [{ required: true, message: '请输入标签标识' }],
    color: [{ required: true, message: '请选择标签颜色' }],
  };

  // 加载数据
  const fetchData = async () => {
    loading.value = true;
    try {
      const res = await getTagList({
        page: pagination.current,
        pageSize: pagination.pageSize,
        keyword: searchKey.value,
      });
      tableData.value = res.data.items || [];
      pagination.total = res.data.total || 0;
    } catch (error) {
      Message.error('加载失败');
    } finally {
      loading.value = false;
    }
  };

  const handlePageChange = (page: number) => {
    pagination.current = page;
    fetchData();
  };

  // 新增
  const handleAdd = () => {
    modalTitle.value = '新增标签';
    isEdit.value = false;
    formData.value = {
      name: '',
      slug: '',
      color: '#1890ff',
      status: 1,
    };
    modalVisible.value = true;
  };

  // 编辑
  const handleEdit = (record: Tag) => {
    modalTitle.value = '编辑标签';
    isEdit.value = true;
    formData.value = { ...record };
    modalVisible.value = true;
  };

  // 删除
  const handleDelete = async (id: number) => {
    try {
      await deleteTag(id);
      Message.success('删除成功');
      await fetchData();
    } catch (error) {
      Message.error('删除失败');
    }
  };

  // 提交
  const handleSubmit = async () => {
    const valid = await formRef.value?.validate();
    if (!valid) {
      try {
        if (isEdit.value) {
          await updateTag(formData.value.id!, formData.value);
          Message.success('更新成功');
        } else {
          await createTag(formData.value);
          Message.success('创建成功');
        }
        modalVisible.value = false;
        await fetchData();
        return true;
      } catch (error) {
        Message.error('操作失败');
        return false;
      }
    }
    return false;
  };

  const handleCancel = () => {
    formRef.value?.resetFields();
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style scoped lang="less">
  .tag-container {
    padding: 20px;
  }

  .header-actions {
    display: flex;
    justify-content: space-between;
    margin-bottom: 20px;
  }
</style>
