describe "ManagedWebWorker", ->
  $workerContext = $worker = null

  beforeEach ->
    $workerContext =
      onmessage: ->
      postMessage: ->

    $worker = new ManagedWebWorker($workerContext)

  describe "#constructor", ->
    it "exists", ->
      expect(ManagedWebWorker).not.toBeNull()

    it "associates the Worker's onmessage with the current onMessage", ->
      expect($worker._onMessage).toBe($workerContext.onmessage)

    it "associates the Worker's postMessage with the current postMethod", ->
      spy = spyOn($workerContext, "postMessage")

      $worker._postMethod("test")
      expect(spy).toHaveBeenCalledWith("test")

    it "sends a message saying the worker is ready for work", ->
      spy = spyOn($workerContext, "postMessage")
      worker = new ManagedWebWorker($workerContext)

      expect(spy).toHaveBeenCalledWith(messageType: "ready", params: {})
      
  describe "#_onMessage", ->
    it "raises an error if there is no type to the message", ->
      expect(-> $worker._onMessage(data: {})).toThrow()

    it "raises an error if the job specified doesn't exist", ->
      expect(-> $worker._onMessage(data: {messageType: "doesn't_exist"})).toThrow()

    it "calls a job based on its name", ->
      fakeJob = jasmine.createSpy("fakeJob")
      $worker._jobs.fake_job = fakeJob

      $worker._onMessage(data: {messageType: "fake_job"})
      expect(fakeJob).toHaveBeenCalled()
  describe "#_sendTypedMessage", ->
    it "throws an error if no message type is specified", ->
      expect(-> $worker._sendTypedMessage() ).toThrow()

    it "sends a message converting params to a hash", ->
      spy = spyOn($worker, "_sendMessage")
      $worker._sendTypedMessage("test", test: true)

      expect(spy).toHaveBeenCalledWith(messageType: "test", params: {test: true})

  describe "#registerJob", ->
    it "adds a job using the jobName with a callback which is executed when asked for", ->
      fakeJob = ->
      $worker.registerJob("fakeJob", fakeJob)

      expect($worker._jobs.fakeJob).toBe(fakeJob)
