// seconds
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FLXDateUtils {
  static int yearsFrom(int? fromTime, int? endTime) {
    DateTime fromDate = (fromTime ?? 0).secondsToDate;
    DateTime endDate = (endTime ?? 0).secondsToDate;
    if ((endDate.day >= fromDate.day) && (endDate.month >= fromDate.month)) {
      return endDate.year - fromDate.year;
    }
    return endDate.year - fromDate.year - 1;
  }

  static int daysFrom(int? fromTime, int? endTime) {
    int misOfADay = 24 * 60 * 60;
    int fromDays = (fromTime ?? 0) ~/ misOfADay;
    int endDays = (endTime ?? 0) ~/ misOfADay;
    return endDays - fromDays;
  }

  // seconds
  static int daysFromNow(int? fromTime) {
    return daysFrom(
        (fromTime ?? 0).secondsToDate.trimTimeOfDay().secondsSinceEpoch,
        DateTime.now().trimTimeOfDay().secondsSinceEpoch);
  }

  // seconds
  static int yearsFromNow(int? fromTime) {
    return yearsFrom(fromTime, DateTime.now().secondsSinceEpoch);
  }

  static bool isToday(int? fromTime) {
    return daysFromNow(fromTime) == 0;
  }

  static int? daysInMonth(int month, int year) {
    if (month > 12) {
      return null;
    }
    // month 1~12
    var monthLen = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (isLeapYear(year)) {
      monthLen[1] = 29;
    }
    return monthLen[month - 1];
  }

  static bool isLeapYear(int year) {
    bool leapYear = false;
    bool leap = ((year % 100 == 0) && (year % 400 != 0));
    if (leap == true) {
      leapYear = false;
    } else if (year % 4 == 0) {
      leapYear = true;
    }
    return leapYear;
  }
}

extension DateTimeExt on DateTime {
  int get secondsSinceEpoch {
    return millisecondsSinceEpoch ~/ 1000;
  }

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  int get secondsOfDay => 60 * 60 * hour + 60 * minute + second;

  int get daysInMonth => FLXDateUtils.daysInMonth(month, year) ?? 0;

  String formatString([String? pattern, String? local]) =>
      DateFormat(pattern, local).format(this);

  DateTime replaceTimeOfDay(TimeOfDay timeOfDay) {
    int interval = secondsSinceEpoch;
    interval -= secondsOfDay;
    interval += timeOfDay.timeOfSeconds;
    return DateTime.fromMillisecondsSinceEpoch(1000 * interval);
  }

  DateTime trimTimeOfDay() {
    return replaceTimeOfDay(const TimeOfDay(hour: 0, minute: 0));
  }

  static DateTime fromSeconds(int? seconds) =>
      DateTime.fromMillisecondsSinceEpoch(1000 * (seconds ?? 0));
}

extension TimeOfDayExt on TimeOfDay {
  Duration get duration => Duration(hours: hour, minutes: minute);

  int get timeOfSeconds => 60 * 60 * hour + 60 * minute;
}

extension DateTimeSeconds on int {
  String formatDateString([String? pattern, String? local = 'en_us']) =>
      DateFormat(pattern, local).format(secondsToDate);

  DateTime get secondsToDate =>
      DateTime.fromMillisecondsSinceEpoch(1000 * this);
}

extension DateTimeString on String {
  DateTime formatDate([String? pattern, String? local]) =>
      DateFormat(pattern, local).parse(this);

  bool get patternHasYear => contains('y');

  bool get patternHasMonth => contains('M');

  bool get patternHasDay => contains('d');

  bool get patternHasHour => contains('H') || contains('h');

  bool get patternHasMinute => contains('m');

  bool get patternHasSecond => contains('s');
}
