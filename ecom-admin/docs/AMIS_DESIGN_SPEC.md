# Amis 组件尺寸规范

## 设计原则
- 字体大小：统一 12px
- 组件高度：统一 32px
- 行高：1.5（18px）
- 内边距：水平 12px，垂直根据组件调整

## 组件尺寸对照表

### 表单组件
| 组件 | 高度 | 字体 | 行高 | padding | 说明 |
|------|------|------|------|---------|------|
| Input | 32px | 12px | 1.5 | 0 12px | 单行输入框 |
| Textarea | auto | 12px | 1.5 | 8px 12px | 多行文本，最小64px |
| Select | 32px | 12px | 1.5 | 0 12px | 下拉选择 |
| DatePicker | 32px | 12px | 1.5 | 0 12px | 日期选择 |
| NumberPicker | 32px | 12px | 1.5 | 0 12px | 数字输入 |
| Form Label | auto | 12px | 32px | - | 表单标签，行高与输入框对齐 |

### 按钮组件
| 组件 | 高度 | 字体 | 行高 | padding | 说明 |
|------|------|------|------|---------|------|
| Button | 32px | 12px | 1 | 0 16px | 所有类型按钮 |
| Button Icon | 24px | - | - | - | 按钮内图标 |

### 表格组件
| 组件 | 高度 | 字体 | 行高 | padding | 说明 |
|------|------|------|------|---------|------|
| Table Header | 44px | 12px | 1.5 | 10px 12px | 表头 |
| Table Cell | 40px | 12px | 1.5 | 8px 12px | 单元格 |
| Pagination | 32px | 12px | 1 | - | 分页按钮 |

### 弹窗组件
| 组件 | 高度 | 字体 | 行高 | padding | 说明 |
|------|------|------|------|---------|------|
| Modal Header | auto | 14px | 20px | 10px 16px | 弹窗标题 |
| Modal Body | auto | 12px | 1.5 | 20px | 弹窗内容 |
| Modal Footer | auto | 12px | 1 | 10px 20px | 弹窗底部 |
| Modal Close | 24px | - | - | - | 关闭按钮 |

### 其他组件
| 组件 | 高度 | 字体 | 行高 | padding | 说明 |
|------|------|------|------|---------|------|
| Switch | 22px | - | - | - | 开关 |
| Checkbox | 16px | 12px | 1.5 | - | 复选框 |
| Radio | 16px | 12px | 1.5 | - | 单选框 |
| Tag | auto | 12px | 1.5 | 2px 8px | 标签 |

## CSS 变量设置

```less
.amis-wrapper {
  // 基础字体
  --fontSizeBase: 12px;
  
  // 表单
  --Form-input-height: 32px;
  --Form-input-fontSize: 12px;
  --Form-input-lineHeight: 1.5;
  --Form-label-fontSize: 12px;
  
  // 按钮
  --Button-height: 32px;
  --Button-fontSize: 12px;
  
  // 表格
  --Table-thead-fontSize: 12px;
  --Table-fontSize: 12px;
  
  // 其他
  --gap-base: 8px;
  --gap-sm: 4px;
  --gap-md: 12px;
  --gap-lg: 16px;
}
```

## 视觉协调检查清单

### 垂直对齐
- [ ] 表单标签与输入框垂直居中对齐
- [ ] 按钮文字垂直居中
- [ ] 表格单元格内容垂直居中
- [ ] 下拉选项文字垂直居中

### 水平间距
- [ ] 输入框内边距一致（12px）
- [ ] 按钮内边距一致（16px）
- [ ] 表格单元格内边距一致（12px）
- [ ] 弹窗内边距协调

### 字体大小
- [ ] 所有正文文字 12px
- [ ] 弹窗标题 14px
- [ ] 表格表头 12px（加粗）
- [ ] 按钮文字 12px

### 组件高度
- [ ] 所有输入类组件 32px
- [ ] 所有按钮 32px
- [ ] 表格行高度 40px
- [ ] 表格表头高度 44px

## 常见问题修复

### 问题1：输入框文字不居中
**原因**：line-height 设置不当
**解决**：设置 `line-height: 1.5` 配合 `height: 32px`

### 问题2：按钮文字看不见
**原因**：子元素颜色未继承
**解决**：添加 `*, span, div { color: inherit !important; }`

### 问题3：表单标签与输入框不对齐
**原因**：标签行高与输入框高度不匹配
**解决**：设置标签 `line-height: 32px`

### 问题4：弹窗头部太高
**原因**：padding 过大
**解决**：调整为 `padding: 10px 16px`

### 问题5：组件尺寸不统一
**原因**：未使用 CSS 变量统一控制
**解决**：在 `.amis-wrapper` 根元素设置 CSS 变量

## 测试页面

访问 `/amis-button-test.html` 测试各组件显示效果。

## 更新日志

- 2026-02-22: 初始版本，定义基础规范
- 统一所有组件高度为 32px
- 统一字体大小为 12px
- 统一行高为 1.5
