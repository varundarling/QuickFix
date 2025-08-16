class Validators {
  static String? email (String? value) {
    if(value == null || value.isEmpty){
      return 'Email is required';
    }

    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    );

    if(!emailRegExp.hasMatch(value)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  static String? password(String? value) {
    if(value == null || value.isEmpty){
      return 'Password is required';
    }

    if(value.length < 6){
      return 'Password must be atleast 6 characters';
    }

    return null;
  }

  static String? phone(String? value) {
    if(value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final phoneRegExp = RegExp(r'^[6-9] \d{9}');

    if(!phoneRegExp.hasMatch(value)) {
      return 'Please enter a valid mobile number';
    }

    return null;
  }

  static String? name(String? value) {
    if(value == null || value.isEmpty) {
      return 'Name is required';
    }

    if(value.length < 2){
      return 'Name must be atleast 2 characters';
    }

    return null;
  }
}