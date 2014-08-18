module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    connect:
      server:
        options:
          port: 8000
          base: './examples'
    coffee:
      compile:
        files:
          'web-worker-manager-v0.1-main.js': ['lib/manager/**/*.coffee']
          'web-worker-manager-v0.1-worker.js': ['lib/worker/**/*.coffee']
    watch:
      coffee:
        options:
          livereload: true
          debounceDelay: 8000
        files: ['lib/**/*.coffee', 'examples/**/*.coffee', 'examples/**/*.html', 'test/**/*.coffee']
        tasks: ['coffee', 'karma:unit', 'uglify:min']
    karma:
      options:
        configFile: 'test/karma.conf.js'
        browsers: ['PhantomJS']
      unit:
        reporters: 'dots'
        background: false
        singleRun: true
      continuous:
        background: false
        singleRun: true
        browsers: ['PhantomJS']
    uglify:
      options:
        mangle:
          except: ['Q']
        compress:
          drop_console: true
        banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %> */'
      min:
        files:
          'web-worker-manager-v0.1-main.min.js': ['web-worker-manager-v0.1-main.js']
          'web-worker-manager-v0.1-worker.min.js': ['web-worker-manager-v0.1-worker.js']

  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-karma'

  grunt.registerTask 'default', ['connect', 'watch']
  grunt.registerTask 'build', ['coffee', 'uglify:min']
  grunt.registerTask 'oneshot', ['coffee', 'karma:continuous']
