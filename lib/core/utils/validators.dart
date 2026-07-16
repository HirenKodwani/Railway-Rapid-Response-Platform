// Form validators for the Indian Railways RRS app

class Validators {
  Validators._(); // Prevent instantiation

  /// Validate required field
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Sanitize phone number (strip spaces, hyphens, +91, 0)
  static String sanitizePhone(String value) {
    String sanitized = value.replaceAll(RegExp(r'\s+|-'), '');
    if (sanitized.startsWith('+91')) {
      sanitized = sanitized.substring(3);
    } else if (sanitized.startsWith('0') && sanitized.length == 11) {
      sanitized = sanitized.substring(1);
    }
    return sanitized;
  }

  /// Validate email format
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate phone number format (Indian 10-digit)
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final sanitized = sanitizePhone(value);
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(sanitized)) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  /// Validate email or phone (for login identifier)
  static String? emailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or Phone is required';
    }
    final trimmed = value.trim();
    // Check if it looks like an email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    // Check if it looks like a phone number
    final sanitizedPhone = sanitizePhone(trimmed);
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');

    if (!emailRegex.hasMatch(trimmed) &&
        !phoneRegex.hasMatch(sanitizedPhone)) {
      return 'Please enter a valid email or 10-digit phone number';
    }
    return null;
  }

  /// Validate password strength
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  /// Validate confirm password match
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validate employee ID format
  static String? employeeId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Employee ID is required';
    }
    return null;
  }

  /// Validate name
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(value.trim())) {
      return 'Name can only contain alphabetic characters, spaces, and hyphens';
    }
    return null;
  }
}
