# راهنمای عیب‌یابی (DevBox Lite)

**[English](../en/troubleshooting.md) | [بازگشت به خانه](README.md)**

---

## فهرست مطالب

* [عیب‌یابی سریع](#عیبیابی-سریع)
* [مشکلات Docker](#مشکلات-docker)
  * [کانتینر بالا نمی‌آید](#کانتینر-بالا-نمیآید)
  * [پورت در حال استفاده است](#پورت-در-حال-استفاده-است)
  * [Permission Denied](#permission-denied)
  * [Image Build نمی‌شود](#image-build-نمیشود)
  * [فضای دیسک پر است](#فضای-دیسک-پر-است)
* [مشکلات VS Code](#مشکلات-vs-code)
  * [VS Code به کانتینر وصل نمی‌شود](#vs-code-به-کانتینر-وصل-نمیشود)
  * [افزونه‌ها نصب نمی‌شوند](#افزونهها-نصب-نمیشوند)
* [مشکلات ابزارها](#مشکلات-ابزارها)
  * [ابزارها نصب نشده‌اند](#ابزارها-نصب-نشدهاند)
  * [خطای pnpm ERR_PNPM_IGNORED_BUILDS](#خطای-pnpm-err_pnpm_ignored_builds)
  * [Composer خطا می‌دهد](#composer-خطا-میدهد)
* [مشکلات دیتابیس](#مشکلات-دیتابیس)
  * [خطای Connection Refused هنگام اجرای Laravel Migration](#خطای-connection-refused-هنگام-اجرای-laravel-migration)
* [مشکلات شبکه](#مشکلات-شبکه)
  * [ارتباط بین کانتینرها](#ارتباط-بین-کانتینرها)
  * [دسترسی به اینترنت](#دسترسی-به-اینترنت)
* [مشکلات Volume](#مشکلات-volume)
  * [تغییرات ذخیره نمی‌شود](#تغییرات-ذخیره-نمیشود)
  * [ساخت پروژه Laravel با خاموشی مواجه می‌شود](#ساخت-پروژه-laravel-با-خاموشی-مواجه-میشود)
  * [Volume های قدیمی پس از حذف پروژه](#volume-های-قدیمی-پس-از-حذف-پروژه)
* [Docker Desktop اجرا نمی‌شود](#docker-desktop-اجرا-نمیشود)
* [مشکلات WSL2](#مشکلات-wsl2)
  * [WSL2 نصب نیست](#wsl2-نصب-نیست)
  * [Docker در WSL2 در دسترس نیست](#docker-در-wsl2-در-دسترس-نیست)
  * [کندی عملکرد در ویندوز](#کندی-عملکرد-در-ویندوز)
  * [Permission Denied در WSL2](#permission-denied-در-wsl2)
  * [بیلد کند Docker در WSL2](#بیلد-کند-docker-در-wsl2)
  * [دسترسی به فایل‌های ویندوز از WSL2](#دسترسی-به-فایلهای-ویندوز-از-wsl2)
* [احراز هویت GitHub](#احراز-هویت-github)
  * [روش ۱: SSH Key (توصیه شده)](#روش-۱-ssh-key-توصیه-شده)
  * [روش ۲: Personal Access Token](#روش-۲-personal-access-token)
* [منابع مفید](#منابع-مفید)
* [مستندات مرتبط](#مستندات-مرتبط)

---

## عیب‌یابی سریع [🔝](#فهرست-مطالب)

- لاگ‌ها را ببینید:

```powershell
.\scripts\logs
```

- وضعیت کانتینر:

```powershell
.\scripts\status
```

- کانتینر را ری‌استارت کنید:

```powershell
.\scripts\restart
```

- Docker Desktop را ری‌استارت کنید

---

## مشکلات Docker [🔝](#فهرست-مطالب)

### کانتینر بالا نمی‌آید

**راه‌حل:**

```powershell
.\scripts\logs
```

اگر خطا دیدید:

```powershell
.\scripts\rebuild
```

```powershell
.\scripts\up
```

### پورت در حال استفاده است

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

### پیغام Permission Denied

```powershell
docker compose exec devbox-lite chmod -R 777 /workspace
```

اگر مشکل ادامه داشت:

```powershell
.\scripts\down
```

```powershell
docker volume rm devbox_workspace
```

```powershell
.\scripts\up
```

### ایمیج Build نمی‌شود

```powershell
docker builder prune
.\scripts\rebuild
```

### فضای دیسک پر است

```powershell
docker system df
docker system prune -a --volumes
```

---

## مشکلات VS Code [🔝](#فهرست-مطالب)

## ادیتور (VS Code) به کانتینر وصل نمی‌شود

1. ری‌استارت کانتینر:

```powershell
.\scripts\restart
```

2. در VS Code: F1 → "Dev Containers: Reopen in Container"

### افزونه‌ها نصب نمی‌شوند

```powershell
docker compose exec devbox-lite rm -rf /root/.vscode-server
```

سپس VS Code را ری‌استارت کنید

---

## مشکلات ابزارها [🔝](#فهرست-مطالب)

### ابزارها نصب نشده‌اند

```powershell
docker compose exec devbox-lite bash
which php
which node
which python3
```

### خطای pnpm ERR_PNPM_IGNORED_BUILDS

اگر هنگام `pnpm install` خطای `ERR_PNPM_IGNORED_BUILDS` دیدید:

```bash
# داخل کانتینر
pnpm approve-builds --all
```

این یک ویژگی امنیتی pnpm 10+ است. DevBox با تنظیم `dangerouslyAllowAllBuilds: true` در تنظیمات جهانی، این مشکل را بعد از rebuild حل کرده است.

### کامپوزر خطا می‌دهد

```powershell
docker compose exec devbox-lite bash
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
```

---

## مشکلات دیتابیس [🔝](#فهرست-مطالب)

### خطای Connection Refused هنگام اجرای Laravel Migration

اگر هنگام اجرای `php artisan migrate` خطای `SQLSTATE[HY000] [2002] Connection refused` دیدید:

**علت:** فایل `.env` از `127.0.0.1` به عنوان `DB_HOST` استفاده می‌کند، اما داخل کانتینرهای Docker، سرویس‌ها از طریق نام کانتینر ارتباط برقرار می‌کنند.

**راه‌حل:** فایل `.env` لاراول خود را به‌روزرسانی کنید:

```env
DB_HOST=devbox-mysql    # نه 127.0.0.1
```

---

## مشکلات شبکه [🔝](#فهرست-مطالب)

### ارتباط بین کانتینرها

```powershell
docker network ls
docker network inspect devbox-network
.\scripts\down
.\scripts\up
```

### دسترسی به اینترنت

```powershell
docker compose exec devbox-lite ping 8.8.8.8
```

اگر مشکل داشتید، DNS را در docker-compose.yml تنظیم کنید:

```yaml
services:
  devbox-lite:
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

---

## مشکلات Volume [🔝](#فهرست-مطالب)

### تغییرات ذخیره نمی‌شود

```powershell
docker volume ls
docker volume inspect devbox_workspace
docker compose exec devbox-lite chmod -R 777 /workspace
```

اگر مشکل ادامه داشت:

```powershell
.\scripts\down-v
.\scripts\up
```

### ساخت پروژه Laravel با خاموشی مواجه می‌شود

اگر `laravel new` پرامپت‌ها را نمایش می‌دهد اما بلافاصله پس از "Creating Laravel application..." خارج می‌شود:

**علت:** Volume های named قدیمی (`devbox_vendor-laravel`، `devbox_node-modules-laravel`) از پروژه قبلی باقی مانده‌اند.

**راه‌حل:**

توقف کانتینر و حذف volume ها:

```powershell
.\scripts\down-v
```

شروع مجدد:

```powershell
.\scripts\up
```

حالا پروژه خود را بسازید:

```powershell
.\scripts\shell
```

داخل کانتینر:

```bash
laravel new my-app
```

### ‏volume های قدیمی پس از حذف پروژه

وقتی پوشه پروژه را حذف می‌کنید، volume های مرتبط باقی می‌مانند. برای پاک کردن آنها:

لیست تمام volume های devbox:

```powershell
docker volume ls | findstr devbox
```

حذف volume های خاص (اول کانتینر را متوقف کنید):

```powershell
.\scripts\down-v
docker volume rm devbox_vendor-laravel devbox_node-modules-laravel
.\scripts\up
```

---

## Docker Desktop اجرا نمی‌شود [🔝](#فهرست-مطالب)

```powershell
Restart-Service com.docker.service
```

یا Docker Desktop را از منوی Start ری‌استارت کنید

---

## مشکلات WSL2 [🔝](#فهرست-مطالب)

### ‏WSL2 نصب نیست

```powershell
wsl --install
```

پس از نصب، کامپیوتر را ری‌استارت کنید.

### ‏Docker در WSL2 در دسترس نیست

**روش ۱: فعال‌سازی WSL Integration در Docker Desktop (توصیه شده)**

1. ‏Docker Desktop را باز کنید
2. به Settings → Resources → WSL Integration بروید
3. توزیع Ubuntu خود را فعال کنید
4. روی "Apply & Restart" کلیک کنید

**روش ۲: نصب Docker به صورت بومی در Ubuntu**

```bash
# داخل Ubuntu WSL2
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
# ری‌استارت WSL
wsl --shutdown
```

سپس ترمینال Ubuntu را مجدداً باز کنید.

### کندی عملکرد در ویندوز

اگر توسعه در ویندوز کند است، به WSL2 مهاجرت کنید:

```bash
# کلون کردن داخل WSL2
git clone https://github.com/efmojtaba1/DevBox.git ~/projects/DevBox
cd ~/projects/DevBox
echo "WORKSPACE_PATH=$PWD" > .env
./scripts/build
./scripts/up
./scripts/shell
```

### ‏Permission Denied در WSL2

```bash
sudo chmod -R 777 ~/projects/DevBox
```

### بیلد کند Docker در WSL2

اگر بیلد Docker در WSL2 کند است:

1. اتصال اینترنت را بررسی کنید: `ping -c 4 8.8.8.8`
2. از رجیستری mirror استفاده کنید
3. منابع کافی اختصاص دهید (حداقل 4GB RAM، 2 هسته CPU)
4. محدودیت حافظه WSL2 را در `.wslconfig` بررسی کنید:

```ini
# %USERPROFILE%\.wslconfig
[wsl2]
memory=8GB
processors=4
```

### دسترسی به فایل‌های ویندوز از WSL2

درایوهای ویندوز در مسیر `/mnt/` مانت می‌شوند. مثال:

- `C:\Users` → `/mnt/c/Users`
- `D:\Projects` → `/mnt/d/Projects`

برای عملکرد بهتر، فایل‌های پروژه را داخل فایل‌سیستم WSL2 (`~/projects/`) نگه دارید، نه روی درایوهای ویندوز.

---

## احراز هویت GitHub [🔝](#فهرست-مطالب)

‏GitHub دیگر از پسورد برای عملیات Git پشتیبانی نمی‌کند. باید از SSH key یا Personal ‏Access Token استفاده کنید.

### روش ۱: SSH Key (توصیه شده)

**مرحله ۱: ساخت SSH key**

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

‏Enter بزنید تا مسیر پیش‌فرض و بدون رمز عبور قبول شود.

**مرحله ۲: کپی کلید عمومی**

```bash
cat ~/.ssh/id_ed25519.pub
```

خروجی را کامل کپی کنید.

**مرحله ۳: اضافه کردن کلید به GitHub**

1. به https://github.com/settings/keys بروید
2. روی **"New SSH key"** کلیک کنید
3. کلید کپی شده را Paste کنید
4. روی **"Add SSH key"** کلیک کنید

**مرحله ۴: تست اتصال**

```bash
ssh -T git@github.com
```

اگر پیام "Hi username! You've successfully authenticated..." را دیدید، کار می‌کند.

**مرحله ۵: کلون با SSH**

```bash
git clone git@github.com:efmojtaba1/DevBox.git
```

### روش ۲: Personal Access Token

**مرحله ۱: ساخت token**

1. به https://github.com/settings/tokens بروید
2. روی **"Generate new token (classic)"** کلیک کنید
3. ‏scopes را انتخاب کنید: `repo`، `read:org`
4. روی **"Generate token"** کلیک کنید
5. ‏token را فوراً کپی کنید

**مرحله ۲: کلون با token**

```bash
git clone https://YOUR_TOKEN@github.com/efmojtaba1/DevBox.git
```

**مرحله ۳: ذخیره credential (اختیاری)**

```bash
git config --global credential.helper store
```

---

## منابع مفید [🔝](#فهرست-مطالب)

- [مستندات Docker](https://docs.docker.com/)
- [مستندات Docker Compose](https://docs.docker.com/compose/)
- ‏[VS Code Dev Containers](https://code.visualstudio.com/docs/remote/containers)

---

## مستندات مرتبط [🔝](#فهرست-مطالب)

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
