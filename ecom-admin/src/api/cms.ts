import request from './request';
import type {
  ContentModel,
  Content,
  Category,
  Tag,
  Media,
  MediaFolder,
  Template,
  ContentVersion,
  Translation,
  ApiResponse,
  PageResponse,
  QueryParams,
} from '@/types/cms';

// ==================== 内容模型 ====================
export const getModelList = (params?: QueryParams) =>
  request.get<ApiResponse<PageResponse<ContentModel>>>('/api/cms/models', {
    params,
  });

export const getModelDetail = (id: number) =>
  request.get<ApiResponse<ContentModel>>(`/api/cms/models/${id}`);

export const createModel = (data: Partial<ContentModel>) =>
  request.post<ApiResponse<ContentModel>>('/api/cms/models', data);

export const updateModel = (id: number, data: Partial<ContentModel>) =>
  request.put<ApiResponse<ContentModel>>(`/api/cms/models/${id}`, data);

export const deleteModel = (id: number) =>
  request.delete<ApiResponse<void>>(`/api/cms/models/${id}`);

// 字段管理
export const addModelField = (modelId: number, data: any) =>
  request.post(`/api/cms/models/${modelId}/fields`, data);

export const updateModelField = (modelId: number, fieldId: number, data: any) =>
  request.put(`/api/cms/models/${modelId}/fields/${fieldId}`, data);

export const deleteModelField = (modelId: number, fieldId: number) =>
  request.delete(`/api/cms/models/${modelId}/fields/${fieldId}`);

export const sortModelFields = (modelId: number, fieldIds: number[]) =>
  request.post(`/api/cms/models/${modelId}/fields/sort`, { fieldIds });

// ==================== 内容管理 ====================
export const getContentList = (modelId: number, params?: QueryParams) =>
  request.get<ApiResponse<PageResponse<Content>>>(
    `/api/cms/contents/${modelId}`,
    { params }
  );

export const getContentDetail = (modelId: number, id: number) =>
  request.get<ApiResponse<Content>>(`/api/cms/contents/${modelId}/${id}`);

export const createContent = (modelId: number, data: Partial<Content>) =>
  request.post<ApiResponse<Content>>(`/api/cms/contents/${modelId}`, data);

export const updateContent = (
  modelId: number,
  id: number,
  data: Partial<Content>
) =>
  request.put<ApiResponse<Content>>(`/api/cms/contents/${modelId}/${id}`, data);

export const deleteContent = (modelId: number, id: number) =>
  request.delete<ApiResponse<void>>(`/api/cms/contents/${modelId}/${id}`);

// 内容发布
export const publishContent = (modelId: number, id: number, data?: any) =>
  request.post(`/api/cms/contents/${modelId}/${id}/publish`, data);

export const unpublishContent = (modelId: number, id: number) =>
  request.post(`/api/cms/contents/${modelId}/${id}/unpublish`);

// 批量操作
export const batchPublishContent = (modelId: number, ids: number[]) =>
  request.post(`/api/cms/contents/${modelId}/batch/publish`, { ids });

export const batchDeleteContent = (modelId: number, ids: number[]) =>
  request.post(`/api/cms/contents/${modelId}/batch/delete`, { ids });

// ==================== 版本管理 ====================
export const getVersionList = (modelId: number, contentId: number) =>
  request.get<ApiResponse<PageResponse<ContentVersion>>>(
    `/api/cms/contents/${modelId}/${contentId}/versions`
  );

export const rollbackVersion = (
  modelId: number,
  contentId: number,
  versionId: number
) =>
  request.post(
    `/api/cms/contents/${modelId}/${contentId}/versions/${versionId}/rollback`
  );

export const compareVersions = (
  modelId: number,
  contentId: number,
  v1: number,
  v2: number
) =>
  request.get(
    `/api/cms/contents/${modelId}/${contentId}/versions/compare?v1=${v1}&v2=${v2}`
  );

// ==================== 分类管理 ====================
export const getCategoryList = (params?: QueryParams) =>
  request.get<ApiResponse<PageResponse<Category>>>('/api/cms/categories', {
    params,
  });

export const getCategoryTree = (modelId?: number) =>
  request.get<ApiResponse<Category[]>>('/api/cms/categories/tree', {
    params: { model_id: modelId },
  });

export const createCategory = (data: Partial<Category>) =>
  request.post<ApiResponse<Category>>('/api/cms/categories', data);

export const updateCategory = (id: number, data: Partial<Category>) =>
  request.put<ApiResponse<Category>>(`/api/cms/categories/${id}`, data);

export const deleteCategory = (id: number) =>
  request.delete<ApiResponse<void>>(`/api/cms/categories/${id}`);

export const sortCategories = (ids: number[]) =>
  request.post('/api/cms/categories/sort', { ids });

// ==================== 标签管理 ====================
export const getTagList = (params?: QueryParams) =>
  request.get<ApiResponse<PageResponse<Tag>>>('/api/cms/tags', { params });

export const createTag = (data: Partial<Tag>) =>
  request.post<ApiResponse<Tag>>('/api/cms/tags', data);

export const updateTag = (id: number, data: Partial<Tag>) =>
  request.put<ApiResponse<Tag>>(`/api/cms/tags/${id}`, data);

export const deleteTag = (id: number) =>
  request.delete<ApiResponse<void>>(`/api/cms/tags/${id}`);

export const mergeTags = (sourceId: number, targetId: number) =>
  request.post('/api/cms/tags/merge', { sourceId, targetId });

// ==================== 媒体库 ====================
export const getMediaList = (params?: QueryParams) =>
  request.get<ApiResponse<PageResponse<Media>>>('/api/cms/media', { params });

export const uploadMedia = (data: FormData) =>
  request.post<ApiResponse<Media>>('/api/cms/media/upload', data);

export const uploadChunk = (data: FormData) =>
  request.post('/api/cms/media/upload/chunk', data);

export const mergeChunks = (fileId: string) =>
  request.post('/api/cms/media/upload/merge', { fileId });

export const deleteMedia = (id: number) =>
  request.delete<ApiResponse<void>>(`/api/cms/media/${id}`);

export const batchDeleteMedia = (ids: number[]) =>
  request.post('/api/cms/media/batch/delete', { ids });

// 媒体文件夹
export const getFolderTree = () =>
  request.get<ApiResponse<MediaFolder[]>>('/api/cms/media/folders/tree');

export const createFolder = (data: Partial<MediaFolder>) =>
  request.post<ApiResponse<MediaFolder>>('/api/cms/media/folders', data);

export const updateFolder = (id: number, data: Partial<MediaFolder>) =>
  request.put<ApiResponse<MediaFolder>>(`/api/cms/media/folders/${id}`, data);

export const deleteFolder = (id: number) =>
  request.delete<ApiResponse<void>>(`/api/cms/media/folders/${id}`);

// ==================== 模板管理 ====================
export const getTemplateList = (params?: QueryParams) =>
  request.get<ApiResponse<PageResponse<Template>>>('/api/cms/templates', {
    params,
  });

export const createTemplate = (data: Partial<Template>) =>
  request.post<ApiResponse<Template>>('/api/cms/templates', data);

export const updateTemplate = (id: number, data: Partial<Template>) =>
  request.put<ApiResponse<Template>>(`/api/cms/templates/${id}`, data);

export const deleteTemplate = (id: number) =>
  request.delete<ApiResponse<void>>(`/api/cms/templates/${id}`);

// ==================== 翻译管理 ====================
export const getTranslationList = (contentId: number) =>
  request.get<ApiResponse<Translation[]>>(`/api/cms/translations/${contentId}`);

export const saveTranslation = (
  contentId: number,
  data: Partial<Translation>
) =>
  request.post<ApiResponse<Translation>>(
    `/api/cms/translations/${contentId}`,
    data
  );

// ==================== SEO 工具 ====================
export const generateSitemap = () =>
  request.post('/api/cms/seo/sitemap/generate');

export const getSitemapStatus = () =>
  request.get('/api/cms/seo/sitemap/status');

// ==================== 缓存管理 ====================
export const clearCache = (type: 'page' | 'api' | 'all') =>
  request.post('/api/cms/cache/clear', { type });

export const getCacheStats = () => request.get('/api/cms/cache/stats');

// ==================== 工作流管理 ====================
export const getWorkflowList = () => request.get('/api/cms/workflows');

export const createWorkflow = (data: any) =>
  request.post('/api/cms/workflows', data);

export const updateWorkflow = (id: number, data: any) =>
  request.put(`/api/cms/workflows/${id}`, data);

export const deleteWorkflow = (id: number) =>
  request.delete(`/api/cms/workflows/${id}`);

// 定时发布
export const getScheduleList = () => request.get('/api/cms/schedules');

export const cancelSchedule = (id: number) =>
  request.post(`/api/cms/schedules/${id}/cancel`);

// 审批记录
export const getApprovalRecords = (params?: any) =>
  request.get('/api/cms/approvals', { params });

export const approveContent = (id: number, data: any) =>
  request.post(`/api/cms/approvals/${id}/approve`, data);

// ==================== CMS 统计 ====================
export const getCMSStats = () => request.get('/api/cms/stats');

export const getRecentContents = () => request.get('/api/cms/contents/recent');

// ==================== 媒体文件夹 ====================
export const getMediaFolders = () => request.get('/api/cms/media/folders');

export const createMediaFolder = (data: any) =>
  request.post('/api/cms/media/folders', data);

export const updateMediaFolder = (id: number, data: any) =>
  request.put(`/api/cms/media/folders/${id}`, data);

export const deleteMediaFolder = (id: number) =>
  request.delete(`/api/cms/media/folders/${id}`);

// ==================== 版本控制 ====================
export const getContentVersions = (modelId: number, contentId: number) =>
  request.get(`/api/cms/contents/${modelId}/${contentId}/versions`);

export const rollbackContentVersion = (
  modelId: number,
  contentId: number,
  version: number
) =>
  request.post(
    `/api/cms/contents/${modelId}/${contentId}/versions/${version}/rollback`
  );

// ==================== 分类排序 ====================
export const sortCategory = (data: any) =>
  request.post('/api/cms/categories/sort', data);
