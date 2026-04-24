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

  String _proyectoActual = 'TQI';

  String _predioProyecto(Predio predio) {
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

    return 'TQI';
  }

  int _conteoProyecto(List<Predio> predios, String proyecto) {
    return predios.where((predio) => _predioProyecto(predio) == proyecto).length;
  }

  Map<String, int> _groupCountBy<T>(Iterable<Predio> predios, T Function(Predio) selector) {
    final result = <String, int>{};
    for (final predio in predios) {
      final key = selector(predio).toString();
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
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
          final copFirmados = proyectoPredios.where((predio) => predio.cop).length;
          final ddvNecesario = m2Total;
          final ddvAcreditado = proyectoPredios
              .where((predio) =>
                  predio.identificacion || predio.levantamiento || predio.negociacion || predio.cop)
              .fold<double>(0, (sum, predio) => sum + (predio.superficie ?? 0));
          final ddvLiberado = proyectoPredios
              .where((predio) => predio.cop)
              .fold<double>(0, (sum, predio) => sum + (predio.superficie ?? 0));
          final ddvPendiente = (ddvNecesario - ddvLiberado).clamp(0.0, double.infinity);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
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
                const SizedBox(height: 12),
                // KPIs principales
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _buildKpiCard(context, 'Total Predios', fmtInt.format(total),
                        Icons.terrain, AppColors.primary),
                    _buildKpiCard(context, 'COP Firmados', fmtInt.format(copFirmados),
                        Icons.check_circle_outline, AppColors.secondary),
                    _buildKpiCard(context, 'M² DDV Total', '${fmtInt.format(m2Total)} m²',
                        Icons.square_foot, AppColors.info),
                    _buildKpiCard(
                      context,
                      'Pendiente COP',
                      fmtInt.format((total - copFirmados).clamp(0, total)),
                      Icons.pending_outlined,
                      AppColors.warning,
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                Text('Cuantificación DDV', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _buildDdvBar(context, 'DDV Necesario', ddvNecesario, ddvNecesario, AppColors.primary),
                const SizedBox(height: 8),
                _buildDdvBar(context, 'DDV Acreditado', ddvAcreditado, ddvNecesario, AppColors.info),
                const SizedBox(height: 8),
                _buildDdvBar(context, 'DDV Liberado', ddvLiberado, ddvNecesario, AppColors.secondary),
                const SizedBox(height: 8),
                _buildDdvBar(context, 'DDV Pendiente', ddvPendiente, ddvNecesario, AppColors.danger),
                const SizedBox(height: 4),
                Text(
                  'Total DDV Necesario en $_proyectoActual: ${fmt.format(ddvNecesario)} m²',
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

  Widget _buildDdvBar(BuildContext context, String label, double value, double max, Color color) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final fmt = NumberFormat('#,##0', 'es_MX');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text('${fmt.format(value)} m²  (${(pct * 100).toStringAsFixed(1)}%)',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            color: color,
            minHeight: 10,
          ),
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

  Widget _buildKpiCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
