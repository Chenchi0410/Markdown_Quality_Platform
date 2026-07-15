# Markdown 质量评测平台

统一入口，用于访问三个独立的 Markdown 质量工具：

- 转换效果评测：`/evaluation/`
- 评测集构建：`/dataset-builder/`
- 语法格式检测：`/syntax-check/`

门户通过同源 iframe 加载三个系统。三个业务系统以 Git Submodule 固定版本，仍保留各自独立仓库。

## 仓库结构

```text
Markdown_Quality_Platform/
├── src/                         # 统一 React 门户
├── services/
│   ├── doc-eval/                # 转换效果评测 submodule
│   ├── dataset-builder/         # 评测集构建 submodule
│   └── grammar-check/           # 语法格式检测 submodule
└── deploy/
    ├── nginx/                   # Windows 联调与 Ubuntu 生产配置
    ├── systemd/                 # 三个后端服务
    ├── install-ubuntu.sh
    ├── update-ubuntu.sh
    └── verify-ubuntu.sh
```

## 本地开发

```powershell
npm install
npm run dev
```

门户默认运行在 `http://127.0.0.1:5174/`。开发模式会将三个 iframe 分别连接到
`8000`、`8001` 和 `5173`；对应服务未启动时，该模块会显示连接失败。

## 构建

```powershell
npm run build
```

生产文件输出至 `dist/`，后续由统一 Nginx 在根路径 `/` 提供。

## Windows 本地联调

本地 Nginx 将以下服务统一到 `http://127.0.0.1/`：

| 路径 | 本地服务 |
|---|---|
| `/` | 门户 `127.0.0.1:5174` |
| `/evaluation/`、`/api/evaluation/` | 转换效果评测 `127.0.0.1:8000` |
| `/dataset-builder/`、`/api/dataset-builder/` | 评测集构建 `127.0.0.1:8001` |
| `/syntax-check/` | 语法检测前端 `127.0.0.1:5173` |
| `/api/syntax/` | 语法检测后端 `127.0.0.1:3000` |

一键启动五个本地服务和 Nginx：

```powershell
.\deploy\start-windows-stack.ps1
```

一键停止：

```powershell
.\deploy\stop-windows-stack.ps1
```

如果五个应用已经由各自的开发命令启动，也可以只运行
`.\deploy\start-windows-nginx.ps1`。

## Ubuntu 生产部署

生产结构：

```text
内网用户 → Nginx :80
             ├── /                         门户静态文件
             ├── /evaluation/              FastAPI :8000
             ├── /dataset-builder/         FastAPI :8001
             ├── /syntax-check/             语法检测静态文件
             └── /api/syntax/               Node.js :3000
```

门户和语法检测前端由 Nginx直接托管生产构建，不运行 Vite。三个后端只监听
`127.0.0.1`，分别由 systemd 管理。

### 1. 服务器要求

- Ubuntu 24.04 或具备 Python 3.12 的兼容版本
- Git
- Python 3.12、`venv` 和 pip
- Node.js 22 或更高版本、npm
- `uv`
- Nginx、curl、systemd
- 能访问 GitHub、PyPI 和 npm 仓库

基础软件示例：

```bash
sudo apt update
sudo apt install -y git nginx curl python3.12 python3.12-venv

node --version       # 必须 >= 22
npm --version
uv --version
python3.12 --version
```

Node.js 和 `uv` 请使用公司批准的软件源或安装方式。

### 2. 克隆完整仓库

必须包含 submodule，并使用固定目录：

```bash
sudo git clone --recurse-submodules \
  https://github.com/Chenchi0410/Markdown_Quality_Platform.git \
  /opt/markdown-quality-platform

cd /opt/markdown-quality-platform
git submodule status
```

三个 submodule 行首不能出现 `-`；出现时执行：

```bash
sudo git submodule update --init --recursive
```

### 3. 安装和构建

如果这是本平台独占的新服务器，可以替换 Ubuntu 默认 Nginx 站点：

```bash
cd /opt/markdown-quality-platform
sudo REPLACE_DEFAULT_NGINX_SITE=1 bash deploy/install-ubuntu.sh
```

如果 Nginx 已承载其他系统，不要删除原有默认站点。先让运维把
`deploy/nginx/ubuntu.conf` 的 location 合并到现有站点，然后跳过本项目的站点文件安装：

```bash
sudo SKIP_NGINX_SITE=1 bash deploy/install-ubuntu.sh
```

安装脚本会：

- 创建低权限用户 `md-platform`
- 创建共享目录 `/srv/markdown-quality-platform/datasets`
- 初始化并锁定三个 submodule
- 安装 Python/Node.js 依赖并构建两个前端
- 安装三个 systemd 单元和 Nginx 配置
- 执行 `nginx -t`

脚本不会自动启动服务。

### 4. 分别启动服务

```bash
sudo systemctl enable --now markdown-evaluation
sudo systemctl enable --now markdown-dataset-builder
sudo systemctl enable --now markdown-syntax-api
sudo systemctl enable --now nginx
```

查看状态：

```bash
systemctl status markdown-evaluation --no-pager
systemctl status markdown-dataset-builder --no-pager
systemctl status markdown-syntax-api --no-pager
systemctl status nginx --no-pager
```

### 5. 验证

```bash
sudo bash /opt/markdown-quality-platform/deploy/verify-ubuntu.sh
```

全部通过后，内网用户访问：

```text
http://服务器内网IP/
```

只需向内网开放 TCP 80；不要开放 `3000`、`8000`、`8001`。

### 6. 共享评测集

两个 Python 服务使用同一个目录：

```text
/srv/markdown-quality-platform/datasets
```

安装脚本会创建以下符号链接，使上游 `doc-eval` 使用同一目录：

```text
/opt/markdown-quality-platform/services/doc-eval/datasets
  -> /srv/markdown-quality-platform/datasets
```

第二个系统发布完成后，第一个系统需要重启才能重新扫描数据集：

```bash
sudo systemctl restart markdown-evaluation
```

### 7. 更新

确认集成仓库的新版本已推送后执行：

```bash
sudo bash /opt/markdown-quality-platform/deploy/update-ubuntu.sh
```

共享 Nginx 服务器更新时继续传入：

```bash
sudo SKIP_NGINX_SITE=1 \
  bash /opt/markdown-quality-platform/deploy/update-ubuntu.sh
```

更新脚本会拒绝覆盖服务器上的本地修改，重新同步 submodule、构建项目、安装配置，
然后依次重启三个服务并验证。

### 8. 日志与停止

```bash
sudo journalctl -u markdown-evaluation -f
sudo journalctl -u markdown-dataset-builder -f
sudo journalctl -u markdown-syntax-api -f
sudo tail -f /var/log/nginx/markdown-quality-platform.error.log
```

服务可分别停止：

```bash
sudo systemctl stop markdown-evaluation
sudo systemctl stop markdown-dataset-builder
sudo systemctl stop markdown-syntax-api
sudo systemctl stop nginx
```
