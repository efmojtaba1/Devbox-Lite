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
│   └── compose/          # فایل Docker Compose
├── scripts/              # اسکریپت‌های مدیریت
├── docs/                 # مستندات
│   ├── fa/               # مستندات فارسی
│   └── en/               # مستندات انگلیسی
├── prebuilt/             # پکیج‌های آماده برای استفاده آفلاین
│   ├── images/           # آرشیو ایمیج‌های Docker
│   └── packages/         # پکیج‌های Bruno
└── workspace/            # پوشه کاری پروژه‌ها
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

### راه‌اندازی

```bash
# کلون کردن داخل WSL2
git clone https://github.com/efmojtaba1/DevBox.git ~/projects/DevBox
cd ~/projects/DevBox

# تنظیم مسیر workspace
echo "WORKSPACE_PATH=$PWD" > .env

# ساخت و اجرا
./scripts/build
./scripts/up
./scripts/shell
```

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
