import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/providers/auth_provider.dart';
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
  bool _avanceTipoPorSegmento = false;
  String _segmentoTipoActual = '';

  String _predioProyecto(Predio predio) {
    final proyectoDirecto = predio.proyecto?.trim().toUpperCase();
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predio.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') ||
        compact.startsWith('SNL') ||
        compact.startsWith('SL'))
      return 'TSNL';
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

  Map<String, int> _groupCountBy<T>(
    Iterable<Predio> predios,
    T Function(Predio) selector,
  ) {
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
    final proyectoSesion = ref.watch(proyectoActivoProvider);
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
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.danger,
              ),
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
          final proyectoActual = _resolveProyectoActual(
            predios: predios,
            proyectoSesion: proyectoSesion,
          );
          if (proyectoActual != _proyectoActual) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _proyectoActual = proyectoActual);
            });
          }

          final proyectoPredios = predios
              .where((predio) => _predioProyecto(predio) == proyectoActual)
              .toList();
          final total = proyectoPredios.length;
          final liberados = proyectoPredios
              .where(_isLiberado)
              .toList(growable: false);
          final noLiberados = proyectoPredios
              .where((p) => !_isLiberado(p))
              .toList(growable: false);

          final kmLiberados = liberados.fold<double>(
            0,
            (sum, predio) => sum + (predio.kmEfectivos ?? 0),
          );
          final kmNoLiberados = noLiberados.fold<double>(
            0,
            (sum, predio) => sum + (predio.kmEfectivos ?? 0),
          );

          final porSegmento = <String, List<Predio>>{};
          for (final predio in proyectoPredios) {
            final key = predio.tramo.trim().isEmpty
                ? 'SIN TRAMO'
                : predio.tramo.trim();
            porSegmento.putIfAbsent(key, () => <Predio>[]).add(predio);
          }
          final segmentos = porSegmento.keys.toList()
            ..sort((a, b) => a.compareTo(b));

          var segmentoTipoActual = _segmentoTipoActual;
          if (segmentoTipoActual.isNotEmpty &&
              !segmentos.contains(segmentoTipoActual)) {
            segmentoTipoActual = '';
          }
          if (segmentoTipoActual != _segmentoTipoActual) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _segmentoTipoActual = segmentoTipoActual);
            });
          }

          final baseTipoPredios = _avanceTipoPorSegmento
              ? (segmentoTipoActual.isNotEmpty
                    ? (porSegmento[segmentoTipoActual] ?? const <Predio>[])
                    : const <Predio>[])
              : proyectoPredios;

          final privadas = baseTipoPredios
              .where((p) => _isPrivada(p.tipoPropiedad))
              .toList(growable: false);
          final socialDominio = baseTipoPredios
              .where((p) => _isSocialODominio(p.tipoPropiedad))
              .toList(growable: false);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Proyecto:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDCDCDC)),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: DropdownButton<String>(
                            value: _proyectoActual,
                            isDense: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF9A9A9A),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            items: _proyectos
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null)
                                setState(() => _proyectoActual = v);
                            },
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => context.push('/reportes/reporte'),
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Reporte'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Avance general',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 980;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildQuantCard(
                                  title: 'Total de predios del proyecto',
                                  value: fmtInt.format(total),
                                  subtitle: 'Cuadro de cuantificación',
                                  icon: Icons.domain,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 12),
                                _buildPrediosAvanceBar(
                                  total: total,
                                  liberados: liberados.length,
                                  noLiberados: noLiberados.length,
                                  fmtInt: fmtInt,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDonutCard(
                              title: 'Avance de km registrados',
                              centerLabel: 'KM',
                              primaryLabel: 'Liberados',
                              primaryValue: kmLiberados,
                              secondaryLabel: 'No liberados',
                              secondaryValue: kmNoLiberados,
                              valueFormat: (v) => fmt.format(v),
                              primaryColor: AppColors.secondary,
                              secondaryColor: AppColors.danger,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildQuantCard(
                          title: 'Total de predios del proyecto',
                          value: fmtInt.format(total),
                          subtitle: 'Cuadro de cuantificación',
                          icon: Icons.domain,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildPrediosAvanceBar(
                          total: total,
                          liberados: liberados.length,
                          noLiberados: noLiberados.length,
                          fmtInt: fmtInt,
                        ),
                        const SizedBox(height: 12),
                        _buildDonutCard(
                          title: 'Avance de km registrados',
                          centerLabel: 'KM',
                          primaryLabel: 'Liberados',
                          primaryValue: kmLiberados,
                          secondaryLabel: 'No liberados',
                          secondaryValue: kmNoLiberados,
                          valueFormat: (v) => fmt.format(v),
                          primaryColor: AppColors.secondary,
                          secondaryColor: AppColors.danger,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),
                Text(
                  'Avance por tipo de propiedad',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildTipoViewControls(segmentos: segmentos),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 980;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTipoPanel(
                              title: 'Propiedad privada',
                              predios: privadas,
                              fmtInt: fmtInt,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTipoPanel(
                              title: 'Propiedad social y dominio pleno',
                              predios: socialDominio,
                              fmtInt: fmtInt,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildTipoPanel(
                          title: 'Propiedad privada',
                          predios: privadas,
                          fmtInt: fmtInt,
                        ),
                        const SizedBox(height: 12),
                        _buildTipoPanel(
                          title: 'Propiedad social y dominio pleno',
                          predios: socialDominio,
                          fmtInt: fmtInt,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),
                Text(
                  'Avance por segmentos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildSegmentosBarChart(
                  segmentos: segmentos,
                  porSegmento: porSegmento,
                  fmtInt: fmtInt,
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  String _resolveProyectoActual({
    required List<Predio> predios,
    required String? proyectoSesion,
  }) {
    final conteo = <String, int>{
      for (final proyecto in _proyectos) proyecto: 0,
    };
    for (final predio in predios) {
      final proyecto = _predioProyecto(predio);
      if (conteo.containsKey(proyecto)) {
        conteo[proyecto] = (conteo[proyecto] ?? 0) + 1;
      }
    }

    if ((conteo[_proyectoActual] ?? 0) > 0) return _proyectoActual;

    if (proyectoSesion != null && (conteo[proyectoSesion] ?? 0) > 0) {
      return proyectoSesion;
    }

    String? mejorProyecto;
    var mayorConteo = 0;
    for (final entry in conteo.entries) {
      if (entry.value > mayorConteo) {
        mayorConteo = entry.value;
        mejorProyecto = entry.key;
      }
    }
    if (mejorProyecto != null && mayorConteo > 0) return mejorProyecto;
    if (proyectoSesion != null && _proyectos.contains(proyectoSesion)) {
      return proyectoSesion;
    }
    return _proyectos.first;
  }

  bool _isLiberado(Predio predio) {
    final estatus = predio.estatusGestion.trim().toUpperCase();
    final byEstatus =
        estatus.contains('LIBERADO') && !estatus.contains('NO LIBERADO');
    return predio.cop || _hasPdfDocumento(predio) || byEstatus;
  }

  bool _isPrivada(String tipo) {
    final token = tipo.trim().toUpperCase();
    return token.contains('PRIVADA');
  }

  bool _isSocialODominio(String tipo) {
    final token = tipo.trim().toUpperCase();
    return token.contains('SOCIAL') || token.contains('DOMINIO');
  }

  Widget _buildTipoViewControls({required List<String> segmentos}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('General (todo el proyecto)'),
          selected: !_avanceTipoPorSegmento,
          onSelected: (selected) {
            if (!selected) return;
            setState(() => _avanceTipoPorSegmento = false);
          },
        ),
        ChoiceChip(
          label: const Text('Por segmento'),
          selected: _avanceTipoPorSegmento,
          onSelected: (selected) {
            if (!selected) return;
            setState(() {
              _avanceTipoPorSegmento = true;
              if (_segmentoTipoActual.isEmpty && segmentos.isNotEmpty) {
                _segmentoTipoActual = segmentos.first;
              }
            });
          },
        ),
        if (_avanceTipoPorSegmento)
          _buildSegmentoTipoDropdown(segmentos: segmentos),
      ],
    );
  }

  Widget _buildSegmentoTipoDropdown({required List<String> segmentos}) {
    if (segmentos.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Sin segmentos disponibles',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    final selected = segmentos.contains(_segmentoTipoActual)
        ? _segmentoTipoActual
        : segmentos.first;

    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: segmentos
              .map(
                (segmento) => DropdownMenuItem<String>(
                  value: segmento,
                  child: Text(segmento, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _segmentoTipoActual = value);
          },
        ),
      ),
    );
  }

  Widget _buildQuantCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
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
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrediosAvanceBar({
    required int total,
    required int liberados,
    required int noLiberados,
    required NumberFormat fmtInt,
  }) {
    final safeTotal = total <= 0 ? 1 : total;
    final pctLiberados = (liberados / safeTotal).clamp(0.0, 1.0);
    final pctNoLiberados = (noLiberados / safeTotal).clamp(0.0, 1.0);

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
          const Text(
            'Predios liberados y no liberados',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (pctLiberados > 0)
                  Expanded(
                    flex: (pctLiberados * 1000).round().clamp(1, 1000),
                    child: Container(height: 24, color: AppColors.secondary),
                  ),
                if (pctNoLiberados > 0)
                  Expanded(
                    flex: (pctNoLiberados * 1000).round().clamp(1, 1000),
                    child: Container(height: 24, color: AppColors.danger),
                  ),
                if (total == 0)
                  Expanded(
                    child: Container(height: 24, color: Colors.grey.shade300),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Liberados: ${fmtInt.format(liberados)} (${(pctLiberados * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'No liberados: ${fmtInt.format(noLiberados)} (${(pctNoLiberados * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutCard({
    required String title,
    required String centerLabel,
    required String primaryLabel,
    required double primaryValue,
    required String secondaryLabel,
    required double secondaryValue,
    required String Function(double value) valueFormat,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final total = primaryValue + secondaryValue;
    final safePrimary = primaryValue <= 0 ? 0.0001 : primaryValue;
    final safeSecondary = secondaryValue <= 0 ? 0.0001 : secondaryValue;

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
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 44,
                    sections: [
                      PieChartSectionData(
                        value: safePrimary,
                        color: primaryColor,
                        radius: 52,
                        title: '',
                      ),
                      PieChartSectionData(
                        value: safeSecondary,
                        color: secondaryColor,
                        radius: 52,
                        title: '',
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      valueFormat(total),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _legendLine(
            primaryLabel,
            primaryValue,
            total,
            primaryColor,
            valueFormat,
          ),
          const SizedBox(height: 4),
          _legendLine(
            secondaryLabel,
            secondaryValue,
            total,
            secondaryColor,
            valueFormat,
          ),
        ],
      ),
    );
  }

  Widget _legendLine(
    String label,
    double value,
    double total,
    Color color,
    String Function(double value) valueFormat,
  ) {
    final pct = total <= 0 ? 0.0 : (value / total) * 100;
    return Row(
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
        Expanded(
          child: Text(
            '$label: ${valueFormat(value)} (${pct.toStringAsFixed(1)}%)',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipoPanel({
    required String title,
    required List<Predio> predios,
    required NumberFormat fmtInt,
  }) {
    final total = predios.length;
    final identificacion = predios.where((p) => p.identificacion).length;
    final levantamiento = predios.where((p) => p.levantamiento).length;
    final negociacion = predios.where((p) => p.negociacion).length;
    final liberados = predios.where(_isLiberado).length;

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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _buildQuantCard(
            title: 'Total de propiedades',
            value: fmtInt.format(total),
            subtitle: 'Cuantificación del bloque',
            icon: Icons.home_work_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final cards = [
                _buildDonutCard(
                  title: 'Predios con identificación',
                  centerLabel: 'ID',
                  primaryLabel: 'Con identificación',
                  primaryValue: identificacion.toDouble(),
                  secondaryLabel: 'Sin identificación',
                  secondaryValue: (total - identificacion).toDouble(),
                  valueFormat: (v) => fmtInt.format(v),
                  primaryColor: AppColors.info,
                  secondaryColor: const Color(0xFFE6E8EB),
                ),
                _buildDonutCard(
                  title: 'Predios con levantamiento',
                  centerLabel: 'LEV',
                  primaryLabel: 'Con levantamiento',
                  primaryValue: levantamiento.toDouble(),
                  secondaryLabel: 'Sin levantamiento',
                  secondaryValue: (total - levantamiento).toDouble(),
                  valueFormat: (v) => fmtInt.format(v),
                  primaryColor: AppColors.primary,
                  secondaryColor: const Color(0xFFE6E8EB),
                ),
                _buildDonutCard(
                  title: 'Predios con negociación',
                  centerLabel: 'NEG',
                  primaryLabel: 'Con negociación',
                  primaryValue: negociacion.toDouble(),
                  secondaryLabel: 'Sin negociación',
                  secondaryValue: (total - negociacion).toDouble(),
                  valueFormat: (v) => fmtInt.format(v),
                  primaryColor: AppColors.warning,
                  secondaryColor: const Color(0xFFE6E8EB),
                ),
                _buildDonutCard(
                  title: 'Liberados',
                  centerLabel: 'LIB',
                  primaryLabel: 'Liberados',
                  primaryValue: liberados.toDouble(),
                  secondaryLabel: 'No liberados',
                  secondaryValue: (total - liberados).toDouble(),
                  valueFormat: (v) => fmtInt.format(v),
                  primaryColor: AppColors.secondary,
                  secondaryColor: const Color(0xFFE6E8EB),
                ),
              ];

              if (wide) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[1]),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: cards[2]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[3]),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i != cards.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentosBarChart({
    required List<String> segmentos,
    required Map<String, List<Predio>> porSegmento,
    required NumberFormat fmtInt,
  }) {
    if (segmentos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Sin datos de segmentos para el proyecto seleccionado.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final maxY = segmentos.fold<double>(0, (max, segmento) {
      final rows = porSegmento[segmento] ?? const <Predio>[];
      final liberados = rows.where(_isLiberado).length.toDouble();
      final noLiberados = rows.where((p) => !_isLiberado(p)).length.toDouble();
      final negociacion = rows.where((p) => p.negociacion).length.toDouble();
      final localMax = [
        liberados,
        noLiberados,
        negociacion,
      ].reduce((a, b) => a > b ? a : b);
      return localMax > max ? localMax : max;
    });

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
          const Text(
            'Liberados, no liberados y negociación por segmento',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxY <= 0 ? 1 : maxY * 1.25),
                groupsSpace: 16,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (v, _) => Text(
                        fmtInt.format(v.toInt()),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= segmentos.length) {
                          return const SizedBox.shrink();
                        }
                        final label = segmentos[idx];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label.length > 10 ? label.substring(0, 10) : label,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxY <= 0
                      ? 1
                      : (maxY / 5).clamp(1, double.infinity),
                ),
                barGroups: segmentos.asMap().entries.map((entry) {
                  final rows = porSegmento[entry.value] ?? const <Predio>[];
                  final liberados = rows.where(_isLiberado).length.toDouble();
                  final noLiberados = rows
                      .where((p) => !_isLiberado(p))
                      .length
                      .toDouble();
                  final negociacion = rows
                      .where((p) => p.negociacion)
                      .length
                      .toDouble();
                  return BarChartGroupData(
                    x: entry.key,
                    barsSpace: 5,
                    barRods: [
                      BarChartRodData(
                        toY: liberados,
                        width: 10,
                        color: AppColors.secondary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: noLiberados,
                        width: 10,
                        color: AppColors.danger,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: negociacion,
                        width: 10,
                        color: AppColors.warning,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: const [
              _LegendBadge(label: 'Liberados', color: AppColors.secondary),
              _LegendBadge(label: 'No liberados', color: AppColors.danger),
              _LegendBadge(label: 'Negociación', color: AppColors.warning),
            ],
          ),
        ],
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
        Expanded(child: Container(height: 24, color: Colors.grey.shade300)),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
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

  List<PieChartSectionData> _buildPieSectionsTipo(
    Map<String, int> porTipo,
    int total,
  ) {
    return porTipo.entries.map((e) {
      final pct = total > 0 ? e.value / total * 100 : 0.0;
      return PieChartSectionData(
        color: AppColors.tipoPropiedadColor(e.key),
        value: e.value.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        radius: 80,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.05),
          ],
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
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
