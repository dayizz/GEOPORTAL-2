import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../models/proyecto.dart';
import '../providers/proyectos_provider.dart';

class ProyectosScreen extends ConsumerStatefulWidget {
  const ProyectosScreen({super.key});

  @override
  ConsumerState<ProyectosScreen> createState() => _ProyectosScreenState();
}

class _ProyectosScreenState extends ConsumerState<ProyectosScreen> {
  static const _proyectos = ['Sin proyecto', 'TQI', 'TSNL', 'TAP', 'TQM'];

  final _searchCtrl = TextEditingController();
  final _verticalScroll = ScrollController();
  final _horizontalScroll = ScrollController();

  String _proyectoActual = 'TQI';
  String _busqueda = '';
  String? _filtroTipo;

  final _nf = NumberFormat('#,##0.00');
  final _nf4 = NumberFormat('0.0000');

  @override
  void dispose() {
    _searchCtrl.dispose();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  List<Proyecto> _applyFilters(List<Proyecto> all) {
    return all.where((p) {
      if (p.proyecto != _proyectoActual) return false;
      if (_filtroTipo != null && p.tipoPropiedad != _filtroTipo) return false;
      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        return p.propietario.toLowerCase().contains(q) ||
            p.tramo.toLowerCase().contains(q) ||
            (p.estado?.toLowerCase().contains(q) ?? false) ||
            (p.municipio?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  int _conteoProyecto(List<Proyecto> proyectos, String proyecto) {
    return proyectos.where((p) => p.proyecto == proyecto).length;
  }

  @override
  Widget build(BuildContext context) {
    final allProyectos = ref.watch(proyectosProvider);
    final filtered = _applyFilters(allProyectos);
    final activeFilters = (_filtroTipo != null ? 1 : 0);

    return AppScaffold(
      currentIndex: 1,
      title: 'Proyectos Capturados  •  $_proyectoActual  •  ${filtered.length} registros',
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
                  _filtroTipo = null;
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
      ],
      child: Column(
        children: [
          _buildTopBar(filtered.length, allProyectos),
          const Divider(height: 1),
          Expanded(
            child: _buildTable(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(int visible, List<Proyecto> allProyectos) {
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
                          label: Text('$proyecto (${_conteoProyecto(allProyectos, proyecto)})'),
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
                      hintText: 'Buscar propietario, tramo, estado, municipio…',
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
                  'Filtros${_filtroTipo != null ? ' ✓' : ''}',
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
              '$visible de ${_conteoProyecto(allProyectos, _proyectoActual)} registros en $_proyectoActual',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          if (_filtroTipo != null) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTable(List<Proyecto> rows) {
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

    const colWidths = <double>[
      44,   // ACCIONES
      120,  // PROYECTO
      180,  // PROPIETARIO
      80,   // TRAMO
      100,  // TIPO
      90,   // ESTATUS
      90,   // ESTADO
      90,   // MUNICIPIO
      90,   // KM INICIO
      90,   // KM FIN
      90,   // ÁREA (M²)
    ];

    const headers = <String>[
      '', 'PROYECTO', 'PROPIETARIO', 'TRAMO', 'TIPO', 'ESTATUS',
      'ESTADO', 'MUNICIPIO', 'KM INICIO', 'KM FIN', 'ÁREA (M²)',
    ];

    final totalWidth = colWidths.reduce((a, b) => a + b) + colWidths.length * 1.0;

    return Scrollbar(
      controller: _verticalScroll,
      thumbVisibility: true,
      child: Scrollbar(
        controller: _horizontalScroll,
        thumbVisibility: true,
        notificationPredicate: (n) => n.depth == 1,
        child: SingleChildScrollView(
          controller: _horizontalScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                _buildHeaderRow(headers, colWidths, totalWidth),
                const Divider(height: 1, thickness: 1.5, color: AppColors.border),
                Expanded(
                  child: ListView.builder(
                    controller: _verticalScroll,
                    itemCount: rows.length,
                    itemExtent: 38,
                    itemBuilder: (ctx, idx) => _buildDataRow(rows[idx], colWidths, idx),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildDataRow(Proyecto p, List<double> widths, int idx) {
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
          // PROYECTO
          _dataCell(p.proyecto, widths[1], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          // PROPIETARIO
          _dataCell(p.propietario, widths[2], color: tipoColor.withValues(alpha: 0.08)),
          // TRAMO
          _dataCell(p.tramo, widths[3]),
          // TIPO
          _tipoBadgeCell(p.tipoPropiedad, tipoColor, widths[4]),
          // ESTATUS
          _estatusBadgeCell(p.estatusPredio, widths[5]),
          // ESTADO
          _dataCell(p.estado ?? '-', widths[6]),
          // MUNICIPIO
          _dataCell(p.municipio ?? '-', widths[7]),
          // KM INICIO
          _numCell(p.kmInicio, widths[8], decimals: 4),
          // KM FIN
          _numCell(p.kmFin, widths[9], decimals: 4),
          // ÁREA (M²)
          _numCell(p.superficie, widths[10], decimals: 2),
        ],
      ),
    );
  }

  Widget _actionCell(Proyecto p, double width) {
    return Container(
      width: width,
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: 'Eliminar',
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
              onPressed: () => _showDeleteConfirm(p),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(Proyecto proyecto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Estás seguro de que deseas eliminar el registro de ${proyecto.propietario}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(proyectosProvider.notifier).removeProyecto(proyecto.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Registro eliminado')),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
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
        color: Color(0xFFF8F9FA),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _tipoBadgeCell(String tipo, Color color, double width) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: const Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Text(
        tipo.replaceAll('Sin tipo', '—'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _estatusBadgeCell(String? estatus, double width) {
    final statusText = (estatus?.trim().isNotEmpty ?? false)
      ? estatus!.trim()
      : 'Sin estatus';
    final color = statusText == 'Liberado'
        ? AppColors.secondary
      : statusText == 'No liberado'
            ? AppColors.danger
            : Colors.grey;
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: const Border(right: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  void _showFiltros(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filtros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tipo de propiedad:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['SOCIAL', 'PRIVADA', 'Sin tipo'].map((tipo) {
                return FilterChip(
                  label: Text(tipo),
                  selected: _filtroTipo == tipo,
                  onSelected: (selected) {
                    Navigator.pop(ctx);
                    setState(() => _filtroTipo = selected ? tipo : null);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
