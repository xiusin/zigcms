<!--暂废弃 使用media-account-group-select-->
<template>
  <a-tree-select
    ref="selectRef"
    :loading="loading"
    :multiple="multiple"
    :data="showData"
    :label-in-value="labelInValue"
    style="width: 100%"
    :tree-props="treeProps"
    :model-value="modelValue"
    allow-search
    v-bind="$attrs"
    on-item-remove="onItemRemove"
    @change="valChange"
  >
  </a-tree-select>
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
      item.children.forEach((cItem: any) => {
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
      emits('update:modelValue', val);
      emits('change', val);
    } else {
      emits('update:companySubject', '');
      emits('update:modelValue', []);
      emits('change', []);
    }
  };

  const treeProps = computed(() => {
    return {
      onSelect(selectedKeys: any[], data: any) {
        emits(
          'update:companySubject',
          data.selectedNodes[0]?.company_subject || ''
        );
      },
      virtualListProps:
        treeData.value.length > 4
          ? {
              height: 360,
              threshold: 100,
              fixedSize: true,
              buffer: 10,
            }
          : undefined,
    };
  });

  const getDataList = () => {
    loading.value = true;
    request('/api/mediaAccountList', {
      account_agent_type: 2,
      is_group_subject: true,
    })
      .then((resData) => {
        treeData.value = resData.data.map((item: any) => ({
          title: item.company_subject,
          key: item.company_subject,
          disabled: true,
          children: item.accounts.map((cItem: any) => ({
            title: `${cItem.account_name}-${cItem.advertiser_id}`,
            label: cItem.account_name,
            key: cItem.advertiser_id,
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
