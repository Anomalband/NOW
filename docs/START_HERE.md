# NOW MVP Baslangic

Bu repo NOW MVP icin tek kaynak kod tabanidir:
- Mobile: Flutter
- API: Fastify + Prisma + PostgreSQL
- Dashboard: React + Vite

## Hizli Kurulum

### API
1. `cd api`
2. `.env` icinde `DATABASE_URL` ve `APP_ADMIN_TOKEN` degerlerini kontrol et
3. `npm install`
4. `npm run prisma:generate`
5. `npm run prisma:push`
6. `npm run seed:quests`
7. `npm run dev`

Saglik kontrolu:
- `GET http://localhost:3000/api/v1/health`

### Dashboard
1. `cd dashboard`
2. `npm install`
3. `npm run dev`

### Mobile
1. `cd mobile`
2. `flutter pub get`
3. `flutter run`

Emulator API URL:
- `http://10.0.2.2:3000/api/v1`

## Match/Karma Akisi
1. `POST /users`
2. `POST /daily-profiles`
3. `POST /quest-selections`
4. `POST /matches/find-or-create`
5. `POST /matches/:id/messages`
6. `POST /matches/:id/proof`
7. `POST /matches/:id/complete`
8. `GET /users/:id/karma-history`

## Android Build Notu (Windows)
Eger APK build sirasinda `JAVA_HOME is not set` hatasi alirsan:
1. `JAVA_HOME` degerini JDK 17 yoluna ver
2. path'e `%JAVA_HOME%\\bin` ekle

Ornek (PowerShell):
```powershell
$env:JAVA_HOME='C:\\Program Files\\Microsoft\\jdk-17.0.18.8-hotspot'
$env:Path=\"$env:JAVA_HOME\\bin;$env:Path\"
flutter build apk --debug
```

## Deploy
- Render adimlari: `docs/RENDER_DEPLOY.md`
- Cleanup endpoint: `POST /api/v1/admin/cleanup` (`x-admin-token` gerekli)
