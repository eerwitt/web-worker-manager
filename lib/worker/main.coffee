"use strict"
exports = exports ? this

###
# The ManagedWebWorker class is a thin wrapper around the context actual workers run in.
# The extra methods are similar to how firefox described a method to switch on the job name:
# https://developer.mozilla.org/en-US/docs/Web/Guide/Performance/Using_web_workers#Example_.232.3A_Advanced_passing_JSON_Data_and_creating_a_switching_system
# The main difference is naming and calling a job with callbacks for progress, completion and error. Those callbacks are sent straight back to the manager to deal with.
# Exceptions being thrown will raise back to the WebWorkerManager which will terminate the worker and start a new one in its place.
###
class ManagedWebWorker
  constructor: (@workerContext) ->
    @_jobs = {}
    @workerContext.onmessage = @_onMessage
    @_postMethod = (args) ->
      @workerContext.postMessage args

    @_sendTypedMessage "ready"

  _sendMessage: (args) ->
    @_postMethod args

  _sendTypedMessage: (messageType, params={}) ->
    unless messageType?
      throw new Error("No messageType specified for the outgoing message.")

    @_sendMessage messageType: messageType, params: params

  _onMessage: (event) =>
    jobName = event?.data?.messageType
    unless jobName?
      throw new Error("No messageType specified for the incoming message.")
    else if not @_jobs[jobName]?
      throw new Error("No job exists by that jobName")
    else
      @_jobs[jobName](
        event.data.params,
        ( (current, total) => @_sendTypedMessage "progress", current: current, total: total ),
        ( (payload) => @_sendTypedMessage "complete", payload: payload),
        ( (error) => @_sendTypedMessage "error", error: error ))

  registerJob: (jobName, callback) =>
    @_jobs[jobName] = callback

exports.ManagedWebWorker = ManagedWebWorker

# Only create the web worker if it is in a worker context.
# TODO I would like to find a better way to be able to test this otherwise
# this code is not well suited to testing.
unless document?
  managedWebWorker = new ManagedWebWorker(this)
  exports.registerJob = managedWebWorker.registerJob
