import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class NLogo extends StatelessWidget {
  const NLogo({super.key, this.size = 42, this.showFrame = false});

  final double size;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * .22),
        border: showFrame
            ? Border.all(color: const Color(0xFFD8B45B), width: size * .025)
            : null,
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => NColors.brandGradient.createShader(bounds),
        child: Text(
          'N',
          style: TextStyle(
            fontSize: size * .72,
            height: .95,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
            color: Colors.white,
          ),
        ),
      ),
    );

    return showFrame
        ? Padding(padding: EdgeInsets.all(size * .04), child: logo)
        : logo;
  }
}
