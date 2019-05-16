gulp          = require 'gulp'
coffee        = require 'gulp-coffee'
transform     = require 'gulp-transform'
rename        = require 'gulp-rename'
plumber       = require 'gulp-plumber'
debug         = require 'gulp-debug'
path          = require 'path'
child_process = require 'child_process'

execSync  = child_process.execSync
exec      = child_process.exec
spawn     = child_process.spawn



### Utils ###

runChild = (cmd) =>
  child = spawn cmd, {shell: true}
  child.stdout.on 'data' , (data) -> console.log data.toString()
  child.stderr.on 'data' , (data) -> console.log data.toString()
  # child.on        'close', (code) -> console.log code.toString()
  child



### Globals ###

rootPath   = '..'
toRootPath = (s) -> "#{rootPath}/#{s}"
distPath   = toRootPath 'dist'
srcPath    = toRootPath 'src'
pkgCfgPath = toRootPath 'package.json'
toSrcPath  = (s) -> "#{srcPath}/#{s}"
toDistPath = (s) -> "#{distPath}/#{s}"


### Watchables ###

watchables = []
watchableTask = (name, glob, fn) ->
  watchName = "watch:#{name}"
  srcGlob   = toSrcPath glob
  watchables.push watchName
  pipeOut = (t)    => t.pipe gulp.dest distPath
  runner  = (done) => gulp.watch(srcGlob).on "change", (s) => pipeOut fn(task s, done)
  task    = (s)    =>
    gulp.src s, {base: srcPath, sourcemaps: true}
      .pipe plumber()
      .pipe debug {title: "Processing [#{name}]:"}
  runner.displayName = "#{watchName} runner"
  gulp.task name      , (done) => pipeOut fn(task srcGlob, done)
  gulp.task watchName , (gulp.series name, runner)


### Transpilation ###

watchableTask 'coffee', '**/*.coffee', (t) => t .pipe coffee {bare: true}
watchableTask 'glsl'  , '**/*.glsl'  , (t) =>
  t .pipe transform 'utf8', (str) => "var code = `\n#{str.replace(/`/g,"'")}`;\nexport default code;"
    .pipe rename (path) => path.extname = ".js"


### Watching ###

gulp.task 'watch', (gulp.parallel watchables...)
gulp.task 'start', -> runChild "node #{toDistPath 'index.js'}"

gulp.task 'watch:start',
  gulp.parallel 'watch', () =>
    gulp.watch(toDistPath '**/*').on "change", (s) =>
      runChild "node #{toDistPath 'index.js'}"



### Versioning ###

versions = ['major', 'minor', 'dev']
incVersionWith = (v) => (str) =>
  json    = JSON.parse(str)
  version = json.version.split '.'
  if version.length != 3 then throw "Incorrect version '#{json.version}'."
  version = (parseInt a for a in version)
  idx = versions.indexOf v
  version[idx] += 1
  if idx != 0 then for j in [(idx-1)...0]
    version[j] = 0
  version = version.join '.'
  json.version = version
  JSON.stringify(json,null,2)

mkIncVersionTask = (name) =>
  gulp.task "incVersion:#{name}", ->
    gulp.src pkgCfgPath
      .pipe transform 'utf8', incVersionWith name
      .pipe gulp.dest(rootPath)

for v in versions
  mkIncVersionTask v


### Configurations ###

gulp.task 'copy:pkgCfg', -> gulp.src(pkgCfgPath).pipe gulp.dest distPath


### Group tasks ###

gulp.task 'build'   , gulp.series 'copy:pkgCfg', 'coffee', 'glsl'
gulp.task 'default' , gulp.series 'build'

mkPublishTask = (tag, useTag=true) =>
  sfx = if useTag then ":#{tag}" else ''
  gulp.task "publish#{sfx}" , gulp.series 'build', "incVersion:#{tag}", 'copy:pkgCfg', -> execSync "cd #{distPath} && npm publish", {stdio:'inherit'}

mkPublishTask 'dev', false
for v in versions
  mkPublishTask v

gulp.task 'sandboxServer', ->
  child = spawn("cd #{toRootPath 'examples'} && npx webpack-dev-server --open --env=sandbox", {shell: true})
  child.stdout.on 'data', (data) -> console.log(data.toString())
  child.stderr.on 'data', (data) -> console.log(data.toString())
  child.on        'close', (code) -> console.log(code.toString())

gulp.task 'sandbox', (gulp.series 'build', (gulp.parallel 'watch', 'sandboxServer'))

gulp.task 'mocha', ->
  runChild 'npx mocha ../test/**/*.spec.js'
gulp.task 'test', (gulp.series 'build', 'mocha')
