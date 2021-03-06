(function() {
  "use strict";
  var ManagedWebWorker, exports, managedWebWorker,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  exports = exports != null ? exports : this;


  /*
   * The ManagedWebWorker class is a thin wrapper around the context actual workers run in.
   * The extra methods are similar to how firefox described a method to switch on the job name:
   * https://developer.mozilla.org/en-US/docs/Web/Guide/Performance/Using_web_workers#Example_.232.3A_Advanced_passing_JSON_Data_and_creating_a_switching_system
   * The main difference is naming and calling a job with callbacks for progress, completion and error. Those callbacks are sent straight back to the manager to deal with.
   * Exceptions being thrown will raise back to the WebWorkerManager which will terminate the worker and start a new one in its place.
   */

  ManagedWebWorker = (function() {

    /*
     * @param {Object} The context which is used for HTML5 Workers. For more information see https://developer.mozilla.org/en-US/docs/Web/API/DedicatedWorkerGlobalScope.
     * @return {Null} Not used.
     */
    function ManagedWebWorker(workerContext) {
      this.workerContext = workerContext;
      this.registerJob = __bind(this.registerJob, this);
      this._onMessage = __bind(this._onMessage, this);
      this._jobs = {};
      this.workerContext.onmessage = this._onMessage;
      this._postMethod = function(args) {
        return this.workerContext.postMessage(args);
      };
      this._sendTypedMessage("ready");
    }


    /*
     * A method which will send a message in a format understood by the WebWorkerManager.
     *
     * @param {Object} The workers communicate to the WebWorkerManager by passing message object with a key called "messageType". The "messageType" is used to run code related to that message.
     * @param {Object} A list of parameters which is passed along back to the WebWorkerManager
     * @return {Object} The response from the system's _postMethod. Not used.
     */

    ManagedWebWorker.prototype._sendTypedMessage = function(messageType, params) {
      if (params == null) {
        params = {};
      }
      if (messageType == null) {
        throw new Error("No messageType specified for the outgoing message.");
      }
      this._postMethod({
        messageType: messageType,
        params: params
      });
      return true;
    };


    /*
     * Event handler for messages coming from the WebWorkerManager.
     *
     * @param {Object} Event data from messages sent to the worker, the information used is under the "data" key in the event object.
     * @return {Object} Response fromthe executed job. Not used.
     */

    ManagedWebWorker.prototype._onMessage = function(event) {
      var jobName, _ref;
      jobName = event != null ? (_ref = event.data) != null ? _ref.messageType : void 0 : void 0;
      if (jobName == null) {
        throw new Error("No messageType specified for the incoming message.");
      } else if (this._jobs[jobName] == null) {
        throw new Error("No job exists by that jobName");
      } else {
        return this._jobs[jobName](event.data.params, ((function(_this) {
          return function(current, total) {
            return _this._sendTypedMessage("progress", {
              current: current,
              total: total
            });
          };
        })(this)), ((function(_this) {
          return function(payload) {
            return _this._sendTypedMessage("complete", {
              payload: payload
            });
          };
        })(this)), ((function(_this) {
          return function(error) {
            return _this._sendTypedMessage("error", {
              error: error
            });
          };
        })(this)));
      }
    };


    /*
     * The method used to register a new job from client code.
     *
     * @param {String} A unique name to be used for the job which is being ran. If the same name is used twice only the second one is actually stored.
     * @param {Function} When a job is executed this callback will be sent information from the worker. The callback should accept 4 parameters (params sent from manager, progress callback, completion callback and an error calback).
     * @return {Function} The callback parameter. Not used.
     */

    ManagedWebWorker.prototype.registerJob = function(jobName, callback) {
      return this._jobs[jobName] = callback;
    };

    return ManagedWebWorker;

  })();

  exports.ManagedWebWorker = ManagedWebWorker;

  if (typeof document === "undefined" || document === null) {
    managedWebWorker = new ManagedWebWorker(this);
    exports.registerJob = managedWebWorker.registerJob;
  }

}).call(this);
