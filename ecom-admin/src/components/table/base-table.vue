<template>
  <a-table
    v-if="$slots.columns"
    :row-key="rowKey"
    :pagination="noPagination ? false : pagination"
    :data="renderData"
    :columns="theColumns.data"
    :bordered="false"
    :size="tableSize"
    :scroll="scrollPercent"
    :loading="loading"
    :summary="() => summary"
    v-bind="$attrs"
    @page-change="onPageChange"
    @page-size-change="onPageSizeChange"
    @sorter-change="sortHandleChange"
  >
    <template #columns>
      <slot name="columns"></slot>
    </template>
    <template #summary-cell="{ column, record }">
      <div>{{ record[column.dataIndex] }}</div>
    </template>
  </a-table>
  <a-table
    v-if="!$slots.columns"
    v-model:columns="theColumns.data"
    :row-key="rowKey"
    :pagination="noPagination ? false : pagination"
    :data="renderData"
    :bordered="false"
    :size="tableSize"
    :scroll="{ x: 'max-content' }"
    :loading="loading"
    :summary="() => summary"
    v-bind="$attrs"
    @page-change="onPageChange"
    @page-size-change="onPageSizeChange"
    @selection-change="selectionChange"
    @sorter-change="sortHandleChange"
  >
    <template #columns>
      <a-table-column
        v-for="column in theColumns.data"
        :key="column.dataIndex"
        v-bind="column"
      >
        <template #title>
          <div>
            {{ column.title || '-' }}
            <a-popover v-if="column.description">
              <template #content>{{ column.description || '-' }}</template>
              <icon-question-circle class="help-icon" />
            </a-popover>
          </div>
        </template>
        <template #cell="{ record, dataIndex }">
          <!-- 如何将外部的插槽，选择性的嵌入到这里? -->
          <!-- 1、取到外部的插槽 2、展示插槽 3、展示未配置插槽的列-->
          <template
            v-if="isIncludes($slots, column.dataIndex, column.slotName)"
          >
            <template v-for="(slotItem, slotKey) in $slots" :key="slotKey">
              <div
                v-if="column.slotName == slotKey || record.dataIndex == slotKey"
                :style="{ maxWidth: `${column.maxWidth}px` }"
              >
                <slot v-bind="{ record }" :name="slotKey"></slot>
              </div>
            </template>
          </template>
          <!-- 如果有render函数  需要在这展示 -->
          <div v-else-if="column.render">
            <template
              v-if="
                record[column.dataIndex] &&
                typeof record[column.dataIndex] !== 'string'
              "
            >
              <ParseVnode
                :vnode="column.render({ record, column, dataIndex })"
              ></ParseVnode>
            </template>
            <span v-else>{{ record[column.dataIndex] || '-' }}</span>
          </div>
          <!-- 没有定义插槽的 直接展示在这里 -->
          <div v-else>{{ record[column.dataIndex] || '-' }}</div>
        </template>
      </a-table-column>
    </template>
  </a-table>
</template>

<script lang="ts" setup>
  import {
    ref,
    reactive,
    computed,
    watch,
    watchEffect,
    nextTick,
    h,
  } from 'vue';
  import { Pagination } from '@/types/global';
  import { getColumns } from '@/components/table/columns-setting';
  import { pageConfig } from './table-util';
  import ParseVnode from './parse-vnode.vue';

  const tableSize = 'small';

  const props = defineProps({
    dataConfig: {
      // 动态数据配置: 请求路径 | 请求方法 | 静态数据配置
      default: '',
      type: [String, Function, Array],
    },
    dataList: {
      default: () => [],
      type: [Array],
    },
    dataHandle: {
      type: Function,
      default: undefined,
    },
    serverPagination: {
      // 服务端翻页配置, 如使用 dataConfig 为静态数据，则服务端翻页强制为false
      default: true,
      type: Boolean,
    },
    columnsConfig: {
      default: () => {
        return [];
      },
      type: [Array],
      required: true,
    },
    // 数据列平台标识
    columnsPlatform: {
      default: null,
      type: [String, Number],
    },
    // 需要排序的字段
    sortKeys: {
      default: null,
      type: [Array],
    },
    sendParams: {
      type: Object,
      default: () => {
        return {};
      },
    },
    scrollPercent: {
      default: () => {
        return { x: '100%' };
      },
      type: Object,
    },
    noSelection: {
      default: () => {
        return false;
      },
      type: Boolean,
    },
    noPagination: {
      default: () => {
        return false;
      },
      type: Boolean,
    },
    rowKey: {
      default: 'id',
      type: String,
    },
    autoRequest: {
      default: true,
      type: Boolean,
    },
    loading: {
      default: false,
      type: Boolean,
    },
    dpagination: {
      default: null,
      type: Object,
    },
    hasSum: {
      default: false,
      type: Boolean,
    },
  });
  const emits = defineEmits([
    'sorterChange',
    'tableChange',
    'update:selectedKeys',
    'selectChange',
    'update:loading',
    'update:summaryData',
    'update:emptyFlag',
    'update:renderData',
    'pageChange',
    'update:dpagination',
  ]);
  const theColumns: any = reactive({
    data: [],
  });
  // 默认排序配置
  const sortOption: any = reactive({
    sort: {
      field: '',
      value: '',
    },
  });

  // 确保 theColumns.data 始终是数组
  watch(
    () => theColumns.data,
    (newVal) => {
      if (!Array.isArray(newVal)) {
        theColumns.data = [];
      }
    },
    { immediate: true }
  );

  watchEffect(() => {
    let cols = getColumns(props.columnsConfig, props.columnsPlatform);
    // 安全检查：确保 cols 是数组
    if (!Array.isArray(cols)) {
      cols = [];
    }
    if (props.sortKeys?.length && Array.isArray(theColumns.data)) {
      theColumns.data.forEach((item: any) => {
        if (props.sortKeys?.includes(item.dataIndex)) {
          item.sortable = {
            sortDirections: ['ascend', 'descend'],
            sorter: true,
            sortOrder:
              sortOption.sort?.field === item.dataIndex
                ? sortOption.sort?.value
                : '',
          };
        }
      });
    }
    theColumns.data = cols;
  });
  const renderData = ref<any[]>([]);
  const summary = ref<any[]>([]);

  // 确保 renderData 始终是数组
  watch(
    renderData,
    (newVal) => {
      if (!Array.isArray(newVal)) {
        renderData.value = [];
      }
    },
    { immediate: true }
  );
  const isIncludes = (slots: any, dataIndex: any, slotName: any) => {
    // 查验插槽是否存在对等的插槽
    let slotLastRes = Object.keys(slots).includes(slotName);
    // 查验dataIndex是否对等插槽
    let lastRes = Object.keys(slots).includes(dataIndex);
    // 任何一个能对上插槽 则返回true  就不直接渲染
    if (lastRes || slotLastRes) {
      return true;
    }
    return false;
  };
  // 生成分页参数
  let pagination: Pagination = reactive({
    ...pageConfig(props.dpagination),
  });
  // 搜索条件的计算依赖汇总
  const searchParams = computed(() => {
    let pra: any = {
      page: pagination.current,
      pageSize: pagination.pageSize,
      ...props.sendParams,
      ...sortOption,
    };
    if (props.sendParams.date?.length) {
      [pra.start_date, pra.end_date] = props.sendParams.date;
    }
    return pra;
  });

  // 向上抛出loading
  const refreshLoading = (flag: boolean) => {
    emits('update:loading', flag);
  };
  // 1.获取表格数据
  const fetchData = async (exportParams: any = {}) => {
    refreshLoading(true);

    nextTick(async () => {
      if (typeof props.dataConfig === 'function') {
        props
          .dataConfig({
            ...searchParams.value,
          })
          .then(({ data }: any) => {
            // 安全检查：确保 data 存在且有数据
            // 响应格式: {code: 200, msg: 'success', data: {list: [...], pagination: {...}}}
            let responseData = data?.data ?? data ?? {};
            let rawData =
              responseData?.list ?? responseData?.table ?? responseData ?? [];
            let listData = Array.isArray(rawData) ? rawData : [];

            if (props.hasSum) {
              if (listData.length > 1) {
                let summaryData = listData.shift();
                summary.value = summaryData ? [summaryData] : [];
              } else {
                listData = [];
                summary.value = [];
              }
            }
            if (props.dataHandle) {
              renderData.value = props.dataHandle(listData);
            } else {
              renderData.value = listData;
            }

            pagination.current =
              responseData.current_page || responseData.pagination?.page || 1;
            pagination.total =
              responseData.total ?? responseData.pagination?.total ?? 0;
            emits('update:dpagination', pagination);
            if (responseData.summary) {
              emits('update:summaryData', responseData.summary);
            }
            emits(
              'update:emptyFlag',
              !(
                responseData.total ||
                responseData.pagination?.total ||
                listData.length
              )
            );
            refreshLoading(false);
            emits('tableChange', renderData.value);
          })
          .catch((err: any) => {
            // eslint-disable-next-line no-underscore-dangle
            if (!err.__CANCEL__) {
              renderData.value = [];
              refreshLoading(false);
              emits('tableChange', renderData.value);
            }
          });
      } else {
        renderData.value = props.dataList;
        emits('tableChange', renderData.value);
      }
    });
  };
  // 2.重置页码搜索
  const resetPage = () => {
    pagination.current = 1;
    fetchData();
  };
  // 3.点击搜索时 处理逻辑
  const search = () => {
    resetPage();
  };
  // 4.监听页码更换
  const onPageChange = (current: number) => {
    pagination.current = current;
    emits('pageChange', pagination);
    if (props.serverPagination) {
      fetchData();
    }
  };
  // 5.页码大小变化
  const onPageSizeChange = (pageSize: number) => {
    pagination.pageSize = pageSize;
    fetchData();
  };
  // 6.表格变化 用来后端排序
  const sortHandleChange = (dataIndex: string, direction: string) => {
    Object.assign(sortOption, {
      sort: {
        field: direction ? dataIndex : '',
        value: direction,
      },
    });
    setTimeout(() => {
      fetchData();
    }, 200);
    // emits('sorterChange', dataIndex, direction);
  };
  // 导出表格
  const exportTable = (data: any) => {
    if (typeof props.dataConfig === 'function') {
      try {
        return props.dataConfig({
          export: true,
          export_now: true,
          header: theColumns.data,
          ...data,
          ...searchParams.value,
        });
      } catch (err) {
        console.log(err);
        refreshLoading(false);
      }
      return Promise.resolve();
    }
    return '';
  };
  // 外部修改内部数据
  const setTableData = (idx: number, key: string, val: any) => {
    renderData.value[idx][key] = val;
  };
  // 选择行发生变化
  const selectionChange = (rowKeys: any[]) => {
    // 根据rowKeys获取选中行的数据
    const selectedRows = renderData.value.filter((item) => {
      return rowKeys.includes(item[props.rowKey]);
    });
    emits('update:selectedKeys', rowKeys);
    emits('selectChange', rowKeys, selectedRows);
  };
  watch(renderData, () => {
    emits('update:renderData', renderData.value);
  });
  if (props.autoRequest) {
    fetchData();
  }

  // 暴露外部刷新方法
  defineExpose({
    search,
    fetchData,
    setTableData,
    exportTable,
  });
</script>

<style scoped lang="less">
  :deep(.arco-table-element) {
    table-layout: auto !important;
  }
</style>
