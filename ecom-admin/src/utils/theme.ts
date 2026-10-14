/**
 * 主题切换工具
 * 支持亮色/暗色模式切换
 */

export type ThemeMode = 'light' | 'dark' | 'auto';

const THEME_STORAGE_KEY = 'app-theme-mode';

class ThemeManager {
  private currentTheme: ThemeMode = 'light';
  private listeners: Set<(theme: ThemeMode) => void> = new Set();

  constructor() {
    this.init();
  }

  /**
   * 初始化主题
   */
  private init(): void {
    // 从 localStorage 读取主题设置
    const savedTheme = localStorage.getItem(THEME_STORAGE_KEY) as ThemeMode;

    if (savedTheme) {
      this.setTheme(savedTheme, false);
    } else {
      // 检测系统主题偏好
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      this.setTheme(prefersDark ? 'dark' : 'light', false);
    }

    // 监听系统主题变化
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (this.currentTheme === 'auto') {
        this.applyTheme(e.matches ? 'dark' : 'light');
      }
    });
  }

  /**
   * 应用主题到 DOM
   */
  private applyTheme(theme: 'light' | 'dark'): void {
    if (theme === 'dark') {
      document.body.setAttribute('arco-theme', 'dark');
      document.documentElement.classList.add('dark');
    } else {
      document.body.removeAttribute('arco-theme');
      document.documentElement.classList.remove('dark');
    }
  }

  /**
   * 获取实际应用的主题（处理 auto 模式）
   */
  private getActualTheme(theme: ThemeMode): 'light' | 'dark' {
    if (theme === 'auto') {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return theme;
  }

  /**
   * 设置主题
   * @param theme 主题模式
   * @param save 是否保存到 localStorage
   */
  setTheme(theme: ThemeMode, save: boolean = true): void {
    this.currentTheme = theme;

    // 应用主题
    const actualTheme = this.getActualTheme(theme);
    this.applyTheme(actualTheme);

    // 保存到 localStorage
    if (save) {
      localStorage.setItem(THEME_STORAGE_KEY, theme);
    }

    // 通知监听器
    this.notifyListeners(theme);
  }

  /**
   * 获取当前主题
   */
  getTheme(): ThemeMode {
    return this.currentTheme;
  }

  /**
   * 获取实际应用的主题
   */
  getActualThemeMode(): 'light' | 'dark' {
    return this.getActualTheme(this.currentTheme);
  }

  /**
   * 切换主题（亮色 <-> 暗色）
   */
  toggleTheme(): void {
    const actualTheme = this.getActualTheme(this.currentTheme);
    const newTheme = actualTheme === 'light' ? 'dark' : 'light';
    this.setTheme(newTheme);
  }

  /**
   * 是否为暗色模式
   */
  isDark(): boolean {
    return this.getActualTheme(this.currentTheme) === 'dark';
  }

  /**
   * 是否为亮色模式
   */
  isLight(): boolean {
    return this.getActualTheme(this.currentTheme) === 'light';
  }

  /**
   * 添加主题变化监听器
   */
  addListener(listener: (theme: ThemeMode) => void): () => void {
    this.listeners.add(listener);

    // 返回移除监听器的函数
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * 通知所有监听器
   */
  private notifyListeners(theme: ThemeMode): void {
    this.listeners.forEach((listener) => {
      try {
        listener(theme);
      } catch (error) {
        console.error('主题监听器执行错误:', error);
      }
    });
  }

  /**
   * 获取主题颜色变量
   */
  getThemeColors(): Record<string, string> {
    const isDark = this.isDark();

    return {
      // 主色
      primary: isDark ? '#6366f1' : '#6366f1',
      primaryLight: isDark ? '#818cf8' : '#818cf8',
      primaryDark: isDark ? '#4f46e5' : '#4f46e5',

      // 背景色
      bgBase: isDark ? '#17171a' : '#ffffff',
      bgContainer: isDark ? '#232324' : '#f7f8fa',
      bgElevated: isDark ? '#2e2e30' : '#ffffff',

      // 文字色
      textPrimary: isDark ? '#f7f8fa' : '#1d2129',
      textSecondary: isDark ? '#c9cdd4' : '#4e5969',
      textDisabled: isDark ? '#86909c' : '#c9cdd4',

      // 边框色
      borderBase: isDark ? '#3c3c3f' : '#e5e6eb',
      borderLight: isDark ? '#2e2e30' : '#f2f3f5',

      // 状态色
      success: isDark ? '#10b981' : '#10b981',
      warning: isDark ? '#f59e0b' : '#f59e0b',
      danger: isDark ? '#ef4444' : '#ef4444',
      info: isDark ? '#3b82f6' : '#3b82f6',
    };
  }

  /**
   * 获取主题配置（用于 Arco Design）
   */
  getArcoThemeConfig(): Record<string, any> {
    const isDark = this.isDark();

    return {
      theme: isDark ? 'dark' : 'light',
      themeColor: '#6366f1',
    };
  }
}

// 全局主题管理器实例
export const theme = new ThemeManager();

/**
 * Vue 组合式 API Hook
 * 在组件中使用主题
 */
export function useTheme() {
  const currentTheme = theme.getTheme();
  const isDark = theme.isDark();
  const isLight = theme.isLight();

  const setTheme = (newTheme: ThemeMode) => {
    theme.setTheme(newTheme);
  };

  const toggleTheme = () => {
    theme.toggleTheme();
  };

  const addListener = (listener: (theme: ThemeMode) => void) => {
    return theme.addListener(listener);
  };

  return {
    currentTheme,
    isDark,
    isLight,
    setTheme,
    toggleTheme,
    addListener,
    getThemeColors: () => theme.getThemeColors(),
  };
}

/**
 * 主题切换动画
 */
export function animateThemeTransition(callback: () => void): void {
  // 添加过渡类
  document.documentElement.classList.add('theme-transition');

  // 执行回调
  callback();

  // 移除过渡类
  setTimeout(() => {
    document.documentElement.classList.remove('theme-transition');
  }, 300);
}

/**
 * 获取主题相关的 CSS 变量
 */
export function getThemeCSSVariables(): Record<string, string> {
  const colors = theme.getThemeColors();
  const variables: Record<string, string> = {};

  Object.entries(colors).forEach(([key, value]) => {
    variables[`--theme-${key}`] = value;
  });

  return variables;
}

/**
 * 应用主题 CSS 变量到 DOM
 */
export function applyThemeCSSVariables(): void {
  const variables = getThemeCSSVariables();
  const root = document.documentElement;

  Object.entries(variables).forEach(([key, value]) => {
    root.style.setProperty(key, value);
  });
}

// 导出默认对象
export default {
  theme,
  useTheme,
  animateThemeTransition,
  getThemeCSSVariables,
  applyThemeCSSVariables,
};
