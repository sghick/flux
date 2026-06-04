import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../styles/text_style/text_style_builder.dart';
import '../../styles/text_style/text_style_font.dart';
import '../../utils/date_utils.dart';
import '../../utils/screen_utils.dart';
import '../buttons/text.dart';

class FLXDatePicker extends StatefulWidget {
  /// If the [currentDate] is earlier than [minDate], use [currentDate] as [minDate].
  final DateTime minDate;

  /// If the [currentDate] is later than [maxDate], use [currentDate] as [maxDate].
  final DateTime maxDate;
  final DateTime currentDate;
  final ValueChanged<DateTime>? onChange;
  final CBDatePickerFlex flex;

  const FLXDatePicker({
    super.key,
    required this.minDate,
    required this.maxDate,
    required this.currentDate,
    this.onChange,
    this.flex = const CBDatePickerFlex.myd(),
  });

  @override
  State<StatefulWidget> createState() => _FLXDatePickerState();
}

class _FLXDatePickerState extends State<FLXDatePicker> {
  late final DateTime minDate;
  late final DateTime maxDate;
  late final DateTime currentDate;

  final double itemHeight = 30.dp;
  final double magnification = 1.2;

  List<int> yearSource = [];
  List<int> monthSource = [];
  List<int> daySource = [];
  List<int> hourSource = [];
  List<int> minuteSource = [];
  List<int> secondSource = [];

  int year = 0;
  int month = 0;
  int day = 0;
  int hour = 0;
  int minute = 0;
  int second = 0;

  late final FixedExtentScrollController yearCtr;
  late final FixedExtentScrollController monthCtr;
  late final FixedExtentScrollController dayCtr;
  late final FixedExtentScrollController hourCtr;
  late final FixedExtentScrollController minuteCtr;
  late final FixedExtentScrollController secondCtr;

  bool isYearPickerScrolling = false;
  bool isMonthPickerScrolling = false;
  bool isDayPickerScrolling = false;
  bool isHourPickerScrolling = false;
  bool isMinutePickerScrolling = false;
  bool isSecondPickerScrolling = false;

  bool get isScrolling {
    return isYearPickerScrolling ||
        isMonthPickerScrolling ||
        isDayPickerScrolling ||
        isHourPickerScrolling ||
        isMinutePickerScrolling ||
        isSecondPickerScrolling;
  }

  @override
  void initState() {
    super.initState();

    /// Make the minDate is earlier than maxDate.
    var wMinDate = widget.minDate;
    var wMaxDate = widget.maxDate;
    if (widget.maxDate.isBefore(widget.minDate)) {
      wMinDate = widget.maxDate;
      wMaxDate = widget.minDate;
    }

    /// Make the currentDate in range of minDate and maxDate.
    var wCurrentDate = widget.currentDate;
    minDate = wMinDate.isAfter(wCurrentDate) ? wCurrentDate : wMinDate;
    maxDate = wMaxDate.isBefore(wCurrentDate) ? wCurrentDate : wMaxDate;
    currentDate = wCurrentDate;

    /// to set the current date components.
    final pt = widget.flex.patterns.join();
    year = pt.patternHasYear ? currentDate.year : 0;
    month = pt.patternHasMonth ? currentDate.month : 0;
    day = pt.patternHasDay ? currentDate.day : 0;
    hour = pt.patternHasHour ? currentDate.hour : 0;
    minute = pt.patternHasMinute ? currentDate.minute : 0;
    second = pt.patternHasSecond ? currentDate.second : 0;

    refreshAllSource(isInit: true);
  }

  @override
  Widget build(BuildContext context) {
    return _buildPickers();
  }

  Widget _buildPickers() {
    List<String> patterns = widget.flex.patterns;
    List<Widget> pickers = patterns.map((e) => _componentPicker(e)).toList();
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(children: pickers),
        IgnorePointer(
          child: Container(
            width: 1.sw,
            height: itemHeight * magnification,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10.dp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _componentPicker(String pt) {
    if (pt.patternHasYear) {
      return Flexible(flex: widget.flex.year, child: _buildYearPicker(pt));
    } else if (pt.patternHasMonth) {
      return Flexible(flex: widget.flex.month, child: _buildMonthPicker(pt));
    } else if (pt.patternHasDay) {
      return Flexible(flex: widget.flex.day, child: _buildDayPicker(pt));
    } else if (pt.patternHasHour) {
      return Flexible(flex: widget.flex.hour, child: _buildHourPicker(pt));
    } else if (pt.patternHasMinute) {
      return Flexible(flex: widget.flex.month, child: _buildMinutePicker(pt));
    } else if (pt.patternHasSecond) {
      return Flexible(flex: widget.flex.second, child: _buildSecondPicker(pt));
    }
    return Container();
  }

  Widget _buildYearPicker(String pattern) {
    final yearSource = this.yearSource;
    return _CBWheelPicker(
      controller: yearCtr,
      itemHeight: itemHeight,
      magnification: magnification,
      itemCount: yearSource.length,
      itemBuilder: (context, index) =>
          _buildText(DateTime(yearSource[index]).formatString(pattern)),
      onSelectedItemChanged: (index) {
        year = yearSource[index];
        refreshAllSource(ignore: _RefreshSourceStyle.year);
      },
      onScrollChanged: (isScrolling) {
        print('scrolling-Year:$isScrolling');
        isYearPickerScrolling = isScrolling;
      },
    );
  }

  Widget _buildMonthPicker(String pattern) {
    final monthSource = this.monthSource;
    return _CBWheelPicker(
      controller: monthCtr,
      itemHeight: itemHeight,
      magnification: magnification,
      itemCount: monthSource.length,
      itemBuilder: (context, index) =>
          _buildText(DateTime(0, monthSource[index]).formatString(pattern)),
      onSelectedItemChanged: (index) {
        month = monthSource[index];
        refreshAllSource(ignore: _RefreshSourceStyle.month);
      },
      onScrollChanged: (isScrolling) {
        print('scrolling-Month:$isScrolling');
        isMonthPickerScrolling = isScrolling;
      },
    );
  }

  Widget _buildDayPicker(String pattern) {
    final daySource = this.daySource;
    return _CBWheelPicker(
      controller: dayCtr,
      itemHeight: itemHeight,
      magnification: magnification,
      itemCount: daySource.length,
      itemBuilder: (context, index) =>
          _buildText(DateTime(0, 0, daySource[index]).formatString(pattern)),
      onSelectedItemChanged: (index) {
        day = daySource[index];
        refreshAllSource(ignore: _RefreshSourceStyle.day);
      },
      onScrollChanged: (isScrolling) {
        print('scrolling-Day:$isScrolling');
        isDayPickerScrolling = isScrolling;
      },
    );
  }

  Widget _buildHourPicker(String pattern) {
    final hourSource = this.hourSource;
    return _CBWheelPicker(
      controller: hourCtr,
      itemHeight: itemHeight,
      magnification: magnification,
      itemCount: hourSource.length,
      itemBuilder: (context, index) => _buildText(
        DateTime(0, 0, 0, hourSource[index]).formatString(pattern),
      ),
      onSelectedItemChanged: (index) {
        hour = hourSource[index];
        refreshAllSource(ignore: _RefreshSourceStyle.hour);
      },
      onScrollChanged: (isScrolling) {
        print('scrolling-Hour:$isScrolling');
        isHourPickerScrolling = isScrolling;
      },
    );
  }

  Widget _buildMinutePicker(String pattern) {
    final minuteSource = this.minuteSource;
    return _CBWheelPicker(
      controller: minuteCtr,
      itemHeight: itemHeight,
      magnification: magnification,
      itemCount: minuteSource.length,
      itemBuilder: (context, index) => _buildText(
        DateTime(0, 0, 0, 0, minuteSource[index]).formatString(pattern),
      ),
      onSelectedItemChanged: (index) {
        minute = minuteSource[index];
        refreshAllSource(ignore: _RefreshSourceStyle.minute);
      },
      onScrollChanged: (isScrolling) {
        print('scrolling-Minute:$isScrolling');
        isMinutePickerScrolling = isScrolling;
      },
    );
  }

  Widget _buildSecondPicker(String pattern) {
    final secondSource = this.secondSource;
    return _CBWheelPicker(
      controller: secondCtr,
      itemHeight: itemHeight,
      magnification: magnification,
      itemCount: secondSource.length,
      itemBuilder: (context, index) => _buildText(
        DateTime(0, 0, 0, 0, 0, secondSource[index]).formatString(pattern),
      ),
      onSelectedItemChanged: (index) {
        second = secondSource[index];
        refreshAllSource(ignore: _RefreshSourceStyle.second);
      },
      onScrollChanged: (isScrolling) {
        isSecondPickerScrolling = isScrolling;
      },
    );
  }

  Widget _buildText(String text) {
    return Container(
      alignment: Alignment.center,
      child: FLXText(
        text,
        style: TextStyleBuilder().size(14.dp).color(Colors.black).w500,
      ),
    );
  }

  void refreshAllSource({
    bool isInit = false,
    _RefreshSourceStyle ignore = _RefreshSourceStyle.none,
  }) {
    if (isScrolling) return;

    yearSource = getYearSource();
    final yearIndex = getFixedIndex(yearSource, year);
    year = yearSource[yearIndex];

    monthSource = getMonthSource(year);
    final monthIndex = getFixedIndex(monthSource, month);
    month = monthSource[monthIndex];

    daySource = getDaySource(year, month);
    final dayIndex = getFixedIndex(daySource, day);
    day = daySource[dayIndex];

    hourSource = getHourSource(year, month, day);
    final hourIndex = getFixedIndex(hourSource, hour);
    hour = hourSource[hourIndex];

    minuteSource = getMinuteSource(year, month, day, hour);
    final minuteIndex = getFixedIndex(minuteSource, minute);
    minute = minuteSource[minuteIndex];

    secondSource = getSecondSource(year, month, day, hour, minute);
    final secondIndex = getFixedIndex(secondSource, second);
    second = secondSource[secondIndex];

    if (isInit) {
      yearCtr = FixedExtentScrollController(initialItem: yearIndex);
      monthCtr = FixedExtentScrollController(initialItem: monthIndex);
      dayCtr = FixedExtentScrollController(initialItem: dayIndex);
      hourCtr = FixedExtentScrollController(initialItem: hourIndex);
      minuteCtr = FixedExtentScrollController(initialItem: minuteIndex);
      secondCtr = FixedExtentScrollController(initialItem: secondIndex);
    } else {
      ignore.isYear ? null : yearCtr.jumpToItem(yearIndex);
      ignore.isMonth ? null : monthCtr.jumpToItem(monthIndex);
      ignore.isDay ? null : dayCtr.jumpToItem(dayIndex);
      ignore.isHour ? null : hourCtr.jumpToItem(hourIndex);
      ignore.isMinute ? null : minuteCtr.jumpToItem(minuteIndex);
      ignore.isSecond ? null : secondCtr.jumpToItem(secondIndex);

      onPickerValueChanged();
    }

    setState(() {});
  }

  void onPickerValueChanged() {
    widget.onChange?.call(DateTime(year, month, day, hour, minute, second));
  }
}

extension _MmDatePickerSources on _FLXDatePickerState {
  int getFixedIndex(List<int> source, int value) {
    var index = source.indexOf(value);
    if (index == -1) {
      final nearestValue = getNearestValue(source, value);
      index = source.indexOf(nearestValue);
    }
    return index;
  }

  int getNearestValue(List<int> source, int value) {
    return value < source.first ? source.first : source.last;
  }

  List<int> getYearSource() {
    final minYear = minDate.year;
    final maxYear = maxDate.year;
    final yearCount = maxYear - minYear + 1;
    return List.generate(yearCount, (index) => minYear + index);
  }

  List<int> getMonthSource(int year) {
    int minMonth = 1;
    int maxMonth = 12;
    if (year == minDate.year) {
      minMonth = minDate.month;
    }
    if (year == maxDate.year) {
      maxMonth = maxDate.month;
    }
    final monthCount = maxMonth - minMonth + 1;
    return List.generate(monthCount, (index) => minMonth + index);
  }

  List<int> getDaySource(int year, int month) {
    final date = DateTime(year, month);
    int minDay = 1;
    int maxDay = date.daysInMonth;
    if (year == minDate.year && month == minDate.month) {
      minDay = minDate.day;
    }
    if (year == maxDate.year && month == maxDate.month) {
      maxDay = maxDate.day;
    }
    final dayCount = maxDay - minDay + 1;
    return List.generate(dayCount, (index) => minDay + index);
  }

  List<int> getHourSource(int year, int month, int day) {
    int minHour = 0;
    int maxHour = 23;
    if (year == minDate.year && month == minDate.month && day == minDate.day) {
      minHour = minDate.hour;
    }
    if (year == maxDate.year && month == maxDate.month && day == maxDate.day) {
      maxHour = maxDate.hour;
    }
    final hourCount = maxHour - minHour + 1;
    return List.generate(hourCount, (index) => minHour + index);
  }

  List<int> getMinuteSource(int year, int month, int day, int hour) {
    int minMinute = 0;
    int maxMinute = 59;
    if (year == minDate.year &&
        month == minDate.month &&
        day == minDate.day &&
        hour == minDate.hour) {
      minMinute = minDate.minute;
    }
    if (year == maxDate.year &&
        month == maxDate.month &&
        day == maxDate.day &&
        hour == maxDate.hour) {
      maxMinute = maxDate.minute;
    }
    final minuteCount = maxMinute - minMinute + 1;
    return List.generate(minuteCount, (index) => minMinute + index);
  }

  List<int> getSecondSource(
    int year,
    int month,
    int day,
    int hour,
    int minute,
  ) {
    int minSecond = 0;
    int maxSecond = 59;
    if (year == minDate.year &&
        month == minDate.month &&
        day == minDate.day &&
        hour == minDate.hour &&
        minute == minDate.minute) {
      minSecond = minDate.second;
    }
    if (year == maxDate.year &&
        month == maxDate.month &&
        day == maxDate.day &&
        hour == maxDate.hour &&
        minute == maxDate.minute) {
      maxSecond = maxDate.second;
    }
    final secondCount = maxSecond - minSecond + 1;
    return List.generate(secondCount, (index) => minSecond + index);
  }
}

class CBDatePickerFlex {
  final List<String> patterns;
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;

  const CBDatePickerFlex({
    required this.patterns,
    this.year = 1,
    this.month = 1,
    this.day = 1,
    this.hour = 1,
    this.minute = 1,
    this.second = 1,
  });

  static const List<String> all = ['MMM', 'dd', 'yyyy', 'HH', 'mm', 'ss'];
  static const List<String> mydHmPatterns = ['MMM', 'dd', 'yyyy', 'HH', 'mm'];
  static const List<String> mydHPatterns = ['MMM', 'dd', 'yyyy', 'HH'];
  static const List<String> mydPatterns = ['MMM', 'dd', 'yyyy'];
  static const List<String> mydH0Patterns = ['MMM', 'dd', 'yyyy', 'HH:00'];

  const CBDatePickerFlex.full() : this(patterns: all);

  const CBDatePickerFlex.mydHm() : this(patterns: mydHmPatterns);

  const CBDatePickerFlex.mydH() : this(patterns: mydHPatterns);

  const CBDatePickerFlex.myd() : this(patterns: mydPatterns);

  const CBDatePickerFlex.mydH0() : this(patterns: mydH0Patterns);
}

enum _RefreshSourceStyle {
  none,
  year,
  month,
  day,
  hour,
  minute,
  second,
  ;

  bool get isNone => this == none;

  bool get isYear => this == year;

  bool get isMonth => this == month;

  bool get isDay => this == day;

  bool get isHour => this == hour;

  bool get isMinute => this == minute;

  bool get isSecond => this == second;
}

class _CBWheelPicker extends StatelessWidget {
  final FixedExtentScrollController controller;
  final double itemHeight;
  final double magnification;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onSelectedItemChanged;
  final ValueChanged<bool>? onScrollChanged;

  const _CBWheelPicker({
    required this.controller,
    required this.itemHeight,
    this.magnification = 1.0,
    required this.itemCount,
    required this.itemBuilder,
    this.onSelectedItemChanged,
    this.onScrollChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _buildPickerList();
  }

  Widget _buildPickerList() {
    return NotificationListener(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          onScrollChanged?.call(true);
        } else if (notification is ScrollEndNotification) {
          onScrollChanged?.call(false);
        }
        if (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
          onSelectedItemChanged?.call(controller.selectedItem);
        }
        return false;
      },
      child: ListWheelScrollView.useDelegate(
        physics: const FixedExtentScrollPhysics(),
        controller: controller,
        itemExtent: itemHeight,
        diameterRatio: 1.2,
        overAndUnderCenterOpacity: 0.7,
        magnification: magnification,
        useMagnifier: true,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: itemBuilder,
        ),
      ),
    );
  }
}
