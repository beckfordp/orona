###
Orona, © 2010 Stéphan Kochen

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
###

{floor}           = Math
{MapView}         = require '../map'
{TILE_SIZE_PIXEL,
 MAP_SIZE_TILES}  = require '../constants'

SEGMENT_SIZE_TILES = 16
MAP_SIZE_SEGMENTS = MAP_SIZE_TILES / SEGMENT_SIZE_TILES
SEGMENT_SIZE_PIXEL = SEGMENT_SIZE_TILES * TILE_SIZE_PIXEL


class CachedSegment
  constructor: (@view, x, y) ->
    # Tile bounds
    @sx = x * SEGMENT_SIZE_TILES
    @sy = y * SEGMENT_SIZE_TILES
    @ex = @sx + SEGMENT_SIZE_TILES - 1
    @ey = @sy + SEGMENT_SIZE_TILES - 1

    # Pixel bounds
    @psx = x * SEGMENT_SIZE_PIXEL
    @psy = y * SEGMENT_SIZE_PIXEL
    @pex = @psx + SEGMENT_SIZE_PIXEL - 1
    @pey = @psy + SEGMENT_SIZE_PIXEL - 1

    @canvas = null

  isInView: (sx, sy, ex, ey) ->
    # Compare canvas pixel bounds to our own.
    # We can reduce the number of conditions by checking if we don't overlap,
    # rather than if we do.
    if      ex < @psx or ey < @psy then false
    else if sx > @pex or sy > @pey then false
    else true

  build: ->
    # Create the canvas.
    @canvas = $('<canvas/>')[0]
    @canvas.width = @canvas.height = SEGMENT_SIZE_PIXEL
    @ctx = @canvas.getContext('2d')

    # Apply a permanent translation, so we can draw regular map pixel coordinates.
    @ctx.translate(-@psx, -@psy)

    # Iterate the map tiles in this segment, and draw them.
    @view.map.each (cell) =>
      @onRetile(cell, cell.tile[0], cell.tile[1])
    , @sx, @sy, @ex, @ey

  clear: ->
    @canvas = @ctx = null

  onRetile: (cell, tx, ty) ->
    return unless @canvas
    @ctx.drawImage @view.tilemap,
      tx * TILE_SIZE_PIXEL,     ty * TILE_SIZE_PIXEL,     TILE_SIZE_PIXEL, TILE_SIZE_PIXEL,
      cell.x * TILE_SIZE_PIXEL, cell.y * TILE_SIZE_PIXEL, TILE_SIZE_PIXEL, TILE_SIZE_PIXEL

class Offscreen2dMapView extends MapView
  constructor: (@tilemap, @map) ->
    # Build a 2D array of map segments.
    @cache = new Array(MAP_SIZE_SEGMENTS)
    for y in [0...MAP_SIZE_SEGMENTS]
      row = @cache[y] = new Array(MAP_SIZE_SEGMENTS)
      for x in [0...MAP_SIZE_SEGMENTS]
        row[x] = new CachedSegment(this, x, y)

  onRetile: (cell, tx, ty) ->
    # Remember the tilemap index.
    cell.tile = [tx, ty]

    # Notify the segment, so it can update it's buffer if it has one.
    segx = floor(cell.x / SEGMENT_SIZE_TILES)
    segy = floor(cell.y / SEGMENT_SIZE_TILES)
    @cache[segy][segx].onRetile(cell, tx, ty)

  draw: (c, sx, sy, w, h) ->
    ex = sx + w - 1
    ey = sy + h - 1

    # Iterate all cache segments.
    alreadyBuiltOne = no
    for row in @cache
      for segment in row
        # Skip if not in view.
        if not segment.isInView(sx, sy, ex, ey)
          segment.clear() if segment.canvas
          continue

        # Make sure the segment buffer is available.
        unless segment.canvas
          # Let's only draw one segment per frame, to keep things smooth.
          continue if alreadyBuiltOne
          segment.build()
          alreadyBuiltOne = yes

        # Blit the segment to the screen.
        c.drawImage segment.canvas,
          0,           0,           SEGMENT_SIZE_PIXEL, SEGMENT_SIZE_PIXEL,
          segment.psx, segment.psy, SEGMENT_SIZE_PIXEL, SEGMENT_SIZE_PIXEL

    return


# Exports
exports.Offscreen2dMapView = Offscreen2dMapView