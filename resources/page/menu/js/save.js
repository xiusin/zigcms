layui.use(['iconPickerFa', 'autocomplete'], function () {
    var iconPickerFa = layui.iconPickerFa;
    var autocomplete = layui.autocomplete;
    layui.$(function () {
        iconPickerFa.render({
            elem: '#icon',
            url: "../../lib/font-awesome-4.7.0/less/variables.less",
            limit: 12,
            click: function (data) {
                $('#icon').val('fa ' + data.icon);
            },
            success: function (d) {

            }
        });

        // 自动补全
        autocomplete.render({
            elem: $('#href')[0],
            url: za.url('system.menu/getMenuTips'),
            cache: true,
            template_val: '{{-d.node}}',
            template_txt: '{{-d.node}} <span class=\'layui-badge layui-bg-gray\'>{{-d.title}}</span>',
            onselect: function (resp) {
            }
        });

        za.listen(function (data) {
            return data;
        }, function (res) {
            za.msg.success(res.msg, function () {
                var index = parent.layer.getFrameIndex(window.name);
                parent.layer.close(index);
                parent.$('[data-treetable-refresh]').trigger("click");
            });
        });
    });
});
