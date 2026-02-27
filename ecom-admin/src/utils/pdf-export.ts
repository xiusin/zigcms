import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';

export interface PDFOptions {
  filename?: string;
  title?: string;
  orientation?: 'portrait' | 'landscape';
  format?: 'a4' | 'letter';
}

export const exportPDF = {
  // 从 HTML 元素导出
  async fromElement(element: HTMLElement, options: PDFOptions = {}) {
    const canvas = await html2canvas(element, {
      scale: 2,
      useCORS: true,
      logging: false,
    });

    const imgData = canvas.toDataURL('image/png');
    const pdf = new jsPDF({
      orientation: options.orientation || 'portrait',
      unit: 'mm',
      format: options.format || 'a4',
    });

    const imgWidth = 210;
    const imgHeight = (canvas.height * imgWidth) / canvas.width;

    pdf.addImage(imgData, 'PNG', 0, 0, imgWidth, imgHeight);
    pdf.save(options.filename || 'export.pdf');
  },

  // 从表格数据导出
  fromTable(columns: any[], data: any[], options: PDFOptions = {}) {
    const pdf = new jsPDF({
      orientation: options.orientation || 'landscape',
      unit: 'mm',
      format: options.format || 'a4',
    });

    // 添加标题
    if (options.title) {
      pdf.setFontSize(16);
      pdf.text(options.title, 14, 15);
    }

    // 简化版表格（实际项目建议使用 jspdf-autotable）
    let y = options.title ? 25 : 15;
    pdf.setFontSize(10);

    // 表头
    columns.forEach((col, i) => {
      pdf.text(col.title, 14 + i * 40, y);
    });

    y += 7;

    // 数据行
    data.forEach((row) => {
      columns.forEach((col, i) => {
        const value = String(row[col.dataIndex] || '');
        pdf.text(value.substring(0, 20), 14 + i * 40, y);
      });
      y += 7;
      if (y > 190) {
        pdf.addPage();
        y = 15;
      }
    });

    pdf.save(options.filename || 'table.pdf');
  },
};
