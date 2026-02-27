/**
 * 模块间跳转工具函数
 * 统一处理路由参数传递和清理
 */
import { useRouter, useRoute, type LocationQueryRaw } from 'vue-router';
import { ref, onMounted } from 'vue';

// 路由路径常量
export const ROUTE_PATHS = {
  MEMBER: '/business/member',
  ORDER: '/business/order',
  MACHINE: '/business/machine',
  INCOME: '/business/income',
  OVERVIEW: '/business/overview',
  PROMOTION: '/business/promotion',
} as const;

// 跳转参数类型
export interface JumpToMemberParams {
  memberId?: number;
}

export interface JumpToOrderParams {
  orderId?: number;
  memberId?: number;
  machineId?: number;
}

export interface JumpToMachineParams {
  machineId?: number;
  orderId?: number;
}

export interface JumpToIncomeParams {
  memberId?: number;
  machineId?: number;
  orderId?: number;
}

/**
 * 模块间跳转 Hook
 * 提供统一的跳转方法和参数处理
 */
export function useModuleNavigation() {
  const router = useRouter();
  const route = useRoute();

  // ========== 跳转方法 ==========

  /** 跳转到会员管理 */
  const jumpToMember = (params: JumpToMemberParams = {}) => {
    const query: LocationQueryRaw = {};
    if (params.memberId) {
      query.memberId = String(params.memberId);
    }
    router.push({ path: ROUTE_PATHS.MEMBER, query });
  };

  /** 跳转到订单管理 */
  const jumpToOrder = (params: JumpToOrderParams = {}) => {
    const query: LocationQueryRaw = {};
    if (params.orderId) {
      query.orderId = String(params.orderId);
    }
    if (params.memberId) {
      query.memberId = String(params.memberId);
    }
    if (params.machineId) {
      query.machineId = String(params.machineId);
    }
    router.push({ path: ROUTE_PATHS.ORDER, query });
  };

  /** 跳转到机器管理 */
  const jumpToMachine = (params: JumpToMachineParams = {}) => {
    const query: LocationQueryRaw = {};
    if (params.machineId) {
      query.machineId = String(params.machineId);
    }
    if (params.orderId) {
      query.orderId = String(params.orderId);
    }
    router.push({ path: ROUTE_PATHS.MACHINE, query });
  };

  /** 跳转到收入管理 */
  const jumpToIncome = (params: JumpToIncomeParams = {}) => {
    const query: LocationQueryRaw = {};
    if (params.memberId) {
      query.memberId = String(params.memberId);
    }
    if (params.machineId) {
      query.machineId = String(params.machineId);
    }
    if (params.orderId) {
      query.orderId = String(params.orderId);
    }
    router.push({ path: ROUTE_PATHS.INCOME, query });
  };

  // ========== 参数处理方法 ==========

  /**
   * 获取并清理路由参数
   * @param paramNames 需要获取的参数名列表
   * @returns 参数值对象
   */
  const getAndClearQueryParams = <T extends string>(
    paramNames: T[]
  ): Record<T, string | undefined> => {
    const result = {} as Record<T, string | undefined>;

    paramNames.forEach((name) => {
      const value = route.query[name];
      if (value) {
        result[name] = String(value);
      }
    });

    // 清理 URL 参数
    if (Object.keys(result).length > 0) {
      router.replace({ path: route.path });
    }

    return result;
  };

  /**
   * 解析路由参数
   * @param paramNames 需要解析的参数名列表
   * @returns 参数值对象（未清理 URL）
   */
  const getQueryParams = <T extends string>(
    paramNames: T[]
  ): Record<T, string | undefined> => {
    const result = {} as Record<T, string | undefined>;

    paramNames.forEach((name) => {
      const value = route.query[name];
      if (value) {
        result[name] = String(value);
      }
    });

    return result;
  };

  return {
    // 跳转方法
    jumpToMember,
    jumpToOrder,
    jumpToMachine,
    jumpToIncome,
    // 参数处理
    getAndClearQueryParams,
    getQueryParams,
    // 路由实例
    router,
    route,
  };
}

/**
 * 路由参数处理 Hook
 * 在组件挂载时自动获取并清理参数
 */
export function useRouteParams<T extends string>(
  paramNames: T[],
  onParamsReceived?: (params: Record<T, string | undefined>) => void
) {
  const params = ref<Record<T, string | undefined>>(
    {} as Record<T, string | undefined>
  );
  const { getAndClearQueryParams, router, route } = useModuleNavigation();

  onMounted(() => {
    params.value = getAndClearQueryParams(paramNames);
    if (onParamsReceived && Object.keys(params.value).length > 0) {
      onParamsReceived(params.value);
    }
  });

  return {
    params,
    router,
    route,
  };
}

export default {
  ROUTE_PATHS,
  useModuleNavigation,
  useRouteParams,
};
