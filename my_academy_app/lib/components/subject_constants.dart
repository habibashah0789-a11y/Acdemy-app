/// Constants for subject filters and colors used in the dashboard.
/// This file defines both private (underscored) and public versions of the
/// constants to maintain compatibility with existing code that expects the
/// underscore-prefixed names.

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

// Private aliases (with underscore) to match existing code expectations.
const Map<String, List<String>> _subjectFilters = subjectFilters;
const Map<String, Color> _subjectColors = subjectColors;
