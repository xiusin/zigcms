#!/usr/bin/env python3
"""
批量修复无用的 _ = self; 问题

检测模式：
1. 函数中有 _ = self;
2. 后续代码使用了 self -> 删除 _ = self;
3. 后续代码不使用 self -> 改为 _: *Self 参数

修复方案：
- 情况1: 删除 _ = self; 行
- 情况2: 改为 _: *Self 参数（需要手动处理）
"""

import os
import re
import sys

def find_zig_files(root_dir):
    """查找所有 .zig 文件"""
    zig_files = []
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith('.zig'):
                zig_files.append(os.path.join(dirpath, filename))
    return zig_files

def analyze_file(filepath):
    """分析文件中的 _ = self; 使用情况"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    issues = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # 检查是否是 _ = self; 行
        if re.match(r'^\s*_ = self;\s*(//.*)?$', line):
            # 检查后续是否使用了 self
            uses_self = False
            func_end = i
            
            for j in range(i + 1, len(lines)):
                next_line = lines[j]
                # 如果遇到函数结束，停止检查
                if re.match(r'^\s*}\s*$', next_line):
                    func_end = j
                    break
                # 检查是否使用了 self
                if re.search(r'\bself\b', next_line) and not re.match(r'^\s*_ = self;', next_line):
                    uses_self = True
            
            issues.append({
                'line_num': i + 1,
                'line': line,
                'uses_self': uses_self,
                'func_end': func_end
            })
        
        i += 1
    
    return issues

def fix_file(filepath):
    """修复单个文件 - 只删除后续使用 self 的情况"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    changes = 0
    
    while i < len(lines):
        line = lines[i]
        
        # 检查是否是 _ = self; 行
        if re.match(r'^\s*_ = self;\s*(//.*)?$', line):
            # 检查后续是否使用了 self
            uses_self = False
            for j in range(i + 1, len(lines)):
                next_line = lines[j]
                # 如果遇到函数结束，停止检查
                if re.match(r'^\s*}\s*$', next_line):
                    break
                # 检查是否使用了 self（排除 _ = self; 本身）
                if re.search(r'\bself\b', next_line) and not re.match(r'^\s*_ = self;', next_line):
                    uses_self = True
                    break
            
            if uses_self:
                # 删除这行
                changes += 1
                i += 1
                continue
        
        fixed_lines.append(line)
        i += 1
    
    if changes > 0:
        new_content = '\n'.join(fixed_lines)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return changes
    
    return 0

def main():
    if len(sys.argv) < 2:
        print("用法: python3 fix_discard.py <目录>")
        sys.exit(1)
    
    root_dir = sys.argv[1]
    
    if not os.path.isdir(root_dir):
        print(f"错误: {root_dir} 不是一个目录")
        sys.exit(1)
    
    print(f"扫描目录: {root_dir}")
    zig_files = find_zig_files(root_dir)
    print(f"找到 {len(zig_files)} 个 .zig 文件\n")
    
    # 先分析
    print("=== 分析阶段 ===")
    total_issues = 0
    uses_self_count = 0
    not_uses_self_count = 0
    
    for filepath in zig_files:
        issues = analyze_file(filepath)
        if issues:
            total_issues += len(issues)
            for issue in issues:
                if issue['uses_self']:
                    uses_self_count += 1
                else:
                    not_uses_self_count += 1
    
    print(f"发现 {total_issues} 处 _ = self;")
    print(f"  - 后续使用 self: {uses_self_count} 处（可自动修复）")
    print(f"  - 后续不使用 self: {not_uses_self_count} 处（需手动改参数）\n")
    
    # 修复
    print("=== 修复阶段 ===")
    total_changes = 0
    fixed_files = []
    
    for filepath in zig_files:
        changes = fix_file(filepath)
        if changes > 0:
            total_changes += changes
            fixed_files.append((filepath, changes))
            print(f"✅ {filepath}: 修复 {changes} 处")
    
    print(f"\n=== 总结 ===")
    print(f"- 扫描文件: {len(zig_files)}")
    print(f"- 修复文件: {len(fixed_files)}")
    print(f"- 自动修复: {total_changes} 处")
    print(f"- 需手动处理: {not_uses_self_count} 处")
    
    if not_uses_self_count > 0:
        print(f"\n⚠️  还有 {not_uses_self_count} 处需要手动改为 _: *Self 参数")

if __name__ == '__main__':
    main()
