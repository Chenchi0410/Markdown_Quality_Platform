import { useEffect, useState } from "react";

type ModuleId = "home" | "evaluation" | "dataset-builder" | "syntax-check";

interface PlatformModule {
  id: Exclude<ModuleId, "home">;
  number: string;
  shortTitle: string;
  title: string;
  description: string;
  detail: string;
  path: string;
  action: string;
  tone: string;
}

interface Workflow {
  number: string;
  label: string;
  title: string;
  description: string;
  steps: string[];
  moduleId: PlatformModule["id"];
  action: string;
  tone: string;
}

const modules: PlatformModule[] = [
  {
    id: "evaluation",
    number: "01",
    shortTitle: "转换效果评测",
    title: "衡量转换结果，而不只检查文件是否生成",
    description: "使用黄金评测集，对各部门转换器输出的 Markdown 进行统一评分与对比。",
    detail: "适合已经拥有标准评测集，需要验证 PDF、DOCX 等文档转换质量的场景。",
    path: "/evaluation/",
    action: "进入转换效果评测",
    tone: "blue"
  },
  {
    id: "dataset-builder",
    number: "02",
    shortTitle: "评测集构建",
    title: "把部门数据，转化为可复用的评测基准",
    description: "上传同名 PDF 与人工标注的高质量 Markdown，生成适配评测系统的数据集。",
    detail: "构建完成后可发布到共享目录，作为部门自己的黄金评测集。",
    path: "/dataset-builder/",
    action: "进入评测集构建",
    tone: "green"
  },
  {
    id: "syntax-check",
    number: "03",
    shortTitle: "语法格式检测",
    title: "没有黄金数据，也能快速发现格式问题",
    description: "检测 Markdown 语法与排版问题，筛选问题并批量修复可安全处理的内容。",
    detail: "适合缺少原始数据或人工标注 Markdown 时，进行基础质量检查。",
    path: "/syntax-check/",
    action: "进入语法格式检测",
    tone: "amber"
  }
];

const developmentOrigins: Record<PlatformModule["id"], string> = {
  evaluation: "http://127.0.0.1:8000",
  "dataset-builder": "http://127.0.0.1:8001",
  "syntax-check": "http://127.0.0.1:5173"
};

const workflows: Workflow[] = [
  {
    number: "01",
    label: "已有部门转换器",
    title: "使用统一黄金数据，评测转换效果",
    description: "适用于多个部门需要在同一标准下验证各自 Markdown 转换器质量的场景。",
    steps: [
      "从转换效果评测系统下载黄金数据集 PDF",
      "使用本部门转换器将 PDF 转换为 Markdown",
      "上传转换后的 Markdown 文件",
      "查看统一指标评分与评测结果"
    ],
    moduleId: "evaluation",
    action: "进入转换效果评测",
    tone: "blue"
  },
  {
    number: "02",
    label: "已有 PDF + 人工检视 MD",
    title: "构建适配平台的部门评测集",
    description: "适用于部门已有自己的评测资料，但数据结构尚不符合统一评测系统要求的场景。",
    steps: [
      "准备同名 PDF 与人工检视后的 Markdown",
      "上传文件并构建标准评测集",
      "下载到本地，或发布到服务器共享目录",
      "由转换效果评测系统识别并使用新数据集"
    ],
    moduleId: "dataset-builder",
    action: "进入评测集构建",
    tone: "green"
  },
  {
    number: "03",
    label: "没有评测集",
    title: "直接检查 Markdown 语法格式",
    description: "适用于暂时没有黄金数据，只需要快速确认 Markdown 语法与排版是否存在问题的场景。",
    steps: [
      "上传 Markdown 文件或直接粘贴内容",
      "执行语法与排版检测",
      "查看问题，并处理可安全修复的内容"
    ],
    moduleId: "syntax-check",
    action: "进入语法格式检测",
    tone: "amber"
  }
];

function getModuleUrl(module: PlatformModule): string {
  if (import.meta.env.DEV) {
    return new URL(module.path, developmentOrigins[module.id]).toString();
  }

  return module.path;
}

function readModuleFromUrl(): ModuleId {
  const value = new URLSearchParams(window.location.search).get("module");
  return modules.some((item) => item.id === value) ? (value as ModuleId) : "home";
}

function App() {
  const [activeModule, setActiveModule] = useState<ModuleId>(readModuleFromUrl);

  useEffect(() => {
    const handlePopState = () => setActiveModule(readModuleFromUrl());
    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, []);

  const navigate = (next: ModuleId) => {
    const url = next === "home" ? "/" : `/?module=${next}`;
    window.history.pushState({}, "", url);
    setActiveModule(next);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const current = modules.find((item) => item.id === activeModule);
  const currentUrl = current ? getModuleUrl(current) : null;

  return (
    <div className={`app-shell ${current ? "has-module" : ""}`}>
      <header className="topbar">
        <button className="brand" type="button" onClick={() => navigate("home")} aria-label="返回平台首页">
          <span className="brand-mark">M</span>
          <span className="brand-copy">
            <strong>Markdown 质量评测平台</strong>
            <small>QUALITY WORKSPACE</small>
          </span>
        </button>
        <nav className="main-nav" aria-label="平台功能导航">
          <button className={activeModule === "home" ? "active" : ""} onClick={() => navigate("home")} type="button">
            首页
          </button>
          {modules.map((item) => (
            <button
              key={item.id}
              className={activeModule === item.id ? "active" : ""}
              onClick={() => navigate(item.id)}
              type="button"
            >
              {item.shortTitle}
            </button>
          ))}
        </nav>
      </header>

      {current ? (
        <main className="module-view">
          <div className="module-toolbar">
            <div>
              <span className={`module-dot ${current.tone}`} aria-hidden="true" />
              <strong>{current.shortTitle}</strong>
              <span>{current.description}</span>
            </div>
            <a href={currentUrl ?? current.path} target="_blank" rel="noreferrer">在新页面打开</a>
          </div>
          <iframe src={currentUrl ?? current.path} title={current.shortTitle} />
        </main>
      ) : (
        <main className="home-page">
          <section className="workflow" aria-labelledby="workflow-title">
            <div className="workflow-heading">
              <span>推荐工作流</span>
              <h2 id="workflow-title">从当前数据条件出发，选择对应工作流</h2>
              <p>每条路径都对应一种实际使用场景，并可直接进入所需工具。</p>
            </div>
            <div className="workflow-paths">
              {workflows.map((workflow) => (
                <article className={`workflow-card ${workflow.tone}`} key={workflow.number}>
                  <div className="workflow-card-heading">
                    <span className="workflow-number">{workflow.number}</span>
                    <div>
                      <small>{workflow.label}</small>
                      <h3>{workflow.title}</h3>
                    </div>
                  </div>
                  <p>{workflow.description}</p>
                  <ol className="workflow-steps">
                    {workflow.steps.map((step, index) => (
                      <li key={step}>
                        <span>{String(index + 1).padStart(2, "0")}</span>
                        <strong>{step}</strong>
                      </li>
                    ))}
                  </ol>
                  <button type="button" onClick={() => navigate(workflow.moduleId)}>
                    {workflow.action}<span aria-hidden="true">↗</span>
                  </button>
                </article>
              ))}
            </div>
          </section>

          <footer>
            <span>Markdown Quality Workspace</span>
            <span>面向内部文档转换与质量验证</span>
          </footer>
        </main>
      )}
    </div>
  );
}

export default App;
