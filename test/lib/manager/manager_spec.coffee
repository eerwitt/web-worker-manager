describe "WebWorkerManager", ->
  fakeWorkerClass = ->
    class FakeWorker
      @runs: 0
      constructor: ->
        FakeWorker.runs++
      addEventListener: ->

  fakeManager = ->
    new WebWorkerManager("test.js", 1, fakeWorkerClass())

  $manager = null
  beforeEach ->
    $manager = fakeManager()

  it "is an available class", ->
    expect(WebWorkerManager).not.toBeNull()

  describe "#constructor", ->
    it "creates @poolSize number of workers", ->
      spy = spyOn(WebWorkerManager.prototype, "_createWorker")
      new WebWorkerManager("1", 3)
      expect(spy).toHaveBeenCalled()
      expect(spy.calls.count()).toBe(3)

  describe "#_getWorkerById", ->
    it "finds a worker based on the worker ID", ->
      foundWorker = id: "found"
      $manager.pool = [{id: "not the ID being looked for"}, foundWorker]

      expect($manager._getWorkerById("found")).toBe(foundWorker)

    it "raises an error if the worker cannot be found", ->
      $manager.pool = [{id: "a different ID"}]

      expect(-> $manager._getWorkerById("not-found") ).toThrow()

    it "raises an error if more than one worker has the same ID", ->
      duplicateWorker = id: "duplicate"
      $manager.pool = [duplicateWorker, duplicateWorker]

      expect(-> $manager._getWorkerById("duplicate") ).toThrow()

  describe "#_verifyRequirements", ->
    $realQ = $realWorker = null

    beforeEach ->
      $realQ = Q
      $realWorker = Worker

    afterEach ->
      window.Q = $realQ
      window.Worker = $realWorker

    it "thows an error if Q is undefined", ->
      window.Q = undefined

      expect(-> $manager._validateRequirements()).toThrow()

    it "throws an error if HTML5 Workers are not available", ->
      window.Worker = null

      expect(-> $manager = new WebWorkerManager("test.js")).toThrow()

    it "throws an error if no script is set", ->
      $manager.workerScriptLocation = null

      expect(-> $manager._validateRequirements()).toThrow()

  describe "#_createWorker", ->
    it "creates a worker", ->
      fake = fakeWorkerClass()

      listener = spyOn(fake.prototype, "addEventListener")

      $manager.workerClass = fake
      $manager._createWorker("test")

      expect(listener).toHaveBeenCalled()
      expect(fake.runs).toBe(1)
      
    it "adds a worker to the pool of workers", ->
      currentPool = $manager.pool.length
      $manager._createWorker("test")
      updatedPool = $manager.pool.length

      expect(updatedPool - currentPool).toBe(1)

  describe "#_handleWorker", ->
    $workerId = "test_worker"
    beforeEach ->
      $manager.jobs =
        test_worker:
          notify: ->
          resolve: ->
          reject: ->

    it "changes a worker to be IDLE when it is ready for work", ->
      spy = spyOn($manager, "_updateWorkerToIdle")
      fakeWorker = {id: $workerId}
      $manager.pool = [fakeWorker]

      $manager._handleWorker($workerId, {data: {messageType: "ready"}})

      expect(spy).toHaveBeenCalledWith(fakeWorker)

    it "calls notify for a job on progress", ->
      spy = spyOn($manager.jobs.test_worker, "notify")

      $manager._handleWorker($workerId, {data: {messageType: "progress", params: {current: 1, total: 4}}})
      expect(spy).toHaveBeenCalledWith(0.25)

    it "calls complete for a job which is complete", ->
      spy = spyOn($manager.jobs.test_worker, "resolve")

      $manager._handleWorker($workerId, {data: {messageType: "complete", params: {payload: "test payload"}}})
      expect(spy).toHaveBeenCalledWith("test payload")

    it "calls reject for a job which has errored", ->
      spy = spyOn($manager.jobs.test_worker, "reject")

      $manager._handleWorker($workerId, {data: {messageType: "error", params: {error: "test error"}}})
      expect(spy).toHaveBeenCalledWith("test error")

    it "raises an error if the request is unknown", ->
      expect( -> $manager._handleWorker($workerId)).toThrow()
      expect( -> $manager._handleWorker($workerId, {data: {messageType: "unknown_type"}})).toThrow()

  describe "#_handleErrors", ->
    $fakeWorker = null

    beforeEach ->
      $fakeWorker =
        thread:
          terminate: ->
        id: "fake"
        status: null

    it "recreates the thread in error", ->
      $manager.pool = [$fakeWorker]

      $manager._handleErrors("fake")
      expect($manager.pool.length).toBe(2)
      expect($manager.pool.filter( (w) -> w.status isnt STATUS.ERROR).length).toBe(1)

    it "terminates the error'd out thread", ->
      $manager.pool = [$fakeWorker]
      spy = spyOn($fakeWorker.thread, "terminate")

      $manager._handleErrors("fake")
      expect(spy).toHaveBeenCalled()

  describe "#_completedWork", ->
    $fakeWorker = null

    beforeEach ->
      $fakeWorker =
        status: null

    it "updates the worker status", ->
      spy = spyOn($manager, "_updateWorkerToIdle")
      $manager._completedWork($fakeWorker)

      expect(spy).toHaveBeenCalledWith($fakeWorker)

  describe "#_updateWorkerToIdle", ->
    $fakeWorker = null

    beforeEach ->
      $fakeWorker =
        status: null

    it "throws an error if no worker is specified", ->
      expect(-> $manager._updateWorkerToIdle()).toThrow()

    it "resets the worker status as IDLE", ->
      $manager._updateWorkerToIdle($fakeWorker)
      expect($fakeWorker.status).toBe(STATUS.IDLE)

    it "takes the next available new work", ->
      fakeWork = jasmine.createSpy("fakeWork")
      $manager.queue = [fakeWork]

      $manager._updateWorkerToIdle($fakeWorker)
      expect(fakeWork).toHaveBeenCalledWith($fakeWorker)

    it "doesn't do anything more if no work is available", ->
      fakeWork = jasmine.createSpy("fakeWork")
      $manager.queue = [fakeWork]

      $manager._updateWorkerToIdle($fakeWorker)
      expect(fakeWork).toHaveBeenCalledWith($fakeWorker)

      $manager._updateWorkerToIdle($fakeWorker)
      expect(fakeWork.calls.count()).toBe(1)

  describe "#_addToQueue", ->
    it "added an item to the work queue", ->
      queue = $manager.queue.length
      $manager._addToQueue(-> )
      updatedQueue = $manager.queue.length

      expect(updatedQueue - queue).toBe(1)

    it "adds the item in the last place of the queue", ->
      callback = -> "returned"
      $manager._addToQueue(-> "not returned")
      $manager._addToQueue(callback)

      lastInQueue = $manager.queue.pop()
      expect(lastInQueue()).toEqual("returned")

    it "raises an error if the item isn't a function", ->
      expect(-> $manager._addToQueue("fake")).toThrow()

  describe "#getWorker", ->
    it "uses the first idle worker to start a job", (done) ->
      $manager.pool = [{id: "busy_worker", status: STATUS.BUSY}, {id: "idle_worker", status: STATUS.IDLE}]

      $manager.getWorker().then( (worker) ->
        expect(worker.id).toBe("idle_worker")
        done()
      )

    it "doesn't use a busy worker", (done) ->
      $manager.pool = [{id: "idle_worker", status: STATUS.IDLE}, {id: "busy_worker", status: STATUS.BUSY}]

      spy = spyOn($manager, "_addToQueue")

      $manager.getWorker().then( (worker) ->
        worker.status = STATUS.BUSY
        expect(worker.id).toBe("idle_worker")

        # Now the getWorker should not return anyone
        $manager.getWorker()
        expect(spy.calls.count()).toBe(1)
        done()
      )

    it "adds the job to a queue if no workers are available", ->
      $manager.pool = [{id: "busy_worker", status: STATUS.BUSY}]

      spy = spyOn($manager, "_addToQueue")

      $manager.getWorker()
      expect(spy.calls.count()).toBe(1)

  describe "#runJob", ->
    it "starts a job running", (done) ->
      idleWorker =
        thread:
          postMessage: (event) ->
            expect(idleWorker.status).toBe(STATUS.BUSY)
            done()
        id: "test_worker"
        status: STATUS.IDLE

      $manager.pool = [idleWorker]
      $manager.runJob("test")

    it "fails if a job name wasn't provided", ->
      expect( -> $manager.runJob(null, "params")).toThrow()

    it "marks the worker as complete when it is finished (TODO reconsider this)", (done) ->
      idleWorker =
        thread:
          postMessage: (event) -> $manager._handleWorker("test_worker", {data: {messageType: "complete", params: {payload: "complete"}}})
        id: "test_worker"
        status: STATUS.IDLE

      $manager.pool = [idleWorker]
      $manager.runJob("test").then( (payload) ->
        expect(payload).toBe("complete")
        expect(idleWorker.status).toBe(STATUS.IDLE)
        done()
      )

    it "marks the worker as complete if an error occurs", (done) ->
      idleWorker =
        thread:
          postMessage: (event) -> $manager._handleWorker("test_worker", {data: {messageType: "error", params: {error: "error"}}})
        id: "test_worker"
        status: STATUS.IDLE

      $manager.pool = [idleWorker]
      $manager.runJob("test").fail( (payload) ->
        expect(payload).toBe("error")
        expect(idleWorker.status).toBe(STATUS.IDLE)
        done()
      )

    it "tells a worker to start processing the job using the params", (done) ->
      params = {test: true}
      idleWorker =
        thread:
          postMessage: (event) ->
            expect(event.params).toBe(params)
            done()
        id: "test_worker"
        status: STATUS.IDLE


      $manager.pool = [idleWorker]
      $manager.runJob("test", params)
