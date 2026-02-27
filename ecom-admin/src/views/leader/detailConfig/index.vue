<template>
  <div class="content-box">
    <a-card class="table-card">
      <div class="table-card-header">
        <a-space>
          <a-button size="small" type="primary" @click="saveAction(null)">
            <template #icon>
              <icon-plus />
            </template>
            新增
          </a-button>
        </a-space>
        <a-space class="c-table-tool-item"> </a-space>
      </div>
      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #content="{ record }">
          <span v-if="!record.content?.data?.url"> - </span>
          <a-image
            v-else
            height="80"
            width="80"
            :src="record.content?.data?.url"
            :preview="true"
          ></a-image>
        </template>
        <template #action="{ record }">
          <a-link @click="saveAction(record)"> 修改 </a-link>
          <a-divider direction="vertical" />
          <a-popconfirm
            :content="`确定删除【${record.title}】吗?`"
            @ok="delAction(record)"
          >
            <a-link> 删除 </a-link>
          </a-popconfirm>
        </template>
      </base-table>
    </a-card>
    <AddEditForm
      ref="saveRef"
      :hide-footer="false"
      @create-over="handleSubmit()"
    />
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import AddEditForm from './add-edit-form.vue';
  import { Message } from '@arco-design/web-vue';

  const user = useUserStore();

  const tableRef = ref();
  const saveRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: '排序',
      align: 'left',
      dataIndex: 'sort',
    },
    {
      title: '组件名称',
      align: 'left',
      dataIndex: 'title',
    },
    {
      title: '组件内容',
      align: 'left',
      dataIndex: 'content',
    },
    {
      title: '操作',
      align: 'left',
      dataIndex: 'action',
    },
  ];

  const generateFormModel = () => {
    return {
      // 基础查询条件
    };
  };

  const formModel: any = ref(generateFormModel());

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  const delAction = (data: any) => {
    loading.value = true;
    request('/api/product/detail/option/delete', {
      id: data.id,
    })
      .then(() => {
        Message.success('操作成功');
        handleSubmit();
      })
      .catch(() => {
        loading.value = false;
      });
  };

  const getDataList = (data: any) => {
    return request('/api/product/detail/option/list', data);
  };

  function saveAction(record: any) {
    saveRef.value?.show(record);
  }
</script>

<style scoped lang="less">
  .no-padding {
    :deep(.arco-card-body) {
      padding: 16px 16px 6px !important;
    }
  }
</style>
