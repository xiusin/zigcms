/**
 * 质量中心Dashboard加载骨架屏
 * 【高级特性】优化首屏加载体验
 */
<template>
  <div class="dashboard-skeleton">
    <!-- 统计卡片骨架 -->
    <a-row :gutter="16" class="stat-cards-skeleton">
      <a-col v-for="i in 8" :key="i" :xs="12" :sm="6" :md="6" :lg="3">
        <a-card>
          <a-skeleton animation>
            <a-skeleton-line :rows="2" />
          </a-skeleton>
        </a-card>
      </a-col>
    </a-row>

    <!-- 第二行骨架 -->
    <a-row :gutter="16" style="margin-top: 16px">
      <a-col :xs="24" :lg="8">
        <a-card>
          <template #title>
            <a-skeleton-line :widths="['120px']" :rows="1" />
          </template>
          <a-skeleton animation>
            <a-skeleton-line :rows="6" />
          </a-skeleton>
        </a-card>
      </a-col>
      <a-col :xs="24" :lg="16">
        <a-card>
          <template #title>
            <a-skeleton-line :widths="['100px']" :rows="1" />
          </template>
          <a-skeleton animation>
            <a-skeleton-line :rows="8" />
          </a-skeleton>
        </a-card>
      </a-col>
    </a-row>

    <!-- 第三行骨架 -->
    <a-row :gutter="16" style="margin-top: 16px">
      <a-col :xs="24" :lg="10">
        <a-card>
          <a-skeleton animation>
            <a-skeleton-line :rows="6" />
          </a-skeleton>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="7">
        <a-card>
          <a-skeleton animation>
            <a-skeleton-shape shape="circle" style="width: 200px; height: 200px; margin: 20px auto" />
          </a-skeleton>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="7">
        <a-card>
          <a-skeleton animation>
            <a-skeleton-shape shape="circle" style="width: 200px; height: 200px; margin: 20px auto" />
          </a-skeleton>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<style lang="less" scoped>
.dashboard-skeleton {
  padding: 16px;
  background: var(--color-bg-1);
  min-height: 100vh;
}

.stat-cards-skeleton {
  :deep(.arco-card-body) {
    padding: 16px;
  }
}
</style>
