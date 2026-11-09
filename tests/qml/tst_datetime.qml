import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/datetime.js" as DateTime

TestCase {
    name: "DateTimeJs"

    function test_pad2() {
        compare(DateTime.pad2(3), "03")
        compare(DateTime.pad2(12), "12")
    }

    function test_digitsOnly() {
        compare(DateTime.digitsOnly("13.08.2026"), "13082026")
        compare(DateTime.digitsOnly(""), "")
    }

    function test_formatDigitsWithDateTokens() {
        var tokens = DateTime._parseFormatTokens("dd.MM.yyyy")
        compare(DateTime.maxDigitsFor(tokens), 8)
        compare(DateTime.formatDigitsWithTokens("13082026", tokens), "13.08.2026")
        compare(DateTime.formatDigitsWithTokens("13", tokens), "13")
    }

    function test_formatDigitsWithTimeTokens() {
        var tokens = DateTime._parseFormatTokens("HH:mm")
        compare(DateTime.formatDigitsWithTokens("0930", tokens), "09:30")
    }

    function test_parseIsoDateAndTime() {
        var d = DateTime.parseDate("2026-08-13")
        verify(d !== null)
        var t = DateTime.parseTime("9:05")
        compare(t.hours, 9)
        compare(t.minutes, 5)
        verify(DateTime.parseTime("25:00") === null)
        var combined = DateTime.combineDateTime("2026-08-13", "09:30", false)
        verify(combined !== null)
        var allDay = DateTime.combineDateTime("2026-08-13", "", true)
        verify(allDay !== null)
        verify(DateTime.combineDateTime("", "09:30", false) === null)
    }

    function test_segments() {
        var tokens = DateTime._parseFormatTokens("dd.MM.yyyy")
        var segs = DateTime.computeSegments("13.08.2026", tokens)
        compare(segs.length, 3)
        compare(DateTime.segmentAtPosition("13.08.2026", tokens, 4).kind, "month")
    }

    function test_isValidDate_rejectsInvalid() {
        verify(!DateTime.isValidDate(null))
        verify(!DateTime.isValidDate(undefined))
        verify(!DateTime.isValidDate(""))
        verify(!DateTime.isValidDate(new Date(Number.NaN)))
        var bad = new Date("not-a-date")
        verify(!DateTime.isValidDate(bad))
    }

    function test_isValidDate_acceptsValid() {
        var d = new Date(2026, 7, 13, 9, 30)
        verify(DateTime.isValidDate(d))
        compare(DateTime.isoDateKey(d), "2026-08-13")
    }

    function test_safeFormatDate_neverThrows() {
        compare(DateTime.safeFormatDate(null, "yyyy-MM-dd"), "")
        compare(DateTime.safeFormatDate(new Date(Number.NaN), "yyyy-MM-dd"), "")
        var d = new Date(2026, 7, 13)
        verify(DateTime.safeFormatDate(d, Qt.DefaultLocaleShortDate).length > 0)
    }

    function test_formatDueRowLabel_relativeToday() {
        var today = new Date()
        today.setHours(12, 0, 0, 0)
        var label = DateTime.formatDueRowLabel(today, {
            relativeDates: true,
            showTime: false,
            allDay: true,
            today: "TODAY",
            tomorrow: "TOMORROW",
            yesterday: "YESTERDAY"
        })
        compare(label, "TODAY")
    }

    function test_formatDueRowLabel_invalidDue() {
        compare(DateTime.formatDueRowLabel(null, {}), "")
        compare(DateTime.formatDueRowLabel(new Date(Number.NaN), {}), "")
    }

    // #27: day labels follow the locale's own order instead of fixed German formats.
    function test_localeDayFormats_data() {
        return [
            { tag: "de_DE", locale: "de_DE", longDayMonth: "dddd, d. MMMM", shortDayMonth: "ddd, d. MMM",
              dayMonth: "d. MMM", dayMonthYear: "d. MMM yyyy", monthYear: "MMMM yyyy", numeric: "d.M." },
            { tag: "en_US", locale: "en_US", longDayMonth: "dddd, MMMM d", shortDayMonth: "ddd, MMM d",
              dayMonth: "MMM d", dayMonthYear: "MMM d, yyyy", monthYear: "MMMM yyyy", numeric: "M/d" },
            { tag: "en_GB", locale: "en_GB", longDayMonth: "dddd, d MMMM", shortDayMonth: "ddd, d MMM",
              dayMonth: "d MMM", dayMonthYear: "d MMM yyyy", monthYear: "MMMM yyyy", numeric: "d/M" },
            { tag: "ja_JP", locale: "ja_JP", longDayMonth: "M月d日dddd", shortDayMonth: "M月d日ddd",
              dayMonth: "M月d日", dayMonthYear: "yyyy年M月d日", monthYear: "yyyy年M月", numeric: "M/d" },
            { tag: "es_ES", locale: "es_ES", longDayMonth: "dddd, d 'de' MMMM", shortDayMonth: "ddd, d 'de' MMM",
              dayMonth: "d 'de' MMM", dayMonthYear: "d 'de' MMM 'de' yyyy", monthYear: "MMMM 'de' yyyy", numeric: "d/M" },
        ]
    }

    function test_localeDayFormats(row) {
        var locale = Qt.locale(row.locale)
        compare(DateTime.longDayMonthFormat(locale), row.longDayMonth)
        compare(DateTime.shortDayMonthFormat(locale), row.shortDayMonth)
        compare(DateTime.dayMonthFormat(locale), row.dayMonth)
        compare(DateTime.dayMonthYearFormat(locale), row.dayMonthYear)
        compare(DateTime.monthYearFormat(locale), row.monthYear)
        compare(DateTime.numericDayMonthFormat(locale), row.numeric)
        compare(DateTime.longDateFormat(locale), locale.dateFormat(Locale.LongFormat))
    }

    function test_rangeStartFormat() {
        compare(DateTime.rangeStartFormat(Qt.locale("de_DE")), "d.")
        compare(DateTime.rangeStartFormat(Qt.locale("en_GB")), "d")
        compare(DateTime.rangeStartFormat(Qt.locale("en_US")), "MMM d")
        compare(DateTime.rangeStartFormat(Qt.locale("ja_JP")), "M月d日")
    }

    // Quoted suffixes stay whole (eu: "d('a')"), no unbalanced parenthesis.
    function test_quotedSuffix() {
        var eu = Qt.locale("eu_ES")
        var label = eu.toString(new Date(2026, 9, 29), DateTime.dayMonthFormat(eu))
        compare(label.split("(").length, label.split(")").length)
    }

    function test_localeDayLabels() {
        var day = new Date(2026, 9, 29)
        var en = Qt.locale("en_US")
        compare(en.toString(day, DateTime.longDayMonthFormat(en)), "Thursday, October 29")
        var de = Qt.locale("de_DE")
        compare(de.toString(day, DateTime.longDayMonthFormat(de)), "Donnerstag, 29. Oktober")
        compare(de.toString(day, DateTime.numericDayMonthFormat(de)), "29.10.")
        var ja = Qt.locale("ja_JP")
        compare(ja.toString(day, DateTime.longDayMonthFormat(ja)), "10月29日木曜日")
        compare(ja.toString(day, DateTime.monthYearFormat(ja)), "2026年10月")
    }

    // Headings use the standalone month name (nominative), not the one inside a date.
    function test_monthYearLabelStandalone() {
        var october = new Date(2026, 9, 29)
        compare(DateTime.monthYearLabel(october, false, Qt.locale("de_DE")), "Oktober 2026")
        compare(DateTime.monthYearLabel(october, false, Qt.locale("en_US")), "October 2026")
        compare(DateTime.monthYearLabel(october, false, Qt.locale("ja_JP")), "2026年10月")
        var ru = Qt.locale("ru_RU")
        var label = DateTime.monthYearLabel(october, false, ru)
        verify(label.indexOf(ru.standaloneMonthName(9, Locale.LongFormat)) === 0, label)
        verify(label.indexOf("2026") > 0, label)
        compare(DateTime.monthYearLabel(october, false, Qt.locale("es_ES")), "octubre de 2026")
        // Languages without inflection keep the format's abbreviation, period included.
        var de = Qt.locale("de_DE")
        compare(DateTime.monthYearLabel(october, true, de), de.toString(october, DateTime.monthYearFormat(de, true)))
    }

    function test_unquote() {
        compare(DateTime._unquote("'o''clock' 'de'"), "o'clock de")
        compare(DateTime._unquote("''"), "'")
    }

    // Separators that belong to a field stay with it.
    function test_dropKeepsFieldPunctuation() {
        compare(DateTime.longDayMonthFormat(Qt.locale("az_AZ")), "d MMMM, dddd")
        compare(DateTime.dayMonthFormat(Qt.locale("lt_LT")), "MMM d 'd'.")
    }

    function test_weekdayNumericOrder() {
        compare(DateTime.weekdayNumericFormat(Qt.locale("de_DE")), "ddd d.M.")
        compare(DateTime.weekdayNumericFormat(Qt.locale("en_US")), "ddd M/d")
        compare(DateTime.weekdayNumericFormat(Qt.locale("ja_JP")), "M/d ddd")
    }
}
