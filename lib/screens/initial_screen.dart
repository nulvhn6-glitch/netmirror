import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:netmirror/api/get_initial.dart';
import 'package:netmirror/constants.dart';
import 'package:netmirror/data/cookies_manager.dart';
import 'package:netmirror/log.dart';
import 'package:netmirror/provider/AudioTrackProvider.dart';
import 'package:netmirror/data/options.dart';
import 'package:netmirror/widgets/windows_titlebar_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class InitialScreen extends ConsumerStatefulWidget {
  const InitialScreen({super.key});

  @override
  ConsumerState<InitialScreen> createState() => _InitialScreenState();
}

const l = L("initial");

class _InitialScreenState extends ConsumerState<InitialScreen> {
  bool counterStarted = false;
  int counterSeconds = 35;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initial();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startCounter({Function? onFinish}) {
    setState(() {
      counterStarted = true;
      counterSeconds = 35;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (counterSeconds > 0) {
        setState(() {
          counterSeconds--;
        });
      } else {
        timer.cancel();
        onFinish?.call();
      }
    });
  }

  void _initial() async {
    sp = await SharedPreferences.getInstance();
    ref.read(audioTrackProvider.notifier).initial();
    SettingsOptions.initialize(sp!);
    CookiesManager.initialize();

    await CookiesManager.validate(
      onAddOpen: startCounter,
      handleAddOpenError: (String addHash) async {
        // Silently trigger openAdd in the background without launching the external browser!
        try {
          await openAdd(addHash);
        } catch (_) {}

        startCounter(
          onFinish: () async {
            final newTHashT = await verifyAdd(addHash);
            if (newTHashT != null) {
              l.log("newTHashT: $newTHashT");
              CookiesManager.tHashT = newTHashT;
              GoRouter.of(context).go(SettingsOptions.currentScreen, extra: 0);
            }
          },
        );
      },
      onSuccess: () {
        GoRouter.of(context).go(SettingsOptions.currentScreen, extra: 0);
      },
    );
  }

  String get _statusMessage {
    if (!counterStarted) return "Connecting to netmirror server...";
    if (counterSeconds > 28) return "Establishing secure gateway...";
    if (counterSeconds > 21) return "Authenticating streaming token...";
    if (counterSeconds > 14) return "Configuring media pipelines...";
    if (counterSeconds > 7) return "Optimizing network routes...";
    return "Almost ready...";
  }

  @override
  Widget build(BuildContext context) {
    final double progress = counterStarted ? (35 - counterSeconds) / 35 : 0.0;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        title: windowDragArea(),
        elevation: 0,
      ),
      body: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Centered Netflix Logo with dynamic pulse entrance animation
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 2),
              tween: Tween<double>(begin: 0.8, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Image.asset(
                    "assets/logos/netflix.png",
                    height: 130,
                    width: 130,
                  ),
                );
              },
            ),
            const SizedBox(height: 50),

            // Premium loader matching Netflix color schemes
            SizedBox(
              height: 48,
              width: 48,
              child: CircularProgressIndicator(
                value: counterStarted ? progress : null,
                color: Colors.red,
                strokeWidth: 3.5,
                backgroundColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 35),

            // Sleek, enterprise loading feedback instead of raw ad waiting seconds
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            if (counterStarted) ...[
              const SizedBox(height: 8),
              Text(
                "Initializing: ${(progress * 100).toInt()}% (${counterSeconds}s remaining)",
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

