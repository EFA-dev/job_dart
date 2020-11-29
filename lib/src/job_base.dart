// region [g]

import 'package:state_notifier/state_notifier.dart';

typedef JobFunction<TParam, TResult> = Future<TResult> Function(TParam param);
typedef JobFunctionSync<TParam, TResult> = TResult Function(TParam param);

typedef JobFunctionOnlyParam<TParam> = Future<void> Function(TParam param);
typedef JobFunctionOnlyParamSync<TParam> = void Function(TParam param);

typedef JobFunctionOnlyResult<TResult> = Future<TResult> Function();
typedef JobFunctionOnlyResultSync<TResult> = TResult Function();

typedef JobFunctionPure<TParam, TResult> = Future<void> Function();
typedef JobFunctionPureSync<TParam, TResult> = void Function();

//*
typedef OnStartOnlyParam<TParam> = void Function(TParam param);
typedef OnStartPure = void Function();

typedef OnEnd<TParam, TResult> = void Function(TParam param, TResult result);
typedef OnEndOnlyResult<TResult> = void Function(TResult result);
typedef OnEndOnlyParam<TParam> = void Function(TParam param);
typedef OnEndPure = void Function();

typedef OnException<TParam, TResult> = void Function(JobDone<TParam, TResult> output);
typedef OnExceptionOnlyParam<TParam> = void Function(JobDoneOnlyParam<TParam> output);
typedef OnExceptionOnlyResult<TResult> = void Function(JobDoneOnlyResult<TResult> output);
typedef OnExceptionPure = void Function(JobDonePure output);

// endregion

// region [y]

abstract class JobDoneBase {
  final dynamic error;
  JobDoneBase(this.error);
  bool get isSuccess => error == null;
}

class JobDone<TParam, TResult> extends JobDoneBase {
  final TParam param;
  final TResult result;
  JobDone({this.param, this.result, dynamic error}) : super(error);
}

class JobDoneOnlyParam<TParam> extends JobDoneBase {
  final TParam param;
  JobDoneOnlyParam({this.param, dynamic error}) : super(error);
}

class JobDoneOnlyResult<TResult> extends JobDoneBase {
  final TResult result;
  JobDoneOnlyResult({this.result, dynamic error}) : super(error);
}

class JobDonePure extends JobDoneBase {
  JobDonePure({dynamic error}) : super(error);
}

class BusyError implements Exception {
  final String message;

  BusyError(this.message);
  @override
  String toString() => message;
}

// endregion

// region [pk]

abstract class JobBase<TResult> extends StateNotifier<TResult> {
  bool isWorking = false;

  TResult get value => state;

  void refresh() {
    // notifyListeners();
  }

  JobBase(TResult value) : super(value);
}

// endregion

// region [g]

class Job<TParam, TResult> extends JobBase<TResult> {
  Job(this.function, {TResult initialValue, this.onStart, this.onEnd, this.onException}) : super(initialValue);

  final JobFunction<TParam, TResult> function;
  final OnStartOnlyParam<TParam> onStart;
  final OnEnd<TParam, TResult> onEnd;
  final OnException<TParam, TResult> onException;

  List<void Function(TParam, TResult)> listenerList = [];
  void listen(void Function(TParam param, TResult result) listener) {
    listenerList.add(listener);
  }

  Future<JobDone<TParam, TResult>> call(TParam param) async {
    if (isWorking) {
      return Future.value(JobDone<TParam, TResult>(param: param, error: BusyError('Worker busy')));
    } else {
      return await run(param);
    }
  }

  Future<JobDone<TParam, TResult>> run(TParam param) async {
    isWorking = true;
    //* Start
    if (onStart != null) {
      onStart(param);
    }

    //* Work
    TResult result;
    dynamic error;

    try {
      result = await function(param);
    } catch (e) {
      isWorking = false;
      error = e;
    }

    //* Output
    var jobDone = JobDone<TParam, TResult>(param: param, result: result, error: error);

    if (jobDone.isSuccess) {
      state = result;

      if (onEnd != null) {
        try {
          onEnd(param, result);
        } catch (_) {}
      }
      for (var listener in listenerList) {
        try {
          listener(param, result);
        } catch (_) {}
      }

      // notifyListeners();
    } else {
      if (onException != null) {
        try {
          onException(jobDone);
        } catch (_) {}
      }
    }
    isWorking = false;
    return jobDone;
  }
}

class JobSync<TParam, TResult> extends JobBase<TResult> {
  JobSync(this.function, {TResult initialValue, this.onStart, this.onEnd, this.onException}) : super(initialValue);

  final JobFunctionSync<TParam, TResult> function;
  final OnStartOnlyParam<TParam> onStart;
  final OnEnd<TParam, TResult> onEnd;
  final OnException<TParam, TResult> onException;

  List<void Function(TParam, TResult)> listenerList = [];
  void listen(void Function(TParam param, TResult result) listener) {
    listenerList.add(listener);
  }

  JobDone<TParam, TResult> call(TParam param) {
    if (isWorking) {
      return JobDone<TParam, TResult>(param: param, error: BusyError('Worker busy'));
    } else {
      return run(param);
    }
  }

  JobDone<TParam, TResult> run(TParam param) {
    isWorking = true;
    //* Start
    if (onStart != null) {
      onStart(param);
    }

    //* Work
    TResult result;
    dynamic error;

    try {
      result = function(param);
    } catch (e) {
      isWorking = false;
      error = e;
    }

    //* Output
    var jobDone = JobDone<TParam, TResult>(param: param, result: result, error: error);

    if (jobDone.isSuccess) {
      state = result;

      if (onEnd != null) {
        try {
          onEnd(param, result);
        } catch (_) {}
      }

      for (var listener in listenerList) {
        try {
          listener(param, result);
        } catch (_) {}
      }

      // notifyListeners();
    } else {
      if (onException != null) {
        try {
          onException(jobDone);
        } catch (_) {}
      }
    }
    isWorking = false;
    return jobDone;
  }
}

// endregion

// region [p]

class JobOnlyParam<TParam> extends JobBase<void> {
  JobOnlyParam(this.function, {this.onStart, this.onEnd, this.onException}) : super(true);

  final JobFunctionOnlyParam<TParam> function;
  final OnStartPure onStart;
  final OnEndOnlyParam<TParam> onEnd;
  final OnExceptionOnlyParam<TParam> onException;

  List<void Function(TParam)> listenerList = [];
  void listen(void Function(TParam param) listener) {
    listenerList.add(listener);
  }

  Future<JobDoneOnlyParam<TParam>> call(TParam param) async {
    if (isWorking) {
      return Future.value(JobDoneOnlyParam<TParam>(param: param, error: BusyError('Worker busy')));
    } else {
      return await run(param);
    }
  }

  Future<JobDoneOnlyParam<TParam>> run(TParam param) async {
    isWorking = true;
    //* Start
    if (onStart != null) {
      onStart();
    }

    //* Work

    dynamic error;

    try {
      await function(param);
    } catch (e) {
      error = e;
      isWorking = false;
    }

    //* Output
    var jobDone = JobDoneOnlyParam<TParam>(error: error);

    if (jobDone.isSuccess) {
      state = true;

      if (onEnd != null) {
        try {
          onEnd(param);
        } catch (_) {}
      }

      for (var listener in listenerList) {
        try {
          listener(param);
        } catch (_) {}
      }

      // notifyListeners();
    } else {
      try {
        onException(jobDone);
      } catch (_) {}
    }

    isWorking = false;

    return jobDone;
  }
}

class JobOnlyParamSync<TParam> extends JobBase<void> {
  JobOnlyParamSync(this.function, {this.onStart, this.onEnd, this.onException}) : super(true);

  final JobFunctionOnlyParamSync<TParam> function;
  final OnStartPure onStart;
  final OnEndOnlyParam<TParam> onEnd;
  final OnExceptionOnlyParam<TParam> onException;

  List<void Function(TParam)> listenerList = [];
  void listen(void Function(TParam param) listener) {
    listenerList.add(listener);
  }

  JobDoneOnlyParam<TParam> call(TParam param) {
    if (isWorking) {
      return JobDoneOnlyParam<TParam>(param: param, error: BusyError('Worker busy'));
    } else {
      return run(param);
    }
  }

  JobDoneOnlyParam<TParam> run(TParam param) {
    isWorking = true;
    //* Start
    if (onStart != null) {
      onStart();
    }

    //* Work
    dynamic error;
    try {
      function(param);
    } catch (e) {
      isWorking = false;
      error = e;
    }

    //* Output
    var jobDone = JobDoneOnlyParam<TParam>(error: error);

    if (jobDone.isSuccess) {
      state = true;

      if (onEnd != null) {
        try {
          onEnd(param);
        } catch (_) {}
      }

      for (var listener in listenerList) {
        try {
          listener(param);
        } catch (_) {}
      }

      // notifyListeners();
    } else {
      try {
        onException(jobDone);
      } catch (_) {}
    }

    isWorking = false;

    return jobDone;
  }
}

// endregion

// region [b]

class JobOnlyResult<TResult> extends JobBase<TResult> {
  JobOnlyResult(this.function, {TResult initialValue, this.onStart, this.onEnd, this.onException}) : super(initialValue);

  final JobFunctionOnlyResult<TResult> function;
  final OnStartPure onStart;
  final OnEndOnlyResult<TResult> onEnd;
  final OnExceptionOnlyResult<TResult> onException;

  List<void Function(TResult)> listenerList = [];
  void listen(void Function(TResult result) listener) {
    listenerList.add(listener);
  }

  Future<JobDoneOnlyResult<TResult>> call() async {
    if (isWorking) {
      return Future.value(JobDoneOnlyResult<TResult>(error: BusyError('Worker busy')));
    } else {
      return await run();
    }
  }

  Future<JobDoneOnlyResult<TResult>> run() async {
    isWorking = true;
    //* Start
    if (onStart != null) {
      onStart();
    }

    //* Work
    TResult result;
    dynamic error;

    try {
      result = await function();
    } catch (e) {
      isWorking = false;
      error = e;
    }

    //* Output
    var jobDone = JobDoneOnlyResult<TResult>(result: result, error: error);

    if (jobDone.isSuccess) {
      state = result;

      if (onEnd != null) {
        try {
          onEnd(result);
        } catch (_) {}
      }
      for (var listener in listenerList) {
        try {
          listener(result);
        } catch (_) {}
      }

      // notifyListeners();
    } else {
      try {
        onException(jobDone);
      } catch (_) {}
    }

    isWorking = false;

    return jobDone;
  }
}

class JobOnlyResultSync<TResult> extends JobBase<TResult> {
  JobOnlyResultSync(this.function, {TResult initialValue, this.onStart, this.onEnd, this.onException}) : super(initialValue);

  final JobFunctionOnlyResultSync<TResult> function;
  final OnStartPure onStart;
  final OnEndOnlyResult<TResult> onEnd;
  final OnExceptionOnlyResult<TResult> onException;

  List<void Function(TResult)> listenerList = [];
  void listen(void Function(TResult result) listener) {
    listenerList.add(listener);
  }

  JobDoneOnlyResult<TResult> call() {
    if (isWorking) {
      return JobDoneOnlyResult<TResult>(error: BusyError('Worker busy'));
    } else {
      return run();
    }
  }

  JobDoneOnlyResult<TResult> run() {
    isWorking = true;
    //* Start
    if (onStart != null) {
      onStart();
    }

    //* Work
    TResult result;
    dynamic error;

    try {
      result = function();
    } catch (e) {
      isWorking = false;
      error = e;
    }

    //* Output
    var jobDone = JobDoneOnlyResult<TResult>(result: result, error: error);

    if (jobDone.isSuccess) {
      state = result;

      if (onEnd != null) {
        try {
          onEnd(result);
        } catch (_) {}
      }

      for (var listener in listenerList) {
        try {
          listener(result);
        } catch (_) {}
      }

      // notifyListeners();
    } else {
      if (onException != null) {
        try {
          onException(jobDone);
        } catch (_) {}
      }
    }

    isWorking = false;

    return jobDone;
  }
}

// endregion

// region [bl]

class JobPure extends JobBase<void> {
  JobPure(this.function, {this.onStart, this.onEnd, this.onException}) : super(true);

  final JobFunctionPure function;
  final OnStartPure onStart;
  final OnEndPure onEnd;
  final OnExceptionPure onException;

  List<Function> listenerList = [];

  void listen(Function listener) {
    listenerList.add(listener);
  }

  Future<JobDonePure> call() async {
    if (isWorking) {
      return Future.value(JobDonePure(error: BusyError('Worker busy')));
    } else {
      return await run();
    }
  }

  Future<JobDonePure> run() async {
    isWorking = true;
    //* Start
    if (onStart != null) {
      onStart();
    }

    //* Work
    dynamic error;

    try {
      await function();
    } catch (e) {
      error = e;
      isWorking = false;
    }

    //* Output
    var jobDone = JobDonePure(error: error);

    if (jobDone.isSuccess) {
      state = true;

      if (onEnd != null) {
        try {
          onEnd();
        } catch (_) {}
      }

      for (var listener in listenerList) {
        try {
          listener();
        } catch (_) {}
      }

      // notifyListeners();
    } else {
      if (onException != null) {
        try {
          onException(jobDone);
        } catch (_) {}
      }
    }
    isWorking = false;
    return jobDone;
  }
}

class JobPureSync extends JobBase<void> {
  JobPureSync(this.function, {this.onStart, this.onEnd, this.onException}) : super(true);

  final JobFunctionPureSync function;
  final OnStartPure onStart;
  final OnEndPure onEnd;
  final OnExceptionPure onException;

  List<Function> listenerList = [];
  void listen(Function listener) {
    listenerList.add(listener);
  }

  JobDonePure call() {
    if (isWorking) {
      return JobDonePure(error: BusyError('Worker busy'));
    } else {
      return run();
    }
  }

  JobDonePure run() {
    isWorking = true;
    //* Start
    if (onStart != null) {
      onStart();
    }

    //* Work
    dynamic error;
    try {
      function();
    } catch (e) {
      error = e;
    }

    //* Output
    var jobDone = JobDonePure(error: error);

    if (jobDone.isSuccess) {
      state = true;

      if (onEnd != null) {
        try {
          onEnd();
        } catch (_) {}
      }

      for (var listener in listenerList) {
        try {
          listener();
        } catch (_) {}
      }

      // notifyListeners();
    } else {
      if (onException != null) {
        try {
          onException(jobDone);
        } catch (_) {}
      }
    }
    isWorking = false;
    return jobDone;
  }
}

// endregion
