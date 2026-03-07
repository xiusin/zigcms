/**
 * 交互式图表 Composable
 * 支持图表点击钻取、数据导出、自定义配置等功能
 */

import { ref, computed, onMounted, onUnmounted } from 'vue';
import * as echarts from 'echarts';
import { Message } from '@arco-design/web-vue';

export interface ChartConfig {
  type: 'line' | 'bar' | 'pie' | 'scatter' | 'heatmap';
  title?: string;
  subtitle?: string;
  xAxis?: any;
  yAxis?: any;
  series?: any[];
  legend?: any;
  tooltip?: any;
  grid?: any;
  dataZoom?: any[];
  toolbox?: any;
}

export interface DrillDownConfig {
  enabled: boolean;
  levels: string[];
  currentLevel: number;
  onDrillDown?: (params: any) => void;
  onDrillUp?: () => void;
}

export interface ExportConfig {
  formats: ('png' | 'jpg' | 'svg' | 'pdf' | 'excel' | 'csv')[];
  filename?: string;
}

export interface UseInteractiveChartOptions {
  /**
   * 图表容器元素
   */
  container: HTMLElement | null;
  
  /**
   * 初始配置
   */
  config: ChartConfig;
  
  /**
   * 钻取配置
   */
  drillDown?: DrillDownConfig;
  
  /**
   * 导出配置
   */
  export?: ExportConfig;
  
  /**
   * 是否启用实时更新
   */
  realtime?: boolean;
  
  /**
   * 实时更新间隔（毫秒）
   */
  realtimeInterval?: number;
  
  /**
   * 点击事件回调
   */
  onClick?: (params: any) => void;
  
  /**
   * 数据更新回调
   */
  onDataUpdate?: (data: any) => void;
}

export function useInteractiveChart(options: UseInteractiveChartOptions) {
  const {
    container,
    config,
    drillDown,
    export: exportConfig,
    realtime = false,
    realtimeInterval = 5000,
    onClick,
    onDataUpdate,
  } = options;
  
  // 图表实例
  let chartInstance: echarts.ECharts | null = null;
  
  // 状态
  const loading = ref(false);
  const currentConfig = ref<ChartConfig>(config);
  const drillDownHistory = ref<any[]>([]);
  const currentDrillLevel = ref(0);
  
  // 实时更新定时器
  let realtimeTimer: number | null = null;
  
  /**
   * 初始化图表
   */
  const init = () => {
    if (!container) {
      console.error('[InteractiveChart] Container is null');
      return;
    }
    
    // 创建图表实例
    chartInstance = echarts.init(container);
    
    // 设置初始配置
    updateChart(currentConfig.value);
    
    // 绑定事件
    bindEvents();
    
    // 启动实时更新
    if (realtime) {
      startRealtime();
    }
    
    // 监听窗口大小变化
    window.addEventListener('resize', handleResize);
  };
  
  /**
   * 更新图表
   */
  const updateChart = (config: ChartConfig) => {
    if (!chartInstance) return;
    
    const option = buildChartOption(config);
    chartInstance.setOption(option, true);
    currentConfig.value = config;
  };
  
  /**
   * 构建图表配置
   */
  const buildChartOption = (config: ChartConfig): any => {
    const baseOption: any = {
      title: {
        text: config.title,
        subtext: config.subtitle,
        left: 'center',
      },
      tooltip: config.tooltip || {
        trigger: 'axis',
        axisPointer: {
          type: 'shadow',
        },
      },
      legend: config.legend || {
        bottom: 10,
      },
      grid: config.grid || {
        left: '3%',
        right: '4%',
        bottom: '10%',
        containLabel: true,
      },
      toolbox: {
        feature: {
          saveAsImage: {
            title: '保存为图片',
          },
          dataZoom: {
            title: {
              zoom: '区域缩放',
              back: '还原',
            },
          },
          restore: {
            title: '还原',
          },
          dataView: {
            title: '数据视图',
            readOnly: false,
          },
          magicType: {
            title: {
              line: '折线图',
              bar: '柱状图',
              stack: '堆叠',
              tiled: '平铺',
            },
            type: ['line', 'bar'],
          },
        },
      },
    };
    
    // 添加坐标轴
    if (config.xAxis) {
      baseOption.xAxis = config.xAxis;
    }
    
    if (config.yAxis) {
      baseOption.yAxis = config.yAxis;
    }
    
    // 添加系列
    if (config.series) {
      baseOption.series = config.series;
    }
    
    // 添加数据缩放
    if (config.dataZoom) {
      baseOption.dataZoom = config.dataZoom;
    }
    
    return baseOption;
  };
  
  /**
   * 绑定事件
   */
  const bindEvents = () => {
    if (!chartInstance) return;
    
    // 点击事件
    chartInstance.on('click', (params: any) => {
      console.log('[InteractiveChart] Click:', params);
      
      // 触发回调
      onClick?.(params);
      
      // 处理钻取
      if (drillDown?.enabled && canDrillDown()) {
        handleDrillDown(params);
      }
    });
    
    // 双击事件
    chartInstance.on('dblclick', (params: any) => {
      console.log('[InteractiveChart] Double click:', params);
    });
    
    // 鼠标悬停事件
    chartInstance.on('mouseover', (params: any) => {
      // 可以添加悬停效果
    });
  };
  
  /**
   * 处理钻取
   */
  const handleDrillDown = (params: any) => {
    if (!drillDown) return;
    
    // 保存当前配置到历史
    drillDownHistory.value.push({
      config: { ...currentConfig.value },
      level: currentDrillLevel.value,
    });
    
    // 增加钻取层级
    currentDrillLevel.value++;
    
    // 触发钻取回调
    drillDown.onDrillDown?.(params);
  };
  
  /**
   * 返回上一层
   */
  const drillUp = () => {
    if (drillDownHistory.value.length === 0) return;
    
    const previous = drillDownHistory.value.pop();
    if (previous) {
      currentDrillLevel.value = previous.level;
      updateChart(previous.config);
      
      // 触发回调
      drillDown?.onDrillUp?.();
    }
  };
  
  /**
   * 是否可以钻取
   */
  const canDrillDown = (): boolean => {
    if (!drillDown) return false;
    return currentDrillLevel.value < drillDown.levels.length - 1;
  };
  
  /**
   * 是否可以返回
   */
  const canDrillUp = computed(() => {
    return drillDownHistory.value.length > 0;
  });
  
  /**
   * 导出图表
   */
  const exportChart = async (format: 'png' | 'jpg' | 'svg' | 'pdf' | 'excel' | 'csv') => {
    if (!chartInstance) {
      Message.error('图表未初始化');
      return;
    }
    
    loading.value = true;
    
    try {
      const filename = exportConfig?.filename || `chart_${Date.now()}`;
      
      switch (format) {
        case 'png':
        case 'jpg':
          exportAsImage(format, filename);
          break;
        case 'svg':
          exportAsSVG(filename);
          break;
        case 'pdf':
          await exportAsPDF(filename);
          break;
        case 'excel':
          await exportAsExcel(filename);
          break;
        case 'csv':
          await exportAsCSV(filename);
          break;
      }
      
      Message.success(`导出${format.toUpperCase()}成功`);
    } catch (error: any) {
      Message.error(`导出失败: ${error.message}`);
    } finally {
      loading.value = false;
    }
  };
  
  /**
   * 导出为图片
   */
  const exportAsImage = (format: 'png' | 'jpg', filename: string) => {
    if (!chartInstance) return;
    
    const url = chartInstance.getDataURL({
      type: format,
      pixelRatio: 2,
      backgroundColor: '#fff',
    });
    
    downloadFile(url, `${filename}.${format}`);
  };
  
  /**
   * 导出为SVG
   */
  const exportAsSVG = (filename: string) => {
    if (!chartInstance) return;
    
    const svg = chartInstance.renderToSVGString();
    const blob = new Blob([svg], { type: 'image/svg+xml' });
    const url = URL.createObjectURL(blob);
    
    downloadFile(url, `${filename}.svg`);
    URL.revokeObjectURL(url);
  };
  
  /**
   * 导出为PDF
   */
  const exportAsPDF = async (filename: string) => {
    // 需要引入 jsPDF 库
    Message.info('PDF导出功能开发中...');
  };
  
  /**
   * 导出为Excel
   */
  const exportAsExcel = async (filename: string) => {
    if (!chartInstance) return;
    
    // 获取图表数据
    const option = chartInstance.getOption() as any;
    const data = extractChartData(option);
    
    // 转换为Excel格式
    const csv = convertToCSV(data);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    
    downloadFile(url, `${filename}.csv`);
    URL.revokeObjectURL(url);
  };
  
  /**
   * 导出为CSV
   */
  const exportAsCSV = async (filename: string) => {
    if (!chartInstance) return;
    
    const option = chartInstance.getOption() as any;
    const data = extractChartData(option);
    const csv = convertToCSV(data);
    
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    
    downloadFile(url, `${filename}.csv`);
    URL.revokeObjectURL(url);
  };
  
  /**
   * 提取图表数据
   */
  const extractChartData = (option: any): any[][] => {
    const data: any[][] = [];
    
    // 提取表头
    const headers: string[] = [];
    if (option.xAxis && option.xAxis[0]?.data) {
      headers.push('X轴');
    }
    
    if (option.series) {
      option.series.forEach((s: any) => {
        headers.push(s.name || '数据');
      });
    }
    
    data.push(headers);
    
    // 提取数据
    if (option.xAxis && option.xAxis[0]?.data) {
      const xData = option.xAxis[0].data;
      xData.forEach((x: any, index: number) => {
        const row: any[] = [x];
        
        if (option.series) {
          option.series.forEach((s: any) => {
            row.push(s.data[index] || '');
          });
        }
        
        data.push(row);
      });
    }
    
    return data;
  };
  
  /**
   * 转换为CSV
   */
  const convertToCSV = (data: any[][]): string => {
    return data.map(row => row.join(',')).join('\n');
  };
  
  /**
   * 下载文件
   */
  const downloadFile = (url: string, filename: string) => {
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
  };
  
  /**
   * 启动实时更新
   */
  const startRealtime = () => {
    if (realtimeTimer) return;
    
    realtimeTimer = window.setInterval(() => {
      onDataUpdate?.(currentConfig.value);
    }, realtimeInterval);
  };
  
  /**
   * 停止实时更新
   */
  const stopRealtime = () => {
    if (realtimeTimer) {
      clearInterval(realtimeTimer);
      realtimeTimer = null;
    }
  };
  
  /**
   * 处理窗口大小变化
   */
  const handleResize = () => {
    chartInstance?.resize();
  };
  
  /**
   * 显示加载状态
   */
  const showLoading = () => {
    chartInstance?.showLoading();
  };
  
  /**
   * 隐藏加载状态
   */
  const hideLoading = () => {
    chartInstance?.hideLoading();
  };
  
  /**
   * 清空图表
   */
  const clear = () => {
    chartInstance?.clear();
  };
  
  /**
   * 销毁图表
   */
  const dispose = () => {
    stopRealtime();
    window.removeEventListener('resize', handleResize);
    chartInstance?.dispose();
    chartInstance = null;
  };
  
  // 生命周期
  onMounted(() => {
    init();
  });
  
  onUnmounted(() => {
    dispose();
  });
  
  return {
    // 状态
    loading: computed(() => loading.value),
    canDrillUp,
    currentDrillLevel: computed(() => currentDrillLevel.value),
    
    // 方法
    updateChart,
    drillUp,
    exportChart,
    showLoading,
    hideLoading,
    clear,
    dispose,
    startRealtime,
    stopRealtime,
    
    // 图表实例
    getInstance: () => chartInstance,
  };
}

