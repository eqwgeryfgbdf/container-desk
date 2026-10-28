from pathlib import Path
from html import escape
import json
root=Path(__file__).resolve().parents[1]
release='https://github.com/eqwgeryfgbdf/container-desk/releases/download/v1.0.0/Container-Desk-1.0.0-arm64.dmg'
repo='https://github.com/eqwgeryfgbdf/container-desk'
copy={
'en':{
'path':'/en/','title':'Apple Container Desk — A calmer home for your containers.','desc':'A native Mac app for Apple Container. Manage containers, images, files and projects in one thoughtful workspace. Free and open source.',
'navFeatures':'Features','navStart':'Get started','download':'Download for Mac','eyebrow':'YOUR MAC. YOUR CONTAINERS.','headline':'Powerful containers.','accent':'Beautifully simple.','intro':'Meet a calmer way to work with Apple Container. Your containers, images and projects, together in a native Mac app.','source':'Explore on GitHub','requirements':'macOS 26+ · Apple Silicon · Free & open source','badge':'Made for your Mac','badgeSub':'Native SwiftUI experience','shots':['Overview','Containers','Create a container'],'shotAlts':['Container Desk overview showing real Mac specifications and container resource usage','Container management with searchable rows, running states and resource metrics','Container creation with downloaded image picker, CPU menu and memory controls'],'shotNote':'Real app captures from version 0.2.0. Host names are masked.','viewFull':'View full-size screenshot',
'principles':['Native SwiftUI','Apple Container','Apache-2.0'],
'featureEye':'LESS FRICTION. MORE FLOW.','featureTitle':'Everything in its place.','featureIntro':'The controls you reach for every day, designed to feel at home on your Mac.',
'features':[
('01','See the whole picture.','A clear overview of your Mac, running containers and resource use. Double-click a container to focus on the details.','Actual host information'),
('02','From image to running service.','Search Docker Hub, inspect available architectures, download an image and configure your container in one flow.','Search. Choose. Deploy.'),
('03','Make room for your workflow.','Manage files, networks and volumes. Review batch actions, browse logs and open published web ports with a click.','The everyday essentials'),
('04','Bring your projects along.','Import supported Compose configurations and review Docker project conversions. Unsupported settings are clearly identified.','Review before you migrate')],
'aiTag':'LOCAL AI + MCP','aiTitle':'A workspace for local AI.','aiText':'Search Hugging Face GGUF models, run llama.cpp CPU inference in a container, and test MCP capability before approving tool calls. Included in 1.0; compatibility depends on the model.',
'startEye':'A FEW CLICKS TO YOUR FIRST CONTAINER.','startTitle':'Ready when you are.','steps':[
('Download the app.','Open the DMG and drag Container Desk into Applications.'),('Connect the engine.','Use Container Engine to connect to or install the supported official Apple Container release.'),('Make it your workspace.','Choose an image, set resources and ports, then create and start your container.')],
'guide':'Read the quick-start guide','guideFile':'QUICK_START.md','installNote':'The current build is ad hoc signed and is not Apple-notarized. Read the installation guide if macOS blocks it. Apple Container is a separate installation.',
'faqTitle':'A little more to know.','faq':[
('Which Macs are supported?','Apple Silicon Macs running macOS 26 or later. The public release was tested with Apple Container 1.5.0 on the developer’s own M4 Mac mini.'),('Can every Docker project move over?','Supported Compose settings can be imported and reviewed. Local Docker images and persistent data need separate migration. Selecting ARM64 or AMD64 is not binary conversion.'),('Is Container Desk an Apple product?','No. Container Desk is an independent, Apache-2.0 open-source application that manages the official Apple Container engine.')],
'ctaTitle':'Your containers.\nA clearer view.','ctaText':'A small app for a more focused workflow.','downloadMeta':'Version 1.0.0 · ARM64 · DMG hosted on GitHub','releaseNotes':'Release notes','footer':'An independent open-source project. Not affiliated with Apple.','back':'Part of EMO-Lab','skip':'Skip to content','notFound':'This page is not here.'},
'zh-Hant':{
'path':'/','title':'Apple Container Desk — 讓容器管理，簡單而優雅。','desc':'專為 Mac 打造的 Apple Container 圖形管理工具。容器、映像檔、檔案與專案，一個原生介面即可掌握。免費、開源。',
'navFeatures':'功能特色','navStart':'快速上手','download':'下載 Mac 版','eyebrow':'YOUR MAC. YOUR CONTAINERS.','headline':'容器管理，','accent':'就該如此簡單。','intro':'用熟悉的 Mac 方式，掌握 Apple Container。\n容器、映像檔與專案，在同一個原生介面裡各就各位。','source':'前往 GitHub','requirements':'macOS 26 以上 · Apple Silicon · 免費開源','badge':'為你的 Mac 而生','badgeSub':'原生 SwiftUI 操作體驗','shots':['總覽','容器管理','建立容器'],'shotAlts':['Container Desk 總覽，顯示實際 Mac 規格與容器資源用量','容器管理頁面，包含搜尋、執行狀態與資源用量','建立容器介面，包含已下載映像檔選單、CPU 與記憶體設定'],'shotNote':'0.2.0 正式版實機截圖，主機名稱已遮蔽。','viewFull':'查看完整尺寸截圖',
'principles':['原生 SwiftUI','Apple Container','Apache-2.0 開源授權'],
'featureEye':'LESS FRICTION. MORE FLOW.','featureTitle':'常用功能，恰到好處。','featureIntro':'把每天需要的操作整理好，讓你專注在真正想做的事。',
'features':[
('01','全貌，一眼掌握。','實際主機規格、容器狀態與資源用量，清楚呈現。雙擊容器展開詳細資訊，讓注意力回到正在進行的工作。','讀取真實主機資訊'),
('02','從搜尋，到啟動。','搜尋 Docker Hub、查看可用架構、下載映像檔，再設定容器。把原本分散的步驟，串成順手的流程。','搜尋、選擇、部署'),
('03','配合你的工作方式。','管理檔案、網路與儲存卷，檢查批量操作、查看日誌。點一下已發布的網頁連接埠，就能開啟服務。','日常操作，一應俱全'),
('04','讓既有專案接著走。','匯入支援的 Compose 設定，檢查 Docker 專案轉換結果。不支援的欄位會明確標示，讓搬移更有依據。','先檢查，再遷移')],
'aiTag':'本機 AI + MCP','aiTitle':'本機 AI，有自己的工作區。','aiText':'搜尋 Hugging Face GGUF 模型、以 llama.cpp 在容器內執行 CPU 推論，先測試 MCP 能力，再確認工具呼叫。1.0 已整合；模型相容性依實測結果而定。',
'startEye':'A FEW CLICKS TO YOUR FIRST CONTAINER.','startTitle':'準備好，就開始。','steps':[
('下載並安裝。','開啟 DMG，將 Container Desk 拖入「應用程式」。'),('連接容器引擎。','在「容器引擎」頁面，連接或安裝支援的 Apple 官方 Container 版本。'),('建立你的工作區。','選擇映像檔、設定資源與連接埠，建立並啟動容器。')],
'guide':'閱讀快速上手教學','guideFile':'QUICK_START.zh-Hant.md','installNote':'目前版本採 ad hoc 簽署，尚未經 Apple 公證。若 macOS 阻擋開啟，請依安裝教學處理。Apple Container 引擎需另外安裝。',
'faqTitle':'你可能還想知道。','faq':[
('哪些 Mac 可以使用？','需要搭載 Apple Silicon 的 Mac 與 macOS 26 以上系統。正式版在開發者自己的 M4 Mac mini 上，搭配 Apple Container 1.5.0 測試。'),('所有 Docker 專案都能直接搬移嗎？','支援的 Compose 設定可匯入並檢查；Docker 本機映像檔與持久資料仍需另行搬移。選擇 ARM64 或 AMD64 架構不代表轉換二進位程式。'),('這是 Apple 官方的應用程式嗎？','Container Desk 是獨立開發、採 Apache-2.0 授權的開源應用程式，用來管理 Apple 官方的 Container 引擎。')],
'ctaTitle':'你的容器，\n清楚在眼前。','ctaText':'讓日常管理更輕鬆，從一個小小的 App 開始。','downloadMeta':'1.0.0 正式版 · ARM64 · DMG 由 GitHub 提供','releaseNotes':'版本說明','footer':'獨立開發的開源專案，與 Apple 無隸屬關係。','back':'EMO-Lab 的開源專案','skip':'跳至主要內容','notFound':'這個頁面不存在。'},
'zh-Hans':{
'path':'/zh-Hans/','title':'Apple Container Desk — 让容器管理，简单而优雅。','desc':'专为 Mac 打造的 Apple Container 图形管理工具。容器、镜像、文件与项目，一个原生界面即可掌握。免费、开源。',
'navFeatures':'功能特色','navStart':'快速上手','download':'下载 Mac 版','eyebrow':'YOUR MAC. YOUR CONTAINERS.','headline':'容器管理，','accent':'就该如此简单。','intro':'用熟悉的 Mac 方式，掌握 Apple Container。\n容器、镜像与项目，在同一个原生界面里各就各位。','source':'前往 GitHub','requirements':'macOS 26 及以上 · Apple Silicon · 免费开源','badge':'为你的 Mac 而生','badgeSub':'原生 SwiftUI 操作体验','shots':['总览','容器管理','创建容器'],'shotAlts':['Container Desk 总览，显示实际 Mac 规格与容器资源用量','容器管理页面，包含搜索、运行状态与资源用量','创建容器界面，包含已下载镜像菜单、CPU 与内存设置'],'shotNote':'0.2.0 正式版实机截图，主机名称已遮蔽。','viewFull':'查看完整尺寸截图',
'principles':['原生 SwiftUI','Apple Container','Apache-2.0 开源许可'],
'featureEye':'LESS FRICTION. MORE FLOW.','featureTitle':'常用功能，恰到好处。','featureIntro':'把每天需要的操作整理好，让你专注于真正想做的事。',
'features':[
('01','全貌，一眼掌握。','实际主机规格、容器状态与资源用量，清楚呈现。双击容器展开详细信息，让注意力回到正在进行的工作。','读取真实主机信息'),
('02','从搜索，到启动。','搜索 Docker Hub、查看可用架构、下载镜像，再配置容器。把原本分散的步骤，串成顺手的流程。','搜索、选择、部署'),
('03','配合你的工作方式。','管理文件、网络与存储卷，检查批量操作、查看日志。点击已发布的网页端口，就能打开服务。','日常操作，一应俱全'),
('04','让现有项目接着走。','导入支持的 Compose 配置，检查 Docker 项目转换结果。不支持的字段会明确标示，让迁移更有依据。','先检查，再迁移')],
'aiTag':'本地 AI + MCP','aiTitle':'本地 AI，有自己的工作区。','aiText':'搜索 Hugging Face GGUF 模型，通过 llama.cpp 在容器内执行 CPU 推理，先测试 MCP 能力，再确认工具调用。1.0 已整合；模型兼容性以实测为准。',
'startEye':'A FEW CLICKS TO YOUR FIRST CONTAINER.','startTitle':'准备好，就开始。','steps':[
('下载并安装。','打开 DMG，将 Container Desk 拖入“应用程序”。'),('连接容器引擎。','在“容器引擎”页面，连接或安装支持的 Apple 官方 Container 版本。'),('创建你的工作区。','选择镜像、配置资源和端口，创建并启动容器。')],
'guide':'阅读快速上手教程','guideFile':'QUICK_START.zh-Hans.md','installNote':'当前版本采用 ad hoc 签名，尚未经过 Apple 公证。若 macOS 阻止打开，请按照安装教程处理。Apple Container 引擎需单独安装。',
'faqTitle':'你可能还想知道。','faq':[
('哪些 Mac 可以使用？','需要搭载 Apple Silicon 的 Mac 和 macOS 26 及以上系统。正式版在开发者自己的 M4 Mac mini 上，搭配 Apple Container 1.5.0 测试。'),('所有 Docker 项目都能直接迁移吗？','支持的 Compose 配置可导入并检查；Docker 本地镜像与持久数据仍需单独迁移。选择 ARM64 或 AMD64 架构不代表转换二进制程序。'),('这是 Apple 官方的应用程序吗？','Container Desk 是独立开发、采用 Apache-2.0 许可的开源应用程序，用于管理 Apple 官方的 Container 引擎。')],
'ctaTitle':'你的容器，\n清楚在眼前。','ctaText':'让日常管理更轻松，从一个小小的 App 开始。','downloadMeta':'1.0.0 正式版 · ARM64 · DMG 由 GitHub 提供','releaseNotes':'版本说明','footer':'独立开发的开源项目，与 Apple 无隶属关系。','back':'EMO-Lab 的开源项目','skip':'跳至主要内容','notFound':'这个页面不存在。'}
}
icons=['<rect x="3" y="4" width="18" height="14" rx="3"/><path d="M8 22h8m-4-4v4M7 10h3m4 0h3M7 14h10"/>','<path d="m12 3 9 5-9 5-9-5 9-5Zm-9 5v9l9 5 9-5V8M12 13v9m-4.5-16L16 11"/>','<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4m10-4v4M7 12h10m-10 4h6"/>','<path d="M8 4H4v16h4M16 4h4v16h-4M8 12h8m-3-3 3 3-3 3"/>']
def e(s):return escape(s,quote=True)
def nl(s):return e(s).replace('\n','<br>')
for lang,c in copy.items():
 langs="".join('<a href="{}" lang="{}" hreflang="{}" aria-label="{}" aria-current="{}">{}</a>'.format(v["path"],k,k,{"en":"English","zh-Hant":"繁體中文","zh-Hans":"简体中文"}[k],"page" if k==lang else "false",{"en":"EN","zh-Hant":"繁","zh-Hans":"简"}[k]) for k,v in copy.items())
 tabs=''.join(f'<button type="button" role="tab" id="shot-tab-{i}" aria-controls="shot-panel" aria-selected="{str(i==0).lower()}" tabindex="{0 if i==0 else -1}" data-src="/assets/{file}" data-alt="{e(c["shotAlts"][i])}">{e(label)}</button>' for i,(label,file) in enumerate(zip(c['shots'],['overview.png','containers.jpg','create.png'])))
 features=''.join(f'<article class="feature reveal"><div class="feature-top"><svg viewBox="0 0 24 24" aria-hidden="true">{icons[i]}</svg><span>{num}</span></div><h3>{e(title)}</h3><p>{e(body)}</p><span class="feature-note">{e(note)}</span></article>' for i,(num,title,body,note) in enumerate(c['features']))
 steps=''.join(f'<article class="reveal"><span class="step-number">{i+1:02}</span><h3>{e(title)}</h3><p>{e(body)}</p></article>' for i,(title,body) in enumerate(c['steps']))
 faq=''.join(f'<details><summary>{e(q)}<span aria-hidden="true">+</span></summary><p>{e(a)}</p></details>' for q,a in c['faq'])
 alternates=''.join(f'<link rel="alternate" hreflang="{k}" href="https://container.emo-lab.com{v["path"]}">' for k,v in copy.items())
 html=f'''<!doctype html>
<html lang="{lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{e(c['title'])}</title><meta name="description" content="{e(c['desc'])}"><meta name="theme-color" content="#f5f8fc"><link rel="canonical" href="https://container.emo-lab.com{c['path']}">{alternates}<link rel="icon" type="image/png" href="/assets/app-icon-vm-package.png"><meta property="og:title" content="{e(c['title'])}"><meta property="og:site_name" content="Apple Container Desk"><meta name="twitter:title" content="{e(c['title'])}"><meta property="og:description" content="{e(c['desc'])}"><meta property="og:type" content="website"><meta property="og:url" content="https://container.emo-lab.com{c['path']}"><meta property="og:image" content="https://container.emo-lab.com/assets/overview.png"><meta name="twitter:card" content="summary_large_image"><link rel="stylesheet" href="/style.css"><script src="/app.js" defer></script><script src="/locale.js" defer></script></head>
<body><a class="skip" href="#main">{e(c['skip'])}</a><header class="site-header"><nav class="nav wrap" aria-label="Main"><a href="{c['path']}" class="brand"><img src="/assets/app-icon-vm-package.png" width="44" height="44" alt="">Container Desk</a><div class="nav-links"><a href="#features">{e(c['navFeatures'])}</a><a href="#start">{e(c['navStart'])}</a><a href="{repo}">GitHub ↗</a></div><div class="nav-end"><div class="languages" aria-label="Language">{langs}</div><a class="button small" data-download href="{release}">{e(c['download'])}<span aria-hidden="true">↗</span></a></div></nav></header>
<main id="main"><section class="hero wrap"><img class="hero-logo" src="/assets/app-icon-vm-package.png" width="128" height="128" alt="Container Desk"><div class="eyebrow"><span class="live-dot"></span>{e(c['eyebrow'])}</div><h1>{e(c['headline'])}<br><span>{e(c['accent'])}</span></h1><p class="hero-intro">{nl(c['intro'])}</p><div class="hero-actions"><a class="button" data-download href="{release}">{e(c['download'])}<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12m-4-4 4 4 4-4M5 17v4h14v-4"/></svg></a><a class="text-link" href="{repo}">{e(c['source'])}<span aria-hidden="true">↗</span></a></div><p class="requirements">{e(c['requirements'])}</p>
<div class="showcase"><div class="halo" aria-hidden="true"></div><div class="floating-label"><span class="glass-icon" aria-hidden="true">⌘</span><div><strong>{e(c['badge'])}</strong><span>{e(c['badgeSub'])}</span></div></div><div class="screenshot-shell" role="tabpanel" id="shot-panel" aria-labelledby="shot-tab-0"><a id="full-shot" href="/assets/overview.png" target="_blank" rel="noopener" aria-label="{e(c['viewFull'])}"><img id="app-shot" src="/assets/overview.png" alt="{e(c['shotAlts'][0])}" width="1280" height="800" fetchpriority="high"></a></div><div class="shot-tabs" role="tablist" aria-label="App screenshots">{tabs}</div><p class="shot-note">{e(c['shotNote'])}</p></div></section>
<div class="principles wrap">{''.join(f'<span><i aria-hidden="true">✦</i>{e(x)}</span>' for x in c['principles'])}</div>
<section class="section wrap" id="features"><div class="section-heading reveal"><p class="eyebrow">{e(c['featureEye'])}</p><h2>{e(c['featureTitle'])}</h2><p>{e(c['featureIntro'])}</p></div><div class="feature-grid">{features}</div><aside class="ai-preview reveal"><div class="ai-orb" aria-hidden="true">✧</div><div><span class="tag">{e(c['aiTag'])}</span><h3>{e(c['aiTitle'])}</h3><p>{e(c['aiText'])}</p></div><span class="preview-version" aria-hidden="true">1.0</span></aside></section>
<section class="start-section" id="start"><div class="wrap"><div class="section-heading reveal"><p class="eyebrow">{e(c['startEye'])}</p><h2>{e(c['startTitle'])}</h2></div><div class="steps">{steps}</div><div class="guide-box"><a class="text-link" href="{repo}/blob/v1.0.0/docs/{c['guideFile']}">{e(c['guide'])} <span aria-hidden="true">↗</span></a><p>{e(c['installNote'])}</p></div></div></section>
<section class="faq wrap"><h2>{e(c['faqTitle'])}</h2><div>{faq}</div></section>
<section class="download-section wrap"><div class="download-card reveal"><img src="/assets/app-icon-vm-package.png" alt="" width="112" height="112" loading="lazy"><h2>{nl(c['ctaTitle'])}</h2><p>{e(c['ctaText'])}</p><a class="button" data-download href="{release}">{e(c['download'])}<span aria-hidden="true">↗</span></a><p class="download-meta">{e(c['downloadMeta'])}</p><a class="release-link" href="{repo}/releases/tag/v1.0.0">{e(c['releaseNotes'])} →</a></div></section></main>
<footer class="wrap"><div class="footer-top"><a class="lab-link" href="https://emo-lab.com/">EMO<span>—</span>LAB <small>{e(c['back'])} ↗</small></a><div><a href="{repo}">GitHub</a><a href="https://github.com/apple/container">Apple Container ↗</a><a href="{repo}/blob/main/LICENSE">Apache-2.0</a></div></div><div class="footer-bottom"><span>© 2026 Container Desk</span><span>{e(c['footer'])}</span></div></footer></body></html>'''
 target=root/'public'/c['path'].strip('/')/'index.html';target.parent.mkdir(parents=True,exist_ok=True);target.write_text(html)
(root/'public/404.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Page not found — Container Desk</title><link rel="stylesheet" href="/style.css"><main class="hero wrap"><h1>404</h1><p>This page is not here.</p><a class="button" href="/">Container Desk →</a></main></html>')
(root/'public/sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+''.join(f'<url><loc>https://container.emo-lab.com{c["path"]}</loc></url>' for c in copy.values())+'</urlset>')
(root/'public/robots.txt').write_text('User-agent: *\nAllow: /\nSitemap: https://container.emo-lab.com/sitemap.xml\n')
print('Built 3 languages + sitemap + 404')
