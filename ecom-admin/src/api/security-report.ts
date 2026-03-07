import request from '@/utils/request';
import type {
  ReportData,
  GenerateReportRequest,
  ExportReportRequest,
} from '@/types/security-report';

/**
 * 生成日报
 */
export function generateDailyReport(date: string) {
  return request<ReportData>({
    url: '/api/security/reports/daily',
    method: 'get',
    params: { date },
  });
}

/**
 * 生成周报
 */
export function generateWeeklyReport(startDate: string, endDate: string) {
  return request<ReportData>({
    url: '/api/security/reports/weekly',
    method: 'get',
    params: {
      start_date: startDate,
      end_date: endDate,
    },
  });
}

/**
 * 生成月报
 */
export function generateMonthlyReport(month: string) {
  return request<ReportData>({
    url: '/api/security/reports/monthly',
    method: 'get',
    params: { month },
  });
}

/**
 * 生成自定义报告
 */
export function generateCustomReport(data: GenerateReportRequest) {
  return request<ReportData>({
    url: '/api/security/reports/custom',
    method: 'post',
    data,
  });
}

/**
 * 导出HTML报告
 */
export function exportHTMLReport(data: ExportReportRequest) {
  return request<Blob>({
    url: '/api/security/reports/export/html',
    method: 'post',
    data,
    responseType: 'blob',
  });
}

/**
 * 下载报告
 */
export function downloadReport(blob: Blob, filename: string) {
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.URL.revokeObjectURL(url);
}
