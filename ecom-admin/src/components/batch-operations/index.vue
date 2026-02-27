<template>
  <a-space>
    <!-- 批量导入 -->
    <a-upload
      :custom-request="handleImport"
      :show-file-list="false"
      accept=".xlsx,.xls,.csv"
    >
      <a-button size="small">
        <template #icon><icon-import /></template>
        批量导入
      </a-button>
    </a-upload>

    <!-- 批量导出 -->
    <a-dropdown @select="handleExportSelect">
      <a-button size="small">
        <template #icon><icon-export /></template>
        批量导出
        <icon-down />
      </a-button>
      <template #content>
        <a-doption value="current">导出当前页</a-doption>
        <a-doption value="selected">导出选中项</a-doption>
        <a-doption value="all">导出全部</a-doption>
        <a-doption value="custom">自定义导出</a-doption>
      </template>
    </a-dropdown>

    <!-- 批量操作 -->
    <a-dropdown v-if="selectedKeys.length > 0" @select="handleBatchSelect">
      <a-button size="small" type="primary">
        批量操作 ({{ selectedKeys.length }})
        <icon-down />
      </a-button>
      <template #content>
        <a-doption value="edit">批量编辑</a-doption>
        <a-doption value="delete">批量删除</a-doption>
        <a-doption value="enable">批量启用</a-doption>
        <a-doption value="disable">批量禁用</a-doption>
      </template>
    </a-dropdown>
  </a-space>

  <!-- 自定义导出弹窗 -->
  <a-modal
    v-model:visible="exportModalVisible"
    title="自定义导出"
    width="600px"
    @ok="handleCustomExport"
  >
    <a-form :model="exportForm" layout="vertical">
      <a-form-item label="选择字段">
        <a-checkbox-group v-model="exportForm.fields" direction="vertical">
          <a-checkbox
            v-for="col in columns"
            :key="col.dataIndex"
            :value="col.dataIndex"
          >
            {{ col.title }}
          </a-checkbox>
        </a-checkbox-group>
      </a-form-item>
      <a-form-item label="导出格式">
        <a-radio-group v-model="exportForm.format">
          <a-radio value="xlsx">Excel (.xlsx)</a-radio>
          <a-radio value="csv">CSV (.csv)</a-radio>
        </a-radio-group>
      </a-form-item>
    </a-form>
  </a-modal>

  <!-- 批量编辑弹窗 -->
  <a-modal
    v-model:visible="batchEditVisible"
    title="批量编辑"
    width="500px"
    @ok="handleBatchEdit"
  >
    <a-form :model="batchEditForm" layout="vertical">
      <a-form-item label="选择要修改的字段">
        <a-select v-model="batchEditForm.field" placeholder="请选择字段">
          <a-option
            v-for="col in editableColumns"
            :key="col.dataIndex"
            :value="col.dataIndex"
          >
            {{ col.title }}
          </a-option>
        </a-select>
      </a-form-item>
      <a-form-item label="新值">
        <a-input v-model="batchEditForm.value" placeholder="请输入新值" />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
  import { ref } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';
  import * as XLSX from 'xlsx';

  interface Props {
    columns: any[];
    selectedKeys: (string | number)[];
    data: any[];
  }

  const props = defineProps<Props>();
  const emit = defineEmits([
    'import',
    'export',
    'batchEdit',
    'batchDelete',
    'batchStatus',
  ]);

  const exportModalVisible = ref(false);
  const batchEditVisible = ref(false);

  const exportForm = ref({
    fields: [] as string[],
    format: 'xlsx',
  });

  const batchEditForm = ref({
    field: '',
    value: '',
  });

  const editableColumns = props.columns.filter((col) => col.dataIndex !== 'id');

  // 批量导入
  const handleImport = async (option: any) => {
    const { file } = option.fileItem;
    const reader = new FileReader();

    reader.onload = (e: any) => {
      try {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
        const jsonData = XLSX.utils.sheet_to_json(firstSheet);

        emit('import', jsonData);
        Message.success(`成功导入 ${jsonData.length} 条数据`);
      } catch (error: any) {
        Message.error(`导入失败: ${error.message}`);
      }
    };

    reader.readAsArrayBuffer(file);
  };

  // 导出数据
  const handleExport = (type: string) => {
    let exportData = [];

    switch (type) {
      case 'current':
        exportData = props.data;
        break;
      case 'selected':
        exportData = props.data.filter((item) =>
          props.selectedKeys.includes(item.id)
        );
        break;
      case 'all':
        exportData = props.data;
        break;
      default:
        exportData = props.data;
        break;
    }

    if (exportData.length === 0) {
      Message.warning('没有可导出的数据');
      return;
    }

    const ws = XLSX.utils.json_to_sheet(exportData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Sheet1');
    XLSX.writeFile(wb, `export_${Date.now()}.xlsx`);

    Message.success(`成功导出 ${exportData.length} 条数据`);
    emit('export', { type, data: exportData });
  };

  // 导出选择
  const handleExportSelect = (value: string) => {
    if (value === 'custom') {
      exportForm.value.fields = props.columns.map((col) => col.dataIndex);
      exportModalVisible.value = true;
    } else {
      handleExport(value);
    }
  };

  // 自定义导出
  const handleCustomExport = () => {
    const exportData = props.data.map((item) => {
      const filtered: any = {};
      exportForm.value.fields.forEach((field) => {
        filtered[field] = item[field];
      });
      return filtered;
    });

    const ws = XLSX.utils.json_to_sheet(exportData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Sheet1');
    const ext = exportForm.value.format === 'csv' ? 'csv' : 'xlsx';
    XLSX.writeFile(wb, `custom_export_${Date.now()}.${ext}`);

    Message.success(`成功导出 ${exportData.length} 条数据`);
    exportModalVisible.value = false;
  };

  // 批量删除
  const handleBatchDelete = () => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除选中的 ${props.selectedKeys.length} 条数据吗？此操作不可恢复。`,
      onOk: () => {
        emit('batchDelete', props.selectedKeys);
        Message.success(`已删除 ${props.selectedKeys.length} 条数据`);
      },
    });
  };

  // 批量状态
  const handleBatchStatus = (status: number) => {
    emit('batchStatus', {
      ids: props.selectedKeys,
      status,
    });
    Message.success(
      `已批量${status ? '启用' : '禁用'} ${props.selectedKeys.length} 条数据`
    );
  };

  // 批量操作选择
  const handleBatchSelect = (value: string) => {
    switch (value) {
      case 'edit':
        batchEditVisible.value = true;
        break;
      case 'delete':
        handleBatchDelete();
        break;
      case 'enable':
        handleBatchStatus(1);
        break;
      case 'disable':
        handleBatchStatus(0);
        break;
      default:
        break;
    }
  };

  // 批量编辑
  const handleBatchEdit = () => {
    if (!batchEditForm.value.field || !batchEditForm.value.value) {
      Message.warning('请填写完整信息');
      return;
    }

    emit('batchEdit', {
      ids: props.selectedKeys,
      field: batchEditForm.value.field,
      value: batchEditForm.value.value,
    });

    Message.success(`已批量修改 ${props.selectedKeys.length} 条数据`);
    batchEditVisible.value = false;
    batchEditForm.value = { field: '', value: '' };
  };
</script>
