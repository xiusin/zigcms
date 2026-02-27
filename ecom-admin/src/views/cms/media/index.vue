<template>
  <div class="media-container">
    <a-layout>
      <a-layout-sider :width="260" class="folder-sider">
        <div class="folder-header">
          <h3>文件夹</h3>
          <a-button type="text" size="small" @click="handleAddFolder()">
            <template #icon><icon-plus /></template>
          </a-button>
        </div>
        <a-tree
          :data="folderTree"
          :selected-keys="[currentFolderId]"
          block-node
          @select="handleFolderSelect"
        >
          <template #title="nodeData">
            <div class="folder-node">
              <span>{{ nodeData.title }}</span>
              <div class="folder-actions">
                <a-button
                  type="text"
                  size="mini"
                  @click.stop="handleAddFolder(nodeData)"
                >
                  <template #icon><icon-plus /></template>
                </a-button>
                <a-button
                  type="text"
                  size="mini"
                  @click.stop="handleEditFolder(nodeData)"
                >
                  <template #icon><icon-edit /></template>
                </a-button>
                <a-popconfirm
                  v-if="nodeData.key !== '0'"
                  content="确定删除该文件夹吗？"
                  @ok="handleDeleteFolder(nodeData.key)"
                >
                  <a-button type="text" size="mini" status="danger" @click.stop>
                    <template #icon><icon-delete /></template>
                  </a-button>
                </a-popconfirm>
              </div>
            </div>
          </template>
        </a-tree>
      </a-layout-sider>

      <a-layout-content class="media-content">
        <div class="content-header">
          <a-space>
            <a-upload
              :custom-request="handleUpload"
              :show-file-list="false"
              multiple
            >
              <a-button type="primary">
                <template #icon><icon-upload /></template>
                上传文件
              </a-button>
            </a-upload>
            <a-button
              @click="viewMode = 'grid'"
              :type="viewMode === 'grid' ? 'primary' : 'default'"
            >
              <template #icon><icon-apps /></template>
            </a-button>
            <a-button
              @click="viewMode = 'list'"
              :type="viewMode === 'list' ? 'primary' : 'default'"
            >
              <template #icon><icon-list /></template>
            </a-button>
          </a-space>
          <a-space>
            <a-input-search
              v-model="searchKey"
              placeholder="搜索文件"
              style="width: 300px"
              @search="fetchData"
            />
            <a-select
              v-model="fileType"
              placeholder="文件类型"
              style="width: 120px"
              @change="fetchData"
            >
              <a-option value="">全部</a-option>
              <a-option value="image">图片</a-option>
              <a-option value="video">视频</a-option>
              <a-option value="document">文档</a-option>
            </a-select>
          </a-space>
        </div>

        <a-spin :loading="loading" style="width: 100%">
          <!-- 网格视图 -->
          <div v-if="viewMode === 'grid'" class="grid-view">
            <div
              v-for="item in mediaList"
              :key="item.id"
              class="media-item"
              @click="handlePreview(item)"
            >
              <div class="media-preview">
                <img
                  v-if="item.type === 'image'"
                  :src="item.url"
                  :alt="item.name"
                />
                <icon-file-video v-else-if="item.type === 'video'" :size="48" />
                <icon-file v-else :size="48" />
              </div>
              <div class="media-info">
                <div class="media-name" :title="item.name">{{ item.name }}</div>
                <div class="media-size">{{ formatSize(item.size) }}</div>
              </div>
              <div class="media-actions">
                <a-button
                  type="text"
                  size="mini"
                  @click.stop="handleDownload(item)"
                >
                  <template #icon><icon-download /></template>
                </a-button>
                <a-popconfirm
                  content="确定删除该文件吗？"
                  @ok="handleDelete(item.id)"
                >
                  <a-button type="text" size="mini" status="danger" @click.stop>
                    <template #icon><icon-delete /></template>
                  </a-button>
                </a-popconfirm>
              </div>
            </div>
          </div>

          <!-- 列表视图 -->
          <a-table
            v-else
            :data="mediaList"
            :pagination="pagination"
            @page-change="handlePageChange"
          >
            <template #columns>
              <a-table-column title="预览" :width="80">
                <template #cell="{ record }">
                  <img
                    v-if="record.type === 'image'"
                    :src="record.url"
                    style="
                      width: 50px;
                      height: 50px;
                      object-fit: cover;
                      border-radius: 4px;
                    "
                  />
                  <icon-file-video
                    v-else-if="record.type === 'video'"
                    :size="32"
                  />
                  <icon-file v-else :size="32" />
                </template>
              </a-table-column>
              <a-table-column title="文件名" data-index="name" />
              <a-table-column title="类型" data-index="type" :width="100" />
              <a-table-column title="大小" :width="120">
                <template #cell="{ record }">{{
                  formatSize(record.size)
                }}</template>
              </a-table-column>
              <a-table-column
                title="上传时间"
                data-index="created_at"
                :width="180"
              />
              <a-table-column title="操作" :width="150" fixed="right">
                <template #cell="{ record }">
                  <a-space>
                    <a-button
                      type="text"
                      size="small"
                      @click="handlePreview(record)"
                    >
                      预览
                    </a-button>
                    <a-button
                      type="text"
                      size="small"
                      @click="handleDownload(record)"
                    >
                      下载
                    </a-button>
                    <a-popconfirm
                      content="确定删除吗？"
                      @ok="handleDelete(record.id)"
                    >
                      <a-button type="text" size="small" status="danger"
                        >删除</a-button
                      >
                    </a-popconfirm>
                  </a-space>
                </template>
              </a-table-column>
            </template>
          </a-table>
        </a-spin>
      </a-layout-content>
    </a-layout>

    <!-- 文件夹编辑弹窗 -->
    <a-modal
      v-model:visible="folderModalVisible"
      :title="folderModalTitle"
      width="400px"
      @before-ok="handleFolderSubmit"
    >
      <a-form :model="folderForm" ref="folderFormRef" layout="vertical">
        <a-form-item label="文件夹名称" field="name" required>
          <a-input v-model="folderForm.name" placeholder="请输入文件夹名称" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 文件预览弹窗 -->
    <a-modal
      v-model:visible="previewVisible"
      :title="previewFile?.name"
      width="800px"
      :footer="false"
    >
      <div class="preview-content">
        <img
          v-if="previewFile?.type === 'image'"
          :src="previewFile.url"
          style="max-width: 100%"
        />
        <video
          v-else-if="previewFile?.type === 'video'"
          :src="previewFile.url"
          controls
          style="max-width: 100%"
        />
        <div v-else class="file-info">
          <icon-file :size="64" />
          <p>{{ previewFile?.name }}</p>
          <p>大小: {{ formatSize(previewFile?.size || 0) }}</p>
        </div>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import {
    IconPlus,
    IconEdit,
    IconDelete,
    IconUpload,
    IconApps,
    IconList,
    IconFile,
    IconFileVideo,
    IconDownload,
  } from '@arco-design/web-vue/es/icon';
  import type { TreeNodeData } from '@arco-design/web-vue';
  import {
    getMediaList,
    uploadMedia,
    deleteMedia,
    getMediaFolders,
    createMediaFolder,
    updateMediaFolder,
    deleteMediaFolder,
  } from '@/api/cms';
  import type { Media, MediaFolder } from '@/types/cms';

  const loading = ref(false);
  const viewMode = ref<'grid' | 'list'>('grid');
  const mediaList = ref<Media[]>([]);
  const folders = ref<MediaFolder[]>([]);
  const currentFolderId = ref('0');
  const searchKey = ref('');
  const fileType = ref('');

  const pagination = reactive({
    current: 1,
    pageSize: 20,
    total: 0,
    showTotal: true,
  });

  // 文件夹
  const folderModalVisible = ref(false);
  const folderModalTitle = ref('');
  const folderFormRef = ref();
  const folderForm = ref({
    name: '',
    parent_id: undefined as number | undefined,
  });
  const isEditFolder = ref(false);
  const editFolderId = ref<number>();

  // 预览
  const previewVisible = ref(false);
  const previewFile = ref<Media>();

  // 构建文件夹树
  const buildFolderTree = (
    items: MediaFolder[],
    parentId?: number
  ): TreeNodeData[] => {
    return items
      .filter((item) => item.parent_id === parentId)
      .map((item) => ({
        key: String(item.id),
        title: item.name,
        children: buildFolderTree(items, item.id),
      }));
  };

  const folderTree = computed(() => [
    { key: '0', title: '全部文件', children: buildFolderTree(folders.value) },
  ]);

  // 加载数据
  const fetchData = async () => {
    loading.value = true;
    try {
      const res = await getMediaList({
        page: pagination.current,
        pageSize: pagination.pageSize,
        folder_id:
          currentFolderId.value === '0'
            ? undefined
            : Number(currentFolderId.value),
        keyword: searchKey.value,
        type: fileType.value,
      });
      mediaList.value = res.data.items || [];
      pagination.total = res.data.total || 0;
    } catch (error) {
      Message.error('加载失败');
    } finally {
      loading.value = false;
    }
  };

  const fetchFolders = async () => {
    try {
      const res = await getMediaFolders();
      folders.value = res.data || [];
    } catch (error) {
      Message.error('加载文件夹失败');
    }
  };

  const handlePageChange = (page: number) => {
    pagination.current = page;
    fetchData();
  };

  const handleFolderSelect = (keys: string[]) => {
    currentFolderId.value = keys[0] || '0';
    pagination.current = 1;
    fetchData();
  };

  // 上传
  const handleUpload = async (option: any) => {
    const formData = new FormData();
    formData.append('file', option.fileItem.file);
    formData.append('folder_id', currentFolderId.value);

    try {
      await uploadMedia(formData);
      Message.success('上传成功');
      await fetchData();
    } catch (error) {
      Message.error('上传失败');
    }
  };

  // 文件夹操作
  const handleAddFolder = (node?: TreeNodeData) => {
    folderModalTitle.value = '新建文件夹';
    isEditFolder.value = false;
    folderForm.value = {
      name: '',
      parent_id: node ? Number(node.key) : undefined,
    };
    folderModalVisible.value = true;
  };

  const handleEditFolder = (node: TreeNodeData) => {
    folderModalTitle.value = '编辑文件夹';
    isEditFolder.value = true;
    editFolderId.value = Number(node.key);
    const folder = folders.value.find((f) => f.id === Number(node.key));
    if (folder) {
      folderForm.value = { name: folder.name, parent_id: folder.parent_id };
    }
    folderModalVisible.value = true;
  };

  const handleDeleteFolder = async (key: string) => {
    try {
      await deleteMediaFolder(Number(key));
      Message.success('删除成功');
      await fetchFolders();
    } catch (error) {
      Message.error('删除失败');
    }
  };

  const handleFolderSubmit = async () => {
    try {
      if (isEditFolder.value) {
        await updateMediaFolder(editFolderId.value!, folderForm.value);
        Message.success('更新成功');
      } else {
        await createMediaFolder(folderForm.value);
        Message.success('创建成功');
      }
      folderModalVisible.value = false;
      await fetchFolders();
      return true;
    } catch (error) {
      Message.error('操作失败');
      return false;
    }
  };

  // 文件操作
  const handlePreview = (item: Media) => {
    previewFile.value = item;
    previewVisible.value = true;
  };

  const handleDownload = (item: Media) => {
    const a = document.createElement('a');
    a.href = item.url;
    a.download = item.name;
    a.click();
  };

  const handleDelete = async (id: number) => {
    try {
      await deleteMedia(id);
      Message.success('删除成功');
      await fetchData();
    } catch (error) {
      Message.error('删除失败');
    }
  };

  const formatSize = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
  };

  onMounted(() => {
    fetchFolders();
    fetchData();
  });
</script>

<style scoped lang="less">
  .media-container {
    height: calc(100vh - 100px);
    padding: 20px;

    .arco-layout {
      height: 100%;
      background: #fff;
      border-radius: 4px;
    }
  }

  .folder-sider {
    border-right: 1px solid var(--color-border);
    padding: 16px;

    .folder-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;

      h3 {
        margin: 0;
      }
    }

    .folder-node {
      display: flex;
      align-items: center;
      justify-content: space-between;
      width: 100%;

      .folder-actions {
        display: none;
        gap: 4px;
      }

      &:hover .folder-actions {
        display: flex;
      }
    }
  }

  .media-content {
    padding: 16px;

    .content-header {
      display: flex;
      justify-content: space-between;
      margin-bottom: 16px;
    }

    .grid-view {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
      gap: 16px;

      .media-item {
        border: 1px solid var(--color-border);
        border-radius: 4px;
        padding: 12px;
        cursor: pointer;
        transition: all 0.3s;

        &:hover {
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);

          .media-actions {
            display: flex;
          }
        }

        .media-preview {
          width: 100%;
          height: 120px;
          display: flex;
          align-items: center;
          justify-content: center;
          background: var(--color-fill-2);
          border-radius: 4px;
          margin-bottom: 8px;

          img {
            max-width: 100%;
            max-height: 100%;
            object-fit: cover;
          }
        }

        .media-info {
          .media-name {
            font-size: 14px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            margin-bottom: 4px;
          }

          .media-size {
            font-size: 12px;
            color: var(--color-text-3);
          }
        }

        .media-actions {
          display: none;
          justify-content: center;
          gap: 8px;
          margin-top: 8px;
        }
      }
    }
  }

  .preview-content {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 300px;

    .file-info {
      text-align: center;

      p {
        margin-top: 16px;
      }
    }
  }
</style>
