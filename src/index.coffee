###
Orona, © 2010 Stéphan Kochen

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
###

net = require './net'

# These requires are to ensure that all world objects are registered.
require './tank'
require './explosion'
require './shell'


class Simulation
  constructor: (@map) ->
    @objects = []
    @tanks = []

  # Basic object management.

  tick: ->
    # Work on a shallow copy of the object list.
    for obj in @objects.slice(0)
      obj.update()
    return

  spawn: (type, args...) ->
    obj = new type(this, args...)
    # Register it.
    obj.idx = @objects.length
    @objects.push obj
    # Notify networking.
    net.created obj
    # Return the new object.
    obj

  destroy: (obj, destructor) ->
    # Call the destructor.
    destructor ||= obj.destroy
    destructor.apply(obj)
    # Remove it from the list.
    @objects.splice obj.idx, 1
    # Update the indices of everything that follows.
    for i in [obj.idx...@objects.length]
      @objects[i].idx--
    # Notify networking.
    net.destroyed obj
    # Return the same object.
    obj

  # Player management.

  addTank: (tank) ->
    tank.tank_idx = @tanks.length
    @tanks.push tank
    @resolveMapObjects()

  removeTank: (tank) ->
    @tanks.splice tank.tank_idx, 1
    @resolveMapObjects()

  # Resolve pillbox and base owner indices to the actual tanks.
  resolveMapObjects: ->
    mapObjects = @map.pills.concat @map.bases
    for obj in mapObjects
      obj.owner = @tanks[obj.owner_idx]
      obj.cell.retile()
    return


# Exports.
module.exports = Simulation
