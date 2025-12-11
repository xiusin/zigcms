layui.use(['form'], function () {
    var $ = layui.$;
    var form = layui.form;

    window.init = za.tableInit("/department");

    // 获取URL参数
    function getUrlParam(name) {
        var reg = new RegExp("(^|&)" + name + "=([^&]*)(&|$)");
        var r = window.location.search.substr(1).match(reg);
        if (r != null) return decodeURIComponent(r[2]);
        return null;
    }

    // 加载部门下拉选项
    function loadDeptOptions() {
        za.request.get({
            url: '/department/select'
        }, function (res) {
            var html = '<option value="0">顶级部门</option>';
            var depts = res.data || [];

            // 构建树形结构选项
            function buildOptions(data, level) {
                level = level || 0;
                var prefix = '';
                for (var i = 0; i < level; i++) {
                    prefix += '&nbsp;&nbsp;&nbsp;&nbsp;';
                }
                if (level > 0) {
                    prefix += '├ ';
                }

                data.forEach(function (item) {
                    html += '<option value="' + item.id + '">' + prefix + item.name + '</option>';
                });
            }

            buildOptions(depts, 0);
            $('#parentDeptSelect').html(html);

            // 设置默认值
            var parentId = getUrlParam('parent_id');
            if (parentId) {
                $('input[name="parent_id"]').val(parentId);
                form.val('module-save-form', { parent_id: parentId });
            }

            form.render('select');
        });
    }

    // 加载员工下拉选项（用于选择负责人）
    function loadEmployeeOptions() {
        za.request.get({
            url: '/employee/select'
        }, function (res) {
            var html = '<option value="">请选择负责人</option>';
            var employees = res.data || [];

            employees.forEach(function (item) {
                html += '<option value="' + item.id + '">' + item.name + ' (' + item.employee_no + ')</option>';
            });

            $('#leaderSelect').html(html);
            form.render('select');
        });
    }

    // 初始化
    loadDeptOptions();
    loadEmployeeOptions();

    za.listen();
});
