layui.use(['selectPlus'], function () {
    const init = za.tableInit('/article');
    const selectPlus = layui.selectPlus;
    za.table.render({
        init: init,
        cols: [
            [
                { type: "checkbox", fixed: 'left', width: 60 },
                { field: 'id', width: 80, title: 'ID', fixed: 'left' },
                { field: 'title', minWidth: 200, title: '文章标题', fixed: 'left' },
                { field: 'article_type', width: 150, title: '文章类型', templet: (d) => d.article_type == 'article_type_original' ? '原创' : '转载' },
                { field: 'category_id', width: 150, title: '文章分类', templet: "#selectPlus" },
                { field: 'tags', title: '标签' },
                { field: 'status', width: 100, title: '状态', selectList: { 0: '关闭', 1: '开启' }, templet: za.table.switch },
                { field: 'view_count', width: 100, title: '观看次数' },
                { field: 'create_time', width: 160, title: '创建时间', templet: za.table.time('create_time') },
                { field: 'update_time', width: 160, title: '更新时间', templet: za.table.time('update_time') },
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
        ],
        before: function () {
            console.log('before');
        },
        done: function () {
            selectPlus.render({
                el: '.select-plus',
                data: [{
                    "name": "vue",
                    "id": 1,
                    "text": "hello vue"
                }, {
                    "name": "layui",
                    "id": 2,
                    "text": "hello layui"
                }, {
                    "name": "react",
                    "id": 3,
                    "text": "hello react"
                }, {
                    "name": "bootstrap",
                    "id": 4,
                    "text": "hello bootstrap"
                }, {
                    "name": "element",
                    "id": 5,
                    "text": "hello element"
                }],
                type: "radio",
                valueName: "text",
                label: ["name", "id"],
                values: 'hello layui'
            });
        }
    });
    za.listen();
});
