/*
 * @Desc 全局通用列相关函数
 */
import { columnsConfig, defaultEmptyShow } from './columns-config';

const getDefaultConfig = (kName: string) => {
  return columnsConfig[kName] || {};
};
export const getColumns = (key: any, platformKey?: string | number) => {
  let newArr: any = [];

  // 安全检查：确保 key 是数组
  if (!Array.isArray(key) || key.length === 0) {
    return newArr;
  }

  key.forEach((item: any) => {
    let temp: any;
    let originKey: any;
    if (typeof item === 'string') {
      originKey = item;
      temp = {
        ...columnsConfig[item],
        key: originKey,
      };
      // 分平台展示表格表头
      temp.title =
        (platformKey && columnsConfig[item].titles?.[platformKey]) ||
        temp.title;
    }
    if (typeof item === 'object') {
      // item.dataIndex = item.dataIndex || '';
      // let defaultConfig = {
      //  ...getDefaultConfig(item.dataIndex),
      //  key: item.dataIndex,
      // };
      /// / dataIndex 如果一致，自定义配置合并默认配置
      // temp = Object.assign(defaultConfig, item);
      temp = item;
    }
    temp = temp || { dataIndex: '', title: '未知' };
    let defaultSlotName = temp.slotName || originKey || temp.dataIndex;
    let defaultTitleSlotName = originKey || temp.dataIndex;
    let lastTitleSlotName =
      temp.titleSlotName || `${defaultTitleSlotName}_title`;
    // 支持自定义 slotName 和 titleSlotName, 传入的key默认作为内容slotName，或者用数据字段名作为slotName，优先级依次递减
    temp.slotName = defaultSlotName;
    // 标题 slot 默认是字段 key 加后缀 '_title'
    temp.titleSlotName = lastTitleSlotName;
    temp.align = temp.align || 'center';
    newArr.push(temp);
  });
  return newArr;
};

// 根据列的key获取列名称
export const getColumnTitle = (key: string, platformKey?: string) => {
  return (
    (platformKey && columnsConfig[key]?.titles?.[platformKey]) ||
    columnsConfig[key]?.title ||
    '未知'
  );
};

// fieldmap: [{dataList:[{title:'xxx', dataIndex:'xxx'}]}]
export const getColumnsFormMap = (fieldmap: any[], keys: any) => {
  let newArr: any = [];
  keys.forEach((itemKey: any) => {
    let temp: any;
    fieldmap.some((fItem) => {
      let fRes = fItem.dataList.find(
        (fcItem: any) => fcItem.dataIndex === itemKey
      );
      if (fRes) {
        temp = {
          ...fRes,
        };
        return true;
      }
      return false;
    });
    console.log();
    temp = temp || { dataIndex: '', title: '未知' };
    let defaultSlotName = temp.slotName || itemKey || temp.dataIndex;
    let defaultTitleSlotName = itemKey || temp.dataIndex;
    let lastTitleSlotName =
      temp.titleSlotName || `${defaultTitleSlotName}_title`;
    // 支持自定义 slotName 和 titleSlotName, 传入的key默认作为内容slotName，或者用数据字段名作为slotName，优先级依次递减
    temp.slotName = defaultSlotName;
    // 标题 slot 默认是字段 key 加后缀 '_title'
    temp.titleSlotName = lastTitleSlotName;
    temp.align = temp.align || 'center';
    newArr.push(temp);
  });
  return newArr;
};
