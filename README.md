# Estimasi Potensi Produk (Flutter + FastAPI)

```
proyek_estimasi/
├─ backend/        FastAPI + model .pkl
└─ flutter_app/    Aplikasi Flutter
```

## 1. Backend
1. Taruh 5 file `.pkl` dan `data_produk_hasil.csv` di `backend/` (lihat PUT_MODEL_FILES_HERE.txt).
2. Edit `backend/requirements.txt`: ganti `VERSI_COLAB` dengan versi scikit-learn di Colab.
3. Jalankan:
```
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows  (Mac/Linux: source .venv/bin/activate)
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```
Tes: buka http://localhost:8000/docs

## 2. Flutter
```
cd flutter_app
flutter create .              # membuat folder android/ios/dll; lib/ dan pubspec milikmu tidak ditimpa
python patch_android.py       # izinkan http:// saat pengembangan
flutter pub get
flutter run
```
- Emulator Android: `baseUrl` sudah `http://10.0.2.2:8000`.
- HP asli: ubah `baseUrl` di `lib/api_service.dart` ke IP laptop (mis. `http://192.168.1.10:8000`), satu Wi-Fi, dan izinkan port 8000 di firewall.
- Untuk produksi: pakai HTTPS dan hapus `usesCleartextTraffic`.
