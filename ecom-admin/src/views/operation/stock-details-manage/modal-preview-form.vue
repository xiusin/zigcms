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
      <a-button size="small" @click="() => htmlToPDF('FormPrintReturn', 'test pdf')">
        <template #icon>
          <icon-printer />
        </template>
        导出</a-button
      >
    </div> -->
    <a-spin :loading="loading" style="width: 100%">
      <div id="FormPrintReturn">
        <table>
          <tr>
            <th colspan="11">
              <div class="table-title"> 提交返货单 </div>
            </th>
          </tr>
          <template v-for="(item, index) in thisFormData" :key="index">
            <tr>
              <th colspan="1">返货单({{ index + 1 }})</th>
              <th colspan="1">供应商</th>
              <th colspan="2">{{ item.supplier_name }}</th>
              <th colspan="1">供应商地址</th>
              <th colspan="2">{{ item.address }}</th>
              <th colspan="1">供应商联系人</th>
              <th colspan="1">{{ item.person }}</th>
              <th colspan="1">供应商联系电话</th>
              <th colspan="1">{{ item.mobile }}</th>
            </tr>
            <tr>
              <th colspan="1">商品ID</th>
              <th colspan="1">品牌</th>
              <th colspan="2">系列名称</th>
              <th colspan="1">商品规格</th>
              <th colspan="2">颜色</th>
              <th colspan="1">材质</th>
              <th colspan="1">备注</th>
              <th colspan="1">附件</th>
              <th colspan="1">提货价</th>
            </tr>

            <tr
              v-for="(products, indexproducts) in item.goods"
              :key="indexproducts"
            >
              <td colspan="1">{{ products.product_no || '-' }}</td>
              <td colspan="1">{{ products.brand_name }}</td>
              <td colspan="2">{{ products.style_name }}</td>
              <td colspan="1">{{ products.size_name }}</td>
              <td colspan="2">{{ products.color_name }}</td>
              <td colspan="1">{{ products.element_name }}</td>
              <td colspan="1">{{ products.remark }}</td>
              <td colspan="1">{{ products.accessories.join() }}</td>
              <td colspan="1">{{ products.in_warehouse_price }}</td>
            </tr>
            <tr v-if="index < thisFormData.length - 1">
              <td colspan="11"><br /></td>
            </tr>
          </template>
        </table>

        <div class="commit-buf">
          <a-button size="small" type="primary" @click="refundSubmit">
            提交返货单
          </a-button>
        </div>
      </div>
    </a-spin>
  </a-modal>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref } from 'vue';
  import request from '@/api/request';
  import { useRoute, useRouter } from 'vue-router';
  import { htmlToPDF } from '@/utils/html2pdf';
  import { Message } from '@arco-design/web-vue';

  const defaultForm = () => [
    {
      address: '',
      goods: [],
      mobile: '',
      person: '',
      supplier_id: 0,
      supplier_name: '',
    },
  ];

  const thisFormData: any = ref(defaultForm());
  const loading = ref(false);
  const visible = ref(false);

  // 关闭回调
  function onClose() {
    visible.value = false;
  }

  const emit = defineEmits(['submitSuccess']);
  const refundSubmit = async () => {
    loading.value = true;
    request('/api/refund/submit', {
      tables: unref(thisFormData),
    })
      .then((res) => {
        if (res.code && res.code === 200) {
          Message.success('操作成功');
          emit('submitSuccess');
          onClose();
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
    thisFormData.value = item;
  }

  defineExpose({
    show,
  });
</script>

<style lang="less" scoped>
  #FormPrintReturn {
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
  .commit-buf {
    padding-top: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>
