<template>
  <a-select
    ref="selectRef"
    v-bind="$attrs"
    :loading="loading"
    :model-value="modelValue"
    :multiple="multiple"
    :label-in-value="true"
    style="width: 100%"
    allow-search
    :options="showData"
    value-key="value"
    :virtual-list-props="virtualListProps"
    @change="valChange"
  >
  </a-select>
</template>

<script lang="ts" setup>
  import { computed, onBeforeMount, ref } from 'vue';
  import request from '@/api/request';

  const props = defineProps({
    modelValue: {
      type: [Array],
      default: null,
    },
    companySubject: {
      type: String,
      default: '',
    },
    multiple: {
      type: Boolean,
      default: false,
    },
    labelInValue: {
      type: Boolean,
      default: false,
    },
  });

  const loading = ref(false);
  const treeData = ref([]);
  const selectRef = ref();

  const emits = defineEmits([
    'update:modelValue',
    'update:companySubject',
    'change',
  ]);

  const showData = computed(() =>
    treeData.value.map((item: any) => {
      item.options.forEach((cItem: any) => {
        cItem.disabled =
          props.companySubject &&
          props.companySubject !== cItem.company_subject;
      });
      return item;
    })
  );

  const valChange = (val: any) => {
    // 优化：处理非多选情况
    if (val.length) {
      emits('update:companySubject', val[0]?.company_subject || '');
      emits('update:modelValue', val);
      emits('change', val);
    } else {
      emits('update:companySubject', '');
      emits('update:modelValue', []);
      emits('change', []);
    }
  };

  const virtualListProps = {
    height: '400px',
    fixedSize: true,
  };

  const getDataList = () => {
    loading.value = true;
    request('/api/mediaAccountList', {
      account_agent_type: 2,
      is_group_subject: true,
    })
      .then((resData) => {
        treeData.value = resData.data
          .filter((item: any) => item.company_subject)
          .map((item: any) => ({
            isGroup: true,
            label: item.company_subject,
            value: item.company_subject,
            options: item.accounts.map((cItem: any) => ({
              label: `${cItem.account_name}-${cItem.advertiser_id}`,
              title: cItem.account_name,
              key: cItem.advertiser_id,
              value: {
                label: `${cItem.account_name}-${cItem.advertiser_id}`,
                title: cItem.account_name,
                value: cItem.advertiser_id,
                company_subject: item.company_subject,
              },
              company_subject: item.company_subject,
            })),
          }));
      })
      .finally(() => {
        loading.value = false;
      });
  };

  onBeforeMount(() => {
    getDataList();
  });
</script>

<style scoped></style>
