layui.$(function () {
    var $ = layui.$;
    var table = layui.table;
    var form = layui.form;

    const init = za.tableInit("/position");

    // 加载部门下拉选项
    function loadDeptOptions() {
        za.request.get({
            url: '/department/select'
        }, function (res) {
            var html = '<option value="">全部部门</option>';
            var depts = res.data || [];

            depts.forEach(function (item) {
                html += '<option value="' + item.id + '">' + item.name + '</option>';
            });

            $('#searchDept').html(html);
            form.render('select');
        });
    }

    // 渲染表格
    za.table.render({
        init: init,
        toolbar: '#toolbar',
        cols: [
            [
                { type: "checkbox" },
                { field: "id", width: 80, title: "ID", sort: true },
                { field: "name", minWidth: 150, title: "职位名称" },
                { field: "code", minWidth: 120, title: "职位编码" },
                {
                    field: "level",
                    width: 100,
                    title: "职级",
                    sort: true,
                    templet: '#levelTpl'
                },
                { field: "sort", width: 80, title: "排序", edit: "text", sort: true },
                {
                    field: "status",
                    title: "状态",
                    width: 100,
                    templet: '#statusTpl'
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

    // 监听行工具事件
    table.on('tool(currentTable)', function (obj) {
        var data = obj.data;
        if (obj.event === 'del') {
            layer.confirm('确定要删除该职位吗？', { icon: 3, title: '提示' }, function (index) {
                za.request.get({
                    url: '/position/delete?id=' + data.id
                }, function (res) {
                    layer.msg('删除成功', { icon: 1 });
                    obj.del();
                }, function (res) {
                    layer.msg(res.msg || '删除失败', { icon: 2 });
                });
                layer.close(index);
            });
        }
    });

    // 初始化
    loadDeptOptions();
    za.listen();
});
