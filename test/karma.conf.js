module.exports = function(config){
  config.set({
    preprocessors: {
      '**/*.coffee': ['coffee']
    },
    basePath : '../',
    files : [
      'bower_components/q/q.js',
      'web-worker-manager-v0.1-main.js',
      'test/**/*.coffee'
    ],
    frameworks: ['jasmine'],
    plugins : [
      'karma-coffee-preprocessor',
      'karma-chrome-launcher',
      'karma-jasmine'
    ],
    coffeePreprocessor: {
      options: {
        bare: true,
        sourceMap: false
      },
      transformPath: function(path) {
        return path.replace(/\.coffee$/, '.js');
      }
    }
  });
};
