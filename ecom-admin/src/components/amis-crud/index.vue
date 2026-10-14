<template>
  <div class="amis-crud-wrapper">
    <a-spin v-if="loading" :loading="true" style="width: 100%; height: 400px" />
    <AmisRenderer v-else-if="schema" :schema="schema" @event="handleEvent" />
  </div>
</template>

<script setup lang="ts">
  import { ref, onMounted, onUnmounted, computed } from 'vue';
  import { AmisRenderer } from '@/components/amis';
  import {
    generateCrudSchema,
    type CrudConfig,
  } from '@/utils/amis-crud-generator';
  import {
    crudEventBus,
    CrudEvents,
    crudStateManager,
    crudInstanceManager,
  } from '@/utils/crud-event-bus';
  import './style.less';

  interface Props {
    config: CrudConfig;
    id?: string; // CRUD 实例 ID
  }

  const props = defineProps<Props>();
  const schema = ref<any>(null);
  const loading = ref(true);
  const crudId = computed(() => props.id || `crud_${Date.now()}`);

  // 数据加载完成
  const handleDataLoaded = (data: any) => {
    crudStateManager.update(crudId.value, {
      loading: false,
      data: data.items || [],
      total: data.total || 0,
    });
    crudEventBus.emit(CrudEvents.DATA_LOADED, { id: crudId.value, data });
    props.config.events?.onLoad?.(data);
  };

  // 新增
  const handleAdd = async (data: any) => {
    await props.config.events?.onAdd?.(data);
    crudEventBus.emit(CrudEvents.DATA_ADDED, { id: crudId.value, data });
    props.config.events?.onAddSuccess?.(data);
  };

  // 编辑
  const handleEdit = async (data: any) => {
    await props.config.events?.onEdit?.(data);
    crudEventBus.emit(CrudEvents.DATA_UPDATED, { id: crudId.value, data });
    props.config.events?.onEditSuccess?.(data);
  };

  // 删除
  const handleDelete = async (data: any) => {
    const canDelete = await props.config.events?.onDelete?.(data);
    if (canDelete === false) return;
    crudEventBus.emit(CrudEvents.DATA_DELETED, { id: crudId.value, data });
    props.config.events?.onDeleteSuccess?.(data);
  };

  // 批量操作
  const handleBulkAction = (data: any) => {
    crudEventBus.emit(CrudEvents.DATA_BULK_ACTION, {
      id: crudId.value,
      data,
    });
    props.config.events?.onBulkAction?.(data.action, data.items);
  };

  // 行点击
  const handleRowClick = (row: any) => {
    crudEventBus.emit(CrudEvents.ROW_CLICKED, { id: crudId.value, row });
    props.config.events?.onRowClick?.(row);
  };

  // 选择变化
  const handleSelectionChange = (rows: any[]) => {
    crudStateManager.update(crudId.value, { selectedRows: rows });
    crudEventBus.emit(CrudEvents.SELECTION_CHANGED, {
      id: crudId.value,
      rows,
    });
    props.config.events?.onSelectionChange?.(rows);
  };

  // 处理 Amis 事件
  const handleEvent = (event: any) => {
    const { type, data } = event;

    switch (type) {
      case 'loaded':
        handleDataLoaded(data);
        break;
      case 'add':
        handleAdd(data);
        break;
      case 'edit':
        handleEdit(data);
        break;
      case 'delete':
        handleDelete(data);
        break;
      case 'bulkAction':
        handleBulkAction(data);
        break;
      case 'rowClick':
        handleRowClick(data);
        break;
      case 'selectionChange':
        handleSelectionChange(data);
        break;
      default:
        break;
    }
  };

  // 刷新数据
  const refresh = () => {
    crudEventBus.emit(CrudEvents.REFRESH, { id: crudId.value });
  };

  // 重新加载
  const reload = () => {
    crudEventBus.emit(CrudEvents.RELOAD, { id: crudId.value });
  };

  // 获取选中行
  const getSelectedRows = () => {
    return crudStateManager.get(crudId.value)?.selectedRows || [];
  };

  // 清空选择
  const clearSelection = () => {
    crudStateManager.update(crudId.value, { selectedRows: [] });
  };

  onMounted(async () => {
    try {
      // 初始化状态
      crudStateManager.init(crudId.value);

      // 注册实例
      crudInstanceManager.register({
        id: crudId.value,
        config: props.config,
        refresh,
        reload,
        getSelectedRows,
        clearSelection,
      });

      // 生成 Schema
      schema.value = await generateCrudSchema(props.config);

      // 触发初始化事件
      props.config.events?.onInit?.(props.config);
    } catch (error) {
      console.error('生成 CRUD Schema 失败:', error);
      crudEventBus.emit(CrudEvents.ERROR, { id: crudId.value, error });
    } finally {
      loading.value = false;
    }
  });

  onUnmounted(() => {
    // 清理资源
    crudInstanceManager.unregister(crudId.value);
    crudStateManager.remove(crudId.value);
  });

  // 暴露方法给父组件
  defineExpose({
    refresh,
    reload,
    getSelectedRows,
    clearSelection,
  });
</script>

<style scoped lang="less">
  .amis-crud-wrapper {
    width: 100%;
    height: 100%;
  }
</style>
