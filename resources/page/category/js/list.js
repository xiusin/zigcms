layui.$(function () {
    const init = za.tableInit('/category');
    za.table.render({
        init: init,
        cols: [[
            { type: "checkbox" },
            { field: 'id', width: 80, title: 'ID' },
            { field: 'sort', width: 80, title: '排序', edit: 'text' },
            { field: 'title', minWidth: 80, title: '分类名称', edit: 'text' },
            { field: 'image', minWidth: 80, title: '分类图片', search: false, templet: za.table.image },
            { field: 'remark', minWidth: 80, title: '备注信息', edit: 'text' },
            { field: 'status', title: '状态', width: 85, search: 'select', selectList: { 0: '禁用', 1: '启用' }, templet: za.table.switch },
            { field: 'create_time', minWidth: 80, title: '创建时间', search: 'range', templet: za.table.time('create_time') },
            { field: 'update_time', minWidth: 80, title: '更新时间', search: 'range', templet: za.table.time('update_time') },
            { width: 250, title: '操作', templet: za.table.tool }
        ]],
    });
    za.listen();
});