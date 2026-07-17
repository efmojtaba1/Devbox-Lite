# DevBox Lite

**[English](../en/README.md)** | [بازگشت به خانه](../../README.md)

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

> **چرا WSL2؟** Docker Desktop bind mount حدود 10-20 برابر کندتر از فایل‌سیستم بومی WSL2 است. برای توسعه جدی، WSL2 به شدت توصیه می‌شود.

#### مرحله ۱: نصب WSL2

‏**PowerShell را به عنوان Administrator** باز کنید و اجرا کنید:

```powershell
wsl --install
```

پس از نصب، کامپیوتر را ری‌استارت کنید.

#### مرحله ۲: نصب Ubuntu

پس از ری‌استارت، Ubuntu به صورت خودکار باز می‌شود. نام کاربری و رمز عبور بسازید.

اگر Ubuntu باز نشد:
```powershell
wsl --install -d Ubuntu
```

#### نحوه باز کردن ترمینال Ubuntu

روش‌های باز کردن ترمینال Ubuntu:

| روش | نحوه انجام |
|-----|------------|
| ‎**Start منوی** | را جستجو کنید و روی آیکون کلیک کنید "Ubuntu" |
| **PowerShell** |`wsl` یا `wsl -d Ubuntu`  تایپ کنید |
| **Win + R** | بزنید Enter و `wsl` تایپ کنید |
| **Windows Terminal** |را انتخاب کنید "Ubuntu" روی فلش کشویی کلیک کنید و|
| **VS Code** | Ctrl+Shift+P → "WSL: Connect to WSL" |

**توصیه:** Ubuntu را به taskbar پین کنید برای دسترسی سریع.

#### مرحله ۳: نصب Docker در Ubuntu

ترمینال Ubuntu را باز کنید:
```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2 && sudo usermod -aG docker $USER && newgrp docker
```

#### مرحله ۴: اجرای Docker Desktop

‏**Docker Desktop** را در ویندوز باز کنید. به **Settings → Resources → WSL Integration** بروید و توزیع Ubuntu خود را فعال کنید.

#### مرحله ۵: کلون کردن DevBox

در ترمینال Ubuntu:
```bash
mkdir -p ~/projects && cd ~/projects && git clone git@github.com:efmojtaba1/DevBox.git && cd DevBox
```

#### مرحله ۶: تنظیم و ساخت

```bash
echo "WORKSPACE_PATH=$PWD" > .env && chmod +x scripts/*.sh && ./scripts/build.sh
```

#### مرحله ۷: اجرای DevBox

```bash
./scripts/up.sh && ./scripts/shell.sh
```

اکنون داخل کانتینر DevBox هستید با تمام ابزارهای آماده.

#### مرحله ۸: تنظیم دستورات کوتاه (اختیاری)

برای استفاده از دستورات کوتاه مثل `up`، `down`، `shell`:
```bash
chmod +x scripts/*.sh && ./scripts/setup-aliases.sh && source ~/.bashrc
```

حالا می‌توانید از این دستورات استفاده کنید:
```bash
up          # بالا آوردن کانتینر
down        # توقف کانتینر
shell       # ورود به کانتینر
build       # ساخت ایمیج
rebuild     # ساخت مجدد ایمیج
logs        # مشاهده لاگ‌ها
status      # بررسی وضعیت
setup-deps  # راه‌اندازی دیتابیس
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

**نکته مهم:** تمام دستورات توسعه (python, pnpm, composer, php و...) **داخل کانتینر** اجرا میشن، نه روی سیستم عامل میزبان. از `run` برای دستورات تکی یا `shell` برای ترمینال تعاملی استفاده کنید.

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
```
```powershell
python3 -m venv my-env
```
```powershell
source my-env/bin/activate
```
```powershell
pip install flask
```

### Laravel

```bash
cd /workspace
```
```bash
laravel new my-app
```
```bash
cd my-app
```
```bash
composer install
```
```bash
npm install
```
```bash
php artisan serve --host=0.0.0.0 --port=8000
```

### Next.js / React

```bash
cd /workspace
```
```bash
pnpm create next-app my-app
```
```bash
cd my-app
```
```bash
pnpm install
```
```bash
pnpm dev --hostname 0.0.0.0 --port=3000
```

### Python

```bash
cd /workspace
```
```bash
python3 -m venv my-env
```
```bash
source my-env/bin/activate
```
```bash
pip install flask
```


## مستندات

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع داکر](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
