<template>
  <!-- 组件布局 1、左侧为条件搜索区域 2、右侧为表格功能区域 -->
  <a-row justify="space-between" class="search-box" align="center">
    <a-col flex="auto">
      <a-button v-if="searchRules?.length" class="mr-10" @click="handleClick"
        >所有筛选
        <icon-filter class="ml-10" />
      </a-button>
      <!-- 基础筛选 -->
      <a-dropdown
        position="bl"
        :popup-visible="!!theFormData.content"
        @select="handleSelect"
      >
        <a-input-search
          v-model="theFormData.content"
          class="base-search-item"
          :placeholder="placeholder"
          search-button
          allow-clear
          @search="handleOk(false)"
          @keydown.enter="handleSelect(null)"
        >
        </a-input-search>
        <template #content>
          <div class="wrap-select">
            <a-doption
              v-for="(item, index) in baseSearchRules"
              :key="index"
              :value="item"
            >
              {{ item.label }}{{ item.symbol || '包含' }}：{{
                theFormData.content
              }}</a-doption
            >
          </div>
        </template>
      </a-dropdown>
      <!--  剩下的区域为搜索组件的展开布局 -->
      <template
        v-for="(item, index) in showSearchArr"
        :key="item.label + index"
      >
        <a-input-group class="search-wrap">
          <span class="label">
            {{ item.label }}{{ item.onlyShow ? item.symbol || '包含' : '' }}：
          </span>
          <!-- 针对不同的组件 需要展示相对应的组件类型 -->
          <div :style="{ width: item.searchWidth || item.width }">
            <div v-if="item.onlyShow" class="show-box">
              <span class="show-text" :style="{ width: item.width }">
                {{ item.value }}
              </span>
            </div>
            <component
              :is="item.component_name"
              v-else
              v-model="theFormData[item.field]"
              v-bind="{ ...item.attr }"
              style="width: 100%"
              @change="handleOk(false)"
            />
          </div>
          <icon-close-circle class="close-btn" @click="closeFn(item)" />
        </a-input-group>
      </template>
      <span v-if="showSearchArr.length > 0" class="clearAll" @click="clearAll">
        清空
      </span>
    </a-col>
    <!-- 右侧插槽：用于放置功能按钮 -->
    <a-col flex="none" class="search-actions">
      <slot name="actions"></slot>
    </a-col>
  </a-row>
  <a-modal
    v-model:visible="visible"
    :width="1080"
    :unmount-on-close="true"
    @ok="handleOk(true)"
    @cancel="handleCancel"
  >
    <template #title>
      <div class="title-box">
        <div class="title-left"> 所有筛选 </div>
        <div class="title-right" @click="resetHandler">
          <icon-refresh /> 重置筛选项
        </div>
      </div>
    </template>
    <div class="grid-search-box">
      <div class="grid-box" :gutter="20">
        <div
          v-for="(item, index) in searchRules"
          :key="index"
          class="single-search"
        >
          <div class="label">{{ item.label }}</div>
          <div :style="{ width: item.searchWidth || item.width }">
            <component
              :is="item.component_name"
              v-model="cacheFormData[item.field]"
              v-bind="{ ...item.attr }"
              style="width: 100%"
            />
          </div>
        </div>
      </div>
    </div>
  </a-modal>
</template>

<script lang="ts">
  import {
    ref,
    defineComponent,
    watch,
    PropType,
    onMounted,
    nextTick,
  } from 'vue';
  import FolderTreeSelect from '@/components/fold-tree/folder-tree-select.vue';
  import { AnyObject } from '@/types/global';
  // const components: any = import.meta.globEager('./*.vue');
  // const componentEntries: any = Object.entries(components);
  // const componentMap = componentEntries.reduce(
  //   (acc: any, [path, component]: any) => {
  //     const name = path.match(/\.\/([\w-]+)\.vue$/)?.[1] ?? 'UnknownComponent';
  //     acc[name] = component.default;
  //     return acc;
  //   },
  //   {}
  // );

  interface PolicyRecord {
    field: string;
    label: string;
    component_name: string;
    value: any;
    width: string;
    searchWidth: string;
    attr: object;
  }

  interface BaseRecord {
    field: string;
    label: string;
    symbol: any;
  }

  export default defineComponent({
    components: { FolderTreeSelect },
    inheritAttrs: false,
    // components: componentMap,
    props: {
      formData: {
        type: Object,
        default: () => {
          return {};
        },
      },
      getDefaultFormData: {
        type: Function,
        default: () => {
          return {};
        },
      },
      searchRules: {
        type: Array as PropType<PolicyRecord[]>,
        default: () => {
          return [];
        },
      },
      baseSearchRules: {
        type: Array as PropType<BaseRecord[]>,
        default: () => {
          return [
            {
              field: 'id',
              label: '账户ID',
              value: null,
              width: '100px',
            },
          ];
        },
      },
      placeholder: {
        type: String,
        default: '请输入名称、ID、备注搜索',
      },
      continueKeys: {
        type: Array as PropType<string[]>,
        default: () => [],
      },
    },

    emits: ['reset', 'handSubmit', 'changeCacheFormData'],
    setup(props, { emit }) {
      // 动态获取默认数据，避免修改联动
      // 保留初始数据，清理查询条件时使用
      const initFormData: any = props.getDefaultFormData();
      const theFormData: any = ref(props.getDefaultFormData());

      // 当前需要展示的其他若干条件
      const showSearchArr: any = ref([]);
      // 当前已经被添加的基础条件
      const selectedBaseRule: any = ref([]);
      // theFormData 与传入的默认值比较  得到当前的值已经变更的 筛选项
      const compareWhatNeedFn = () => {
        showSearchArr.value = [];
        // 添加基础条件的筛选
        selectedBaseRule.value.forEach((item: any) => {
          showSearchArr.value.push(item);
        });

        // 添加其他条件的筛选
        props.searchRules.forEach((item: any) => {
          if (
            (theFormData.value[item.field] ||
              theFormData.value[item.field] === 0) &&
            theFormData.value[item.field].length !== 0
          ) {
            showSearchArr.value.push(item);
          }
          //  &&
          //   theFormData.value[item.field] !== initFormData[item.field]
        });
      };

      // 外部修改传参时，修改显示数据
      watch(
        props.formData,
        () => {
          Object.assign(theFormData.value, props.formData);
        },
        {
          immediate: true,
          deep: true,
        }
      );

      watch(
        () => props.searchRules,
        (v) => {
          // console.log('watch: ', v);
          let temp = v;
          // v;
          compareWhatNeedFn();
        },
        {
          deep: true,
        }
      );

      const visible = ref(false);

      // 点开搜索弹窗 将将会做一份缓存搜索条件，弹窗内的内容变化都在缓存里更改
      const cacheFormData: any = ref(
        JSON.parse(JSON.stringify(props.getDefaultFormData()))
      );
      const handleClick = () => {
        cacheFormData.value = JSON.parse(JSON.stringify(theFormData.value));
        visible.value = true;
      };

      props.searchRules.forEach((item: any) => {
        if (item.watch) {
          watch(
            () => cacheFormData.value[item.field],
            (v) => {
              let ret: AnyObject = {};
              ret[item.field] = v;
              emit('changeCacheFormData', ret);
            }
          );
        }
      });

      const searchFn = () => {
        emit('handSubmit', theFormData.value);
      };
      // 确定搜索，将搜索缓存更新为正式搜索条件
      const handleOk = (updateParams: any) => {
        visible.value = false;
        if (updateParams) {
          theFormData.value = cacheFormData.value;
        } else if (theFormData.value.content) {
          selectedBaseRule.value = [];
          props.baseSearchRules.forEach((item: any) => {
            selectedBaseRule.value.push({
              ...item,
              value: theFormData.value.content,
              onlyShow: true,
            });
            theFormData.value[item.field] = theFormData.value.content;
          });
        }
        compareWhatNeedFn();
        theFormData.value.content = null;
        // emit('handSubmit', theFormData.value);
        searchFn();
      };

      // 基础下拉条件的勾选确定 追加/更新基础查询数组
      const handleSelect = (targetObject: any) => {
        // 检测当前筛选值是否存在 不存在直接查询
        if (!theFormData.value.content) {
          searchFn();
          return;
        }
        // 检测targetObject是否存在  不存在则默认选择第一项
        if (!targetObject) {
          [targetObject] = props.baseSearchRules;
        }

        const existingObjectIndex = selectedBaseRule.value.findIndex(
          (item: any) => item.field === targetObject.field
        );
        targetObject.onlyShow = true;
        targetObject.value = theFormData.value.content;
        if (existingObjectIndex !== -1) {
          // 如果数组中已经存在具有相同 field 属性的目标对象，则更新该对象
          selectedBaseRule.value.splice(existingObjectIndex, 1, targetObject);
        } else {
          // 如果数组中不存在具有相同 field 属性的目标对象，则添加目标对象到数组中
          selectedBaseRule.value.push(targetObject);
        }
        // 展示当前勾选的搜索条件
        compareWhatNeedFn();
        // 赋值给当前搜索条件 使用
        theFormData.value[targetObject.field] = theFormData.value.content;
        // 重置搜索内容
        theFormData.value.content = null;
        searchFn();
      };

      const handleCancel = () => {
        visible.value = false;
      };

      const resetHandler = () => {
        // 重置查询条件 首先清空缓存中的值
        // cacheMeta.resetMetaCacheData();
        const keys = Object.keys(initFormData);
        const resetInfo: any = {};
        // 需要定义继承原值的Key 不能因为处理缓存导致默认值也被重置
        const continueKeys = [...props.continueKeys];
        keys.map((key: any) => {
          if (continueKeys.includes(key) || key === 'dateArr') {
            resetInfo[key] = props.formData[key] || null;
          } else {
            resetInfo[key] = null;
          }
          return null;
        });
        Object.assign(cacheFormData.value, resetInfo);
      };

      //  取消某个值的筛选
      const closeFn = (item: any) => {
        showSearchArr.value = showSearchArr.value.filter((curVal: any) => {
          return curVal.field !== item.field;
        });
        selectedBaseRule.value = selectedBaseRule.value.filter(
          (curVal: any) => {
            return curVal.field !== item.field;
          }
        );
        theFormData.value[item.field] = null;
        searchFn();
      };

      // 重置所有筛选条件
      const clearAll = async () => {
        showSearchArr.value = [];
        selectedBaseRule.value = [];
        await resetHandler();
        handleOk(true);
      };

      // 初始化展示 筛选条件  支持配置默认值
      onMounted(() => {
        props.baseSearchRules.forEach((item: any) => {
          if (initFormData[item.field]) {
            theFormData.value.content = initFormData[item.field];
            nextTick().then(() => {
              handleOk(false);
            });
          }
        });
        compareWhatNeedFn();
      });

      return {
        // components: componentMap,
        showSearchArr,
        resetHandler,
        theFormData,
        cacheFormData,
        closeFn,
        visible,
        handleClick,
        handleOk,
        handleCancel,
        clearAll,
        handleSelect,
        searchFn,
        compareWhatNeedFn,
      };
    },
    // 在销毁之前，清空其下的搜索缓存
    unmounted() {
      // todo
    },
  });
</script>

<style lang="less" scoped>
  .search-box {
    .mr-20 {
      margin-right: 20px;
    }
    .ml-10 {
      margin-left: 10px;
    }
    .base-search-item {
      width: 240px;
      margin-right: 20px;
      margin-bottom: 10px;
    }
    .clearAll {
      color: rgb(var(--primary-6));
      cursor: pointer;
    }
    .search-actions {
      display: flex;
      align-items: center;
      margin-bottom: 10px;
    }
    .search-wrap {
      margin: 0 10px 10px 0;
      background: var(--color-secondary);
      border: 1px solid rgb(var(--primary-color-6));
      border-radius: 5px;
      .label {
        margin-left: 10px;
      }
      .show-box {
        display: flex;
        height: 32px;
        align-items: center;
        .show-text {
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
      }
      .close-btn {
        margin: 0 10px;
        cursor: pointer;
        color: rgb(var(--primary-6));
      }
    }
  }
  .wrap-select {
    width: 208px;
  }
  .title-box {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    .title-right {
      padding-right: 30px;
      font-size: 14px;
      font-weight: normal;
      color: rgb(var(--primary-6));
      cursor: pointer;
    }
  }
  .grid-search-box {
    .grid-box {
      display: grid;
      grid-template-columns: repeat(4, minmax(0px, 1fr));
      // gap: 20px 48px;
      gap: 20px 0;
      .single-search {
        padding: 5px;
        .label {
          font-weight: bold;
          margin-bottom: 5px;
        }
      }
    }
  }
</style>
