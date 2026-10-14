/**
 * Amis 组件导出
 */
import AmisRenderer from './index.vue';
import AmisEditor from './editor.vue';

export { AmisRenderer, AmisEditor };
export type {
  AmisSchema,
  PageConfig,
  PageCategory,
  AmisProps,
  AmisEditorProps,
} from '@/types/amis.d';
export { SchemaTemplates } from '@/types/amis.d';
