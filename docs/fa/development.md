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
│   └── packages/         # پکیج‌های Bruno و Postman
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
- **tools:** Database clients, GitHub CLI, Docker CLI, Nginx, Supervisor, PM2, Bruno, Postman
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

---

## پشتیبانی آفلاین

### پکیج‌های آماده

پکیج‌ها را در `prebuilt/packages/` قرار دهید:
- `bruno_3.5.2_amd64_linux.deb`
- `postman-linux-x64.tar.gz`

اسکریپت‌های نصب ابتدا پکیج‌های آماده را بررسی می‌کنند و در صورت پیدا نشدن از اینترنت دانلود می‌کنند.

### ایمیج‌های Docker آماده

ایمیج‌های خروجی‌گرفته‌شده را در `prebuilt/images/` قرار دهید:
- `mysql-8.4.tar`
- `postgres-17.tar`
- `redis-7.tar`
- و غیره

---

## مستندات

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
