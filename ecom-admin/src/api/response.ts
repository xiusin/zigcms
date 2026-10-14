export interface NormalizedResponse<T = unknown> {
  code: number;
  msg: string;
  data: T | any;
  success: boolean;
  list: any[];
  total: number;
  pagination: {
    page: number;
    pageSize: number;
    total: number;
  };
}

function toNumber(value: unknown, fallback = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function resolveCode(payload: any): number {
  const rawCode = payload?.code;
  if (rawCode === 0 || rawCode === 200) return 200;

  const status = payload?.status;
  if (status === 0 || status === 200) return 200;
  if (typeof status === 'number') return status;

  if (typeof rawCode === 'number') return rawCode;
  return 500;
}

export function normalizeApiResponse<T = unknown>(payload: any): NormalizedResponse<T> {
  const code = resolveCode(payload);
  const msg = String(payload?.msg ?? payload?.message ?? '');
  const data = payload?.data ?? {};

  const dataList = Array.isArray(data?.list)
    ? data.list
    : Array.isArray(data?.items)
    ? data.items
    : Array.isArray(data)
    ? data
    : [];

  const total =
    toNumber(data?.total, -1) >= 0
      ? toNumber(data?.total)
      : toNumber(data?.pagination?.total, -1) >= 0
      ? toNumber(data?.pagination?.total)
      : toNumber(payload?.count, dataList.length);

  const page = toNumber(data?.page, toNumber(data?.pagination?.page, 1));
  const pageSize = toNumber(
    data?.page_size,
    toNumber(data?.pageSize, toNumber(data?.pagination?.pageSize, dataList.length || 10))
  );

  return {
    code,
    msg,
    data,
    success: code === 200,
    list: dataList,
    total,
    pagination: {
      page,
      pageSize,
      total,
    },
  };
}

export function toAmisResponse(payload: any) {
  const normalized = normalizeApiResponse(payload);
  const data = normalized.data && typeof normalized.data === 'object' ? normalized.data : {};

  return {
    ...payload,
    code: normalized.code,
    msg: normalized.msg,
    status: normalized.success ? 0 : normalized.code,
    data: {
      ...data,
      list: normalized.list,
      items: normalized.list,
      total: normalized.total,
      pagination: normalized.pagination,
    },
  };
}
