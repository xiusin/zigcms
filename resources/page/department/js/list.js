layui.$(function () {
    var $ = layui.$;
    var table = layui.table;
    var layer = layui.layer;

    var currentDeptId = 0;
    var deptTreeData = [];

    const init = za.tableInit("/department");

    // 加载部门树
    function loadDeptTree() {
        za.request.get({
            url: '/department/tree'
        }, function (res) {
            deptTreeData = res.data || [];
            renderDeptTree(deptTreeData);
        });
    }

    // 渲染部门树
    function renderDeptTree(data, container) {
        container = container || $('#deptTree');
        container.empty();

        // 添加"全部"选项
        if (container.attr('id') === 'deptTree') {
            var allNode = $('<div class="tree-node' + (currentDeptId === 0 ? ' active' : '') + '" data-id="0">' +
                '<div class="node-info">' +
                '<i class="fa fa-building"></i>' +
                '<span class="node-name">全部部门</span>' +
                '</div>' +
                '</div>');
            allNode.on('click', function () {
                currentDeptId = 0;
                $('.tree-node').removeClass('active');
                $(this).addClass('active');
                $('#currentDeptName').text('全部部门');
                loadTableData();
                updateStats(null);
            });
            container.append(allNode);
        }

        data.forEach(function (item) {
            var node = $('<div class="tree-node' + (currentDeptId === item.id ? ' active' : '') + '" data-id="' + item.id + '">' +
                '<div class="node-info">' +
                '<i class="fa fa-' + (item.children && item.children.length > 0 ? 'folder' : 'file') + '"></i>' +
                '<span class="node-name">' + item.name + '</span>' +
                '<span class="node-count">(' + (item.total_employee_count || 0) + '人)</span>' +
                '</div>' +
                '</div>');

            node.on('click', function (e) {
                e.stopPropagation();
                currentDeptId = item.id;
                $('.tree-node').removeClass('active');
                $(this).addClass('active');
                $('#currentDeptName').text(item.name);
                loadTableData();
                updateStats(item);
            });

            container.append(node);

            if (item.children && item.children.length > 0) {
                var childContainer = $('<div class="tree-children"></div>');
                container.append(childContainer);
                renderDeptTree(item.children, childContainer);
            }
        });
    }

    // 更新统计数据
    function updateStats(deptData) {
        if (deptData) {
            $('#statDeptCount').text(deptData.children ? deptData.children.length : 0);
            $('#statEmpCount').text(deptData.total_employee_count || 0);
            $('#statPosCount').text(deptData.position_count || 0);
        } else {
            // 统计全部
            var totalDept = countNodes(deptTreeData);
            var totalEmp = sumEmployees(deptTreeData);
            $('#statDeptCount').text(totalDept);
            $('#statEmpCount').text(totalEmp);
            $('#statPosCount').text('-');
        }
    }

    function countNodes(data) {
        var count = data.length;
        data.forEach(function (item) {
            if (item.children) {
                count += countNodes(item.children);
            }
        });
        return count;
    }

    function sumEmployees(data) {
        var sum = 0;
        data.forEach(function (item) {
            sum += item.employee_count || 0;
            if (item.children) {
                sum += sumEmployees(item.children);
            }
        });
        return sum;
    }

    // 加载表格数据
    function loadTableData() {
        var whereData = {};
        if (currentDeptId > 0) {
            whereData.parent_id = currentDeptId;
        }
        table.reload('currentTableRenderId', {
            where: whereData,
            page: { curr: 1 }
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
                { field: "name", minWidth: 150, title: "部门名称" },
                { field: "code", minWidth: 120, title: "部门编码" },
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
                    width: 220,
                    title: "操作",
                    toolbar: '#currentTableBar',
                    fixed: 'right'
                },
            ],
        ],
    });

    // 监听工具栏事件
    table.on('toolbar(currentTable)', function (obj) {
        if (obj.event === 'refresh') {
            loadDeptTree();
            loadTableData();
        }
    });

    // 监听行工具事件
    table.on('tool(currentTable)', function (obj) {
        var data = obj.data;
        if (obj.event === 'edit') {
            layer.open({
                type: 2,
                title: '编辑部门',
                content: '/department/save?id=' + data.id,
                area: ['700px', '550px'],
                end: function () {
                    loadDeptTree();
                    loadTableData();
                }
            });
        } else if (obj.event === 'addChild') {
            layer.open({
                type: 2,
                title: '添加子部门',
                content: '/department/save?parent_id=' + data.id,
                area: ['700px', '550px'],
                end: function () {
                    loadDeptTree();
                    loadTableData();
                }
            });
        } else if (obj.event === 'del') {
            layer.confirm('确定要删除该部门吗？删除后不可恢复！', { icon: 3, title: '提示' }, function (index) {
                za.request.get({
                    url: '/department/delete?id=' + data.id
                }, function (res) {
                    layer.msg('删除成功', { icon: 1 });
                    loadDeptTree();
                    obj.del();
                }, function (res) {
                    layer.msg(res.msg || '删除失败', { icon: 2 });
                });
                layer.close(index);
            });
        }
    });

    // 添加顶级部门
    $('#addRootDept').on('click', function () {
        layer.open({
            type: 2,
            title: '添加顶级部门',
            content: '/department/save?parent_id=0',
            area: ['700px', '550px'],
            end: function () {
                loadDeptTree();
                loadTableData();
            }
        });
    });

    // 添加子部门
    $('#addChildDept').on('click', function () {
        if (currentDeptId === 0) {
            layer.open({
                type: 2,
                title: '添加顶级部门',
                content: '/department/save?parent_id=0',
                area: ['700px', '550px'],
                end: function () {
                    loadDeptTree();
                    loadTableData();
                }
            });
        } else {
            layer.open({
                type: 2,
                title: '添加子部门',
                content: '/department/save?parent_id=' + currentDeptId,
                area: ['700px', '550px'],
                end: function () {
                    loadDeptTree();
                    loadTableData();
                }
            });
        }
    });

    // 刷新表格
    $('#refreshTable').on('click', function () {
        loadDeptTree();
        loadTableData();
    });

    // 初始化加载
    loadDeptTree();
    za.listen();
});
