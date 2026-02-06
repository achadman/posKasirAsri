import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../controllers/analytics_controller.dart';
import '../../controllers/admin_controller.dart';
import 'employee_page.dart';
import 'history/history_page.dart';
import 'inventory_page.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminCtrl = Provider.of<AdminController>(context, listen: false);
      Provider.of<AnalyticsController>(
        context,
        listen: false,
      ).init(adminCtrl.storeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.compactCurrency(
      locale: 'id',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    // Separate currency for Revenue card for full detail if needed, or compact for grid
    final fullCurrency = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Analitik Penjualan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<AnalyticsController>().refreshData(),
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: Consumer<AnalyticsController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => controller.refreshData(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGridSummary(controller, isDark, context, fullCurrency),
                  const SizedBox(height: 30),
                  _buildChartSection(controller, fullCurrency, isDark),
                  const SizedBox(height: 30),
                  _buildGrowthIndicators(controller, isDark),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridSummary(
    AnalyticsController controller,
    bool isDark,
    BuildContext context,
    NumberFormat currency,
  ) {
    final storeId = context.read<AdminController>().storeId;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      shrinkWrap: true,
      childAspectRatio: 1.1, // Adjust for card shape
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 1. Employee Count
        _buildGridCard(
          "Total Karyawan",
          "${controller.employeeCount} Orang",
          CupertinoIcons.person_2_fill,
          Colors.blue,
          () {
            if (storeId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeePage(storeId: storeId),
                ),
              );
            }
          },
        ),

        // 2. Transaction Count
        _buildGridCard(
          "Total Transaksi",
          "${controller.totalTransactionCount} Trx",
          CupertinoIcons.doc_text_fill,
          Colors.orange,
          () {
            if (storeId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryPage(storeId: storeId),
                ),
              );
            }
          },
        ),

        // 3. Revenue (All Time)
        _buildGridCard(
          "Total Revenue",
          currency.format(
            controller.totalSales,
          ), // Use totalsales for all time logic if applicable, otherwise use specific all time fetch
          CupertinoIcons.money_dollar_circle_fill,
          Colors.green,
          null, // Not clickable
        ),

        // 4. Products/Stock
        _buildGridCard(
          "Total Produk",
          "${controller.totalProductCount} Item",
          CupertinoIcons.cube_box_fill,
          Colors.purple,
          () {
            if (storeId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InventoryPage(storeId: storeId),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildGridCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    final isClickable = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ],
              ),
              if (isClickable)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    CupertinoIcons.arrow_right,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(
    AnalyticsController controller,
    NumberFormat currency,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRangeFilters(controller, isDark),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Pemasukan (Revenue)",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Icon(
                CupertinoIcons.chart_bar_alt_fill,
                color: Colors.blue,
                size: 20,
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 220,
              width: (controller.chartData.length * 60.0).clamp(
                MediaQuery.of(context).size.width - 80,
                3000,
              ),
              child: Stack(
                children: [
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (controller.chartData.isEmpty
                          ? 1000
                          : controller.chartData
                                    .map((e) => e['amount'] as double)
                                    .reduce((a, b) => a > b ? a : b) *
                                1.3),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.blueAccent,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              currency.format(rod.toY),
                              GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < controller.chartData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    controller.chartData[value
                                        .toInt()]['label'],
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(controller.chartData.length, (
                        i,
                      ) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: controller.chartData[i]['amount'],
                              color: Colors.blue.withValues(alpha: 0.7),
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: controller.chartData.isEmpty
                                    ? 0
                                    : controller.chartData
                                              .map((e) => e['amount'] as double)
                                              .reduce((a, b) => a > b ? a : b) *
                                          1.3,
                                color: Colors.blue.withValues(alpha: 0.05),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  LineChart(
                    LineChartData(
                      maxY: (controller.chartData.isEmpty
                          ? 1000
                          : controller.chartData
                                    .map((e) => e['amount'] as double)
                                    .reduce((a, b) => a > b ? a : b) *
                                1.3),
                      lineTouchData: const LineTouchData(enabled: false),
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(controller.chartData.length, (
                            i,
                          ) {
                            return FlSpot(
                              i.toDouble(),
                              controller.chartData[i]['amount'] as double,
                            );
                          }),
                          isCurved: true,
                          color: Colors.orange,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: Colors.orange,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.withValues(alpha: 0.2),
                                Colors.orange.withValues(alpha: 0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildRangeFilters(AnalyticsController controller, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFilterBtn(controller, ChartRange.today, "Hari Ini"),
        _buildFilterBtn(controller, ChartRange.week, "Minggu"),
        _buildFilterBtn(controller, ChartRange.month, "Bulan"),
      ],
    );
  }

  Widget _buildFilterBtn(
    AnalyticsController controller,
    ChartRange range,
    String label,
  ) {
    final isSelected = controller.selectedRange == range;
    return GestureDetector(
      onTap: () => controller.setRange(range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildGrowthIndicators(AnalyticsController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Performa Bisnis",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 15),
        _buildGrowthRow("Mingguan", controller.weeklyGrowth, isDark),
        const SizedBox(height: 12),
        _buildGrowthRow("Bulanan", controller.monthlyGrowth, isDark),
      ],
    );
  }

  Widget _buildGrowthRow(String label, double growth, bool isDark) {
    final isPositive = growth >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.green : Colors.red).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPositive
                  ? CupertinoIcons.graph_circle_fill
                  : CupertinoIcons.graph_circle,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                Text(
                  isPositive ? "Pertumbuhan Bisnis" : "Penurunan Performa",
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            "${isPositive ? '+' : ''}${growth.toStringAsFixed(1)}%",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
