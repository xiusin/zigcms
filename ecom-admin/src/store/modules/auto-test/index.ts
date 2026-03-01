/**
 * 自动化测试系统状态管理
 */
import { defineStore } from 'pinia';
import {
  getTestTaskList,
  getTestTaskDetail,
  createTestTask,
  updateTestTask,
  deleteTestTask,
  executeTestTask,
  getTestCaseList,
  getTestCaseDetail,
  createTestCase,
  updateTestCase,
  deleteTestCase,
  runTestCase,
  getBugAnalysisList,
  getBugAnalysisDetail,
  analyzeBug,
  autoFixBug,
  updateBugStatus,
  getTestExecutionList,
  getTestExecutionDetail,
  getExecutionLogs,
  getTestReportList,
  getTestReportDetail,
  generateTestReport,
  aiExecuteTestTask,
  aiGenerateTestCases,
  aiAnalyzeBug,
  aiAutoFix,
  aiVerifyFix,
  getTestSuiteList,
  getTestModuleList,
} from '@/api/auto-test';
import type {
  TestTask,
  TestCase,
  BugAnalysis,
  TestExecution,
  TestReport,
  TestTaskListParams,
  TestCaseListParams,
  BugAnalysisListParams,
  TestExecutionListParams,
  CreateTestTaskParams,
  CreateTestCaseParams,
  AIBugAnalysisParams,
  AIAutoFixParams,
  AIGenerateTestCaseParams,
} from '@/types/auto-test';

// 测试任务 Store
export const useAutoTestTaskStore = defineStore('autoTestTask', {
  state: () => ({
    taskList: [] as TestTask[],
    taskTotal: 0,
    currentTask: null as TestTask | null,
    loading: false,
    executing: false,
  }),

  getters: {
    getTaskById: (state) => (id: number) => state.taskList.find(t => t.id === id),
  },

  actions: {
    async fetchTaskList(params: TestTaskListParams) {
      this.loading = true;
      try {
        const res = await getTestTaskList(params);
        this.taskList = res.data.list;
        this.taskTotal = res.data.total;
      } finally {
        this.loading = false;
      }
    },

    async fetchTaskDetail(id: number) {
      this.loading = true;
      try {
        const res = await getTestTaskDetail(id);
        this.currentTask = res.data;
        return res.data;
      } finally {
        this.loading = false;
      }
    },

    async createTask(data: CreateTestTaskParams) {
      const res = await createTestTask(data);
      return res.data;
    },

    async updateTask(data: { id: number } & Partial<CreateTestTaskParams>) {
      const res = await updateTestTask(data);
      return res.data;
    },

    async deleteTask(id: number) {
      await deleteTestTask(id);
    },

    async executeTask(id: number, options?: { parallel?: boolean; retry_failed?: boolean }) {
      this.executing = true;
      try {
        const res = await executeTestTask(id, options);
        return res.data;
      } finally {
        this.executing = false;
      }
    },
  },
});

// 测试用例 Store
export const useAutoTestCaseStore = defineStore('autoTestCase', {
  state: () => ({
    caseList: [] as TestCase[],
    caseTotal: 0,
    currentCase: null as TestCase | null,
    loading: false,
  }),

  getters: {
    getCaseById: (state) => (id: number) => state.caseList.find(c => c.id === id),
  },

  actions: {
    async fetchCaseList(params: TestCaseListParams) {
      this.loading = true;
      try {
        const res = await getTestCaseList(params);
        this.caseList = res.data.list;
        this.caseTotal = res.data.total;
      } finally {
        this.loading = false;
      }
    },

    async fetchCaseDetail(id: number) {
      this.loading = true;
      try {
        const res = await getTestCaseDetail(id);
        this.currentCase = res.data;
        return res.data;
      } finally {
        this.loading = false;
      }
    },

    async createCase(data: CreateTestCaseParams) {
      const res = await createTestCase(data);
      return res.data;
    },

    async updateCase(id: number, data: Partial<CreateTestCaseParams>) {
      const res = await updateTestCase(id, data);
      return res.data;
    },

    async deleteCase(id: number) {
      await deleteTestCase(id);
    },

    async runCase(testCaseId: number, environment?: any) {
      const res = await runTestCase({ test_case_id: testCaseId, environment });
      return res.data;
    },
  },
});

// Bug分析 Store
export const useBugAnalysisStore = defineStore('bugAnalysis', {
  state: () => ({
    bugList: [] as BugAnalysis[],
    bugTotal: 0,
    currentBug: null as BugAnalysis | null,
    loading: false,
    analyzing: false,
    fixing: false,
  }),

  getters: {
    getBugById: (state) => (id: number) => state.bugList.find(b => b.id === id),
    pendingBugs: (state) => state.bugList.filter(b => b.status === 'pending'),
    resolvedBugs: (state) => state.bugList.filter(b => b.status === 'resolved' || b.status === 'closed'),
  },

  actions: {
    async fetchBugList(params: BugAnalysisListParams) {
      this.loading = true;
      try {
        const res = await getBugAnalysisList(params);
        this.bugList = res.data.list;
        this.bugTotal = res.data.total;
      } finally {
        this.loading = false;
      }
    },

    async fetchBugDetail(id: number) {
      this.loading = true;
      try {
        const res = await getBugAnalysisDetail(id);
        this.currentBug = res.data;
        return res.data;
      } finally {
        this.loading = false;
      }
    },

    async analyzeBug(data: AIBugAnalysisParams) {
      this.analyzing = true;
      try {
        const res = await analyzeBug(data);
        return res.data;
      } finally {
        this.analyzing = false;
      }
    },

    async fixBug(data: AIAutoFixParams) {
      this.fixing = true;
      try {
        const res = await autoFixBug(data);
        return res.data;
      } finally {
        this.fixing = false;
      }
    },

    async updateStatus(id: number, status: string, remark?: string) {
      await updateBugStatus(id, status, remark);
    },

    // AI Agent actions
    async aiAnalyzeBug(data: AIBugAnalysisParams) {
      this.analyzing = true;
      try {
        const res = await aiAnalyzeBug(data);
        return res.data;
      } finally {
        this.analyzing = false;
      }
    },

    async aiAutoFix(data: AIAutoFixParams) {
      this.fixing = true;
      try {
        const res = await aiAutoFix(data);
        return res.data;
      } finally {
        this.fixing = false;
      }
    },

    async aiVerifyFix(bugAnalysisId: number) {
      const res = await aiVerifyFix({ bug_analysis_id: bugAnalysisId });
      return res.data;
    },
  },
});

// 测试执行 Store
export const useTestExecutionStore = defineStore('testExecution', {
  state: () => ({
    executionList: [] as TestExecution[],
    executionTotal: 0,
    currentExecution: null as TestExecution | null,
    logs: [] as any[],
    loading: false,
  }),

  getters: {
    runningExecutions: (state) => state.executionList.filter(e => e.status === 'running'),
    latestExecution: (state) => state.executionList[0],
  },

  actions: {
    async fetchExecutionList(params: TestExecutionListParams) {
      this.loading = true;
      try {
        const res = await getTestExecutionList(params);
        this.executionList = res.data.list;
        this.executionTotal = res.data.total;
      } finally {
        this.loading = false;
      }
    },

    async fetchExecutionDetail(id: number) {
      this.loading = true;
      try {
        const res = await getTestExecutionDetail(id);
        this.currentExecution = res.data;
        return res.data;
      } finally {
        this.loading = false;
      }
    },

    async fetchExecutionLogs(executionId: number, cursor?: string) {
      const res = await getExecutionLogs(executionId, { cursor, limit: 100 });
      return res.data;
    },

    async aiExecuteTask(testTaskId: number, options?: { parallel?: boolean; retry_failed?: boolean }) {
      const res = await aiExecuteTestTask({ test_task_id: testTaskId, execute_options: options });
      return res.data;
    },
  },
});

// 测试报告 Store
export const useTestReportStore = defineStore('testReport', {
  state: () => ({
    reportList: [] as TestReport[],
    reportTotal: 0,
    currentReport: null as TestReport | null,
    loading: false,
  }),

  getters: {
    latestReports: (state) => state.reportList.slice(0, 5),
  },

  actions: {
    async fetchReportList(params?: any) {
      this.loading = true;
      try {
        const res = await getTestReportList(params);
        this.reportList = res.data.list;
        this.reportTotal = res.data.total;
      } finally {
        this.loading = false;
      }
    },

    async fetchReportDetail(id: number) {
      this.loading = true;
      try {
        const res = await getTestReportDetail(id);
        this.currentReport = res.data;
        return res.data;
      } finally {
        this.loading = false;
      }
    },

    async generateReport(data: { test_execution_id?: number; test_task_id?: number; type: string; format: string }) {
      const res = await generateTestReport(data);
      return res.data;
    },
  },
});

// 测试套件 Store
export const useTestSuiteStore = defineStore('testSuite', {
  state: () => ({
    suiteList: [] as any[],
    loading: false,
  }),

  actions: {
    async fetchSuiteList() {
      this.loading = true;
      try {
        const res = await getTestSuiteList();
        this.suiteList = res.data.list;
      } finally {
        this.loading = false;
      }
    },
  },
});

// 测试模块 Store
export const useTestModuleStore = defineStore('testModule', {
  state: () => ({
    moduleList: [] as any[],
    loading: false,
  }),

  actions: {
    async fetchModuleList() {
      this.loading = true;
      try {
        const res = await getTestModuleList();
        this.moduleList = res.data.list;
      } finally {
        this.loading = false;
      }
    },
  },
});

// AI测试用例生成 Store
export const useAITestCaseStore = defineStore('aiTestCase', {
  state: () => ({
    generating: false,
    generatedCases: [] as TestCase[],
    lastGenerationTime: 0,
    tokensUsed: 0,
  }),

  actions: {
    async generateTestCases(data: AIGenerateTestCaseParams) {
      this.generating = true;
      try {
        const res = await aiGenerateTestCases(data);
        this.generatedCases = res.data.test_cases;
        this.lastGenerationTime = res.data.generation_time;
        this.tokensUsed = res.data.tokens_used;
        return res.data;
      } finally {
        this.generating = false;
      }
    },
  },
});
