# راهنمای توسعه DevBox Lite

**[فارسی](development.md)** | **[English](../en/development.md)** | [بازگشت به خانه](../../README.md)

---

## معماری پروژه

```
DevBox Lite/
├── docker/
│   ├── app/              # فایل‌های ساخت Image
│   │   ├── Dockerfile    # فایل اصلی (multi-stage)
│   │   ├── .env          # ورژن ابزارها
│   │   ├── entrypoint.sh # اسکریپت راه‌اندازی
│   │   └── install/      # اسکریپت‌های نصب مدولار
│   └── compose/          # فایل Docker Compose (.env برای WORKSPACE_PATH)
├── scripts/              # اسکریپت‌های مدیریت
├── docs/                 # مستندات
│   ├── fa/               # مستندات فارسی
│   └── en/               # مستندات انگلیسی
├── prebuilt/             # پکیج‌های آماده برای استفاده آفلاین
│   ├── images/           # آرشیو ایمیج‌های Docker
│   └── packages/         # پکیج‌های Bruno
└── workspace/            # پوشه کاری پروژه‌ها (به /workspace در کانتینر مانت می‌شود)
    ├── data/             # داده‌های پایدار
    │   └── bruno/        # داده‌های کلاینت API برونو
    │       ├── collections/  # کالکشن‌ها و ریکوئست‌های ذخیره شده
    │       └── config/       # تنظیمات برنامه برونو
    ├── laravel/          # پروژه Laravel (مثال)
    ├── next-js/          # پروژه Next.js (مثال)
    └── python/           # پروژه Python (مثال)
```

---

## ساختار Dockerfile

```
base → languages → frameworks → tools → extensions → cleanup → runtime
```

- **base:** Ubuntu 24.04 + پکیج‌های پایه
- **languages:** PHP, Node.js, Python, Composer, Bun
- **frameworks:** Laravel Installer
- **tools:** Database clients, GitHub CLI, Docker CLI, Nginx, Supervisor, PM2, Bruno
- **extensions:** Xdebug, Pest
- **cleanup:** پاکسازی کش‌ها
- **runtime:** تصویر نهایی سبک

---

## نحوه اضافه کردن نرم‌افزار جدید

### ۱. ایجاد اسکریپت نصب

```bash
# docker/app/install/tools/mytool.sh
#!/bin/bash
source "$(dirname "$0")/../common.sh"
log "Installing MyTool"
set -e
apt install -y --no-install-recommends mytool
echo "MyTool installed successfully."
mytool --version
```

### ۲. اضافه کردن به Dockerfile

```dockerfile
COPY install/tools/mytool.sh /tmp/install/mytool.sh
RUN chmod +x /tmp/install/mytool.sh && /tmp/install/mytool.sh
```

---

## نحوه تغییر ورژن ابزارها

فایل `docker/app/.env` را ویرایش کنید:

```bash
PHP_VERSION=8.4
NODE_VERSION=22
PYTHON_VERSION=3.12
```

سپس ایمیج را مجدداً بسازید:

```powershell
.\scripts\build
```

---

## تست و اعتبارسنجی

### تست ابزارها

```bash
docker run --rm devbox-lite bash -c "
  php --version
  node --version
  python3 --version
  composer --version
"
```

### تست کل ایمیج

```bash
docker build -t devbox-lite:test ./docker/app
docker run --rm devbox-lite:test bash -c "
  php --version
  node --version
  python3 --version
"
```

---

## سبک کدنویسی

### اسکریپت‌های شل

- از `set -e` برای توقف در صورت خطا استفاده کنید
- از `common.sh` برای توابع مشترک استفاده کنید
- مراحل مهم را با `log` لاگ کنید

### اسکریپت‌های PowerShell

- از `common.ps1` برای توابع مشترک استفاده کنید
- خطاها را با `Test-Result` مدیریت کنید

### تنظیمات pnpm 11

DevBox از pnpm 11 با `dangerouslyAllowAllBuilds: true` در تنظیمات جهانی (`~/.config/pnpm/config.yaml`) استفاده می‌کند تا build scripts پکیج‌هایی مانند `sharp` و `unrs-resolver` بدون نیاز به تأیید دستی اجرا شوند.

Store پکیج‌ها از Docker volume (`pnpm-store`) استفاده می‌کند و در ریشه workspace ایجاد نمی‌شود.

---

## پشتیبانی آفلاین

### پکیج‌های آماده

پکیج‌ها را در `prebuilt/packages/` قرار دهید:
- `bruno_3.5.2_amd64_linux.deb`

اسکریپت‌های نصب ابتدا پکیج‌های آماده را بررسی می‌کنند و در صورت پیدا نشدن از اینترنت دانلود می‌کنند.

### ایمیج‌های Docker آماده

ایمیج‌های خروجی‌گرفته‌شده را در `prebuilt/images/` قرار دهید:
- `mysql-8.4.tar`
- `postgres-17.tar`
- `redis-7.tar`
- و غیره

---

## عملکرد WSL2

برای عملکرد بهتر توسعه، DevBox را داخل WSL2 اجرا کنید به جای استفاده از bind mount Docker Desktop.

### چرا WSL2؟

- Docker Desktop bind mount: عملیات فایل از پل Windows → WSL2 عبور می‌کند (کند)
- WSL2 native: فایل‌ها روی فایل‌سیستم لینوکس ذخیره می‌شوند (10-20 برابر سریع‌تر)

### پیش‌نیازها

1. WSL2 نصب باشد: `wsl --install` (PowerShell به عنوان Administrator)
2. Docker در WSL2 در دسترس باشد (یکی از روش‌ها):
   - WSL Integration در Docker Desktop فعال باشد، یا
   - Docker به صورت بومی نصب باشد: `sudo apt install docker.io docker-compose-v2`

### راه‌اندازی کامل

```bash
# ۱. ترمینال Ubuntu را باز کنید (از منوی Start یا تایپ `wsl` در PowerShell)

# ۲. نصب Docker (اگر از WSL Integration استفاده نمی‌کنید)
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
wsl --shutdown  # سپس Ubuntu را مجدداً باز کنید

# ۳. کلون و تنظیم
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/efmojtaba1/DevBox.git && cd DevBox
echo "WORKSPACE_PATH=$PWD" > .env

# ۴. ساخت و اجرا
chmod +x scripts/*.sh
./scripts/build.sh
./scripts/up.sh
./scripts/shell.sh
```

### بهینه‌سازی منابع WSL2

فایل `%USERPROFILE%\.wslconfig` را ایجاد یا ویرایش کنید:

```ini
[wsl2]
memory=8GB
processors=4
swap=4GB
```

سپس WSL را ری‌استارت کنید: `wsl --shutdown`

### مقایسه عملکرد

| عملیات | Docker Desktop | WSL2 Native |
|--------|---------------|-------------|
| pnpm install | ~7 دقیقه | ~30 ثانیه |
| Next.js build | ~10+ دقیقه | ~30 ثانیه |
| شروع Next.js dev | ~5 دقیقه | ~5 ثانیه |

---

## مستندات

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
