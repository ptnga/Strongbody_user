/// `data` của login (email / Google / Apple) — web `authOptions.ts`, Multime `login_response.dart`:
/// `{ token: {accessToken, refreshToken}, user: { role, user: {id, first_name, last_name, email} }, seller }`.
class LoginResponseDto {
  final String? accessToken;
  final String? refreshToken;
  final int? userId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? role;

  const LoginResponseDto({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.firstName,
    this.lastName,
    this.email,
    this.role,
  });

  factory LoginResponseDto.fromData(Map<String, dynamic> data) {
    final token = data['token'] is Map ? data['token'] as Map : const {};
    final userWrap = data['user'] is Map ? data['user'] as Map : const {};
    // Bọc 2 lớp `user.user`; một số bản BE trả thẳng `user`.
    final user = userWrap['user'] is Map ? userWrap['user'] as Map : userWrap;
    return LoginResponseDto(
      accessToken: (token['accessToken'] ?? data['accessToken'])?.toString(),
      refreshToken: (token['refreshToken'] ?? data['refreshToken'])?.toString(),
      userId: ((user['id'] ?? user['user_id']) as num?)?.toInt(),
      firstName: user['first_name']?.toString(),
      lastName: user['last_name']?.toString(),
      email: user['email']?.toString(),
      role: userWrap['role']?.toString(),
    );
  }
}
