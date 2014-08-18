"use strict"
exports = exports ? this

exports.STATUS = Object.freeze(
  IDLE: "idle"
  BUSY: "busy"
  WAITING: "waiting"
  STARTING: "starting"
  ERROR: "error")

###
# General overview of how the process of scheduling background work occurs.
# 1. Try to get a worker.
# 2. Returns a promise.
# 3. When a worker is available, work begins on the task.
# 4. When the work is done, the promise is resolved.
# 5. On resolution the worker is added back to the pool.
# 6. The manager checks for work which is waiting.
# 7. If work is waiting it resolves that promise by creating a worker to work on it.
# 8. If no worker is available it adds the promise to a queue of promises to be pulled from.
# 9. When a job completes it checks the queue.
###

###
# NOTE Originally this was supposed to run as a worker but the ability to
# launch a worker from a worker is broken in many browsers.
# https://developer.mozilla.org/en-US/docs/Web/API/Worker/Functions_and_classes_available_to_workers
###
class WebWorkerManager
  constructor: (@workerScriptLocation, @poolSize=2, @workerClass=Worker) ->
    @pool = []
    @queue = []
    @jobs = {}

    # TODO it would be nice to have a GUID generator for use here.
    for i in [0...@poolSize]
      @_createWorker "worker_#{i}"

  _validateRequirements: ->
    unless Q? and @workerClass? and @workerScriptLocation?
      throw new Error("Unable to initialize WebWorkerManager due to a missing parameter.
          Q found... #{Q?}
          WorkerClass found... #{@workerClass?}")

  _createWorker: (id) ->
    @_validateRequirements()

    thread = new @workerClass(@workerScriptLocation)
    thread.addEventListener "message", (event) =>
      @_handleWorker id, event

    # TODO this is a considerable amount of logic, worth simplifying
    thread.addEventListener "error", (event) =>
      errorInfo =
        data:
          messageType: "error"
          params:
            error: event?.data?.error

      @_handleWorker id, errorInfo
      @_handleErrors id

    @pool.push thread: thread, id: id, status: STATUS.STARTING

  _getWorkerById: (id) ->
    workers = @pool.filter((worker) -> worker.id is id)
    if workers.length > 1
      throw new Error("More than 1 worker has the same ID. #{id}")
    if workers.length is 0
      throw new Error("No worker found with that ID. #{id}")

    workers[0]

  _handleErrors: (id) =>
    worker = @_getWorkerById id

    worker.status = STATUS.ERROR
    try
      worker.thread.terminate()
    catch error
      console.error "Problem terminating thread: #{error}"

    replacedId = "#{id}.resqued"

    @_createWorker replacedId

  _handleWorker: (id, event) =>
    messageType = event?.data?.messageType
    params = event?.data?.params

    switch messageType
      when "ready"
        @_updateWorkerToIdle @_getWorkerById(id)
      when "progress"
        @jobs[id].notify(params.current / params.total)
      when "complete"
        @jobs[id].resolve(params.payload)
      when "error"
        @jobs[id].reject(params.error)
      else
        throw new Error("An unknown event was sent back to the Manager.")

  # NOTE currently this is used as a shortcut to be called when a worker needs to be set to IDLE then it picks up work.
  # Since so much of this system works on events being passed around it would make since to have this be an event based approach instead.
  _updateWorkerToIdle: (worker) ->
    unless worker?
      throw new Error("No worker was specified to be set to IDLE.")

    worker.status = STATUS.IDLE
    newJob = @queue.shift()

    if newJob?
      newJob worker

  _completedWork: (worker) =>
    @_updateWorkerToIdle(worker)

  _addToQueue: (callback) ->
    unless typeof(callback) is "function"
      throw new Error("The callback being added to the queue is not a function.")

    @queue.push callback

  getWorker: ->
    Q.Promise (resolve, reject, notify) =>
      idleWorker = null
      for worker in @pool
        if worker.status is STATUS.IDLE
          idleWorker = worker
          break

      if idleWorker?
        resolve idleWorker
      else
        @_addToQueue (availableWorker) =>
          resolve availableWorker

  runJob: (jobName, params={}) ->
    unless jobName?
      throw new Error("The name of the job to execute is required.")

    runJob = (worker) =>
      worker.status = STATUS.BUSY

      Q.Promise (resolve, reject, notify) =>
        @jobs[worker.id] =
          job: jobName
          notify: notify
          resolve: (payload) =>
            resolve(payload)
            @_completedWork(worker)
          reject: (error) =>
            reject(error)
            @_completedWork(worker)

        worker.thread.postMessage(
          messageType: jobName, params: params)

    @getWorker().then(runJob)

exports.WebWorkerManager = WebWorkerManager
