import { defineStore } from 'pinia';
import { App, h } from 'vue';
import { Notification } from '@arco-design/web-vue';

interface VersionState {
  version: string | null;
  [key: string]: unknown | null;
}
const versionKey = 'shentui-appVersion';
export const useVersionStore = defineStore('version', {
  state: (): VersionState => ({
    version: localStorage.getItem(versionKey) || '', // 版本标记
    updateVersion: '',
  }),
  getters: {
    versionStr(state: VersionState): any {
      return state.version || localStorage.getItem(versionKey) || '--';
    },
  },
  actions: {
    setVersion(val: string) {
      this.version = val;
      localStorage.setItem(versionKey, val);
    },
    setUpdateVersion(val: string) {
      this.updateVersion = val;
    },
  },
});
export default {
  timer: 1,
  versionStore: null as any,
  setCheck() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      this.checkVersion();
    }, 60000) as unknown as number;
  },
  visibilityChange() {
    // console.log('visibilityState', document.visibilityState);
    if (document.visibilityState === 'visible') {
      this.setCheck();
    } else {
      clearTimeout(this.timer);
    }
  },
  // 展示更新消息
  showNotes() {
    // console.info('有新版本');
    const key = `version-${Date.now()}`;
    Notification.clear();
    Notification.info({
      id: key,
      title: '新消息',
      content: () =>
        h('div', {}, [
          '有新版本可用了！ 点击 ',
          h(
            'a',
            {
              class: 'a-text',
              onClick: () => {
                window.location.reload();
              },
            },
            '新版本'
          ),
          ' 使用新功能吧！',
        ]),
      position: 'bottomRight',
      closable: true,
      duration: 0,
    });
  },
  // 获取html中的version
  getVersionForHtml(html?: any) {
    let parser = new DOMParser();
    let doc = html ? parser.parseFromString(html, 'text/html') : document;
    // @ts-ignore
    return doc.getElementsByTagName('meta').version?.content;
  },
  async checkVersion(needTimer = true) {
    return new Promise((resolve, reject) => {
      const { versionStr: lcVersion } = useVersionStore();
      fetch(
        `${window.location.origin + window.location.pathname}?t=${Date.now()}`
      )
        .then(async (res) => {
          let resHtml = await res.text();
          let metaVersion = this.getVersionForHtml(resHtml);
          // console.log(lcVersion, metaVersion);
          if (lcVersion !== metaVersion) {
            this.versionStore?.setUpdateVersion(metaVersion);
            clearTimeout(this.timer);
            if (needTimer) this.showNotes();
            resolve(true);
            return;
          }
          if (needTimer) this.setCheck();
        })
        .catch((err) => {
          console.log('Failed to fetch page: ', err);
          reject(err);
        });
    });
  },
  install(Vue: App) {
    this.versionStore = useVersionStore() as any;
    // 初始存储缓存html中携带的版本
    this.versionStore?.setVersion(this.getVersionForHtml());
    this.setCheck();
    document.removeEventListener(
      'visibilitychange',
      this.visibilityChange,
      false
    );
    document.addEventListener(
      'visibilitychange',
      this.visibilityChange.bind(this),
      false
    );
  },
};
