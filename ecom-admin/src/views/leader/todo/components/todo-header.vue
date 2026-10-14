<template>
  <a-radio-group v-model="typeRadio" type="button" @change="change">
    <a-radio
      v-for="item in activeOptions"
      :key="item.module"
      :value="item.module"
      >{{ item.module }}</a-radio
    >
  </a-radio-group>
</template>

<script lang="ts" setup>
  import { ref, computed, reactive, watch, watchEffect } from 'vue';
  // import { getHeaders } from '@/api/dashboard';

  const props = defineProps({
    type: {
      type: [Number, String],
      default: '',
    },
    totalTodo: {
      type: Number,
      default: 0,
    },
  });
  const emits = defineEmits(['change', 'update:totalTodo']);
  const stateOption = reactive({
    module: '全部',
    total: 0,
  });
  const typeRadio = ref('全部');
  let options = ref([
    {
      module: '出库单',
      total: 0,
    },
  ]);
  const activeOptions = computed(() => {
    return [stateOption, ...options.value];
  });

  // 查询报价详情
  // const getDetailFn = async (id: any) => {
  //   try {
  //     let sendParams = {
  //       type: props.type,
  //     };
  // getHeaders(sendParams).then((res: any) => {
  //   console.log(res);
  //   stateOption.total = 0;
  //   if (res.data) {
  //     options.value = res.data;
  //     // 遍历options,汇总total
  //     options.value.forEach((item: any) => {
  //       stateOption.total += item.total;
  //     });
  //   } else {
  //     options.value = [];
  //   }
  // });
  //   } catch (error) {
  //     console.log(error);
  //   }
  // };
  watchEffect(() => {
    let newNum = stateOption.total;
    // 仅当type为1时，才会触发
    if (props.type === 1) {
      emits('update:totalTodo', newNum);
    }
  });
  const change = () => {
    // getDetailFn(props.type);
    emits('change', typeRadio.value);
  };
  watch(
    () => props.type,
    () => {
      if (props.type) {
        // 当类型发生改变，首先重置当前的待办总数
        stateOption.total = 0;
        typeRadio.value = '全部';
        // getDetailFn(props.type);
      }
    },
    {
      immediate: true,
    }
  );
</script>

<style lang="less" scoped>
  .arco-radio-group-button {
    flex-wrap: wrap;
    font-size: 14px;
  }
</style>
