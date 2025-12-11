layui.$(function () {
    var $ = layui.$;
    var table = layui.table;
    var form = layui.form;
    var layer = layui.layer;

    const init = za.tableInit("/employee");

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
                { field: "id", width: 70, title: "ID", sort: true },
                {
                    field: "name",
                    minWidth: 180,
                    title: "员工信息",
                    templet: '#employeeInfoTpl'
                },
                {
                    field: "gender",
                    width: 80,
                    title: "性别",
                    templet: '#genderTpl'
                },
                { field: "phone", width: 130, title: "手机号" },
                { field: "email", minWidth: 180, title: "邮箱" },
                {
                    field: "status",
                    title: "状态",
                    width: 90,
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
                    width: 180,
                    title: "操作",
                    toolbar: '#currentTableBar',
                    fixed: 'right'
                },
            ],
        ],
    });

    // 监听工具栏事件
    table.on('toolbar(currentTable)', function (obj) {
        if (obj.event === 'export') {
            layer.msg('导出功能开发中...', { icon: 0 });
        }
    });

    // 监听行工具事件
    table.on('tool(currentTable)', function (obj) {
        var data = obj.data;
        if (obj.event === 'detail') {
            // 查看详情
            za.request.get({
                url: '/employee/detail?id=' + data.id
            }, function (res) {
                var detail = res.data;
                var content = '<div style="padding: 20px; line-height: 2;">' +
                    '<div style="text-align: center; margin-bottom: 20px;">' +
                    '<img src="' + (detail.avatar || '../../images/default-avatar.png') + '" style="width: 80px; height: 80px; border-radius: 50%; border: 3px solid #eee;" />' +
                    '<h3 style="margin: 10px 0 5px;">' + detail.name + '</h3>' +
                    '<span style="color: #999;">' + detail.employee_no + '</span>' +
                    '</div>' +
                    '<table class="layui-table" lay-skin="nob">' +
                    '<tr><td width="100"><b>性别：</b></td><td>' + (detail.gender === 1 ? '男' : detail.gender === 2 ? '女' : '未知') + '</td></tr>' +
                    '<tr><td><b>手机：</b></td><td>' + (detail.phone || '-') + '</td></tr>' +
                    '<tr><td><b>邮箱：</b></td><td>' + (detail.email || '-') + '</td></tr>' +
                    '<tr><td><b>部门：</b></td><td>' + (detail.department_name || '-') + '</td></tr>' +
                    '<tr><td><b>职位：</b></td><td>' + (detail.position_name || '-') + '</td></tr>' +
                    '<tr><td><b>直属上级：</b></td><td>' + (detail.leader_name || '-') + '</td></tr>' +
                    '<tr><td><b>状态：</b></td><td>' + (detail.status === 1 ? '在职' : detail.status === 2 ? '试用期' : '离职') + '</td></tr>' +
                    '<tr><td><b>备注：</b></td><td>' + (detail.remark || '-') + '</td></tr>' +
                    '</table>' +
                    '</div>';

                layer.open({
                    type: 1,
                    title: '员工详情',
                    content: content,
                    area: ['450px', '550px'],
                    btn: ['关闭'],
                    yes: function (index) {
                        layer.close(index);
                    }
                });
            });
        } else if (obj.event === 'del') {
            layer.confirm('确定要删除该员工吗？', { icon: 3, title: '提示' }, function (index) {
                za.request.get({
                    url: '/employee/delete?id=' + data.id
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
