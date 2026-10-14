import defaultApi from './api';
import request from './request';

const {
  REPORTED_MENU,
  MEDIA_ACCOUNT_LIST,
  SET_WATER_MARK_STATE,
  SET_WATER_MARK,
  GET_WATER_MARK,
} = defaultApi;

// 菜单上报
export async function doReportedMenu(params: any) {
  return request(REPORTED_MENU, params);
}

// 获取媒体账户列表
export async function getMediaAccountList(params: any) {
  return request(MEDIA_ACCOUNT_LIST, params);
}

// 设置水印开关状态
export async function setWaterMarkState(params: any) {
  return request(SET_WATER_MARK_STATE, params);
}

// 设置水印
export async function setWaterMark(params: any) {
  return request(SET_WATER_MARK, params);
}

// 设置水印
export async function getWaterMark(params: any) {
  return request(GET_WATER_MARK, params);
}
