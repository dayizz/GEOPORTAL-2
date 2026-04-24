import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/demo_provider.dart';
import '../../auth/providers/demo_data.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../predios/data/predios_repository.dart';
import '../../predios/models/predio.dart';
import '../../predios/providers/demo_predios_notifier.dart';
import '../../predios/providers/predios_provider.dart';

class TablaScreen extends ConsumerStatefulWidget {
  const TablaScreen({super.key});

  @override
  ConsumerState<TablaScreen> createState() => _TablaScreenState();
}

class _TablaScreenState extends ConsumerState<TablaScreen> {
  static const _proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];

  final _searchCtrl = TextEditingController();
  final _verticalScroll = ScrollController();

  String _proyectoActual = 'TQI';
  String _busqueda = '';
  String? _filtroTramo;
  String? _filtroTipo;
  String? _filtroCop; // 'SI' | 'NO' | null

  final _nf = NumberFormat('#,##0.00');
  final _nf4 = NumberFormat('0.0000');

  @override
  void dispose() {
    _searchCtrl.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  List<Predio> _applyFilters(List<Predio> all) {
    return all.where((p) {
      if (_predioProyecto(p) != _proyectoActual) return false;
      if (_filtroTramo != null && p.tramo != _filtroTramo) return false;
      if (_filtroTipo != null && p.tipoPropiedad != _filtroTipo) return false;
      if (_filtroCop != null) {
        final want = _filtroCop == 'SI';
        if (p.cop != want) return false;
      }
      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        return p.claveCatastral.toLowerCase().contains(q) ||
            (p.propietarioNombre?.toLowerCase().contains(q) ?? false) ||
            (p.ejido?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  String _predioProyecto(Predio predio) {
    final proyectoDirecto = predio.proyecto?.trim().toUpperCase();
    if (proyectoDirecto != null && proyectoDirecto.isNotEmpty) {
      return proyectoDirecto;
    }

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

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(demoModeProvider);
    final demoPrediosList = ref.watch(demoPrediosNotifierProvider);
    final supabasePredios = isDemo
        ? demoPrediosList
        : ref.watch(prediosListProvider).maybeWhen(
              data: (d) => d,
              orElse: () => <Predio>[],
            );
    // Siempre usa datos demo si Supabase no devuelve nada
    final allPredios = supabasePredios.isNotEmpty ? supabasePredios : demoPrediosList;
    final filtered = _applyFilters(allPredios);
    final activeFilters =
        (_filtroTramo != null ? 1 : 0) + (_filtroTipo != null ? 1 : 0) + (_filtroCop != null ? 1 : 0);

    return AppScaffold(
      currentIndex: 4,
      title: 'Gestion  •  $_proyectoActual  •  ${filtered.length} predios',
      actions: [
        if (activeFilters > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              label: Text('$activeFilters'),
              child: IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Limpiar filtros',
                onPressed: () => setState(() {
                  _filtroTramo = null;
                  _filtroTipo = null;
                  _filtroCop = null;
                }),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtros',
            onPressed: () => _showFiltros(context),
          ),
        IconButton(
          icon: const Icon(Icons.tune_outlined),
          tooltip: 'Filtros avanzados',
          onPressed: () => _showFiltros(context),
        ),
      ],
      child: Column(
        children: [
          _buildTopBar(filtered.length, allPredios),
          const Divider(height: 1),
          Expanded(
            child: _buildTable(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(int visible, List<Predio> allPredios) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _proyectos
                    .map(
                      (proyecto) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$proyecto (${_conteoProyecto(allPredios, proyecto)})'),
                          selected: _proyectoActual == proyecto,
                          onSelected: (_) => setState(() => _proyectoActual = proyecto),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar propietario, ID SEDATU, ejido…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _busqueda = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text(
                  'Filtros${_filtroTramo != null || _filtroTipo != null || _filtroCop != null ? ' ✓' : ''}',
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => _showFiltros(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$visible de ${_conteoProyecto(allPredios, _proyectoActual)} predios en $_proyectoActual',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          if (_filtroTramo != null || _filtroTipo != null || _filtroCop != null) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_filtroTramo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('Tramo: $_filtroTramo'),
                        onDeleted: () => setState(() => _filtroTramo = null),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (_filtroTipo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(_filtroTipo!),
                        onDeleted: () => setState(() => _filtroTipo = null),
                        backgroundColor: AppColors.tipoPropiedadColor(_filtroTipo!).withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (_filtroCop != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('COP: $_filtroCop'),
                        onDeleted: () => setState(() => _filtroCop = null),
                        backgroundColor: _filtroCop == 'SI'
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : AppColors.danger.withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTable(List<Predio> rows) {
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_rows_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Sin registros para $_proyectoActual', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    const rawWidths = <double>[
       44, // ACCIONES
       40, // VER MAPA
      180, // PROPIETARIO
      110, // ID SEDATU
       50, // TRAMO
       90, // TIPO
      120, // EJIDO
       72, // KM INICIO
       72, // KM FIN
       72, // KM LIN
       72, // KM EF
       80, // M²
       46, // COP
      130, // COP FIRMADO
      130, // OFICIO
       54, // POL. INS
       54, // IDENT.
       54, // LEVANT.
       54, // NEGOC.
    ];

    const headers = <String>[
      '', 'MAPA', 'PROPIETARIO', 'ID SEDATU', 'TRAMO', 'TIPO', 'EJIDO',
      'KM INICIO', 'KM FIN', 'KM LIN', 'KM EF', 'M²',
      'C.O.P', 'COP FIRMADO', 'OFICIO',
      'POL.\nINS.', 'IDENT.', 'LEVANT.', 'NEGOC.',
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final rawTotal = rawWidths.reduce((a, b) => a + b) + rawWidths.length * 1.0;
        final scale = (constraints.maxWidth / rawTotal).clamp(0.7, 1.4);
        final colWidths = rawWidths.map((w) => w * scale).toList();
        final totalWidth = constraints.maxWidth;

        return Scrollbar(
          controller: _verticalScroll,
          thumbVisibility: true,
          child: Column(
            children: [
              // Header fijo
              _buildHeaderRow(headers, colWidths, totalWidth),
              const Divider(height: 1, thickness: 1.5, color: AppColors.border),
              // Filas
              Expanded(
                child: ListView.builder(
                  controller: _verticalScroll,
                  itemCount: rows.length,
                  itemExtent: 38,
                  itemBuilder: (ctx2, idx) => _buildDataRow(rows[idx], colWidths, idx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(List<String> headers, List<double> widths, double total) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.92),
      height: 40,
      child: Row(
        children: List.generate(headers.length, (i) {
          return _headerCell(headers[i], widths[i]);
        }),
      ),
    );
  }

  Widget _headerCell(String label, double width) {
    return Container(
      width: width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _savePredio(Predio updated) {
    final isDemo = ref.read(demoModeProvider);
    final supabasePredios = ref.read(prediosListProvider).maybeWhen(
      data: (d) => d,
      orElse: () => <Predio>[],
    );
    final usingDemo = isDemo || supabasePredios.isEmpty;
    if (usingDemo) {
      ref.read(demoPrediosNotifierProvider.notifier).updatePredio(updated);
    } else {
      ref.read(prediosRepositoryProvider).updatePredio(updated.id, updated.toMap());
      ref.invalidate(prediosListProvider);
    }
  }

  Widget _buildDataRow(Predio p, List<double> widths, int idx) {
    final isEven = idx % 2 == 0;
    final tipoColor = AppColors.tipoPropiedadColor(p.tipoPropiedad);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8F9FA),
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // ACCIONES
          _actionCell(p, widths[0]),
          // VER EN MAPA
          _mapCell(p, widths[1]),
          // PROPIETARIO
          _dataCell(p.propietarioNombre ?? p.claveCatastral, widths[2],
              color: tipoColor.withValues(alpha: 0.08)),
          // ID SEDATU
          _dataCell(p.claveCatastral, widths[3],
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          // TRAMO
          _tramoBadgeCell(p.tramo, widths[4]),
          // TIPO
          _tipoBadgeCell(p.tipoPropiedad, tipoColor, widths[5]),
          // EJIDO
          _dataCell(p.ejido ?? '-', widths[6]),
          // KM INICIO
          _numCell(p.kmInicio, widths[7], decimals: 4),
          // KM FIN
          _numCell(p.kmFin, widths[8], decimals: 4),
          // KM LIN
          _numCell(p.kmLineales, widths[9], decimals: 4),
          // KM EF
          _numCell(p.kmEfectivos, widths[10], decimals: 4),
          // M²
          _numCell(p.superficie, widths[11], decimals: 2),
          // COP (tappable toggle)
          _tappableBoolCell(
            p.cop, widths[12],
            trueColor: AppColors.secondary,
            falseColor: Colors.grey.shade400,
            onTap: () => _savePredio(p.copyWith(cop: !p.cop, updatedAt: DateTime.now())),
          ),
          // COP FIRMADO
          _dataCell(p.copFirmado ?? '-', widths[13]),
          // OFICIO
          _dataCell(p.oficio ?? '-', widths[14]),
          // POLÍGONO INSERTADO (tappable)
          _tappableBoolCell(
            p.poligonoInsertado, widths[15],
            onTap: () => _savePredio(p.copyWith(poligonoInsertado: !p.poligonoInsertado, updatedAt: DateTime.now())),
          ),
          // IDENTIFICACION (tappable)
          _tappableBoolCell(
            p.identificacion, widths[16],
            onTap: () => _savePredio(p.copyWith(identificacion: !p.identificacion, updatedAt: DateTime.now())),
          ),
          // LEVANTAMIENTO (tappable)
          _tappableBoolCell(
            p.levantamiento, widths[17],
            onTap: () => _savePredio(p.copyWith(levantamiento: !p.levantamiento, updatedAt: DateTime.now())),
          ),
          // NEGOCIACION (tappable)
          _tappableBoolCell(
            p.negociacion, widths[18],
            onTap: () => _savePredio(p.copyWith(negociacion: !p.negociacion, updatedAt: DateTime.now())),
          ),
        ],
      ),
    );
  }

  Widget _actionCell(Predio p, double width) {
    return InkWell(
      onTap: () => _showEditSheet(context, p),
      child: Container(
        width: width,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
      ),
    );
  }

  /// Botón "Ver en Mapa": navega al mapa y hace fly-to al predio.
  Widget _mapCell(Predio p, double width) {
    final tieneGeometria = p.geometry != null ||
        (p.latitud != null && p.longitud != null);
    return Tooltip(
      message: tieneGeometria ? 'Ver en mapa' : 'Sin geometría registrada',
      child: InkWell(
        onTap: tieneGeometria
            ? () {
                ref.read(focusPredioIdProvider.notifier).state = p.id;
                context.go('/mapa');
              }
            : null,
        child: Container(
          width: width,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Icon(
            Icons.map_outlined,
            size: 16,
            color: tieneGeometria ? AppColors.secondary : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _dataCell(String text, double width, {TextStyle? style, Color? color}) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        border: const Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Text(
        text,
        style: style ?? const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _numCell(double? value, double width, {int decimals = 2}) {
    final text = value == null
        ? '-'
        : decimals == 4
            ? _nf4.format(value)
            : _nf.format(value);
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tappableBoolCell(bool value, double width,
      {Color? trueColor, Color? falseColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Icon(
          value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: value
              ? (trueColor ?? AppColors.secondary)
              : (falseColor ?? Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _tramoBadgeCell(String tramo, double width) {
    const colors = {
      'T1': Color(0xFF3498DB),
      'T2': Color(0xFF9B59B6),
      'T3': Color(0xFFE67E22),
      'T4': Color(0xFF1ABC9C),
    };
    final c = colors[tramo] ?? Colors.grey;
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          tramo,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
        ),
      ),
    );
  }

  Widget _tipoBadgeCell(String tipo, Color color, double width) {
    final label = tipo == 'DOMINIO PLENO' ? 'D.PLENO' : tipo;
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, Predio p) {
    final propCtrl = TextEditingController(text: p.propietarioNombre ?? '');
    final ejidoCtrl = TextEditingController(text: p.ejido ?? '');
    final m2Ctrl = TextEditingController(text: p.superficie?.toString() ?? '');
    final copFirmadoCtrl = TextEditingController(text: p.copFirmado ?? '');
    final dwgCtrl = TextEditingController(text: p.poligonoDwg ?? '');
    final oficioCtrl = TextEditingController(text: p.oficio ?? '');
    final kmIniCtrl = TextEditingController(text: p.kmInicio?.toString() ?? '');
    final kmFinCtrl = TextEditingController(text: p.kmFin?.toString() ?? '');

    bool cop = p.cop;
    bool ident = p.identificacion;
    bool levant = p.levantamiento;
    bool negoc = p.negociacion;
    bool poli = p.poligonoInsertado;
    String tramo = p.tramo;
    String tipo = p.tipoPropiedad;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void save() {
            final updated = p.copyWith(
              propietarioNombre: propCtrl.text.trim().isEmpty ? null : propCtrl.text.trim(),
              ejido: ejidoCtrl.text.trim().isEmpty ? null : ejidoCtrl.text.trim(),
              tramo: tramo,
              tipoPropiedad: tipo,
              kmInicio: double.tryParse(kmIniCtrl.text),
              kmFin: double.tryParse(kmFinCtrl.text),
              superficie: double.tryParse(m2Ctrl.text),
              cop: cop,
              copFirmado: copFirmadoCtrl.text.trim().isEmpty ? null : copFirmadoCtrl.text.trim(),
              poligonoDwg: dwgCtrl.text.trim().isEmpty ? null : dwgCtrl.text.trim(),
              oficio: oficioCtrl.text.trim().isEmpty ? null : oficioCtrl.text.trim(),
              identificacion: ident,
              levantamiento: levant,
              negociacion: negoc,
              poligonoInsertado: poli,
              updatedAt: DateTime.now(),
            );
            _savePredio(updated);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${p.claveCatastral} actualizado'),
                backgroundColor: AppColors.secondary,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          InputDecoration _dec(String label) => InputDecoration(
                labelText: label,
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              );

          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.tipoPropiedadColor(tipo),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.claveCatastral,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(onPressed: save, child: const Text('Guardar')),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  // Tramo + Tipo
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tramo,
                          decoration: _dec('Tramo'),
                          items: ['T1', 'T2', 'T3', 'T4']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setS(() => tramo = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tipo,
                          decoration: _dec('Tipo'),
                          items: ['SOCIAL', 'DOMINIO PLENO', 'PRIVADA']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setS(() => tipo = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Propietario + Ejido
                  Row(
                    children: [
                      Expanded(child: TextField(controller: propCtrl, decoration: _dec('Propietario'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: ejidoCtrl, decoration: _dec('Ejido'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // KM inicio + fin + M²
                  Row(
                    children: [
                      Expanded(child: TextField(controller: kmIniCtrl, decoration: _dec('KM Inicio'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: kmFinCtrl, decoration: _dec('KM Fin'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: m2Ctrl, decoration: _dec('M²'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Documentos
                  TextField(controller: copFirmadoCtrl, decoration: _dec('COP Firmado (archivo)')),
                  const SizedBox(height: 8),
                  TextField(controller: dwgCtrl, decoration: _dec('Polígono DWG (archivo)')),
                  const SizedBox(height: 8),
                  TextField(controller: oficioCtrl, decoration: _dec('Oficio')),
                  const SizedBox(height: 12),
                  // Etapas
                  Text('Etapas de Avance', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _etapaChip('Identificación', ident, AppColors.primary,
                          (v) => setS(() => ident = v)),
                      _etapaChip('Levantamiento', levant, AppColors.info,
                          (v) => setS(() => levant = v)),
                      _etapaChip('Negociación', negoc, AppColors.warning,
                          (v) => setS(() => negoc = v)),
                      _etapaChip('C.O.P.', cop, AppColors.secondary,
                          (v) => setS(() => cop = v)),
                      _etapaChip('Pol. Insertado', poli, const Color(0xFF8E44AD),
                          (v) => setS(() => poli = v)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar cambios'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: save,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      propCtrl.dispose(); ejidoCtrl.dispose(); m2Ctrl.dispose();
      copFirmadoCtrl.dispose(); dwgCtrl.dispose(); oficioCtrl.dispose();
      kmIniCtrl.dispose(); kmFinCtrl.dispose();
    });
  }

  Widget _etapaChip(String label, bool value, Color color, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: value ? color : AppColors.textSecondary)),
      selected: value,
      onSelected: onChanged,
      selectedColor: color.withValues(alpha: 0.18),
      checkmarkColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showFiltros(BuildContext context) {
    String? tramo = _filtroTramo;
    String? tipo = _filtroTipo;
    String? cop = _filtroCop;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text('Filtros', style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setS(() { tramo = null; tipo = null; cop = null; });
                    },
                    child: const Text('Limpiar todo'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Text('Tramo', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['T1', 'T2', 'T3', 'T4'].map((t) => FilterChip(
                  label: Text(t),
                  selected: tramo == t,
                  onSelected: (v) => setS(() => tramo = v ? t : null),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                )).toList(),
              ),
              const SizedBox(height: 16),
              Text('Tipo de Propiedad', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['SOCIAL', 'DOMINIO PLENO', 'PRIVADA'].map((t) => FilterChip(
                  label: Text(t),
                  selected: tipo == t,
                  onSelected: (v) => setS(() => tipo = v ? t : null),
                  selectedColor: AppColors.tipoPropiedadColor(t).withValues(alpha: 0.2),
                )).toList(),
              ),
              const SizedBox(height: 16),
              Text('C.O.P.', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Con COP'),
                    selected: cop == 'SI',
                    onSelected: (v) => setS(() => cop = v ? 'SI' : null),
                    selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                  FilterChip(
                    label: const Text('Sin COP'),
                    selected: cop == 'NO',
                    onSelected: (v) => setS(() => cop = v ? 'NO' : null),
                    selectedColor: AppColors.danger.withValues(alpha: 0.2),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _filtroTramo = tramo;
                      _filtroTipo = tipo;
                      _filtroCop = cop;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
