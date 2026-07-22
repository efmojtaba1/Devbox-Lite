# راهنمای استفاده روزمره

**[English](../en/usage.md) | [بازگشت به خانه](README.md)**

---

## فهرست مطالب

* [راه‌اندازی اولیه](#راهاندازی-اولیه)
  * [ویندوز](#ویندوز)
  * [محیط WSL2 (توصیه شده)](#wsl2-توصیه-شده)
* [گردش کار روزمره](#گردش-کار-روزمره)
* [اسکریپت‌های مدیریت](#اسکریپتهای-مدیریت)
* [ساخت پروژه](#ساخت-پروژه)
  * [روش پیشنهادی: `new-project` (تعاملی، آفلاین)](#روش-پیشنهادی-new-project-تعاملی-آفلاین)
  * [راه‌اندازی template های نمونه](#راهاندازی-template-های-نمونه)
  * [بروزرسانی template ها](#بروزرسانی-template-ها)
  * [ساخت دستی پروژه](#ساخت-دستی-پروژه)
  * [اجرای پروژه‌ها](#اجرای-پروژهها)
* [توقف و حذف Volume ها](#توقف-و-حذف-volume-ها)
* [راه‌اندازی خودکار دیتابیس‌ها](#راهاندازی-خودکار-دیتابیسها)
  * [چه چیزی شناسایی می‌شود](#چه-چیزی-شناسایی-میشود)
  * [اطلاعات اتصال (از داخل کانتینر)](#اطلاعات-اتصال-از-داخل-کانتینر)
  * [تنظیمات `.env` لاراول](#تنظیمات-env-لاراول)
  * [لاراول با React/Vite (Starter Kits)](#لاراول-با-reactvite-starter-kits)
* [مدیریت دیتابیس](#مدیریت-دیتابیس)
  * [ایجاد دیتابیس](#ایجاد-دیتابیس)
  * [مدیریت کانتینرها](#مدیریت-کانتینرها)
  * [ابزارهای گرافیکی](#ابزارهای-گرافیکی)
* [پورت‌های پیش‌فرض](#پورتهای-پیشفرض)
* [اتصال VS Code به کانتینر](#اتصال-vs-code-به-کانتینر)
* [تست API](#تست-api)
  * [نرم افزار Bruno](#bruno)
  * [استفاده آفلاین](#استفاده-آفلاین)
* [ورژن ابزارها](#ورژن-ابزارها)
* [نکات مهم](#نکات-مهم)
* [مستندات مرتبط](#مستندات-مرتبط)

---

## راه‌اندازی اولیه

### ویندوز

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
cd D:\DevBox
.\scripts\build
.\scripts\up
```

### WSL2 (توصیه شده)

```bash
cd ~/projects/DevBox
echo "WORKSPACE_PATH=$PWD" > .env
./scripts/build.sh
./scripts/up.sh
./scripts/shell.sh
```

---

## گردش کار روزمره

1. ابتدا Docker Desktop را باز کنید
2. کانتینر را بالا بیاورید.
3. سپس VS Code را باز کنید → Remote Explorer → Dev Containers
4. داخل پوشه `workspace/` کار کنید

---

## اسکریپت‌های مدیریت

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
| `scan` | workspace شناسایی نوع پروژه‌ها در |
| `new-project` | ایجاد پروژه جدید (آفلاین، تعاملی) |
| `setup-example` | نصب dependency در template های نمونه |
| `refresh-example` | بروزرسانی نمونه‌ها با ورژن‌های جدید |

---

## ساخت پروژه

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

#### داخل کانتینر

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

### گزینه‌های Laravel

هنگام انتخاب Laravel، گزینه‌های تعاملی زیر نمایش داده می‌شوند:

- **استارتر کیت:** Breeze (Blade/React/Vue), Jetstream (Livewire/Inertia), None
- **دیتابیس:** SQLite, MySQL, PostgreSQL
- **تست:** Pest, PHPUnit
- **حالت تاریک:** بله/خیر
- **مسیرهای API:** بله/خیر

### گزینه‌های React

- **تایپ اسکریپت:** بله/خیر
- **تیلویند:** بله/خیر

### گزینه‌های Python

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

---

## توقف و حذف Volume ها

اگر نیاز به ریست کامل دارید (حذف تمام volume های named مثل `node_modules`، `vendor`، `bruno`):

### ‎ویندوز

```powershell
.\scripts\down-v
```

### WSL2

```powershell
./scripts/down-v.sh
```

> **هشدار:** این دستور تمام volume های named را حذف می‌کند شامل کالکشن‌های Bruno، pnpm store و dependency های کش شده.

---

## راه‌اندازی خودکار دیتابیس‌ها

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

---

## مدیریت دیتابیس

### ایجاد دیتابیس

| دستور | کاربرد |
|-------|--------|
| `create mysql` | MySQL ایجاد و اجرای |
| `create postgres` | PostgreSQL ایجاد و اجرای |
| `create redis` | Redis ایجاد و اجرای |
| `create mongo` | MongoDB ایجاد و اجرای |
| `create mariadb` | MariaDB ایجاد و اجرای |
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

---

## پورت‌های پیش‌فرض

| سرویس      | پورت | نام کانتینر     |
|------------|------|-----------------|
| MySQL      | 3307 | devbox-mysql    |
| PostgreSQL | 5433 | devbox-postgres |
| Redis      | 6380 | devbox-redis    |
| MongoDB    | 27017| devbox-mongo    |
| MariaDB    | 3308 | devbox-mariadb  |
| phpMyAdmin | 8081 |        -        |
| Adminer    | 8082 |        -        |
| pgAdmin    | 8083 |        -        |

---

## اتصال VS Code به کانتینر

1. ادیتور VS Code را باز کنید
2. سپس Remote Explorer → Dev Containers را انتخاب کنید
3. روی **"+"** کلیک کنید و مسیر پروژه را انتخاب کنید
4. ادیتور VS Code به صورت خودکار کانتینر را شناسایی و متصل می‌شود

---

## تست API

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

---

## ورژن ابزارها

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

---

## نکات مهم

1. پروژه‌ها را در پوشه `workspace/` قرار دهید
2. از VS Code Dev Containers استفاده کنید
3. به‌طور منظم از پروژه پشتیبان بگیرید
4. اگر مشکلی داشتید، به [عیب‌یابی](troubleshooting.md) مراجعه کنید

---

## مستندات مرتبط

| مستند | توضیحات |
|-------|---------|
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
