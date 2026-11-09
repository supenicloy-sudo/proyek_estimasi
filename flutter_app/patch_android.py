"""Jalankan SETELAH `flutter create .` : menambah usesCleartextTraffic (http) ke AndroidManifest."""
p = "android/app/src/main/AndroidManifest.xml"
s = open(p, encoding="utf-8").read()
if "usesCleartextTraffic" in s:
    print("Sudah ada, tidak diubah.")
else:
    s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
    open(p, "w", encoding="utf-8").write(s)
    print("OK: usesCleartextTraffic ditambahkan.")
