import 'package:flutter/material.dart';
import 'package:local_legacy/view/auth/screens/splash_screen.dart';
import 'package:local_legacy/viewmodel/auth_viewmodel.dart';
import 'package:local_legacy/viewmodel/shop_viewmodel.dart';
import 'package:local_legacy/viewmodel/customer_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => ShopViewModel()),
        ChangeNotifierProvider(create: (_) => CustomerViewModel()),
      ],
      child: MaterialApp(
        title: 'Local Legacy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}