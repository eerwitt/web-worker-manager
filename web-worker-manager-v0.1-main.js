(function() {
  "use strict";
  var WebWorkerManager, exports,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  exports = exports != null ? exports : this;

  exports.STATUS = Object.freeze({
    IDLE: "idle",
    BUSY: "busy",
    WAITING: "waiting",
    STARTING: "starting",
    ERROR: "error"
  });


  /*
   * General overview of how the process of scheduling background work occurs.
   * 1. Try to get a worker.
   * 2. Returns a promise.
   * 3. When a worker is available, work begins on the task.
   * 4. When the work is done, the promise is resolved.
   * 5. On resolution the worker is added back to the pool.
   * 6. The manager checks for work which is waiting.
   * 7. If work is waiting it resolves that promise by creating a worker to work on it.
   * 8. If no worker is available it adds the promise to a queue of promises to be pulled from.
   * 9. When a job completes it checks the queue.
   */


  /*
   * NOTE Originally this was supposed to run as a worker but the ability to
   * launch a worker from a worker is broken in many browsers.
   * https://developer.mozilla.org/en-US/docs/Web/API/Worker/Functions_and_classes_available_to_workers
   */

  WebWorkerManager = (function() {
    function WebWorkerManager(workerScriptLocation, poolSize, workerClass) {
      var i, _i, _ref;
      this.workerScriptLocation = workerScriptLocation;
      this.poolSize = poolSize != null ? poolSize : 2;
      this.workerClass = workerClass != null ? workerClass : Worker;
      this._completedWork = __bind(this._completedWork, this);
      this._handleWorker = __bind(this._handleWorker, this);
      this._handleErrors = __bind(this._handleErrors, this);
      this.pool = [];
      this.queue = [];
      this.jobs = {};
      for (i = _i = 0, _ref = this.poolSize; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
        this._createWorker("worker_" + i);
      }
    }

    WebWorkerManager.prototype._validateRequirements = function() {
      if (!((typeof Q !== "undefined" && Q !== null) && (this.workerClass != null) && (this.workerScriptLocation != null))) {
        throw new Error("Unable to initialize WebWorkerManager due to a missing parameter. Q found... " + (typeof Q !== "undefined" && Q !== null) + " WorkerClass found... " + (this.workerClass != null));
      }
    };

    WebWorkerManager.prototype._createWorker = function(id) {
      var thread;
      this._validateRequirements();
      thread = new this.workerClass(this.workerScriptLocation);
      thread.addEventListener("message", (function(_this) {
        return function(event) {
          return _this._handleWorker(id, event);
        };
      })(this));
      thread.addEventListener("error", (function(_this) {
        return function(event) {
          var errorInfo, _ref;
          errorInfo = {
            data: {
              messageType: "error",
              params: {
                error: event != null ? (_ref = event.data) != null ? _ref.error : void 0 : void 0
              }
            }
          };
          _this._handleWorker(id, errorInfo);
          return _this._handleErrors(id);
        };
      })(this));
      return this.pool.push({
        thread: thread,
        id: id,
        status: STATUS.STARTING
      });
    };

    WebWorkerManager.prototype._getWorkerById = function(id) {
      var workers;
      workers = this.pool.filter(function(worker) {
        return worker.id === id;
      });
      if (workers.length > 1) {
        throw new Error("More than 1 worker has the same ID. " + id);
      }
      if (workers.length === 0) {
        throw new Error("No worker found with that ID. " + id);
      }
      return workers[0];
    };

    WebWorkerManager.prototype._handleErrors = function(id) {
      var error, replacedId, worker;
      worker = this._getWorkerById(id);
      worker.status = STATUS.ERROR;
      try {
        worker.thread.terminate();
      } catch (_error) {
        error = _error;
        console.error("Problem terminating thread: " + error);
      }
      replacedId = "" + id + ".resqued";
      return this._createWorker(replacedId);
    };

    WebWorkerManager.prototype._handleWorker = function(id, event) {
      var messageType, params, _ref, _ref1;
      messageType = event != null ? (_ref = event.data) != null ? _ref.messageType : void 0 : void 0;
      params = event != null ? (_ref1 = event.data) != null ? _ref1.params : void 0 : void 0;
      switch (messageType) {
        case "ready":
          return this._updateWorkerToIdle(this._getWorkerById(id));
        case "progress":
          return this.jobs[id].notify(params.current / params.total);
        case "complete":
          return this.jobs[id].resolve(params.payload);
        case "error":
          return this.jobs[id].reject(params.error);
        default:
          throw new Error("An unknown event was sent back to the Manager.");
      }
    };

    WebWorkerManager.prototype._updateWorkerToIdle = function(worker) {
      var newJob;
      if (worker == null) {
        throw new Error("No worker was specified to be set to IDLE.");
      }
      worker.status = STATUS.IDLE;
      newJob = this.queue.shift();
      if (newJob != null) {
        return newJob(worker);
      }
    };

    WebWorkerManager.prototype._completedWork = function(worker) {
      return this._updateWorkerToIdle(worker);
    };

    WebWorkerManager.prototype._addToQueue = function(callback) {
      if (typeof callback !== "function") {
        throw new Error("The callback being added to the queue is not a function.");
      }
      return this.queue.push(callback);
    };

    WebWorkerManager.prototype.getWorker = function() {
      return Q.Promise((function(_this) {
        return function(resolve, reject, notify) {
          var idleWorker, worker, _i, _len, _ref;
          idleWorker = null;
          _ref = _this.pool;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            worker = _ref[_i];
            if (worker.status === STATUS.IDLE) {
              idleWorker = worker;
              break;
            }
          }
          if (idleWorker != null) {
            return resolve(idleWorker);
          } else {
            return _this._addToQueue(function(availableWorker) {
              return resolve(availableWorker);
            });
          }
        };
      })(this));
    };

    WebWorkerManager.prototype.runJob = function(jobName, params) {
      var runJob;
      if (params == null) {
        params = {};
      }
      if (jobName == null) {
        throw new Error("The name of the job to execute is required.");
      }
      runJob = (function(_this) {
        return function(worker) {
          worker.status = STATUS.BUSY;
          return Q.Promise(function(resolve, reject, notify) {
            _this.jobs[worker.id] = {
              job: jobName,
              notify: notify,
              resolve: function(payload) {
                resolve(payload);
                return _this._completedWork(worker);
              },
              reject: function(error) {
                reject(error);
                return _this._completedWork(worker);
              }
            };
            return worker.thread.postMessage({
              messageType: jobName,
              params: params
            });
          });
        };
      })(this);
      return this.getWorker().then(runJob);
    };

    return WebWorkerManager;

  })();

  exports.WebWorkerManager = WebWorkerManager;

}).call(this);
