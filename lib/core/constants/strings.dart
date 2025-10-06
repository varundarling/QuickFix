// Centralized user-facing strings. English (US) only for now.
// Expandable to localization later via arb or similar.

class Strings {
  // App
  static const String appName = 'QuickFix';
  static const String tagline = 'Fast. Reliable. Local services.';

  // Common
  static const String or = 'OR';
  static const String change = 'Change';
  static const String loadingUserData = 'Loading user data...';

  // Roles
  static const String provider = 'Provider';
  static const String customer = 'Customer';
  static const String loggingInAsProvider = 'Logging in as Service Provider';
  static const String loggingInAsCustomer = 'Logging in as Customer';
  static const String signingUpAsProvider = 'Signing up as Service Provider';
  static const String signingUpAsCustomer = 'Signing up as Customer';

  // Auth headings
  static const String providerLoginTitle = 'Provider Login';
  static const String loginTitle = 'Welcome Back!';
  static const String providerLoginSubtitle = 'Login to manage your services';
  static const String customerLoginSubtitle = 'Login to book trusted services';
  static const String providerSignUpTitle = 'Join as Service Provider';
  static const String customerSignUpTitle = 'Create Account';
  static const String providerSignUpSubtitle =
      'Start earning by providing services';
  static const String customerSignUpSubtitle =
      'Sign up to book trusted services';

  // Buttons
  static const String login = 'Login';
  static const String signUp = 'Sign Up';
  static const String continueWithGoogle = 'Continue with Google';
  static const String signingIn = 'Signing in...';
  static const String signingUp = 'Signing up...';
  static const String signUpWithGoogle = 'Sign Up with Google';

  // Auth links
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account? ';

  // Fields
  static const String email = 'Email';
  static const String emailHint = 'Enter your email';
  static const String password = 'Password';
  static const String passwordHint = 'Enter your password';
  static const String fullName = 'Full Name';
  static const String fullNameHint = 'Enter your full name';
  static const String phoneNumber = 'Phone Number';
  static const String phoneNumberHint = 'Enter your phone number';
  static const String confirmPassword = 'Confirm Password';
  static const String confirmPasswordHint = 'Confirm your password';

  // Validation messages (simple, friendly)
  static const String emailRequired = 'Please enter your email';
  static const String emailInvalid = 'Please enter a valid email address';
  static const String passwordRequired = 'Please enter your password';
  static const String passwordTooShort = 'Use at least 6 characters';
  static const String nameRequired = 'Please enter your full name';
  static const String nameTooShort = 'Name must be at least 2 characters';
  static const String phoneRequired = 'Please enter your phone number';
  static const String phoneInvalid = 'Please enter a valid phone number';
  static const String confirmPasswordRequired = 'Please confirm your password';
  static const String passwordsDoNotMatch = 'Passwords do not match';

  // Terms & privacy
  static const String agreeTo = 'I agree to the ';
  static const String termsAndConditions = 'Terms & Conditions';
  static const String and = ' and ';
  static const String privacyPolicy = 'Privacy Policy';
  static const String couldNotOpen = 'Could not open';

  // Snackbars / errors
  static const String loginFailed = 'Login failed. Please try again.';
  static const String signUpFailed = 'Sign up failed. Please try again.';

  // Currency labels
  static const String usdSuffix = 'USD';
  static const String currencyNotice = 'All prices are shown in USD (\$)';
  static const String searchHint = 'Find services';
}


