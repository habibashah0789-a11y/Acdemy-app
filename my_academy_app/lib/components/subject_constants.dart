// Constants for subject filters and colors used in the dashboard.

import 'package:flutter/material.dart';

// Public constants (without underscore) – can be used by new code.
const Map<String, List<String>> subjectFilters = {
  'Bio': ['biology', 'bio'],
  'Physics': ['physics'],
  'Chemistry': ['chemistry'],
  'Maths': ['math', 'mathematics'],
  'English': ['english'],
};

const Map<String, Color> subjectColors = {
  'Bio': Color(0xFF22C55E),
  'Physics': Color(0xFF3B82F6),
  'Chemistry': Color(0xFFF97316),
  'Maths': Color(0xFFA855F7),
  'English': Color(0xFFEC4899),
};
