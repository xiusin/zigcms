<!--全局跨度日历控件 -->
<template>
  <a-range-picker
    v-model="dateArr"
    :allow-clear="allowClear"
    :disabled-date="disabledDate"
    :format="format"
    :mode="mode"
    :value-format="format"
    :shortcuts="defaultRanges"
    class="cus-range-date"
    dropdown-class-name="range-picker"
    @change="handleChange"
    @select-shortcut="setRangeDate"
  >
  </a-range-picker>
</template>

<script>
  import dayjs from 'dayjs';

  export default {
    name: 'CRangePicker',
    components: {},
    props: {
      // 是否限制最大可选日期为今天
      maxDateDisabled: {
        default: true,
        type: Boolean,
      },
      // 限制最小日期为多少天前
      minDateDisabled: {
        default: 0,
        type: Number,
      },
      parentRange: {
        default: () => {
          return '';
        },
        type: String,
      },
      mode: {
        default: 'date',
        type: String,
      },
      modelValue: {
        default: () => [],
        type: Array,
      },
      allowClear: {
        default: () => false,
        type: Boolean,
      },
      inputReadOnly: {
        default: () => false,
        type: Boolean,
      },
      needDefault: {
        default: true,
        type: Boolean,
      },
    },
    emits: ['change', 'update:modelValue'],
    data() {
      return {
        rangeOpen: false,
        defaultValue: '近7天',
        dateType: 'date',
        format: 'YYYY-MM',
        dateArr: [],
        defaultRanges: [],
        defaultRangesMonth: [
          {
            label: '本月',
            value: () => [dayjs().startOf('month').add(0, 'month'), dayjs()],
          },
          {
            label: '上月',
            value: () => [
              dayjs().add(-1, 'month').startOf('month'),
              dayjs().add(-1, 'month').endOf('month'),
            ],
          },
          {
            label: '近3月',
            value: () => [
              dayjs().add(-2, 'month').startOf('month'),
              dayjs().add(0, 'month').endOf('month'),
            ],
          },
          {
            label: '近6月',
            value: () => [
              dayjs().add(-5, 'month').startOf('month'),
              dayjs().add(0, 'month').endOf('month'),
            ],
          },
          {
            label: '近12月',
            value: () => [
              dayjs().add(-11, 'month').startOf('month'),
              dayjs().add(0, 'month').endOf('month'),
            ],
          },
        ],
        defaultRangesDay: [
          {
            label: '今天',
            value: () => [dayjs(), dayjs()],
          },
          {
            label: '昨天',
            value: () => [
              dayjs().add(-1, 'days').startOf('days'),
              dayjs().add(-1, 'days').startOf('days'),
            ],
          },
          {
            label: '近7天',
            value: () => [
              dayjs().add(-6, 'days').startOf('days'),
              dayjs().add(0, 'days').startOf('days'),
            ],
          },
          {
            label: '近30天',
            value: () => [
              dayjs().add(-29, 'days').startOf('days'),
              dayjs().add(0, 'days').startOf('days'),
            ],
          },
          {
            label: '本周',
            value: () => [dayjs().startOf('week').day(0), dayjs()],
          },
          {
            label: '上周',
            value: () => [
              dayjs().add(-1, 'week').startOf('week').day(0),
              dayjs().add(-1, 'week').endOf('week'),
            ],
          },
          {
            label: '本月',
            value: () => [dayjs().add(0, 'month').startOf('month'), dayjs()],
          },
          {
            label: '上月',
            value: () => [
              dayjs().add(-1, 'month').startOf('month'),
              dayjs().add(-1, 'month').endOf('month'),
            ],
          },
        ],
      };
    },
    computed: {
      // 输出为字符串
      showDateArr() {
        if (this.dateArr.length === 2) {
          return [
            dayjs(this.dateArr[0]).format(this.format),
            dayjs(this.dateArr[1]).format(this.format),
          ];
        }
        return [];
      },
    },
    watch: {
      mode: {
        handler(newVal, oldVal) {
          if (newVal === 'date') {
            this.dateType = 'date';
            this.defaultRanges = this.defaultRangesDay;
            this.format = 'YYYY-MM-DD';
          }
          if (newVal === 'month') {
            this.dateType = 'month';
            this.defaultRanges = this.defaultRangesMonth;
            this.format = 'YYYY-MM';
          }
          this.setDefaultVal();
        },
        immediate: true,
        deep: true,
      },
      // 宿主主动更新值时，更新组件内各项设置

      modelValue: {
        handler(newVal) {
          if (newVal && newVal.length !== 0 && this.showDateArr !== newVal) {
            this.dateArr = [
              dayjs(newVal[0]).format(this.format),
              dayjs(newVal[1]).format(this.format),
            ];
          } else if (!newVal || newVal?.length === 0) {
            this.setDefaultVal();
          }
        },
        immediate: true,
      },
    },
    created() {},
    methods: {
      setDefaultVal() {
        this.defaultValue = this.parentRange;
        let curInfo = this.defaultRanges.find((item) => {
          return item.label === this.defaultValue;
        });
        if (!curInfo && this.defaultValue !== '-') {
          if (this.dateType === 'date') {
            this.defaultValue = '近7天';
          }
          if (this.dateType === 'month') {
            this.defaultValue = '近3月';
          }
        }
        this.dateArr = this.value || [];
        if (this.dateArr.length === 0) {
          // 宿主没有默认值的时候，可以通过 defaultValue 设定默认跨度
          if (this.defaultValue) {
            curInfo = this.defaultRanges.find((item) => {
              return item.label === this.defaultValue;
            });
            if (curInfo && this.needDefault) {
              this.dateArr = curInfo.value();
            }
          }
          if (this.dateArr.length > 0 && this.value !== this.dateArr) {
            // console.log(this.dateArr, '默认日期', this.showDateArr);
            this.$emit('update:modelValue', this.showDateArr);
            // this.$emit('change', this.showDateArr);
          }
        }
      },
      disabledDate(date) {
        return (
          (this.maxDateDisabled && date.valueOf() > dayjs().valueOf()) ||
          (this.minDateDisabled &&
            date.valueOf() <
              dayjs().add(-this.minDateDisabled, 'day').valueOf())
        );
      },
      // handleEndOpenChange(open) {
      //   this.rangeOpen = open;
      // },
      handleChange(val, mode) {
        this.dateArr = val;
        this.$emit('update:modelValue', this.showDateArr);
        this.$emit('change', this.showDateArr);
      },
      setRangeDate(val) {
        this.dateArr = val.value();
        this.$emit('update:modelValue', this.showDateArr);
      },
    },
  };
</script>

<style lang="less">
  .cus-range-date {
    width: 230px;
  }
  .range-picker .ant-calendar-footer-btn {
    display: flex;
    flex-direction: row-reverse;
    justify-content: space-between;
    .ant-calendar-footer-extra {
      float: none;
    }
  }
</style>
