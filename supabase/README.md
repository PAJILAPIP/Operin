# Setup backend Supabase untuk Operin

Semua data Operin (akun, stok, promo, pesanan, barter, riwayat) disimpan di
Supabase. Scan AI juga lewat server, jadi key Groq tidak ada di APK.

## 1. Buat project

1. Masuk ke <https://supabase.com> → **New project**. Pilih region terdekat
   (mis. Singapore) dan simpan password database.
2. **Authentication → Sign In / Providers → Email**: matikan **Confirm email**
   (untuk prototype, supaya akun baru langsung bisa dipakai).

## 2. Buat tabel & fungsi

Di **SQL Editor**, jalankan isi file berikut **berurutan** (salin-tempel → Run):

1. `migrations/0001_init.sql`: tabel, keamanan (RLS), view, realtime
2. `migrations/0002_functions.sql`: transaksi pesanan & barter

Kalau memakai Supabase CLI: `supabase link --project-ref <ref>` lalu
`supabase db push`.

## 3. Sambungkan aplikasi

Di **Project Settings → API Keys**, salin:

- **Project URL** (`https://<ref>.supabase.co`)
- **Publishable key** (`sb_publishable_...`, atau *anon key* untuk project lama)

Isi keduanya di `lib/core/config/supabase_config.dart` (`defaultValue`), atau
saat build:

```
flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_...
```

Key ini **aman** ada di aplikasi: data dilindungi Row Level Security, dan
transaksi hanya bisa lewat fungsi yang memeriksa siapa yang login.

## 4. Scan AI (Edge Function `scan-food`)

Buat **API key Groq baru** di <https://console.groq.com> (key lama sudah
tersimpan di riwayat git, jadi anggap bocor dan hapus).

**Lewat dashboard:** Edge Functions → **Deploy a new function** → *Via Editor*
→ nama `scan-food` → tempel isi `functions/scan-food/index.ts` → Deploy.
Lalu Edge Functions → **Secrets** → **Add new secret**:

| Kolom | Isi |
|---|---|
| Name | `GROQ_API_KEY` |
| Value | key Groq Anda saja, mis. `gsk_AbC123...` (tanpa `GROQ_API_KEY=`, tanpa tanda kutip) |

**Lewat CLI:**

```
supabase functions deploy scan-food
supabase secrets set GROQ_API_KEY=gsk_...
```

Opsional: secret `GROQ_MODEL` untuk mengganti model (default
`qwen/qwen3.8-27b`).

## 5. Cek

1. Jalankan app di dua perangkat (mis. HP + emulator), daftar akun A dan B.
2. A: tambah stok → buat promo. B: tab **Pasar B2B** → promo A muncul → ajukan.
3. A: pengajuan masuk muncul otomatis (realtime) → terima → **Tandai Selesai**.
4. B: stok bertambah, halaman **Dampak** terisi.
5. Tab **Scan AI** → foto buah/sayur → hasil analisis muncul.
