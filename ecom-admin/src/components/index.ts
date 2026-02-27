import { App } from 'vue';
import { use } from 'echarts/core';
import { Icon } from '@arco-design/web-vue';
import { CanvasRenderer } from 'echarts/renderers';
import { BarChart, LineChart, PieChart, RadarChart } from 'echarts/charts';
import {
  GridComponent,
  TooltipComponent,
  LegendComponent,
  DataZoomComponent,
  GraphicComponent,
} from 'echarts/components';
import SearchForm from '@/components/searchForm/searchForm.vue';
import Chart from './chart/index.vue';
import Breadcrumb from './breadcrumb/index.vue';
import IconSelector from './icon-selector/index.vue';

import CRangePicker from './date-picker/RangePicker.vue';
import PlayPopover from './play-popover/index.vue';
import ImgPopover from './img-popover/index.vue';
import BaseTable from './table/base-table.vue';

// Manually introduce ECharts modules to reduce packing size
const IconFont = Icon.addFromIconFontCn({
  src: '//at.alicdn.com/t/c/font_4144300_5zgj4celhy6.js',
});

const components: any = import.meta.globEager('./searchForm/*.vue');
const componentEntries: any = Object.entries(components);

use([
  CanvasRenderer,
  BarChart,
  LineChart,
  PieChart,
  RadarChart,
  GridComponent,
  TooltipComponent,
  LegendComponent,
  DataZoomComponent,
  GraphicComponent,
]);

export default {
  install(Vue: App) {
    Vue.component('Chart', Chart);
    Vue.component('Breadcrumb', Breadcrumb);
    Vue.component('IconSelector', IconSelector);
    Vue.component('CRangePicker', CRangePicker);
    Vue.component('IconFont', IconFont);
    Vue.component('SearchForm', SearchForm);
    Vue.component('PlayPopover', PlayPopover);
    Vue.component('ImgPopover', ImgPopover);
    Vue.component('BaseTable', BaseTable);

    componentEntries.forEach(([path, component]: any) => {
      const name =
        path.match(/\.\/searchForm\/([\w-]+)\.vue$/)?.[1] ?? 'UnknownComponent';
      Vue.component(name, component.default);
    });
  },
};
