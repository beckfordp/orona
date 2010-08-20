###
Orona, © 2010 Stéphan Kochen

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
###

# Portions of this are based on: (both are MIT-licensed)
# - CoffeeScript's command.coffee, © 2010 Jeremy Ashkenas
# - Yabble's yabbler.js, © 2010 James Brantly

# FIXME: watch functionality, as in 'coffee -w ...'
# FIXME: minify client bundle
# FIXME: include jquery and yabble in client bundle

{puts}       = require 'sys'
fs           = require 'fs'
path         = require 'path'
{spawn}      = require 'child_process'
CoffeeScript = require 'coffee-script'


# Determine the module dependencies of a piece of JavaScript.
determineDependencies = (module) ->
  retval = []

  # Walk through all the require() calls in the code.
  re = /(?:^|[^\w\$_.])require(?:\s+|\s*\(\s*)("[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*')/g
  while match = re.exec(module.code)
    requirePath = eval match[1]
    dep = { external: no }

    # An absolute path, assume it's an external dependency.
    unless requirePath.charAt(0) == '.'
      dep.name = requirePath
      dep.external = yes

    # Find the module name and file name of this dependency
    else
      # Get the base directory we're going to start our search with.
      nameParts = module.name.split('/'); nameParts.pop()
      fileParts = module.file.split('/'); fileParts.pop()

      # Walk the require-path.
      for part in requirePath.split('/')
        switch part
          when '.'  then continue
          when '..' then nameParts.pop();      fileParts.pop()
          else           nameParts.push(part); fileParts.push(part)

      # Set the module attributes. For the filename, we need to check if the path
      # is pointing at a file or a directory. In the latter, we use the 'index'
      # module inside the directory.
      dep.name = nameParts.join('/')
      fileName =  fileParts.join('/')
      try
        fileStat = fs.statSync(fileName)
        directory = true
      catch e
        directory = false
      if directory
        unless fileStat.isDirectory()
          throw new Error("Expected '#{fileName}' to be a directory.")
        dep.file = "#{fileName}/index.coffee"
      else
        # Assume there's a '.coffee' source file.
        dep.file = "#{fileName}.coffee"

    # Collect it.
    retval.push(dep)

  retval

# Iterate on the given module and its dependencies.
iterateDependencyTree = (module, depsSeen, cb) ->
  # On first invocation, we're given different parameters.
  if typeof(module) == 'string'
    [fileName, moduleName, cb] = arguments
    # The specified file is assumed to have the module identifier given by moduleName.
    # All the dependencies will be given module names relative to this.
    module = { name: moduleName, file: fileName, external: no }
    depsSeen = []

  # Check to see if we've already iterated this module.
  for dep in depsSeen
    return if module.name == dep.name
  depsSeen.push module

  # Read the source code.
  module.code = fs.readFileSync module.file, 'utf-8'
  # Store the dependencies here, so the callback may use them.
  module.dependencies = determineDependencies(module)
  # Callback on the module.
  cb(module)
  # Recurse for dependencies, unless external.
  for dep in module.dependencies
    iterateDependencyTree(dep, depsSeen, cb) unless dep.external
  return

# Wrap some JavaScript that came from some file into a module transport definition.
wrapModule = (module, js) ->
  dependencies = "'#{dep.name}'" for dep in module.dependencies

  """
    require.define({'#{module.name}': function(require, exports, module) {
    #{js}
    }}, [#{dependencies.join(', ')}]);
    
  """

# Build the lib/ output path for a file underneath src/.
buildOutputPath = (module) ->
  parts = module.file.split('/')
  parts[0] = 'lib'
  basename = parts.pop().replace(/\.coffee$/, '.js')

  # Create the parent directories.
  partial = ''
  for part in parts
    partial += "#{part}/"
    try
      fs.mkdirSync partial, 0777
    catch e
      false # Assume already exists.

  parts.push(basename)
  parts.join('/')


# Task definitions.

task 'build:client', 'Compile the Bolo client-side module bundle', ->
  puts "Building Bolo client JavaScript bundle..."
  output = fs.openSync 'public/bolo-bundle.js', 'w'
  iterateDependencyTree 'src/client/index.coffee', 'bolo/client', (module) ->
    js = CoffeeScript.compile module.code, fileName: module.file, noWrap: yes
    wrappedJs = wrapModule module, js
    fs.writeSync output, wrappedJs
    puts "Compiled '#{module.file}'."
  fs.closeSync output
  puts "Done."
  puts ""

task 'build:server', 'Compile the Bolo server-side modules', ->
  puts "Building Bolo server modules..."
  iterateDependencyTree 'src/server/index.coffee', 'bolo/server', (module) ->
    js = CoffeeScript.compile module.code, fileName: module.file
    output = buildOutputPath module
    fs.writeFileSync output, js
    puts "Compiled '#{module.file}'."
  puts "Done."
  puts ""

task 'build', 'Compile the Bolo client and server.', ->
  invoke 'build:server'
  invoke 'build:client'

task 'run', 'Compile the Bolo client and server, then run the server', ->
  invoke 'build'

  puts "Starting Bolo server..."
  spawn 'bin/bolo-server', [], customFds: [process.stdout, process.stdout -1]
