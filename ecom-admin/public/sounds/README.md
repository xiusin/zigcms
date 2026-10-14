# 告警声音文件

## 文件要求

请在此目录下放置告警声音文件：

- **文件名**：`alert.mp3`
- **格式**：MP3
- **时长**：建议 1-3 秒
- **音量**：适中，不要太大声

## 获取声音文件

### 方式一：在线下载（推荐）

1. **Zapsplat**（免费）
   - 网址：https://www.zapsplat.com/
   - 搜索：alert, notification, beep
   - 下载后重命名为 `alert.mp3`

2. **Freesound**（免费）
   - 网址：https://freesound.org/
   - 搜索：notification sound
   - 下载后重命名为 `alert.mp3`

3. **Mixkit**（免费）
   - 网址：https://mixkit.co/free-sound-effects/notification/
   - 选择合适的通知音效
   - 下载后重命名为 `alert.mp3`

### 方式二：使用系统声音

可以从系统声音库中复制一个声音文件：

**macOS**：
```bash
cp /System/Library/Sounds/Glass.aiff alert.aiff
# 然后使用在线工具转换为 MP3
```

**Windows**：
```bash
# 从 C:\Windows\Media\ 目录复制声音文件
# 然后使用在线工具转换为 MP3
```

### 方式三：自己录制

使用手机或电脑录制一个简短的提示音，然后转换为 MP3 格式。

## 注意事项

1. 如果没有声音文件，系统仍然可以正常工作，只是不会播放声音
2. 声音文件会在用户启用"声音提醒"时播放
3. 建议使用简短、清晰的提示音，避免过于刺耳
4. 文件大小建议控制在 100KB 以内

## 测试声音

1. 将声音文件放置到此目录
2. 启动前端：`npm run dev`
3. 登录系统
4. 在通知设置中启用"声音提醒"
5. 等待新告警或手动触发测试

## 禁用声音

如果不需要声音提醒，可以在通知设置中关闭"声音提醒"开关。
