# The base class for all renderers is defined here. A renderer is responsible for drawing the map,
# objects on the map, HUD map overlays and HUD screen overlays. Especially of the last two points,
# a lot of shared code lives in this base class. Methods that need to be implemented by subclasses
# are stubbed out here. All renderers also implement the `MapView` interface.


{round, cos, sin, PI} = Math
{TILE_SIZE_PIXELS,
 PIXEL_SIZE_WORLD}    = require '../../constants'


class BaseRenderer
  # The constructor takes a reference to the Image resources and the Simulation it needs to draw.
  # Once the constructor finishes, `Map#setView` is called to hook up this renderer instance, which
  # causes onRetile to be invoked once for each tile to initialize.
  constructor: (@images, @sim) ->
    @lastCenter = [0, 0]

  # This methods takes x and y coordinates to center the screen on. The callback provided should be
  # invoked exactly once. Any drawing operations used from within the callback will have a
  # translation applied so that the given coordinates become the center on the screen.
  centerOn: (x, y, cb) ->

  # Draw the tile (tx,ty), which are x and y indices in the base tilemap (and not pixel
  # coordinates), so that the top left corner of the tile is placed at (sdx,sdy) pixel coordinates
  # on the screen. The destination coordinates may be subject to translation from centerOn.
  drawTile: (tx, ty, sdx, sdy) ->

  # Similar to drawTile, but draws from the styled tilemap. Takes an additional parameter `style`,
  # which is a selection from the team colors. The overlay tile is drawn in this color on top of
  # the tile from the styled tilemap. If the style doesn't exist, no overlay is drawn.
  drawStyledTile: (tx, ty, style, sdx, sdy) ->

  # Draw the map section that intersects with the given boundary box (sx,sy,w,h). The boundary
  # box is given in pixel coordinates. This may very well be a no-op if the renderer can do all of
  # its work in onRetile.
  drawMap: (sx, sy, w, h) ->

  # Inherited from MapView.
  onRetile: (cell, tx, ty) ->

  #### Common functions.

  # Draw a single frame.
  draw: ->
    {x, y} = @sim.player

    # Remember or restore the last center position. We use this after tank
    # death, so as to keep drawing something useful while we fade.
    unless x? and y?
      [x, y] = @lastCenter
    else
      @lastCenter = [x, y]

    @centerOn x, y, (left, top, width, height) =>
      # Draw all canvas elements.
      @drawMap(left, top, width, height)
      for obj in @sim.objects when obj.styled? and obj.x? and obj.y?
        [tx, ty] = obj.getTile()
        ox = round(obj.x / PIXEL_SIZE_WORLD) - TILE_SIZE_PIXELS / 2
        oy = round(obj.y / PIXEL_SIZE_WORLD) - TILE_SIZE_PIXELS / 2
        switch obj.styled
          when true  then @drawStyledTile tx, ty, obj.team, ox, oy
          when false then @drawTile tx, ty, ox, oy
      @drawOverlay()

    # Update all DOM HUD elements.
    @updateHud()

  #### HUD elements

  # Draw HUD elements that overlay the map. These are elements that need to be drawn in regular
  # game coordinates, rather than screen coordinates.
  drawOverlay: ->
    # FIXME: variable firing distance
    # FIXME: hide when dead
    distance = 7 * TILE_SIZE_PIXELS
    rad = (256 - @sim.player.direction) * 2 * PI / 256
    x = round(@sim.player.x / PIXEL_SIZE_WORLD + cos(rad) * distance) - TILE_SIZE_PIXELS / 2
    y = round(@sim.player.y / PIXEL_SIZE_WORLD + sin(rad) * distance) - TILE_SIZE_PIXELS / 2

    @drawTile 17, 4, x, y

  # Create the HUD container.
  initHud: ->
    @hud = $('<div/>').appendTo('body')

    # Create the pillbox status indicator.
    container = $('<div/>', id: 'pillStatus').appendTo(@hud)
    $('<div/>', class: 'deco').appendTo(container)
    $('<div/>', class: 'pill').appendTo(container).data('pill', pill) for pill in @sim.map.pills

    # Create the base status indicator.
    container = $('<div/>', id: 'baseStatus').appendTo(@hud)
    $('<div/>', class: 'deco').appendTo(container)
    $('<div/>', class: 'base').appendTo(container).data('base', base) for base in @sim.map.bases

    # Show WIP notice. This is really a temporary hack, so FIXME someday.
    if location.hostname.split('.')[1] == 'github'
      $('<div/>').html('''
        This is a work-in-progress; less than alpha quality!<br>
        To see multiplayer in action, follow instructions on Github.
      ''').css(
        'position': 'absolute', 'top': '8px', 'left': '0px', 'width': '100%', 'text-align': 'center',
        'font-family': 'monospace', 'font-size': '16px', 'font-weight': 'bold', 'color': 'white'
      ).appendTo(@hud);

    # Show GitHub ribbon. Also temporary. FIXME
    if location.hostname.split('.')[1] == 'github' or location.hostname.substr(-6) == '.no.de'
      $('<a href="http://github.com/stephank/orona"></a>')
        .css('position': 'absolute', 'top': '0px', 'right': '0px')
        .html('<img src="http://s3.amazonaws.com/github/ribbons/forkme_right_darkblue_121621.png" alt="Fork me on GitHub">')
        .appendTo(@hud);

    # One-shot update to set all the real-time attributes.
    @updateHud()

  # Update the HUD elements.
  updateHud: ->
    # Pillboxes.
    @hud.find('#pillStatus .pill').each (i, node) =>
      # FIXME: allegiance
      $(node).attr('status', 'neutral')

    # Bases.
    @hud.find('#baseStatus .base').each (i, node) =>
      # FIXME: allegiance
      $(node).attr('status', 'neutral')


#### Exports
module.exports = BaseRenderer