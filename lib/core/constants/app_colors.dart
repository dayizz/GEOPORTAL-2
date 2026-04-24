import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1B6CA8);
  static const Color primaryDark = Color(0xFF0D4F7C);
  static const Color primaryLight = Color(0xFF3A8FCC);
  static const Color secondary = Color(0xFF27AE60);
  static const Color secondaryDark = Color(0xFF1E8449);
  static const Color accent = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF1C40F);
  static const Color info = Color(0xFF3498DB);

  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEFF2F7);
  static const Color border = Color(0xFFDDE1E9);

  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8D);
  static const Color textLight = Color(0xFFB0BAC9);

  static const Color mapBackground = Color(0xFFE8F0F7);

  // Usos de suelo
  static const Color usoHabitacional = Color(0xFF3498DB);
  static const Color usoComercial = Color(0xFFF39C12);
  static const Color usoIndustrial = Color(0xFFE74C3C);
  static const Color usoAgricola = Color(0xFF27AE60);
  static const Color usoMixto = Color(0xFF9B59B6);
  static const Color usoEquipamiento = Color(0xFF1ABC9C);
  static const Color usoOtro = Color(0xFF95A5A6);

  static Color usoSueloColor(String uso) {
    switch (uso.toLowerCase()) {
      case 'habitacional':
        return usoHabitacional;
      case 'comercial':
        return usoComercial;
      case 'industrial':
        return usoIndustrial;
      case 'agrícola':
      case 'agricola':
        return usoAgricola;
      case 'mixto':
        return usoMixto;
      case 'equipamiento':
        return usoEquipamiento;
      default:
        return usoOtro;
    }
  }

  // Colores para tipos de propiedad LDDV
  static const Color tipoSinTipo = Color(0xFF757575);      // gris
  static const Color tipoSocial = Color(0xFF8E44AD);       // purpura
  static const Color tipoPrivada = Color(0xFFF39C12);      // naranja

  static Color tipoPropiedadColor(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'SIN TIPO':
        return tipoSinTipo;
      case 'SOCIAL':
        return tipoSocial;
      case 'PRIVADA':
        return tipoPrivada;
      default:
        return tipoSinTipo;
    }
  }
}
