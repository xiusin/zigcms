#!/bin/bash

# 安全监控数据库持久化测试脚本
# 用途：验证安全事件和IP封禁记录的持久化功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
API_URL="http://localhost:8080"
TOKEN=""  # 需要先登录获取 Token

# 打印函数
print_header() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# 检查服务是否运行
check_service() {
    print_header "检查服务状态"
    
    if curl -s -f "$API_URL/api/health" > /dev/null 2>&1; then
        print_success "服务正在运行"
        return 0
    else
        print_error "服务未运行，请先启动服务"
        return 1
    fi
}

# 登录获取 Token
login() {
    print_header "登录获取 Token"
    
    response=$(curl -s -X POST "$API_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}')
    
    TOKEN=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$TOKEN" ]; then
        print_success "登录成功，Token: ${TOKEN:0:20}..."
        return 0
    else
        print_error "登录失败"
        echo "$response"
        return 1
    fi
}

# 测试1：安全事件持久化
test_security_event_persistence() {
    print_header "测试1：安全事件持久化"
    
    # 1. 触发安全事件（登录失败）
    print_info "触发登录失败事件..."
    for i in {1..5}; do
        curl -s -X POST "$API_URL/api/auth/login" \
            -H "Content-Type: application/json" \
            -d '{"username":"test","password":"wrong"}' \
            -H "X-Forwarded-For: 192.168.1.100" > /dev/null
    done
    print_success "已触发 5 次登录失败事件"
    
    # 2. 查询安全事件列表
    print_info "查询安全事件列表..."
    response=$(curl -s "$API_URL/api/security/events?page=1&page_size=10" \
        -H "Authorization: Bearer $TOKEN")
    
    event_count=$(echo "$response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$event_count" ] && [ "$event_count" -gt 0 ]; then
        print_success "查询到 $event_count 条安全事件"
        echo "$response" | jq '.data.items[0]' 2>/dev/null || echo "$response"
    else
        print_error "未查询到安全事件"
        echo "$response"
        return 1
    fi
    
    # 3. 提示重启服务验证持久化
    print_info "请重启服务后再次运行此脚本验证持久化"
}

# 测试2：IP封禁持久化
test_ip_ban_persistence() {
    print_header "测试2：IP封禁持久化"
    
    # 1. 手动封禁IP
    print_info "手动封禁IP 192.168.1.200..."
    response=$(curl -s -X POST "$API_URL/api/security/ban-ip" \
        -H "Authorization: Bearer $TOKEN" \
        -d "ip=192.168.1.200&duration=3600&reason=测试封禁")
    
    if echo "$response" | grep -q "success"; then
        print_success "IP封禁成功"
    else
        print_error "IP封禁失败"
        echo "$response"
        return 1
    fi
    
    # 2. 查询封禁IP列表
    print_info "查询封禁IP列表..."
    response=$(curl -s "$API_URL/api/security/banned-ips?page=1&page_size=10" \
        -H "Authorization: Bearer $TOKEN")
    
    ban_count=$(echo "$response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$ban_count" ] && [ "$ban_count" -gt 0 ]; then
        print_success "查询到 $ban_count 条封禁记录"
        echo "$response" | jq '.data.items[0]' 2>/dev/null || echo "$response"
    else
        print_error "未查询到封禁记录"
        echo "$response"
        return 1
    fi
    
    # 3. 解封IP
    print_info "解封IP 192.168.1.200..."
    response=$(curl -s -X POST "$API_URL/api/security/unban-ip" \
        -H "Authorization: Bearer $TOKEN" \
        -d "ip=192.168.1.200")
    
    if echo "$response" | grep -q "success"; then
        print_success "IP解封成功"
    else
        print_error "IP解封失败"
        echo "$response"
        return 1
    fi
    
    # 4. 验证解封
    print_info "验证IP已解封..."
    response=$(curl -s "$API_URL/api/security/banned-ips?page=1&page_size=10" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$response" | grep -q "192.168.1.200"; then
        print_error "IP仍在封禁列表中"
        return 1
    else
        print_success "IP已成功解封"
    fi
}

# 测试3：自动封禁
test_auto_ban() {
    print_header "测试3：自动封禁"
    
    # 1. 触发多次登录失败（超过阈值20次）
    print_info "触发25次登录失败（超过自动封禁阈值20次）..."
    for i in {1..25}; do
        curl -s -X POST "$API_URL/api/auth/login" \
            -H "Content-Type: application/json" \
            -d '{"username":"test","password":"wrong"}' \
            -H "X-Forwarded-For: 192.168.1.201" > /dev/null
        echo -n "."
    done
    echo ""
    print_success "已触发 25 次登录失败"
    
    # 2. 查询封禁IP列表
    print_info "查询封禁IP列表（应该看到自动封禁记录）..."
    sleep 2  # 等待处理
    response=$(curl -s "$API_URL/api/security/banned-ips?page=1&page_size=10" \
        -H "Authorization: Bearer $TOKEN")
    
    if echo "$response" | grep -q "192.168.1.201"; then
        print_success "IP 192.168.1.201 已被自动封禁"
        echo "$response" | jq '.data.items[] | select(.ip=="192.168.1.201")' 2>/dev/null || echo "$response"
    else
        print_error "未检测到自动封禁"
        echo "$response"
        return 1
    fi
    
    # 3. 清理：解封IP
    print_info "清理：解封IP 192.168.1.201..."
    curl -s -X POST "$API_URL/api/security/unban-ip" \
        -H "Authorization: Bearer $TOKEN" \
        -d "ip=192.168.1.201" > /dev/null
    print_success "清理完成"
}

# 测试4：数据库直接查询验证
test_database_query() {
    print_header "测试4：数据库直接查询验证"
    
    print_info "查询安全事件表..."
    mysql -u root -p -e "USE zigcms; SELECT COUNT(*) as total FROM security_events;" 2>/dev/null || \
        print_error "无法连接数据库（需要MySQL客户端）"
    
    print_info "查询IP封禁表..."
    mysql -u root -p -e "USE zigcms; SELECT COUNT(*) as total FROM ip_bans;" 2>/dev/null || \
        print_error "无法连接数据库（需要MySQL客户端）"
    
    print_info "查询未过期的封禁记录..."
    mysql -u root -p -e "USE zigcms; SELECT * FROM ip_bans WHERE expires_at > UNIX_TIMESTAMP() ORDER BY created_at DESC LIMIT 5;" 2>/dev/null || \
        print_error "无法连接数据库（需要MySQL客户端）"
}

# 测试5：服务重启后验证持久化
test_persistence_after_restart() {
    print_header "测试5：服务重启后验证持久化"
    
    print_info "此测试需要手动执行："
    echo ""
    echo "1. 记录当前安全事件数量和封禁IP数量"
    echo "2. 停止服务：pkill zigcms"
    echo "3. 启动服务：./zig-out/bin/zigcms"
    echo "4. 再次查询安全事件和封禁IP"
    echo "5. 验证数据是否一致"
    echo ""
    print_info "如果数据一致，说明持久化功能正常"
}

# 主函数
main() {
    print_header "安全监控数据库持久化测试"
    
    # 检查服务
    if ! check_service; then
        exit 1
    fi
    
    # 登录
    if ! login; then
        exit 1
    fi
    
    # 执行测试
    test_security_event_persistence
    echo ""
    
    test_ip_ban_persistence
    echo ""
    
    test_auto_ban
    echo ""
    
    test_database_query
    echo ""
    
    test_persistence_after_restart
    echo ""
    
    print_header "测试完成"
    print_success "所有测试已执行完成"
    print_info "请查看上述测试结果，验证持久化功能是否正常"
}

# 运行主函数
main
