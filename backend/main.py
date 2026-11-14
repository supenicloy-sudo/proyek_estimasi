
import re
import joblib
import numpy as np
import pandas as pd
import __main__

from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sklearn.metrics.pairwise import cosine_similarity


# ==================================================
# 1. KONFIGURASI DIREKTORI
# ==================================================

BASE_DIR = Path(__file__).resolve().parent


# ==================================================
# 2. FUNGSI PREPROCESSING
# ==================================================

def clean_text(t):
    t = re.sub(r"http\S+|www\S+", "", str(t).lower())
    t = re.sub(r"[^a-z\s]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def norm_nama(t):
    return re.sub(
        r"\s+",
        " ",
        re.sub(r"[^a-z\s]", " ", str(t).lower())
    ).strip()


# Dibutuhkan jika model pickle menyimpan referensi
# ke fungsi __main__.clean_text
__main__.clean_text = clean_text


# ==================================================
# 3. MEMUAT MODEL DAN DATASET
# ==================================================

def load_file(filename):
    path = BASE_DIR / filename

    if not path.exists():
        raise FileNotFoundError(
            f"File tidak ditemukan: {path}"
        )

    return path


try:
    nb = joblib.load(
        load_file("naive_bayes_pipeline.pkl")
    )

    km = joblib.load(
        load_file("kmeans_model.pkl")
    )

    sc = joblib.load(
        load_file("kmeans_scaler.pkl")
    )

    pre = joblib.load(
        load_file("kmeans_preprocessing.pkl")
    )

    idx = joblib.load(
        load_file("tfidf_nama_produk.pkl")
    )

    vec = idx["vectorizer"]
    M = idx["matrix"]

    data = pd.read_csv(
        load_file("data_produk_hasil.csv")
    )

except Exception as e:
    raise RuntimeError(
        f"Gagal memuat model atau dataset: {str(e)}"
    )


# ==================================================
# 4. INISIALISASI FASTAPI
# ==================================================

app = FastAPI(
    title="Proyek Estimasi Kelayakan Usaha",
    description=(
        "API untuk estimasi kelayakan produk "
        "menggunakan TF-IDF, K-Means, dan Naive Bayes."
    ),
    version="1.0.0"
)


# ==================================================
# 5. KONFIGURASI CORS
# ==================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==================================================
# 6. KONFIGURASI PARAMETER
# ==================================================

AMBANG_SIMILARITY = 0.25
K_MAKS = 10


# ==================================================
# 7. VALIDASI INPUT
# ==================================================

class EstimasiIn(BaseModel):
    nama: str = Field(min_length=1)
    harga: float = Field(ge=0)


class SegmenIn(BaseModel):
    number_sold: float = Field(ge=0)
    total_review: float = Field(ge=0)


class UlasanIn(BaseModel):
    ulasan: list[str] = Field(min_length=1)


# ==================================================
# 8. ENDPOINT HALAMAN UTAMA
# ==================================================

@app.get("/")
def home():
    return {
        "status": "online",
        "aplikasi": "Proyek Estimasi Kelayakan Usaha",
        "versi": "1.0.0",
        "algoritma": [
            "TF-IDF",
            "K-Means",
            "Naive Bayes"
        ],
        "endpoints": [
            "/estimasi",
            "/segmen",
            "/sentimen",
            "/health",
            "/docs"
        ]
    }


# ==================================================
# 9. ENDPOINT HEALTH CHECK
# ==================================================

@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": {
            "naive_bayes": nb is not None,
            "kmeans": km is not None,
            "scaler": sc is not None,
            "tfidf": vec is not None
        },
        "jumlah_data": int(len(data))
    }


# ==================================================
# 10. ESTIMASI KELAYAKAN PRODUK
# ==================================================

@app.post("/estimasi")
def estimasi(inp: EstimasiIn):

    try:
        nama_produk = norm_nama(inp.nama)

        if not nama_produk:
            raise HTTPException(
                status_code=400,
                detail="Nama produk tidak valid."
            )

        # Menghitung similarity produk
        skor = cosine_similarity(
            vec.transform([nama_produk]),
            M
        ).ravel()

        # Memilih produk berdasarkan ambang similarity
        kandidat = np.where(
            skor >= AMBANG_SIMILARITY
        )[0]

        if len(kandidat) == 0:
            return {
                "ditemukan": False,
                "pesan": (
                    "Produk serupa tidak ditemukan "
                    "dalam dataset."
                ),
                "similarity_tertinggi": round(
                    float(skor.max()), 3
                ),
                "ambang_similarity": AMBANG_SIMILARITY
            }

        # Mengurutkan produk berdasarkan similarity
        pilih = kandidat[
            np.argsort(skor[kandidat])[::-1][:K_MAKS]
        ]

        top = data.iloc[pilih]

        # Menghitung informasi ulasan
        n = int(top["Jumlah Ulasan"].sum())
        n_pos = int(top["Positive"].sum())
        n_neg = int(top["Negative"].sum())

        # Menghitung median harga
        med = float(top["Price"].median())

        # Menentukan posisi harga
        if inp.harga > med * 1.1:
            posisi_harga = "di atas"
        elif inp.harga < med * 0.9:
            posisi_harga = "di bawah"
        else:
            posisi_harga = "sebanding"

        # Menentukan segmen berdasarkan data
        segmen_produk = top["Potensi"].mode()

        if len(segmen_produk) == 0:
            segmen_produk = "Tidak diketahui"
        else:
            segmen_produk = str(segmen_produk.iloc[0])

        # Mengambil tiga produk paling mirip
        produk_mirip = []

        for i in pilih[:3]:
            produk_mirip.append({
                "nama": str(data.iloc[i]["Product Name"]),
                "similarity": round(float(skor[i]), 3)
            })

        return {
            "ditemukan": True,
            "nama_produk": inp.nama,
            "harga_input": inp.harga,

            "segmen": segmen_produk,

            "pct_positif": round(
                n_pos / n * 100, 1
            ) if n > 0 else None,

            "jumlah_positif": n_pos,
            "jumlah_negatif": n_neg,
            "jumlah_ulasan_dasar": n,

            "median_harga_serupa": med,
            "posisi_harga": posisi_harga,

            "ambang_similarity": AMBANG_SIMILARITY,
            "k_maks": K_MAKS,

            "jumlah_lolos_ambang": int(len(kandidat)),
            "jumlah_dianalisis": int(len(pilih)),
            "total_produk": int(len(data)),

            "similarity_tertinggi": round(
                float(skor[pilih[0]]), 3
            ),

            "similarity_rata_rata": round(
                float(skor[pilih].mean()), 3
            ),

            "produk_mirip": produk_mirip
        }

    except HTTPException:
        raise

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Terjadi kesalahan estimasi: {str(e)}"
        )


# ==================================================
# 11. SEGMENTASI PRODUK DENGAN K-MEANS
# ==================================================

@app.post("/segmen")
def segmen(inp: SegmenIn):

    try:
        # Membuat dataframe berdasarkan fitur model
        x = pd.DataFrame(
            [[inp.number_sold, inp.total_review]],
            columns=pre["features"]
        )

        # Melakukan clipping berdasarkan preprocessing
        for c in pre["features"]:
            b = pre["clip_bounds"][c]

            x[c] = x[c].clip(
                lower=b["lower"],
                upper=b["upper"]
            )

        # Transformasi log
        x = np.log1p(x)

        # Standardisasi data
        x_scaled = sc.transform(x)

        # Prediksi cluster
        cluster = int(
            km.predict(x_scaled)[0]
        )

        # Mengubah cluster menjadi label potensi
        mapping = pre["potensi_mapping"]

        nama_segmen = mapping[cluster]

        return {
            "berhasil": True,
            "cluster": cluster,
            "segmen": str(nama_segmen),
            "input": {
                "number_sold": inp.number_sold,
                "total_review": inp.total_review
            }
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Terjadi kesalahan segmentasi: {str(e)}"
        )


# ==================================================
# 12. ANALISIS SENTIMEN DENGAN NAIVE BAYES
# ==================================================

@app.post("/sentimen")
def sentimen(inp: UlasanIn):

    try:
        # Memastikan ulasan tidak kosong
        ulasan_bersih = [
            u.strip()
            for u in inp.ulasan
            if u and u.strip()
        ]

        if not ulasan_bersih:
            raise HTTPException(
                status_code=400,
                detail="Masukkan minimal satu ulasan."
            )

        # Prediksi sentimen
        pred = nb.predict(ulasan_bersih)

        # Menghitung probabilitas prediksi
        conf = nb.predict_proba(
            ulasan_bersih
        ).max(axis=1)

        hasil = []

        for u, p, c in zip(
            ulasan_bersih,
            pred,
            conf
        ):
            hasil.append({
                "ulasan": u,
                "sentimen": str(p),
                "keyakinan": round(float(c), 3)
            })

        return {
            "berhasil": True,
            "total_ulasan": len(hasil),
            "hasil": hasil
        }

    except HTTPException:
        raise

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Terjadi kesalahan analisis sentimen: {str(e)}"
        )
