import 'package:flutter/material.dart';

class Specialisations {
  Specialisations._();

  static const Map<String, String> labels = {
    'fire_response': 'Fire Response',
    'medical_response': 'Medical Response',
    'mechanical_response': 'Mechanical Response',
    'electrical': 'Electrical',
    'ohe': 'OHE',
    'engineering_track': 'Engineering / Track',
    'signal_telecom': 'Signal & Telecom',
    'security': 'Security',
    'disaster_management': 'Disaster Management',
  };

  static const Map<String, Color> colors = {
    'fire_response': Color(0xFFE53935), // Red
    'medical_response': Color(0xFF43A047), // Green
    'mechanical_response': Color(0xFF5E35B1), // Deep Purple
    'electrical': Color(0xFFFDD835), // Yellow
    'ohe': Color(0xFF00ACC1), // Cyan
    'engineering_track': Color(0xFF8D6E63), // Brown
    'signal_telecom': Color(0xFF3949AB), // Indigo
    'security': Color(0xFF546E7A), // Blue Grey
    'disaster_management': Color(0xFFFB8C00), // Orange
  };

  static List<String> get ids => labels.keys.toList();

  static String getLabel(String? id) {
    if (id == null) return 'Unspecified';
    return labels[id] ?? 'Unknown';
  }

  static Color getColor(String? id) {
    if (id == null) return Colors.grey.shade400;
    return colors[id] ?? Colors.grey.shade600;
  }
}
