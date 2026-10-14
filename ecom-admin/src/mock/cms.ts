import Mock from 'mockjs';
import type { ContentModel, ModelField, Content } from '@/types/cms';

// 内容模型数据
const models: ContentModel[] = [
  {
    id: 1,
    name: '文章',
    slug: 'article',
    table_name: 'cms_content_article',
    description: '新闻文章内容管理',
    enable_category: true,
    enable_tag: true,
    enable_version: true,
    enable_i18n: false,
    status: 1,
    content_count: 25,
    fields: [
      {
        id: 1,
        label: '标题',
        key: 'title',
        type: 'text',
        required: true,
        unique: false,
        searchable: true,
        default_value: '',
        placeholder: '请输入文章标题',
        help_text: '文章的主标题，建议不超过30字',
        validation_rules: { min_length: 5, max_length: 200 },
        sort: 1,
      },
      {
        id: 2,
        label: '副标题',
        key: 'subtitle',
        type: 'text',
        required: false,
        unique: false,
        searchable: false,
        placeholder: '请输入副标题',
        help_text: '可选的副标题或摘要',
        validation_rules: { max_length: 100 },
        sort: 2,
      },
      {
        id: 3,
        label: '作者',
        key: 'author',
        type: 'text',
        required: true,
        unique: false,
        searchable: true,
        placeholder: '请输入作者姓名',
        validation_rules: { max_length: 50 },
        sort: 3,
      },
      {
        id: 4,
        label: '封面图',
        key: 'cover',
        type: 'image',
        required: true,
        unique: false,
        searchable: false,
        placeholder: '上传封面图片',
        help_text: '建议尺寸：1200x630px',
        sort: 4,
      },
      {
        id: 5,
        label: '内容',
        key: 'content',
        type: 'richtext',
        required: true,
        unique: false,
        searchable: true,
        placeholder: '请输入文章内容',
        help_text: '支持富文本编辑',
        validation_rules: { min_length: 100 },
        sort: 5,
      },
      {
        id: 6,
        label: '摘要',
        key: 'summary',
        type: 'textarea',
        required: false,
        unique: false,
        searchable: true,
        placeholder: '请输入文章摘要',
        help_text: '用于列表展示和SEO',
        validation_rules: { max_length: 500 },
        sort: 6,
      },
      {
        id: 7,
        label: '发布时间',
        key: 'publish_time',
        type: 'datetime',
        required: true,
        unique: false,
        searchable: false,
        placeholder: '选择发布时间',
        default_value: 'now',
        sort: 7,
      },
      {
        id: 8,
        label: '阅读量',
        key: 'views',
        type: 'number',
        required: false,
        unique: false,
        searchable: false,
        default_value: '0',
        placeholder: '阅读次数',
        validation_rules: { min: 0 },
        sort: 8,
      },
      {
        id: 9,
        label: '排序',
        key: 'sort',
        type: 'number',
        required: false,
        unique: false,
        searchable: false,
        default_value: '0',
        placeholder: '数字越大越靠前',
        help_text: '用于控制显示顺序',
        validation_rules: { min: 0, max: 9999 },
        sort: 9,
      },
      {
        id: 10,
        label: '状态',
        key: 'status',
        type: 'switch',
        required: false,
        unique: false,
        searchable: false,
        default_value: '1',
        help_text: '是否启用',
        sort: 10,
      },
    ],
    created_at: '2024-01-15 10:00:00',
    updated_at: '2024-02-20 15:30:00',
  },
  {
    id: 2,
    name: '产品',
    slug: 'product',
    table_name: 'cms_content_product',
    description: '产品展示管理',
    enable_category: true,
    enable_tag: true,
    enable_version: false,
    enable_i18n: true,
    status: 1,
    content_count: 48,
    fields: [
      {
        id: 11,
        label: '产品名称',
        key: 'name',
        type: 'text',
        required: true,
        unique: true,
        searchable: true,
        placeholder: '请输入产品名称',
        validation_rules: { min_length: 2, max_length: 100 },
        sort: 1,
      },
      {
        id: 12,
        label: '产品编号',
        key: 'sku',
        type: 'text',
        required: true,
        unique: true,
        searchable: true,
        placeholder: '请输入产品编号',
        help_text: '唯一的产品SKU编号',
        validation_rules: { pattern: '^[A-Z0-9-]+$' },
        sort: 2,
      },
      {
        id: 13,
        label: '产品图片',
        key: 'images',
        type: 'image',
        required: true,
        unique: false,
        searchable: false,
        placeholder: '上传产品图片',
        help_text: '可上传多张图片',
        sort: 3,
      },
      {
        id: 14,
        label: '价格',
        key: 'price',
        type: 'money',
        required: true,
        unique: false,
        searchable: false,
        placeholder: '请输入价格',
        validation_rules: { min: 0, max: 999999 },
        sort: 4,
      },
      {
        id: 15,
        label: '原价',
        key: 'original_price',
        type: 'money',
        required: false,
        unique: false,
        searchable: false,
        placeholder: '请输入原价',
        help_text: '用于显示折扣',
        validation_rules: { min: 0 },
        sort: 5,
      },
      {
        id: 16,
        label: '库存',
        key: 'stock',
        type: 'number',
        required: true,
        unique: false,
        searchable: false,
        default_value: '0',
        placeholder: '请输入库存数量',
        validation_rules: { min: 0 },
        sort: 6,
      },
      {
        id: 17,
        label: '产品描述',
        key: 'description',
        type: 'richtext',
        required: true,
        unique: false,
        searchable: true,
        placeholder: '请输入产品描述',
        validation_rules: { min_length: 50 },
        sort: 7,
      },
      {
        id: 18,
        label: '产品规格',
        key: 'specifications',
        type: 'json',
        required: false,
        unique: false,
        searchable: false,
        placeholder: '输入JSON格式的规格数据',
        help_text: '如：{"颜色": "红色", "尺寸": "L"}',
        sort: 8,
      },
      {
        id: 19,
        label: '是否推荐',
        key: 'is_featured',
        type: 'switch',
        required: false,
        unique: false,
        searchable: false,
        default_value: '0',
        help_text: '首页推荐显示',
        sort: 9,
      },
      {
        id: 20,
        label: '上架状态',
        key: 'status',
        type: 'select',
        required: true,
        unique: false,
        searchable: false,
        default_value: 'draft',
        options: [
          { label: '草稿', value: 'draft' },
          { label: '已上架', value: 'published' },
          { label: '已下架', value: 'offline' },
        ],
        sort: 10,
      },
    ],
    created_at: '2024-01-20 14:00:00',
    updated_at: '2024-02-22 09:15:00',
  },
  {
    id: 3,
    name: '案例',
    slug: 'case',
    table_name: 'cms_content_case',
    description: '成功案例展示',
    enable_category: true,
    enable_tag: true,
    enable_version: false,
    enable_i18n: false,
    status: 1,
    content_count: 12,
    fields: [
      {
        id: 21,
        label: '案例标题',
        key: 'title',
        type: 'text',
        required: true,
        unique: false,
        searchable: true,
        placeholder: '请输入案例标题',
        validation_rules: { min_length: 5, max_length: 100 },
        sort: 1,
      },
      {
        id: 22,
        label: '客户名称',
        key: 'client',
        type: 'text',
        required: true,
        unique: false,
        searchable: true,
        placeholder: '请输入客户名称',
        validation_rules: { max_length: 50 },
        sort: 2,
      },
      {
        id: 23,
        label: '行业',
        key: 'industry',
        type: 'select',
        required: true,
        unique: false,
        searchable: false,
        placeholder: '选择行业',
        options: [
          { label: '互联网', value: 'internet' },
          { label: '金融', value: 'finance' },
          { label: '教育', value: 'education' },
          { label: '医疗', value: 'healthcare' },
          { label: '制造业', value: 'manufacturing' },
          { label: '零售', value: 'retail' },
        ],
        sort: 3,
      },
      {
        id: 24,
        label: '项目周期',
        key: 'duration',
        type: 'daterange',
        required: true,
        unique: false,
        searchable: false,
        placeholder: '选择项目周期',
        sort: 4,
      },
      {
        id: 25,
        label: '封面图',
        key: 'cover',
        type: 'image',
        required: true,
        unique: false,
        searchable: false,
        placeholder: '上传案例封面',
        help_text: '建议尺寸：800x600px',
        sort: 5,
      },
      {
        id: 26,
        label: '案例介绍',
        key: 'introduction',
        type: 'textarea',
        required: true,
        unique: false,
        searchable: true,
        placeholder: '请输入案例简介',
        validation_rules: { min_length: 50, max_length: 500 },
        sort: 6,
      },
      {
        id: 27,
        label: '详细内容',
        key: 'content',
        type: 'richtext',
        required: true,
        unique: false,
        searchable: true,
        placeholder: '请输入详细内容',
        validation_rules: { min_length: 200 },
        sort: 7,
      },
      {
        id: 28,
        label: '项目成果',
        key: 'achievements',
        type: 'checkbox',
        required: false,
        unique: false,
        searchable: false,
        options: [
          { label: '提升效率', value: 'efficiency' },
          { label: '降低成本', value: 'cost' },
          { label: '增加收入', value: 'revenue' },
          { label: '优化体验', value: 'experience' },
        ],
        sort: 8,
      },
      {
        id: 29,
        label: '客户评分',
        key: 'rating',
        type: 'rating',
        required: false,
        unique: false,
        searchable: false,
        default_value: '5',
        help_text: '1-5星评分',
        validation_rules: { min: 1, max: 5 },
        sort: 9,
      },
      {
        id: 30,
        label: '是否展示',
        key: 'status',
        type: 'switch',
        required: false,
        unique: false,
        searchable: false,
        default_value: '1',
        sort: 10,
      },
    ],
    created_at: '2024-02-01 11:00:00',
    updated_at: '2024-02-23 16:20:00',
  },
];

// 内容数据存储
const contents: Record<number, Content[]> = {
  1: [], // 文章
  2: [], // 产品
};

// 生成示例内容
const generateMockContents = () => {
  // 生成文章内容
  for (let i = 1; i <= 20; i++) {
    contents[1].push({
      id: i,
      model_id: 1,
      category_id: Mock.Random.integer(1, 3),
      category_name: Mock.Random.pick(['公司新闻', '行业动态', '技术分享']),
      tag_ids: [Mock.Random.integer(1, 5), Mock.Random.integer(1, 5)],
      tags: [
        {
          id: 1,
          name: '热门',
          slug: 'hot',
          color: '#f5222d',
          count: 10,
          status: 1,
          created_at: '',
        },
        {
          id: 2,
          name: '推荐',
          slug: 'recommend',
          color: '#1890ff',
          count: 8,
          status: 1,
          created_at: '',
        },
      ],
      status: Mock.Random.integer(0, 2),
      fields: {
        title: Mock.Random.ctitle(10, 30),
        subtitle: Mock.Random.ctitle(5, 15),
        author: Mock.Random.cname(),
        cover: Mock.Random.image('400x300'),
        summary: Mock.Random.cparagraph(1, 3),
        content: Mock.Random.cparagraph(5, 10),
      },
      created_by: 1,
      created_at: Mock.Random.datetime(),
      updated_at: Mock.Random.datetime(),
    });
  }

  // 生成产品内容
  for (let i = 1; i <= 15; i++) {
    contents[2].push({
      id: i,
      model_id: 2,
      category_id: Mock.Random.integer(4, 6),
      category_name: Mock.Random.pick(['电子产品', '服装鞋包', '食品饮料']),
      status: Mock.Random.integer(0, 2),
      fields: {
        name: Mock.Random.ctitle(5, 15),
        code: `PROD${String(i).padStart(4, '0')}`,
        price: Mock.Random.float(10, 1000, 2, 2),
        stock: Mock.Random.integer(0, 1000),
      },
      created_by: 1,
      created_at: Mock.Random.datetime(),
      updated_at: Mock.Random.datetime(),
    });
  }
};

generateMockContents();

// 分类数据存储
const categories: Category[] = [
  {
    id: 1,
    name: '公司新闻',
    slug: 'company-news',
    parent_id: undefined,
    sort: 1,
    status: 1,
    description: '公司相关新闻动态',
    seo_title: '公司新闻 - 企业动态',
    seo_keywords: '公司新闻,企业动态',
    seo_description: '了解公司最新动态和新闻资讯',
    content_count: 10,
    created_at: '2026-01-01 10:00:00',
  },
  {
    id: 2,
    name: '产品发布',
    slug: 'product-release',
    parent_id: 1,
    sort: 1,
    status: 1,
    description: '新产品发布信息',
    content_count: 5,
    created_at: '2026-01-02 10:00:00',
  },
  {
    id: 3,
    name: '公司活动',
    slug: 'company-events',
    parent_id: 1,
    sort: 2,
    status: 1,
    description: '公司举办的各类活动',
    content_count: 5,
    created_at: '2026-01-03 10:00:00',
  },
  {
    id: 4,
    name: '行业动态',
    slug: 'industry-news',
    parent_id: undefined,
    sort: 2,
    status: 1,
    description: '行业相关新闻和趋势',
    seo_title: '行业动态 - 行业资讯',
    seo_keywords: '行业动态,行业资讯',
    seo_description: '关注行业最新动态和发展趋势',
    content_count: 8,
    created_at: '2026-01-04 10:00:00',
  },
  {
    id: 5,
    name: '技术分享',
    slug: 'tech-sharing',
    parent_id: undefined,
    sort: 3,
    status: 1,
    description: '技术文章和经验分享',
    seo_title: '技术分享 - 技术博客',
    seo_keywords: '技术分享,技术博客',
    seo_description: '分享技术经验和最佳实践',
    content_count: 7,
    created_at: '2026-01-05 10:00:00',
  },
  {
    id: 6,
    name: '前端技术',
    slug: 'frontend',
    parent_id: 5,
    sort: 1,
    status: 1,
    description: '前端开发相关技术',
    content_count: 4,
    created_at: '2026-01-06 10:00:00',
  },
  {
    id: 7,
    name: '后端技术',
    slug: 'backend',
    parent_id: 5,
    sort: 2,
    status: 1,
    description: '后端开发相关技术',
    content_count: 3,
    created_at: '2026-01-07 10:00:00',
  },
];

// 标签数据存储
const tags: Tag[] = [
  {
    id: 1,
    name: '热门',
    slug: 'hot',
    color: '#f5222d',
    count: 15,
    status: 1,
    created_at: '2026-01-01 10:00:00',
  },
  {
    id: 2,
    name: '推荐',
    slug: 'recommend',
    color: '#1890ff',
    count: 12,
    status: 1,
    created_at: '2026-01-02 10:00:00',
  },
  {
    id: 3,
    name: '精选',
    slug: 'featured',
    color: '#52c41a',
    count: 10,
    status: 1,
    created_at: '2026-01-03 10:00:00',
  },
  {
    id: 4,
    name: '新品',
    slug: 'new',
    color: '#fa8c16',
    count: 8,
    status: 1,
    created_at: '2026-01-04 10:00:00',
  },
  {
    id: 5,
    name: '促销',
    slug: 'sale',
    color: '#eb2f96',
    count: 6,
    status: 1,
    created_at: '2026-01-05 10:00:00',
  },
];

// 媒体文件夹数据
const mediaFolders: MediaFolder[] = [
  {
    id: 1,
    name: '产品图片',
    parent_id: undefined,
    created_at: '2026-01-01 10:00:00',
  },
  {
    id: 2,
    name: '文章配图',
    parent_id: undefined,
    created_at: '2026-01-02 10:00:00',
  },
  {
    id: 3,
    name: '视频资源',
    parent_id: undefined,
    created_at: '2026-01-03 10:00:00',
  },
  {
    id: 4,
    name: '文档资料',
    parent_id: undefined,
    created_at: '2026-01-04 10:00:00',
  },
];

// 媒体文件数据
const mediaFiles: Media[] = [];

// 生成示例媒体文件
const generateMockMedia = () => {
  for (let i = 1; i <= 30; i++) {
    const types = ['image', 'video', 'document'];
    const type = types[i % 3];
    const folderId = (i % 4) + 1;

    mediaFiles.push({
      id: i,
      name: `${type}_${i}.${
        type === 'image' ? 'jpg' : type === 'video' ? 'mp4' : 'pdf'
      }`,
      url:
        type === 'image'
          ? Mock.Random.image('400x300')
          : `https://example.com/${type}_${i}`,
      type,
      size: Mock.Random.integer(100000, 5000000),
      folder_id: folderId,
      created_at: Mock.Random.datetime(),
    });
  }
};

generateMockMedia();

// 版本数据存储
const contentVersions: Record<string, ContentVersion[]> = {};

// 生成版本数据
const generateVersionForContent = (modelId: number, contentId: number) => {
  const key = `${modelId}_${contentId}`;
  if (!contentVersions[key]) {
    contentVersions[key] = [];
    for (let i = 1; i <= 5; i++) {
      contentVersions[key].push({
        id: i,
        content_id: contentId,
        version: i,
        version_id: i,
        data: {
          title: `标题 v${i}`,
          content: `内容 v${i}`,
        },
        change_summary: `第 ${i} 次修改`,
        created_by: 1,
        created_by_name: Mock.Random.cname(),
        created_at: Mock.Random.datetime(),
      });
    }
  }
  return contentVersions[key];
};

// 工作流数据
const workflows: any[] = [
  {
    id: 1,
    name: '文章审批流程',
    model_id: 1,
    model_name: '文章',
    nodes: [
      { id: 1, name: '初审', approver_id: 2, approver_name: '编辑', sort: 1 },
      { id: 2, name: '终审', approver_id: 1, approver_name: '管理员', sort: 2 },
    ],
    status: 1,
    created_at: '2026-01-01 10:00:00',
  },
];

// 定时发布数据
const schedules: any[] = [
  {
    id: 1,
    content_id: 1,
    content_title: '示例文章标题',
    model_id: 1,
    model_name: '文章',
    publish_time: '2026-03-01 10:00:00',
    status: 0,
    created_at: '2026-02-25 10:00:00',
  },
];

// 审批记录数据
const approvalRecords: any[] = [
  {
    id: 1,
    workflow_id: 1,
    workflow_name: '文章审批流程',
    content_id: 1,
    content_title: '示例文章标题',
    model_id: 1,
    current_node_id: 1,
    current_node_name: '初审',
    applicant_id: 3,
    applicant_name: '作者',
    status: 0,
    logs: [
      {
        id: 1,
        node_id: 1,
        node_name: '初审',
        approver_id: 2,
        approver_name: '编辑',
        status: 0,
        created_at: '2026-02-25 10:00:00',
      },
    ],
    created_at: '2026-02-25 10:00:00',
  },
];

export default [
  // 获取模型列表
  {
    url: '/api/cms/models',
    method: 'get',
    response: (config: any) => {
      const { page = 1, pageSize = 20, keyword, status } = config.query || {};

      let filteredModels = [...models];

      // 关键词搜索
      if (keyword) {
        filteredModels = filteredModels.filter(
          (m) =>
            m.name.includes(keyword) ||
            m.slug.includes(keyword) ||
            m.description?.includes(keyword)
        );
      }

      // 状态筛选
      if (status !== undefined && status !== '') {
        filteredModels = filteredModels.filter(
          (m) => m.status === Number(status)
        );
      }

      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const items = filteredModels.slice(start, end);

      return {
        code: 200,
        msg: 'success',
        data: {
          items,
          total: filteredModels.length,
          page: Number(page),
          pageSize: Number(pageSize),
        },
      };
    },
  },

  // 获取模型详情
  {
    url: /\/api\/cms\/models\/(\d+)$/,
    method: 'get',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/cms\/models\/(\d+)$/)[1]);
      const model = models.find((m) => m.id === id);

      if (!model) {
        return {
          code: 404,
          msg: '模型不存在',
          data: null,
        };
      }

      return {
        code: 200,
        msg: 'success',
        data: model,
      };
    },
  },

  // 创建模型
  {
    url: '/api/cms/models',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body);
      const newModel: ContentModel = {
        id: models.length + 1,
        name: data.name,
        slug: data.slug,
        table_name: `cms_content_${data.slug}`,
        description: data.description || '',
        enable_category: data.enable_category !== false,
        enable_tag: data.enable_tag !== false,
        enable_version: data.enable_version || false,
        enable_i18n: data.enable_i18n || false,
        status: 1,
        content_count: 0,
        fields: [],
        created_at: new Date().toLocaleString(),
        updated_at: new Date().toLocaleString(),
      };

      models.push(newModel);

      return {
        code: 200,
        msg: '创建成功',
        data: newModel,
      };
    },
  },

  // 更新模型
  {
    url: /\/api\/cms\/models\/(\d+)$/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/cms\/models\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);
      const index = models.findIndex((m) => m.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '模型不存在',
          data: null,
        };
      }

      models[index] = {
        ...models[index],
        ...data,
        updated_at: new Date().toLocaleString(),
      };

      return {
        code: 200,
        msg: '更新成功',
        data: models[index],
      };
    },
  },

  // 删除模型
  {
    url: /\/api\/cms\/models\/(\d+)$/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/cms\/models\/(\d+)$/)[1]);
      const index = models.findIndex((m) => m.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '模型不存在',
          data: null,
        };
      }

      if (models[index].content_count && models[index].content_count! > 0) {
        return {
          code: 400,
          msg: '该模型下还有内容，无法删除',
          data: null,
        };
      }

      models.splice(index, 1);

      return {
        code: 200,
        msg: '删除成功',
        data: null,
      };
    },
  },

  // ==================== 内容管理 ====================
  // 获取内容列表
  {
    url: /\/api\/cms\/contents\/(\d+)$/,
    method: 'get',
    response: (config: any) => {
      const modelId = parseInt(
        config.url.match(/\/api\/cms\/contents\/(\d+)$/)[1]
      );
      const {
        page = 1,
        pageSize = 20,
        keyword,
        category_id,
        status,
      } = config.query || {};

      let items = contents[modelId] || [];

      // 关键词搜索
      if (keyword) {
        items = items.filter((item) =>
          Object.values(item.fields).some((v) =>
            String(v).toLowerCase().includes(keyword.toLowerCase())
          )
        );
      }

      // 分类筛选
      if (category_id) {
        items = items.filter(
          (item) => item.category_id === Number(category_id)
        );
      }

      // 状态筛选
      if (status !== undefined && status !== '') {
        items = items.filter((item) => item.status === Number(status));
      }

      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const pageItems = items.slice(start, end);

      return {
        code: 200,
        msg: 'success',
        data: {
          items: pageItems,
          total: items.length,
          page: Number(page),
          pageSize: Number(pageSize),
        },
      };
    },
  },

  // 获取内容详情
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)$/,
    method: 'get',
    response: (config: any) => {
      const match = config.url.match(/\/api\/cms\/contents\/(\d+)\/(\d+)$/);
      const modelId = parseInt(match[1]);
      const id = parseInt(match[2]);

      const item = contents[modelId]?.find((c) => c.id === id);

      if (!item) {
        return {
          code: 404,
          msg: '内容不存在',
          data: null,
        };
      }

      return {
        code: 200,
        msg: 'success',
        data: item,
      };
    },
  },

  // 创建内容
  {
    url: /\/api\/cms\/contents\/(\d+)$/,
    method: 'post',
    response: (config: any) => {
      const modelId = parseInt(
        config.url.match(/\/api\/cms\/contents\/(\d+)$/)[1]
      );
      const data = JSON.parse(config.body);

      if (!contents[modelId]) {
        contents[modelId] = [];
      }

      const newContent: Content = {
        id: contents[modelId].length + 1,
        model_id: modelId,
        category_id: data.category_id,
        category_name: data.category_name,
        tag_ids: data.tag_ids,
        tags: data.tags,
        status: data.status || 0,
        fields: data.fields || {},
        created_by: 1,
        created_at: new Date().toLocaleString(),
        updated_at: new Date().toLocaleString(),
      };

      contents[modelId].push(newContent);

      return {
        code: 200,
        msg: '创建成功',
        data: newContent,
      };
    },
  },

  // 更新内容
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)$/,
    method: 'put',
    response: (config: any) => {
      const match = config.url.match(/\/api\/cms\/contents\/(\d+)\/(\d+)$/);
      const modelId = parseInt(match[1]);
      const id = parseInt(match[2]);
      const data = JSON.parse(config.body);

      const index = contents[modelId]?.findIndex((c) => c.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '内容不存在',
          data: null,
        };
      }

      contents[modelId][index] = {
        ...contents[modelId][index],
        ...data,
        updated_at: new Date().toLocaleString(),
      };

      return {
        code: 200,
        msg: '更新成功',
        data: contents[modelId][index],
      };
    },
  },

  // 删除内容
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)$/,
    method: 'delete',
    response: (config: any) => {
      const match = config.url.match(/\/api\/cms\/contents\/(\d+)\/(\d+)$/);
      const modelId = parseInt(match[1]);
      const id = parseInt(match[2]);

      const index = contents[modelId]?.findIndex((c) => c.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '内容不存在',
          data: null,
        };
      }

      contents[modelId].splice(index, 1);

      return {
        code: 200,
        msg: '删除成功',
        data: null,
      };
    },
  },

  // 发布内容
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)\/publish$/,
    method: 'post',
    response: (config: any) => {
      const match = config.url.match(
        /\/api\/cms\/contents\/(\d+)\/(\d+)\/publish$/
      );
      const modelId = parseInt(match[1]);
      const id = parseInt(match[2]);

      const index = contents[modelId]?.findIndex((c) => c.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '内容不存在',
          data: null,
        };
      }

      contents[modelId][index].status = 2;
      contents[modelId][index].published_at = new Date().toLocaleString();

      return {
        code: 200,
        msg: '发布成功',
        data: contents[modelId][index],
      };
    },
  },

  // 下线内容
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)\/unpublish$/,
    method: 'post',
    response: (config: any) => {
      const match = config.url.match(
        /\/api\/cms\/contents\/(\d+)\/(\d+)\/unpublish$/
      );
      const modelId = parseInt(match[1]);
      const id = parseInt(match[2]);

      const index = contents[modelId]?.findIndex((c) => c.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '内容不存在',
          data: null,
        };
      }

      contents[modelId][index].status = 0;

      return {
        code: 200,
        msg: '下线成功',
        data: contents[modelId][index],
      };
    },
  },

  // 批量发布
  {
    url: /\/api\/cms\/contents\/(\d+)\/batch\/publish$/,
    method: 'post',
    response: (config: any) => {
      const modelId = parseInt(
        config.url.match(/\/api\/cms\/contents\/(\d+)\/batch\/publish$/)[1]
      );
      const { ids } = JSON.parse(config.body);

      ids.forEach((id: number) => {
        const index = contents[modelId]?.findIndex((c) => c.id === id);
        if (index !== -1) {
          contents[modelId][index].status = 2;
          contents[modelId][index].published_at = new Date().toLocaleString();
        }
      });

      return {
        code: 200,
        msg: '批量发布成功',
        data: null,
      };
    },
  },

  // 批量删除
  {
    url: /\/api\/cms\/contents\/(\d+)\/batch\/delete$/,
    method: 'post',
    response: (config: any) => {
      const modelId = parseInt(
        config.url.match(/\/api\/cms\/contents\/(\d+)\/batch\/delete$/)[1]
      );
      const { ids } = JSON.parse(config.body);

      contents[modelId] =
        contents[modelId]?.filter((c) => !ids.includes(c.id)) || [];

      return {
        code: 200,
        msg: '批量删除成功',
        data: null,
      };
    },
  },

  // ==================== 分类管理 ====================
  // 获取分类列表
  {
    url: '/api/cms/categories',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: categories,
      };
    },
  },

  // 获取分类详情
  {
    url: /\/api\/cms\/categories\/(\d+)$/,
    method: 'get',
    response: (config: any) => {
      const id = parseInt(
        config.url.match(/\/api\/cms\/categories\/(\d+)$/)[1]
      );
      const category = categories.find((c) => c.id === id);

      if (!category) {
        return {
          code: 404,
          msg: '分类不存在',
          data: null,
        };
      }

      return {
        code: 200,
        msg: 'success',
        data: category,
      };
    },
  },

  // 创建分类
  {
    url: '/api/cms/categories',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body);

      const newCategory: Category = {
        id: categories.length + 1,
        name: data.name,
        slug: data.slug,
        parent_id: data.parent_id,
        sort: data.sort || 0,
        status: data.status ?? 1,
        description: data.description,
        seo_title: data.seo_title,
        seo_keywords: data.seo_keywords,
        seo_description: data.seo_description,
        content_count: 0,
        created_at: new Date().toLocaleString(),
      };

      categories.push(newCategory);

      return {
        code: 200,
        msg: '创建成功',
        data: newCategory,
      };
    },
  },

  // 更新分类
  {
    url: /\/api\/cms\/categories\/(\d+)$/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(
        config.url.match(/\/api\/cms\/categories\/(\d+)$/)[1]
      );
      const data = JSON.parse(config.body);

      const index = categories.findIndex((c) => c.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '分类不存在',
          data: null,
        };
      }

      categories[index] = {
        ...categories[index],
        ...data,
        updated_at: new Date().toLocaleString(),
      };

      return {
        code: 200,
        msg: '更新成功',
        data: categories[index],
      };
    },
  },

  // 删除分类
  {
    url: /\/api\/cms\/categories\/(\d+)$/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(
        config.url.match(/\/api\/cms\/categories\/(\d+)$/)[1]
      );

      const index = categories.findIndex((c) => c.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '分类不存在',
          data: null,
        };
      }

      // 删除分类及其子分类
      const deleteIds = [id];
      const findChildren = (parentId: number) => {
        categories
          .filter((c) => c.parent_id === parentId)
          .forEach((c) => {
            deleteIds.push(c.id);
            findChildren(c.id);
          });
      };
      findChildren(id);

      deleteIds.forEach((delId) => {
        const idx = categories.findIndex((c) => c.id === delId);
        if (idx !== -1) {
          categories.splice(idx, 1);
        }
      });

      return {
        code: 200,
        msg: '删除成功',
        data: null,
      };
    },
  },

  // 分类排序
  {
    url: '/api/cms/categories/sort',
    method: 'post',
    response: (config: any) => {
      const { id, parent_id, sort } = JSON.parse(config.body);

      const index = categories.findIndex((c) => c.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '分类不存在',
          data: null,
        };
      }

      categories[index].parent_id = parent_id;
      categories[index].sort = sort;

      return {
        code: 200,
        msg: '排序成功',
        data: categories[index],
      };
    },
  },

  // ==================== 标签管理 ====================
  // 获取标签列表
  {
    url: '/api/cms/tags',
    method: 'get',
    response: (config: any) => {
      const { page = 1, pageSize = 20, keyword } = config.query || {};

      let items = tags;

      // 关键词搜索
      if (keyword) {
        items = items.filter((item) =>
          item.name.toLowerCase().includes(keyword.toLowerCase())
        );
      }

      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const pageItems = items.slice(start, end);

      return {
        code: 200,
        msg: 'success',
        data: {
          items: pageItems,
          total: items.length,
          page: Number(page),
          pageSize: Number(pageSize),
        },
      };
    },
  },

  // 创建标签
  {
    url: '/api/cms/tags',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body);

      const newTag: Tag = {
        id: tags.length + 1,
        name: data.name,
        slug: data.slug,
        color: data.color,
        count: 0,
        status: data.status ?? 1,
        created_at: new Date().toLocaleString(),
      };

      tags.push(newTag);

      return {
        code: 200,
        msg: '创建成功',
        data: newTag,
      };
    },
  },

  // 更新标签
  {
    url: /\/api\/cms\/tags\/(\d+)$/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/cms\/tags\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);

      const index = tags.findIndex((t) => t.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '标签不存在',
          data: null,
        };
      }

      tags[index] = {
        ...tags[index],
        ...data,
        updated_at: new Date().toLocaleString(),
      };

      return {
        code: 200,
        msg: '更新成功',
        data: tags[index],
      };
    },
  },

  // 删除标签
  {
    url: /\/api\/cms\/tags\/(\d+)$/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/cms\/tags\/(\d+)$/)[1]);

      const index = tags.findIndex((t) => t.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '标签不存在',
          data: null,
        };
      }

      tags.splice(index, 1);

      return {
        code: 200,
        msg: '删除成功',
        data: null,
      };
    },
  },

  // ==================== 媒体库 ====================
  // 获取文件夹列表
  {
    url: '/api/cms/media/folders',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: mediaFolders,
      };
    },
  },

  // 创建文件夹
  {
    url: '/api/cms/media/folders',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body);

      const newFolder: MediaFolder = {
        id: mediaFolders.length + 1,
        name: data.name,
        parent_id: data.parent_id,
        created_at: new Date().toLocaleString(),
      };

      mediaFolders.push(newFolder);

      return {
        code: 200,
        msg: '创建成功',
        data: newFolder,
      };
    },
  },

  // 更新文件夹
  {
    url: /\/api\/cms\/media\/folders\/(\d+)$/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(
        config.url.match(/\/api\/cms\/media\/folders\/(\d+)$/)[1]
      );
      const data = JSON.parse(config.body);

      const index = mediaFolders.findIndex((f) => f.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '文件夹不存在',
          data: null,
        };
      }

      mediaFolders[index] = {
        ...mediaFolders[index],
        ...data,
      };

      return {
        code: 200,
        msg: '更新成功',
        data: mediaFolders[index],
      };
    },
  },

  // 删除文件夹
  {
    url: /\/api\/cms\/media\/folders\/(\d+)$/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(
        config.url.match(/\/api\/cms\/media\/folders\/(\d+)$/)[1]
      );

      const index = mediaFolders.findIndex((f) => f.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '文件夹不存在',
          data: null,
        };
      }

      mediaFolders.splice(index, 1);

      return {
        code: 200,
        msg: '删除成功',
        data: null,
      };
    },
  },

  // 获取媒体文件列表
  {
    url: '/api/cms/media',
    method: 'get',
    response: (config: any) => {
      const {
        page = 1,
        pageSize = 20,
        folder_id,
        keyword,
        type,
      } = config.query || {};

      let items = mediaFiles;

      // 文件夹筛选
      if (folder_id) {
        items = items.filter((item) => item.folder_id === Number(folder_id));
      }

      // 关键词搜索
      if (keyword) {
        items = items.filter((item) =>
          item.name.toLowerCase().includes(keyword.toLowerCase())
        );
      }

      // 类型筛选
      if (type) {
        items = items.filter((item) => item.type === type);
      }

      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const pageItems = items.slice(start, end);

      return {
        code: 200,
        msg: 'success',
        data: {
          items: pageItems,
          total: items.length,
          page: Number(page),
          pageSize: Number(pageSize),
        },
      };
    },
  },

  // 上传文件
  {
    url: '/api/cms/media/upload',
    method: 'post',
    response: (config: any) => {
      const newMedia: Media = {
        id: mediaFiles.length + 1,
        name: `file_${mediaFiles.length + 1}.jpg`,
        url: Mock.Random.image('400x300'),
        type: 'image',
        size: Mock.Random.integer(100000, 5000000),
        folder_id: 1,
        created_at: new Date().toLocaleString(),
      };

      mediaFiles.push(newMedia);

      return {
        code: 200,
        msg: '上传成功',
        data: newMedia,
      };
    },
  },

  // 删除文件
  {
    url: /\/api\/cms\/media\/(\d+)$/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/cms\/media\/(\d+)$/)[1]);

      const index = mediaFiles.findIndex((m) => m.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '文件不存在',
          data: null,
        };
      }

      mediaFiles.splice(index, 1);

      return {
        code: 200,
        msg: '删除成功',
        data: null,
      };
    },
  },

  // ==================== 版本管理 ====================
  // 获取内容版本列表
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)\/versions$/,
    method: 'get',
    response: (config: any) => {
      const match = config.url.match(
        /\/api\/cms\/contents\/(\d+)\/(\d+)\/versions$/
      );
      const modelId = parseInt(match[1]);
      const contentId = parseInt(match[2]);

      const versions = generateVersionForContent(modelId, contentId);

      return {
        code: 200,
        msg: 'success',
        data: versions,
      };
    },
  },

  // 版本回滚
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)\/versions\/(\d+)\/rollback$/,
    method: 'post',
    response: (config: any) => {
      const match = config.url.match(
        /\/api\/cms\/contents\/(\d+)\/(\d+)\/versions\/(\d+)\/rollback$/
      );
      const modelId = parseInt(match[1]);
      const contentId = parseInt(match[2]);
      const versionId = parseInt(match[3]);

      // 找到对应的内容并更新
      const contentList = contents[modelId];
      if (contentList) {
        const index = contentList.findIndex((c) => c.id === contentId);
        if (index !== -1) {
          const key = `${modelId}_${contentId}`;
          const versions = contentVersions[key] || [];
          const version = versions.find((v) => v.version_id === versionId);

          if (version) {
            contentList[index].fields = { ...version.data };
            contentList[index].updated_at = new Date().toLocaleString();

            // 创建新版本记录
            versions.unshift({
              id: versions.length + 1,
              content_id: contentId,
              version: versions.length + 1,
              version_id: versions.length + 1,
              data: { ...version.data },
              change_summary: `回滚到版本 v${version.version}`,
              created_by: 1,
              created_by_name: '管理员',
              created_at: new Date().toLocaleString(),
            });
          }
        }
      }

      return {
        code: 200,
        msg: '回滚成功',
        data: null,
      };
    },
  },

  // 版本对比
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)\/versions\/(\d+)\/compare$/,
    method: 'get',
    response: (config: any) => {
      const match = config.url.match(
        /\/api\/cms\/contents\/(\d+)\/(\d+)\/versions\/(\d+)\/compare$/
      );
      const modelId = parseInt(match[1]);
      const contentId = parseInt(match[2]);
      const versionId = parseInt(match[3]);

      const key = `${modelId}_${contentId}`;
      const versions = contentVersions[key] || [];
      const currentVersion = versions[0];
      const compareVersion = versions.find((v) => v.version_id === versionId);

      return {
        code: 200,
        msg: 'success',
        data: {
          current: currentVersion?.data || {},
          compare: compareVersion?.data || {},
        },
      };
    },
  },

  // ==================== 工作流管理 ====================
  // 获取工作流列表
  {
    url: '/api/cms/workflows',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: workflows,
      };
    },
  },

  // 创建工作流
  {
    url: '/api/cms/workflows',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body);

      const newWorkflow = {
        id: workflows.length + 1,
        ...data,
        created_at: new Date().toLocaleString(),
      };

      workflows.push(newWorkflow);

      return {
        code: 200,
        msg: '创建成功',
        data: newWorkflow,
      };
    },
  },

  // 更新工作流
  {
    url: /\/api\/cms\/workflows\/(\d+)$/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/cms\/workflows\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);

      const index = workflows.findIndex((w) => w.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '工作流不存在',
          data: null,
        };
      }

      workflows[index] = {
        ...workflows[index],
        ...data,
        updated_at: new Date().toLocaleString(),
      };

      return {
        code: 200,
        msg: '更新成功',
        data: workflows[index],
      };
    },
  },

  // 删除工作流
  {
    url: /\/api\/cms\/workflows\/(\d+)$/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/cms\/workflows\/(\d+)$/)[1]);

      const index = workflows.findIndex((w) => w.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '工作流不存在',
          data: null,
        };
      }

      workflows.splice(index, 1);

      return {
        code: 200,
        msg: '删除成功',
        data: null,
      };
    },
  },

  // 获取定时发布列表
  {
    url: '/api/cms/schedules',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: schedules,
      };
    },
  },

  // 取消定时发布
  {
    url: /\/api\/cms\/schedules\/(\d+)\/cancel$/,
    method: 'post',
    response: (config: any) => {
      const id = parseInt(
        config.url.match(/\/api\/cms\/schedules\/(\d+)\/cancel$/)[1]
      );

      const index = schedules.findIndex((s) => s.id === id);

      if (index !== -1) {
        schedules[index].status = 2;
      }

      return {
        code: 200,
        msg: '取消成功',
        data: null,
      };
    },
  },

  // 获取审批记录
  {
    url: '/api/cms/approvals',
    method: 'get',
    response: (config: any) => {
      const { status } = config.query || {};

      let items = approvalRecords;

      if (status !== undefined && status !== '') {
        items = items.filter((item) => item.status === Number(status));
      }

      return {
        code: 200,
        msg: 'success',
        data: items,
      };
    },
  },

  // 审批操作
  {
    url: /\/api\/cms\/approvals\/(\d+)\/approve$/,
    method: 'post',
    response: (config: any) => {
      const id = parseInt(
        config.url.match(/\/api\/cms\/approvals\/(\d+)\/approve$/)[1]
      );
      const { status, remark } = JSON.parse(config.body);

      const index = approvalRecords.findIndex((r) => r.id === id);

      if (index !== -1) {
        approvalRecords[index].status = status;
        approvalRecords[index].logs[0].status = status;
        approvalRecords[index].logs[0].remark = remark;
        approvalRecords[index].updated_at = new Date().toLocaleString();
      }

      return {
        code: 200,
        msg: '审批成功',
        data: null,
      };
    },
  },

  // ==================== 分类排序 ====================
  {
    url: '/api/cms/categories/sort',
    method: 'post',
    response: (config: any) => {
      const { id, parent_id, sort } = JSON.parse(config.body);

      const index = categories.findIndex((c) => c.id === id);

      if (index === -1) {
        return {
          code: 404,
          msg: '分类不存在',
          data: null,
        };
      }

      categories[index].parent_id = parent_id;
      categories[index].sort = sort;

      return {
        code: 200,
        msg: '排序成功',
        data: categories[index],
      };
    },
  },

  // 获取分类树
  {
    url: '/api/cms/categories/tree',
    method: 'get',
    response: () => {
      const buildTree = (items: any[], parentId?: number): any[] => {
        return items
          .filter((item) => item.parent_id === parentId)
          .map((item) => ({
            ...item,
            children: buildTree(items, item.id),
          }));
      };

      return {
        code: 200,
        msg: 'success',
        data: buildTree(categories),
      };
    },
  },

  // ==================== 标签合并 ====================
  {
    url: '/api/cms/tags/merge',
    method: 'post',
    response: (config: any) => {
      const { sourceId, targetId } = JSON.parse(config.body);

      const sourceIndex = tags.findIndex((t) => t.id === sourceId);
      const targetIndex = tags.findIndex((t) => t.id === targetId);

      if (sourceIndex === -1 || targetIndex === -1) {
        return {
          code: 404,
          msg: '标签不存在',
          data: null,
        };
      }

      // 合并使用次数
      tags[targetIndex].count += tags[sourceIndex].count;

      // 删除源标签
      tags.splice(sourceIndex, 1);

      // 更新内容中的标签引用
      Object.values(contents).forEach((contentList) => {
        contentList.forEach((content) => {
          if (content.tag_ids?.includes(sourceId)) {
            content.tag_ids = content.tag_ids.filter((id) => id !== sourceId);
            if (!content.tag_ids.includes(targetId)) {
              content.tag_ids.push(targetId);
            }
          }
        });
      });

      return {
        code: 200,
        msg: '合并成功',
        data: tags[targetIndex],
      };
    },
  },

  // ==================== 媒体库文件夹 ====================
  // 获取文件夹列表
  {
    url: '/api/cms/media/folders',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: mediaFolders,
      };
    },
  },

  // 获取文件夹树
  {
    url: '/api/cms/media/folders/tree',
    method: 'get',
    response: () => {
      const buildTree = (items: any[], parentId?: number): any[] => {
        return items
          .filter((item) => item.parent_id === parentId)
          .map((item) => ({
            ...item,
            children: buildTree(items, item.id),
          }));
      };

      return {
        code: 200,
        msg: 'success',
        data: buildTree(mediaFolders),
      };
    },
  },

  // 批量删除媒体文件
  {
    url: '/api/cms/media/batch/delete',
    method: 'post',
    response: (config: any) => {
      const { ids } = JSON.parse(config.body);

      ids.forEach((id: number) => {
        const index = mediaFiles.findIndex((m) => m.id === id);
        if (index !== -1) {
          mediaFiles.splice(index, 1);
        }
      });

      return {
        code: 200,
        msg: '批量删除成功',
        data: null,
      };
    },
  },

  // 分片上传
  {
    url: '/api/cms/media/upload/chunk',
    method: 'post',
    response: () => {
      return {
        code: 200,
        msg: '分片上传成功',
        data: { chunkId: Mock.Random.guid() },
      };
    },
  },

  // 合并分片
  {
    url: '/api/cms/media/upload/merge',
    method: 'post',
    response: (config: any) => {
      const { fileId } = JSON.parse(config.body);

      const newMedia: any = {
        id: mediaFiles.length + 1,
        name: `merged_${fileId}.jpg`,
        url: Mock.Random.image('400x300'),
        type: 'image',
        size: Mock.Random.integer(1000000, 10000000),
        folder_id: 1,
        created_at: new Date().toLocaleString(),
      };

      mediaFiles.push(newMedia);

      return {
        code: 200,
        msg: '合并成功',
        data: newMedia,
      };
    },
  },

  // ==================== 内容版本对比 ====================
  {
    url: /\/api\/cms\/contents\/(\d+)\/(\d+)\/versions\/compare$/,
    method: 'get',
    response: (config: any) => {
      const { v1, v2 } = config.query || {};

      return {
        code: 200,
        msg: 'success',
        data: {
          v1: { title: `版本 ${v1}`, content: `内容 ${v1}` },
          v2: { title: `版本 ${v2}`, content: `内容 ${v2}` },
        },
      };
    },
  },

  // ==================== 模板管理 ====================
  {
    url: '/api/cms/templates',
    method: 'get',
    response: (config: any) => {
      const { page = 1, pageSize = 20 } = config.query || {};

      const templates = [
        {
          id: 1,
          name: '文章详情模板',
          code: 'article_detail',
          content: '<div>{{title}}</div><div>{{content}}</div>',
          status: 1,
          created_at: '2026-01-01 10:00:00',
        },
      ];

      return {
        code: 200,
        msg: 'success',
        data: {
          items: templates,
          total: templates.length,
          page: Number(page),
          pageSize: Number(pageSize),
        },
      };
    },
  },

  {
    url: '/api/cms/templates',
    method: 'post',
    response: () => {
      return {
        code: 200,
        msg: '创建成功',
        data: { id: 2 },
      };
    },
  },

  {
    url: /\/api\/cms\/templates\/(\d+)$/,
    method: 'put',
    response: () => {
      return {
        code: 200,
        msg: '更新成功',
        data: null,
      };
    },
  },

  {
    url: /\/api\/cms\/templates\/(\d+)$/,
    method: 'delete',
    response: () => {
      return {
        code: 200,
        msg: '删除成功',
        data: null,
      };
    },
  },

  // ==================== 翻译管理 ====================
  {
    url: /\/api\/cms\/translations\/(\d+)$/,
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: [
          {
            id: 1,
            content_id: 1,
            language: 'en',
            fields: { title: 'English Title', content: 'English Content' },
            status: 1,
            created_at: '2026-01-01 10:00:00',
          },
        ],
      };
    },
  },

  {
    url: /\/api\/cms\/translations\/(\d+)$/,
    method: 'post',
    response: () => {
      return {
        code: 200,
        msg: '保存成功',
        data: { id: 2 },
      };
    },
  },

  // ==================== SEO 工具 ====================
  {
    url: '/api/cms/seo/sitemap/generate',
    method: 'post',
    response: () => {
      return {
        code: 200,
        msg: 'Sitemap 生成成功',
        data: { url: '/sitemap.xml' },
      };
    },
  },

  {
    url: '/api/cms/seo/sitemap/status',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: {
          lastGenerated: '2026-02-25 10:00:00',
          totalUrls: 150,
          status: 'success',
        },
      };
    },
  },

  // ==================== 缓存管理 ====================
  {
    url: '/api/cms/cache/clear',
    method: 'post',
    response: (config: any) => {
      const { type } = JSON.parse(config.body);

      return {
        code: 200,
        msg: `${type} 缓存清除成功`,
        data: null,
      };
    },
  },

  {
    url: '/api/cms/cache/stats',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: {
          pageCache: { size: '125MB', hits: 15000, misses: 500 },
          apiCache: { size: '45MB', hits: 8000, misses: 200 },
          totalSize: '170MB',
        },
      };
    },
  },

  // ==================== CMS 统计 ====================
  {
    url: '/api/cms/stats',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: {
          totalContents: 35,
          publishedContents: 25,
          pendingApprovals: 3,
          totalMedia: 30,
        },
      };
    },
  },

  // 获取最近内容
  {
    url: '/api/cms/contents/recent',
    method: 'get',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: [
          {
            id: 1,
            title: '示例文章1',
            model_name: '文章',
            status: 2,
            created_at: '2026-02-25 10:00:00',
          },
          {
            id: 2,
            title: '示例文章2',
            model_name: '文章',
            status: 0,
            created_at: '2026-02-25 09:00:00',
          },
        ],
      };
    },
  },
];
