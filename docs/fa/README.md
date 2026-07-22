# DevBox Lite

سبک، ایزوله، و آماده کار — محیط توسعه‌ای مبتنی بر **Docker + Ubuntu 24.04** که برای پروژه‌های **Laravel، Next.js، React و Python** طراحی شده.

**[English](../en/README.md) | [بازگشت به خانه](../../README.md)**

---

## فهرست مطالب

* [چرا DevBox Lite؟](#چرا-devbox-lite)
* [ابزارهای موجود](#ابزارهای-موجود)
* [شروع سریع](#شروع-سریع)
  * [پیش‌نیازها](#پیشنیازها)
  * [راه‌اندازی در ویندوز](#راهاندازی-در-ویندوز)
  * [راه‌اندازی در WSL2](#راهاندازی-در-wsl2-توصیه-شده)
  * [دستورات کوتاه](#دستورات-کوتاه-اختیاری)
* [ساختار پوشه‌بندی](#ساختار-پوشهبندی)
* [ساخت پروژه جدید](#ساخت-پروژه-جدید)
  * [روش پیشنهادی: `new-project`](#روش-پیشنهادی-new-project-تعاملی-آفلاین)
  * [Templateهای موجود](#template-های-موجود)
  * [روش دستی: `shell`](#روش-دستی-shell-ترمینال)
* [راه‌اندازی خودکار دیتابیس‌ها](#راهاندازی-خودکار-دیتابیسها)
* [مستندات](#مستندات)
* [لایسنس](#لایسنس)

---

## چرا DevBox Lite؟

- **سبک و سریع:** حجم ایمیج حدود ۱ گیگابایت
- **پشتیبانی آفلاین:** دیتابیس‌ها و ابزارها بدون اینترنت کار می‌کنند
- **ابزارهای کامل:** PHP، Node.js، Python، Composer، Laravel، Xdebug، Pest
- **مدیریت دیتابیس:** MySQL، PostgreSQL، Redis به همراه ابزارهای گرافیکی (phpMyAdmin، Adminer)
- **تست API:** Bruno (کاملاً آفلاین)

---

## ابزارهای موجود

| دسته‌بندی | ابزارها |
|----------|---------|
| **PHP** | PHP 8.4 + Composer + Laravel Installer + Xdebug + Pest |
| **Node.js** | Node.js 22 + pnpm + npm + Bun |
| **Python** | Python 3.12 + pip + pipx + Jupyter + poetry + black + ruff + pytest |
| **دیتابیس** | MySQL Client + PostgreSQL Client + Redis CLI |
| **سرور** | Nginx + Supervisor + PM2 |
| **ابزارها** | Docker CLI + GitHub CLI + Git |
| **تست API** | Bruno (از طریق VNC) |

---

## شروع سریع

### پیش‌نیازها

* [Docker Desktop](https://www.docker.com/products/docker-desktop/) نصب و اجرا شده باشد.
* [VS Code](https://code.visualstudio.com/) به همراه افزونه [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) نصب شده باشد.

### راه‌اندازی در ویندوز

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
cd D:\DevBox
.\scripts\build
.\scripts\up
```

سپس VS Code را باز کنید و از طریق **Remote Explorer → Dev Containers** به کانتینر متصل شوید.

### راه‌اندازی در WSL2 (توصیه‌شده)

> **چرا WSL2؟** عملیات فایل در Docker Desktop حدود ۱۰ تا ۲۰ برابر کندتر از فایل‌سیستم بومی WSL2 است. برای توسعه جدی، استفاده از WSL2 به‌شدت توصیه می‌شود.

#### مرحله ۱: نصب WSL2

PowerShell را به‌عنوان Administrator اجرا کنید:

```powershell
wsl --install
```

سپس کامپیوتر را ری‌استارت کنید.

#### مرحله ۲: نصب Docker در Ubuntu

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER && newgrp docker
```

#### مرحله ۳: فعال‌سازی Docker Desktop

در Docker Desktop به مسیر زیر بروید:

**Settings → Resources → WSL Integration**

سپس اتصال به توزیع **Ubuntu** را فعال کنید.

#### مرحله ۴: کلون و راه‌اندازی

```bash
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:efmojtaba1/DevBox.git
cd DevBox

echo "WORKSPACE_PATH=$PWD" > .env

chmod +x scripts/*.sh

./scripts/build.sh
./scripts/up.sh
./scripts/shell.sh
```

### دستورات کوتاه (اختیاری)

برای فعال‌سازی aliasهای DevBox:

```bash
./scripts/setup-aliases.sh && source ~/.bashrc
```

پس از آن می‌توانید از دستورات زیر استفاده کنید:

| دستور             | کاربرد                                            |
| ----------------- | ------------------------------------------------- |
| `up`              | بالا آوردن کانتینر                                |
| `down`            | توقف کانتینر                                      |
| `down-v`          | توقف کانتینر و حذف Volumeها                       |
| `shell`           | ورود به ترمینال کانتینر                           |
| `build`           | ساخت ایمیج                                        |
| `rebuild`         | ساخت مجدد ایمیج                                   |
| `logs`            | مشاهده لاگ‌ها                                     |
| `status`          | بررسی وضعیت                                       |
| `new-project`     | ایجاد پروژه جدید به‌صورت تعاملی و آفلاین          |
| `setup-deps`      | راه‌اندازی خودکار دیتابیس و ابزارها               |
| `init-example`    | راه‌اندازی اولیه Templateها، یک‌بار پس از Rebuild |
| `setup-example`   | بررسی صحت Templateها                              |
| `refresh-example` | بروزرسانی Templateها به نسخه‌های جدید             |

---

## ساختار پوشه‌بندی

```text
DevBox_Lite/
├── docker/
│   ├── app/              # فایل‌های ساخت ایمیج
│   │   ├── Dockerfile
│   │   └── install/      # اسکریپت‌های نصب
│   └── compose/          # Docker Compose
├── scripts/              # اسکریپت‌های مدیریت
├── example/              # Templateهای پروژه برای استفاده آفلاین
│   ├── laravel/          # اسکلت لاراول
│   ├── next-js/          # اسکلت نکست
│   ├── python/           # اسکلت پایتون
│   └── react/            # اسکلت ری‌اکت
├── docs/                 # مستندات فارسی و انگلیسی
├── prebuilt/             # ایمیج‌های آماده برای استفاده آفلاین
│   └── images/           # mysql-8.4.tar، postgres-17.tar و ...
└── workspace/            # پروژه‌های شما در اینجا قرار می‌گیرند
```

> **نکته:** ایمیج‌های موجود در پوشه `prebuilt/` به‌صورت خودکار به کانتینر Mount می‌شوند.

---

## ساخت پروژه جدید

> **نکته مهم:** تمام دستورات توسعه **داخل کانتینر** اجرا می‌شوند.

### روش پیشنهادی: `new-project` (تعاملی، آفلاین)

از روی Host:

```powershell
.\scripts\devbox.sh new-project
```

یا از داخل کانتینر:

```bash
new-project
```

اسکریپت نام پروژه، فریم‌ورک و گزینه‌های موردنظر را مرحله‌به‌مرحله از شما دریافت می‌کند.

Templateها از پوشه `example/` کپی می‌شوند و برای ایجاد پروژه نیازی به اتصال اینترنت ندارند.

### Templateهای موجود

| Template  | گزینه‌ها                                  | پورت          |
| --------- | ----------------------------------------- | ------------- |
| `laravel` | Starter Kit، دیتابیس، تست، Dark Mode، API | `8000`        |
| `next-js` | TypeScript، Tailwind                      | `3000`        |
| `react`   | Vite + React 19                           | `5173`        |
| `python`  | Flask، FastAPI، خام                       | `5001 / 8000` |

### روش دستی: `shell` (ترمینال)

```powershell
.\scripts\shell.ps1
```

سپس داخل کانتینر:

```bash
cd /workspace

laravel new my-app
```

یا برای ایجاد پروژه‌های دیگر:

```bash
pnpm create next-app
```

---

## راه‌اندازی خودکار دیتابیس‌ها

اسکریپت `setup-deps` به‌صورت خودکار نوع پروژه‌ها را شناسایی کرده و دیتابیس و ابزار گرافیکی موردنیاز را راه‌اندازی می‌کند.

از داخل کانتینر اجرا کنید:

```bash
setup-deps
```

| نوع پروژه       | دیتابیس       | ابزار گرافیکی |
| --------------- | ------------- | ------------- |
| Laravel         | MySQL + Redis | phpMyAdmin    |
| Next.js / React | PostgreSQL    | Adminer       |
| Python          | PostgreSQL    | Adminer       |

---

## مستندات

| مستند                           | توضیحات                           |
| ------------------------------- | --------------------------------- |
| [راهنمای استفاده](usage.md)     | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docker.md)        | دستورات کامل Docker               |
| [عیب‌یابی](troubleshooting.md)  | رفع اشکال و خطاهای متداول         |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox            |

---

## لایسنس

این پروژه تحت لایسنس [LICENSE](../../LICENSE) منتشر شده است.

---

**نسخه فعلی:** `lite-1.0.0`
