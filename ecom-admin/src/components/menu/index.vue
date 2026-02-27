<script lang="tsx">
  import { defineComponent, ref, h, compile, computed } from 'vue';
  import { useI18n } from 'vue-i18n';
  import { useRoute, useRouter, RouteRecordRaw } from 'vue-router';
  import type { RouteMeta } from 'vue-router';
  import { useAppStore } from '@/store';
  import { listenerRouteChange } from '@/utils/route-listener';
  import { openWindow, regexUrl } from '@/utils';
  import useMenuTree from './use-menu-tree';

  export default defineComponent({
    emit: ['collapse'],
    props: {
      mode: {
        type: String,
        default: 'vertical',
      },
      isSubMenu: {
        type: Boolean,
        default: false,
      },
      isNeedCollapsed: {
        type: Boolean,
        default: true,
      },
    },
    setup(props) {
      const { t } = useI18n();
      const appStore = useAppStore();
      const router = useRouter();
      const route = useRoute();
      const { menuTree, subMenuTree } = useMenuTree();
      const collapsed = computed({
        get() {
          if (appStore.device === 'desktop' && props.isNeedCollapsed)
            return appStore.menuCollapse;
          return false;
        },
        set(value: boolean) {
          appStore.updateSettings({ menuCollapse: value });
        },
      });

      const topMenu = computed(() => appStore.topMenu);
      const openKeys = ref<string[]>([]);
      const selectedKey = ref<string[]>([]);

      const goto = (item: RouteRecordRaw) => {
        // Open external link
        if (regexUrl.test(item.path)) {
          openWindow(item.path);
          selectedKey.value = [item.name as string];
          return;
        }
        // Eliminate external link side effects
        const { hideInMenu, activeMenu } = item.meta as RouteMeta;
        if (route.name === item.name && !hideInMenu && !activeMenu) {
          selectedKey.value = [item.name as string];
          return;
        }
        // Trigger router change
        router.push({
          name: item.name,
        });
      };
      const findMenuOpenKeys = (target: string) => {
        const result: string[] = [];
        let isFind = false;
        const backtrack = (item: RouteRecordRaw, keys: string[]) => {
          if (item.name === target) {
            isFind = true;
            result.push(...keys);
            return;
          }
          if (item.children?.length) {
            item.children.forEach((el) => {
              backtrack(el, [...keys, el.name as string]);
            });
          }
        };
        menuTree.value.forEach((el: RouteRecordRaw) => {
          if (isFind) return; // Performance optimization
          backtrack(el, [el.name as string]);
        });
        return result;
      };
      listenerRouteChange((newRoute) => {
        const { requiresAuth, activeMenu, hideInMenu } = newRoute.meta;
        if (requiresAuth && (!hideInMenu || activeMenu)) {
          const menuOpenKeys = findMenuOpenKeys(
            (activeMenu || newRoute.name) as string
          );

          const keySet = new Set([...menuOpenKeys, ...openKeys.value]);
          openKeys.value = [...keySet];

          selectedKey.value = [
            activeMenu || menuOpenKeys[menuOpenKeys.length - 1],
          ];
        }
      }, true);
      const setCollapse = (val: boolean) => {
        if (appStore.device === 'desktop')
          appStore.updateSettings({ menuCollapse: val });
      };

      const renderSubMenu = () => {
        function travel(_route: RouteRecordRaw[], nodes = []) {
          if (_route) {
            _route.forEach((element) => {
              let icon = element?.meta?.icon ? `<${element?.meta?.icon}/>` : ``;
              // 优先支持 iconFont 配置
              if (element?.meta?.iconFont) {
                icon = `<IconFont type="${element?.meta?.iconFont}"/>`;
              }
              const node =
                element?.children && element?.children.length !== 0 ? (
                  <a-sub-menu
                    key={element?.name}
                    popup-max-height={false}
                    v-slots={{
                      icon: () => h(compile(icon)),
                      title: () => h(compile(t(element?.meta?.locale || ''))),
                    }}
                  >
                    {travel(element?.children)}
                  </a-sub-menu>
                ) : (
                  <a-menu-item
                    key={element?.name}
                    v-slots={{ icon: () => h(compile(icon)) }}
                    onClick={() => goto(element)}
                  >
                    <router-link class="initA" to={{ name: element.name }}>
                      {t(element?.meta?.locale || '')}
                    </router-link>
                  </a-menu-item>
                );
              nodes.push(node as never);
            });
          }
          return nodes;
        }
        if (props.isSubMenu) {
          return travel(subMenuTree.value);
        }
        return travel(menuTree.value);
      };
      return () => (
        <a-menu
          mode={props.mode}
          v-model:collapsed={collapsed.value}
          v-model:open-keys={openKeys.value}
          show-collapse-button={
            appStore.device !== 'mobile' && props.isNeedCollapsed
          }
          auto-open={false}
          selected-keys={selectedKey.value}
          auto-open-selected={true}
          level-indent={34}
          class="dmenu"
          popup-max-height={false}
          onCollapse={setCollapse}
        >
          {renderSubMenu()}
        </a-menu>
      );
    },
  });
</script>

<style lang="less" scoped>
  .dmenu {
    padding: 6px 16px 16px;
    height: 100%;
    width: 100%;
    background-color: transparent;

    :deep(.arco-menu-inner) {
      .arco-menu-inline-header {
        display: flex;
        align-items: center;
        background-color: transparent;
        font-weight: 700;
      }
      .arco-icon {
        &:not(.arco-icon-down) {
          font-size: 18px;
        }
      }
      .arco-menu-pop-header,
      .arco-menu-item {
        background-color: transparent;
        font-weight: 700;
        margin-left: 0;
        border-radius: 8px;
        line-height: 36px;
        margin-bottom: 10px;
        &:hover {
          background-color: var(--color-bg-2);
          opacity: 0.6;
        }
      }
      .arco-menu-inline-content .arco-menu-item {
        .arco-menu-icon {
          display: flex;
        }
      }
    }
    // 纵向菜单
    &.arco-menu-vertical {
      :deep(.arco-menu-inner) {
        .arco-menu-item {
          &.arco-menu-selected {
            background: var(--color-bg-2);
          }
        }
      }
    }
    // 横向菜单
    &.arco-menu-horizontal {
      :deep(.arco-menu-inner) {
        overflow: hidden;
        padding: 0;
        height: auto;
        .arco-menu-selected-label {
          bottom: 0px;
          left: 20px;
          right: 20px;
          border-radius: 3px;
          display: none;
        }
        .arco-menu-pop-header {
          padding: 0 15px;
        }
      }
    }
  }

  // 横向菜单的弹出子菜单图标（全局样式）
  :deep(.arco-menu-pop) {
    .arco-menu-icon {
      display: inline-flex !important;
      margin-right: 8px;
    }
    .arco-menu-item .arco-menu-icon {
      display: inline-flex !important;
    }
  }
  .arco-layout-sider-collapsed {
    .dmenu {
      padding: 6px 0 16px 0;
    }
  }
  // 亮色主题的导航
  .arco-menu-light.dmenu {
    :deep(.arco-menu-inner) {
      .arco-menu-pop-header:hover {
        background-color: var(--color-bg-1);
      }
    }
  }
</style>
