<template>
  <a-modal
    :hide-title="true"
    :visible="visible"
    :footer="false"
    width="1060px"
    :loading="loading"
    @cancel="onClose"
  >
    <!-- <div class="print-box">
      <a-button size="small" @click="() => htmlToPDF('FormPrintBill', 'test pdf')">
        <template #icon>
          <icon-printer />
        </template>
        导出</a-button
      >
    </div> -->
    <a-spin :loading="loading" style="width: 100%">
      <div id="FormPrintBill">
        <table>
          <tr>
            <th colspan="11">
              <div class="table-title"> 提货单 </div>
            </th>
          </tr>
          <tr>
            <th colspan="1">提货表编码</th>
            <th colspan="4">{{ thisFormData.pickup_no || '-' }}</th>
            <th colspan="1">货盘期号</th>
            <th colspan="5">{{ thisFormData.demand_no }}</th>
          </tr>
          <tr>
            <th colspan="1">供应商</th>
            <th colspan="4">{{ thisFormData.supplier_name }}</th>
            <th colspan="1">供应商地点</th>
            <th colspan="5">{{ thisFormData.supplier_address }}</th>
          </tr>
          <tr>
            <th colspan="1">供应商联系人</th>
            <th colspan="4">{{ thisFormData.supplier_person }}</th>
            <th colspan="1">供应商电话</th>
            <th colspan="5">{{ thisFormData.supplier_mobile }}</th>
          </tr>
          <tr>
            <th colspan="1">提货单位</th>
            <th colspan="1">鹏景</th>
            <th colspan="1">提货人</th>
            <th colspan="2">{{ thisFormData.receiver_name }}</th>
            <th colspan="1">提货人电话</th>
            <th colspan="2">{{ thisFormData.receiver_mobile }}</th>
            <th colspan="1">提货时间</th>
            <th colspan="3">{{ thisFormData.pickup_time }}</th>
          </tr>

          <tr>
            <th colspan="1">商品ID</th>
            <th colspan="1">品牌</th>
            <th colspan="1">系列名称</th>
            <th colspan="1">商品规格</th>
            <th colspan="1">颜色</th>
            <th colspan="1">材质</th>
            <th colspan="1">成色</th>
            <th colspan="1">附件</th>
            <th colspan="1">瑕疵说明</th>
            <th colspan="1">备注</th>
            <th colspan="1">提货价</th>
          </tr>
          <tr v-for="(item, index) in thisFormData.products" :key="index">
            <td>{{ item.product_no || '-' }}</td>
            <td>{{ item.brand_name }}</td>
            <td>{{ item.style_name }}</td>
            <td>{{ item.size_name }}</td>
            <td>{{ item.color_name }}</td>
            <td>{{ item.element_name }}</td>
            <td></td>
            <td></td>
            <td></td>
            <td>{{ item.remark }}</td>
            <td></td>
          </tr>
          <tr>
            <th colspan="2">供应商签字</th>
            <th colspan="3"></th>
            <th colspan="2">提货人签字</th>
            <th colspan="5"></th>
          </tr>
          <tr>
            <td colspan="11" class="text-right">
              <div> 数量：{{ thisFormData.products.length }} </div>
              提交时间：{{ thisFormData.created_at }}
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
    demand_id: null,
    demand_no: null,
    company_id: null,
    supplier_id: null,
    receive_user_id: null,
    pickup_time: null,
    created_at: null,
    updated_at: null,
    products: [],
    receiver_name: null,
    receiver_mobile: null,
    supplier_name: null,
    supplier_mobile: null,
    supplier_address: null,
    supplier_person: null,
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
    Object.assign(thisFormData.value, item);
  }

  defineExpose({
    show,
  });
</script>

<style lang="less" scoped>
  #FormPrintBill {
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
