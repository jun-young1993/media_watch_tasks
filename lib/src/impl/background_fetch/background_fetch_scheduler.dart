import 'package:background_fetch/background_fetch.dart';

import '../../interfaces/logger.dart';
import '../../interfaces/scheduler.dart';

class BackgroundFetchScheduler implements Scheduler {
  BackgroundFetchScheduler({
    required this.onFetch,
    this.minimumFetchIntervalMinutes = 15,
    Logger? logger,
  }) : logger = logger ?? NoopLogger();

  final Future<void> Function() onFetch;
  final int minimumFetchIntervalMinutes;
  final Logger logger;

  @override
  Future<void> start() async {
    final status = await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: minimumFetchIntervalMinutes,
        stopOnTerminate: false,
        enableHeadless: true,
        startOnBoot: true,
        requiredNetworkType: NetworkType.NONE,
      ),
      (taskId) async {
        try {
          logger.debug('background_fetch: task start id=$taskId');
          await onFetch();
        } catch (e, st) {
          logger.error('background_fetch: task error id=$taskId', error: e, stackTrace: st);
        } finally {
          BackgroundFetch.finish(taskId);
        }
      },
      (taskId) async {
        logger.warn('background_fetch: timeout id=$taskId');
        BackgroundFetch.finish(taskId);
      },
    );

    logger.info('background_fetch: configured status=$status');
    await BackgroundFetch.start();
  }

  @override
  Future<void> stop() async {
    await BackgroundFetch.stop();
  }
}


