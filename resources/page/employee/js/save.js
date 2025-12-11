layui.use(['form', 'laydate', 'upload'], function () {
    var $ = layui.$;
    var form = layui.form;
    var laydate = layui.laydate;
    var upload = layui.upload;

    window.init = za.tableInit("/employee");

    // 获取URL参数
    function getUrlParam(name) {
        var reg = new RegExp("(^|&)" + name + "=([^&]*)(&|$)");
        var r = window.location.search.substr(1).match(reg);
        if (r != null) return decodeURIComponent(r[2]);
        return null;
    }

    // 初始化日期选择器
    laydate.render({
        elem: '#hireDateInput',
        type: 'date',
        format: 'yyyy-MM-dd',
        done: function (value, date) {
            // 转换为时间戳
            if (value) {
                var timestamp = new Date(value).getTime() * 1000; // 微秒级
                $('input[name="hire_date"]').val(timestamp);
            }
        }
    });

    // 初始化头像上传
    upload.render({
        elem: '#avatarUpload',
        url: '/public/upload',
        accept: 'images',
        acceptMime: 'image/*',
        done: function (res) {
            if (res.code === 0) {
                var url = res.data.url || res.data.src;
                $('#avatarInput').val(url);
                $('#avatarPreview').attr('src', url).show();
                $('#avatarIcon').hide();
                layer.msg('上传成功', { icon: 1 });
            } else {
                layer.msg(res.msg || '上传失败', { icon: 2 });
            }
        },
        error: function () {
            layer.msg('上传失败，请重试', { icon: 2 });
        }
    });

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

    // 加载职位下拉选项
    function loadPositionOptions(departmentId) {
        var url = '/position/select';
        if (departmentId) {
            url = '/position/byDepartment?department_id=' + departmentId;
        }

        za.request.get({
            url: url
        }, function (res) {
            var html = '<option value="">请选择职位</option>';
            var positions = res.data || [];

            positions.forEach(function (item) {
                html += '<option value="' + item.id + '">' + item.name + '</option>';
            });

            $('#positionSelect').html(html);
            form.render('select');
        });
    }

    // 加载员工下拉选项（用于选择上级）
    function loadEmployeeOptions() {
        za.request.get({
            url: '/employee/select'
        }, function (res) {
            var html = '<option value="">请选择上级</option>';
            var employees = res.data || [];
            var currentId = getUrlParam('id');

            employees.forEach(function (item) {
                // 排除自己
                if (currentId && item.id == currentId) return;
                html += '<option value="' + item.id + '">' + item.name + ' (' + item.employee_no + ')</option>';
            });

            $('#leaderSelect').html(html);
            form.render('select');
        });
    }

    // 监听部门选择变化，联动加载职位
    form.on('select(dept)', function (data) {
        loadPositionOptions(data.value);
    });

    // 表单数据填充后的回调处理
    $(document).on('formDataLoaded', function (e, data) {
        // 显示头像
        if (data.avatar) {
            $('#avatarPreview').attr('src', data.avatar).show();
            $('#avatarIcon').hide();
        }

        // 显示入职日期
        if (data.hire_date) {
            var date = new Date(data.hire_date / 1000); // 微秒转毫秒
            var dateStr = date.getFullYear() + '-' +
                String(date.getMonth() + 1).padStart(2, '0') + '-' +
                String(date.getDate()).padStart(2, '0');
            $('#hireDateInput').val(dateStr);
        }

        // 加载对应部门的职位
        if (data.department_id) {
            loadPositionOptions(data.department_id);
        }
    });

    // 初始化
    loadDeptOptions();
    loadPositionOptions();
    loadEmployeeOptions();

    za.listen();
});
