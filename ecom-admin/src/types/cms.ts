// CMS 内容模型类型定义
export interface ContentModel {
  id: number;
  name: string;
  slug: string;
  table_name: string;
  description?: string;
  enable_category: boolean;
  enable_tag: boolean;
  enable_version: boolean;
  enable_i18n: boolean;
  status: number;
  fields: ModelField[];
  content_count?: number;
  created_at: string;
  updated_at?: string;
}

// 模型字段
export interface ModelField {
  id: number;
  label: string;
  key: string;
  type: FieldType;
  required: boolean;
  unique: boolean;
  searchable: boolean;
  default_value?: any;
  placeholder?: string;
  help_text?: string;
  validation_rules?: ValidationRule;
  options?: FieldOption[];
  sort: number;
}

// 字段类型
export type FieldType =
  | 'text'
  | 'textarea'
  | 'richtext'
  | 'markdown'
  | 'number'
  | 'money'
  | 'percent'
  | 'date'
  | 'datetime'
  | 'time_range'
  | 'select'
  | 'radio'
  | 'checkbox'
  | 'switch'
  | 'image'
  | 'file'
  | 'video'
  | 'relation'
  | 'json'
  | 'array'
  | 'location'
  | 'color'
  | 'rating'
  | 'icon';

// 验证规则
export interface ValidationRule {
  min_length?: number;
  max_length?: number;
  min?: number;
  max?: number;
  pattern?: string;
  custom?: string;
}

// 字段选项
export interface FieldOption {
  label: string;
  value: any;
}

// 内容数据
export interface Content {
  id: number;
  model_id: number;
  category_id?: number;
  category_name?: string;
  tag_ids?: number[];
  tags?: Tag[];
  status: ContentStatus;
  fields: Record<string, any>;
  created_by: number;
  updated_by?: number;
  published_at?: string;
  created_at: string;
  updated_at?: string;
}

// 内容状态
export enum ContentStatus {
  DRAFT = 0,
  PENDING = 1,
  PUBLISHED = 2,
  ARCHIVED = 3,
  REJECTED = 4,
}

// 内容版本
export interface ContentVersion {
  id: number;
  content_id: number;
  version: number;
  version_id: number;
  data: Record<string, any>;
  change_summary?: string;
  created_by: number;
  created_by_name?: string;
  created_at: string;
}

// 分类
export interface Category {
  id: number;
  name: string;
  slug: string;
  parent_id: number;
  model_id?: number;
  icon?: string;
  cover?: string;
  sort: number;
  seo_title?: string;
  seo_keywords?: string;
  seo_description?: string;
  status: number;
  children?: Category[];
  created_at: string;
}

// 标签
export interface Tag {
  id: number;
  name: string;
  slug: string;
  color: string;
  group?: string;
  count: number;
  status: number;
  created_at: string;
}

// 媒体文件
export interface Media {
  id: number;
  folder_id?: number;
  name: string;
  original_name: string;
  path: string;
  url: string;
  type: MediaType;
  mime_type: string;
  size: number;
  width?: number;
  height?: number;
  duration?: number;
  thumbnail?: string;
  status: number;
  created_by: number;
  created_at: string;
}

// 媒体类型
export enum MediaType {
  IMAGE = 'image',
  VIDEO = 'video',
  AUDIO = 'audio',
  DOCUMENT = 'document',
  OTHER = 'other',
}

// 媒体文件夹
export interface MediaFolder {
  id: number;
  name: string;
  parent_id: number;
  sort: number;
  children?: MediaFolder[];
  created_at: string;
}

// 模板
export interface Template {
  id: number;
  name: string;
  slug: string;
  type: TemplateType;
  content: string;
  variables: string[];
  status: number;
  created_at: string;
}

// 模板类型
export enum TemplateType {
  LIST = 'list',
  DETAIL = 'detail',
  SEARCH = 'search',
  ERROR = 'error',
}

// 工作流
export interface Workflow {
  id: number;
  name: string;
  model_id: number;
  steps: WorkflowStep[];
  status: number;
  created_at: string;
}

// 工作流步骤
export interface WorkflowStep {
  id: number;
  name: string;
  type: 'approve' | 'notify' | 'auto';
  approvers: number[];
  sort: number;
}

// 翻译
export interface Translation {
  id: number;
  content_id: number;
  locale: string;
  fields: Record<string, any>;
  status: number;
  translator_id?: number;
  updated_at: string;
}

// API 响应
export interface ApiResponse<T = any> {
  code: number;
  msg: string;
  data: T;
}

// 分页响应
export interface PageResponse<T = any> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

// 查询参数
export interface QueryParams {
  page?: number;
  pageSize?: number;
  keyword?: string;
  status?: number;
  category_id?: number;
  tag_ids?: number[];
  sort?: string;
  order?: 'asc' | 'desc';
}

// 工作流
export interface Workflow {
  id: number;
  name: string;
  model_id: number;
  model_name?: string;
  nodes: WorkflowNode[];
  status: number;
  created_at: string;
  updated_at?: string;
}

export interface WorkflowNode {
  id?: number;
  name: string;
  approver_id: number;
  approver_name?: string;
  sort?: number;
}

// 定时发布
export interface Schedule {
  id: number;
  content_id: number;
  content_title: string;
  model_id: number;
  model_name: string;
  publish_time: string;
  status: number;
  created_at: string;
}

// 审批记录
export interface ApprovalRecord {
  id: number;
  workflow_id: number;
  workflow_name: string;
  content_id: number;
  content_title: string;
  model_id: number;
  current_node_id: number;
  current_node_name: string;
  applicant_id: number;
  applicant_name: string;
  status: number;
  logs: ApprovalLog[];
  created_at: string;
  updated_at?: string;
}

export interface ApprovalLog {
  id: number;
  node_id: number;
  node_name: string;
  approver_id: number;
  approver_name: string;
  status: number;
  remark?: string;
  created_at: string;
}
