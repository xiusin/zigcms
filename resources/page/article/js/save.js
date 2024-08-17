layui.use(['form', 'layer', 'inputTag'], function () {
    var form = layui.form,
        layer = layui.layer,
        upload = layui.upload,
        inputTag = layui.inputTag,
        $ = layui.$;



    const E = window.wangEditor

    // 切换语言
    const LANG = location.href.indexOf('lang=en') > 0 ? 'en' : 'zh-CN'
    E.i18nChangeLanguage(LANG)

    // 默认内容
    let html = `<h1>简洁模式：</h1><ol><li>简化工具栏菜单</li><li>取消选中文字的悬浮菜单</li></ol><p><br></p>`
    if (LANG === 'en') html = `<h1>Simple&nbsp;mode.</h1><ol><li>Simplify&nbsp;toolbar&nbsp;menus</li><li>Hide&nbsp;hover-bar&nbsp;when&nbsp;selected&nbsp;text</li></ol><p><br></p>`

    window.editor = E.createEditor({
        selector: '#editor-text-area',
        html,
        mode: 'simple',
        config: {
            placeholder: 'Type here...',
            MENU_CONF: {
                uploadImage: {
                    fieldName: 'your-fileName',
                    base64LimitSize: 10 * 1024 * 1024 // 10M 以下插入 base64
                }
            },
            onChange() {
                console.log(editor.getHtml())

                // 选中文字
                const selectionText = editor.getSelectionText()
                document.getElementById('selected-length').innerHTML = selectionText.length
                // 全部文字
                // 全部文字
                const text = editor.getText().replace(/\n|\r/mg, '')
                document.getElementById('total-length').innerHTML = text.length
            }
        }
    })

    window.toolbar = E.createToolbar({
        editor,
        mode: 'simple',
        selector: '#editor-toolbar',
        config: {}
    })




    inputTag.render({
        elem: '.tag1',
        data: [],
        removeKeyNum: 8,
        createKeyNum: 13,
        onChange: function (data, value, type) {
            $('#tag1').text(JSON.stringify(data));
        }
    });

    // 单图片上传
    var uploadInst = upload.render({
        elem: '#ID-upload-demo-btn',
        url: '/public/upload',
        before: function (obj) {
            obj.preview(function (index, file, result) {
                $('#ID-upload-demo-img').attr('src', result); // 图片链接（base64）
            });
            layer.msg('上传中', { icon: 16, time: 0 });
        },
        done: function (res) {
            console.log(res);
            if (res.code > 0) return layer.msg('上传失败');
            $("#upload-file-input").val(res.data.url);
        },
        progress: function (n, elem, e) {
            if (n == 100) {
                layer.msg('上传完毕', { icon: 1 });
            }
        }
    });

    var params = new URLSearchParams(window.location.search);
    const id = params.get('id');
    if (id) {
        $.get('/article/get', { id: id }, (res) => {
            form.val('form', res.data);
            $('#ID-upload-demo-img').attr('src', res.data.image_url);
            setTimeout(() => vditor.setValue(res.data.content), 50);
        });
    }

    //监听提交
    form.on('submit(save)', function (data) {
        if (!data.field['id']) delete data.field['id'];
        if (!data.field['view_count']) delete data.field['view_count'];
        data.field['file'] =
            data.field['content'] = vditor.getValue();
        var index = layer.load(1, { shade: false });
        $.ajax({
            url: "/article/save",
            data: JSON.stringify(data.field),
            type: "POST",
            processData: false,
            contentType: "application/json",
            success: (res) => {
                layer.close(index);
                if (res.code) return layer.error(res.msg);
                layer.alert('保存成功');
                var iframeIndex = parent.layer.getFrameIndex(window.name);
                parent.layer.close(iframeIndex);
            }
        });
        return false;
    });
});