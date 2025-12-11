layui.use(['form'], function () {
    var $ = layui.$;
    var form = layui.form;

    window.init = za.tableInit("/position");

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
            var html = '<option value="">请选择部门</option>';
            var depts = res.data || [];

            depts.forEach(function (item) {
                html += '<option value="' + item.id + '">' + item.name + '</option>';
            });

            $('#deptSelect').html(html);

            // 设置默认值
            var deptId = getUrlParam('department_id');
            if (deptId) {
                form.val('module-save-form', { department_id: deptId });
            }

            form.render('select');
        });
    }

    // 初始化
    loadDeptOptions();
    za.listen();
});
