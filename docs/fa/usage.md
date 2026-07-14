# راهنمای استفاده روزمره (DevBox Lite)

**[فارسی](usage.md)** | **[English](../en/usage.md)** | [بازگشت به خانه](../../README.md)

---

## گردش کار اصلی

1. ‏Docker Desktop را باز کنید
2. وارد ترمینال داکر  دسکتاپ بشید .
3. کانتینر را بالا بیاورید:

```powershell
.\scripts\up
```
   - اگر از محیط گرافیکی Docker Desktop استفاده میکنید :
   - با رفتن به  بخش ایمیج ها با کلیک روی علامت ▶ میتونید یک کانتینر از ایمیج دوباکس بسازید.
   - سپس به بخش کانتینر ها برید و مجدد با کلیک روی علامت ▶ کانتینر رو بالا بیارید.

4. ‏VS Code را باز کرده و از طریق Remote Explorer به کانتینر وصل شوید


---

## اسکریپت‌های مدیریت

پوشه `vscode.` در ریشه پروژه حاوی فایل تنظیمات و اسکریپتی است که دستورات کانتینر را در ترمینال یکپارچه VS Code ساده‌سازی می‌کند.

با استفاده از این تنظیمات، به جای تایپ مسیرهای کاملی مانند `scripts\up\.` توسعه‌دهندگان می‌توانند دستورات میانبری مانند `up`، `shell` و... را مستقیماً در ترمینال VS Code تایپ کنند.



| دستور | کاربرد |
|-------|--------|
| `up` | بالا آوردن کانتینر |
| `down` | توقف کانتینر |
| `shell` | ورود به ترمینال کانتینر |
| `logs` | مشاهده لاگ‌ها |
| `restart` | ری‌استارت کانتینر |
| `status` | بررسی وضعیت |
| `build` | ساخت ایمیج |
| `rebuild` | ساخت مجدد ایمیج |
| `clean` | پاک کردن ایمیج و کانتینر |
| `setup-deps` | راه‌اندازی خودکار وابستگی‌های پروژه |
| `test-api` | ابزار تست API (Bruno/Postman) |
| `run` | اجرای دستور دلخواه داخل کانتینر |
| `scan` | شناسایی نوع پروژه‌ها در workspace |

---

## ساخت پروژه جدید

### Laravel

```bash
cd /workspace
laravel new my-app
cd my-app
composer install
npm install
php artisan serve --host=0.0.0.0 --port=8000
```

### Next.js / React

```bash
cd /workspace
pnpm create next-app my-app
cd my-app
pnpm install
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

## مدیریت دیتابیس

### ایجاد دیتابیس

| دستور | کاربرد |
|-------|--------|
| `create mysql` | MySQL ایجاد و اجرای |
| `create postgres` | PostgreSQL  ایجاد و اجرای |
| `create redis` | Redis  ایجاد و اجرای |
| `create mongo` | MongoDB  ایجاد و اجرای |
| `create mariadb` | MariaDB  ایجاد و اجرای |
| `create memcached` |Memcached  ایجاد و اجرای |

### مدیریت کانتینرها

| دستور | کاربرد |
|-------|--------|
| `start mysql` | روشن کردن کانتینر |
| `stop mysql` | توقف کانتینر |
| `connect mysql` | اتصال به ترمینال دیتابیس |

### ابزارهای گرافیکی

| دستور | آدرس وب | کاربرد |
|-------|---------|--------|
| `phpmyadmin` | http://localhost:8081 |MySQL/MariaDB  مدیریت |
| `adminer` | http://localhost:8082 | مدیریت چند دیتابیس |
| `pgadmin` | http://localhost:8083 | PostgreSQL  مدیریت |

---

## اتصال VS Code به کانتینر

1. ‏VS Code را باز کنید
2. ‏Remote Explorer → Dev Containers را انتخاب کنید
3. روی **"+"** کلیک کنید و مسیر پروژه را انتخاب کنید
4. ‏VS Code به صورت خودکار کانتینر را شناسایی و متصل می‌شود

---

## پورت‌های پیش‌فرض

| دیتابیس | پورت | نام کانتینر |
|---------|------|-------------|
| MySQL | 3307 | devbox-mysql |
| PostgreSQL | 5433 | devbox-postgres |
| Redis | 6380 | devbox-redis |
| MongoDB | 27017 | devbox-mongo |
| MariaDB | 3308 | devbox-mariadb |
| phpMyAdmin | 8081 | - |
| Adminer | 8082 | - |
| pgAdmin | 8083 | - |

---

## اتصال از داخل کانتینر

```bash
# PostgreSQL
psql -h devbox-postgres -p 5432

# MySQL
mysql -h devbox-mysql -P 3306

# Redis
redis-cli -h devbox-redis -p 6379
```

---

## تست API

### Bruno (سبک و سریع)

```powershell
# از پاورشل
test-api bruno

# داخل کانتینر
bruno
```

آدرس: http://localhost:6081

### Postman (امکانات پیشرفته)

```powershell
# از پاورشل
test-api postman

# داخل کانتینر
postman
```

آدرس: http://localhost:6080

### استفاده آفلاین

1. در سیستم آنلاین: کالکشن‌ها را در Postman/Bruno بسازید → خروجی JSON بگیرید
2. فایل‌های JSON را در `workspace/postman-collections/` کپی کنید
3. در سیستم آفلاین: کالکشن‌ها بدون اینترنت کار می‌کنند

---

## انتخاب ورژن ابزارها

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
