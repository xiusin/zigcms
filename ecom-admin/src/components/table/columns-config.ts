/*
 * @Desc 全局通用列配置方法(尽量放需要自定义列的字段或者复用比较多的字段，防止列配置的唯一key重复)
 */
import { h } from 'vue';
import { TableColumnData, TableData } from '@arco-design/web-vue';
import { getPathValue } from '@/utils/util';

import {
  moneyFormat,
  numberFormat,
  rateFormat,
  formatEmptyStr,
} from './table-util';

/**
 * @description 获取展示的数据
 * @param key {string} 数据的key
 * @param data {object} 当前行数据
 * @return {string} 展示
 */
export const getTextFromData = (
  {
    record,
    column,
    rowIndex,
  }: {
    record: TableData;
    column: TableColumnData;
    rowIndex: number;
  },
  key?: any
) => {
  if (key) {
    return getPathValue(record, key);
  }
  let val = record[column.dataIndex || ''];
  return val || val === 0 ? val : '';
};
export const defaultEmptyShow = (key?: any) => {
  return (data: {
    record: TableData;
    column: TableColumnData;
    rowIndex: number;
  }) => {
    return h('span', `${formatEmptyStr(getTextFromData(data, key))}`);
  };
};
export const rateFormatShow = (key?: any) => {
  return (data: {
    record: TableData;
    column: TableColumnData;
    rowIndex: number;
  }) => h('span', `${rateFormat(getTextFromData(data, key))}`);
};
export const numberFormatShow = (key?: any) => {
  return (data: {
    record: TableData;
    column: TableColumnData;
    rowIndex: number;
  }) => h('span', `${numberFormat(getTextFromData(data, key))}`);
};
export const moneyFormatShow = (key?: any) => {
  return (data: {
    record: TableData;
    column: TableColumnData;
    rowIndex: number;
  }) => h('span', `${moneyFormat(getTextFromData(data, key))}`);
};

// 汇总行
export const judgeTotalColumnShow = (key: any) => {
  return (data: {
    record: TableData;
    column: TableColumnData;
    rowIndex: number;
  }) => {
    if (!data.record.advertiser_id) {
      return h('span', `汇总`);
    }
    return h('span', `${moneyFormat(getTextFromData(data, key))}`);
  };
};

/*
 * @Desc 全局通用列配置
 */
export const columnsConfig: any = {
  video_name: {
    title: '视频名称',
    dataIndex: 'name',
    width: 200,
  },
  video_url: {
    title: '视频预览',
    dataIndex: 'url',
    width: 120,
  },
  image_name: {
    title: '图片名称',
    dataIndex: 'name',
    width: 200,
  },
  image_url: {
    title: '图片预览',
    dataIndex: 'url',
    width: 120,
  },
  push_account_num: {
    title: '已推送账户数',
    dataIndex: 'push_account_num',
    width: 130,
    align: 'center',
  },
  unit_num: {
    title: '创建计划数',
    dataIndex: 'unit_num',
    width: 130,
    align: 'center',
  },
  media_audit_result: {
    title: '媒体审核状态',
    dataIndex: 'media_audit_result',
    width: 130,
  },
  product_name: {
    title: '产品',
    dataIndex: 'product_name',
    render: defaultEmptyShow(),
    width: 160,
  },
  cost: {
    title: '消耗',
    dataIndex: 'cost',
    align: 'right',
    render: moneyFormatShow(),
    width: 120,
  },
  material_click: {
    title: '展示数',
    dataIndex: 'material_click',
    align: 'right',
    render: numberFormatShow(),
    width: 120,
  },
  action_rate: {
    title: '点击率',
    dataIndex: 'action_rate',
    align: 'right',
    render: rateFormatShow(),
    width: 120,
  },
  has_cost_day_num: {
    title: '有消耗天数',
    dataIndex: 'has_cost_day_num',
    align: 'right',
    render: numberFormatShow(),
    width: 120,
  },

  designer_name: {
    title: '平面',
    dataIndex: 'designer_name',
    render: defaultEmptyShow(),
    width: 100,
  },
  user_director_name: {
    title: '编导',
    dataIndex: 'user_director_name',
    render: defaultEmptyShow(),
    width: 100,
  },
  user_cameraman_name: {
    title: '摄像',
    dataIndex: 'user_cameraman_name',
    render: defaultEmptyShow(),
    width: 100,
  },
  user_laterstage_name: {
    title: '后期',
    dataIndex: 'user_laterstage_name',
    render: defaultEmptyShow(),
    width: 100,
  },
  video_user_name: {
    title: '上传人',
    dataIndex: 'user_name',
    width: 160,
  },
  image_user_name: {
    title: '上传人',
    dataIndex: 'user_name',
    width: 160,
  },
  video_add_time: {
    title: '上传时间',
    dataIndex: 'add_time',
    width: 180,
  },
  image_add_time: {
    title: '上传时间',
    dataIndex: 'add_time',
    width: 180,
  },

  video_keywords: {
    title: '关键词',
    dataIndex: 'keywords',
    // width: 160,
  },
  image_keywords: {
    title: '关键词',
    dataIndex: 'keywords',
    // align: 'center',
    // width: 220,
  },
  video_info: {
    title: '信息',
    dataIndex: 'video_info',
    width: 180,
  },
  image_info: {
    title: '信息',
    dataIndex: 'image_info',
    width: 180,
  },
};
