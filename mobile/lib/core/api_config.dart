class ApiConfig {
  // Points at the live Render backend by default. Override at build time
  // with --dart-define=API_BASE_URL=http://localhost:4000 for local dev
  // against `npm run dev` in backend/.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cuts-salon-backend.onrender.com',
  );
}
