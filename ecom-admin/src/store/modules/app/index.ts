import { defineStore } from 'pinia';
import { Notification } from '@arco-design/web-vue';
import type { NotificationReturn } from '@arco-design/web-vue/es/notification/interface';
import type { RouteRecordNormalized } from 'vue-router';
import defaultSettings from '@/config/settings.json';
import { AppState } from './types';
import request from '@/api/request';

const useAppStore = defineStore('app', {
  state: (): AppState => ({ ...defaultSettings }),

  getters: {
    appCurrentSetting(state: AppState): AppState {
      return { ...state };
    },
    appDevice(state: AppState) {
      return state.device;
    },
    appAsyncMenus(state: AppState): RouteRecordNormalized[] {
      return state.serverMenu as unknown as RouteRecordNormalized[];
    },
  },

  actions: {
    // Update app settings
    updateSettings(partial: Partial<AppState>) {
      // @ts-ignore-next-line
      this.$patch(partial);
    },

    // Change theme color
    toggleTheme(dark: boolean) {
      if (dark) {
        this.theme = 'dark';
        document.body.setAttribute('arco-theme', 'dark');
      } else {
        this.theme = 'light';
        document.body.removeAttribute('arco-theme');
      }
    },
    toggleDevice(device: string) {
      this.device = device;
    },
    toggleMenu(value: boolean) {
      this.hideMenu = value;
    },
    // 从后端获取菜单配置
    async fetchServerMenuConfig() {
      let notifyInstance: NotificationReturn | null = null;
      try {
        notifyInstance = Notification.info({
          id: 'menuNotice',
          content: '加载菜单中...',
          closable: true,
        });

        // 调用后端接口获取菜单数据
        const res = await request(
          '/api/system/menu/list',
          {},
          undefined,
          'GET'
        );
        const menuList = res.data?.list || res.data || [];

        if (menuList && menuList.length > 0) {
          // 将后端菜单数据转换为路由格式
          const menuData = this.convertServerMenuToRoutes(menuList);
          this.serverMenu = menuData;
          this.menuFromServer = true;

          notifyInstance = Notification.success({
            id: 'menuNotice',
            content: '菜单加载成功',
            closable: true,
          });
        } else {
          // 如果后端返回空数据，使用本地菜单
          this.serverMenu = [];
          this.menuFromServer = false;

          notifyInstance = Notification.warning({
            id: 'menuNotice',
            content: '未获取到菜单配置，使用本地菜单',
            closable: true,
          });
        }
      } catch (error) {
        console.error('获取菜单配置失败:', error);
        this.serverMenu = [];
        this.menuFromServer = false;

        notifyInstance = Notification.error({
          id: 'menuNotice',
          content: '菜单加载失败，使用本地菜单',
          closable: true,
        });
      }
    },

    // 将后端菜单数据转换为路由格式
    convertServerMenuToRoutes(menuData: any[]): RouteRecordNormalized[] {
      const convertMenu = (menu: any): RouteRecordNormalized => {
        // 动态加载组件
        let component: any = null;
        if (menu.component && menu.menu_type === 2) {
          // 菜单类型为2（菜单页面）时才加载组件
          component = () => {
            const comp = menu.component.replace('@/', '@/');
            // 使用 @vite-ignore 忽略 Vite 的动态导入分析
            return import(/* @vite-ignore */ comp);
          };
        } else if (menu.menu_type === 1) {
          // 目录类型，使用默认布局
          component = () => import('@/layout/default-layout.vue');
        }

        const route: any = {
          name: menu.path?.replace(/\//g, '_') || `menu_${menu.id}`,
          path: menu.path || '/',
          component,
          meta: {
            order: menu.sort || 0,
            locale: menu.menu_name,
            icon: menu.icon,
            hideInMenu: menu.is_hide === 1,
            hideChildrenInMenu: menu.is_hide === 1,
            requiresAuth: true,
            roles: menu.roles || ['*'],
            title: menu.menu_name,
          },
        };

        // 处理子菜单
        if (menu.children && menu.children.length > 0) {
          route.children = menu.children.map((child: any) =>
            convertMenu(child)
          );
        }

        return route;
      };

      return menuData.map((menu) => convertMenu(menu));
    },

    clearServerMenu() {
      this.serverMenu = [];
      this.menuFromServer = false;
    },
  },
});

export default useAppStore;
