import axios, { AxiosResponse } from 'axios';
import { isArray, isNumber, isString } from 'lodash';
import { Notification, Space, Button, Message } from '@arco-design/web-vue';
import { h } from 'vue';
import { HttpResponse } from '@/api/request';
import { getToken } from '@/utils/auth';
import router from '@/router';

export function isDef(v: any): boolean {
  return v !== undefined && v !== null;
}

const NODE_ENV = import.meta.env.VITE_NODE_ENV as string;
/**
 * form 表单的方式发起 export 事件
 * @param publicHost API路径
 * @param data 传输数据对象
 * @returns {Promise<AxiosResponse>}
 */
export async function exportForm(
  publicHost: string,
  data: any
): Promise<HttpResponse> {
  return new Promise((resolve, reject) => {
    axios({
      method: 'post',
      url: publicHost,
      data: data || {},
      responseType: 'blob',
      baseURL: NODE_ENV === 'production' ? `${window.location.origin}/be` : '',
      headers: {
        Authorization: getToken(),
      },
    })
      .then((res) => {
        let fileName = `响应头无文件名-${Date.now()}`;
        try {
          if (res.headers['content-disposition'].includes('filename*=utf-8')) {
            fileName = decodeURIComponent(
              res.headers['content-disposition']
                .split(';')[2]
                .split("filename*=utf-8''")[1]
            );
          } else {
            fileName = decodeURIComponent(
              res.headers['content-disposition']
                .split(';')[1]
                .split('filename=')[1]
                .replace(/"/g, '')
            );
          }
        } catch (e) {
          console.log(e);
        }
        const blob = new Blob([res.data], {
          type: 'application/octet-stream',
        });
        // @ts-ignore
        if (window.navigator.msSaveOrOpenBlob) {
          // @ts-ignore
          navigator.msSaveBlob(blob, fileName);
        } else {
          const link = document.createElement('a');
          link.href = window.URL.createObjectURL(blob);
          link.download = fileName;
          link.click();
          window.URL.revokeObjectURL(link.href);
        }
        resolve(res.data);
      })
      .catch((error) => {
        let { message } = error;
        Message.error(message);
        console.log('导出失败', error);
        reject(error);
      });
  });
}

export function numToYiOrWan(value: number) {
  // 数字转换
  const param: any = {};
  const k = 10000;
  const sizes = ['', '万', '亿', '万亿'];
  let i;
  if (value < k) {
    param.value = value;
    param.unit = '';
  } else {
    i = Math.floor(Math.log(value) / Math.log(k));
    param.value = (value / k ** i).toFixed(2);
    param.unit = sizes[i];
  }
  param.text = Number.isNaN(param.value) ? '' : param.value + param.unit;
  return param;
}

// 文件对象转base64
export const getBase64 = (file: File) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = () => resolve(reader.result);
    reader.onerror = (error) => reject(error);
  });
};

// 把base64 转换成文件对象
export function dataURLtoFile(base64Str: string, fileName: string) {
  const arr = base64Str.split(',');
  if (arr[0]) {
    // @ts-ignore
    const mime = arr[0].match(/:(.*?);/)[1]; // base64解析出来的图片类型
    const bstr = atob(arr[1]); // 对base64串进行操作，去掉url头，并转换为byte   atob为window内置方法
    let len = bstr.length;
    const ab = new ArrayBuffer(len); // 将ASCII码小于0的转换为大于0
    const u8arr = new Uint8Array(ab); //
    // eslint-disable-next-line no-plusplus
    while (len--) {
      u8arr[len] = bstr.charCodeAt(len);
    }
    // 创建新的 File 对象实例[utf-8内容，文件名称或者路径，[可选参数，type：文件中的内容mime类型]]
    return new File([u8arr], fileName, {
      type: mime,
    });
  }
  return base64Str;
}

export const createObject = (
  path: string[],
  value: any
): { [key: string]: any } => {
  let keyPath: string[] = [];
  if (isArray(path)) keyPath = [...path];
  const key = keyPath.shift();
  if (isDef(key)) {
    if (isNumber(key)) {
      const obj = new Array(key + 1);
      obj[key] = createObject(keyPath, value);
      return obj;
    }
    // @ts-ignore
    return { [key]: createObject(keyPath, value) };
  }
  return value;
};

export const setPathValue = (
  obj: { [key: string]: any },
  path: string[] | string,
  value: any
): { [key: string]: any } => {
  let keyPath: string[] = [];
  if (isArray(path)) keyPath = [...path];
  else if (isString(path)) keyPath = path.split('.');
  const key = keyPath.shift();
  if (isDef(key)) {
    // @ts-ignore
    if (obj && isDef(obj[key])) {
      // @ts-ignore
      obj[key] = setPathValue(obj[key], keyPath, value);
    } else {
      // @ts-ignore
      obj[key] = createObject(keyPath, value);
    }
  } else obj = value;
  return obj;
};

export const getPathValue = (
  obj: { [key: string]: any },
  path: string[] | string
) => {
  let keyPath: string[] = [];
  if (isArray(path)) keyPath = [...path];
  else if (isString(path)) keyPath = path.split('.');
  if (keyPath.length) {
    return keyPath.reduce(
      (currentObj, key) => currentObj && currentObj[key],
      obj || {}
    );
  }
  return '';
};

// 设置光标位置
export const setCaretPosition = (iptDom: HTMLInputElement, pos: number) => {
  if (iptDom.setSelectionRange) {
    iptDom.focus();
    iptDom.setSelectionRange(pos, pos);
    // @ts-ignore
  } else if (iptDom.createTextRange) {
    // @ts-ignore
    const range = iptDom.createTextRange();
    range.moveStart('character', pos);
    range.moveEnd('character', pos);
    range.collapse(true);
    range.select();
  } else {
    iptDom.selectionStart = pos;
    iptDom.selectionEnd = pos;
  }
};

// 获取字符的长度, 非英文码则计算长度为2
export function getByteLen(str: string): number {
  let len = 0;
  for (let i = 0; i < str.length; i += 1) {
    const length = str.charCodeAt(i);
    if (length >= 0 && length <= 128) {
      len += 1;
    } else {
      len += 2;
    }
  }
  return len;
}

/**
 * 下载文件 -直接通过链接下载，不经文件流
 */
export async function downloadLinkFile(url: string) {
  const alink = document.createElement('a');
  alink.setAttribute('download', url);
  alink.setAttribute('href', url);
  document.body.appendChild(alink);
  alink.click();
  document.body.removeChild(alink);
}

export function getNoMarkUrl(str: string): string {
  if (str) {
    const urlArr = str.split('/');
    const lastName = urlArr.pop() || '';
    const fileExtension = lastName.substring(lastName.lastIndexOf('.') + 1);
    const fileName = lastName.substring(0, lastName.lastIndexOf('.'));
    urlArr.push(`${fileName.split('').reverse().join('')}.${fileExtension}`);
    return urlArr.join('/');
  }
  return '';
}

export const handleNotification = (type: any) => {
  const id = `${Date.now()}`;
  Notification.clear();
  Notification.info({
    id,
    title: '提示',
    content: () =>
      h('div', {}, [
        '任务提交成功，点击',
        h(
          'a',
          {
            class: 'a-text',
            onClick: () => {
              let routeUrl = router.resolve({
                name: 'task-manage',
                query: {
                  type: type || 'download',
                },
              });
              window.open(routeUrl.href, '_blank');
              // router.push({
              //   name: 'task-manage',
              //   target: '_blank',
              //   query: {
              //     type: type || 'download',
              //   },
              // });
            },
          },
          '任务中心'
        ),
        '立即查看',
      ]),
    // position: 'bottomRight',
    closable: true,
    duration: 5000,
  });
};
