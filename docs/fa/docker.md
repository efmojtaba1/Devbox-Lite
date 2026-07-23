# مرجع دستورات Docker

**[English](../en/docker.md) | [بازگشت به خانه](README.md)**

---

## فهرست مطالب

* [مفاهیم پایه](#مفاهیم-پایه)
* [مدیریت کانتینر](#مدیریت-کانتینر)
  * [بالا آوردن کانتینر](#بالا-آوردن-کانتینر)
  * [توقف کانتینر](#توقف-کانتینر)
  * [توقف و حذف Volume ها](#توقف-و-حذف-volume-ها)
  * [ورود به ترمینال](#ورود-به-ترمینال)
  * [مشاهده لاگ‌ها](#مشاهده-لاگها)
  * [ری‌استارت](#ریاستارت)
  * [بررسی وضعیت](#بررسی-وضعیت)
  * [اجرای دستور داخل کانتینر](#اجرای-دستور-داخل-کانتینر)
  * [شناسایی پروژه‌ها](#شناسایی-پروژهها)
* [دستورات Image](#دستورات-image)
  * [ساخت ایمیج](#ساخت-ایمیج)
  * [ساخت مجدد (بدون کش)](#ساخت-مجدد-بدون-کش)
  * [مشاهده ایمیج‌ها](#مشاهده-ایمیجها)
  * [حذف ایمیج](#حذف-ایمیج)
* [دستورات پاک‌سازی](#دستورات-پاکسازی)
  * [پاک کردن کامل](#پاک-کردن-کامل)
  * [پاک کردن کش](#پاک-کردن-کش)
* [تست API](#تست-api)
  * [ نرم افزار Bruno ](#bruno)
  * [استفاده آفلاین](#استفاده-آفلاین)
  * [ولوم های Bruno](#ولوم-های-bruno)
* [عیب‌یابی](#عیبیابی)
  * [کانتینر بالا نمی‌آید](#کانتینر-بالا-نمیآید)
  * [پورت در حال استفاده است](#پورت-در-حال-استفاده-است)
  * [مشکل دسترسی](#مشکل-دسترسی)
* [نکات مهم](#نکات-مهم)
* [مستندات مرتبط](#مستندات-مرتبط)

---

## مفاهیم پایه [🔝](#فهرست-مطالب)

- **Image:** قالب سیستم‌عامل و ابزارهای نصب‌شده
- **Container:** نمونه اجرا شده از ایمیج
- **Volume:** ذخیره دائمی داده‌ها
- **Network:** ارتباط بین کانتینرها (devbox-network)

---

## مدیریت کانتینر [🔝](#فهرست-مطالب)

### بالا آوردن کانتینر

**ویندوز:**

```powershell
.\scripts\up
```

**WSL2:**

```bash
./scripts/up
```

یا مستقیماً:

```bash
cd docker/compose
docker compose up -d
```

### توقف کانتینر

**ویندوز:**

```powershell
.\scripts\down
```

**WSL2:**

```bash
./scripts/down
```

### توقف و حذف Volume ها

**ویندوز:**

```powershell
.\scripts\down-v
```

**WSL2:**

```bash
./scripts/down-v.sh
```

> **هشدار:** این دستور تمام volume های named را حذف می‌کند شامل کالکشن‌های Bruno، pnpm store و dependency های کش شده.

### ورود به ترمینال

**ویندوز:**

```powershell
.\scripts\shell
```

**WSL2:**

```bash
./scripts/shell
```

### مشاهده لاگ‌ها

**ویندوز:**

```powershell
.\scripts\logs
```

**WSL2:**

```bash
./scripts/logs
```

### ری‌استارت

**ویندوز:**

```powershell
.\scripts\restart
```

**WSL2:**

```bash
./scripts/restart
```

### بررسی وضعیت

**ویندوز:**

```powershell
.\scripts\status
```

**WSL2:**

```bash
./scripts/status
```

### اجرای دستور داخل کانتینر

```powershell
run <command>
```

مثال:

```powershell
run pnpm create next-app my-app
run php artisan serve
```

### شناسایی پروژه‌ها

```powershell
scan
```

---

## دستورات Image [🔝](#فهرست-مطالب)

### ساخت ایمیج

**ویندوز:**

```powershell
.\scripts\build
```

**WSL2:**

```bash
./scripts/build
```

### ساخت مجدد (بدون کش)

**ویندوز:**

```powershell
.\scripts\rebuild
```

**WSL2:**

```bash
./scripts/rebuild
```

### مشاهده ایمیج‌ها

```bash
docker images
```

### حذف ایمیج

```bash
docker rmi devbox-lite
```

---

## دستورات پاک‌سازی [🔝](#فهرست-مطالب)

### پاک کردن کامل

**ویندوز:**

```powershell
.\scripts\clean
```

**WSL2:**

```bash
./scripts/clean
```

### پاک کردن کش

```bash
docker builder prune
docker system prune -a
```

---

## تست API [🔝](#فهرست-مطالب)

### Bruno

```powershell
test-api bruno
```

آدرس: http://localhost:6080

### استفاده آفلاین

1. کالکشن‌ها را در Bruno بسازید → خروجی JSON بگیرید
2. کالکشن‌ها در `workspace/data/bruno/collections/` ذخیره می‌شوند
3. کالکشن‌ها بدون اینترنت کار می‌کنند

### ولوم های Bruno

نرم افزار Bruno از volume های named Docker برای ذخیره‌سازی استفاده می‌کند:

- ‏`bruno-config` → `/root/.config/bruno` (تنظیمات Electron)
- ‏`bruno-collections` → `/root/bruno` (کالکشن‌های API)

برای پشتیبان‌گیری از داده‌های Bruno:

```bash
docker run --rm -v devbox_bruno-collections:/data:ro alpine tar czf /backup/bruno-collections.tar.gz -C /data .
```

---

## عیب‌یابی [🔝](#فهرست-مطالب)

### کانتینر بالا نمی‌آید

```powershell
.\scripts\logs
```

یا:

```powershell
cd docker/compose
docker compose logs devbox-lite
```

### پورت در حال استفاده است

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

### مشکل دسترسی

```powershell
docker compose exec devbox-lite chmod -R 777 /workspace
```

---

## نکات مهم [🔝](#فهرست-مطالب)

1. همیشه از اسکریپت‌های مدیریت استفاده کنید
2. قبل از حذف ایمیج، کانتینر را متوقف کنید
3. از `docker system prune` با احتیاط استفاده کنید
4. لاگ‌ها را برای عیب‌یابی بررسی کنید

---

## مستندات مرتبط [🔝](#فهرست-مطالب)

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
