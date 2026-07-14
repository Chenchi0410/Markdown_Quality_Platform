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
          <section className="hero">
            <div className="hero-copy">
              <span className="eyebrow">MARKDOWN QUALITY WORKSPACE</span>
              <h1>让 Markdown 转换质量，<br />看得见、可比较、可修复。</h1>
              <p>
                一个入口，覆盖评测基准构建、转换效果评测与语法格式检测，
                为不同数据条件提供清晰的质量验证路径。
              </p>
            </div>
            <div className="hero-index" aria-hidden="true">
              <span>MD</span>
              <strong>03</strong>
              <small>QUALITY TOOLS</small>
            </div>
          </section>

          <section className="workflow" aria-labelledby="workflow-title">
            <div className="workflow-heading">
              <span>推荐工作流</span>
              <h2 id="workflow-title">根据现有数据，选择合适的质量路径</h2>
            </div>
            <div className="workflow-paths">
              <button type="button" onClick={() => navigate("dataset-builder")}>
                <small>有 PDF + 人工标注 MD</small>
                <strong>构建黄金评测集</strong>
              </button>
              <span className="path-arrow" aria-hidden="true">→</span>
              <button type="button" onClick={() => navigate("evaluation")}>
                <small>已有黄金评测集</small>
                <strong>评测转换效果</strong>
              </button>
              <span className="path-divider">或</span>
              <button type="button" onClick={() => navigate("syntax-check")}>
                <small>没有黄金数据</small>
                <strong>进行语法格式检测</strong>
              </button>
            </div>
          </section>

          <section className="module-section" aria-labelledby="module-title">
            <div className="section-heading">
              <span>平台能力</span>
              <h2 id="module-title">三个工具，一套完整的质量检查链路</h2>
            </div>
            <div className="module-grid">
              {modules.map((item) => (
                <article className={`module-card ${item.tone}`} key={item.id}>
                  <div className="card-top">
                    <span className="card-number">{item.number}</span>
                    <span className="card-label">{item.shortTitle}</span>
                  </div>
                  <h3>{item.title}</h3>
                  <p>{item.description}</p>
                  <small>{item.detail}</small>
                  <button type="button" onClick={() => navigate(item.id)}>
                    {item.action}<span aria-hidden="true">↗</span>
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
