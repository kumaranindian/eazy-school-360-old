class Validators {
  /// Validates if a field is not empty
  static String? validateRequired(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  /// Validates email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    
    return null;
  }

  /// Validates password strength
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  /// Validates phone number format
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    final phoneRegex = RegExp(r'^\d{10,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[^\d]'), ''))) {
      return 'Enter a valid phone number';
    }
    
    return null;
  }

  /// Validates numeric input
  static String? validateNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    
    if (double.tryParse(value) == null) {
      return 'Enter a valid number';
    }
    
    return null;
  }

  /// Validates positive number
  static String? validatePositiveNumber(String? value) {
    final numberError = validateNumber(value);
    if (numberError != null) {
      return numberError;
    }
    
    final number = double.parse(value!);
    if (number <= 0) {
      return 'Enter a positive number';
    }
    
    return null;
  }

  /// Validates date range
  static String? validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return 'Both start and end dates are required';
    }
    
    if (endDate.isBefore(startDate)) {
      return 'End date must be after start date';
    }
    
    return null;
  }

  /// Validates URL format
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }
    
    final urlRegex = RegExp(
      r'^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );
    
    if (!urlRegex.hasMatch(value)) {
      return 'Enter a valid URL';
    }
    
    return null;
  }
}
