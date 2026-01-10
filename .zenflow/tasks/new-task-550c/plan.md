# Spec and build

## Configuration
- **Artifacts Path**: {@artifacts_path} → `.zenflow/tasks/{task_id}`

---

## Agent Instructions

Ask the user questions when anything is unclear or needs their input. This includes:
- Ambiguous or incomplete requirements
- Technical decisions that affect architecture or user experience
- Trade-offs that require business context

Do not make assumptions on important decisions — get clarification first.

---

## Workflow Steps

### [x] Step: Technical Specification
<!-- chat-id: 2b267e80-90bd-4986-8df6-71b68b4fa1aa -->

Assess the task's difficulty, as underestimating it leads to poor outcomes.
- easy: Straightforward implementation, trivial bug fix or feature
- medium: Moderate complexity, some edge cases or caveats to consider
- hard: Complex logic, many caveats, architectural considerations, or high-risk changes

Create a technical specification for the task that is appropriate for the complexity level:
- Review the existing codebase architecture and identify reusable components.
- Define the implementation approach based on established patterns in the project.
- Identify all source code files that will be created or modified.
- Define any necessary data model, API, or interface changes.
- Describe verification steps using the project's test and lint commands.

Save the output to `{@artifacts_path}/spec.md` with:
- Technical context (language, dependencies)
- Implementation approach
- Source code structure changes
- Data model / API / interface changes
- Verification approach

If the task is complex enough, create a detailed implementation plan based on `{@artifacts_path}/spec.md`:
- Break down the work into concrete tasks (incrementable, testable milestones)
- Each task should reference relevant contracts and include verification steps
- Replace the Implementation step below with the planned tasks

Rule of thumb for step size: each step should represent a coherent unit of work (e.g., implement a component, add an API endpoint, write tests for a module). Avoid steps that are too granular (single function).

Save to `{@artifacts_path}/plan.md`. If the feature is trivial and doesn't warrant this breakdown, keep the Implementation step below as is.

---

### [x] Step: Implementation
<!-- chat-id: f734ee17-61aa-405a-bccd-6cdb2922a909 -->

✅ **已完成** - 2026-01-10

**实施内容**：
1. ✅ 深度分析缓存契约系统 - 发现已完善实现
2. ✅ 深度分析 ORM 内存管理 - 发现已完善实现
3. ✅ 创建测试用例验证功能
4. ✅ 创建示例程序展示最佳实践
5. ✅ 撰写优化实施报告

**输出文件**：
- `tests/cache_contract_test.zig` - 缓存契约测试
- `tests/orm_memory_test.zig` - ORM 内存管理测试
- `examples/cache_example.zig` - 缓存使用示例
- `examples/orm_memory_example.zig` - ORM 内存管理示例
- `optimization_report.md` - 优化实施报告

**关键发现**：
项目在缓存契约和 ORM 内存管理方面已经实现得非常完善，无需额外修复。
已创建测试和示例以展示正确用法。
