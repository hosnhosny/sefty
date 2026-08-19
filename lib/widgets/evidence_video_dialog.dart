// lib/widgets/evidence_video_dialog.dart
//
// يعرض فيديو الدليل (من Cloudinary) في نافذة منبثقة باستخدام Chewie،
// وهو ما يوفر أدوات تشغيل كاملة (تشغيل/إيقاف، شريط تقديم، ملء الشاشة،
// مستوى الصوت، سرعة التشغيل) ويمنع التهنيج الذي يسببه استدعاء setState
// يدوياً مع كل نبضة من VideoPlayerController.

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Future<void> showEvidenceVideoDialog(BuildContext context, String url) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _EvidenceVideoDialog(url: url),
  );
}

class _EvidenceVideoDialog extends StatefulWidget {
  final String url;
  const _EvidenceVideoDialog({required this.url});

  @override
  State<_EvidenceVideoDialog> createState() => _EvidenceVideoDialogState();
}

class _EvidenceVideoDialogState extends State<_EvidenceVideoDialog> {
  late final VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _videoController.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          allowPlaybackSpeedChanging: true,
          showControlsOnInitialize: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.red.shade400,
            handleColor: Colors.red.shade400,
            bufferedColor: Colors.white38,
            backgroundColor: Colors.white24,
          ),
        );
      });
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_error)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'تعذر تشغيل الفيديو',
                style: TextStyle(color: Colors.white),
              ),
            )
          else if (_chewieController == null)
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            AspectRatio(
              aspectRatio: _videoController.value.aspectRatio == 0
                  ? 16 / 9
                  : _videoController.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}