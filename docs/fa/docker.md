# مرجع دستورات Docker (DevBox Lite)

**[فارسی](docker.md)** | **[English](../en/docker.md)** | [بازگشت به خانه](../../README.md)

---

## مفاهیم پایه

- ‏**Image:** قالب سیستم‌عامل و ابزارهای نصب‌شده
- ‏**Container:** نمونه اجرا شده از Image
- ‏**Volume:** ذخیره دائمی داده‌ها (پوشه workspace/)
- ‏**Network:** ارتباط بین کانتینرها (devbox-network)

---

## دستورات مدیریت

### بالا آوردن کانتینر

**ویندوز:**
```powershell
.\scripts\up
```

**WSL2:**
```bash
./scripts/up
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

### اجرای دستور دلخواه

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

## دستورات Image

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

## دستورات پاک‌سازی

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

## تست API

### Bruno (سبک و سریع)

```powershell
test-api bruno
```
آدرس: http://localhost:6080

### استفاده آفلاین

1. کالکشن‌ها را در Bruno بسازید → خروجی JSON بگیرید
2. فایل‌های JSON را در `workspace/bruno-collections/` کپی کنید
3. کالکشن‌ها بدون اینترنت کار می‌کنند

---

## عیب‌یابی

### کانتینر بالا نمی‌آید

```powershell
.\scripts\logs
```
یا:
```powershell
cd docker/compose
docker compose logs devbox-lite
```

### پورت در حال استفاده

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

### مشکل دسترسی

```powershell
docker compose exec devbox-lite chmod -R 777 /workspace
```

---

## نکات مهم

1. همیشه از اسکریپت‌های مدیریت استفاده کنید
2. قبل از حذف ایمیج، کانتینر را متوقف کنید
3. از `docker system prune` با احتیاط استفاده کنید
4. لاگ‌ها را برای عیب‌یابی بررسی کنید

---

## مستندات مرتبط

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [عیب‌یابی](troubleshooting.md) | رفع اشکال و خطاهای متداول |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
