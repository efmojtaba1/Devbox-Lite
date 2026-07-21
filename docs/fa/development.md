<div class="doc-nav-header">
  <h1>راهنمای توسعه DevBox Lite</h1>
  <span class="lang-links">
    <strong><a href="development.md">فارسی</a></strong> | <strong><a href="../en/development.md">English</a></strong> | <a href="README.md">بازگشت به خانه</a>
  </span>
</div>



## فهرست مطالب

<style>
  .custom-toc,
  .custom-toc ul {
    list-style: none;
    padding-right: 0;
    margin: 0;
  }
  .custom-toc li {
    line-height: 2;
  }
  .custom-toc > li:not(:has(details)) {
    display: flex;
    align-items: center;
  }
  .custom-toc > li:not(:has(details))::before {
    content: "•";
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;
    font-size: 1.2rem;
    line-height: 1;
    flex-shrink: 0;
  }
  .custom-toc details {
    width: 100%;
  }
  .custom-toc summary {
    cursor: pointer;
    display: flex;
    align-items: center;
    list-style: none;
  }
  .custom-toc summary::-webkit-details-marker {
    display: none;
  }
  .custom-toc summary::before {
    content: "◀";
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;
    font-size: 0.7rem;
    line-height: 1;
    flex-shrink: 0;
  }
  .custom-toc details[open] > summary::before {
    content: "▼";
    font-size: 0.65rem;
  }
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
    content: "◦";
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;
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
<li><a href="#معماری-پروژه">معماری پروژه</a></li>
<li><a href="#ساختار-dockerfile">ساختار Dockerfile</a></li>
<li>
<details><summary><a href="#نحوه-اضافه-کردن-نرمافزار-جدید">نحوه اضافه کردن نرم‌افزار جدید</a></summary>
<ul>
<li><a href="#۱-ایجاد-اسکریپت-نصب">۱. ایجاد اسکریپت نصب</a></li>
<li><a href="#۲-اضافه-کردن-به-dockerfile">۲. اضافه کردن به Dockerfile</a></li>
</ul>
</details>
</li>
<li><a href="#نحوه-تغییر-ورژن-ابزارها">نحوه تغییر ورژن ابزارها</a></li>
<li>
<details><summary><a href="#تست-و-اعتبارسنجی">تست و اعتبارسنجی</a></summary>
<ul>
<li><a href="#تست-ابزارها">تست ابزارها</a></li>
<li><a href="#تست-کل-ایمیج">تست کل ایمیج</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#سبک-کدنویسی">سبک کدنویسی</a></summary>
<ul>
<li><a href="#اسکریپتهای-شل">اسکریپت‌های شل</a></li>
<li><a href="#اسکریپتهای-powershell">اسکریپت‌های PowerShell</a></li>
<li><a href="#تنظیمات-pnpm-11">تنظیمات pnpm 11</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#پشتیبانی-آفلاین">پشتیبانی آفلاین</a></summary>
<ul>
<li><a href="#پکیج-های-آماده">پکیج‌های آماده</a></li>
<li><a href="#ایمیجهای-docker-آماده">ایمیج‌های Docker آماده</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#عملکرد-wsl2">عملکرد WSL2</a></summary>
<ul>
<li><a href="#چرا-wsl2">چرا WSL2؟</a></li>
<li><a href="#پیشنیازها">پیش‌نیازها</a></li>
<li><a href="#راهاندازی-کامل">راه‌اندازی کامل</a></li>
<li><a href="#بهینهسازی-منابع-wsl2">بهینه‌سازی منابع WSL2</a></li>
<li><a href="#مقایسه-عملکرد">مقایسه عملکرد</a></li>
</ul>
</details>
</li>
<li><a href="#مستندات">مستندات</a></li>
</ul>



<h2 id="معماری-پروژه" class="heading-with-back">
  <span>معماری پروژه</span>
</h2>

```
DevBox Lite/
├── docker/
│   ├── app/                  # فایل‌های ساخت ایمیج
│   │   ├── Dockerfile        # (multi-stage) فایل اصلی 
│   │   ├── .env              # ورژن ابزارها
│   │   ├── entrypoint.sh     # اسکریپت راه‌اندازی
│   │   └── install/          # اسکریپت‌های نصب مدولار
│   └── compose/              # Docker Compose فایل 
├── scripts/                  # اسکریپت‌های مدیریت
├── docs/                     # مستندات
│   ├── fa/                   # مستندات فارسی
│   └── en/                   # مستندات انگلیسی
├── prebuilt/                 # پکیج‌های آماده برای استفاده آفلاین
│   ├── images/               # آرشیو ایمیج‌های داکر
│   └── packages/             # Bruno پکیج‌های 
└── workspace/                # پوشه کاری پروژه‌ها
    ├── data/                 # داده‌های پایدار
    │   └── bruno/            # Postman آفلاین شبیه API ابزار تست  
    │       ├── collections/  # کالکشن‌ها و ریکوئست‌های ذخیره شده
    │       └── config/       # تنظیمات برنامه برونو
    ├── laravel/              # پروژه لاراول (مثال)
    ├── next-js/              # پروژه نکست (مثال)
    └── python/               # پروژه پایتون (مثال)
```



<h2 id="ساختار-dockerfile" class="heading-with-back">
  <span>ساختار Dockerfile</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

```
base → languages → frameworks → tools → extensions → cleanup → runtime
```

- **base:** Ubuntu 24.04 + پکیج‌های پایه
- **languages:** PHP, Node.js, Python, Composer, Bun
- **frameworks:** Laravel Installer
- **tools:** Database clients, GitHub CLI, Docker CLI, Nginx, Supervisor, PM2, Bruno
- **extensions:** Xdebug, Pest
- **cleanup:** پاکسازی کش‌ها
- **runtime:** تصویر نهایی سبک



<h2 id="نحوه-اضافه-کردن-نرمافزار-جدید" class="heading-with-back">
  <span>نحوه اضافه کردن نرم‌افزار جدید</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### ۱. ایجاد اسکریپت نصب

```bash
# docker/app/install/tools/mytool.sh
#!/bin/bash
source "$(dirname "$0")/../common.sh"
log "Installing MyTool"
set -e
apt install -y --no-install-recommends mytool
echo "MyTool installed successfully."
mytool --version
```

### ۲. اضافه کردن به Dockerfile

```dockerfile
COPY install/tools/mytool.sh /tmp/install/mytool.sh
RUN chmod +x /tmp/install/mytool.sh && /tmp/install/mytool.sh
```


<h2 id="نحوه-تغییر-ورژن-ابزارها" class="heading-with-back">
  <span>نحوه تغییر ورژن ابزارها</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

فایل `docker/app/.env` را ویرایش کنید:

```bash
PHP_VERSION=8.4
NODE_VERSION=22
PYTHON_VERSION=3.12
```

سپس ایمیج را مجدداً بسازید:

```powershell
.\scripts\build
```


<h2 id="تست-و-اعتبارسنجی" class="heading-with-back">
  <span>تست و اعتبارسنجی</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### تست ابزارها

```bash
docker run --rm devbox-lite bash -c "
  php --version
  node --version
  python3 --version
  composer --version
"
```

### تست کل ایمیج

```bash
docker build -t devbox-lite:test ./docker/app
docker run --rm devbox-lite:test bash -c "
  php --version
  node --version
  python3 --version
"
```


<h2 id="سبک-کدنویسی" class="heading-with-back">
  <span>سبک کدنویسی</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### اسکریپت‌های شل

- از `set -e` برای توقف در صورت خطا استفاده کنید
- از `common.sh` برای توابع مشترک استفاده کنید
- مراحل مهم را با `log` لاگ کنید

### اسکریپت‌های PowerShell

- از `common.ps1` برای توابع مشترک استفاده کنید
- خطاها را با `Test-Result` مدیریت کنید

### تنظیمات pnpm 11

‏DevBox از pnpm 11 با `dangerouslyAllowAllBuilds: true` در تنظیمات جهانی (`~/.config/pnpm/config.yaml`) استفاده می‌کند تا build scripts پکیج‌هایی مانند `sharp` و `unrs-resolver` بدون نیاز به تأیید دستی اجرا شوند.

‏Store پکیج‌ها از Docker volume (`pnpm-store`) استفاده می‌کند و در ریشه workspace ایجاد نمی‌شود.


<h2 id="پشتیبانی-آفلاین" class="heading-with-back">
  <span>پشتیبانی آفلاین</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### پکیج‌های آماده

پکیج‌ها را در `prebuilt/packages/` قرار دهید:
- `bruno_3.5.2_amd64_linux.deb`

اسکریپت‌های نصب ابتدا پکیج‌های آماده را بررسی می‌کنند و در صورت پیدا نشدن از اینترنت دانلود می‌کنند.

### ایمیج‌های Docker آماده

ایمیج‌های خروجی‌گرفته‌شده را در `prebuilt/images/` قرار دهید:
- `mysql-8.4.tar`
- `postgres-17.tar`
- `redis-7.tar`
- ‎و غیره


<h2 id="عملکرد-wsl2" class="heading-with-back">
  <span>عملکرد WSL2</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

برای عملکرد بهتر توسعه، DevBox را داخل WSL2 اجرا کنید به جای استفاده از bind mount Docker Desktop.

### چرا WSL2؟

- ‏Docker Desktop bind mount: عملیات فایل از پل Windows → WSL2 عبور می‌کند (کند)
- ‏WSL2 native: فایل‌ها روی فایل‌سیستم لینوکس ذخیره می‌شوند (10-20 برابر سریع‌تر)

### پیش‌نیازها

1. ‏WSL2 نصب باشد: `wsl --install` (PowerShell به عنوان Administrator)
2. ‏Docker در WSL2 در دسترس باشد (یکی از روش‌ها):
   - ‏WSL Integration در Docker Desktop فعال باشد، یا
   - ‏Docker به صورت بومی نصب باشد: `sudo apt install docker.io docker-compose-v2`

### راه‌اندازی کامل

**مرحله ۱:** ترمینال Ubuntu را باز کنید (از منوی Start یا تایپ `wsl` در PowerShell)

**مرحله ۲:** نصب Docker (اگر از WSL Integration استفاده نمی‌کنید)

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
wsl --shutdown
```

سپس Ubuntu را مجدداً باز کنید.

**مرحله ۳:** کلون و تنظیم

```bash
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/efmojtaba1/DevBox.git && cd DevBox
echo "WORKSPACE_PATH=$PWD" > .env
```

**مرحله ۴:** ساخت و اجرا

```bash
chmod +x scripts/*.sh
./scripts/build.sh
./scripts/up.sh
./scripts/shell.sh
```

### بهینه‌سازی منابع WSL2

فایل `%USERPROFILE%\.wslconfig` را ایجاد یا ویرایش کنید:

```ini
[wsl2]
memory=8GB
processors=4
swap=4GB
```

سپس WSL را ری‌استارت کنید: `wsl --shutdown`

### مقایسه عملکرد

| عملیات | Docker Desktop | WSL2 Native |
|--------|---------------|-------------|
| pnpm install | ~7 دقیقه | ~30 ثانیه |
| Next.js build | ~10+ دقیقه | ~30 ثانیه |
| شروع Next.js dev | ~5 دقیقه | ~5 ثانیه |



<h2 id="مستندات" class="heading-with-back">
  <span>مستندات</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
