# NOW Monorepo

NOW, 24 saatlik gecici sosyallesme vizyonu icin gelistirilmis MVP uygulama setidir.

## Klasorler
- `api/`: Fastify + Prisma + PostgreSQL backend
- `mobile/`: Flutter mobil uygulama (Android APK)
- `dashboard/`: React + Vite operasyon paneli
- `docs/`: hizli kurulum ve deploy notlari

## MVP Akisi (Uctan Uca)
1. Kullanici olustur
2. Gunluk vitrin (kamera/base64 photo) yayinla
3. Gunun gorevini sec
4. `find-or-create` ile esles
5. Match icinde mesajlas
6. Proof photo gonder
7. Iki taraf `complete` onayi verince:
   - match `COMPLETED` olur
   - iki kullaniciya +10 karma yazilir
   - `karma_event` kaydi olusur

## Local Calistirma

### 1) API
```bash
cd api
npm install
npm run prisma:generate
npm run prisma:push
npm run seed:quests
npm run dev
```

### 2) Dashboard
```bash
cd dashboard
npm install
npm run dev
```

### 3) Mobile
```bash
cd mobile
flutter pub get
flutter run
```

## Build Komutlari
- API build: `npm run build --workspace api`
- Dashboard build: `npm run build --workspace dashboard`
- Mobile test: `flutter test`
- Mobile debug APK: `flutter build apk --debug`

## Deploy (Render)
- Detayli adimlar: `docs/RENDER_DEPLOY.md`
- Render API deploy akisi otomatik:
  - `prisma db push`
  - quest seed (`seed:quests:prod`)
  - API start

## Notlar
- Android emulator icin varsayilan API adresi: `http://10.0.2.2:3000/api/v1`
- Gece temizligi: `POST /api/v1/admin/cleanup` (`x-admin-token` gerekli)
