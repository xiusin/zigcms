import type { RouteRecordNormalized } from 'vue-router';

// 导入所有有效模块
import business from './modules/business';
import cms from './modules/cms';
import exception from './modules/exception';
import feedback from './modules/feedback';
import leader from './modules/leader';
import oauth from './modules/oauth';
import purchase from './modules/purchase';
import report from './modules/report';
import stock from './modules/stock';
import system from './modules/system';
import autoTest from './modules/auto-test';
import qualityCenter from './modules/quality-center';

const allModules = [
  business,
  cms,
  exception,
  feedback,
  leader,
  oauth,
  purchase,
  report,
  stock,
  system,
  autoTest,
  qualityCenter,
];

const externalModules = import.meta.glob('./externalModules/*.ts', {
  eager: true,
});

function formatModules(_modules: any[], result: RouteRecordNormalized[]) {
  _modules.forEach((mod) => {
    if (!mod) return;
    const defaultModule = mod.default || mod;
    if (!defaultModule) return;
    const moduleList = Array.isArray(defaultModule)
      ? [...defaultModule]
      : [defaultModule];
    result.push(...moduleList);
  });
  return result;
}

export const appRoutes: RouteRecordNormalized[] = formatModules(allModules, []);

export const appExternalRoutes: RouteRecordNormalized[] = formatModules(
  Object.values(externalModules),
  []
);
