import html2canvas from 'html2canvas';
import JsPDF from 'jspdf';

export const htmlToPDF = async (
  htmlId: any,
  title = '报表',
  bgColor = '#fff',
  widthScreen = false
) => {
  let pdfDom: any = document.getElementById(htmlId);
  pdfDom.style.padding = '10px !important';
  let A4Width = 595.28;
  let A4Height = 841.89;
  let pdfDirection: any = 'p';
  if (widthScreen) {
    A4Width = 841.89;
    A4Height = 595.28;
    pdfDirection = 'l';
  }
  let canvas = await html2canvas(pdfDom, {
    scale: 2,
    useCORS: true,
    backgroundColor: bgColor,
  });
  let pageHeight = (canvas.width / A4Width) * A4Height;
  let leftHeight = canvas.height;
  let position = 0;
  let imgWidth = A4Width;
  let imgHeight = (A4Width / canvas.width) * canvas.height;
  /*
     根据自身业务需求  是否在此处键入下方水印代码
    */
  let pageData = canvas.toDataURL('image/jpeg', 1.0);
  let PDF = new JsPDF(pdfDirection, 'pt', 'a4');
  if (leftHeight < pageHeight) {
    PDF.addImage(pageData, 'JPEG', 0, 0, imgWidth, imgHeight);
  } else {
    // while (leftHeight > 0) {
    //   PDF.addImage(pageData, 'JPEG', 0, position, imgWidth, imgHeight);
    //   leftHeight -= pageHeight;
    //   position -= A4Height;
    //   if (leftHeight > 0) PDF.addPage();
    // }
    let currentPage = 1;
    while (leftHeight > 0) {
      if (currentPage > 1) {
        PDF.addPage();
        position -= A4Height;

        // 调整内容向下移动的位置，避免截断
        PDF.setPage(currentPage);
        PDF.addImage(pageData, 'JPEG', 0, position, imgWidth, imgHeight);
      } else {
        PDF.addImage(pageData, 'JPEG', 0, position, imgWidth, imgHeight);
      }

      leftHeight -= pageHeight;
      currentPage += 1;
    }
  }
  PDF.save(`${title}.pdf`);
};
