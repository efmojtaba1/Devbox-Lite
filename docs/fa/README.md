# DevBox Lite

**[فارسی](README.md)** | **[English](../en/README.md)** | [بازگشت به خانه](../../README.md)

محیط توسعه سبک و ایزوله بر پایه Docker + Ubuntu 24.04، مخصوص پروژه‌های **Laravel، Next.js، React و Python**.

---

## ویژگی‌ها
- **سبک و سریع:** حجم ایمیج تقریبا 1 گیگابایت.
- **پشتیبانی آفلاین:** مدیریت دیتابیس با پشتیبانی از ایمیج‌های آفلاین
- **ابزارهای کامل:** PHP, Node.js, Python, Composer, Laravel, Xdebug, Pest
- **مدیریت دیتابیس:** MySQL, PostgreSQL, Redis + ابزارهای گرافیکی (phpMyAdmin, Adminer, pgAdmin)
- **ابزارهای API Testing:** Bruno (کاملاً آفلاین)

---

## ابزارهای موجود

| دسته | ابزارها |
|------|---------|
| **PHP** | PHP 8.4 + Composer + Laravel Installer + Xdebug + Pest |
| **Node.js** | Node.js 22 + pnpm + npm + Bun |
| **Python** | Python 3.12 + pip + pipx + Jupyter + poetry + black + ruff + pytest |
| **Database** | MySQL Client + PostgreSQL Client + Redis CLI |
| **Server** | Nginx + Supervisor + PM2 |
| **Tools** | Docker CLI + GitHub CLI + Git |
| **API Testing** | Bruno (via VNC) |

---

## شروع سریع

### پیش‌نیازها

- ‏[Docker Desktop](https://www.docker.com/products/docker-desktop/) نصب و اجرا شده باشد
- ‏[VS Code](https://code.visualstudio.com/) با افزونه [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### مراحل راه‌اندازی (ویندوز)

1. کلون کردن پروژه:

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
```
```powershell
cd D:\DevBox
```
2. ساخت ایمیج:

```powershell
.\scripts\build
```

3. بالا آوردن کانتینر:

```powershell
.\scripts\up
```

4. اتصال VS Code به کانتینر از طریق Remote Explorer → Dev Containers

### مراحل راه‌اندازی (WSL2 - توصیه شده برای سرعت بهتر)

1. کلون کردن داخل WSL2:

```bash
git clone https://github.com/efmojtaba1/DevBox.git ~/projects/DevBox
cd ~/projects/DevBox
```

2. تنظیم مسیر workspace:

```bash
echo "WORKSPACE_PATH=$PWD" > .env
```

3. ساخت و اجرا:

```bash
./scripts/build
./scripts/up
./scripts/shell
```

---

## اسکریپت‌های مدیریت

دستورات زیر را می‌توانید مستقیماً در ترمینال VS Code تایپ کنید:

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
| `test-api` | ابزار تست API (Bruno) |
| `run` | اجرای دستور دلخواه داخل کانتینر |
| `scan` | شناسایی نوع پروژه‌ها در workspace |

### مدیریت دیتابیس (دستورات کوتاه در ترمینال VS Code)

| دستور | کاربرد |
|-------|--------|
| `create mysql` | ایجاد و اجرای MySQL |
| `create postgres` | ایجاد و اجرای PostgreSQL |
| `create redis` | ایجاد و اجرای Redis |
| `start mysql` | روشن کردن کانتینر |
| `stop mysql` | توقف کانتینر |
| `connect mysql` | اتصال به ترمینال دیتابیس |
| `phpmyadmin` | راه‌اندازی phpMyAdmin (پورت 8081) |
| `adminer` | راه‌اندازی Adminer (پورت 8082) |
| `pgadmin` | راه‌اندازی pgAdmin (پورت 8083) |

---

## ساخت پروژه جدید

> **نکته مهم:** تمام دستورات توسعه (python, pnpm, composer, php و...) **داخل کانتینر** اجرا میشن، نه روی سیستم عامل میزبان. از `run` برای دستورات تکی یا `shell` برای ترمینال تعاملی استفاده کنید.

### استفاده از `run` (دستورات تکی)

```powershell
run pnpm create next-app my-app
```
```powershell
run composer install
```
```powershell
run python3 -m venv my-env
```

### استفاده از `shell` (ترمینال تعاملی)
ابتدا با دستور زیر وارد ترمینال کانتینر بشید:
```powershell
shell
```
حالا داخل کانتینر:
```powershell
cd /workspace
python3 -m venv my-env
source my-env/bin/activate
pip install flask
```

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

## مستندات

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع داکر](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
