import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../features/predios/providers/predios_provider.dart';
import '../../../features/predios/models/predio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'package:intl/intl.dart';

class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  static const _proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];
  static const _sparkMonths = 6;

  String _proyectoActual = 'TQI';

  String _predioProyecto(Predio predio) {
    final proyectoDirecto = predio.proyecto?.trim().toUpperCase();
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predio.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TQM') || compact.startsWith('QM')) return 'TQM';

    final contenido = [
      predio.claveCatastral,
      predio.ejido ?? '',
      predio.poligonoDwg ?? '',
      predio.oficio ?? '',
      predio.copFirmado ?? '',
    ].join(' ').toUpperCase();

    for (final proyecto in _proyectos) {
      if (contenido.contains(proyecto)) return proyecto;
    }

    return 'Sin proyecto';
  }

  Map<String, int> _groupCountBy<T>(Iterable<Predio> predios, T Function(Predio) selector) {
    final result = <String, int>{};
    for (final predio in predios) {
      final key = selector(predio).toString();
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  DateTime _monthKey(DateTime date) => DateTime(date.year, date.month);

  bool _hasPdfDocumento(Predio predio) {
    final pdf = (predio.pdfUrl ?? predio.copFirmado ?? '').trim();
    return pdf.isNotEmpty;
  }

  List<double> _monthlySeries({
    required List<Predio> predios,
    required DateTime? Function(Predio) dateSelector,
    required double Function(Predio) valueSelector,
  }) {
    final now = DateTime.now();
    final months = List.generate(
      _sparkMonths,
      (i) => DateTime(now.year, now.month - (_sparkMonths - 1 - i)),
    );
    final monthValues = <DateTime, double>{
      for (final month in months) _monthKey(month): 0,
    };

    for (final predio in predios) {
      final date = dateSelector(predio);
      if (date == null) continue;
      final key = _monthKey(date);
      if (!monthValues.containsKey(key)) continue;
      monthValues[key] = (monthValues[key] ?? 0) + valueSelector(predio);
    }

    return months.map((month) => monthValues[_monthKey(month)] ?? 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prediosAsync = ref.watch(prediosMapaProvider);
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final fmtInt = NumberFormat('#,##0', 'es_MX');

    return AppScaffold(
      currentIndex: 2,
      title: 'Balance  •  $_proyectoActual',
      child: prediosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(e.toString()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(prediosMapaProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (predios) {
          final proyectoPredios = predios
              .where((predio) => _predioProyecto(predio) == _proyectoActual)
              .toList();
          final total = proyectoPredios.length;
          final porTipo = _groupCountBy(proyectoPredios, (predio) => predio.tipoPropiedad);
          final porTramo = _groupCountBy(proyectoPredios, (predio) => predio.tramo);
          final m2Total = proyectoPredios.fold<double>(0, (sum, predio) => sum + (predio.superficie ?? 0));
          final copFirmados = proyectoPredios.where(_hasPdfDocumento).length;
          final kmEfectivosTotal = proyectoPredios.fold<double>(0, (sum, predio) => sum + (predio.kmEfectivos ?? 0));
            final lddvLiberado = proyectoPredios.where(_hasPdfDocumento).length.toDouble();
            final lddvPendiente = (total - lddvLiberado.toInt()).clamp(0, total).toDouble();

          final totalPrediosSeries = _monthlySeries(
            predios: proyectoPredios,
            dateSelector: (p) => p.createdAt,
            valueSelector: (_) => 1,
          );
          final copFirmadosSeries = _monthlySeries(
            predios: proyectoPredios.where(_hasPdfDocumento).toList(),
            dateSelector: (p) => p.copFecha ?? p.updatedAt ?? p.createdAt,
            valueSelector: (_) => 1,
          );
          final kmEfectivosSeries = _monthlySeries(
            predios: proyectoPredios,
            dateSelector: (p) => p.createdAt,
            valueSelector: (p) => p.kmEfectivos ?? 0,
          );
          final pendienteCopSeries = _monthlySeries(
            predios: proyectoPredios.where((p) => !_hasPdfDocumento(p)).toList(),
            dateSelector: (p) => p.updatedAt ?? p.createdAt,
            valueSelector: (_) => 1,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Proyecto:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                      ),
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDCDCDC)),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: DropdownButton<String>(
                            value: _proyectoActual,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9A9A9A)),
                            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                            items: _proyectos
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _proyectoActual = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Paneles de contexto KPI (banner compacto)
                SizedBox(
                  height: 124,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildKpiPanel(
                        label: 'Total Predios',
                        value: fmtInt.format(total),
                        color: AppColors.primary,
                        icon: Icons.terrain_outlined,
                        sparkValues: totalPrediosSeries,
                      ),
                      _buildKpiPanel(
                        label: 'COP Firmados',
                        value: fmtInt.format(copFirmados),
                        color: AppColors.secondary,
                        icon: Icons.check_circle_outline,
                        sparkValues: copFirmadosSeries,
                      ),
                      _buildKpiPanel(
                        label: 'Km Efectivos',
                        value: fmt.format(kmEfectivosTotal),
                        color: AppColors.info,
                        icon: Icons.route_outlined,
                        sparkValues: kmEfectivosSeries,
                      ),
                      _buildKpiPanel(
                        label: 'Pendiente COP',
                        value: fmtInt.format((total - copFirmados).clamp(0, total)),
                        color: AppColors.warning,
                        icon: Icons.pending_outlined,
                        sparkValues: pendienteCopSeries,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text('AVANCE LDDV', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _buildDdvStackedBar(
                  context: context,
                  totalPredios: total.toDouble(),
                  liberado: lddvLiberado,
                  pendiente: lddvPendiente,
                ),
                const SizedBox(height: 4),
                Text(
                  'Predios liberados por PDF en $_proyectoActual: ${fmtInt.format(lddvLiberado.toInt())} de ${fmtInt.format(total)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 28),
                Text('Por Tipo de Propiedad', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),

                if (porTipo.isEmpty)
                  const Text('Sin datos para este proyecto', style: TextStyle(color: AppColors.textSecondary))
                else ...[
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSectionsTipo(porTipo, total),
                        centerSpaceRadius: 50,
                        sectionsSpace: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...porTipo.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.tipoPropiedadColor(e.key),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                        Text('${fmtInt.format(e.value)} predios',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${(total > 0 ? e.value / total * 100 : 0).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.tipoPropiedadColor(e.key),
                                fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],

                if (porTramo.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Por Tramo', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (porTramo.values.reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (v, _) => Text(fmtInt.format(v.toInt()), style: const TextStyle(fontSize: 9)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                final keys = porTramo.keys.toList();
                                final idx = v.toInt();
                                if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                                final label = keys[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    label.length > 10 ? label.substring(0, 10) : label,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: true),
                        barGroups: porTramo.entries.toList().asMap().entries.map((e) {
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.value.toDouble(),
                                color: AppColors.primary,
                                width: 22,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDdvStackedBar({
    required BuildContext context,
    required double totalPredios,
    required double liberado,
    required double pendiente,
  }) {
    final total = totalPredios <= 0 ? 1.0 : totalPredios;
    final pctLiber = (liberado / total).clamp(0.0, 1.0).toDouble();
    final pctPend = (pendiente / total).clamp(0.0, 1.0).toDouble();
    final fmt = NumberFormat('#,##0', 'es_MX');

    final segmentWidgets = <Widget>[];
    if (pctLiber > 0) {
      segmentWidgets.add(
        Expanded(
          flex: (pctLiber * 1000).round().clamp(1, 1000),
          child: Container(height: 24, color: AppColors.secondary),
        ),
      );
    }
    if (pctPend > 0) {
      segmentWidgets.add(
        Expanded(
          flex: (pctPend * 1000).round().clamp(1, 1000),
          child: Container(height: 24, color: AppColors.danger),
        ),
      );
    }
    if (segmentWidgets.isEmpty) {
      segmentWidgets.add(
        Expanded(
          child: Container(height: 24, color: Colors.grey.shade300),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '100% Predios del proyecto',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                '${fmt.format(totalPredios)} predios',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(children: segmentWidgets),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: <Widget>[
              _ddvLegend('Liberado', AppColors.secondary, liberado, pctLiber),
              _ddvLegend('Pendiente', AppColors.danger, pendiente, pctPend),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ddvLegend(String label, Color color, double value, double pct) {
    final fmt = NumberFormat('#,##0', 'es_MX');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label  ${fmt.format(value)} predios (${(pct * 100).toStringAsFixed(1)}%)',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSectionsTipo(Map<String, int> porTipo, int total) {
    return porTipo.entries.map((e) {
      final pct = total > 0 ? e.value / total * 100 : 0.0;
      return PieChartSectionData(
        color: AppColors.tipoPropiedadColor(e.key),
        value: e.value.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        radius: 80,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      );
    }).toList();
  }

  Widget _buildKpiPanel({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required List<double> sparkValues,
  }) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.28,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 44,
                    child: _buildSparkline(sparkValues, color),
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF707780),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSparkline(List<double> values, Color color) {
    final safeValues = values.isEmpty ? [0.0, 0.0] : values;
    final maxY = safeValues.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (safeValues.length - 1).toDouble(),
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.1,
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: safeValues
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}
