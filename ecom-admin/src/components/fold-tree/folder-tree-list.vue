<template>
  <div
    class="layout-left-side-content"
    :class="{ 'need-min-width': needMinWidth }"
  >
    <a-spin
      :loading="loading"
      style="min-height: 200px; width: 100%"
      tip="加载中..."
    >
      <div class="title-box">
        <div>
          <icon-folder />
          {{ preTitle }}文件夹
        </div>
        <a-button v-if="apis.save" type="text" @click="showAddModal({})">
          <icon-plus /> 新建
        </a-button>
      </div>
      <a-divider :margin="10" />
      <a-tree
        v-model:selected-keys="selectedKeys"
        v-model:expanded-keys="expandedKeys"
        :data="treeData"
        @select="onSelect"
      >
        <template v-if="showMenu" #extra="nodeData">
          <a-popover :content-style="{ padding: '6px 10px' }" position="left">
            <icon-more-vertical style="position: absolute; right: 0px" />
            <template #content>
              <a-space direction="vertical">
                <a-link
                  v-if="
                    apis.save && nodeData.key && nodeData.level_one !== 'share'
                  "
                  @click="() => saveAction(nodeData)"
                >
                  编辑 &nbsp;
                  <icon-edit />
                </a-link>
                <a-popconfirm
                  v-if="apis.del"
                  :content="`确定要删除【${nodeData.title}】吗?`"
                  position="left"
                  @ok="delClick(nodeData)"
                >
                  <a-link>
                    删除 &nbsp;
                    <icon-delete />
                  </a-link>
                </a-popconfirm>
                <a-link
                  v-if="
                    nodeData.level_one !== 'share' && apis.share && nodeData.key
                  "
                  @click="() => shareAction(nodeData)"
                >
                  分享 &nbsp;
                  <icon-share-alt />
                </a-link>
              </a-space>
            </template>
          </a-popover>
        </template>
      </a-tree>
    </a-spin>
    <save-folder-modal
      v-if="apis.save"
      ref="modalFolderRef"
      :api="apis.save"
      :tree-data="treeDataCanSelect"
      :send-params="sendParams"
      @refresh="getDept"
    ></save-folder-modal>
    <share-folder-modal
      v-if="apis.share"
      ref="shareFolderRef"
      :api="apis.share"
      :send-params="sendParams"
    ></share-folder-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, onMounted, computed, watch } from 'vue';
  import request from '@/api/request';
  import ShareFolderModal from '@/components/fold-tree/share-folder-modal.vue';
  import { isArray } from 'lodash';
  import SaveFolderModal from './save-folder-modal.vue';

  const props = defineProps({
    dirId: {
      type: [String, Number],
      default: () => '',
    },
    preTitle: {
      type: [String],
      default: '',
    },
    apis: {
      type: [Object],
      default: () => ({}),
      required: true,
    },
    showMenu: {
      type: Boolean,
      default: true,
    },
    sendParams: {
      type: [Object],
      default: null,
    },
    disableSelectShare: {
      type: [Boolean],
      default: false,
    },
    needMinWidth: {
      type: [Boolean],
      default: false,
    },
  });
  const emit = defineEmits(['change', 'update:dirId']);
  const treeData = ref([]);
  const selectedKeys = ref<any>([0]);
  const expandedKeys = ref([0]);
  const loading = ref(false);
  const isAll = ref(true);
  const modalFolderRef = ref();
  const shareFolderRef = ref();

  watch(
    () => props.dirId,
    () => {
      if (selectedKeys.value[0] !== props.dirId) {
        selectedKeys.value = [props.dirId];
      }
    }
  );

  const treeDataCanSelect = computed(() =>
    treeData.value.filter((item: any) => item.level_one !== 'share')
  );

  // 创建文件夹弹窗
  const showAddModal = (record: any) => {
    modalFolderRef.value.show(record);
  };

  function calleArr(arr: any[], level_one = ''): any {
    return arr
      .map((item: any) => {
        if (level_one) {
          item.level_one = level_one;
        }
        if (item.key === 'share') {
          item.level_one = 'share';
        }
        if (item.children) {
          item.children = calleArr(item.children, item.level_one);
        }
        return item;
      })
      .filter(
        (item: any) =>
          !props.disableSelectShare ||
          (props.disableSelectShare && item.level_one !== 'share')
      );
  }

  const getDept = async () => {
    if (props.apis.list) {
      loading.value = true;
      request(props.apis.list, {
        ...props.sendParams,
      })
        .then((res) => {
          treeData.value = calleArr(isArray(res.data) ? res.data : [res.data]);
        })
        .finally(() => {
          loading.value = false;
        });
    }
  };

  const onSelect = async (val: any = []) => {
    isAll.value = val.length === 0;
    emit('update:dirId', val.length === 0 ? '' : val.slice(-1)[0]);
    emit('change', val.length === 0 ? '' : val.slice(-1)[0]);
  };
  const saveAction = (item: any) => {
    showAddModal({
      dir_name: item.title,
      parent_id: item.parent_id,
      id: item.key,
    });
  };

  const shareAction = (item: any) => {
    shareFolderRef.value?.show({
      dir_name: item.title,
      dir_id: item.key,
    });
  };

  const delClick = (item: any) => {
    if (props.apis.del) {
      loading.value = true;
      request(props.apis.del, {
        dir_id: item.key,
        ...props.sendParams,
      })
        .then((res) => {
          getDept();
        })
        .catch(() => {
          loading.value = false;
        });
    }
  };

  onMounted(() => {
    getDept();
  });

  defineExpose({ getDept });
</script>

<style lang="less" scoped>
  .layout-left-side-content {
    // width: 200px;

    &.need-min-width {
      width: 180px;

      :deep(.arco-tree-node-title-text) {
        width: 130px;
      }
    }
  }

  .title-box {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  :deep(.arco-tree-node-title-text) {
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden;
    // width: 130px;
    width: 100%;
  }
  :deep(.arco-tree-node-title) {
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden;
    width: 100%;
  }
</style>
