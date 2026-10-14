/**
 * 导出工具模块
 * 支持PDF、Excel、测试用例、脑图等多种格式导出
 * 【依赖】jspdf、html2canvas、xlsx（项目已安装）
 */
import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';
import * as XLSX from 'xlsx';

// ==================== 通用下载 ====================

/** 触发浏览器下载 */
export function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  console.log(`[导出工具][下载][${filename}][成功]`);
}

/** 下载文本文件 */
export function downloadText(content: string, filename: string, mimeType = 'text/plain') {
  const blob = new Blob([content], { type: `${mimeType};charset=utf-8` });
  downloadBlob(blob, filename);
}

// ==================== 水印配置 ====================

/** 水印配置接口 */
export interface WatermarkConfig {
  text?: string;
  subText?: string;
  fontSize?: number;
  color?: string;
  opacity?: number;
  angle?: number;
  gap?: number;
}

/** 默认水印配置 */
const DEFAULT_WATERMARK: WatermarkConfig = {
  text: 'ZigCMS质量中心',
  subText: '内部机密',
  fontSize: 16,
  color: '#000000',
  opacity: 0.06,
  angle: -30,
  gap: 180,
};

/** 给jsPDF添加水印 */
function addPDFWatermark(pdf: jsPDF, config?: WatermarkConfig) {
  const wm = { ...DEFAULT_WATERMARK, ...config };
  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();
  const totalPages = pdf.getNumberOfPages();

  for (let p = 1; p <= totalPages; p++) {
    pdf.setPage(p);
    pdf.saveGraphicsState();
    pdf.setFontSize(wm.fontSize!);
    pdf.setTextColor(wm.color!);
    // jsPDF setGState for opacity
    const gState = new (pdf as any).GState({ opacity: wm.opacity });
    (pdf as any).setGState(gState);

    const gap = wm.gap!;

    for (let x = -pageWidth; x < pageWidth * 2; x += gap) {
      for (let y = -pageHeight; y < pageHeight * 2; y += gap * 0.6) {
        pdf.text(wm.text!, x, y, { angle: wm.angle! });
        if (wm.subText) {
          pdf.setFontSize(wm.fontSize! * 0.7);
          pdf.text(wm.subText, x + 10, y + 12, { angle: wm.angle! });
          pdf.setFontSize(wm.fontSize!);
        }
      }
    }
    pdf.restoreGraphicsState();
  }
  console.log(`[导出工具][水印][已添加][${totalPages}页][${wm.text}]`);
}

/** 给Canvas添加水印（用于PNG导出） */
export function addCanvasWatermark(
  canvas: HTMLCanvasElement,
  config?: WatermarkConfig
): HTMLCanvasElement {
  const wm = { ...DEFAULT_WATERMARK, ...config };
  const ctx = canvas.getContext('2d');
  if (!ctx) return canvas;

  ctx.save();
  ctx.globalAlpha = wm.opacity! * 2;
  ctx.font = `${wm.fontSize! * 2}px Arial, sans-serif`;
  ctx.fillStyle = wm.color!;
  const gap = wm.gap! * 2;

  for (let x = -canvas.width; x < canvas.width * 2; x += gap) {
    for (let y = -canvas.height; y < canvas.height * 2; y += gap * 0.6) {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate((wm.angle! * Math.PI) / 180);
      ctx.fillText(wm.text!, 0, 0);
      if (wm.subText) {
        ctx.font = `${wm.fontSize! * 1.4}px Arial, sans-serif`;
        ctx.fillText(wm.subText, 20, 24);
        ctx.font = `${wm.fontSize! * 2}px Arial, sans-serif`;
      }
      ctx.restore();
    }
  }
  ctx.restore();
  console.log(`[导出工具][Canvas水印][已添加][${wm.text}]`);
  return canvas;
}

// ==================== PDF 导出 ====================

/** 将DOM元素导出为PDF */
export async function exportElementToPDF(
  element: HTMLElement,
  filename: string,
  options?: {
    title?: string;
    orientation?: 'portrait' | 'landscape';
    scale?: number;
    watermark?: WatermarkConfig | boolean;
  }
) {
  const { title, orientation = 'portrait', scale = 2, watermark } = options || {};

  console.log(`[导出工具][PDF导出][开始][${filename}]`);

  const canvas = await html2canvas(element, {
    scale,
    useCORS: true,
    logging: false,
    backgroundColor: '#ffffff',
  });

  const imgData = canvas.toDataURL('image/png');
  const pdf = new jsPDF({
    orientation,
    unit: 'mm',
    format: 'a4',
  });

  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();
  const imgWidth = pageWidth - 20;
  const imgHeight = (canvas.height * imgWidth) / canvas.width;

  // 添加标题
  if (title) {
    pdf.setFontSize(16);
    pdf.text(title, pageWidth / 2, 15, { align: 'center' });
  }

  const startY = title ? 25 : 10;
  let currentY = startY;

  // 分页处理
  if (imgHeight + startY <= pageHeight - 10) {
    pdf.addImage(imgData, 'PNG', 10, currentY, imgWidth, imgHeight);
  } else {
    let remainingHeight = imgHeight;
    let sourceY = 0;

    while (remainingHeight > 0) {
      const availableHeight = currentY === startY ? pageHeight - startY - 10 : pageHeight - 20;
      const sliceHeight = Math.min(remainingHeight, availableHeight);
      const sliceRatio = sliceHeight / imgHeight;

      const sliceCanvas = document.createElement('canvas');
      sliceCanvas.width = canvas.width;
      sliceCanvas.height = canvas.height * sliceRatio;
      const ctx = sliceCanvas.getContext('2d');
      if (ctx) {
        ctx.drawImage(
          canvas,
          0, sourceY * (canvas.height / imgHeight),
          canvas.width, canvas.height * sliceRatio,
          0, 0,
          sliceCanvas.width, sliceCanvas.height
        );
        const sliceData = sliceCanvas.toDataURL('image/png');
        pdf.addImage(sliceData, 'PNG', 10, currentY, imgWidth, sliceHeight);
      }

      remainingHeight -= sliceHeight;
      sourceY += sliceHeight;

      if (remainingHeight > 0) {
        pdf.addPage();
        currentY = 10;
      }
    }
  }

  // 添加页脚
  const totalPages = pdf.getNumberOfPages();
  for (let i = 1; i <= totalPages; i++) {
    pdf.setPage(i);
    pdf.setFontSize(8);
    pdf.setTextColor(150);
    pdf.text(
      `第 ${i} / ${totalPages} 页  |  生成时间: ${new Date().toLocaleString()}`,
      pageWidth / 2,
      pageHeight - 5,
      { align: 'center' }
    );
  }

  // 添加水印
  if (watermark !== false) {
    const wmConfig = typeof watermark === 'object' ? watermark : undefined;
    addPDFWatermark(pdf, wmConfig);
  }

  pdf.save(filename);
  console.log(`[导出工具][PDF导出][完成][${filename}][${totalPages}页]`);
}

/** 将数据直接导出为PDF表格 */
export function exportDataToPDF(
  data: Record<string, unknown>[],
  columns: { title: string; dataIndex: string; width?: number }[],
  filename: string,
  options?: { title?: string; orientation?: 'portrait' | 'landscape' }
) {
  const { title, orientation = 'landscape' } = options || {};
  const pdf = new jsPDF({ orientation, unit: 'mm', format: 'a4' });
  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();

  let y = 10;

  // 标题
  if (title) {
    pdf.setFontSize(16);
    pdf.text(title, pageWidth / 2, y + 5, { align: 'center' });
    y += 15;
  }

  // 表头
  const colWidth = (pageWidth - 20) / columns.length;
  pdf.setFontSize(9);
  pdf.setFillColor(240, 240, 240);
  pdf.rect(10, y, pageWidth - 20, 8, 'F');
  pdf.setTextColor(50);
  columns.forEach((col, i) => {
    pdf.text(col.title, 12 + i * colWidth, y + 5.5);
  });
  y += 10;

  // 数据行
  pdf.setTextColor(80);
  pdf.setFontSize(8);
  data.forEach((row) => {
    if (y > pageHeight - 15) {
      pdf.addPage();
      y = 10;
    }
    columns.forEach((col, i) => {
      const val = String(row[col.dataIndex] ?? '');
      const truncated = val.length > 30 ? `${val.slice(0, 30)}...` : val;
      pdf.text(truncated, 12 + i * colWidth, y + 4);
    });
    // 行分隔线
    pdf.setDrawColor(230);
    pdf.line(10, y + 6, pageWidth - 10, y + 6);
    y += 8;
  });

  // 页脚
  const totalPages = pdf.getNumberOfPages();
  for (let i = 1; i <= totalPages; i++) {
    pdf.setPage(i);
    pdf.setFontSize(8);
    pdf.setTextColor(150);
    pdf.text(
      `第 ${i} / ${totalPages} 页  |  共 ${data.length} 条记录  |  ${new Date().toLocaleString()}`,
      pageWidth / 2, pageHeight - 5, { align: 'center' }
    );
  }

  pdf.save(filename);
  console.log(`[导出工具][PDF表格导出][完成][${filename}][${data.length}条]`);
}

// ==================== Excel 导出 ====================

/** 将数据导出为Excel */
export function exportToExcel(
  data: Record<string, unknown>[],
  columns: { title: string; dataIndex: string; width?: number }[],
  filename: string,
  sheetName = 'Sheet1'
) {
  console.log(`[导出工具][Excel导出][开始][${filename}][${data.length}条]`);

  // 构建表头
  const headers = columns.map(col => col.title);

  // 构建数据行
  const rows = data.map(row =>
    columns.map(col => {
      const val = row[col.dataIndex];
      if (val === null || val === undefined) return '';
      if (typeof val === 'object') return JSON.stringify(val);
      return val;
    })
  );

  // 合并表头和数据
  const wsData = [headers, ...rows];
  const ws = XLSX.utils.aoa_to_sheet(wsData);

  // 设置列宽
  ws['!cols'] = columns.map(col => ({ wch: col.width || 20 }));

  // 创建工作簿
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheetName);

  // 导出
  XLSX.writeFile(wb, filename);
  console.log(`[导出工具][Excel导出][完成][${filename}]`);
}

/** 多Sheet导出Excel */
export function exportMultiSheetExcel(
  sheets: Array<{
    name: string;
    data: Record<string, unknown>[];
    columns: { title: string; dataIndex: string; width?: number }[];
  }>,
  filename: string
) {
  const wb = XLSX.utils.book_new();

  sheets.forEach(sheet => {
    const headers = sheet.columns.map(col => col.title);
    const rows = sheet.data.map(row =>
      sheet.columns.map(col => {
        const val = row[col.dataIndex];
        if (val === null || val === undefined) return '';
        if (typeof val === 'object') return JSON.stringify(val);
        return val;
      })
    );
    const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
    ws['!cols'] = sheet.columns.map(col => ({ wch: col.width || 20 }));
    XLSX.utils.book_append_sheet(wb, ws, sheet.name);
  });

  XLSX.writeFile(wb, filename);
  console.log(`[导出工具][多Sheet Excel导出][完成][${filename}][${sheets.length}个Sheet]`);
}

// ==================== 测试用例导出 ====================

/** 导出测试用例为Excel */
export function exportTestCases(
  cases: Array<Record<string, unknown>>,
  filename = '测试用例导出.xlsx'
) {
  const columns = [
    { title: 'ID', dataIndex: 'id', width: 8 },
    { title: '用例名称', dataIndex: 'name', width: 30 },
    { title: '描述', dataIndex: 'description', width: 40 },
    { title: '类型', dataIndex: 'type', width: 12 },
    { title: '测试类型', dataIndex: 'test_type', width: 12 },
    { title: '请求方法', dataIndex: 'method', width: 10 },
    { title: '接口地址', dataIndex: 'endpoint', width: 30 },
    { title: '期望状态码', dataIndex: 'expected_status', width: 12 },
    { title: '状态', dataIndex: 'status', width: 10 },
    { title: '来源', dataIndex: 'source', width: 12 },
    { title: 'AI生成', dataIndex: 'generated_by_ai', width: 10 },
    { title: '执行次数', dataIndex: 'run_count', width: 10 },
    { title: '通过次数', dataIndex: 'pass_count', width: 10 },
    { title: '失败次数', dataIndex: 'fail_count', width: 10 },
    { title: '创建时间', dataIndex: 'created_at', width: 20 },
  ];

  exportToExcel(cases, columns, filename, '测试用例');
}

/** 导出测试用例为JSON（可导入） */
export function exportTestCasesJSON(
  cases: Array<Record<string, unknown>>,
  filename = '测试用例导出.json'
) {
  const content = JSON.stringify(cases, null, 2);
  downloadText(content, filename, 'application/json');
}

// ==================== 脑图导出 ====================

/** 脑图节点接口 */
interface MindMapNode {
  label: string;
  children?: MindMapNode[];
  color?: string;
}

/** 生成脑图SVG */
export function generateMindMapSVG(root: MindMapNode): string {
  const svgWidth = 1200;
  const svgHeight = 800;
  const nodeHeight = 36;
  const nodeGap = 12;
  const levelGap = 200;

  // 计算节点总数和每层的高度
  function countLeaves(node: MindMapNode): number {
    if (!node.children || node.children.length === 0) return 1;
    return node.children.reduce((sum, c) => sum + countLeaves(c), 0);
  }

  // 布局计算
  interface LayoutNode {
    label: string;
    x: number;
    y: number;
    width: number;
    height: number;
    color: string;
    children: LayoutNode[];
  }

  function layout(
    node: MindMapNode,
    level: number,
    startY: number,
    parentColor?: string
  ): LayoutNode {
    const leaves = countLeaves(node);
    const totalHeight = leaves * (nodeHeight + nodeGap) - nodeGap;
    const x = 40 + level * levelGap;
    const width = Math.max(80, node.label.length * 14 + 24);
    const colors = ['#165DFF', '#00B42A', '#F53F3F', '#FF7D00', '#722ED1', '#0FC6C2', '#F7BA1E'];
    const color = node.color || parentColor || colors[level % colors.length];

    const layoutChildren: LayoutNode[] = [];
    let childY = startY;
    if (node.children) {
      for (const child of node.children) {
        const childLeaves = countLeaves(child);
        const childHeight = childLeaves * (nodeHeight + nodeGap) - nodeGap;
        layoutChildren.push(layout(child, level + 1, childY, color));
        childY += childHeight + nodeGap;
      }
    }

    const y = layoutChildren.length > 0
      ? (layoutChildren[0].y + layoutChildren[layoutChildren.length - 1].y) / 2
      : startY + totalHeight / 2 - nodeHeight / 2;

    return { label: node.label, x, y, width, height: nodeHeight, color, children: layoutChildren };
  }

  const totalLeaves = countLeaves(root);
  const totalHeight = totalLeaves * (nodeHeight + nodeGap);
  const actualHeight = Math.max(svgHeight, totalHeight + 40);
  const layoutRoot = layout(root, 0, 20);

  // 渲染SVG
  let paths = '';
  let nodes = '';

  function render(node: LayoutNode) {
    const rx = 8;
    const isRoot = node.x < 100;
    const fontSize = isRoot ? 16 : 13;
    const fontWeight = isRoot ? 'bold' : 'normal';
    const fill = isRoot ? node.color : '#ffffff';
    const textColor = isRoot ? '#ffffff' : node.color;
    const strokeColor = node.color;

    // 节点矩形
    nodes += `<rect x="${node.x}" y="${node.y}" width="${node.width}" height="${node.height}" rx="${rx}" ry="${rx}" fill="${fill}" stroke="${strokeColor}" stroke-width="2" />`;
    // 节点文本
    nodes += `<text x="${node.x + node.width / 2}" y="${node.y + node.height / 2 + 5}" text-anchor="middle" fill="${textColor}" font-size="${fontSize}" font-weight="${fontWeight}" font-family="Arial, sans-serif">${escapeXml(node.label)}</text>`;

    // 连接线
    for (const child of node.children) {
      const x1 = node.x + node.width;
      const y1 = node.y + node.height / 2;
      const x2 = child.x;
      const y2 = child.y + child.height / 2;
      const cx1 = x1 + (x2 - x1) * 0.4;
      const cx2 = x2 - (x2 - x1) * 0.4;
      paths += `<path d="M${x1},${y1} C${cx1},${y1} ${cx2},${y2} ${x2},${y2}" fill="none" stroke="${child.color}" stroke-width="2" opacity="0.6" />`;
      render(child);
    }
  }

  render(layoutRoot);

  // 计算实际宽度
  function maxX(node: LayoutNode): number {
    let mx = node.x + node.width;
    for (const c of node.children) {
      mx = Math.max(mx, maxX(c));
    }
    return mx;
  }
  const actualWidth = Math.max(svgWidth, maxX(layoutRoot) + 40);

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${actualWidth} ${actualHeight}" width="${actualWidth}" height="${actualHeight}" style="background:#ffffff">
  <defs>
    <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">
      <feDropShadow dx="2" dy="2" stdDeviation="3" flood-opacity="0.15" />
    </filter>
  </defs>
  <g filter="url(#shadow)">
    ${paths}
    ${nodes}
  </g>
</svg>`;
}

function escapeXml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/** 导出脑图为SVG文件 */
export function exportMindMapSVG(root: MindMapNode, filename = '测试脑图.svg') {
  const svg = generateMindMapSVG(root);
  downloadText(svg, filename, 'image/svg+xml');
  console.log(`[导出工具][脑图SVG导出][完成][${filename}]`);
}

/** 导出脑图为PNG（支持水印） */
export async function exportMindMapPNG(
  root: MindMapNode,
  filename = '测试脑图.png',
  watermark?: WatermarkConfig | boolean
) {
  const svg = generateMindMapSVG(root);
  const svgBlob = new Blob([svg], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(svgBlob);

  const img = new Image();
  img.onload = () => {
    const canvas = document.createElement('canvas');
    canvas.width = img.width * 2;
    canvas.height = img.height * 2;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.scale(2, 2);
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, img.width, img.height);
      ctx.drawImage(img, 0, 0);
      // 添加水印
      if (watermark !== false) {
        const wmConfig = typeof watermark === 'object' ? watermark : undefined;
        addCanvasWatermark(canvas, wmConfig);
      }
      canvas.toBlob((blob) => {
        if (blob) {
          downloadBlob(blob, filename);
          console.log(`[导出工具][脑图PNG导出][完成][${filename}]`);
        }
      }, 'image/png');
    }
    URL.revokeObjectURL(url);
  };
  img.src = url;
}

/** 导出脑图为PDF（支持水印） */
export async function exportMindMapPDF(
  root: MindMapNode,
  filename = '测试脑图.pdf',
  options?: {
    title?: string;
    orientation?: 'portrait' | 'landscape';
    watermark?: WatermarkConfig | boolean;
  }
) {
  const { title, orientation = 'landscape', watermark } = options || {};

  console.log(`[导出工具][脑图PDF导出][开始][${filename}]`);

  // 生成 SVG
  const svg = generateMindMapSVG(root);
  const svgBlob = new Blob([svg], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(svgBlob);

  return new Promise<void>((resolve, reject) => {
    const img = new Image();
    img.onload = async () => {
      try {
        // 创建高分辨率 Canvas
        const canvas = document.createElement('canvas');
        const scale = 2;
        canvas.width = img.width * scale;
        canvas.height = img.height * scale;
        const ctx = canvas.getContext('2d');

        if (!ctx) {
          reject(new Error('无法创建 Canvas 上下文'));
          return;
        }

        ctx.scale(scale, scale);
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, img.width, img.height);
        ctx.drawImage(img, 0, 0);

        // 添加水印到 Canvas
        if (watermark !== false) {
          const wmConfig = typeof watermark === 'object' ? watermark : undefined;
          addCanvasWatermark(canvas, wmConfig);
        }

        // 转换为图片数据
        const imgData = canvas.toDataURL('image/png');

        // 创建 PDF
        const pdf = new jsPDF({
          orientation,
          unit: 'mm',
          format: 'a4',
        });

        const pageWidth = pdf.internal.pageSize.getWidth();
        const pageHeight = pdf.internal.pageSize.getHeight();

        // 添加标题
        if (title) {
          pdf.setFontSize(16);
          pdf.text(title, pageWidth / 2, 15, { align: 'center' });
        }

        const startY = title ? 25 : 10;
        const imgWidth = pageWidth - 20;
        const imgHeight = (canvas.height * imgWidth) / canvas.width;

        // 分页处理
        if (imgHeight + startY <= pageHeight - 10) {
          // 单页
          pdf.addImage(imgData, 'PNG', 10, startY, imgWidth, imgHeight);
        } else {
          // 多页
          let remainingHeight = imgHeight;
          let sourceY = 0;
          let currentY = startY;

          while (remainingHeight > 0) {
            const availableHeight = currentY === startY ? pageHeight - startY - 10 : pageHeight - 20;
            const sliceHeight = Math.min(remainingHeight, availableHeight);
            const sliceRatio = sliceHeight / imgHeight;

            const sliceCanvas = document.createElement('canvas');
            sliceCanvas.width = canvas.width;
            sliceCanvas.height = canvas.height * sliceRatio;
            const sliceCtx = sliceCanvas.getContext('2d');

            if (sliceCtx) {
              sliceCtx.drawImage(
                canvas,
                0, sourceY * (canvas.height / imgHeight),
                canvas.width, canvas.height * sliceRatio,
                0, 0,
                sliceCanvas.width, sliceCanvas.height
              );
              const sliceData = sliceCanvas.toDataURL('image/png');
              pdf.addImage(sliceData, 'PNG', 10, currentY, imgWidth, sliceHeight);
            }

            remainingHeight -= sliceHeight;
            sourceY += sliceHeight;

            if (remainingHeight > 0) {
              pdf.addPage();
              currentY = 10;
            }
          }
        }

        // 添加页脚
        const totalPages = pdf.getNumberOfPages();
        for (let i = 1; i <= totalPages; i++) {
          pdf.setPage(i);
          pdf.setFontSize(8);
          pdf.setTextColor(150);
          pdf.text(
            `第 ${i} / ${totalPages} 页  |  生成时间: ${new Date().toLocaleString()}`,
            pageWidth / 2,
            pageHeight - 5,
            { align: 'center' }
          );
        }

        // 保存 PDF
        pdf.save(filename);
        console.log(`[导出工具][脑图PDF导出][完成][${filename}][${totalPages}页]`);

        URL.revokeObjectURL(url);
        resolve();
      } catch (error) {
        console.error('[导出工具][脑图PDF导出][失败]', error);
        reject(error);
      }
    };

    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('图片加载失败'));
    };

    img.src = url;
  });
}

/** 从测试用例数据生成脑图树结构 */
export function buildTestCaseMindMap(
  cases: Array<Record<string, unknown>>,
  rootLabel = '测试用例'
): MindMapNode {
  // 按模块和类型分组
  const moduleMap = new Map<string, Map<string, Array<Record<string, unknown>>>>();

  cases.forEach(c => {
    const moduleName = String(c.module_name || c.module_id || '未分类');
    const testType = String(c.test_type || c.type || '未分类');

    if (!moduleMap.has(moduleName)) {
      moduleMap.set(moduleName, new Map());
    }
    const typeMap = moduleMap.get(moduleName)!;
    if (!typeMap.has(testType)) {
      typeMap.set(testType, []);
    }
    typeMap.get(testType)!.push(c);
  });

  const children: MindMapNode[] = [];
  moduleMap.forEach((typeMap, moduleName) => {
    const typeChildren: MindMapNode[] = [];
    typeMap.forEach((caseList, typeName) => {
      typeChildren.push({
        label: `${typeName} (${caseList.length})`,
        children: caseList.map(c => ({
          label: String(c.name || c.id || ''),
        })),
      });
    });
    children.push({
      label: `${moduleName} (${typeChildren.reduce((s, t) => s + (t.children?.length || 0), 0)})`,
      children: typeChildren,
    });
  });

  return { label: rootLabel, children };
}

/** 从质量数据生成模块质量脑图 */
export function buildQualityMindMap(
  modules: Array<{
    module_name: string;
    pass_rate: number;
    bug_count: number;
    case_count: number;
    feedback_count: number;
  }>,
  rootLabel = '质量中心'
): MindMapNode {
  return {
    label: rootLabel,
    children: modules.map(m => ({
      label: m.module_name,
      color: m.pass_rate >= 90 ? '#00B42A' : m.pass_rate >= 70 ? '#FF7D00' : '#F53F3F',
      children: [
        { label: `通过率: ${m.pass_rate}%` },
        { label: `Bug: ${m.bug_count}个` },
        { label: `用例: ${m.case_count}个` },
        { label: `反馈: ${m.feedback_count}个` },
      ],
    })),
  };
}

/** 从Bug关联数据生成Bug关联脑图 */
export function buildBugLinkMindMap(
  bugs: Array<{
    id: number;
    title: string;
    severity: string;
    module: string;
    related_cases?: Array<{ id: number; name: string }>;
    related_feedbacks?: Array<{ id: number; title: string }>;
  }>,
  rootLabel = 'Bug关联分析'
): MindMapNode {
  const severityColor: Record<string, string> = {
    critical: '#F53F3F', high: '#FF7D00', medium: '#F7BA1E', low: '#00B42A',
  };
  return {
    label: rootLabel,
    children: bugs.map(bug => ({
      label: `#${bug.id} ${bug.title}`,
      color: severityColor[bug.severity] || '#86909C',
      children: [
        { label: `模块: ${bug.module}` },
        { label: `严重度: ${bug.severity}` },
        ...(bug.related_cases?.length ? [{
          label: `关联用例 (${bug.related_cases.length})`,
          color: '#165DFF',
          children: bug.related_cases.map(c => ({ label: `#${c.id} ${c.name}` })),
        }] : []),
        ...(bug.related_feedbacks?.length ? [{
          label: `关联反馈 (${bug.related_feedbacks.length})`,
          color: '#FF7D00',
          children: bug.related_feedbacks.map(f => ({ label: `#${f.id} ${f.title}` })),
        }] : []),
      ],
    })),
  };
}

/** 从反馈数据生成反馈分类脑图 */
export function buildFeedbackMindMap(
  feedbacks: Array<{
    id: number;
    title: string;
    type: string;
    type_name: string;
    status: number;
    status_name: string;
    priority: string;
    module?: string;
  }>,
  rootLabel = '反馈分类'
): MindMapNode {
  // 按类型分组
  const typeMap = new Map<string, typeof feedbacks>();
  feedbacks.forEach(f => {
    const key = f.type_name || f.type;
    if (!typeMap.has(key)) typeMap.set(key, []);
    typeMap.get(key)!.push(f);
  });

  const typeColors: Record<string, string> = {
    bug: '#F53F3F', feature: '#165DFF', improvement: '#00B42A',
    question: '#722ED1', other: '#86909C',
  };
  const statusColors: Record<number, string> = {
    0: '#FF7D00', 1: '#165DFF', 2: '#00B42A', 3: '#86909C', 4: '#F53F3F',
  };

  const children: MindMapNode[] = [];
  typeMap.forEach((list, typeName) => {
    // 每种类型按状态再分
    const statusMap = new Map<string, typeof list>();
    list.forEach(f => {
      const sKey = f.status_name;
      if (!statusMap.has(sKey)) statusMap.set(sKey, []);
      statusMap.get(sKey)!.push(f);
    });

    const statusChildren: MindMapNode[] = [];
    statusMap.forEach((sList, sName) => {
      statusChildren.push({
        label: `${sName} (${sList.length})`,
        color: statusColors[sList[0]?.status] || '#86909C',
        children: sList.slice(0, 8).map(f => ({
          label: `#${f.id} ${f.title}`,
        })),
      });
    });

    children.push({
      label: `${typeName} (${list.length})`,
      color: typeColors[list[0]?.type] || '#165DFF',
      children: statusChildren,
    });
  });

  return { label: rootLabel, children };
}
