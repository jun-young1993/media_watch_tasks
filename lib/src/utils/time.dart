DateTime dateTimeFromMs(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();

int dateTimeToUtcMs(DateTime dt) => dt.toUtc().millisecondsSinceEpoch;
