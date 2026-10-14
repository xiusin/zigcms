/**
 * CRUD 数据导入导出（无外部依赖版本）
 * 使用浏览器原生 API 实现
 */

/* eslint-disable no-use-before-define */

import { Message } from '@arco-design/web-vue';
import type { FieldConfig } from './amis-crud-generator';

export interface ImportError {
  row: number;
  field?: string;
  message: string;
  data?: any;
}

export interface ExportConfig {
  format: 'excel' | 'csv' | 'json' | 'pdf';
  filename?: string;
  fields?: string[];
  headers?: Record<string, string>;
  filter?: Record<string, any>;
  transform?: (data: any[]) => any[];
  onProgress?: (progress: number) => void;
}

export interface ImportConfig {
  format: 'excel' | 'csv' | 'json';
  fields: FieldConfig[];
  validate?: (row: any, index: number) => string | undefined;
  transform?: (row: any, index: number) => any;
  onProgress?: (progress: number) => void;
  onError?: (errors: ImportError[]) => void;
}

export async function exportData(
  api: string,
  config: ExportConfig
): Promise<void> {
  try {
    Message.loading('正在导出数据...');

    const response = await fetch(api, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(config.filter || {}),
    });
    const result = await response.json();
    let data = result.data?.items || result.data || [];

    if (config.transform) {
      data = config.transform(data);
    }

    if (config.fields) {
      data = data.map((item: any) => {
        const filtered: any = {};
        const fields = config.fields || [];
        fields.forEach((field) => {
          filtered[field] = item[field];
        });
        return filtered;
      });
    }

    if (config.headers) {
      data = data.map((item: any) => {
        const renamed: any = {};
        const headers = config.headers || {};
        Object.keys(item).forEach((key) => {
          const newKey = headers[key] || key;
          renamed[newKey] = item[key];
        });
        return renamed;
      });
    }

    const filename = config.filename || `export_${Date.now()}`;
    switch (config.format) {
      case 'excel':
      case 'csv':
        await exportToCSV(data, filename);
        break;
      case 'json':
        await exportToJSON(data, filename);
        break;
      case 'pdf':
        await exportToPDF(data, filename);
        break;
      default:
        throw new Error(`不支持的导出格式: ${config.format}`);
    }

    Message.success('导出成功');
  } catch (error: any) {
    Message.error(`导出失败: ${error.message}`);
    throw error;
  }
}

export async function importData(
  file: File,
  config: ImportConfig
): Promise<{ success: number; failed: number; errors: ImportError[] }> {
  try {
    Message.loading('正在导入数据...');

    let data: any[] = [];
    switch (config.format) {
      case 'excel':
      case 'csv':
        data = await readCSV(file);
        break;
      case 'json':
        data = await readJSON(file);
        break;
      default:
        throw new Error(`不支持的导入格式: ${config.format}`);
    }

    const errors: ImportError[] = [];
    const validData: any[] = [];

    data.forEach((row, index) => {
      config.fields.forEach((field) => {
        if (field.required && !row[field.name]) {
          errors.push({
            row: index + 1,
            field: field.name,
            message: `${field.label}不能为空`,
            data: row,
          });
        }
      });

      if (config.validate) {
        const error = config.validate(row, index);
        if (error) {
          errors.push({
            row: index + 1,
            message: error,
            data: row,
          });
          return;
        }
      }

      let transformed = row;
      if (config.transform) {
        transformed = config.transform(row, index);
      }

      validData.push(transformed);

      if (config.onProgress) {
        config.onProgress(((index + 1) / data.length) * 100);
      }
    });

    if (errors.length > 0 && config.onError) {
      config.onError(errors);
    }

    Message.success(
      `导入完成: 成功 ${validData.length} 条，失败 ${errors.length} 条`
    );

    return {
      success: validData.length,
      failed: errors.length,
      errors,
    };
  } catch (error: any) {
    Message.error(`导入失败: ${error.message}`);
    throw error;
  }
}

function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

async function exportToCSV(data: any[], filename: string) {
  if (data.length === 0) return;

  const headers = Object.keys(data[0]);
  const csv = [
    headers.join(','),
    ...data.map((row) =>
      headers
        .map((h) => {
          const value = row[h] || '';
          return typeof value === 'string' &&
            (value.includes(',') || value.includes('\n'))
            ? `"${value.replace(/"/g, '""')}"`
            : value;
        })
        .join(',')
    ),
  ].join('\n');

  const blob = new Blob([`\ufeff${csv}`], {
    type: 'text/csv;charset=utf-8;',
  });
  downloadBlob(blob, `${filename}.csv`);
}

async function exportToJSON(data: any[], filename: string) {
  const json = JSON.stringify(data, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  downloadBlob(blob, `${filename}.json`);
}

async function exportToPDF(data: any[], filename: string) {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>${filename}</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        @media print { body { margin: 0; } }
      </style>
    </head>
    <body>
      <h2>${filename}</h2>
      <table>
        <thead>
          <tr>${Object.keys(data[0] || {})
            .map((k) => `<th>${k}</th>`)
            .join('')}</tr>
        </thead>
        <tbody>
          ${data
            .map(
              (row) =>
                `<tr>${Object.values(row)
                  .map((v) => `<td>${v}</td>`)
                  .join('')}</tr>`
            )
            .join('')}
        </tbody>
      </table>
      <script>window.print();</script>
    </body>
    </html>
  `;

  const blob = new Blob([html], { type: 'text/html' });
  const url = URL.createObjectURL(blob);
  window.open(url);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

async function readCSV(file: File): Promise<any[]> {
  const text = await file.text();
  const lines = text.split('\n').filter((line) => line.trim());
  if (lines.length === 0) return [];

  const headers = lines[0]
    .split(',')
    .map((h) => h.trim().replace(/^"|"$/g, ''));
  return lines.slice(1).map((line) => {
    const values = line.split(',').map((v) => v.trim().replace(/^"|"$/g, ''));
    const row: any = {};
    headers.forEach((h, i) => {
      row[h] = values[i];
    });
    return row;
  });
}

async function readJSON(file: File): Promise<any[]> {
  const text = await file.text();
  return JSON.parse(text);
}

export function generateImportTemplate(
  fields: FieldConfig[],
  format: 'excel' | 'csv' = 'excel'
): void {
  const headers = fields
    .filter((f) => !f.hideInForm)
    .reduce((acc, f) => {
      acc[f.name] = f.label;
      return acc;
    }, {} as any);

  const example = fields
    .filter((f) => !f.hideInForm)
    .reduce((acc, f) => {
      acc[f.name] = f.placeholder || `示例${f.label}`;
      return acc;
    }, {} as any);

  const data = [headers, example];
  exportToCSV(data, 'import_template');
}
