layui.$(function () {
    const init = za.tableInit('/article');
    za.table.render({
        init: init,
        cols: [
            [
                { type: "checkbox", fixed: 'left', width: 60 },
                { field: 'id', width: 80, title: 'ID', fixed: 'left' },
                { field: 'title', minWidth: 200, title: '文章标题', fixed: 'left' },
                { field: 'article_type', width: 150, title: '文章类型', templet: (d) => d.article_type == 'article_type_original' ? '原创' : '转载' },
                { field: 'category_id', width: 150, title: '文章分类' },
                { field: 'tags', title: '标签' },
                { field: 'status', width: 100, title: '状态', selectList: { 0: '关闭', 1: '开启' }, templet: za.table.switch },
                { field: 'view_count', width: 100, title: '观看次数' },
                { field: 'create_time', width: 160, title: '创建时间', templet: (d) => new Date(d.create_time / 1000).toLocaleString() },
                { field: 'update_time', width: 160, title: '创建时间', templet: (d) => new Date(d.create_time / 1000).toLocaleString() },
                {
                    width: 250,
                    title: '操作',
                    templet: za.table.tool,
                    operat: [
                        'edit',
                        [{
                            text: '授权',
                            url: init.authorize_url,
                            method: 'open',
                            auth: 'authorize',
                            class: 'layui-btn layui-btn-normal layui-btn-xs',
                        }],
                        'delete'
                    ]
                }
            ]
        ]
    });
    za.listen();
});