import re
import joblib
import numpy as np
import pandas as pd
import __main__
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sklearn.metrics.pairwise import cosine_similarity

def clean_text(t):
    t = re.sub(r"http\S+|www\S+", "", str(t).lower())
    t = re.sub(r"[^a-z\s]", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def norm_nama(t):
    return re.sub(r"\s+", " ", re.sub(r"[^a-z\s]", " ", str(t).lower())).strip()

# Pipeline menyimpan nama fungsi clean_text, jadi harus bisa ditemukan saat load.
__main__.clean_text = clean_text

nb = joblib.load("naive_bayes_pipeline.pkl")
km = joblib.load("kmeans_model.pkl")
sc = joblib.load("kmeans_scaler.pkl")
pre = joblib.load("kmeans_preprocessing.pkl")
idx = joblib.load("tfidf_nama_produk.pkl")
vec, M = idx["vectorizer"], idx["matrix"]
data = pd.read_csv("data_produk_hasil.csv")  # urutan baris sama dengan matriks M

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # izinkan akses dari Flutter Web (Chrome)
    allow_methods=["*"],
    allow_headers=["*"],
)

AMBANG_SIMILARITY = 0.25   # sesuai naskah: kemiripan kosinus minimal 0,25
K_MAKS = 10                # sesuai naskah: maksimal 10 produk teratas

class EstimasiIn(BaseModel):
    nama: str
    harga: float

@app.post("/estimasi")
def estimasi(inp: EstimasiIn):
    skor = cosine_similarity(vec.transform([norm_nama(inp.nama)]), M).ravel()
    kandidat = np.where(skor >= AMBANG_SIMILARITY)[0]
    if len(kandidat) == 0:
        return {
            "ditemukan": False,
            "similarity_tertinggi": float(skor.max()),
            "ambang_similarity": AMBANG_SIMILARITY,
        }
    pilih = kandidat[np.argsort(skor[kandidat])[::-1][:K_MAKS]]
    top = data.iloc[pilih]
    n = int(top["Jumlah Ulasan"].sum())
    n_pos = int(top["Positive"].sum())
    n_neg = int(top["Negative"].sum())
    med = float(top["Price"].median())
    return {
        "ditemukan": True,
        "segmen": top["Potensi"].mode().iloc[0],
        "pct_positif": round(n_pos / n * 100, 1) if n > 0 else None,
        "jumlah_positif": n_pos,
        "jumlah_negatif": n_neg,
        "jumlah_ulasan_dasar": n,
        "median_harga_serupa": med,
        "posisi_harga": "di atas" if inp.harga > med * 1.1
                        else "di bawah" if inp.harga < med * 0.9 else "sebanding",
        "ambang_similarity": AMBANG_SIMILARITY,
        "k_maks": K_MAKS,
        "jumlah_lolos_ambang": int(len(kandidat)),
        "jumlah_dianalisis": int(len(pilih)),
        "total_produk": int(len(data)),
        "similarity_tertinggi": round(float(skor[pilih[0]]), 3),
        "similarity_rata_rata": round(float(skor[pilih].mean()), 3),
        "produk_mirip": [
            {"nama": data.iloc[i]["Product Name"], "similarity": round(float(skor[i]), 3)}
            for i in pilih[:3]
        ],
    }

class SegmenIn(BaseModel):
    number_sold: float
    total_review: float

@app.post("/segmen")
def segmen(inp: SegmenIn):
    x = pd.DataFrame([[inp.number_sold, inp.total_review]], columns=pre["features"])
    for c in pre["features"]:
        b = pre["clip_bounds"][c]
        x[c] = x[c].clip(b["lower"], b["upper"])
    x = np.log1p(x)
    cluster = int(km.predict(sc.transform(x))[0])
    return {"segmen": pre["potensi_mapping"][cluster]}

class UlasanIn(BaseModel):
    ulasan: list[str]

@app.post("/sentimen")
def sentimen(inp: UlasanIn):
    pred = nb.predict(inp.ulasan)
    conf = nb.predict_proba(inp.ulasan).max(axis=1)
    return {"hasil": [
        {"ulasan": u, "sentimen": str(p), "keyakinan": round(float(c), 3)}
        for u, p, c in zip(inp.ulasan, pred, conf)
    ]}