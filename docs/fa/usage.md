# راهنمای استفاده روزمره

**[English](../en/usage.md)** | [بازگشت به خانه](../../README.md)

---

## راه‌اندازی اولیه

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

---

## گردش کار روزمره

1. ‏Docker Desktop را باز کنید
2. ‏کانتینر را بالا بیاورید.
3. ‏VS Code را باز کنید → Remote Explorer → Dev Containers
4. داخل پوشه `workspace/` کار کنید

---

## اسکریپت‌های مدیریت

پوشه `vscode.` در ریشه پروژه حاوی فایل تنظیمات و اسکریپتی است که دستورات کانتینر را در ترمینال یکپارچه VS Code ساده‌سازی می‌کند.

با استفاده از این تنظیمات، به جای تایپ مسیرهای کاملی مانند `scripts\up\.`، توسعه‌دهندگان می‌توانند دستورات میانبری مانند `up`، `shell` و... را مستقیماً در ترمینال VS Code تایپ کنند.


| دستور | کاربرد |
|-------|--------|
| `up` | بالا آوردن کانتینر |
| `down` | توقف کانتینر |
| `down-v` | توقف کانتینر + حذف volume ها |
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

---

## ساخت پروژه

> **نکته مهم:** تمام دستورات توسعه **داخل کانتینر** اجرا می‌شوند، نه روی سیستم میزبان.

### روش سریع: `run` (دستورات تکی)

```powershell
run laravel new my-app
run pnpm create next-app my-app
run python3 -m venv my-env
```

### روش تعاملی: `shell` (ترمینال)

```powershell
shell
# حالا داخل کانتینر:
cd /workspace
```

### Laravel

```bash
cd /workspace
laravel new my-app
cd my-app
php artisan serve --host=0.0.0.0 --port=8000
```

### Next.js / React

```bash
cd /workspace
pnpm create next-app my-app
cd my-app
pnpm dev --hostname 0.0.0.0 --port=3000
```

### Python

```bash
cd /workspace
python3 -m venv my-env
source my-env/bin/activate
pip install flask
```

---

## توقف و حذف Volume ها

اگر نیاز به ریست کامل دارید (حذف تمام volume های named مثل `node_modules`، `vendor`، `bruno`):

```powershell
# ویندوز
.\scripts\down-v

# WSL2
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

```bash
# MySQL
mysql -h devbox-mysql -u root

# PostgreSQL
psql -h devbox-postgres -U postgres

# Redis
redis-cli -h devbox-redis
```

---

## مدیریت دیتابیس

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

---

## پورت‌های پیش‌فرض

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

---

## اتصال VS Code به کانتینر

1. ‏VS Code را باز کنید
2. ‏Remote Explorer → Dev Containers را انتخاب کنید
3. روی **"+"** کلیک کنید و مسیر پروژه را انتخاب کنید
4. ‏VS Code به صورت خودکار کانتینر را شناسایی و متصل می‌شود

---

## تست API

### Bruno

```powershell
# از پاورشل
test-api bruno

# داخل کانتینر
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
