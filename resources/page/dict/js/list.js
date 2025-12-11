layui.$(function () {
    var $ = layui.$;
    var table = layui.table;

    const init = za.tableInit("/dict");

    za.table.render({
        init: init,
        toolbar: '#toolbar',
        cols: [
            [
                { type: "checkbox" },
                { field: "id", width: 80, title: "ID", sort: true },
                { field: "dict_type", minWidth: 120, title: "字典类型", sort: true },
                { field: "dict_label", minWidth: 120, title: "字典标签" },
                { field: "dict_value", minWidth: 100, title: "字典值" },
                { field: "dict_desc", minWidth: 150, title: "字典描述" },
                { field: "sort", width: 80, title: "排序", edit: "text", sort: true },
                {
                    field: "status",
                    title: "状态",
                    width: 100,
                    search: "select",
                    selectList: { 0: "禁用", 1: "启用" },
                    templet: za.table.switch,
                },
                {
                    field: "create_time",
                    width: 170,
                    title: "创建时间",
                    sort: true,
                    templet: za.table.time("create_time"),
                },
                {
                    width: 150,
                    title: "操作",
                    toolbar: '#currentTableBar',
                    fixed: 'right'
                },
            ],
        ],
    });

    // 监听工具栏事件
    table.on('toolbar(currentTable)', function (obj) {
        if (obj.event === 'refreshCache') {
            layer.confirm('确定要刷新字典缓存吗？', { icon: 3, title: '提示' }, function (index) {
                za.request.get({
                    url: '/dict/refreshCache'
                }, function (res) {
                    layer.msg('缓存刷新成功', { icon: 1 });
                });
                layer.close(index);
            });
        }
    });

    // 监听行工具事件
    table.on('tool(currentTable)', function (obj) {
        var data = obj.data;
        if (obj.event === 'del') {
            layer.confirm('确定要删除该字典项吗？', { icon: 3, title: '提示' }, function (index) {
                za.request.get({
                    url: '/dict/delete?id=' + data.id
                }, function (res) {
                    layer.msg('删除成功', { icon: 1 });
                    obj.del();
                });
                layer.close(index);
            });
        }
    });

    za.listen();
});
