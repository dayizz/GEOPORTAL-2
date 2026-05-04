import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/constants/app_colors.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../predios/data/predios_repository.dart';
import '../../predios/models/predio.dart';
import '../../predios/providers/local_predios_provider.dart';
import '../../predios/providers/predios_provider.dart';
import '../../propietarios/providers/local_propietarios_provider.dart';
import '../../propietarios/providers/propietarios_provider.dart';
import '../../../shared/services/backend_service.dart';

class TablaScreen extends ConsumerStatefulWidget {
  const TablaScreen({super.key});

  @override
  ConsumerState<TablaScreen> createState() => _TablaScreenState();
}


class _TablaScreenState extends ConsumerState<TablaScreen> {
  static const _proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];

  final _searchCtrl = TextEditingController();
  final _verticalScroll = ScrollController();
  final Map<String, Predio> _prediosOptimistas = {};
  List<Predio> _ultimosPredios = const [];

  String _proyectoActual = 'TQI';
  String _busqueda = '';
  String? _filtroTramo;
  String? _filtroTipo;
  String? _filtroCop; // 'SI' | 'NO' | null
  String? _filtroEstatus; // 'Liberado' | 'No liberado' | null

  final _nf = NumberFormat('#,##0.00');
  final _nf4 = NumberFormat('0.0000');
  bool _normalizacionInicialAplicada = false;

  // Paginación
  static const int _rowsPerPage = 50;
  int _currentPage = 0;

  int get _startRow => _currentPage * _rowsPerPage;
  int get _endRow => _startRow + _rowsPerPage;
  void _goToPage(int page, int totalRows) {
    final maxPage = (totalRows / _rowsPerPage).ceil() - 1;
    setState(() {
      _currentPage = page.clamp(0, maxPage);
    });
    _verticalScroll.jumpTo(0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _normalizarDatosLocalesExistentes();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  void _normalizarDatosLocalesExistentes() {
    if (_normalizacionInicialAplicada || !mounted) return;
    _normalizacionInicialAplicada = true;

    final prediosActualizados =
        ref.read(localPrediosProvider.notifier).normalizeExistingData();
    final prediosDeduplicados =
        ref.read(localPrediosProvider.notifier).deduplicateExistingData();
    final propietariosActualizados =
        ref.read(localPropietariosProvider.notifier).normalizeExistingData();

    final totalActualizados =
        prediosActualizados + propietariosActualizados + prediosDeduplicados;
    if (totalActualizados > 0) {
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      ref.invalidate(propietariosListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Normalizacion aplicada: $prediosActualizados predio(s) y '
            '$propietariosActualizados propietario(s). '
            '${prediosDeduplicados > 0 ? "Duplicados eliminados: $prediosDeduplicados." : ""}',
          ),
        ),
      );
    }
  }

  // Memoización de filtros
  List<Predio>? _lastAll;
  String? _lastProyecto;
  String? _lastTramo;
  String? _lastTipo;
  String? _lastCop;
  String? _lastEstatus;
  String? _lastBusqueda;
  List<Predio>? _lastFiltered;

  List<Predio> _applyFilters(List<Predio> all) {
    final shouldRecompute = _lastAll != all ||
        _lastProyecto != _proyectoActual ||
        _lastTramo != _filtroTramo ||
        _lastTipo != _filtroTipo ||
        _lastCop != _filtroCop ||
        _lastEstatus != _filtroEstatus ||
        _lastBusqueda != _busqueda;
    if (!shouldRecompute && _lastFiltered != null) {
      return _lastFiltered!;
    }
    final filtered = all.where((p) {
      if (_predioProyecto(p) != _proyectoActual) return false;
      if (_filtroTramo != null && p.tramo != _filtroTramo) return false;
      if (_filtroTipo != null && p.tipoPropiedad != _filtroTipo) return false;
      if (_filtroEstatus != null) {
        final estatus = p.cop ? 'Liberado' : 'No liberado';
        if (estatus != _filtroEstatus) return false;
      }
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
    _lastAll = all;
    _lastProyecto = _proyectoActual;
    _lastTramo = _filtroTramo;
    _lastTipo = _filtroTipo;
    _lastCop = _filtroCop;
    _lastEstatus = _filtroEstatus;
    _lastBusqueda = _busqueda;
    _lastFiltered = filtered;
    return filtered;
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
    final prediosAsync = ref.watch(prediosListProvider);
    Widget content;
    if (prediosAsync.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (prediosAsync.hasError) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Error al cargar los datos', style: TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            Text(prediosAsync.error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(prediosListProvider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else {
      // Si no hay datos, mostrar mensaje amigable y evitar errores
      final remoteData = prediosAsync.asData?.value;
      final prediosList = remoteData ?? _ultimosPredios;
      if (prediosList == null || prediosList.isEmpty) {
        content = Column(
          children: [
            _buildTopBar(0, const []),
            const Divider(height: 1),
            const Expanded(
              child: Center(
                child: Text(
                  'No hay predios registrados aún. Importa un archivo o agrega datos para comenzar.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      } else {
        _ultimosPredios = prediosList;
        final allPredios = prediosList
            .map((predio) => _prediosOptimistas[predio.id] ?? predio)
            .toList(growable: false);
        final filtered = _applyFilters(allPredios);
        final totalPages = (filtered.length / _rowsPerPage).ceil();
        final pageRows = filtered.skip(_startRow).take(_rowsPerPage).toList();

        // Auto-seleccionar el proyecto solicitado por la pantalla de carga (post-importación)
        final proyectoSolicitado = ref.watch(gestionProyectoProvider);
        if (proyectoSolicitado != null && _proyectos.contains(proyectoSolicitado) &&
            proyectoSolicitado != _proyectoActual) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _proyectoActual = proyectoSolicitado);
            ref.read(gestionProyectoProvider.notifier).state = null;
          });
        }

        content = Column(
          children: [
            _buildTopBar(filtered.length, allPredios),
            const Divider(height: 1),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      onPressed: _currentPage > 0
                          ? () => _goToPage(0, filtered.length)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0
                          ? () => _goToPage(_currentPage - 1, filtered.length)
                          : null,
                    ),
                    Text('Página \\${_currentPage + 1} de $totalPages'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < totalPages - 1
                          ? () => _goToPage(_currentPage + 1, filtered.length)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      onPressed: _currentPage < totalPages - 1
                          ? () => _goToPage(totalPages - 1, filtered.length)
                          : null,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildTable(pageRows),
            ),
          ],
        );
      }
    }

    return AppScaffold(
      currentIndex: 3,
      title: 'Gestion',
      child: content,
    );
  }

  Widget _buildTopBar(int visible, List<Predio> allPredios) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Icon(Icons.folder_outlined, size: 16, color: AppColors.textSecondary),
              const Text(
                'Proyecto:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _proyectoActual,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      items: _proyectos.map((proyecto) {
                        final count = _conteoProyecto(allPredios, proyecto);
                        return DropdownMenuItem<String>(
                          value: proyecto,
                          child: Row(
                            children: [
                              Text(
                                proyecto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _proyectoActual = v);
                      },
                    ),
                  ),
                ),
              ),
            ],
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
                  'Filtros${_filtroTramo != null || _filtroTipo != null || _filtroCop != null || _filtroEstatus != null ? ' ✓' : ''}',
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
          if (_filtroTramo != null || _filtroTipo != null || _filtroCop != null || _filtroEstatus != null) ...[
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
                  if (_filtroEstatus != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('Estatus: $_filtroEstatus'),
                        onDeleted: () => setState(() => _filtroEstatus = null),
                        backgroundColor: _filtroEstatus == 'Liberado'
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
      90, // ESTATUS
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
      'C.O.P', 'ESTATUS', 'COP FIRMADO', 'OFICIO',
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

  Future<void> _savePredio(Predio previous, Predio updated) async {
    setState(() {
      _prediosOptimistas[updated.id] = updated;
    });

    if (updated.id.startsWith('local-')) {
      ref.read(localPrediosProvider.notifier).updatePredio(updated);
      ref.invalidate(prediosListProvider);
      return;
    }

    try {
      final saved = await ref
          .read(prediosRepositoryProvider)
          .updatePredio(updated.id, updated.toMap());
      if (!mounted) return;
      setState(() {
        _prediosOptimistas[updated.id] = saved;
      });
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prediosOptimistas[previous.id] = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el predio en la base de datos.'),
          backgroundColor: AppColors.danger,
        ),
      );
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
            onTap: () => _savePredio(
              p,
              p.copyWith(cop: !p.cop, updatedAt: DateTime.now()),
            ),
          ),
          // ESTATUS
          _estatusCell(p, widths[13]),
          // COP FIRMADO
          _dataCell(p.copFirmado ?? '-', widths[14]),
          // OFICIO
          _dataCell(p.oficio ?? '-', widths[15]),
          // POLÍGONO INSERTADO (tappable)
          _tappableBoolCell(
            p.poligonoInsertado, widths[16],
            onTap: () => _savePredio(
              p,
              p.copyWith(
                poligonoInsertado: !p.poligonoInsertado,
                updatedAt: DateTime.now(),
              ),
            ),
          ),
          // IDENTIFICACION (tappable)
          _tappableBoolCell(
            p.identificacion, widths[17],
            onTap: () => _savePredio(
              p,
              p.copyWith(
                identificacion: !p.identificacion,
                updatedAt: DateTime.now(),
              ),
            ),
          ),
          // LEVANTAMIENTO (tappable)
          _tappableBoolCell(
            p.levantamiento, widths[18],
            onTap: () => _savePredio(
              p,
              p.copyWith(
                levantamiento: !p.levantamiento,
                updatedAt: DateTime.now(),
              ),
            ),
          ),
          // NEGOCIACION (tappable)
          _tappableBoolCell(
            p.negociacion, widths[19],
            onTap: () => _savePredio(
              p,
              p.copyWith(
                negociacion: !p.negociacion,
                updatedAt: DateTime.now(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estatusCell(Predio predio, double width) {
    final estatus = predio.cop ? 'Liberado' : 'No liberado';
    final color = predio.cop ? AppColors.secondary : AppColors.danger;

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
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          estatus,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _actionCell(Predio p, double width) {
    return InkWell(
      onTap: () => context.push('/tabla/predio/${p.id}'),
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
    final vinculado = p.poligonoInsertado || p.geometry != null;
    return Tooltip(
      message: vinculado
          ? 'Vinculado: ver en mapa'
          : 'No vinculado: vincular manualmente',
      child: InkWell(
        onTap: () {
          if (!vinculado) {
            ref.read(manualVincularPredioIdProvider.notifier).state = p.id;
            context.go('/mapa');
            return;
          }
          ref.read(focusPredioIdProvider.notifier).state = p.id;
          context.go('/mapa');
        },
        child: Container(
          width: width,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Icon(
            vinculado ? Icons.link_rounded : Icons.link_off_rounded,
            size: 16,
            color: vinculado ? AppColors.secondary : AppColors.danger,
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

  void _showFiltros(BuildContext context) {
    String? tramo = _filtroTramo;
    String? tipo = _filtroTipo;
    String? cop = _filtroCop;
    String? estatus = _filtroEstatus;

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
                      setS(() { tramo = null; tipo = null; cop = null; estatus = null; });
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
              const SizedBox(height: 16),
              Text('Estatus', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Liberado'),
                    selected: estatus == 'Liberado',
                    onSelected: (v) => setS(() => estatus = v ? 'Liberado' : null),
                    selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                  FilterChip(
                    label: const Text('No liberado'),
                    selected: estatus == 'No liberado',
                    onSelected: (v) => setS(() => estatus = v ? 'No liberado' : null),
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
                      _filtroEstatus = estatus;
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
