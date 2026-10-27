import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/helper/queue_setup_helper.dart';
import 'package:flutter_android_tv_queue/helper/shared_preference_helper.dart';
import 'package:flutter_android_tv_queue/models/response_model.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/routes/router_path.dart';
import 'package:flutter_android_tv_queue/service/auth_service.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/brand_panel.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_button.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_checkbox_tile.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_focus_frame.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class LoginPage extends ConsumerStatefulWidget {
  final http.Client? client;

  /// เปิดแอปครั้งแรก + มี user/pass และค่าตั้งคิวครบ → login แล้วเข้าจอคิวเอง
  /// (ทีวีรีสตาร์ท/ไฟดับ จอคิวต้องกลับมาเองโดยไม่ต้องมีคนกด)
  final bool autoStart;

  const LoginPage({super.key, this.client, this.autoStart = true});

  /// ทำครั้งเดียวต่อการเปิดแอป — ออกจากระบบแล้วกลับมาหน้านี้ต้องไม่เข้าเองอีก
  @visibleForTesting
  static bool autoStartUsed = false;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _autoStartRetry = Duration(seconds: 15);

  // Controllers / focus
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode(debugLabel: 'username');
  final _passwordFocus = FocusNode(debugLabel: 'password');
  final _rememberFocus = FocusNode(debugLabel: 'remember');
  final _loginFocus = FocusNode(debugLabel: 'login');

  // State
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorText;

  /// ค่าตั้งคิวที่จะเข้าจอคิวอัตโนมัติ (null = login ปกติ)
  SavedQueueSetup? _autoSetup;
  Timer? _autoRetryTimer;

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _rememberFocus.dispose();
    _loginFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: AppTheme.overscanPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 11, child: BrandPanel()),
            const SizedBox(width: 32),
            Expanded(flex: 9, child: Center(child: _buildLoginCard())),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      // เผื่อที่ให้กรอบ focus ที่ขยายออกไม่โดนตัด
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 20),
          _buildLabel(theme, 'ชื่อเข้าใช้งาน'),
          TvTextField(
            controller: _usernameController,
            focusNode: _usernameFocus,
            hintText: 'กรอกชื่อเข้าใช้งาน',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _buildLabel(theme, 'รหัส'),
          _buildPasswordRow(),
          const SizedBox(height: 8),
          _buildRememberMe(),
          _buildError(theme),
          TvButton(
            text: 'เข้าใช้งาน',
            focusNode: _loginFocus,
            loading: _loading,
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Row(
      children: [
        Expanded(
          child: Text('เข้าสู่ระบบ', style: theme.textTheme.headlineSmall),
        ),
        TvTextButton(
          icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          text: isDark ? 'โหมดสว่าง' : 'โหมดมืด',
          onPressed: _toggleTheme,
        ),
      ],
    );
  }

  Widget _buildLabel(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: TvColors.of(context).mutedText,
        ),
      ),
    );
  }

  Widget _buildPasswordRow() {
    return Row(
      children: [
        Expanded(
          child: TvTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            hintText: 'กรอกรหัส',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            // Enter/✓ ที่ช่องรหัส = เข้าใช้งานทันที
            onSubmitted: _handleLogin,
          ),
        ),
        const SizedBox(width: 4),
        TvFocusFrame(
          child: IconButton(
            tooltip: _obscurePassword ? 'แสดงรหัส' : 'ซ่อนรหัส',
            iconSize: 28,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMe() {
    return TvCheckboxTile(
      value: _rememberMe,
      focusNode: _rememberFocus,
      label: 'จดจำชื่อผู้ใช้และรหัส',
      onChanged: (value) => setState(() => _rememberMe = value),
    );
  }

  /// จองที่ไว้ 1 บรรทัดเสมอ — ข้อความโผล่แล้ว layout ไม่กระโดด และปุ่มไม่หลุดจอ
  Widget _buildError(ThemeData theme) {
    return SizedBox(
      height: 40,
      child: _errorText == null
          ? null
          : Row(
              children: [
                const SizedBox(width: 4),
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadSavedCredentials() async {
    final saved = await SharedPreferenceHelper.getCredentials();
    if (!mounted) return;

    if (saved == null) {
      _usernameFocus.requestFocus();
      return;
    }

    // เติมให้แล้วให้ผู้ใช้กดเข้าเอง — focus รอที่ปุ่มเข้าใช้งาน (กด OK ครั้งเดียว)
    _usernameController.text = saved.username;
    _passwordController.text = saved.password;
    _loginFocus.requestFocus();

    await _tryAutoStart();
  }

  Future<void> _tryAutoStart() async {
    if (!widget.autoStart || LoginPage.autoStartUsed) return;
    LoginPage.autoStartUsed = true;

    final setup = await SharedPreferenceHelper.getQueueSetup();
    if (!mounted || setup == null || !QueueSetupHelper.isComplete(setup)) {
      return;
    }
    _autoSetup = setup;
    await _handleLogin(auto: true);
  }

  Future<void> _toggleTheme() async {
    final notifier = ref.read(themeModeProvider.notifier);
    final next = notifier.state == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifier.state = next;
    await SharedPreferenceHelper.setThemeMode(next);
  }

  Future<void> _handleLogin({bool auto = false}) async {
    if (_loading) return;
    if (!auto) {
      // ผู้ใช้กดเอง → ยกเลิกการเข้าจอคิวอัตโนมัติ ไปหน้าเลือกระบบคิวตามปกติ
      _autoSetup = null;
      _autoRetryTimer?.cancel();
    }

    final credentials = (
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    final validationError = _validate(credentials);
    if (validationError != null) {
      setState(() => _errorText = validationError);
      (credentials.username.isEmpty ? _usernameFocus : _passwordFocus)
          .requestFocus();
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final response = await AuthService.login(
        username: credentials.username,
        password: credentials.password,
        client: widget.client,
      );
      if (!mounted) return;

      if (response.responseEnum == ResponseEnum.success) {
        ref.read(loginProvider.notifier).state = response.data;
        await _onLoginSuccess(credentials);
      } else {
        _autoSetup = null; // รหัสผิด — ลองซ้ำไปก็ไม่ผ่าน
        _onLoginFailed(response.responseEnum);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่');
        _scheduleAutoRetry();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validate(SavedCredentials credentials) {
    if (credentials.username.isEmpty) return 'กรุณากรอกชื่อเข้าใช้งาน';
    if (credentials.password.isEmpty) return 'กรุณากรอกรหัส';
    return null;
  }

  Future<void> _onLoginSuccess(SavedCredentials credentials) async {
    if (_rememberMe) {
      await SharedPreferenceHelper.setCredentials(credentials);
    } else {
      await SharedPreferenceHelper.clearCredentials();
    }
    if (!mounted) return;

    final employee = await AuthService.getUserInfo(
      context,
      client: widget.client,
    );
    if (!mounted) return;
    ref.read(employeeInfoProvider.notifier).state = employee.data;

    final autoSetup = _autoSetup;
    if (autoSetup == null) {
      context.go(RouterPath.queueMode);
      return;
    }

    // เข้าจอคิวเลย แต่วาง stack ให้ Back ย้อนไปหน้าตั้งค่า → เลือกระบบคิวได้ตามปกติ
    QueueSetupHelper.apply(ref, autoSetup);
    GoRouter.of(context)
      ..go(RouterPath.queueMode)
      ..push(RouterPath.queueSetup)
      ..push(RouterPath.queueDisplay);
  }

  /// เปิดเครื่องพร้อมเราเตอร์ (ไฟดับ) เน็ตอาจยังไม่มา — ลองใหม่จนกว่าจะได้
  void _scheduleAutoRetry() {
    if (_autoSetup == null) return;
    setState(() {
      _errorText =
          'เปิดจอคิวอัตโนมัติไม่สำเร็จ — ลองใหม่ใน ${_autoStartRetry.inSeconds} วินาที';
    });
    _autoRetryTimer?.cancel();
    _autoRetryTimer = Timer(_autoStartRetry, () {
      if (mounted && _autoSetup != null) _handleLogin(auto: true);
    });
  }

  void _onLoginFailed(ResponseEnum responseEnum) {
    setState(() {
      _errorText = responseEnum == ResponseEnum.passwordUserIncorrect
          ? 'ชื่อเข้าใช้งานหรือรหัสไม่ถูกต้อง'
          : 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่';
    });
    _passwordFocus.requestFocus();
  }
}
