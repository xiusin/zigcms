/* eslint-disable no-shadow */
/* eslint-disable no-plusplus */
/* eslint-disable new-cap */
/* eslint-disable no-underscore-dangle */
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';
import { ref, nextTick } from 'vue';

/**
 * dom 是否渲染
 * 导出时会改变页面布局,故导出完毕需要重新渲染 dom
 */
const showDom = ref<boolean>(true);
/**
 * 导出 PDF
 */
export async function htmlToPDF(
  id: any,
  title = '报表',
  bgColor = '#fff',
  widthScreen = false
) {
  let A4_WIDTH = 592.28;
  let A4_HEIGHT = 841.89;
  let pdfDirection: any = 'p';
  if (widthScreen) {
    A4_WIDTH = 841.89;
    A4_HEIGHT = 595.28;
    pdfDirection = 'l';
  }

  // 获取需要导出的节点dom
  const printDom: any = document.getElementById(id);

  // 获取目标元素的高度(去除滚动条时高度)
  const domScrollHeight = printDom.scrollHeight;
  const domScrollWidth = printDom.scrollWidth;

  // 根据 A4 的宽高计算 dom 页面一页应该对应的高度
  const pageHeight = (printDom.offsetWidth / A4_WIDTH) * A4_HEIGHT;

  // 将所有不允许被截断的元素进行处理
  const wholeNodes: any = document.querySelectorAll('.whole-node');

  // 添加空白块的总高度
  let allEmptyNodeHeight = 0;

  for (let i = 0; i < wholeNodes.length; i++) {
    // 判断当前的不可分页元素是否在两页显示
    const topPageNum = Math.ceil(wholeNodes[i].offsetTop / pageHeight);
    const bottomPageNum = Math.ceil(
      (wholeNodes[i].offsetTop + wholeNodes[i].offsetHeight) / pageHeight
    );

    // 说明该 dom 会被截断
    if (topPageNum !== bottomPageNum) {
      // 插入空白块使被截断元素下移
      const divParent = wholeNodes[i].parentNode;
      const newBlock = document.createElement('div');
      newBlock.className = 'empty-node';
      newBlock.style.background = '#fff';

      // 计算插入空白块的高度，可以适当留出空间使得内容不会太靠边，根据自己需求而定
      const _H = topPageNum * pageHeight - wholeNodes[i].offsetTop;
      newBlock.style.height = `${_H + 20}px`;
      divParent.insertBefore(newBlock, wholeNodes[i]);

      // 更新插入空白块的总高度
      allEmptyNodeHeight = allEmptyNodeHeight + _H + 20;
    }
  }

  // 设置打印区域的高度 (目标元素的高度 + 添加的空白块的高度)
  printDom.setAttribute(
    'style',
    `height: ${
      domScrollHeight + allEmptyNodeHeight
    }px; width: ${domScrollWidth}px;`
  );

  // 以上完成 dom 层面的分页，可以转为图片进一步处理了
  html2canvas(printDom, {
    height: printDom.offsetHeight,
    width: printDom.offsetWidth,
    allowTaint: false,
    useCORS: true,
    scale: 3,
  }).then((canvas) => {
    // dom 已经转换为 canvas 对象，可以将插入的空白块删除了
    const emptyNodes: any = document.querySelectorAll('.empty-node');
    for (let i = 0; i < emptyNodes.length; i++) {
      emptyNodes[i].style.height = 0;
      emptyNodes[i].parentNode.removeChild(emptyNodes[i]);
    }

    const contentWidth = canvas.width;
    const contentHeight = canvas.height;

    // 生成 pdf 的页面高度;
    const pageHeight = (contentWidth / A4_WIDTH) * A4_HEIGHT;

    // html 页面实际高度
    let htmlHeight = contentHeight;

    // 页面偏移量
    let position = 0;

    // html 页面生成的 canvas 在 pdf 中图片的宽高
    const imgWidth = A4_WIDTH;
    const imgHeight = (A4_WIDTH / contentWidth) * contentHeight;

    // 将图片转为 base64 格式
    const pageData = canvas.toDataURL('image/jpeg', 1.0);

    // 计算分页的 pdf
    const PDF = new jsPDF(pdfDirection, 'pt', 'a4');

    // html 页面的实际高度小于生成 pdf 的页面高度时，即内容未超过 pdf 一页显示的范围，无需分页
    if (htmlHeight <= pageHeight) {
      PDF.addImage(pageData, 'JPEG', 0, 0, imgWidth, imgHeight);
    } else {
      while (htmlHeight > 0) {
        PDF.addImage(pageData, 'JPEG', 0, position, imgWidth, imgHeight);
        htmlHeight -= pageHeight;
        position -= A4_HEIGHT;
        if (htmlHeight > 0) {
          PDF.addPage();
        }
      }
    }

    PDF.save(`${title}.pdf`);
  });

  // 还原页面展示布局
  showDom.value = false;
  nextTick(() => {
    showDom.value = true;
  });
}
