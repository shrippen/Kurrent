#include "tasklogic.h"

#include <QRegularExpression>
#include <QSet>
#include <QVector>
#include <algorithm>
#include <cmath>

namespace TaskLogic
{
namespace {

QString langCode(const QString &uiLanguage)
{
    QString code = uiLanguage.trimmed().toLower();
    int cut = code.indexOf(QLatin1Char('_'));
    const int dash = code.indexOf(QLatin1Char('-'));
    if (cut < 0 || (dash >= 0 && dash < cut)) {
        cut = dash;
    }
    if (cut >= 0) {
        code = code.left(cut);
    }
    return code;
}

QStringList activeLangs(const QString &uiLanguage)
{
    QStringList langs;
    langs.append(QStringLiteral("en"));
    const QString code = langCode(uiLanguage);
    if (!code.isEmpty() && code != QLatin1String("en") && !langs.contains(code)) {
        langs.append(code);
    }
    return langs;
}

QString fold(const QString &input)
{
    QString decomposed = input.trimmed().toLower().normalized(QString::NormalizationForm_D);
    QString out;
    out.reserve(decomposed.size());
    for (const QChar c : decomposed) {
        const QChar::Category cat = c.category();
        if (cat == QChar::Mark_NonSpacing || cat == QChar::Mark_SpacingCombining || cat == QChar::Mark_Enclosing) {
            continue;
        }
        if (c == QLatin1Char('\'') || c == QChar(0x2019) || c == QChar(0x00B4)) {
            continue;
        }
        if (c == QChar(0x00DF)) {
            out += QLatin1String("ss");
            continue;
        }
        out += c;
    }
    return out;
}

bool looksCjk(const QString &s)
{
    for (const QChar c : s) {
        if (c.unicode() >= 0x3040) {
            return true;
        }
    }
    return false;
}

int editDistance(const QString &a, const QString &b, int maxDist)
{
    const int n = a.size();
    const int m = b.size();
    if (qAbs(n - m) > maxDist) {
        return maxDist + 1;
    }
    if (n == 0) {
        return m;
    }
    if (m == 0) {
        return n;
    }

    QVector<int> prev2(m + 1, 0);
    QVector<int> prev(m + 1);
    QVector<int> cur(m + 1);
    for (int j = 0; j <= m; ++j) {
        prev[j] = j;
    }
    for (int i = 1; i <= n; ++i) {
        cur[0] = i;
        int rowMin = cur[0];
        for (int j = 1; j <= m; ++j) {
            const int cost = a.at(i - 1) == b.at(j - 1) ? 0 : 1;
            cur[j] = std::min({prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost});
            if (i > 1 && j > 1 && a.at(i - 1) == b.at(j - 2) && a.at(i - 2) == b.at(j - 1)) {
                cur[j] = std::min(cur[j], prev2[j - 2] + 1);
            }
            rowMin = std::min(rowMin, cur[j]);
        }
        if (rowMin > maxDist) {
            return maxDist + 1;
        }
        prev2.swap(prev);
        prev.swap(cur);
    }
    return prev[m];
}

int maxTypoDistance(const QString &query, bool prefixed)
{
    if (looksCjk(query)) {
        return 0;
    }
    if (query.size() >= 8) {
        return 2;
    }
    if (query.size() >= 5) {
        return 1;
    }
    if (prefixed && query.size() >= 3) {
        return 1;
    }
    return 0;
}

int matchScore(const QString &query, const QString &candidate, bool allowPrefix, bool prefixed = false)
{
    if (query.isEmpty() || candidate.isEmpty()) {
        return -1;
    }
    if (query == candidate) {
        return 4000;
    }
    if (allowPrefix && candidate.startsWith(query)) {
        return 3000 - (candidate.size() - query.size());
    }
    const int maxDist = maxTypoDistance(query, prefixed);
    if (maxDist <= 0) {
        return -1;
    }
    const int dist = editDistance(query, candidate, maxDist);
    if (dist > maxDist) {
        return -1;
    }
    return 2500 - dist * 80 - qAbs(candidate.size() - query.size());
}

enum class DateKind {
    Today,
    Tomorrow,
    Yesterday,
    NextWeek,
    Tonight,
    Weekday,
};

struct DatePhrase {
    QString folded;
    QString insert;
    DateKind kind = DateKind::Today;
    int weekday = 0;
    bool nextOccurrence = false;
    int hour = -1;
};

struct PrioAlias {
    QString folded;
    QString insert;
    int priority = 0;
};

void addPhrase(QList<DatePhrase> &out, const QString &phrase, DateKind kind, int weekday = 0, bool nextOccurrence = false, int hour = -1)
{
    DatePhrase p;
    p.folded = fold(phrase);
    p.insert = phrase;
    p.kind = kind;
    p.weekday = weekday;
    p.nextOccurrence = nextOccurrence;
    p.hour = hour;
    if (!p.folded.isEmpty()) {
        out.append(p);
    }
}

QList<DatePhrase> datePhrasesFor(const QStringList &langs)
{
    QList<DatePhrase> out;
    auto has = [&](const char *code) {
        return langs.contains(QLatin1String(code));
    };

    addPhrase(out, QStringLiteral("today"), DateKind::Today);
    addPhrase(out, QStringLiteral("tomorrow"), DateKind::Tomorrow);
    addPhrase(out, QStringLiteral("yesterday"), DateKind::Yesterday);
    addPhrase(out, QStringLiteral("tonight"), DateKind::Tonight, 0, false, 20);
    addPhrase(out, QStringLiteral("next week"), DateKind::NextWeek);
    const QStringList enDays = {
        QStringLiteral("monday"), QStringLiteral("tuesday"), QStringLiteral("wednesday"),
        QStringLiteral("thursday"), QStringLiteral("friday"), QStringLiteral("saturday"),
        QStringLiteral("sunday"),
    };
    for (int i = 0; i < enDays.size(); ++i) {
        addPhrase(out, enDays.at(i), DateKind::Weekday, i + 1);
        addPhrase(out, QStringLiteral("next ") + enDays.at(i), DateKind::Weekday, i + 1, true);
    }

    if (has("de")) {
        addPhrase(out, QStringLiteral("heute"), DateKind::Today);
        addPhrase(out, QStringLiteral("morgen"), DateKind::Tomorrow);
        addPhrase(out, QStringLiteral("gestern"), DateKind::Yesterday);
        addPhrase(out, QStringLiteral("heute abend"), DateKind::Tonight, 0, false, 20);
        addPhrase(out, QStringLiteral("nächste woche"), DateKind::NextWeek);
        addPhrase(out, QStringLiteral("naechste woche"), DateKind::NextWeek);
        const QStringList deDays = {
            QStringLiteral("montag"), QStringLiteral("dienstag"), QStringLiteral("mittwoch"),
            QStringLiteral("donnerstag"), QStringLiteral("freitag"), QStringLiteral("samstag"),
            QStringLiteral("sonntag"),
        };
        for (int i = 0; i < deDays.size(); ++i) {
            addPhrase(out, deDays.at(i), DateKind::Weekday, i + 1);
            addPhrase(out, QStringLiteral("nächsten ") + deDays.at(i), DateKind::Weekday, i + 1, true);
            addPhrase(out, QStringLiteral("nächster ") + deDays.at(i), DateKind::Weekday, i + 1, true);
            addPhrase(out, QStringLiteral("nächste ") + deDays.at(i), DateKind::Weekday, i + 1, true);
        }
    }
    if (has("es")) {
        addPhrase(out, QStringLiteral("hoy"), DateKind::Today);
        addPhrase(out, QStringLiteral("mañana"), DateKind::Tomorrow);
        addPhrase(out, QStringLiteral("manana"), DateKind::Tomorrow);
        addPhrase(out, QStringLiteral("ayer"), DateKind::Yesterday);
        addPhrase(out, QStringLiteral("esta noche"), DateKind::Tonight, 0, false, 20);
        addPhrase(out, QStringLiteral("próxima semana"), DateKind::NextWeek);
        addPhrase(out, QStringLiteral("proxima semana"), DateKind::NextWeek);
        const QStringList esDays = {
            QStringLiteral("lunes"), QStringLiteral("martes"), QStringLiteral("miércoles"),
            QStringLiteral("jueves"), QStringLiteral("viernes"), QStringLiteral("sábado"),
            QStringLiteral("domingo"),
        };
        for (int i = 0; i < esDays.size(); ++i) {
            addPhrase(out, esDays.at(i), DateKind::Weekday, i + 1);
        }
    }
    if (has("fr")) {
        addPhrase(out, QStringLiteral("aujourd'hui"), DateKind::Today);
        addPhrase(out, QStringLiteral("demain"), DateKind::Tomorrow);
        addPhrase(out, QStringLiteral("hier"), DateKind::Yesterday);
        addPhrase(out, QStringLiteral("ce soir"), DateKind::Tonight, 0, false, 20);
        addPhrase(out, QStringLiteral("semaine prochaine"), DateKind::NextWeek);
        const QStringList frDays = {
            QStringLiteral("lundi"), QStringLiteral("mardi"), QStringLiteral("mercredi"),
            QStringLiteral("jeudi"), QStringLiteral("vendredi"), QStringLiteral("samedi"),
            QStringLiteral("dimanche"),
        };
        for (int i = 0; i < frDays.size(); ++i) {
            addPhrase(out, frDays.at(i), DateKind::Weekday, i + 1);
            addPhrase(out, frDays.at(i) + QStringLiteral(" prochain"), DateKind::Weekday, i + 1, true);
        }
    }
    if (has("ja")) {
        addPhrase(out, QStringLiteral("今日"), DateKind::Today);
        addPhrase(out, QStringLiteral("明日"), DateKind::Tomorrow);
        addPhrase(out, QStringLiteral("昨日"), DateKind::Yesterday);
        addPhrase(out, QStringLiteral("来週"), DateKind::NextWeek);
    }
    if (has("zh")) {
        addPhrase(out, QStringLiteral("今天"), DateKind::Today);
        addPhrase(out, QStringLiteral("明天"), DateKind::Tomorrow);
        addPhrase(out, QStringLiteral("昨天"), DateKind::Yesterday);
        addPhrase(out, QStringLiteral("下周"), DateKind::NextWeek);
        addPhrase(out, QStringLiteral("下週"), DateKind::NextWeek);
    }
    return out;
}

QList<PrioAlias> priorityAliasesFor(const QStringList &langs)
{
    QList<PrioAlias> out;
    auto add = [&](const QString &word, int priority) {
        PrioAlias a;
        a.folded = fold(word);
        a.insert = QLatin1Char('!') + word;
        a.priority = priority;
        out.append(a);
    };
    add(QStringLiteral("high"), 1);
    add(QStringLiteral("medium"), 5);
    add(QStringLiteral("med"), 5);
    add(QStringLiteral("low"), 9);
    add(QStringLiteral("none"), 0);
    if (langs.contains(QLatin1String("de"))) {
        add(QStringLiteral("hoch"), 1);
        add(QStringLiteral("mittel"), 5);
        add(QStringLiteral("niedrig"), 9);
        add(QStringLiteral("keine"), 0);
    }
    if (langs.contains(QLatin1String("es"))) {
        add(QStringLiteral("alta"), 1);
        add(QStringLiteral("media"), 5);
        add(QStringLiteral("baja"), 9);
    }
    if (langs.contains(QLatin1String("fr"))) {
        add(QStringLiteral("haute"), 1);
        add(QStringLiteral("moyenne"), 5);
        add(QStringLiteral("basse"), 9);
    }
    if (langs.contains(QLatin1String("ja"))) {
        add(QStringLiteral("高"), 1);
        add(QStringLiteral("中"), 5);
        add(QStringLiteral("低"), 9);
    }
    if (langs.contains(QLatin1String("zh"))) {
        add(QStringLiteral("高"), 1);
        add(QStringLiteral("中"), 5);
        add(QStringLiteral("低"), 9);
    }
    return out;
}

struct Tok {
    int start = 0;
    int length = 0;
    QString raw;
    QString folded;
    QChar prefix;
    bool used = false;
};

QList<Tok> tokenize(const QString &raw)
{
    QList<Tok> toks;
    int i = 0;
    const int n = raw.size();
    while (i < n) {
        while (i < n && raw.at(i).isSpace()) {
            ++i;
        }
        if (i >= n) {
            break;
        }
        const int start = i;
        while (i < n && !raw.at(i).isSpace()) {
            ++i;
        }
        Tok t;
        t.start = start;
        t.length = i - start;
        t.raw = raw.mid(start, t.length);
        t.prefix = QChar();
        QString body = t.raw;
        if (!body.isEmpty()) {
            const QChar first = body.at(0);
            if (first == QLatin1Char('!') || first == QLatin1Char('#') || first == QLatin1Char('@')) {
                t.prefix = first;
                body = body.mid(1);
            }
        }
        t.folded = fold(body);
        toks.append(t);
    }
    return toks;
}

QString joinFolded(const QList<Tok> &toks, int index, int count)
{
    QString s = toks.at(index).folded;
    for (int k = 1; k < count; ++k) {
        s += QLatin1Char(' ');
        s += toks.at(index + k).folded;
    }
    return s;
}

int spanLength(const QList<Tok> &toks, int index, int count)
{
    const Tok &last = toks.at(index + count - 1);
    return last.start + last.length - toks.at(index).start;
}

QDate applyDate(DateKind kind, int weekday, bool nextOccurrence, const QDate &today)
{
    switch (kind) {
    case DateKind::Today:
    case DateKind::Tonight:
        return today;
    case DateKind::Tomorrow:
        return today.addDays(1);
    case DateKind::Yesterday:
        return today.addDays(-1);
    case DateKind::NextWeek:
        return today.addDays(7);
    case DateKind::Weekday: {
        int diff = weekday - today.dayOfWeek();
        if (nextOccurrence) {
            if (diff <= 0) {
                diff += 7;
            }
        } else if (diff < 0) {
            diff += 7;
        }
        return today.addDays(diff);
    }
    }
    return today;
}

QString dateValue(DateKind kind, int weekday)
{
    switch (kind) {
    case DateKind::Today:
        return QStringLiteral("today");
    case DateKind::Tomorrow:
        return QStringLiteral("tomorrow");
    case DateKind::Yesterday:
        return QStringLiteral("yesterday");
    case DateKind::NextWeek:
        return QStringLiteral("nextweek");
    case DateKind::Tonight:
        return QStringLiteral("tonight");
    case DateKind::Weekday: {
        static const QStringList names = {
            QStringLiteral("monday"), QStringLiteral("tuesday"), QStringLiteral("wednesday"),
            QStringLiteral("thursday"), QStringLiteral("friday"), QStringLiteral("saturday"),
            QStringLiteral("sunday"),
        };
        if (weekday >= 1 && weekday <= 7) {
            return names.at(weekday - 1);
        }
        return QStringLiteral("weekday");
    }
    }
    return QStringLiteral("date");
}

bool parseTimeToken(const QString &raw, QTime *out)
{
    static const QRegularExpression re(
        QStringLiteral(R"(^(\d{1,2})(?::(\d{2}))?\s*(am|pm|uhr|h)?$)"),
        QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch m = re.match(raw.trimmed());
    if (!m.hasMatch()) {
        static const QRegularExpression compact(QStringLiteral(R"(^(\d{1,2})h(\d{2})$)"),
                                                QRegularExpression::CaseInsensitiveOption);
        const QRegularExpressionMatch h = compact.match(raw.trimmed());
        if (!h.hasMatch()) {
            return false;
        }
        const int hour = h.captured(1).toInt();
        const int minute = h.captured(2).toInt();
        if (hour > 23 || minute > 59) {
            return false;
        }
        *out = QTime(hour, minute);
        return true;
    }

    const QString suffix = m.captured(3).toLower();
    if (m.captured(2).isEmpty() && suffix.isEmpty()) {
        return false;
    }

    int hour = m.captured(1).toInt();
    const int minute = m.captured(2).isEmpty() ? 0 : m.captured(2).toInt();
    if (minute > 59) {
        return false;
    }
    if (suffix == QLatin1String("am") || suffix == QLatin1String("pm")) {
        if (hour < 1 || hour > 12) {
            return false;
        }
        if (suffix == QLatin1String("am")) {
            if (hour == 12) {
                hour = 0;
            }
        } else if (hour != 12) {
            hour += 12;
        }
    } else if (hour > 23) {
        return false;
    }
    *out = QTime(hour, minute);
    return true;
}

QString canonicalPrioInsert(int priority, const QStringList &langs)
{
    if (priority <= 0) {
        if (langs.contains(QLatin1String("de"))) {
            return QStringLiteral("!keine");
        }
        return QStringLiteral("!none");
    }
    if (priority <= 3) {
        if (langs.contains(QLatin1String("de"))) {
            return QStringLiteral("!hoch");
        }
        return QStringLiteral("!high");
    }
    if (priority <= 6) {
        if (langs.contains(QLatin1String("de"))) {
            return QStringLiteral("!mittel");
        }
        return QStringLiteral("!medium");
    }
    if (langs.contains(QLatin1String("de"))) {
        return QStringLiteral("!niedrig");
    }
    return QStringLiteral("!low");
}

struct DateHit {
    const DatePhrase *phrase = nullptr;
    int score = -1;
};

DateHit bestDatePhrase(const QString &folded, const QList<DatePhrase> &phrases, bool allowPrefix)
{
    DateHit best;
    for (const DatePhrase &p : phrases) {
        const int score = matchScore(folded, p.folded, allowPrefix, false);
        if (score > best.score) {
            best.score = score;
            best.phrase = &p;
        }
    }
    return best;
}

struct PrioHit {
    const PrioAlias *alias = nullptr;
    int score = -1;
    int numeric = -1;
};

PrioHit bestPriority(const QString &folded, const QList<PrioAlias> &aliases, bool allowPrefix)
{
    PrioHit best;
    if (folded.size() == 1 && folded.at(0).isDigit()) {
        const int n = folded.toInt();
        if (n >= 1 && n <= 9) {
            best.numeric = n;
            best.score = 4000;
            return best;
        }
    }
    for (const PrioAlias &a : aliases) {
        const int score = matchScore(folded, a.folded, allowPrefix, true);
        if (score > best.score) {
            best.score = score;
            best.alias = &a;
        }
    }
    return best;
}

int tokenAtCursor(const QList<Tok> &toks, const QString &raw, int cursor)
{
    cursor = qBound(0, cursor, raw.size());
    for (int i = 0; i < toks.size(); ++i) {
        const int end = toks.at(i).start + toks.at(i).length;
        if (cursor >= toks.at(i).start && cursor <= end) {
            return i;
        }
    }
    if (!toks.isEmpty() && cursor >= toks.last().start + toks.last().length) {
        if (cursor < raw.size() && raw.at(cursor - (cursor > 0 ? 1 : 0)).isSpace()) {
            return -1;
        }
    }
    return -1;
}

QList<QuickAddSuggestion> projectSuggestions(const QString &query, const QList<QuickAddProject> &projects, int tokenStart, int tokenEnd)
{
    QList<QuickAddSuggestion> items;
    const QString q = fold(query);
    for (const QuickAddProject &p : projects) {
        const QString nameFold = fold(p.name);
        int score = matchScore(q, nameFold, true, true);
        if (score < 0 && q.isEmpty()) {
            score = 1000;
        } else if (score < 0 && nameFold.contains(q) && q.size() >= 2) {
            score = 1500 - nameFold.indexOf(q);
        }
        if (score < 0) {
            continue;
        }
        QuickAddSuggestion s;
        s.kind = QStringLiteral("project");
        s.insertText = QLatin1Char('@') + p.name;
        s.value = QString::number(p.id);
        s.collectionId = p.id;
        s.tokenStart = tokenStart;
        s.tokenEnd = tokenEnd;
        s.score = score;
        items.append(s);
    }
    std::sort(items.begin(), items.end(), [](const QuickAddSuggestion &a, const QuickAddSuggestion &b) {
        if (a.score != b.score) {
            return a.score > b.score;
        }
        return a.insertText.localeAwareCompare(b.insertText) < 0;
    });
    if (items.size() > 8) {
        items = items.mid(0, 8);
    }
    return items;
}

QList<QuickAddSuggestion> labelSuggestions(const QString &query, const QStringList &labels, int tokenStart, int tokenEnd)
{
    QList<QuickAddSuggestion> items;
    const QString q = fold(query);
    QSet<QString> seen;
    for (const QString &label : labels) {
        const QString nameFold = fold(label);
        int score = matchScore(q, nameFold, true, true);
        if (score < 0 && q.isEmpty()) {
            score = 1000;
        } else if (score < 0 && nameFold.contains(q) && q.size() >= 2) {
            score = 1500 - nameFold.indexOf(q);
        }
        if (score < 0) {
            continue;
        }
        seen.insert(nameFold);
        QuickAddSuggestion s;
        s.kind = QStringLiteral("label");
        s.insertText = QLatin1Char('#') + label;
        s.value = label;
        s.tokenStart = tokenStart;
        s.tokenEnd = tokenEnd;
        s.score = score;
        items.append(s);
    }
    if (!q.isEmpty() && !seen.contains(q)) {
        QuickAddSuggestion s;
        s.kind = QStringLiteral("label");
        s.insertText = QLatin1Char('#') + query;
        s.value = query;
        s.tokenStart = tokenStart;
        s.tokenEnd = tokenEnd;
        s.score = 500;
        items.append(s);
    }
    std::sort(items.begin(), items.end(), [](const QuickAddSuggestion &a, const QuickAddSuggestion &b) {
        if (a.score != b.score) {
            return a.score > b.score;
        }
        return a.insertText.localeAwareCompare(b.insertText) < 0;
    });
    if (items.size() > 8) {
        items = items.mid(0, 8);
    }
    return items;
}

} // namespace

QuickAdd parseQuickAdd(const QString &raw, const QDate &today, const QTime &now)
{
    return parseQuickAdd(raw, today, now, QuickAddContext{});
}

QuickAdd parseQuickAdd(const QString &rawIn, const QDate &today, const QTime &now, const QuickAddContext &ctx)
{
    QuickAdd out;
    const QString raw = rawIn;
    const QString trimmed = raw.trimmed();
    if (trimmed.isEmpty()) {
        return out;
    }

    const QStringList langs = activeLangs(ctx.uiLanguage);
    const QList<DatePhrase> phrases = datePhrasesFor(langs);
    const QList<PrioAlias> prios = priorityAliasesFor(langs);
    QList<Tok> toks = tokenize(raw);

    QDate dueDate;
    QTime dueTime;
    bool sawDate = false;
    bool sawTime = false;
    int tonightHour = -1;

    auto markSpan = [&](int start, int length, const QString &kind, const QString &value) {
        QuickAddSpan span;
        span.start = start;
        span.length = length;
        span.kind = kind;
        span.value = value;
        out.spans.append(span);
    };

    for (Tok &tok : toks) {
        if (tok.prefix != QLatin1Char('!')) {
            continue;
        }
        const PrioHit hit = bestPriority(tok.folded, prios, false);
        if (hit.score >= 2000) {
            out.priority = hit.numeric >= 0 ? hit.numeric : hit.alias->priority;
            markSpan(tok.start, tok.length, QStringLiteral("priority"), QString::number(out.priority));
            tok.used = true;
        }
    }

    for (Tok &tok : toks) {
        if (tok.prefix != QLatin1Char('#')) {
            continue;
        }
        QString label = tok.raw.mid(1);
        int bestScore = -1;
        QString bestLabel;
        int ties = 0;
        for (const QString &known : ctx.labels) {
            const int score = matchScore(tok.folded, fold(known), false, true);
            if (score > bestScore) {
                bestScore = score;
                bestLabel = known;
                ties = 1;
            } else if (score == bestScore && score >= 0) {
                ++ties;
            }
        }
        if (bestScore >= 2000 && ties == 1) {
            label = bestLabel;
        }
        if (!label.isEmpty()) {
            out.labels.append(label);
            markSpan(tok.start, tok.length, QStringLiteral("label"), label);
            tok.used = true;
        }
    }

    for (Tok &tok : toks) {
        if (tok.prefix != QLatin1Char('@')) {
            continue;
        }
        int bestScore = -1;
        const QuickAddProject *best = nullptr;
        int ties = 0;
        for (const QuickAddProject &p : ctx.projects) {
            const int score = matchScore(tok.folded, fold(p.name), false, true);
            if (score > bestScore) {
                bestScore = score;
                best = &p;
                ties = 1;
            } else if (score == bestScore && score >= 0) {
                ++ties;
            }
        }
        if (best && bestScore >= 2000 && ties == 1) {
            out.collectionId = best->id;
            markSpan(tok.start, tok.length, QStringLiteral("project"), QString::number(best->id));
            tok.used = true;
        }
    }

    for (int i = 0; i < toks.size(); ++i) {
        Tok &tok = toks[i];
        if (tok.used || tok.prefix.unicode() != 0) {
            continue;
        }
        QTime parsed;
        if (parseTimeToken(tok.raw, &parsed)) {
            dueTime = parsed;
            sawTime = true;
            markSpan(tok.start, tok.length, QStringLiteral("time"), parsed.toString(QStringLiteral("HH:mm")));
            tok.used = true;
            continue;
        }
        if (i + 1 < toks.size() && !toks[i + 1].used && toks[i + 1].prefix.unicode() == 0) {
            const QString nextFold = toks[i + 1].folded;
            if ((nextFold == QLatin1String("uhr") || nextFold == QLatin1String("h")) && langs.contains(QLatin1String("de"))) {
                bool ok = false;
                const int hour = tok.folded.toInt(&ok);
                if (ok && hour >= 0 && hour <= 23) {
                    dueTime = QTime(hour, 0);
                    sawTime = true;
                    markSpan(tok.start, spanLength(toks, i, 2), QStringLiteral("time"), dueTime.toString(QStringLiteral("HH:mm")));
                    tok.used = true;
                    toks[i + 1].used = true;
                    ++i;
                }
            }
        }
    }

    for (int count = 3; count >= 1; --count) {
        for (int i = 0; i + count <= toks.size(); ++i) {
            bool blocked = false;
            for (int k = 0; k < count; ++k) {
                if (toks[i + k].used || toks[i + k].prefix.unicode() != 0) {
                    blocked = true;
                    break;
                }
            }
            if (blocked) {
                continue;
            }
            const QString joined = joinFolded(toks, i, count);
            const DateHit hit = bestDatePhrase(joined, phrases, false);
            if (!hit.phrase || hit.score < 2000) {
                continue;
            }
            if (count == 1 && hit.phrase->folded.contains(QLatin1Char(' '))) {
                continue;
            }
            dueDate = applyDate(hit.phrase->kind, hit.phrase->weekday, hit.phrase->nextOccurrence, today);
            sawDate = true;
            if (hit.phrase->hour >= 0) {
                tonightHour = hit.phrase->hour;
            }
            markSpan(toks[i].start, spanLength(toks, i, count), QStringLiteral("date"),
                     dateValue(hit.phrase->kind, hit.phrase->weekday));
            for (int k = 0; k < count; ++k) {
                toks[i + k].used = true;
            }
        }
    }

    QString summary;
    for (const Tok &tok : toks) {
        if (tok.used) {
            continue;
        }
        if (!summary.isEmpty()) {
            summary += QLatin1Char(' ');
        }
        summary += tok.raw;
    }
    out.summary = summary.simplified();

    if (sawDate || sawTime || tonightHour >= 0) {
        out.hasDue = true;
        if (!sawDate) {
            dueDate = today;
            if (sawTime && dueTime.isValid() && dueTime < now) {
                dueDate = today.addDays(1);
            }
        }
        if (!sawTime && tonightHour >= 0) {
            dueTime = QTime(tonightHour, 0);
            sawTime = true;
        }
        out.allDay = !sawTime;
        out.due = QDateTime(dueDate, sawTime ? dueTime : QTime(0, 0));
    }
    return out;
}

QuickAddSuggestResult suggestQuickAdd(const QString &raw, int cursor, const QuickAddContext &ctx)
{
    QuickAddSuggestResult result;
    const QStringList langs = activeLangs(ctx.uiLanguage);
    const QList<DatePhrase> phrases = datePhrasesFor(langs);
    const QList<PrioAlias> prios = priorityAliasesFor(langs);
    const QList<Tok> toks = tokenize(raw);
    const int index = tokenAtCursor(toks, raw, cursor);
    if (index < 0) {
        return result;
    }

    const Tok &tok = toks.at(index);
    result.tokenStart = tok.start;
    result.tokenEnd = tok.start + tok.length;

    auto pushUnique = [&](QuickAddSuggestion s) {
        s.tokenStart = result.tokenStart;
        s.tokenEnd = result.tokenEnd;
        for (const QuickAddSuggestion &existing : result.items) {
            if (existing.kind == s.kind && existing.value == s.value) {
                return;
            }
        }
        result.items.append(s);
    };

    if (tok.prefix == QLatin1Char('@')) {
        result.items = projectSuggestions(tok.raw.mid(1), ctx.projects, result.tokenStart, result.tokenEnd);
        return result;
    }
    if (tok.prefix == QLatin1Char('#')) {
        result.items = labelSuggestions(tok.raw.mid(1), ctx.labels, result.tokenStart, result.tokenEnd);
        return result;
    }
    if (tok.prefix == QLatin1Char('!')) {
        QSet<int> seen;
        const PrioHit hit = bestPriority(tok.folded, prios, true);
        auto addPrio = [&](int priority, const QString &insert, int score) {
            if (seen.contains(priority)) {
                return;
            }
            seen.insert(priority);
            QuickAddSuggestion s;
            s.kind = QStringLiteral("priority");
            s.insertText = insert;
            s.value = QString::number(priority);
            s.priority = priority;
            s.score = score;
            pushUnique(s);
        };
        if (tok.folded.isEmpty()) {
            addPrio(1, canonicalPrioInsert(1, langs), 3000);
            addPrio(5, canonicalPrioInsert(5, langs), 2900);
            addPrio(9, canonicalPrioInsert(9, langs), 2800);
            addPrio(0, canonicalPrioInsert(0, langs), 2700);
        } else {
            if (hit.numeric >= 0) {
                addPrio(hit.numeric, QLatin1Char('!') + tok.folded, hit.score);
            }
            for (const PrioAlias &a : prios) {
                const int score = matchScore(tok.folded, a.folded, true, true);
                if (score >= 0) {
                    addPrio(a.priority, a.insert, score);
                }
            }
        }
        std::sort(result.items.begin(), result.items.end(), [](const QuickAddSuggestion &a, const QuickAddSuggestion &b) {
            return a.score > b.score;
        });
        return result;
    }

    if (tok.folded.size() < 2) {
        return result;
    }

    QTime parsed;
    if (parseTimeToken(tok.raw, &parsed)) {
        return result;
    }

    for (const DatePhrase &p : phrases) {
        const int score = matchScore(tok.folded, p.folded, true, false);
        if (score < 0) {
            continue;
        }
        QuickAddSuggestion s;
        s.kind = QStringLiteral("date");
        s.insertText = p.insert;
        s.value = dateValue(p.kind, p.weekday);
        s.score = score;
        pushUnique(s);
    }

    std::sort(result.items.begin(), result.items.end(), [](const QuickAddSuggestion &a, const QuickAddSuggestion &b) {
        if (a.score != b.score) {
            return a.score > b.score;
        }
        return a.insertText.size() < b.insertText.size();
    });
    if (result.items.size() > 8) {
        result.items = result.items.mid(0, 8);
    }
    return result;
}

} // namespace TaskLogic
