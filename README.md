# DevBox Lite

محیط توسعه سبک و ایزوله بر پایه Docker + Ubuntu 24.04، مخصوص پروژه‌های **Laravel، Next.js، React و Python**.

---

## ویژگی‌ها

- **سبک و سریع:** حجم ایمیج ~2.7GB
- **پشتیبانی آفلاین:** مدیریت دیتابیس با پشتیبانی از ایمیج‌های آفلاین
- **ابزارهای کامل:** PHP, Node.js, Python, Composer, Laravel, Xdebug, Pest
- **مدیریت دیتابیس:** MySQL, PostgreSQL, Redis + ابزارهای گرافیکی (phpMyAdmin, Adminer, pgAdmin)

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

---

## شروع سریع

### پیش‌نیازها

- ‏[Docker Desktop](https://www.docker.com/products/docker-desktop/) نصب و اجرا شده باشد
- ‏[VS Code](https://code.visualstudio.com/) با افزونه [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### مراحل راه‌اندازی

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
pnpm dev --hostname 0.0.0.0 --port 3000
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
| [راهنمای استفاده](docs/usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docs/docker.md) | دستورات کامل Docker |
| [عیب‌یابی](docs/troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](docs/development.md) | توسعه و نگهداری DevBox |

---

## مجوز

این پروژه تحت مجوز [LICENSE](LICENSE) منتشر شده است.

---

**نسخه فعلی:** lite-1.0.0
