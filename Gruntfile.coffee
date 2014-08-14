module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    connect:
      server:
        port: 8000
        base: './examples'
    coffee:
      compile:
        files:
          'web-worker-manager-v0.1-main.js': ['lib/manager/**/*.coffee']
          'web-worker-manager-v0.1-worker.js': ['lib/worker/**/*.coffee']
          'web/js/shared.js': ['lib/**/*.coffee']
    watch:
      coffee:
        options:
          livereload: true
        files: ['lib/**/*.coffee', 'examples/**/*.coffee', 'examples/**/*.html', 'test/**/*.coffee']
        tasks: ['coffee', 'karma:unit:run']
    karma:
      options:
        configFile: 'test/karma.conf.js'
        browsers: ['Chrome']
        files: ['test/**/*.coffee']
      unit:
        reporters: 'dots'
        background: true
      continuous:
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
  grunt.registerTask 'build', ['uglify:min']
