import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

/// Error dengan pesan yang sudah ramah pengguna.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ProdukMirip {
  final String nama;
  final double similarity;
  ProdukMirip(this.nama, this.similarity);

  factory ProdukMirip.fromJson(Map<String, dynamic> j) => ProdukMirip(
        j['nama'] as String,
        (j['similarity'] as num).toDouble(),
      );
}

class EstimasiResult {
  final bool ditemukan;
  final double ambangSimilarity;
  final double? similarityTertinggi;
  final double? similarityRataRata;
  final String? segmen;
  final double? pctPositif;
  final int jumlahPositif;
  final int jumlahNegatif;
  final int jumlahUlasanDasar;
  final double? medianHargaSerupa;
  final String? posisiHarga; // "di atas" | "di bawah" | "sebanding"
  final int kMaks;
  final int jumlahLolosAmbang;
  final int jumlahDianalisis;
  final int totalProduk;
  final List<ProdukMirip> produkMirip;

  EstimasiResult({
    required this.ditemukan,
    this.ambangSimilarity = 0.25,
    this.similarityTertinggi,
    this.similarityRataRata,
    this.segmen,
    this.pctPositif,
    this.jumlahPositif = 0,
    this.jumlahNegatif = 0,
    this.jumlahUlasanDasar = 0,
    this.medianHargaSerupa,
    this.posisiHarga,
    this.kMaks = 10,
    this.jumlahLolosAmbang = 0,
    this.jumlahDianalisis = 0,
    this.totalProduk = 0,
    this.produkMirip = const [],
  });

  factory EstimasiResult.fromJson(Map<String, dynamic> j) {
    final ambang = (j['ambang_similarity'] as num?)?.toDouble() ?? 0.25;
    if (j['ditemukan'] != true) {
      return EstimasiResult(
        ditemukan: false,
        ambangSimilarity: ambang,
        similarityTertinggi: (j['similarity_tertinggi'] as num?)?.toDouble(),
      );
    }
    return EstimasiResult(
      ditemukan: true,
      ambangSimilarity: ambang,
      similarityTertinggi: (j['similarity_tertinggi'] as num?)?.toDouble(),
      similarityRataRata: (j['similarity_rata_rata'] as num?)?.toDouble(),
      segmen: j['segmen'] as String?,
      pctPositif: (j['pct_positif'] as num?)?.toDouble(),
      jumlahPositif: (j['jumlah_positif'] as num?)?.toInt() ?? 0,
      jumlahNegatif: (j['jumlah_negatif'] as num?)?.toInt() ?? 0,
      jumlahUlasanDasar: (j['jumlah_ulasan_dasar'] as num?)?.toInt() ?? 0,
      medianHargaSerupa: (j['median_harga_serupa'] as num?)?.toDouble(),
      posisiHarga: j['posisi_harga'] as String?,
      kMaks: (j['k_maks'] as num?)?.toInt() ?? 10,
      jumlahLolosAmbang: (j['jumlah_lolos_ambang'] as num?)?.toInt() ?? 0,
      jumlahDianalisis: (j['jumlah_dianalisis'] as num?)?.toInt() ?? 0,
      totalProduk: (j['total_produk'] as num?)?.toInt() ?? 0,
      produkMirip: ((j['produk_mirip'] as List?) ?? [])
          .map((e) => ProdukMirip.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SentimenItem {
  final String ulasan;
  final String sentimen;
  final double keyakinan;
  SentimenItem(this.ulasan, this.sentimen, this.keyakinan);

  bool get positif => sentimen.toLowerCase().startsWith('pos');

  factory SentimenItem.fromJson(Map<String, dynamic> j) => SentimenItem(
        j['ulasan'] as String,
        j['sentimen'] as String,
        (j['keyakinan'] as num).toDouble(),
      );
}

class ApiService {
  // Otomatis: Chrome/Windows -> localhost, emulator Android -> 10.0.2.2.
  // HP asli: ganti dengan IP laptop, mis. 'http://192.168.1.10:8000'.
  static final String baseUrl =
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';
  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (res.statusCode == 422) {
        throw ApiException('Input tidak valid. Periksa isian kamu.');
      }
      if (res.statusCode >= 500) {
        throw ApiException('Server bermasalah (${res.statusCode}). Coba lagi nanti.');
      }
      if (res.statusCode != 200) {
        throw ApiException('Permintaan gagal (${res.statusCode}).');
      }
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Server terlalu lama merespons. Coba lagi.');
    } on SocketException {
      throw ApiException(
          'Tidak bisa terhubung ke server. Pastikan backend berjalan dan alamat/Wi-Fi sudah benar.');
    } on http.ClientException {
      throw ApiException('Koneksi ke server gagal.');
    } on FormatException {
      throw ApiException('Respons server tidak sesuai format yang diharapkan.');
    } on TypeError {
      throw ApiException('Respons server tidak sesuai format yang diharapkan.');
    }
  }

  Future<EstimasiResult> estimasi(String nama, double harga) async =>
      EstimasiResult.fromJson(await _post('/estimasi', {'nama': nama, 'harga': harga}));

  Future<String> segmen(double numberSold, double totalReview) async {
    final j = await _post(
        '/segmen', {'number_sold': numberSold, 'total_review': totalReview});
    return j['segmen'].toString();
  }

  Future<List<SentimenItem>> sentimen(List<String> ulasan) async {
    final j = await _post('/sentimen', {'ulasan': ulasan});
    return (j['hasil'] as List)
        .map((e) => SentimenItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}