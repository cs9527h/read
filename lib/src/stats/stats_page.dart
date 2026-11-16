import 'package:flutter/material.dart';

import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';

enum _Period { day, week, month, year, all }

/// 阅读统计：全部数据来自本机真实阅读埋点，没有数据就显示 0。
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _Period _period = _Period.week;
  bool _asChart = true;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: ReadingStatsStore.instance,
      builder: (BuildContext context, Widget? child) {
        final ReadingStatsStore stats = ReadingStatsStore.instance;
        final _Window window = _windowOf(_period);
        final int seconds = window.seconds;
        final int chars = window.chars;
        final int days = window.days.where((String d) => (stats.daySeconds[d] ?? 0) > 0).length;
        final int avgSeconds = days == 0 ? 0 : seconds ~/ days;
        final int bestDay = window.days.fold<int>(
          0,
          (int best, String day) => (stats.daySeconds[day] ?? 0) > best
              ? (stats.daySeconds[day] ?? 0)
              : best,
        );
        final int speed = seconds == 0 ? 0 : (chars / (seconds / 60)).round();

        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: <Widget>[
                Text(
                  '阅读统计',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: palette.ink),
                ),
                const SizedBox(height: 14),
                _Segmented(
                  labels: const <String>['日', '周', '月', '年', '总'],
                  selected: _period.index,
                  onChanged: (int index) => setState(() {
                    _period = _Period.values[index];
                  }),
                ),
                const SizedBox(height: 24),
                Text(
                  _duration(seconds),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  window.label,
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
                const SizedBox(height: 22),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.85,
                  children: <Widget>[
                    _StatCard(title: '日均阅读时长', value: _duration(avgSeconds)),
                    _StatCard(title: '单日阅读最久', value: _duration(bestDay)),
                    _StatCard(title: '阅读天数', value: '$days 天'),
                    _StatCard(title: '累计读过', value: '${stats.booksCount} 本'),
                    _StatCard(title: '读完书籍', value: '${stats.finishedBooks.length} 本'),
                    _StatCard(title: '阅读字数', value: _chars(chars)),
                    _StatCard(title: '阅读速度', value: '$speed 字/分钟'),
                    _StatCard(
                      title: '总时长',
                      value: _duration(stats.totalSeconds),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Text(
                      '阅读时间趋势',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.ink),
                    ),
                    const Spacer(),
                    _TinyToggle(
                      left: '柱状',
                      right: '时间',
                      leftSelected: _asChart,
                      onChanged: (bool chart) => setState(() {
                        _asChart = chart;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_asChart)
                  _BarChart(days: window.days, seconds: stats.daySeconds, chars: stats.dayChars)
                else
                  _TimeList(days: window.days, seconds: stats.daySeconds),
                if (seconds == 0) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    '还没有阅读记录：打开一本书读几分钟后，这里就会出现数据。',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  _Window _windowOf(_Period period) {
    final ReadingStatsStore stats = ReadingStatsStore.instance;
    final DateTime now = DateTime.now();
    List<String> days;
    String label;
    switch (period) {
      case _Period.day:
        days = <String>[_key(DateTime(now.year, now.month, now.day))];
        label = '${now.year}年${now.month}月${now.day}日';
        break;
      case _Period.week:
        days = _range(now, 7);
        label = '${_human(days.first)} 至今';
        break;
      case _Period.month:
        days = _range(now, 30);
        label = '${_human(days.first)} 至今';
        break;
      case _Period.year:
        days = _range(now, now.difference(DateTime(now.year)).inDays + 1);
        label = '${now.year}年1月1日 至今';
        break;
      case _Period.all:
        final Map<String, int> all = stats.daySeconds;
        days = all.isEmpty ? <String>[] : (all.keys.toList()..sort());
        label = days.isEmpty ? '暂无记录' : '${_human(days.first)} 至今';
        break;
    }
    int seconds = 0;
    int chars = 0;
    for (final String day in days) {
      seconds += stats.daySeconds[day] ?? 0;
      chars += stats.dayChars[day] ?? 0;
    }
    return _Window(days: days, seconds: seconds, chars: chars, label: label);
  }

  List<String> _range(DateTime now, int n) {
    final List<String> out = <String>[];
    for (int i = n - 1; i >= 0; i--) {
      out.add(_key(DateTime(now.year, now.month, now.day - i)));
    }
    return out;
  }

  String _key(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  String _human(String key) {
    final List<String> parts = key.split('-');
    return '${parts[0]}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }

  String _duration(int seconds) {
    if (seconds <= 0) return '0 分钟';
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m 分钟';
    return '$h 小时 $m 分钟';
  }

  String _chars(int chars) {
    if (chars < 10000) return '$chars 字';
    return '${(chars / 10000).toStringAsFixed(1)} 万字';
  }
}

class _Window {
  const _Window({
    required this.days,
    required this.seconds,
    required this.chars,
    required this.label,
  });

  final List<String> days;
  final int seconds;
  final int chars;
  final String label;
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.labels, required this.selected, required this.onChanged});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 10),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? palette.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 8),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
                      color: i == selected
                          ? (palette.brightness == Brightness.dark ? Colors.black : Colors.white)
                          : palette.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TinyToggle extends StatelessWidget {
  const _TinyToggle({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    Widget item(String text, bool active) => GestureDetector(
          onTap: () => onChanged(text == left),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: active ? palette.ink : palette.muted,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
    return Row(children: <Widget>[item(left, leftSelected), item(right, !leftSelected)]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(title, style: TextStyle(fontSize: 12, color: palette.muted)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: palette.ink),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.days, required this.seconds, required this.chars});

  final List<String> days;
  final Map<String, int> seconds;
  final Map<String, int> chars;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final List<String> shown = days.length > 30 ? days.sublist(days.length - 30) : days;
    final int maxSeconds = shown.fold<int>(
      1,
      (int best, String day) => (seconds[day] ?? 0) > best ? (seconds[day] ?? 0) : best,
    );
    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final String day in shown)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Tooltip(
                        message: '$day\n${(seconds[day] ?? 0) ~/ 60} 分钟 · ${chars[day] ?? 0} 字',
                        child: Container(
                          height: ((seconds[day] ?? 0) / maxSeconds) * 120 + ((seconds[day] ?? 0) > 0 ? 2 : 0),
                          decoration: BoxDecoration(
                            color: (seconds[day] ?? 0) > 0
                                ? palette.ink.withValues(alpha: 0.85)
                                : palette.outline,
                            borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                shown.isEmpty ? '' : shown.first.substring(5),
                style: TextStyle(fontSize: 10, color: palette.muted),
              ),
              const Spacer(),
              Text(
                shown.isEmpty ? '' : shown.last.substring(5),
                style: TextStyle(fontSize: 10, color: palette.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeList extends StatelessWidget {
  const _TimeList({required this.days, required this.seconds});

  final List<String> days;
  final Map<String, int> seconds;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final List<String> shown = days.length > 30 ? days.sublist(days.length - 30) : days;
    final List<String> reversed = shown.reversed.toList();
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: <Widget>[
          for (final String day in reversed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  Text(day, style: TextStyle(fontSize: 12, color: palette.muted)),
                  const Spacer(),
                  Text(
                    '${(seconds[day] ?? 0) ~/ 60} 分钟',
                    style: TextStyle(fontSize: 12, color: palette.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
