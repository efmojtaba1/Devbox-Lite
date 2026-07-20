# DevBox Lite

**[English](../en/README.md)** | [بازگشت به خانه](../../README.md)

سبک، ایزوله، و آماده کار — محیط توسعه‌ای مبتنی بر Docker + Ubuntu 24.04 که برای پروژه‌های **Laravel، Next.js، React و Python** طراحی شده.

---

## چرا DevBox Lite؟

- **سبک و سریع:** حجم ایمیج حدود ۱ گیگابایت
- **پشتیبانی آفلاین:** دیتابیس‌ها و ابزارها بدون نیاز به اینترنت
- **ابزارهای کامل:** PHP, Node.js, Python, Composer, Laravel, Xdebug, Pest
- **مدیریت دیتابیس:** MySQL, PostgreSQL, Redis + محیط گرافیکی (phpMyAdmin, Adminer)
- **تست API:** Bruno (کاملاً آفلاین)

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

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) نصب و اجرا شده باشد
- [VS Code](https://code.visualstudio.com/) با افزونه [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### راه‌اندازی در ویندوز

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
cd D:\DevBox
.\scripts\build
.\scripts\up
```

سپس VS Code را باز کنید و از طریق Remote Explorer → Dev Containers به کانتینر وصل شوید.

### راه‌اندازی در WSL2 (توصیه شده)

> **چرا WSL2؟** عملیات فایل در Docker Desktop حدود ۱۰-۲۰ برابر کندتر از فایل‌سیستم بومی WSL2 است. برای توسعه جدی، WSL2 به شدت توصیه می‌شود.

```bash
# ۱. نصب WSL2 (PowerShell به عنوان Administrator)
wsl --install
# ری‌استارت کامپیوتر

# ۲. نصب Docker در Ubuntu
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER && newgrp docker

# ۳. فعال‌سازی Docker Desktop
# Docker Desktop → Settings → WSL Integration → Ubuntu را فعال کنید

# ۴. کلون و راه‌اندازی
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:efmojtaba1/DevBox.git && cd DevBox
echo "WORKSPACE_PATH=$PWD" > .env
chmod +x scripts/*.sh
./scripts/build.sh && ./scripts/up.sh && ./scripts/shell.sh
```

### دستورات کوتاه (اختیاری)

```bash
./scripts/setup-aliases.sh && source ~/.bashrc
```

حالا می‌توانید از این دستورات استفاده کنید:

| دستور | کاربرد |
|-------|--------|
| `up` | بالا آوردن کانتینر |
| `down` | توقف کانتینر |
| `down-v` | توقف کانتینر + حذف volume ها |
| `shell` | ورود به ترمینال کانتینر |
| `build` | ساخت ایمیج |
| `rebuild` | ساخت مجدد ایمیج |
| `logs` | مشاهده لاگ‌ها |
| `status` | بررسی وضعیت |
| `setup-deps` | راه‌اندازی خودکار دیتابیس و ابزارها |

---

## ساختار پوشه‌بندی

```
DevBox_Lite/
├── docker/
│   ├── app/              # فایل‌های ساخت ایمیج
│   │   ├── Dockerfile
│   │   ├── .env          # ورژن ابزارها
│   │   └── install/      # اسکریپت‌های نصب
│   └── compose/          # Docker Compose + .env
├── scripts/              # اسکریپت‌های مدیریت
├── docs/                 # مستندات فارسی و انگلیسی
├── prebuilt/             # ایمیج‌های آماده برای آفلاین
│   └── images/           # mysql-8.4.tar, postgres-17.tar, ...
└── workspace/            # پوشه کاری پروژه‌ها
    ├── data/bruno/       # Bruno کالکشن‌ها و تنظیمات 
    ├── laravel/          # پروژه لاراول
    ├── next-js/          # پروژه نکست  
    └── python/           # پروژه پایتون
```

> **نکته:**  ایمیج های موجود در پوشه `prebuilt/` به صورت خودکار به کانتینر مانت می‌شوند.

---

## ساخت پروژه جدید

> **نکته مهم:** تمام دستورات توسعه (python, pnpm, composer, php و...) **داخل کانتینر** اجرا می‌شوند.

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

## راه‌اندازی خودکار دیتابیس‌ها

اسکریپت `setup-deps` به صورت خودکار نوع پروژه‌ها را شناسایی و دیتابیس و ابزار گرافیکی مورد نیاز را راه‌اندازی می‌کند:

```bash
# از داخل کانتینر
setup-deps
```

| نوع پروژه | دیتابیس | ابزار گرافیکی |
|----------|---------|--------------|
| Laravel | MySQL + Redis | phpMyAdmin |
| Next.js / React | PostgreSQL | Adminer |
| Python | PostgreSQL | Adminer |

---

## مستندات

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |

---

## لایسنس

این پروژه تحت لایسنس [LICENSE](../../LICENSE) است.

---

**ورژن فعلی:** lite-1.0.0
