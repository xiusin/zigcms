<template>
  <a-select
    ref="selectRef"
    v-model="curVal"
    :value-key="valueKey"
    :label-key="labelKey"
    :placeholder="placeholder"
    :loading="loading"
    :multiple="multiple"
    :allow-search="true"
    :allow-clear="true"
    :unmount-on-close="false"
    :max-tag-count="maxTagCount"
    v-bind="$attrs"
    @search="searchOption"
    @dropdown-reach-bottom="handleReachBottomScroll"
    @change="handleChange"
    @popup-visible-change="popupVisibleChange"
  >
    <a-option
      v-for="item of showList"
      :key="item[valueKey]"
      :value="item[valueKey]"
      :label="item[labelKey]"
    />
  </a-select>
</template>

<script lang="ts" setup>
  import { ref, watch, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import useLoading from '@/hooks/loading';
  import { getMediaAccountList } from '@/api/base';

  const props = defineProps({
    placeholder: {
      type: String,
      default: () => '请选择',
    },
    // dataList: {
    //   type: Array,
    //   default: () => [],
    // },
    modelValue: {
      type: [String, Number, Array, Object],
      default: () => '',
    },
    // id的键值
    valueKey: {
      type: [String],
      default: () => 'advertiser_id',
    },
    labelKey: {
      type: [String, Number],
      default: () => 'account_name',
    },
    sendParams: {
      type: Object,
      default: () => {
        return {
          user_id: '',
        };
      },
    },
    rowIndex: {
      type: [String, Number],
      default: () => 0,
    },
    multiple: {
      type: Boolean,
      default: () => false,
    },
    maxTagCount: {
      type: Number,
      default: () => undefined,
    },
    // 传入的数据
    options: {
      type: Array,
      default: () => [],
    },
    sendParam: {
      default: () => {
        return {};
      },
      type: Object,
    },
  });
  const emit = defineEmits(['input', 'change', 'update:modelValue']);
  const { loading, setLoading } = useLoading(true);
  const curVal = ref<any>(null);

  const selectRef = ref();
  // 做下拉滚动加载
  const pageSize = ref<number>(1);
  const pageLength = ref<number>(20);
  const cacheList: any = ref([]);
  const dataList: any = ref([]);

  const showList: any = ref([]);

  const refreshSortList = () => {
    if (Array.isArray(curVal.value) && curVal.value) {
      // 多个数组
      curVal.value.forEach((selectItem: any) => {
        // 将勾选的值，顺序调整到第一位
        const index = showList.value.findIndex(
          (item: any) => item[props.valueKey] === selectItem
        );
        if (index !== -1) {
          const deletedItem = showList.value.splice(index, 1)[0];
          showList.value.unshift(deletedItem);
        } else {
          const ele = cacheList.value.find(
            (item: any) => item[props.valueKey] === selectItem
          );
          if (ele) {
            showList.value.unshift(ele);
          }
        }
      });
    }
  };

  const refreshShowList = () => {
    // console.log('重新获取');
    let lastData: any = [];
    const showSize = pageSize.value * pageLength.value;
    if (showSize > dataList.value.length || !showSize) {
      lastData = dataList.value;
    }
    lastData = dataList.value.slice(0, showSize);
    const tempArr: any = [];
    let checkVal = props.modelValue;
    // 统一变量类型
    if (!Array.isArray(checkVal)) {
      checkVal = [checkVal || undefined];
    }
    // 检查选中数据是否在当前页的list中，如果不在则补充进来
    checkVal.forEach((vid: any) => {
      if (!lastData.find((item: any) => item.key === vid)) {
        const ele = cacheList.value.find((item: any) => item.key === vid);
        if (ele) {
          tempArr.push(ele);
        }
      }
    });
    showList.value = [...tempArr, ...lastData];
    refreshSortList();
  };

  const popupVisibleChange = (val: any) => {
    if (!val) {
      pageSize.value = 1;
      refreshSortList();
    } else {
      // 勾选后更新
      dataList.value = cacheList.value.slice();
    }
  };

  const handleChange = async (val: any) => {
    emit('update:modelValue', val || null);
    let nowRecord: any = {};
    if (val) {
      nowRecord = await dataList.value.find((item: any) => {
        return item[props.valueKey] === val;
      });
    }
    emit('change', val || null, nowRecord, props.rowIndex);
    // setLoading(false);
  };

  watch(
    () => props.options,
    () => {
      dataList.value = props.options || [];
      cacheList.value = props.options || [];
      handleChange(props.modelValue);
    },
    {
      deep: true,
      immediate: true,
    }
  );
  watch(
    () => props.modelValue,
    (newVal) => {
      curVal.value = newVal;
    },
    {
      immediate: true,
      deep: true,
    }
  );
  watch(
    dataList.value,
    () => {
      refreshShowList();
    },
    {
      immediate: true,
    }
  );
  const handleReachBottomScroll = () => {
    // 当下拉框下拉并且滚动条到达底部的时候，累加备选数据
    if (showList.value.length !== dataList.value.length) {
      pageSize.value += 1;
      refreshShowList();
    }
  };
  // 搜索
  const searchOption = (val: any) => {
    // 搜索没有关键词
    // console.log('此时的cacheList 搜索关键词：', val);
    pageSize.value = 1;

    if (!val) {
      dataList.value = cacheList.value.slice();
    } else {
      dataList.value = cacheList.value.filter((item: any) => {
        return item[props.labelKey]
          ?.toLowerCase()
          .includes(val.trim().toLowerCase());
      });
    }
    refreshShowList();
  };
  const getDatalist = async (sendInfo: any) => {
    // 在拉起之前读取
    let MEDIA_ACCOUNT_DATA = localStorage.getItem('MEDIA_ACCOUNT_DATA');
    // 设定一个过期时间
    let LAST_ACCOUNT_TIME = localStorage.getItem('LAST_ACCOUNT_TIME');
    if (
      MEDIA_ACCOUNT_DATA &&
      LAST_ACCOUNT_TIME &&
      new Date().getTime() - Number(LAST_ACCOUNT_TIME) <= 3 * 60 * 1000
    ) {
      dataList.value = JSON.parse(MEDIA_ACCOUNT_DATA);
      cacheList.value = JSON.parse(MEDIA_ACCOUNT_DATA) || [];
      setLoading(false);
      refreshShowList();
      return;
    }
    loading.value = true;
    let params = {
      ...props.sendParam,
      ...sendInfo,
    };
    let resData = await getMediaAccountList(params);
    setLoading(false);
    loading.value = false;
    if (resData && resData.code === 0) {
      // 缓存媒体账号数据
      localStorage.setItem(
        'MEDIA_ACCOUNT_DATA',
        JSON.stringify(resData.data.data)
      );
      localStorage.setItem('LAST_ACCOUNT_TIME', `${new Date().getTime()}`);

      dataList.value = resData.data.data;
      cacheList.value = resData.data.data || [];
      refreshShowList();
    } else {
      Message.error(JSON.stringify(resData.msg || '网络异常'));
    }
  };
  onMounted(() => {
    getDatalist({});
  });
</script>

<style lang="less"></style>
