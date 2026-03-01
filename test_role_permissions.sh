#!/bin/bash

# 角色权限保存测试脚本

echo "=== 角色权限保存功能测试 ==="
echo ""

# 配置
API_BASE="http://localhost:3000/api"
TOKEN="your_token_here"  # 需要替换为实际的认证 token

# 测试数据
ROLE_ID=2
MENU_IDS='[1, 2, 3, 4, 5]'

echo "1. 测试创建新角色并分配菜单权限"
curl -X POST "${API_BASE}/system/role/save" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "role_name": "测试角色",
    "role_key": "test_role",
    "sort": 10,
    "remark": "这是一个测试角色",
    "status": 1,
    "menu_ids": [1, 2, 3, 4, 5]
  }' | jq .

echo ""
echo "2. 测试更新现有角色的菜单权限"
curl -X POST "${API_BASE}/system/role/save" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d "{
    \"id\": ${ROLE_ID},
    \"role_name\": \"更新的角色\",
    \"role_key\": \"updated_role\",
    \"sort\": 20,
    \"remark\": \"更新后的角色\",
    \"status\": 1,
    \"menu_ids\": [1, 2, 3, 6, 7, 8]
  }" | jq .

echo ""
echo "3. 查询角色的菜单权限"
curl -X GET "${API_BASE}/system/role/permissions/info?role_id=${ROLE_ID}" \
  -H "Authorization: Bearer ${TOKEN}" | jq .

echo ""
echo "=== 测试完成 ==="
