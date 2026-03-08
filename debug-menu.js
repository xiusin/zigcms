// 在浏览器控制台运行此脚本来调试菜单问题

console.log('========================================');
console.log('菜单调试脚本');
console.log('========================================');

// 1. 检查所有路由
console.log('\n1. 检查所有 security 相关路由：');
const securityRoutes = $router.getRoutes().filter(r => r.name?.toString().includes('security'));
console.table(securityRoutes.map(r => ({
  name: r.name,
  path: r.path,
  hideInMenu: r.meta?.hideInMenu,
  locale: r.meta?.locale,
  icon: r.meta?.icon,
})));

// 2. 检查菜单树
console.log('\n2. 检查菜单树（从 store）：');
if (window.$store) {
  const menuTree = window.$store.state.app?.appAsyncMenus || [];
  const securityMenu = menuTree.find(m => m.name === 'security');
  if (securityMenu) {
    console.log('安全管理菜单：', securityMenu);
    console.log('子菜单：');
    console.table(securityMenu.children?.map(c => ({
      name: c.name,
      locale: c.meta?.locale,
      hideInMenu: c.meta?.hideInMenu,
      icon: c.meta?.icon,
    })));
  } else {
    console.log('❌ 未找到安全管理菜单');
  }
}

// 3. 检查当前路由
console.log('\n3. 当前路由信息：');
console.log('当前路由名称：', $route.name);
console.log('当前路由路径：', $route.path);
console.log('当前路由 meta：', $route.meta);

// 4. 尝试直接访问路由
console.log('\n4. 测试路由访问：');
console.log('尝试访问 /security/log：');
$router.push('/security/log').then(() => {
  console.log('✅ 路由跳转成功');
}).catch(err => {
  console.error('❌ 路由跳转失败：', err);
});

setTimeout(() => {
  console.log('\n尝试访问 /security/blacklist：');
  $router.push('/security/blacklist').then(() => {
    console.log('✅ 路由跳转成功');
  }).catch(err => {
    console.error('❌ 路由跳转失败：', err);
  });
}, 1000);

console.log('\n========================================');
console.log('调试脚本执行完成');
console.log('请查看上面的输出信息');
console.log('========================================');
