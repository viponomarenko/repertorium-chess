/// The current time for everything that depends on "today" (week chart,
/// streak, forecast). Tests replace it to keep dated screens stable.
DateTime Function() appNow = DateTime.now;

/// Whole calendar days from [from] to [to], ignoring the time of day and
/// daylight-saving shifts (a 23- or 25-hour day is still one day).
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
