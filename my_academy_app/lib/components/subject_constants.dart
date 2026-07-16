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
  'Bio': Color(0xFF4CAF50),
  'Physics': Color(0xFF2196F3),
  'Chemistry': Color(0xFFFF9800),
  'Maths': Color(0xFF00897B),
  'English': Color(0xFF9C27B0),
};
