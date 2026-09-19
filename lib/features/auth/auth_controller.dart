import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/entities.dart';

enum AuthStatus { initial, authenticating, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final Student? student;
  final String? error; // 友好错误信息

  const AuthState({this.status = AuthStatus.initial, this.student, this.error});

  bool get isLoading => status == AuthStatus.authenticating;
  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, Student? student, String? error, bool clearError = false}) =>
      AuthState(
        status: status ?? this.status,
        student: student ?? this.student,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  /// App 启动时尝试恢复登录态。
  Future<bool> restore() async {
    final repo = ref.read(authRepositoryProvider);
    final ok = await repo.restoreSession();
    if (ok) {
      state = AuthState(status: AuthStatus.authenticated, student: repo.student);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
    return ok;
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(username, password);
    if (result.success) {
      state = AuthState(status: AuthStatus.authenticated, student: result.student);
      return true;
    }
    state = AuthState(
      status: AuthStatus.unauthenticated,
      error: result.error?.message ?? '登录失败，请稍后重试',
    );
    return false;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    await ref.read(reminderServiceProvider).cancelAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
