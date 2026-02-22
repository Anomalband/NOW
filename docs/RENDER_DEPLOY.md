# NOW Render Deploy Checklist

Bu dokuman NOW MVP'yi Render uzerinde calistirmak icin net adimlari verir.

## 0) On kosullar
- Kod GitHub repo'ya push edilmis olmali.
- Render hesabi GitHub ile baglanmis olmali.
- Managed Postgres (onerilen: Neon) hazir olmali.

## 1) Veritabani hazirla
1. Neon (veya baska provider) uzerinde yeni Postgres DB olustur.
2. `DATABASE_URL` baglanti bilgisini al.
3. SSL aktif olmali (`sslmode=require`).

Ornek:
`postgresql://<user>:<password>@<host>/<db>?sslmode=require`

## 2) Render Blueprint import
1. Render Dashboard -> `New` -> `Blueprint`.
2. Bu repo'yu sec.
3. `render.yaml` dosyasini import et.
4. Olusacak servisler:
   - `now-api` (web service)
   - `now-dashboard` (static site)

Not:
- API servisinde deploy aninda otomatik olarak su akis calisir:
  - `prisma db push`
  - quest seed (`seed:quests:prod`)
  - api start

## 3) Environment variable ayarlari
### now-api
- `NODE_ENV=production`
- `DATABASE_URL=<managed_postgres_connection_string>`
- `APP_ADMIN_TOKEN=<uzun_guclu_token>`
- `CORS_ORIGIN=https://<dashboard-domain>`

### now-dashboard
- `VITE_API_BASE_URL=https://<api-domain>/api/v1`

## 4) Deploy sonrasi smoke test
API:
1. `GET https://<api-domain>/api/v1/health`
2. `GET https://<api-domain>/api/v1/quests?district=Kadikoy&limit=5`

Dashboard:
1. `https://<dashboard-domain>` ac.
2. `Health Check` calistir.
3. `Load Quests` calistir.
4. User + Daily Profile + Quest + Match akisini test et.

## 5) Cleanup workflow
Bu repo saatlik cleanup icin GitHub Actions kullanir (`cleanup-expired.yml`).

GitHub -> Settings -> Secrets and variables -> Actions:
- `NOW_CLEANUP_URL=https://<api-domain>/api/v1/admin/cleanup`
- `NOW_ADMIN_TOKEN=<APP_ADMIN_TOKEN ile ayni>`

## 6) Sik gorulen hatalar
- `401 Unauthorized`:
  `x-admin-token` degeri `APP_ADMIN_TOKEN` ile eslesmiyor.
- CORS hatasi:
  `CORS_ORIGIN` dashboard domaini ile ayni degil.
- Quest listesi bos:
  `seed` calismamis olabilir; logda `seed:quests:prod` kontrol et.

## 7) Production hijyeni
- `APP_ADMIN_TOKEN` rastgele ve guclu olmali.
- Secret degerler repo icine yazilmamali.
- Local `.env` ile production degerleri karistirilmamali.
