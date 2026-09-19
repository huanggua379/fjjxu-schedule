import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/hud_card.dart';
import '../../features/background/background_sync.dart';
import '../../app/providers.dart';
import '../schedule/schedule_controller.dart';
import 'auth_controller.dart';

/// 学号登录页。凭证仅通过安全存储保存，界面与日志均不回显密码。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    // 用 ProviderContainer 而非 widget 的 ref：登录成功后路由会立刻跳走并销毁
    // 本页，若用 ref/mounted 会导致首同步被跳过、课表加载不出来。
    final container = ProviderScope.containerOf(context);

    final ok = await container
        .read(authControllerProvider.notifier)
        .login(_userCtrl.text.trim(), _pwdCtrl.text);

    if (ok) {
      // 登录成功后：请求通知权限、启动后台周期同步、触发首同步（课表+成绩）。
      // 这些都不依赖本页是否仍挂载。
      await container.read(reminderServiceProvider).requestNotificationPermission();
      final s = container.read(settingsControllerProvider);
      await BackgroundSync.reschedule(
        enabled: s.autoSync,
        intervalMinutes: s.syncIntervalMinutes,
      );
      final sem = container.read(currentSemesterProvider);
      await container.read(scheduleControllerProvider(sem).notifier).refresh();
    } else {
      if (!mounted) return;
      final err = container.read(authControllerProvider).error ?? '登录失败，请稍后重试';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 28),
                    HudCard(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const HudLabel('STUDENT LOGIN',
                                icon: Icons.lock_outline_rounded),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _userCtrl,
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: '学号',
                                hintText: '请输入教务系统学号',
                                prefixIcon:
                                    Icon(Icons.badge_outlined, size: 20),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? '请输入学号'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _pwdCtrl,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: '密码',
                                hintText: '请输入教务系统密码',
                                prefixIcon:
                                    const Icon(Icons.key_outlined, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                      size: 20),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? '请输入密码'
                                  : null,
                            ),
                            const SizedBox(height: 22),
                            FilledButton(
                              onPressed: auth.isLoading ? null : _submit,
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white),
                                    )
                                  : const Text('登 录'),
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 14),
                              _ErrorBanner(message: auth.error!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '登录即表示同意仅在本机保存你的凭证，\n用于访问 ${AppConstants.jwxtBaseUrl.replaceFirst('https://', '')} 教务系统。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 16),
        const Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'CAMPUS SCHEDULE & GRADES',
          style: AppTextStylesLocal.muted,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.danger, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 局部文本样式（避免为登录页额外引入主题依赖）
class AppTextStylesLocal {
  static const muted = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    color: AppColors.textSecondaryLight,
  );
}
