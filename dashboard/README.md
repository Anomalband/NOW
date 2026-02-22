# NOW Dashboard

NOW dashboard, MVP operasyon akislarini tek ekrandan test etmek icin kullanilir.

## Ozellikler
- API health kontrolu
- User olusturma
- Daily profile yayinlama
- Quest listeleme ve secim kaydetme
- Match bulma/listeleme
- Match sohbet/proof/complete aksiyonlari
- Karma gecmisi goruntuleme
- Cleanup dry-run

## Calistirma
```bash
cd dashboard
npm install
npm run dev
```

## Build
```bash
npm run build
```

## API URL
`VITE_API_BASE_URL` ayari ile degistirilebilir.
Varsayilan: `http://localhost:3000/api/v1`
