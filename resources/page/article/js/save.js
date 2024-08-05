layui.use(['form', 'layer', 'inputTag'], function () {
    var form = layui.form,
        layer = layui.layer,
        upload = layui.upload,
        inputTag = layui.inputTag,
        $ = layui.$;

    const vditor = new Vditor("editor", {
        height: '100%',
        minHeight: 500,
        width: 1000,
        toolbarConfig: { pin: true },
        counter: { enable: true },
        cache: { enable: false },
        placeholder: '请输入此刻的想法...'
    });

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