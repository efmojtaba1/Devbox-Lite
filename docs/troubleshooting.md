# راهنمای عیب‌یابی (DevBox Lite)

---

## عیب‌یابی سریع

- لاگ‌ها را ببینید:
```powershell
\scripts\logs
```
- وضعیت کانتینر:
 ```powershell
.\scripts\status
```
- کانتینر را ری‌استارت کنید:
 ```powershell
.\scripts\restarts
```

- ‏Docker Desktop را ری‌استارت کنید

---

## ‏مشکلات Docker

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

---

### پورت در حال استفاده است

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

---

### Permission Denied

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
---

### ‏Image Build نمی‌شود

```powershell
docker builder prune
.\scripts\rebuild
```

---

### فضای دیسک پر است

```powershell
docker system df
docker system prune -a --volumes
```

---

## مشکلات VS Code

### ‏VS Code به کانتینر وصل نمی‌شود

1. ری‌استارت کانتینر: `.\scripts\restart`
2. در VS Code: F1 → "Remote-Containers: Reopen in Container"

### افزونه‌ها نصب نمی‌شوند

```powershell
docker compose exec devbox-lite rm -rf /root/.vscode-server
```

سپس VS Code را ری‌استارت کنید

---

## مشکلات ابزارها

### ابزارها نصب نشده‌اند

```powershell
docker compose exec devbox-lite bash
which php
which node
which python3
```

### ‏Composer خطا می‌دهد

```powershell
docker compose exec devbox-lite bash
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
```

---

## مشکلات شبکه

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

## مشکلات Volume

### تغییرات ذخیره نمی‌شود

```powershell
docker volume ls
docker volume inspect devbox_workspace
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
---

## ‏Docker Desktop اجرا نمی‌شود

```powershell
Restart-Service com.docker.service
```

یا Docker Desktop را از منوی Start ری‌استارت کنید

---

## منابع مفید

- [مستندات Docker](https://docs.docker.com/)
- [مستندات Docker Compose](https://docs.docker.com/compose/)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/remote/containers)

---

## مستندات مرتبط

| مستند | توضیحات |
|-------|---------|
| [راهنمای استفاده](usage.md) | گردش کار روزمره و دستورات کاربردی |
| [مرجع Docker](docker.md) | دستورات کامل Docker |
| [راهنمای توسعه](development.md) | توسعه و نگهداری DevBox |
