# Web Worker Manager

Manage background HTML5 workers in the browser to compute long running intensive tasks. The library is setup to be simple to start jobs and deal with callbacks on an event basis.

A fallback for browser which do not support HTML5 `Workers` is available but will be ran in an asynchronous manner.

## Installation

There are four steps in creating a task which can be used with this library.

* Include the library and a copy of `Q`.
* Create your application's main calls to the web worker manager.
* Create a separate script which runs the background tasks.

### Include the library.

Include the `web-worker-manager-v0.1.js` on any page in either the `head` or at the close of the `body` tag.

```html
<html>
  <head>
    <!-- Q promises are used often in this library. -->
    <script src="path/to/q.js" type="text/javascript"></script>
    <script src="js/web-worker-manager-v0.1-main.js" type="text/javascript"></script>
    <!-- Add in script which will work with the web-worker-manager. See [main.js] below. -->
  </head>
  <body></body>
</html>
```

### Create your application's main calls to the web worker manager.

Create a separate file called `main.js` which will instantiate the web worker manager.

```javascript
// The manager requires the location of the worker code to be passed in. This is the location relative to the current page the browser is on.
// *It is recommended to use an absolute path if possible.
manager = new WebWorkerManager("/path/to/worker.js")

// #runJob will ask an available worker to execute the code related to a job of the same name. That job will then be sent a message including
// the data which is passed in as a second parameter.
manager.runJob("parseString", {data: "Some stuff in here"})
  .then( function(results) { console.log(results) } )
  .fail( function(error) { console.error(errror) } )
```

The `#runJob` method is used for a single job to be ran, it returns a `Q` promise immediately.

If all the workers are already working the job will be placed in a queue to be picked up by the next available worker.

### Create your application's worker file (worker.js)

The `worker.js` is responsible for the majority of actual code being executed. Each worker will be reused until the manager is shut down.

```javascript
// We need to import the script which will provide some default functions to help get the worker setup properly.
importScripts("/path/to/web-worker-manager-v0.1-worker.js")

// To create a job we give it a name and code to call when it is ran.
registerJob("parseString", function(params, errorCallback) {
  if(params.data === undefined) {
    errorCallback("No string supplied.")
  }

  return params.data.split();
})
```

## Contibuting

Please do contribute, I appreciate any help.

### Testing

This app relies on `Karma` and is tested using.

`grunt test`.

### Local Development

This project requires `Grunt` to opperate. Most of the code is written in `Coffee`.

```bash
  npm install -g grunt-cli

  # From project directory
  grunt test

  # If all tests passed
  grunt build
```

The project follows a layout of.

```
/
  - test
    - lib
      - worker    // Worker tests
      - manager   // Manager tests
    - examples    // Example code tests
  - lib
    - worker      // Worker related functions
    - manager     // Manager related functions
  - examples      // Example code
```
