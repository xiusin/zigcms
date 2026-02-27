<template>
  <a-modal
    :hide-title="true"
    :visible="visible"
    :footer="false"
    width="1060px"
    :loading="loading"
    @cancel="onClose"
  >
    <div class="print-box">
      <a-button
        size="small"
        @click="
          () =>
            htmlToPDF(
              'product-profile-form',
              `商品档案${thisFormData.product_no}-${dayjs().format(
                'YYYY-MM-DD-HH-mm-ss'
              )}`,
              '#fff',
              true
            )
        "
      >
        <template #icon>
          <icon-printer />
        </template>
        导出</a-button
      >
    </div>
    <a-spin :loading="loading" style="width: 100%">
      <div id="product-profile-form">
        <table>
          <tr>
            <th colspan="13">
              <div class="table-title"> 商品档案 </div>
            </th>
          </tr>
          <tr>
            <td colspan="1" style="width: 8%; font-weight: 600">品牌</td>
            <td colspan="2" style="width: 14%">{{
              thisFormData.brand_name
            }}</td>
            <td colspan="1" style="width: 8%; font-weight: 600">系列名称</td>
            <td colspan="1" style="width: 8%">{{ thisFormData.style_name }}</td>
            <td colspan="1" style="width: 5%; font-weight: 600">名称</td>
            <td colspan="1" style="width: 7%">{{
              thisFormData.product_name || '-'
            }}</td>
            <td colspan="1" style="width: 8%; font-weight: 600">材质</td>
            <td colspan="1">{{ thisFormData.element_name }}</td>
            <td colspan="1" style="font-weight: 600">成色</td>
            <td colspan="1">{{ thisFormData.quality_name }}</td>
            <td colspan="1" style="font-weight: 600">规格</td>
            <td colspan="1">{{ thisFormData.size_name }}</td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">商品ID</td>
            <td colspan="2">{{ thisFormData.product_no }}</td>
            <td colspan="1" style="font-weight: 600">公价</td>
            <td colspan="1">{{ thisFormData.public_price }}</td>
            <td colspan="1" style="font-weight: 600">售价</td>
            <td colspan="1">{{ thisFormData.price }}</td>
            <td colspan="1" style="font-weight: 600">最高售价</td>
            <td colspan="2"></td>
            <td colspan="1" style="font-weight: 600">生产年份</td>
            <td colspan="2">{{ thisFormData.product_at }}</td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">尺寸</td>
            <td colspan="3">{{ thisFormData.dimension }}</td>
            <td colspan="1" style="font-weight: 600">供应商</td>
            <td colspan="2">{{ thisFormData.supplier_name }}</td>
            <td colspan="1" style="font-weight: 600">推荐等级</td>
            <td colspan="2"></td>
            <td colspan="1" style="font-weight: 600">保值率</td>
            <td colspan="2"></td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">品牌历史</td>
            <td colspan="9">{{ thisFormData.brand_data }}</td>
            <td colspan="3" rowspan="8">
              <a-image
                width="200"
                :src="`${
                  thisFormData?.main_imgurl ||
                  (thisFormData.image_urls && thisFormData.image_urls[0]?.url)
                }?x-oss-process=image/auto-orient,1/resize,p_50/quality,q_90`"
                :preview="true"
                show-loader
              ></a-image>
            </td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">系列历史</td>
            <td colspan="9">{{ thisFormData.style_data?.style_history }}</td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">设计师&主要卖点</td>
            <td colspan="9">{{ thisFormData.style_data?.selling_point }}</td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">明星同款</td>
            <td colspan="9">{{ thisFormData.style_data?.same_style }}</td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">瑕疵点</td>
            <td colspan="9">{{ thisFormData.flaw_remark }}</td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">适用人群</td>
            <td colspan="9">{{ thisFormData.style_data?.trial_population }}</td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">使用场景</td>
            <td colspan="9">{{ thisFormData.style_data?.usage_scenario }}</td>
          </tr>
          <tr>
            <td colspan="1" style="font-weight: 600">附件</td>
            <td colspan="9">{{
              `${thisFormData.accessories?.join()}${
                (thisFormData.accessories_instruction &&
                  `;${thisFormData.accessories_instruction}`) ||
                ''
              }`
            }}</td>
          </tr>
        </table>
      </div>
    </a-spin>
  </a-modal>
</template>

<script lang="ts" setup>
  import { onMounted, ref, nextTick } from 'vue';
  import request from '@/api/request';
  import { useRoute, useRouter } from 'vue-router';
  // import { htmlToPDF } from '@/utils/html2pdf';
  import { htmlToPDF } from '@/utils/html2pdf1';
  import { Message } from '@arco-design/web-vue';
  import dayjs from 'dayjs';

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

  // 查询详情
  const getInfoFn = async () => {
    loading.value = true;
    request('/api/warehouse/product/info', {
      id: thisFormData.value.id,
    }).then((res: any) => {
      if (res.code && res.code === 200) {
        thisFormData.value = res.data;
        visible.value = true;

        // nextTick(() => {
        //   setTimeout(() => {
        //     htmlToPDF(
        //       'product-profile-form',
        //       `提货单-${dayjs().format('YYYY-MM-DD-HH-mm-ss')}`,
        //       '#fff',
        //       true
        //     );
        //   }, 200);
        // });
      }
      loading.value = false;
    });
  };

  // 打开抽屉
  async function show(item: any) {
    thisFormData.value = item;
    console.log(item);
    getInfoFn();
  }

  defineExpose({
    show,
  });
</script>

<style lang="less" scoped>
  #product-profile-form {
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
