import 'package:flutter_android_tv_queue/pages/login_page.dart';
import 'package:flutter_android_tv_queue/pages/queue_display_page.dart';
import 'package:flutter_android_tv_queue/pages/queue_mode_page.dart';
import 'package:flutter_android_tv_queue/pages/queue_setup_page.dart';
import 'package:flutter_android_tv_queue/routes/router_path.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: RouterPath.login,
    routes: [
      // ════════════════════════════════════════════════════════════════════
      // AUTH
      // ════════════════════════════════════════════════════════════════════
      GoRoute(
        path: RouterPath.login,
        builder: (context, state) => const LoginPage(),
      ),

      // ════════════════════════════════════════════════════════════════════
      // QUEUE SETUP — เดินหน้าด้วย push เพื่อให้ปุ่ม Back บนรีโมทย้อนกลับได้
      // ════════════════════════════════════════════════════════════════════
      GoRoute(
        path: RouterPath.queueMode,
        builder: (context, state) => const QueueModePage(),
      ),
      GoRoute(
        path: RouterPath.queueSetup,
        builder: (context, state) => const QueueSetupPage(),
      ),

      // ════════════════════════════════════════════════════════════════════
      // QUEUE DISPLAY
      // ════════════════════════════════════════════════════════════════════
      GoRoute(
        path: RouterPath.queueDisplay,
        builder: (context, state) => const QueueDisplayPage(),
      ),
    ],
  );
}
