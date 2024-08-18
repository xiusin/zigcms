layui.$(function () {
    layui.layer.load(4);
    za.listen();

    layui.$.get('/setting/get', (res) => {
        layui.form.val('setting-form', res.data);
        layui.layer.closeAll();
    });
});


// layui.use(['form'], function () {
//     const form = layui.form, layer = layui.layer;
//     const $ = layui.jquery;
//     var index = layer.load(1, { shade: false });
//     $.get('/setting/get', (res) => {
//         layer.close(index);
//         form.val('setting-form', res.data);
//     });

//     form.on('submit(setting)', function (data) {
//         var index = layer.load(1, { shade: false });
//         $.ajax({
//             url: "setting/save",
//             data: JSON.stringify(data.field),
//             type: "POST",
//             processData: false,
//             contentType: "application/json",
//             success: (res) => {
//                 layer.close(index);
//                 if (res.code) {
//                     layer.error(res.msg)
//                     return
//                 }
//                 layer.alert('保存成功');
//                 parent.layui.layer.closeAll();
//                 parent.tableln.reload();
//             }
//         });

//         return false;
//     });

// });