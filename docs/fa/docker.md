<div class="doc-nav-header">
  <h1>مرجع دستورات Docker</h1>
  <span class="lang-links">
    <strong><a href="../en/docker.md">English</a></strong> | <a href="README.md">بازگشت به خانه</a>
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
<li><a href="#مفاهیم-پایه">مفاهیم پایه</a></li>
<li>
<details><summary><a href="#مدیریت-کانتینر">مدیریت کانتینر</a></summary>
<ul>
<li><a href="#بالا-آوردن-کانتینر">بالا آوردن کانتینر</a></li>
<li><a href="#توقف-کانتینر">توقف کانتینر</a></li>
<li><a href="#توقف-و-حذف-volume-ها">توقف و حذف Volume ها</a></li>
<li><a href="#ورود-به-ترمینال">ورود به ترمینال</a></li>
<li><a href="#مشاهده-لاگها">مشاهده لاگ‌ها</a></li>
<li><a href="#ریاستارت">ری‌استارت</a></li>
<li><a href="#بررسی-وضعیت">بررسی وضعیت</a></li>
<li><a href="#اجرای-دستور-داخل-کانتینر">اجرای دستور داخل کانتینر</a></li>
<li><a href="#شناسایی-پروژهها">شناسایی پروژه‌ها</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#دستورات-image">دستورات Image</a></summary>
<ul>
<li><a href="#ساخت-ایمیج">ساخت ایمیج</a></li>
<li><a href="#ساخت-مجدد-بدون-کش">ساخت مجدد (بدون کش)</a></li>
<li><a href="#مشاهده-ایمیجها">مشاهده ایمیج‌ها</a></li>
<li><a href="#حذف-ایمیج">حذف ایمیج</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#دستورات-پاکسازی">دستورات پاک‌سازی</a></summary>
<ul>
<li><a href="#پاک-کردن-کامل">پاک کردن کامل</a></li>
<li><a href="#پاک-کردن-کش">پاک کردن کش</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#تست-api">تست API</a></summary>
<ul>
<li><a href="#bruno">Bruno</a></li>
<li><a href="#استفاده-آفلاین">استفاده آفلاین</a></li>
<li><a href="#volume-های-bruno">Volume های Bruno</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#عیبیابی">عیب‌یابی</a></summary>
<ul>
<li><a href="#کانتینر-بالا-نمیآید">کانتینر بالا نمی‌آید</a></li>
<li><a href="#پورت-در-حال-استفاده-است">پورت در حال استفاده است</a></li>
<li><a href="#مشکل-دسترسی">مشکل دسترسی</a></li>
</ul>
</details>
</li>
<li><a href="#نکات-مهم">نکات مهم</a></li>
<li><a href="#مستندات-مرتبط">مستندات مرتبط</a></li>
</ul>

<h2 id="مفاهیم-پایه" class="heading-with-back">
  <span>مفاهیم پایه</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

- **Image:** قالب سیستم‌عامل و ابزارهای نصب‌شده
- **Container:** نمونه اجرا شده از ایمیج
- **Volume:** ذخیره دائمی داده‌ها
- **Network:** ارتباط بین کانتینرها (devbox-network)

<h2 id="مدیریت-کانتینر" class="heading-with-back">
  <span>مدیریت کانتینر</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### بالا آوردن کانتینر

‎**ویندوز:**
```powershell
.\scripts\up
```

**WSL2:**
```bash
./scripts/up
```

یا مستقیماً:
```bash
cd docker/compose
docker compose up -d
```

### توقف کانتینر

‎**ویندوز:**
```powershell
.\scripts\down
```

**WSL2:**
```bash
./scripts/down
```

### توقف و حذف Volume ها

‎**ویندوز:**
```powershell
.\scripts\down-v
```

**WSL2:**
```bash
./scripts/down-v.sh
```

> **هشدار:** این دستور تمام volume های named را حذف می‌کند شامل کالکشن‌های Bruno، pnpm store و dependency های کش شده.

### ورود به ترمینال

‎**ویندوز:**
```powershell
.\scripts\shell
```

**WSL2:**
```bash
./scripts/shell
```

## مشاهده لاگ‌ها
‎**ویندوز:**
```powershell
.\scripts\logs
```

**WSL2:**
```bash
./scripts/logs
```

### ری‌استارت

‎**ویندوز:**
```powershell
.\scripts\restart
```

**WSL2:**
```bash
./scripts/restart
```

### بررسی وضعیت

‎**ویندوز:**
```powershell
.\scripts\status
```

**WSL2:**
```bash
./scripts/status
```

### اجرای دستور داخل کانتینر

```powershell
run <command>
```

مثال:
```powershell
run pnpm create next-app my-app
run php artisan serve
```

### شناسایی پروژه‌ها

```powershell
scan
```



<h2 id="دستورات-image" class="heading-with-back">
  <span>دستورات Image</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### ساخت ایمیج

‎**ویندوز:**
```powershell
.\scripts\build
```

**WSL2:**
```bash
./scripts/build
```

### ساخت مجدد (بدون کش)

‎**ویندوز:**
```powershell
.\scripts\rebuild
```

**WSL2:**
```bash
./scripts/rebuild
```

### مشاهده ایمیج‌ها

```bash
docker images
```

### حذف ایمیج

```bash
docker rmi devbox-lite
```

---

<h2 id="دستورات-پاکسازی" class="heading-with-back">
  <span>دستورات پاک‌سازی</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### پاک کردن کامل

‎**ویندوز:**
```powershell
.\scripts\clean
```

**WSL2:**
```bash
./scripts/clean
```

### پاک کردن کش

```bash
docker builder prune
docker system prune -a
```

---

<h2 id="تست-api" class="heading-with-back">
  <span>تست API</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### Bruno

```powershell
test-api bruno
```

آدرس: http://localhost:6080

### استفاده آفلاین

1. کالکشن‌ها را در Bruno بسازید → خروجی JSON بگیرید
2. کالکشن‌ها در `workspace/data/bruno/collections/` ذخیره می‌شوند
3. کالکشن‌ها بدون اینترنت کار می‌کنند

### Volume های Bruno

Bruno از volume های named Docker برای ذخیره‌سازی استفاده می‌کند:
- `bruno-config` → `/root/.config/bruno` (تنظیمات Electron)
- `bruno-collections` → `/root/bruno` (کالکشن‌های API)

برای پشتیبان‌گیری از داده‌های Bruno:
```bash
docker run --rm -v devbox_bruno-collections:/data:ro alpine tar czf /backup/bruno-collections.tar.gz -C /data .
```

---

<h2 id="عیبیابی" class="heading-with-back">
  <span>عیب‌یابی</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### کانتینر بالا نمی‌آید

```powershell
.\scripts\logs
```

یا:
```powershell
cd docker/compose
docker compose logs devbox-lite
```

### پورت در حال استفاده است

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

### مشکل دسترسی

```powershell
docker compose exec devbox-lite chmod -R 777 /workspace
```

---

<h2 id="نکات-مهم" class="heading-with-back">
  <span>نکات مهم</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

1. همیشه از اسکریپت‌های مدیریت استفاده کنید
2. قبل از حذف ایمیج، کانتینر را متوقف کنید
3. از `docker system prune` با احتیاط استفاده کنید
4. لاگ‌ها را برای عیب‌یابی بررسی کنید

---

<h2 id="مستندات-مرتبط" class="heading-with-back">
  <span>مستندات مرتبط</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
