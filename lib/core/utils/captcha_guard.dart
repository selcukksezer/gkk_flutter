import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

/// Rate-limit eşiği aşılınca sunucu 'captcha_required' döner.
/// Bu util hatayı yakalar, basit toplama sorusunu gösterir ve çözümü yollar.
class CaptchaGuard {
  CaptchaGuard._();

  /// Hata/yanıt captcha istiyor mu?
  static bool isCaptchaRequired(Object? errorOrResult) {
    if (errorOrResult == null) return false;
    if (errorOrResult is Map) {
      return errorOrResult['code'] == 'captcha_required' ||
          errorOrResult['error'] == 'captcha_required';
    }
    return errorOrResult.toString().contains('captcha_required');
  }

  /// Captcha dialogunu göster. Doğru çözülürse true döner —
  /// çağıran işlem tekrar denenebilir.
  static Future<bool> solve(BuildContext context, String action) async {
    final bool? solved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _CaptchaDialog(action: action),
    );
    return solved ?? false;
  }
}

class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({required this.action});

  final String action;

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  final TextEditingController _answerCtrl = TextEditingController();
  String? _question;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'get_captcha_challenge',
        params: <String, dynamic>{'p_action': widget.action},
      );
      if (!mounted) return;
      setState(() {
        if (res is Map && res['success'] == true) {
          _question = res['question']?.toString();
          _error = null;
        } else {
          _error = 'Soru alınamadı, tekrar dene.';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Soru alınamadı, tekrar dene.');
    }
  }

  Future<void> _submit() async {
    final int? answer = int.tryParse(_answerCtrl.text.trim());
    if (answer == null) {
      setState(() => _error = 'Sayı gir.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'solve_captcha',
        params: <String, dynamic>{
          'p_action': widget.action,
          'p_answer': answer,
        },
      );
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _busy = false;
        _error =
            (res is Map ? res['error']?.toString() : null) ?? 'Yanlış cevap';
        _answerCtrl.clear();
      });
      await _loadQuestion();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Gönderilemedi, tekrar dene.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141B2A),
      title: const Text(
        '🤖 Robot Kontrolü',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Çok hızlı işlem yaptın. Devam etmek için soruyu çöz:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _question ?? '...',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _answerCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cevap',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? '...' : 'Doğrula'),
        ),
      ],
    );
  }
}
