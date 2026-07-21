<div class="doc-nav-header">
  <h1>DevBox Lite</h1>
  <span class="lang-links">
    <strong><a href="../en/README.md">English</a></strong> | <a href="../../README.md">بازگشت به خانه</a>
  </span>
</div>

سبک، ایزوله، و آماده کار — محیط توسعه‌ای مبتنی بر Docker + Ubuntu 24.04 که برای پروژه‌های **Laravel، Next.js، React و Python** طراحی شده.

---

## فهرست مطالب
<style>
  .custom-toc, 
  .custom-toc ul {
    list-style: none; /* حذف کامل بولت‌های پیش‌فرض CSS */
    padding-right: 0;
    margin: 0;
  }

  .custom-toc li {
    line-height: 2;
  }

  /* ۱. تنظیم آیتم‌های اصلی بدون زیرمجموعه (دایره پر) */
  .custom-toc > li:not(:has(details)) {
    display: flex;
    align-items: center;
  }

  .custom-toc > li:not(:has(details))::before {
    content: "•";
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;       /* عرض ثابت یکسان جهت هم‌راستایی */
    font-size: 1.2rem;
    line-height: 1;
    flex-shrink: 0;
  }

  /* ۲. تنظیم آیتم‌های دارای زیرمجموعه (مثلث) */
  .custom-toc details {
    width: 100%;
  }

  .custom-toc summary {
    cursor: pointer;
    display: flex;
    align-items: center; /* تراز کامل افقی/عمودی لینک و آیکون */
    list-style: none;    /* حذف مارکر پیش‌فرض استاندارد */
  }

  /* حذف مارکر پیش‌فرض وب‌کیت */
  .custom-toc summary::-webkit-details-marker {
    display: none;
  }

  /* آیکون مثلث در حالت بسته */
  .custom-toc summary::before {
    content: "◀";
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;       /* هم‌عرض با دایره پر */
    font-size: 0.7rem;
    line-height: 1;
    flex-shrink: 0;
  }

  /* آیکون مثلث در حالت باز (استفاده از کاراکتر مستقیم جهت جلوگیری از بهم خوردن مرکز) */
  .custom-toc details[open] > summary::before {
    content: "▼";
    font-size: 0.65rem;  /* تنظیم ظریف سایز برای تناسب بصری */
  }

  /* ۳. تنظیم زیرمجموعه‌ها (دایره‌های توخالی) */
  .custom-toc details ul {
    padding-right: 1.2rem;
    margin-top: 0.25rem;
    margin-bottom: 0.5rem;
  }

  .custom-toc details ul li {
    display: flex;
    align-items: center;
  }

  .custom-toc details ul li::before {
    content: "◦";        /* آیکون دایره توخالی */
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;       /* هم‌عرض با سطح اصلی */
    font-size: 1rem;
    font-weight: bold;
    line-height: 1;
    flex-shrink: 0;
  }
  .heading-with-back {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .heading-with-back span {
    flex: 1;
  }
  .back-to-toc {
    text-decoration: none !important;
  }
  .back-to-toc:hover {
    text-decoration: none !important;
  }
  table {
    margin-left: 0;
    margin-right: auto;
  }

  table th,
  table td {
    text-align: left !important;
    direction: ltr !important;
  }
  pre, code {
    direction: ltr !important;
    text-align: left !important;
  }
  .doc-nav-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }
  .doc-nav-header .lang-links {
    direction: ltr;
  }
</style>

<ul class="custom-toc" dir="rtl">
  <li><a href="#چرا-devbox-lite">چرا DevBox Lite؟</a></li>
  <li><a href="#ابزارهای-موجود">ابزارهای موجود</a></li>
  <li>
    <details>
      <summary><a href="#شروع-سریع">شروع سریع</a></summary>
      <ul>
        <li><a href="#پیشنیازها">پیش‌نیازها</a></li>
        <li><a href="#راهاندازی-در-ویندوز">راه‌اندازی در ویندوز</a></li>
        <li><a href="#راهاندازی-در-wsl2-توصیه-شده">راه‌اندازی در WSL2 (توصیه شده)</a></li>
        <li><a href="#دستورات-کوتاه-اختیاری">دستورات کوتاه (اختیاری)</a></li>
      </ul>
    </details>
  </li>
  <li><a href="#ساختار-پوشهبندی">ساختار پوشه‌بندی</a></li>
  <li>
    <details>
      <summary><a href="#ساخت-پروژه-جدید">ساخت پروژه جدید</a></summary>
      <ul>
        <li><a href="#روش-پیشنهادی-new-project-تعاملی-آفلاین">روش پیشنهادی: <code>new-project</code> (تعاملی، آفلاین)</a></li>
        <li><a href="#template-های-موجود">template های موجود</a></li>
        <li><a href="#روش-دستی-shell-ترمینال">روش دستی: <code>shell</code> (ترمینال)</a></li>
      </ul>
    </details>
  </li>
  <li><a href="#راهاندازی-خودکار-دیتابیسها">راه‌اندازی خودکار دیتابیس‌ها</a></li>
  <li><a href="#مستندات">مستندات</a></li>
  <li><a href="#لایسنس">لایسنس</a></li>
</ul>

### پیش‌نیازها

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) نصب و اجرا شده باشد
- [VS Code](https://code.visualstudio.com/) با افزونه [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### راه‌اندازی در ویندوز

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
cd D:\DevBox
.\scripts\build
.\scripts\up
```

سپس VS Code را باز کنید و از طریق Remote Explorer → Dev Containers به کانتینر وصل شوید.

### راه‌اندازی در WSL2 (توصیه شده)

> **چرا WSL2؟** عملیات فایل در Docker Desktop حدود ۱۰-۲۰ برابر کندتر از فایل‌سیستم بومی WSL2 است. برای توسعه جدی، WSL2 به شدت توصیه می‌شود.

**مرحله ۱:** نصب WSL2 (PowerShell به عنوان Administrator)

```bash
wsl --install
```

ری‌استارت کامپیوتر

**مرحله ۲:** نصب Docker در Ubuntu

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER && newgrp docker
```

**مرحله ۳:** فعال‌سازی Docker Desktop

Docker Desktop → Settings → WSL Integration → Ubuntu را فعال کنید

**مرحله ۴:** کلون و راه‌اندازی

```bash
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:efmojtaba1/DevBox.git && cd DevBox
echo "WORKSPACE_PATH=$PWD" > .env
chmod +x scripts/*.sh
./scripts/build.sh && ./scripts/up.sh && ./scripts/shell.sh
```

### دستورات کوتاه (اختیاری)

```bash
./scripts/setup-aliases.sh && source ~/.bashrc
```

حالا می‌توانید از این دستورات استفاده کنید:

| دستور | کاربرد |
|-------|--------|
| `up` | بالا آوردن کانتینر |
| `down` | توقف کانتینر |
| `down-v` | توقف کانتینر + حذف volume ها |
| `shell` | ورود به ترمینال کانتینر |
| `build` | ساخت ایمیج |
| `rebuild` | ساخت مجدد ایمیج |
| `logs` | مشاهده لاگ‌ها |
| `status` | بررسی وضعیت |
| `new-project` | ایجاد پروژه جدید (تعاملی، آفلاین) |
| `setup-deps` | راه‌اندازی خودکار دیتابیس و ابزارها |
| `init-example` | راه‌اندازی اولیه template ها (یکبار پس از rebuild) |
| `setup-example` | بررسی صحت template ها |
| `refresh-example` | بروزرسانی template ها به ورژن‌های جدید |

---

<h2 id="ساختار-پوشهبندی" class="heading-with-back">
  <span>ساختار پوشه‌بندی</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

```
DevBox_Lite/
├── docker/
│   ├── app/              # فایل‌های ساخت ایمیج
│   │   ├── Dockerfile
│   │   └── install/      # اسکریپت‌های نصب
│   └── compose/          # Docker Compose
├── scripts/              # اسکریپت‌های مدیریت
├── example/              # template های پروژه برای آفلاین
│   ├── laravel/          # اسکلت لاراول
│   ├── next-js/          # اسکلت نکست
│   ├── python/           # اسکلت پایتون
│   └── react/            # اسکلت ری‌اکت
├── docs/                 # مستندات فارسی و انگلیسی
├── prebuilt/             # ایمیج‌های آماده برای آفلاین
│   └── images/           # mysql-8.4.tar, postgres-17.tar, ...
└── workspace/            # پروژه‌های شما اینجا قرار می‌گیرند
```

> **نکته:**  ایمیج های موجود در پوشه `prebuilt/` به صورت خودکار به کانتینر مانت می‌شوند.

---

<h2 id="ساخت-پروژه-جدید" class="heading-with-back">
  <span>ساخت پروژه جدید</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

> **نکته مهم:** تمام دستورات توسعه **داخل کانتینر** اجرا می‌شوند.

### روش پیشنهادی: `new-project` (تعاملی، آفلاین)

```powershell
# از هاست — منوی تعاملی
.\scripts\devbox.sh new-project

# یا داخل کانتینر
new-project
```

اسکریپت نام پروژه، فریمورک و گزینه‌ها را مرحله به مرحله می‌پرسد. template ها از پوشه `example/` کپی می‌شوند (بدون نیاز به اینترنت).

### template های موجود

| template | گزینه‌ها | پورت |
|----------|---------|------|
| `laravel` | starter kit، دیتابیس، تست، dark mode، API | 8000 |
| `next-js` | TypeScript، Tailwind | 3000 |
| `react` | Vite + React 19 | 5173 |
| `python` | Flask، FastAPI، خام | 5001/8000 |

### روش دستی: `shell` (ترمینال)

```powershell
.\scripts\shell.ps1
# داخل کانتینر:
cd /workspace
laravel new my-app    # یا: pnpm create next-app و...
```



<h2 id="راهاندازی-خودکار-دیتابیسها" class="heading-with-back">
  <span>راه‌اندازی خودکار دیتابیس‌ها</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

اسکریپت `setup-deps` به صورت خودکار نوع پروژه‌ها را شناسایی و دیتابیس و ابزار گرافیکی مورد نیاز را راه‌اندازی می‌کند:

```bash
# از داخل کانتینر
setup-deps
```

| نوع پروژه | دیتابیس | ابزار گرافیکی |
|----------|---------|--------------|
| Laravel | MySQL + Redis | phpMyAdmin |
| Next.js / React | PostgreSQL | Adminer |
| Python | PostgreSQL | Adminer |



<h2 id="مستندات" class="heading-with-back">
  <span>مستندات</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |



<h2 id="لایسنس" class="heading-with-back">
  <span>لایسنس</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

این پروژه تحت لایسنس [LICENSE](../../LICENSE) است.



**ورژن فعلی:** lite-1.0.0
