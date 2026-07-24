import 'package:flutter/material.dart';

import '../../../components/common/gkk_tab_bar.dart';

class GuildWarTabBar extends StatelessWidget {
  const GuildWarTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    required this.icons,
  });

  final TabController controller;
  final List<String> tabs;
  final List<String> icons;

  @override
  Widget build(BuildContext context) {
    return GkkTabBar(
      controller: controller,
      tabs: List<Widget>.generate(tabs.length, (int i) {
        return GkkTabBar.labeledTab(
          child: Tooltip(
            message: tabs[i],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(icons[i], style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(tabs[i]),
              ],
            ),
          ),
        );
      }),
    );
  }
}
