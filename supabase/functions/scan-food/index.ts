// Edge Function "scan-food": menganalisis foto bahan baku dengan Groq.
// Key Groq hanya ada di server (secret GROQ_API_KEY), tidak di APK.
//
// Deploy:  supabase functions deploy scan-food
// Secret:  supabase secrets set GROQ_API_KEY=gsk_...   (opsional: GROQ_MODEL)
//
// Body:    { "image": "<base64>", "mimeType": "image/jpeg", "today": "YYYY-MM-DD" }
// Balasan: respons chat completions Groq apa adanya (dibaca oleh app).

// Tipe runtime Deno/Supabase (agar editor mengenali `Deno`).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_MODEL = "qwen/qwen3.8-27b";
const MAX_BASE64_LENGTH = 8_000_000; // ± 6 MB gambar

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Sama dengan AiScanService.instructions di lib/data/scan_service.dart.
function instructions(today: string): string {
  return `Kamu adalah inspektur kualitas bahan baku untuk UMKM kuliner di Indonesia.
Tanggal hari ini: ${today}.

Analisis foto. Untuk SETIAP jenis bahan makanan yang terlihat (buah, sayur,
daging, ikan, roti, susu, bahan kering, makanan kemasan, makanan jadi):
- Nilai kualitas: "A" (segar, mulus), "B" (layak, cacat kecil), "C" (harus
  segera diolah/dijual), atau "rusak" (busuk, berjamur, tidak layak konsumsi).
- freshness_score 0-100.
- Jika ada tanggal kedaluwarsa TERCETAK dan terbaca di kemasan, isi
  expiry_date (YYYY-MM-DD). Jangan menebak tanggal label.
- Jika tidak ada label, perkirakan shelf_life_days: sisa hari layak pakai
  pada suhu ruang mulai hari ini (0 jika sudah tidak layak).
- Perkirakan jumlah yang terlihat beserta satuannya bila memungkinkan.

Balas HANYA dengan JSON valid (tanpa markdown) dengan format:
{
  "is_food": true,
  "summary": "ringkasan singkat bahasa Indonesia",
  "items": [
    {
      "name": "nama bahan bahasa Indonesia, mis. Tomat",
      "category": "sayur|buah|roti|dagingIkan|susuOlahan|bahanKering|makananJadi",
      "quality": "A|B|C|rusak",
      "freshness_score": 0,
      "quantity": 0,
      "unit": "kg|gram|liter|pcs|pack|ikat|porsi",
      "expiry_date": null,
      "shelf_life_days": null,
      "reason": "alasan singkat penilaian (warna, memar, jamur, label)",
      "recommendation": "saran singkat: jual normal / diskon / olah hari ini / salurkan ke daur ulang"
    }
  ]
}
Jika foto bukan bahan makanan: {"is_food": false, "summary": "...", "items": []}.
`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Metode tidak didukung." }, 405);

  // Hanya user Operin yang login (token sesi, bukan sekadar anon key).
  const userResponse = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: {
      Authorization: req.headers.get("Authorization") ?? "",
      apikey: req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    },
  });
  if (!userResponse.ok) return json({ error: "Sesi berakhir. Silakan login ulang." }, 401);

  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey) return json({ error: "GROQ_API_KEY belum diatur di Supabase." }, 500);

  let body: { image?: unknown; mimeType?: unknown; today?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Permintaan tidak valid." }, 400);
  }
  const image = typeof body.image === "string" ? body.image : "";
  const mimeType = body.mimeType === "image/png" ? "image/png" : "image/jpeg";
  const today = typeof body.today === "string" && /^\d{4}-\d{2}-\d{2}$/.test(body.today)
    ? body.today
    : new Date().toISOString().slice(0, 10);
  if (!image) return json({ error: "Foto tidak ditemukan." }, 400);
  if (image.length > MAX_BASE64_LENGTH) return json({ error: "Ukuran foto terlalu besar." }, 413);

  const groq = await fetch(GROQ_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: Deno.env.get("GROQ_MODEL") ?? DEFAULT_MODEL,
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [{
        role: "user",
        content: [
          { type: "text", text: `${instructions(today)}\nAnalisis kualitas bahan baku pada foto ini.` },
          { type: "image_url", image_url: { url: `data:${mimeType};base64,${image}` } },
        ],
      }],
    }),
  });

  const text = await groq.text();
  if (!groq.ok) {
    console.error(`Groq ${groq.status}: ${text}`);
    if (groq.status === 429) {
      return json({ error: "Batas pemakaian AI tercapai. Coba lagi beberapa saat." }, 429);
    }
    if (groq.status === 401) {
      return json({ error: "GROQ_API_KEY di server tidak valid." }, 502);
    }
    return json({ error: `Layanan AI gagal (kode ${groq.status}).` }, 502);
  }
  return new Response(text, { headers: { ...cors, "Content-Type": "application/json" } });
});
