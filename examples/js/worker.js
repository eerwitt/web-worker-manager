importScripts("/js/web-worker-manager-v0.1-worker.js");

registerJob("downcaseWords", function(params, progress, complete, error) {
  if(params.words === undefined) {
    error("No string supplied");
  }
  words = params.words.split(/\s/);
  total = words.length;
  
  complete(words.map( function(word, i) {
    progress(i, total);

    return word.toLowerCase();
  }));
});
