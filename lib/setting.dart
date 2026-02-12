import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login.dart';
import 'backend/auth_service.dart';

// withOpacity 대체 (프로젝트 공용 패턴 유지)
Color _a(Color c, double o) => c.withAlpha((o * 255).round());

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF2E5), // 앱 기본 톤 유지
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '설정',
          style: GoogleFonts.gowunDodum(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _a(Colors.black, 0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets, size: 40),
              const SizedBox(height: 12),

              /// 닉네임
              Text(
                user?.displayName ?? "달냥이",
                style: GoogleFonts.gowunDodum(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              /// 이메일
              Text(
                user?.email ?? "로그인 필요",
                style: GoogleFonts.gowunDodum(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: AuthService.isSignedIn
                          ? null
                          : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(),
                          ),
                        );
                      },
                      child: const Text("구글 로그인"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade200,
                      ),
                      onPressed: AuthService.isSignedIn
                          ? () async {
                        await FirebaseAuth.instance.signOut();
                      }
                          : null,
                      child: const Text("로그아웃"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
