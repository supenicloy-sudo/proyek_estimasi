import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'api_service.dart';

class EstimasiPage extends StatefulWidget {
  const EstimasiPage({super.key});

  @override
  State<EstimasiPage> createState() => _EstimasiPageState();
}

class _EstimasiPageState extends State<EstimasiPage> {
  final formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final hargaController = TextEditingController();

  final api = ApiService();

  EstimasiResult? result;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    namaController.dispose();
    hargaController.dispose();
    super.dispose();
  }

  // FORMAT RUPIAH
  String rupiah(num value) {
    final angka = value.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < angka.length; i++) {
      buffer.write(angka[i]);

      final sisa = angka.length - i - 1;
      if (sisa > 0 && sisa % 3 == 0) {
        buffer.write('.');
      }
    }

    return 'Rp $buffer';
  }

  // PROSES ESTIMASI
  Future<void> hitungEstimasi() async {
    if (!formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      error = null;
      result = null;
    });

    try {
      final nama = namaController.text.trim();

      final harga = double.parse(
        hargaController.text.replaceAll('.', '').replaceAll(',', ''),
      );

      final data = await api.estimasi(nama, harga);

      if (!mounted) return;

      setState(() {
        result = data;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // TAMPILAN UTAMA
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Estimasi Potensi Produk',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF183B3B),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(),
              const SizedBox(height: 22),
              formProduk(),

              if (loading) ...[
                const SizedBox(height: 25),
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text('Sedang menganalisis produk...'),
                ),
              ],

              if (error != null) ...[
                const SizedBox(height: 15),
                card(
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],

              if (result != null) ...[
                const SizedBox(height: 25),
                hasilAnalisis(result!),
              ],

              const SizedBox(height: 30),

              const Center(
                child: Text(
                  'Estimasi Potensi Produk',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER
  Widget header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF087F75),
            Color(0xFF16A394),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.analytics_outlined,
            color: Colors.white,
            size: 35,
          ),
          SizedBox(height: 15),
          Text(
            'Analisis Potensi Produk',
            style: TextStyle(
              fontSize: 21,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Analisis produk berdasarkan kemiripan produk, '
            'sentimen ulasan, dan perbandingan harga.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // FORM INPUT PRODUK
  Widget formProduk() {
    return card(
      Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Input Produk'),
            const SizedBox(height: 18),

            const Text(
              'Nama Produk',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: namaController,
              decoration: inputDecoration(
                'Masukkan nama produk',
                Icons.shopping_bag_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama produk harus diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 17),

            const Text(
              'Harga Produk',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: hargaController,
              keyboardType: TextInputType.number,
              decoration: inputDecoration(
                'Contoh: 150000',
                Icons.payments_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Harga produk harus diisi';
                }

                final harga = double.tryParse(
                  value.replaceAll('.', '').replaceAll(',', ''),
                );

                if (harga == null || harga <= 0) {
                  return 'Masukkan harga yang valid';
                }

                return null;
              },
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: loading ? null : hitungEstimasi,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text(
                  'Analisis Sekarang',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF087F75),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HASIL ANALISIS
  Widget hasilAnalisis(EstimasiResult data) {
    if (!data.ditemukan) {
      return tidakDitemukan(data);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('Hasil Analisis'),
        const SizedBox(height: 14),

        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Segmen Produk',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),

              Text(
                data.segmen ?? '-',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF087F75),
                ),
              ),

              const SizedBox(height: 10),

              infoRow(
                'Similarity tertinggi',
                '${((data.similarityTertinggi ?? 0) * 100).toStringAsFixed(1)}%',
              ),

              infoRow(
                'Jumlah produk dianalisis',
                '${data.jumlahDianalisis}',
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),
        diagramSentimen(data),

        const SizedBox(height: 15),
        grafikPerbandinganHarga(data),

        const SizedBox(height: 15),

        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionTitle('Statistik Ulasan'),
              const SizedBox(height: 15),

              infoRow(
                'Ulasan dasar',
                '${data.jumlahUlasanDasar}',
              ),

              infoRow(
                'Ulasan positif',
                '${data.jumlahPositif}',
              ),

              infoRow(
                'Ulasan negatif',
                '${data.jumlahNegatif}',
              ),

              infoRow(
                'Persentase positif',
                '${(data.pctPositif ?? 0).toStringAsFixed(1)}%',
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),
        produkMirip(data),

        const SizedBox(height: 15),
        dasarEstimasi(data),
      ],
    );
  }

  // DIAGRAM SENTIMEN
  Widget diagramSentimen(EstimasiResult data) {
    final positif = data.jumlahPositif.toDouble();
    final negatif = data.jumlahNegatif.toDouble();
    final total = positif + negatif;
    final pct = (data.pctPositif ?? 0).toDouble();

    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Analisis Sentimen'),
          const SizedBox(height: 15),

          SizedBox(
            height: 190,
            child: total == 0
                ? const Center(
                    child: Text('Belum ada data sentimen'),
                  )
                : PieChart(
                    PieChartData(
                      centerSpaceRadius: 55,
                      sectionsSpace: 4,
                      sections: [
                        if (positif > 0)
                          PieChartSectionData(
                            value: positif,
                            color: Colors.teal,
                            radius: 25,
                            showTitle: false,
                          ),
                        if (negatif > 0)
                          PieChartSectionData(
                            value: negatif,
                            color: Colors.orange,
                            radius: 25,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
          ),

          Center(
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),

          const Center(
            child: Text(
              'Persentase ulasan positif',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 18),

          legend(
            Colors.teal,
            'Positif',
            '${positif.toInt()} ulasan',
          ),

          const SizedBox(height: 8),

          legend(
            Colors.orange,
            'Negatif',
            '${negatif.toInt()} ulasan',
          ),
        ],
      ),
    );
  }

  // GRAFIK PERBANDINGAN HARGA
  Widget grafikPerbandinganHarga(EstimasiResult data) {
    final hargaInput = double.tryParse(
          hargaController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;

    final median = (data.medianHargaSerupa ?? 0).toDouble();

    if (hargaInput <= 0 || median <= 0) {
      return card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Perbandingan Harga'),
            const SizedBox(height: 12),
            const Text(
              'Data median harga produk serupa belum tersedia.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final maxHarga = hargaInput > median ? hargaInput : median;
    final selisih = (hargaInput - median).abs();
    final persentase = (selisih / median) * 100;

    final status = hargaInput > median
        ? 'Di atas median'
        : hargaInput < median
            ? 'Di bawah median'
            : 'Sama dengan median';

    final statusColor = hargaInput > median
        ? Colors.orange
        : hargaInput < median
            ? Colors.teal
            : Colors.blueGrey;

    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Perbandingan Harga'),
          const SizedBox(height: 5),

          const Text(
            'Harga produk dibandingkan dengan median harga produk serupa.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 25),

          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                maxY: maxHarga * 1.3,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxHarga * 1.3 / 4,
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rupiah(rod.toY),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value == 0
                              ? '0'
                              : '${(value / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        String label;

                        if (value.toInt() == 0) {
                          label = 'Harga Input';
                        } else if (value.toInt() == 1) {
                          label = 'Median';
                        } else {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: hargaInput,
                        color: Colors.teal,
                        width: 38,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: median,
                        color: Colors.orange,
                        width: 38,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),

          infoRow('Harga input', rupiah(hargaInput)),
          infoRow('Median produk serupa', rupiah(median)),
          infoRow('Selisih harga', rupiah(selisih)),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Color.fromARGB(
                26,
                statusColor.red,
                statusColor.green,
                statusColor.blue,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  hargaInput == median
                      ? 'Harga produk sama dengan median harga produk serupa.'
                      : '${persentase.toStringAsFixed(1)}% '
                          '${hargaInput > median ? 'lebih mahal' : 'lebih murah'} '
                          'dibandingkan median harga produk serupa.',
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PRODUK SERUPA
  Widget produkMirip(EstimasiResult data) {
    final produk = data.produkMirip;

    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Produk Serupa'),
          const SizedBox(height: 12),

          if (produk.isEmpty)
            const Text(
              'Tidak ada produk serupa yang ditemukan.',
              style: TextStyle(color: Colors.grey),
            ),

          ...produk.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      item.nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Text(
                    '${(item.similarity * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DASAR ESTIMASI
  Widget dasarEstimasi(EstimasiResult data) {
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Dasar Estimasi'),
          const SizedBox(height: 12),

          infoRow(
            'Ambang similarity',
            '${(data.ambangSimilarity * 100).toStringAsFixed(1)}%',
          ),

          infoRow(
            'Produk lolos ambang',
            '${data.jumlahLolosAmbang}',
          ),

          infoRow(
            'Produk dianalisis',
            '${data.jumlahDianalisis}',
          ),

          infoRow(
            'Total produk dataset',
            '${data.totalProduk}',
          ),

          infoRow(
            'Similarity rata-rata',
            '${((data.similarityRataRata ?? 0) * 100).toStringAsFixed(1)}%',
          ),

          infoRow(
            'Posisi harga',
            data.posisiHarga ?? '-',
          ),
        ],
      ),
    );
  }

  // PRODUK TIDAK DITEMUKAN
  Widget tidakDitemukan(EstimasiResult data) {
    return card(
      Column(
        children: [
          const Icon(
            Icons.search_off,
            size: 45,
            color: Colors.orange,
          ),

          const SizedBox(height: 12),

          const Text(
            'Produk Serupa Tidak Ditemukan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Belum ditemukan produk yang memenuhi ambang similarity.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 12),

          infoRow(
            'Ambang similarity',
            '${(data.ambangSimilarity * 100).toStringAsFixed(1)}%',
          ),

          infoRow(
            'Similarity tertinggi',
            '${((data.similarityTertinggi ?? 0) * 100).toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }

  // JUDUL BAGIAN
  Widget sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFF183B3B),
      ),
    );
  }

  // BARIS INFORMASI
  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // LEGENDA DIAGRAM
  Widget legend(Color color, String title, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // DESAIN INPUT
  InputDecoration inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.teal),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.teal,
          width: 1.5,
        ),
      ),
    );
  }

  // CARD
  Widget card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(9, 0, 0, 0),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}