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
  ###
  # @param {Object} The context which is used for HTML5 Workers. For more information see https://developer.mozilla.org/en-US/docs/Web/API/DedicatedWorkerGlobalScope.
  # @return {Null} Not used.
  ###
  constructor: (@workerContext) ->
    @_jobs = {}
    @workerContext.onmessage = @_onMessage
    @_postMethod = (args) ->
      @workerContext.postMessage args

    @_sendTypedMessage "ready"

  ###
  # A method which will send a message in a format understood by the WebWorkerManager.
  #
  # @param {Object} The workers communicate to the WebWorkerManager by passing message object with a key called "messageType". The "messageType" is used to run code related to that message.
  # @param {Object} A list of parameters which is passed along back to the WebWorkerManager
  # @return {Object} The response from the system's _postMethod. Not used.
  ###
  _sendTypedMessage: (messageType, params={}) ->
    unless messageType?
      throw new Error("No messageType specified for the outgoing message.")

    @_postMethod messageType: messageType, params: params
    true

  ###
  # Event handler for messages coming from the WebWorkerManager.
  #
  # @param {Object} Event data from messages sent to the worker, the information used is under the "data" key in the event object.
  # @return {Object} Response fromthe executed job. Not used.
  ###
  _onMessage: (event) =>
    jobName = event?.data?.messageType
    unless jobName?
      throw new Error("No messageType specified for the incoming message.")
    else if not @_jobs[jobName]?
      throw new Error("No job exists by that jobName")
    else
      # TODO This solution smelled from the start, currently while looking to add in more callbacks I realized it is worth it to make this into a class which can be inherited from which will have a scope inside that object. This means I could call any set of the methods on that object which would include sending messages and be much more testable.
      @_jobs[jobName](
        event.data.params,
        ( (current, total) => @_sendTypedMessage "progress", current: current, total: total ),
        ( (payload) => @_sendTypedMessage "complete", payload: payload),
        ( (error) => @_sendTypedMessage "error", error: error ))

  ###
  # The method used to register a new job from client code.
  #
  # @param {String} A unique name to be used for the job which is being ran. If the same name is used twice only the second one is actually stored.
  # @param {Function} When a job is executed this callback will be sent information from the worker. The callback should accept 4 parameters (params sent from manager, progress callback, completion callback and an error calback).
  # @return {Function} The callback parameter. Not used.
  ###
  registerJob: (jobName, callback) =>
    @_jobs[jobName] = callback

exports.ManagedWebWorker = ManagedWebWorker

# Only create the web worker if it is in a worker context.
# TODO I would like to find a better way to be able to test this otherwise
# this code is not well suited to testing.
unless document?
  managedWebWorker = new ManagedWebWorker(this)
  exports.registerJob = managedWebWorker.registerJob
