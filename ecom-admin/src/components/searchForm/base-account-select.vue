<template>
  <div>
    <a-select
      ref="selectRef"
      v-model:model-value="curVal"
      :placeholder="placeholder"
      :loading="loading"
      :multiple="multiple"
      :allow-search="true"
      :allow-clear="true"
      @change="handleChange"
      @search="searchOption"
    >
      <a-option
        v-for="item of dataList"
        :key="item[valueKey]"
        :value="item[valueKey]"
        :label="item[labelKey]"
      />
    </a-select>
  </div>
</template>

<script lang="ts" setup>
  import { ref, watch } from 'vue';
  import useLoading from '@/hooks/loading';

  const props = defineProps({
    placeholder: {
      type: String,
      default: () => '请选择',
    },
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
      type: [String, Number],
      default: () => 0,
    },
    // 传入的数据
    options: {
      type: Array,
      default: () => [],
    },
  });
  const emit = defineEmits(['input', 'change', 'update:modelValue']);
  const { loading, setLoading } = useLoading(false);
  const curVal = ref<any>(null);
  const initFlag = ref(false);
  // 第一次进来后赋值  触发change事件
  const createFlag = ref(true);

  const selectRef = ref();
  // 做下拉滚动加载
  const pageSize = ref<number>(1);
  const pageLength = ref<number>(20);
  const cacheList: any = ref([]);
  const dataList: any = ref([]);

  const showList: any = ref([]);

  const refreshShowList = () => {
    // console.log('重新获取');
  };

  const popupVisibleChange = (val: any) => {
    if (!val) {
      // pageSize.value = 1;
      // refreshSortList();
    } else {
      // 勾选后更新
      // dataList.value = cacheList.value.slice();
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
    setLoading(false);
  };

  watch(
    () => props.options,
    () => {
      dataList.value = props.options || [];
      cacheList.value = props.options || [];
      // handleChange(props.modelValue);
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
</script>

<style lang="less"></style>
