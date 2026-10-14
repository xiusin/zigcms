<template>
  <div
    ref="containerRef"
    class="virtual-list-container"
    :style="{ height: containerHeight }"
    @scroll="handleScroll"
  >
    <!-- 占位元素，撑起总高度 -->
    <div
      class="virtual-list-phantom"
      :style="{ height: `${totalHeight}px` }"
    ></div>

    <!-- 可见区域 -->
    <div
      class="virtual-list-content"
      :style="{ transform: `translateY(${offsetY}px)` }"
    >
      <div
        v-for="item in visibleItems"
        :key="getItemKey(item)"
        class="virtual-list-item"
        :style="{ height: `${itemHeight}px` }"
      >
        <slot name="item" :item="item" :index="item.__index"></slot>
      </div>
    </div>

    <!-- 加载更多 -->
    <div v-if="loading" class="virtual-list-loading">
      <a-spin />
    </div>
  </div>
</template>

<script setup lang="ts" generic="T extends Record<string, any>">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';

interface Props {
  items: T[];
  itemHeight: number;
  containerHeight?: string;
  bufferSize?: number;
  itemKey?: string;
  loading?: boolean;
}

interface Emits {
  (e: 'load-more'): void;
  (e: 'scroll', event: Event): void;
}

const props = withDefaults(defineProps<Props>(), {
  containerHeight: '600px',
  bufferSize: 5,
  itemKey: 'id',
  loading: false,
});

const emit = defineEmits<Emits>();

// 容器引用
const containerRef = ref<HTMLElement>();

// 滚动位置
const scrollTop = ref(0);

// 容器高度（像素）
const containerHeightPx = computed(() => {
  return parseInt(props.containerHeight);
});

// 总高度
const totalHeight = computed(() => {
  return props.items.length * props.itemHeight;
});

// 可见项数量
const visibleCount = computed(() => {
  return Math.ceil(containerHeightPx.value / props.itemHeight) + props.bufferSize * 2;
});

// 起始索引
const startIndex = computed(() => {
  const index = Math.floor(scrollTop.value / props.itemHeight) - props.bufferSize;
  return Math.max(0, index);
});

// 结束索引
const endIndex = computed(() => {
  const index = startIndex.value + visibleCount.value;
  return Math.min(props.items.length, index);
});

// 可见项
const visibleItems = computed(() => {
  return props.items.slice(startIndex.value, endIndex.value).map((item, index) => ({
    ...item,
    __index: startIndex.value + index,
  }));
});

// 偏移量
const offsetY = computed(() => {
  return startIndex.value * props.itemHeight;
});

// 获取项的key
const getItemKey = (item: T & { __index: number }) => {
  if (props.itemKey && item[props.itemKey] !== undefined) {
    return item[props.itemKey];
  }
  return item.__index;
};

// 处理滚动
const handleScroll = (event: Event) => {
  const target = event.target as HTMLElement;
  scrollTop.value = target.scrollTop;
  
  emit('scroll', event);
  
  // 检查是否需要加载更多
  const scrollHeight = target.scrollHeight;
  const clientHeight = target.clientHeight;
  const scrollBottom = scrollTop.value + clientHeight;
  
  if (scrollHeight - scrollBottom < props.itemHeight * 10 && !props.loading) {
    emit('load-more');
  }
};

// 滚动到指定位置
const scrollTo = (index: number) => {
  if (!containerRef.value) return;
  
  const targetScrollTop = index * props.itemHeight;
  containerRef.value.scrollTop = targetScrollTop;
  scrollTop.value = targetScrollTop;
};

// 滚动到顶部
const scrollToTop = () => {
  scrollTo(0);
};

// 滚动到底部
const scrollToBottom = () => {
  scrollTo(props.items.length - 1);
};

// 暴露方法
defineExpose({
  scrollTo,
  scrollToTop,
  scrollToBottom,
});

// 监听items变化，重置滚动位置
watch(() => props.items.length, (newLength, oldLength) => {
  // 如果是首次加载或清空，重置滚动位置
  if (oldLength === 0 || newLength === 0) {
    scrollTop.value = 0;
    if (containerRef.value) {
      containerRef.value.scrollTop = 0;
    }
  }
});
</script>

<style scoped lang="scss">
.virtual-list-container {
  position: relative;
  overflow-y: auto;
  overflow-x: hidden;

  &::-webkit-scrollbar {
    width: 8px;
  }

  &::-webkit-scrollbar-track {
    background: #f1f1f1;
    border-radius: 4px;
  }

  &::-webkit-scrollbar-thumb {
    background: #888;
    border-radius: 4px;

    &:hover {
      background: #555;
    }
  }
}

.virtual-list-phantom {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  z-index: -1;
}

.virtual-list-content {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
}

.virtual-list-item {
  overflow: hidden;
}

.virtual-list-loading {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 16px;
  background: rgba(255, 255, 255, 0.9);
}
</style>
