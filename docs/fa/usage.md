<div class="doc-nav-header">
  <h1>راهنمای استفاده روزمره</h1>
  <span class="lang-links">
    <strong><a href="../en/usage.md">English</a></strong> | <a href="README.md">بازگشت به خانه</a>
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
<li>
<details><summary><a href="#راهاندازی-اولیه">راه‌اندازی اولیه</a></summary>
<ul>
<li><a href="#ویندوز">ویندوز</a></li>
<li><a href="#wsl2-توصیه-شده">WSL2 (توصیه شده)</a></li>
</ul>
</details>
</li>
<li><a href="#گردش-کار-روزمره">گردش کار روزمره</a></li>
<li><a href="#اسکریپتهای-مدیریت">اسکریپت‌های مدیریت</a></li>
<li>
<details><summary><a href="#ساخت-پروژه">ساخت پروژه</a></summary>
<ul>
<li><a href="#روش-پیشنهادی-new-project-تعاملی-آفلاین">روش پیشنهادی: <code>new-project</code> (تعاملی، آفلاین)</a></li>
<li><a href="#راهاندازی-template-های-نمونه">راه‌اندازی template های نمونه</a></li>
<li><a href="#بروزرسانی-template-ها">بروزرسانی template ها</a></li>
<li><a href="#ساخت-دستی-پروژه">ساخت دستی پروژه</a></li>
<li><a href="#اجرای-پروژهها">اجرای پروژه‌ها</a></li>
</ul>
</details>
</li>
<li><a href="#توقف-و-حذف-volume-ها">توقف و حذف Volume ها</a></li>
<li>
<details><summary><a href="#راهاندازی-خودکار-دیتابیسها">راه‌اندازی خودکار دیتابیس‌ها</a></summary>
<ul>
<li><a href="#چه-چیزی-شناسایی-میشود">چه چیزی شناسایی می‌شود</a></li>
<li><a href="#اطلاعات-اتصال-از-داخل-کانتینر">اطلاعات اتصال (از داخل کانتینر)</a></li>
<li><a href="#تنظیمات-env-لاراول">تنظیمات <code>.env</code> لاراول</a></li>
<li><a href="#لاراول-با-reactvite-starter-kits">لاراول با React/Vite (Starter Kits)</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#مدیریت-دیتابیس">مدیریت دیتابیس</a></summary>
<ul>
<li><a href="#ایجاد-دیتابیس">ایجاد دیتابیس</a></li>
<li><a href="#مدیریت-کانتینرها">مدیریت کانتینرها</a></li>
<li><a href="#ابزارهای-گرافیکی">ابزارهای گرافیکی</a></li>
</ul>
</details>
</li>
<li><a href="#پورتهای-پیشفرض">پورت‌های پیش‌فرض</a></li>
<li><a href="#اتصال-vs-code-به-کانتینر">اتصال VS Code به کانتینر</a></li>
<li>
<details><summary><a href="#تست-api">تست API</a></summary>
<ul>
<li><a href="#bruno">Bruno</a></li>
<li><a href="#استفاده-آفلاین">استفاده آفلاین</a></li>
</ul>
</details>
</li>
<li><a href="#ورژن-ابزارها">ورژن ابزارها</a></li>
<li><a href="#نکات-مهم">نکات مهم</a></li>
<li><a href="#مستندات-مرتبط">مستندات مرتبط</a></li>
</ul>


<h2 id="راهاندازی-اولیه" class="heading-with-back">
  <span>راه‌اندازی اولیه</span>
</h2>

### ‎ویندوز :

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
cd D:\DevBox
.\scripts\build
.\scripts\up
```

### WSL2 : (توصیه شده)

```bash
cd ~/projects/DevBox
echo "WORKSPACE_PATH=$PWD" > .env
./scripts/build.sh
./scripts/up.sh
./scripts/shell.sh
```



<h2 id="گردش-کار-روزمره" class="heading-with-back">
  <span>گردش کار روزمره</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

1. ‏Docker Desktop را باز کنید
2. ‏کانتینر را بالا بیاورید.
3. ‏VS Code را باز کنید → Remote Explorer → Dev Containers
4. داخل پوشه `workspace/` کار کنید



<h2 id="اسکریپتهای-مدیریت" class="heading-with-back">
  <span>اسکریپت‌های مدیریت</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

پوشه `vscode.` در ریشه پروژه حاوی فایل تنظیمات و اسکریپتی است که دستورات کانتینر را در ترمینال یکپارچه VS Code ساده‌سازی می‌کند.

با استفاده از این تنظیمات، به جای تایپ مسیرهای کاملی مانند `scripts\up\.`، توسعه‌دهندگان می‌توانند دستورات میانبری مانند `up`، `shell` و... را مستقیماً در ترمینال VS Code تایپ کنند.


| دستور | کاربرد |
|-------|--------|
| `up` | بالا آوردن کانتینر |
| `down` | توقف کانتینر |
| `down-v` | توقف کانتینر + حذف ولوم ها |
| `shell` | ورود به ترمینال کانتینر |
| `logs` | مشاهده لاگ‌ها |
| `restart` | ری‌استارت کانتینر |
| `status` | بررسی وضعیت |
| `build` | ساخت ایمیج |
| `rebuild` | ساخت مجدد ایمیج |
| `clean` | پاک کردن ایمیج و کانتینر |
| `setup-deps` | راه‌اندازی خودکار دیتابیس و ابزارها |
| `test-api` | (Bruno) API ابزار تست |
| `run` | اجرای دستور دلخواه داخل کانتینر |
| `scan` | workspace شناسایی نوع پروژه‌ها در  |
| `new-project` | ایجاد پروژه جدید (آفلاین، تعاملی) |
| `setup-example` | نصب dependency در template های نمونه |
| `refresh-example` | بروزرسانی نمونه‌ها با ورژن‌های جدید |



<h2 id="ساخت-پروژه" class="heading-with-back">
  <span>ساخت پروژه</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

> **نکته مهم:** تمام دستورات توسعه **داخل کانتینر** اجرا می‌شوند، نه روی سیستم میزبان.

### روش پیشنهادی: `new-project` (تعاملی، آفلاین)

دستور `new-project` پروژه‌ها را به صورت تعاملی و با رویکرد آفلاین-اول می‌سازد. template های از پیش آماده شده (شامل dependency های نصب شده) از پوشه `example/` کپی می‌شوند و نیازی به اینترنت نیست.

#### از هاست (PowerShell / WSL2)

حالت تعاملی — نام پروژه، template و گزینه‌ها را می‌پرسد:

```powershell
devbox new-project
```

با آرگومان (پرسیدن نام/template را رد می‌کند):

```powershell
devbox new-project my-app laravel
```

# داخل کانتینر

حالت تعاملی:

```bash
new-project
```

با آرگومان:

```bash
new-project my-app react
```

#### template های موجود

| template | توضیحات | پورت |
|----------|---------|------|
| `laravel` | Laravel + PHP (با گزینه‌های starter kit) | 8000 |
| `next-js` | Next.js + TypeScript + Tailwind | 3000 |
| `react` | React + Vite | 5173 |
| `python` | Python + Flask/FastAPI | 5001/8000 |

## گزینه‌های Laravel :

هنگام انتخاب Laravel، گزینه‌های تعاملی زیر نمایش داده می‌شوند:
- ‏Breeze (Blade/React/Vue), Jetstream (Livewire/Inertia) , None **:Starter kit**
- **دیتابیس:** SQLite, MySQL, PostgreSQL
- **تست:** Pest, PHPUnit
- **حالت تاریک:** بله/خیر
- **مسیرهای API:** بله/خیر

## گزینه‌های React :

- ‏**TypeScript:** بله/خیر
- ‏**Tailwind CSS:** بله/خیر

#### گزینه‌های Python :

- **فریمورک:** Flask, FastAPI, Python خام

### راه‌اندازی template های نمونه

‏Template ها به صورت خودکار هنگام اجرای `up` راه‌اندازی می‌شوند (بعد از اولین build یا `down-v`). نیازی به راه‌اندازی دستی نیست.

برای بررسی صحت template ها:

از هاست:

```bash
devbox setup-example
```

داخل کانتینر:

```bash
setup-example
```

### بروزرسانی template ها

برای بروزرسانی template های نمونه با ورژن‌های جدید فریمورک‌ها:

از هاست — بروزرسانی همه:

```bash
devbox refresh-example
```

بروزرسانی یک template خاص:

```bash
devbox refresh-example laravel
```

داخل کانتینر:

```bash
refresh-example
```

### ساخت دستی پروژه

همچنین می‌توانید پروژه‌ها را به صورت دستی بسازید:

داخل کانتینر:

```bash
cd /workspace
```

**Laravel:**

```bash
laravel new my-app
cd my-app
serve
```

**Next.js:**

```bash
pnpm create next-app my-app
cd my-app
pnpm dev
```

**React:**

```bash
pnpm create vite my-app --template react
cd my-app
pnpm dev
```

**Python:**

```bash
python3 -m venv my-env
source my-env/bin/activate
pip install flask
python app.py
```

### اجرای پروژه‌ها

بعد از ایجاد پروژه، سرور dev را بالا بیاورید:

| فریمورک | دستور | آدرس |
|---------|-------|------|
| Laravel | `serve` | http://localhost:8000 |
| Next.js | `pnpm dev` | http://localhost:3000 |
| React | `pnpm dev` | http://localhost:5173 |
| Python (Flask) | `dev` | http://localhost:5001 |
| Python (FastAPI) | `dev` | http://localhost:8000 |



<h2 id="توقف-و-حذف-volume-ها" class="heading-with-back">
  <span>توقف و حذف Volume ها</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

اگر نیاز به ریست کامل دارید (حذف تمام volume های named مثل `node_modules`، `vendor`، `bruno`):

### ‎ویندوز :


```powershell
.\scripts\down-v
```

### WSL2 :

```powershell
./scripts/down-v.sh
```

> **هشدار:** این دستور تمام volume های named را حذف می‌کند شامل کالکشن‌های Bruno، pnpm store و dependency های کش شده.



<h2 id="راهاندازی-خودکار-دیتابیسها" class="heading-with-back">
  <span>راه‌اندازی خودکار دیتابیس‌ها</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

اسکریپت `setup-deps` به صورت خودکار نوع پروژه‌ها را شناسایی و دیتابیس و ابزار گرافیکی مورد نیاز را راه‌اندازی می‌کند:

```bash
# از داخل کانتینر
setup-deps /workspace
```

### چه چیزی شناسایی می‌شود

| نوع پروژه | نحوه شناسایی | دیتابیس | ابزار گرافیکی |
|----------|--------------|---------|--------------|
| Laravel | `artisan` فایل | MySQL + Redis | phpMyAdmin |
| Next.js | `next.config*` فایل | PostgreSQL | Adminer |
| React | `react` در package.json | PostgreSQL | Adminer |
| Python | `*.py` یا `requirements.txt` | PostgreSQL | Adminer |
| Django | `manage.py` فایل | PostgreSQL + Redis | Adminer |
| Express | `express` در package.json | PostgreSQL + Redis | Adminer |

### اطلاعات اتصال (از داخل کانتینر)

MySQL:

```bash
mysql -h devbox-mysql -u root
```

PostgreSQL:

```bash
psql -h devbox-postgres -U postgres
```

Redis:

```bash
redis-cli -h devbox-redis
```

### تنظیمات `.env` لاراول

هنگام اجرای `setup-deps`، اسکریپت به صورت خودکار فایل `.env` لاراول شما را پیکربندی می‌کند:
- مقدار `DB_HOST=devbox-mysql` را تنظیم می‌کند
- مقدار `REDIS_HOST=devbox-redis` را تنظیم می‌کند
- مقدار `CACHE_STORE=redis` را تنظیم می‌کند (اگر Redis در دسترس باشد)
- مقدار `QUEUE_CONNECTION=redis` را تنظیم می‌کند (اگر Redis در دسترس باشد)
- مقدار `SESSION_DRIVER=redis` را تنظیم می‌کند (اگر Redis در دسترس باشد)
- در صورت خالی بودن `APP_KEY`، آن را می‌سازد

اگر نیاز به پیکربندی دستی دارید:

```env
DB_CONNECTION=mysql
DB_HOST=devbox-mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD=

REDIS_HOST=devbox-redis

CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
```

> **نکته:** داخل کانتینر، به جای `127.0.0.1` از نام‌های `devbox-mysql` و `devbox-redis` به عنوان هاست استفاده کنید.

### لاراول با React/Vite (Starter Kits)

اگر پروژه لاراول خود را با starter kit React ساخته‌اید، `setup-deps` به صورت خودکار:
- پکیج‌های فرانت‌اند را نصب می‌کند (`pnpm install`)
- سرور Vite dev را با HMR در پس‌زمینه اجرا می‌کند

سرور dev با Hot Module Replacement کار می‌کند - تغییرات فوراً اعمال می‌شوند و نیازی به بیلد مجدد نیست.



<h2 id="مدیریت-دیتابیس" class="heading-with-back">
  <span>مدیریت دیتابیس</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### ایجاد دیتابیس

| دستور | کاربرد |
|-------|--------|
| `create mysql` | MySQL ایجاد و اجرای  |
| `create postgres` | PostgreSQL ایجاد و اجرای |
| `create redis` | Redis ایجاد و اجرای |
| `create mongo` | MongoDB ایجاد و اجرای  |
| `create mariadb` | MariaDB ایجاد و اجرای  |
| `create memcached` | Memcached ایجاد و اجرای |

### مدیریت کانتینرها

| دستور | کاربرد |
|-------|--------|
| `start mysql` | روشن کردن کانتینر |
| `stop mysql` | توقف کانتینر |
| `connect mysql` | اتصال به ترمینال دیتابیس |

### ابزارهای گرافیکی

| دستور | آدرس | کاربرد |
|-------|------|--------|
| `phpmyadmin` | http://localhost:8081 | مدیریت MySQL/MariaDB |
| `adminer` | http://localhost:8082 | مدیریت چند دیتابیس |
| `pgadmin` | http://localhost:8083 | مدیریت PostgreSQL |



<h2 id="پورتهای-پیشفرض" class="heading-with-back">
  <span>پورت‌های پیش‌فرض</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

| سرویس | پورت | نام کانتینر |
|-------|------|-------------|
| MySQL | 3307 | devbox-mysql |
| PostgreSQL | 5433 | devbox-postgres |
| Redis | 6380 | devbox-redis |
| MongoDB | 27017 | devbox-mongo |
| MariaDB | 3308 | devbox-mariadb |
| phpMyAdmin | 8081 | - |
| Adminer | 8082 | - |
| pgAdmin | 8083 | - |



<h2 id="اتصال-vs-code-به-کانتینر" class="heading-with-back">
  <span>اتصال VS Code به کانتینر</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

1. ‏VS Code را باز کنید
2. ‏Remote Explorer → Dev Containers را انتخاب کنید
3. روی **"+"** کلیک کنید و مسیر پروژه را انتخاب کنید
4. ‏VS Code به صورت خودکار کانتینر را شناسایی و متصل می‌شود



<h2 id="تست-api" class="heading-with-back">
  <span>تست API</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

### Bruno

از پاورشل:

```powershell
test-api bruno
```

داخل کانتینر:

```powershell
bruno
```

آدرس: http://localhost:6080

### استفاده آفلاین

1. کالکشن‌ها را در Bruno بسازید
2. کالکشن‌ها در `workspace/data/bruno/collections/` ذخیره می‌شوند
3. کالکشن‌ها بدون اینترنت کار می‌کنند



<h2 id="ورژن-ابزارها" class="heading-with-back">
  <span>ورژن ابزارها</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

ورژن ابزارها از فایل `docker/app/.env` کنترل می‌شود:

```bash
PHP_VERSION=8.4
NODE_VERSION=22
PYTHON_VERSION=3.12
```

برای تغییر ورژن، مقدار مربوطه را تغییر دهید و سپس ایمیج را مجدداً بسازید:

```powershell
.\scripts\build
```



<h2 id="نکات-مهم" class="heading-with-back">
  <span>نکات مهم</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

1. پروژه‌ها را در پوشه `workspace/` قرار دهید
2. از VS Code Dev Containers استفاده کنید
3. به‌طور منظم از پروژه پشتیبان بگیرید
4. اگر مشکلی داشتید، به [عیب‌یابی](troubleshooting.md) مراجعه کنید



<h2 id="مستندات-مرتبط" class="heading-with-back">
  <span>مستندات مرتبط</span>
  <a href="#فهرست-مطالب" title="بازگشت به فهرست مطالب" class="back-to-toc">🔝</a>
</h2>

| مستند | توضیحات |
|-------|---------|
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
