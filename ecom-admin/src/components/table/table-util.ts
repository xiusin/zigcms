import numeral from 'numeral';
import { Message } from '@arco-design/web-vue';

// 全局翻页配置 - 使用 mini 小尺寸
export const pageConfig = (params: any) => ({
  showSizeChanger: true,
  showPageSize: true,
  current: 1,
  pageSize: 20,
  total: 0,
  pageSizeOptions: [10, 20, 50, 100],
  showTotal: true,
  size: 'mini',
  showJumper: true,
  baseSize: 'mini',
  ...params,
});

// 格式化过滤空值
export const formatEmptyStr = (str: any) => {
  return str || '-';
};

export const moneyFormat = (value: any, prefix?: string, suffix?: string) => {
  if ([undefined, null].includes(value)) {
    return '-';
  }
  if (prefix) {
    return prefix + value;
  }
  if (suffix) {
    return value + suffix;
  }
  return numeral(value).format('0,0.00');
};
export const numberFormat = (value: any, prefix?: string, suffix?: string) => {
  if ([undefined, null].includes(value)) {
    return '-';
  }
  if (prefix) {
    return prefix + value;
  }
  if (suffix) {
    return value + suffix;
  }
  return numeral(value).format('0,0');
};

export const rateFormat = (value: any, prefix?: string, suffix?: string) => {
  if ([undefined, null].includes(value)) {
    return '-';
  }
  if (prefix) {
    return prefix + value;
  }
  if (suffix) {
    return value + suffix;
  }
  return `${numeral(value).format('0,0.00')}%`;
};

/**
 * 下载文件 -直接通过链接下载，不经文件流
 */
export async function downloadLinkFile(url: string, fileName: string) {
  const domainName = window.location.host.match(/[^.]+\.[^.]+$/)?.[0] || '';
  if (domainName && url.includes(domainName)) {
    // download属性具有同源策略 只有同一域名下的文件才能下载
    const alink = document.createElement('a');

    alink.setAttribute('download', fileName);
    alink.setAttribute('href', url);
    alink.setAttribute('target', '_blank');
    document.body.appendChild(alink);
    alink.click();
    document.body.removeChild(alink);
  } else {
    const res = await fetch(url).catch((err) => err);
    if (res.status !== 200) {
      return;
    }
    const blob = await res.blob();
    const objectUrl = window.URL.createObjectURL(blob);
    const alink = document.createElement('a');
    alink.setAttribute('download', fileName);
    alink.setAttribute('href', objectUrl);
    document.body.appendChild(alink);
    alink.click();
    document.body.removeChild(alink);
  }
}

/**
 * 打开文件
 */
export async function openFile(url: string) {
  const alink = document.createElement('a');
  alink.setAttribute('href', url);
  alink.setAttribute('target', '_blank');
  document.body.appendChild(alink);
  alink.click();
  document.body.removeChild(alink);
}

// 预览文件
export function previewForOnline(url: any) {
  if (!url) {
    return;
  }
  // let xdoUrl = `http://view.xdocin.com/xdoc?_xdoc=${encodeURIComponent(url)}`;
  let textUrl = `https://api.idocv.com/view/url?url=${encodeURIComponent(url)}`;
  let otherUrl = `https://view.officeapps.live.com/op/view.aspx?src=${encodeURIComponent(
    url
  )}`;
  let fileExtension = url.substring(url.lastIndexOf('.') + 1);
  // ["txt", "png","gif", "jpg","pdf","pptx","xlsx","docx"] office格式走微软接口,其他的格式可以使用浏览器打开
  let hasTagList = ['png', 'gif', 'jpg', 'jpeg', 'pdf', 'mp4', 'mp3'];
  let flag = hasTagList.includes(fileExtension);
  if (flag) {
    otherUrl = url;
  }
  // txt 文件直接用浏览器打开时会出现乱码情况，因此使用第三方服务
  if (fileExtension.includes(['txt'])) {
    otherUrl = textUrl;
  }
  window.open(otherUrl, '_blank');
}

// 通用校验是否有未上传完成的文件  并提示
export const checkFileIsUploaded = async (imgArr: any[]) => {
  let passFlag = true;
  imgArr.map((item: any) => {
    if (item.status && item.status === 'uploading') {
      passFlag = false;
    }
    return null;
  });
  if (!passFlag) {
    Message.warning('文件正在上传中！请稍后再试...');
  }
  return passFlag;
};

const weeks = ['一', '二', '三', '四', '五', '六', '日'];
/**
 * @description 头条投放时段转文字
 * @param schedule_time { string } 投放时段数据 00000000011111111111111
 * @return { array } [{"week":"周一", list: [["8:00", "9:00"]]}]
 */
export const getTimes = (schedule_time: string) => {
  let arr: any = [];
  let result: any = [];
  let data = schedule_time.split('');
  Array.from({ length: 7 }, (item, index) => index).forEach((item, index) => {
    arr[index] = data.slice(index * 48, (index + 1) * 48);
  });
  arr.forEach((item: any, index: number) => {
    result[index] = {
      week: `周${weeks[index]}`,
      list: [],
    };
    let times = '';
    item.forEach((val: any, i: number) => {
      if (val === '1') {
        if (!times) {
          let hour =
            Math.floor(i / 2) < 10
              ? `0${Math.floor(i / 2)}`
              : Math.floor(i / 2);
          let minute = i % 2 === 0 ? ':00' : ':30';
          times = hour + minute;
        }
        if (item[i + 1] === '0' || i === 47) {
          let hour =
            Math.floor((i + 1) / 2) < 10
              ? `0${Math.floor((i + 1) / 2)}`
              : Math.floor((i + 1) / 2);
          let minute = (i + 1) % 2 === 0 ? ':00' : ':30';
          result[index].list.push([times, hour + minute]);
          times = '';
        }
      }
    });
    if (result[index].list.length === 0) {
      result[index] = null;
    }
  });
  return result;
};

// 导出流数据
export const ExportBlobFile = async (api: any, option: any = {}) => {
  const res = await api(option, {
    responseType: 'blob',
  });
  console.log(res);
  let fileName = `响应头无文件名-${Date.now()}`;
  try {
    fileName = decodeURIComponent(
      res.headers['content-disposition']
        .split(';')[2]
        .split("filename*=utf-8''")[1]
    );
  } catch (e) {
    console.log(e);
  }
  let blob = new Blob([res.data], {
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
};
