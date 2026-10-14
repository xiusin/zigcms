// // 跨域代理前缀
// const API_PROXY_PREFIX = '';
// let BASE_URL =
//   process.env.NODE_ENV === 'production'
//     ? process.env.VUE_APP_API_BASE_URL
//     : API_PROXY_PREFIX;
// let BASE_HOST =
//   process.env.NODE_ENV === 'production'
//     ? process.env.VUE_APP_API_BASE_URL
//     : 'https://localupload.pengwin.com';
// BASE_URL += '/api';
export default {
  // 公用接口
  MEDIA_ACCOUNT_LIST: `/api/mediaAccountList`, // 获取产品对应的广告投放账号
  // 上报菜单使用
  REPORTED_MENU: `/api/operation/report`,

  SET_WATER_MARK_STATE: `/api/setWatermarkOpen`,
  SET_WATER_MARK: `/api/setWatermark`,
  GET_WATER_MARK: `/api/getWatermark`,
};
