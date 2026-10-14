<template>
  <a-modal
    :hide-title="true"
    :visible="visible"
    :footer="false"
    width="860px"
    :loading="loading"
    @cancel="onClose"
  >
    <!-- <div class="print-box">
      <a-button size="small" @click="() => htmlToPDF('FormPrint', 'test pdf')">
        <template #icon> <icon-printer /> </template>导出</a-button
      >
    </div> -->
    <a-spin :loading="loading" style="width: 100%">
      <div id="FormPrint">
        <table>
          <tr>
            <th colspan="9">
              <div class="table-title"> 货盘需求表 </div>
            </th>
          </tr>
          <tr>
            <th colspan="2">货盘期号</th>
            <th colspan="3">{{ thisFormData.demand_no }}</th>
            <th colspan="2">理货人</th>
            <th colspan="2">{{ thisFormData.user_name }}</th>
          </tr>
          <tr>
            <th colspan="2">货盘需求单位</th>
            <th colspan="3">鹏景</th>
            <th colspan="2">货盘需求部门</th>
            <th colspan="2">实物电商A部</th>
          </tr>
          <tr>
            <th colspan="1">品牌</th>
            <th colspan="1">系列名称</th>
            <th colspan="1">商品规格</th>
            <th colspan="1">颜色</th>
            <th colspan="1">材质</th>
            <th colspan="1">商品数量</th>
            <th colspan="1">备注</th>
            <th colspan="1">需求直播间</th>
            <th colspan="1">大盘参考价</th>
          </tr>
          <tr v-for="(item, index) in thisFormData.products" :key="index">
            <td>{{ item.brand_name }}</td>
            <td>{{ item.style_name }}</td>
            <td>{{ item.size_name }}</td>
            <td>{{ item.color_name }}</td>
            <td>{{ item.element_name }}</td>
            <td>{{ item.num }}</td>
            <td>{{ item.remark }}</td>
            <td>{{ item.position_text || '-' }}</td>
            <td>{{ item.price }}</td>
          </tr>
          <tr>
            <td colspan="9" class="text-right">
              需求表提交时间：{{ thisFormData.created_at }}
            </td>
          </tr>
        </table>
      </div>
    </a-spin>
  </a-modal>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref } from 'vue';
  import request from '@/api/request';
  import { useRoute, useRouter } from 'vue-router';
  import { htmlToPDF } from '@/utils/html2pdf';

  const defaultForm = () => ({
    id: null,
    company_id: 1,
    department_id: 1,
    delete_ids: [],
    products: [
      {
        brand_id: null,
        style_id: null,
        size_id: null,
        color_id: null,
        element_id: null,
        num: null,
        remark: null,
        anchor_id: null,
        price: null,
        imgurl: 'http://www.baidu.com',
        position: null,
      },
    ],
  });

  const thisFormData: any = ref(defaultForm());
  const loading = ref(false);
  const visible = ref(false);
  const emits = defineEmits(['createOver']);

  // 关闭回调
  function onClose() {
    visible.value = false;
  }

  const getInfoFn = async (item: any) => {
    loading.value = true;
    request('/api/demand/info', {
      id: item.id,
    })
      .then((res) => {
        if (res.code && res.code === 200) {
          Object.assign(thisFormData.value, res.data);
        }
        loading.value = false;
      })
      .finally(() => {
        loading.value = false;
      });
  };

  // 打开抽屉
  async function show(item: any) {
    visible.value = true;
    getInfoFn(item);
  }

  defineExpose({
    show,
  });
</script>

<style lang="less" scoped>
  #FormPrint {
    padding: 10px;
    background: #fff;
    color: #000;
    table {
      border-collapse: collapse;
      width: 100%;
      font-family: Arial, sans-serif;
    }

    th,
    td {
      border: 1px solid #ddd;
      padding: 8px;
      text-align: center;
    }

    th {
      background-color: #f2f2f2;
    }

    .table-heading {
      display: none;
    }
  }
  @media print {
    #FormPrint {
      background: #fff;
      color: #000;
    }
    table {
      font-size: 12px;
    }

    .table-heading {
      display: table-row;
    }
  }

  .print-box {
    display: flex;
    justify-content: flex-end;
  }

  .text-right {
    text-align: right !important;
  }
  .table-title {
    font-size: 18px;
    margin: 10px 20px;
  }
</style>
