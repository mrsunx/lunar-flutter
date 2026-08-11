import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lunar/lunar.dart';

void main() {
  test('1900 至 2099 年历法结果摘要保持稳定', () {
    final yearDigest = StableDigest();
    final lunarDigest = StableDigest();
    for (var year = 1900; year <= 2099; year++) {
      final lunarYear = LunarYear(year);
      yearDigest.addInt(lunarYear.getYear());
      yearDigest.addString(lunarYear.getGanZhi());
      yearDigest.addInt(lunarYear.getLeapMonth());
      yearDigest.addInt(lunarYear.getDayCount());
      for (final value in lunarYear.getJieQiJulianDays()) {
        yearDigest.addDouble(value);
      }
      for (final month in lunarYear.getMonths()) {
        yearDigest.addInt(month.getYear());
        yearDigest.addInt(month.getMonth());
        yearDigest.addInt(month.getDayCount());
        yearDigest.addDouble(month.getFirstJulianDay());
        yearDigest.addInt(month.getIndex());
      }

      for (final solar in <Solar>[
        Solar.fromYmdHms(year, 1, 1, 0, 0, 0),
        Solar.fromYmdHms(year, 2, 4, 12, 0, 0),
        Solar.fromYmdHms(year, 6, 15, 23, 0, 0),
        Solar.fromYmdHms(year, 12, 31, 23, 59, 59),
      ]) {
        final lunar = solar.getLunar();
        final eightChar = lunar.getEightChar();
        lunarDigest.addString(solar.toYmdHms());
        lunarDigest.addString(solar.getFestivals().join('|'));
        lunarDigest.addInt(lunar.getYear());
        lunarDigest.addInt(lunar.getMonth());
        lunarDigest.addInt(lunar.getDay());
        lunarDigest.addString(lunar.getSolar().toYmdHms());
        lunarDigest.addString(lunar.getYearInGanZhi());
        lunarDigest.addString(lunar.getYearInGanZhiExact());
        lunarDigest.addString(lunar.getMonthInGanZhi());
        lunarDigest.addString(lunar.getMonthInGanZhiExact());
        lunarDigest.addString(lunar.getDayInGanZhi());
        lunarDigest.addString(lunar.getDayInGanZhiExact());
        lunarDigest.addString(lunar.getTimeInGanZhi());
        lunarDigest.addString(eightChar.getYear());
        lunarDigest.addString(eightChar.getMonth());
        lunarDigest.addString(eightChar.getDay());
        lunarDigest.addString(eightChar.getTime());
        lunarDigest.addString(lunar.getJieQi());
        lunarDigest.addString(lunar.getHou());
        lunarDigest.addString(lunar.getFestivals().join('|'));
        lunarDigest.addString(Foto.fromLunar(lunar).toFullString());
        lunarDigest.addString(Tao.fromLunar(lunar).toFullString());
      }
    }
    print('[LunarResultBaseline] lunar_year_digest=${yearDigest.value} '
        'lunar_digest=${lunarDigest.value}');
    expect(yearDigest.value, -7036848177040469134);
    expect(lunarDigest.value, -430029749232822440);
  });

  test('年度缓存命中并在超过 128 年后淘汰', () {
    final first = LunarYear.fromYear(1200);
    expect(identical(LunarYear.fromYear(1200), first), isTrue);

    for (var year = 1201; year <= 1328; year++) {
      LunarYear.fromYear(year);
    }

    expect(identical(LunarYear.fromYear(1200), first), isFalse);
  });

  test('年度缓存各容量阶段及淘汰后的 RSS', () {
    final before = ProcessInfo.currentRss;
    final rss = <int, int>{};
    for (var index = 1; index <= 256; index++) {
      LunarYear.fromYear(3000 + index);
      if (<int>[1, 10, 100, 128, 256].contains(index)) {
        rss[index] = ProcessInfo.currentRss;
      }
    }
    print('[LunarCacheMemory] before=$before rss_1=${rss[1]} '
        'rss_10=${rss[10]} rss_100=${rss[100]} rss_128=${rss[128]} '
        'rss_after_eviction=${rss[256]}');
    expect(rss.keys, containsAll(<int>[1, 10, 100, 128, 256]));
  });

  test('冷缓存首次访问与第二次访问分别测量', () {
    final first = <double>[];
    final second = <double>[];
    var checksum = 0;
    for (var index = 0; index < 10; index++) {
      final year = 5000 + index;
      final firstWatch = Stopwatch()..start();
      checksum += LunarYear.fromYear(year).getDayCount();
      firstWatch.stop();
      first.add(firstWatch.elapsedMicroseconds / 1000);

      final secondWatch = Stopwatch()..start();
      checksum += LunarYear.fromYear(year).getDayCount();
      secondWatch.stop();
      second.add(secondWatch.elapsedMicroseconds / 1000);
    }
    PerformanceMetric('lunar_year_first_access', first, 0, 0, checksum)
        .printResult();
    PerformanceMetric('lunar_year_second_access', second, 0, 0, checksum)
        .printResult();
    expect(first.length, second.length);
  });

  test('LunarYear 和 Lunar 构造性能基线', () {
    final years = List<int>.generate(100, (index) => 1900 + index);
    final metrics = <PerformanceMetric>[
      measure(
          'lunar_year_100_direct',
          () => years.fold(
              0, (sum, year) => sum + LunarYear(year).getDayCount())),
      measure(
          'lunar_year_100_from_year',
          () => years.fold(
              0, (sum, year) => sum + LunarYear.fromYear(year).getDayCount())),
      measure('lunar_year_100_alternating', () {
        var sum = 0;
        for (var index = 0; index < 100; index++) {
          sum += LunarYear.fromYear(index.isEven ? 1991 : 2026).getDayCount();
        }
        return sum;
      }),
      measure('lunar_100_same_year', () {
        var sum = 0;
        for (var index = 0; index < 100; index++) {
          sum += Solar.fromYmdHms(
                  2026, index % 12 + 1, index % 27 + 1, index % 24, 0, 0)
              .getLunar()
              .getDayZhiIndex();
        }
        return sum;
      }),
      measure(
          'lunar_100_spanning_years',
          () => years.fold(
              0,
              (sum, year) =>
                  sum +
                  Solar.fromYmdHms(year, 6, 15, 12, 0, 0)
                      .getLunar()
                      .getDayZhiIndex())),
      measure(
          'lunar_100_direct_lunar_date',
          () => years.fold(
              0,
              (sum, year) =>
                  sum +
                  Lunar.fromYmdHms(year, 1, 1, 12, 0, 0).getSolar().getDay())),
      measure(
          'lunar_100_from_date',
          () => years.fold(
              0,
              (sum, year) =>
                  sum +
                  Lunar.fromDate(DateTime(year, 6, 15, 12)).getDayZhiIndex())),
    ];
    for (final metric in metrics) {
      metric.printResult();
      expect(metric.samples.length, 5);
    }
  });

  test('ShouXingUtil 关键方法性能基线', () {
    final metrics = <PerformanceMetric>[
      measure('shouxing_calc_qi_100', () {
        var sum = 0;
        for (var index = 0; index < 100; index++) {
          sum += ShouXingUtil.calcQi((index - 50) * 365.2422).toInt();
        }
        return sum;
      }),
      measure('shouxing_qi_accurate2_100', () {
        var sum = 0;
        for (var index = 0; index < 100; index++) {
          sum += ShouXingUtil.qiAccurate2((index - 50) * 365.2422).toInt();
        }
        return sum;
      }),
      measure('shouxing_calc_shuo_100', () {
        var sum = 0;
        for (var index = 0; index < 100; index++) {
          sum += ShouXingUtil.calcShuo((index - 50) * 365.2422).toInt();
        }
        return sum;
      }),
    ];
    for (final metric in metrics) {
      metric.printResult();
      expect(metric.samples.length, 5);
    }
  });
}

PerformanceMetric measure(String name, int Function() operation) {
  final before = ProcessInfo.currentRss;
  final samples = <double>[];
  var checksum = 0;
  for (var index = 0; index < 5; index++) {
    final stopwatch = Stopwatch()..start();
    checksum += operation();
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds / 1000);
  }
  return PerformanceMetric(
      name, samples, before, ProcessInfo.currentRss, checksum);
}

class PerformanceMetric {
  PerformanceMetric(
      this.name, this.samples, this.rssBefore, this.rssAfter, this.checksum);

  final String name;
  final List<double> samples;
  final int rssBefore;
  final int rssAfter;
  final int checksum;

  void printResult() {
    final sorted = List<double>.from(samples)..sort();
    final total = samples.fold<double>(0, (sum, value) => sum + value);
    print('[LunarPerformance] name=$name samples=${samples.length} '
        'total_ms=${total.toStringAsFixed(3)} '
        'average_ms=${(total / samples.length).toStringAsFixed(3)} '
        'median_ms=${sorted[sorted.length ~/ 2].toStringAsFixed(3)} '
        'rss_before=$rssBefore rss_after=$rssAfter '
        'rss_delta=${rssAfter - rssBefore} checksum=$checksum');
  }
}

class StableDigest {
  static const int _mask = 0xFFFFFFFFFFFFFFFF;
  int value = 0xCBF29CE484222325;

  void addString(String input) {
    for (final byte in input.codeUnits) {
      _addByte(byte);
    }
    _addByte(0xFF);
  }

  void addInt(int input) {
    var bits = input & _mask;
    for (var shift = 0; shift < 64; shift += 8) {
      _addByte((bits >> shift) & 0xFF);
    }
  }

  void addDouble(double input) {
    final data = ByteData(8)..setFloat64(0, input, Endian.host);
    addInt(data.getUint64(0, Endian.host));
  }

  void _addByte(int byte) {
    value = ((value ^ byte) * 0x100000001B3) & _mask;
  }
}
