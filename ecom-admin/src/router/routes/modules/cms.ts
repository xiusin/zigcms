import { DEFAULT_LAYOUT } from '../base';
import { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/cms',
  name: 'cms',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: 'CMS管理',
    requiresAuth: true,
    icon: 'icon-file',
    order: 20,
  },
  children: [
    {
      path: '',
      name: 'cms-index',
      component: () => import('@/views/cms/index.vue'),
      meta: {
        locale: 'CMS首页',
        requiresAuth: true,
        icon: 'icon-dashboard',
        roles: ['*'],
      },
    },
    {
      path: 'model',
      name: 'cms-model',
      component: () => import('@/views/cms/model/index.vue'),
      meta: {
        locale: '内容模型',
        requiresAuth: true,
        icon: 'icon-settings',
        roles: ['*'],
      },
    },
    {
      path: 'model/:modelId/fields',
      name: 'cms-model-fields',
      component: () => import('@/views/cms/model/fields.vue'),
      meta: {
        locale: '字段管理',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['*'],
      },
    },
    {
      path: 'content/:modelId',
      name: 'cms-content',
      component: () => import('@/views/cms/content/index.vue'),
      meta: {
        locale: '内容管理',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['*'],
      },
    },
    {
      path: 'category',
      name: 'cms-category',
      component: () => import('@/views/cms/category/index.vue'),
      meta: {
        locale: '内容分类',
        requiresAuth: true,
        icon: 'icon-folder',
        roles: ['*'],
      },
    },
    {
      path: 'tag',
      name: 'cms-tag',
      component: () => import('@/views/cms/tag/index.vue'),
      meta: {
        locale: '内容标签',
        requiresAuth: true,
        icon: 'icon-tags',
        roles: ['*'],
      },
    },
    {
      path: 'media',
      name: 'cms-media',
      component: () => import('@/views/cms/media/index.vue'),
      meta: {
        locale: '媒体库',
        requiresAuth: true,
        icon: 'icon-image',
        roles: ['*'],
      },
    },
    {
      path: 'template',
      name: 'cms-template',
      component: () => import('@/views/cms/template/index.vue'),
      meta: {
        locale: '模板管理',
        requiresAuth: true,
        icon: 'icon-code',
        roles: ['*'],
      },
    },
    {
      path: 'seo',
      name: 'cms-seo',
      component: () => import('@/views/cms/seo/index.vue'),
      meta: {
        locale: 'SEO工具',
        requiresAuth: true,
        icon: 'icon-search',
        roles: ['*'],
      },
    },
    {
      path: 'workflow',
      name: 'cms-workflow',
      component: () => import('@/views/cms/workflow/index.vue'),
      meta: {
        locale: '工作流',
        requiresAuth: true,
        icon: 'icon-relation',
        roles: ['*'],
      },
    },
  ],
};

export default RouterConfig;
