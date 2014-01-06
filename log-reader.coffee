module.exports = (env) ->
  # ##Dependencies
  # * from node.js
  util = require 'util'
  
  # * pimatic imports.
  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'

  Tail = require('tail').Tail

  # ##The LogReaderPlugin
  class LogReaderPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) ->

    createDevice: (config) ->
      switch config.class
        when 'LogWatcher'
          assert config.name?
          assert config.id?
          watcher = new LogWatcher(config)
          @framework.registerDevice watcher
          return true
        else
          return false

  plugin = new LogReaderPlugin

  # ##LogWatcher Sensor
  class LogWatcher extends env.devices.Sensor
    listener: []

    constructor: (@config) ->
      @id = config.id
      @name = config.name
      @tail = new Tail(config.file)
      @states = {}

      # initialise all states with unknown
      for name in @config.states
        @states[name] = 'unknown'

      # On ervery new line in the log file
      @tail.on 'line', (data) =>
        # check all lines in config
        for line in @config.lines
          # for a match.
          if data.match(new RegExp line.match)
            # If a match occures then emit a "match"-event.
            @emit 'match', line, data
        return

      # When a match event occures
      @on 'match', (line, data) =>
        # then check for each state in the config
        for state in @config.states
          # if the state is registed for the log line.
          if state of line
            # When a value for the state is define, then set the value
            # and emit the event.
            @states[state] = line[state]
            @emit state, line[state]

        for i, listener of @listener
          if line.match is listener.match
            listener.callback 'event'
        return


    getSensorValuesNames: ->
      return @config.states

    getSensorValue: (name)->
      if name in @config.states
        return Q.fcall => @states[name]
      throw new Error("Illegal sensor value name")

    isTrue: (id, predicate) ->
      return Q.fcall -> false

    # Removes the notification for an with `notifyWhen` registered predicate. 
    cancelNotify: (id) ->
      if @listener[id]?
        delete @listener[id]

    _getLineWithPredicate: (predicate) ->
      for line in @config.lines
        if line.predicate? and predicate.match(new RegExp(line.predicate))
          return line
      return null

    canDecide: (predicate) ->
      line = @_getLineWithPredicate predicate
      return if line? then 'event' else no 

    notifyWhen: (id, predicate, callback) ->
      line = @_getLineWithPredicate predicate
      unless line?
        throw new Error 'Can not decide the predicate!'

      @listener[id] =
        match: line.match
        callback: callback



  # For testing...
  @LogReaderPlugin = LogReaderPlugin
  # Export the plugin.
  return plugin