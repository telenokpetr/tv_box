import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/screen_app_bar.dart';
import '../youtube_cookies_export.dart';
import '../youtube_feed.dart';

const String _kSignInUrl =
    'https://accounts.google.com/ServiceLogin?service=youtube'
    '&continue=https%3A%2F%2Fwww.youtube.com%2F';
const Duration _kInitTimeout = Duration(seconds: 20);
const Duration _kPollEvery = Duration(seconds: 2);

// YouTube sets LOGIN_INFO a moment after the redirect; saving a beat later
// catches the cookies it sets next.
const Duration _kSettle = Duration(seconds: 2);

final Logger _log = Logger('YoutubeSignIn');

/// Signs in to Google in the embedded browser and keeps that login for yt-dlp.
/// The browser is parked afterwards and never visits YouTube again: a login
/// that a browser keeps using is rotated by YouTube, and the copy yt-dlp holds
/// would stop working. Pops with true once the account is saved.
class YoutubeSignInPage extends StatefulWidget {
  const YoutubeSignInPage({super.key});

  @override
  State<YoutubeSignInPage> createState() => _YoutubeSignInPageState();
}

class _YoutubeSignInPageState extends State<YoutubeSignInPage> {
  final WebviewController _controller = WebviewController();
  Timer? _poll;
  bool _controllerStarted = false;
  bool _ready = false;
  bool _failed = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _poll?.cancel();
    // Disposing a controller that never started throws.
    if (_controllerStarted) _controller.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      try {
        await WebviewController.initializeEnvironment().timeout(_kInitTimeout);
      } on PlatformException catch (e) {
        // The environment of an earlier panel is reused.
        _log.info('browser environment already exists: ${e.code}');
      }
      _controllerStarted = true;
      await _controller.initialize().timeout(_kInitTimeout);
      await _controller.setPopupWindowPolicy(
        WebviewPopupWindowPolicy.sameWindow,
      );
      // A fresh session each time, so the account can be switched and a
      // browser still holding the old login cannot rotate it.
      await _controller.clearCookies();
      if (!mounted) return;
      setState(() => _ready = true);
      await WidgetsBinding.instance.endOfFrame;
      await _controller.loadUrl(_kSignInUrl);
      _poll = Timer.periodic(_kPollEvery, (_) => _check());
    } on Object catch (e) {
      _log.warning('embedded browser is not available: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _check() async {
    if (_saving || !mounted) return;
    try {
      final String json = await _controller.getCookies();
      if (hasYoutubeLogin(parseBrowserCookies(json))) await _save();
    } on Object catch (e) {
      _log.warning('cookie check failed: $e');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Future<void>.delayed(_kSettle);
      await saveYoutubeCookies(await _controller.getCookies());
      _poll?.cancel();
      await _controller.loadUrl('about:blank');
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      _log.warning('saving the login failed: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is YoutubeFeedException ? e.message : '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return Scaffold(
      appBar: ScreenAppBar(title: l.ytSignInTitle),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.ytSignInNoBrowser, textAlign: TextAlign.center),
              ),
            )
          : !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _saving
                              ? l.ytSignInSaving
                              : _error != null
                              ? l.ytSignInFailed(_error ?? '')
                              : l.ytSignInHint,
                        ),
                      ),
                      if (_saving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: _save,
                          child: Text(l.ytSignInManual),
                        ),
                    ],
                  ),
                ),
                Expanded(child: Webview(_controller)),
              ],
            ),
    );
  }
}
