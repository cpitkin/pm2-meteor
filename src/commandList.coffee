cli = require 'cli'
async = require 'async'
localTasks = require './localTasks'
commonTasks = require './commonTasks'
remoteTasks = require './remoteTasks'
_settings = require './settings'

# CLI commands
module.exports =
  init: ()->
    cli.spinner "Creating new pm2-meteor.json"
    localTasks.initPM2MeteorSettings (err)->
      if err
        cli.spinner "", true
        cli.fatal "#{err.message}"
      else
        cli.spinner "#{_settings.pm2MeteorConfigName} created!", true
  deploy: ()->
    cli.spinner "Building your app and deploying to host machine"
    pm2mConf = commonTasks.readPM2MeteorConfig()
    session = remoteTasks.getRemoteSession pm2mConf
    async.series [
      (cb)->
        remoteTasks.checkDeps session, cb
      (cb)->
        remoteTasks.prepareHost session, pm2mConf, cb
      (cb)->
        localTasks.generatePM2EnvironmentSettings pm2mConf, cb
      (cb)->
        if !pm2mConf.appLocation.local or pm2mConf.appLocation.local.trim() is ""
          localTasks.bundleApplicationFromGit pm2mConf, cb
        else
          localTasks.bundleApplication pm2mConf, cb
      (cb)->
        remoteTasks.backupLastTar session, pm2mConf, cb
      (cb)->
        remoteTasks.shipTarBall session, pm2mConf, cb
      (cb)->
        remoteTasks.extractTarBall session, pm2mConf, cb
      (cb)->
        remoteTasks.installBundleDeps session, pm2mConf, cb
      (cb)->
        remoteTasks.reloadApp session, pm2mConf, cb
    ], (err)->
      cli.spinner "", true
      if err
        localTasks.makeClean (err)-> cli.error err if err
        cli.fatal "#{err.message}"
      else
        localTasks.makeClean (err)-> cli.error err if err
        cli.ok "Deployed your app on the host machine!"
  start: ()->
    cli.spinner "Starting app on host machine"
    pm2mConf = commonTasks.readPM2MeteorConfig()
    session = remoteTasks.getRemoteSession pm2mConf
    remoteTasks.startApp session, pm2mConf, (err)->
      cli.spinner "", true
      if err
        cli.fatal "#{err.message}"
      else
        cli.ok "Started your app!"
  stop: ()->
    cli.spinner "Stopping app on host machine"
    pm2mConf = commonTasks.readPM2MeteorConfig()
    session = remoteTasks.getRemoteSession pm2mConf
    remoteTasks.stopApp session, pm2mConf, (err)->
      cli.spinner "", true
      if err
        cli.fatal "#{err.message}"
      else
        cli.ok "Stopped your app!"
  status: ()->
    cli.spinner "Checking status"
    pm2mConf = commonTasks.readPM2MeteorConfig()
    session = remoteTasks.getRemoteSession pm2mConf
    remoteTasks.status session, pm2mConf, (err, result)->
      cli.spinner "", true
      if err
        cli.fatal "#{err.message}"
      else
        cli.info result
  generateBundle: ()->
    cli.spinner "Generating bundle with pm2-env file"
    pm2mConf = commonTasks.readPM2MeteorConfig()
    async.series [
      (cb)->
        localTasks.generatePM2EnvironmentSettings pm2mConf, cb
      (cb)->
        if !pm2mConf.appLocation.local or pm2mConf.appLocation.local.trim() is ""
          localTasks.bundleApplicationFromGit pm2mConf, cb
        else
          localTasks.bundleApplication pm2mConf, cb
      (cb)->
        localTasks.makeCleanAndLeaveBundle cb
    ], (err)->
      cli.spinner "", true
      if err
        cli.fatal "#{err.message}"
      else
        cli.ok "Generated #{_settings.bundleTarName} with pm2-env file"
