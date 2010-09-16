# All objects that a `Simulation` keeps track of inherit from `WorldObject`. This base class mostly
# deals with state synchronisation and defines an interface for tick updates and graphics.


{pack, unpack} = require './struct'


# The types indexed by their charId.
types = {}


# The base class of world objects.
class WorldObject
  # This is a single character identifier for this class. It's handy for type checks without
  # having to require the module, but is also used as the network identifier.
  charId: null

  # Whether objects of this class are drawn using the regular 'base' tilemap, or the styled
  # tilemap. May also be `null`, in which case the object is not drawn at all.
  styled: null

  # These are properties containing the world coordinates of this object. These are actually
  # defined in the constructor. A special value of -1 for either means that the object is
  # 'not in the world'. For now, only used by dead tanks.
  x: -1
  y: -1

  # Instantiating a WorldObject is usually done using `sim.spawn MyObject, params...`. This wraps
  # the call to the actual constructor, and the simulation can thus keep track of the object.
  #
  # Even though not specified in `params`, the first parameter is always the Simulation instance,
  # and should always be passed on to this base class its constructor using a call such as
  # `super(sim)` as one of the first things.
  #
  # Note that this constructor is *not* invoked for objects instantiated from the network code.
  # The network code instead instantiates using a blank constructor, calls `deserialize`, and
  # then proceeds as normal with `postInitialize` and further updates.
  constructor: (@sim) ->

  # Return the (x,y) index in the tilemap (base or styled, selected above) that the object should
  # be drawn with. May be a no-op if the object is never actually drawn.
  getTile: ->

  # The following are optional callbacks, and thus no-ops by default.
  # It's not hard to implement more, but these are the ones currently used.

  # Called after the object has been added to the Simulation, either through normal means or
  # through the network code.
  postInitialize: ->

  # Called after a network update has been processed.
  postNetUpdate: ->

  # Called before the object is about the be removed from the Simulation, either through normal
  # means or through the network code.
  preRemove: ->

  # Called when the object is destroyed through normal means. This may happen on the simulation
  # authority (local game or server), but also simulated on a client.
  destroy: ->

  # Called on every tick, either on the authority (local game or server)
  # or simulated on the client.
  update: ->

  # The following govern serialization, and are normally not overridden.

  # This method is called to serialize and deserialize an object's state. The parameter `p`
  # is a function which should be repeatedly called for each property of the object. It takes as
  # it's first parameter a format specifier for `struct.pack`, and as it's second parameter the
  # current value of the property.
  #
  # If the function is called to serialize, then parameters are collected to form a packet, and
  # the return value is the same as the value parameter verbatim. If the function is called to
  # deserialize, then the value parameter is ignored, and the return value is the received value.
  #
  # Subclasses may override this, but should always call super.
  serialization: (p) ->
    @x = p('H', @x)
    @y = p('H', @y)

  # This method returns an array of bytes, containing the object's state. The default
  # implementation prepares a function and passes it to `serialization`. Subclasses normally
  # need not override this method.
  getSerializedState: ->
    specifiers = []
    values = []
    flags = []

    # Call the serialization function, with our property serializer function.
    @serialization (specifier, value) ->
      # Group flags.
      if specifier == 'f'
        flags.push value
      # Handle the special 'O' specifier.
      else if specifier == 'O'
        specifiers.push 'H'
        values.push value.idx
      # Nothing special.
      else
        specifiers.push specifier
        values.push value
      # Return the value verbatim.
      value
    # Add the grouped flags to the rest.
    specifiers.push 'f' for i in [0...flags.length]
    values = values.concat(flags)

    # Pack it up.
    pack.apply this, [specifiers.join('')].concat(values)

  # This methods takes an array of bytes and an optional offset, at which to find data originally
  # generated by serialize. This method is then responsible for translating that data back into
  # object state. Finally, it returns the number of bytes it used.
  #
  # The default implementation prepares a function and passes it to `serialization`. Subclasses
  # normally need not override this method.
  loadStateFromData: (data, offset) ->
    # We actually make two passes: one to get the complete format string, and one to
    # finally set the properties' new values.
    specifiers = []
    flags = 0
    @serialization (specifier, value) ->
      # Group flags.
      if specifier == 'f'
        flags++
      # Handle the special 'O' specifier.
      else if specifier == 'O'
        specifiers.push 'H'
      # Nothing special.
      else
        specifiers.push specifier
      # Return the value verbatim.
      value
    # Add the grouped flags to the rest.
    firstFlag = specifiers.length
    specifiers.push 'f' for i in [0...flags]

    # Now, unpack and set.
    [values, bytes] = unpack specifiers.join(''), data, offset
    i = 0
    fi = firstFlag
    @serialization (specifier, value) =>
      if specifier == 'f'
        values[fi++]
      else if specifier == 'O'
        @sim.objects[values[i++]]
      else
        values[i++]

    # Return the number of bytes we ate.
    bytes

  # Class methods.

  # Called by CoffeeScript when subclassed.
  @extended: (child) ->
    # Make the register class method available on the subclass.
    child.register = @register

  # Find a type by character or character code.
  @getType: (c) ->
    c = String.fromCharCode(c) if typeof(c) != 'string'
    types[c]

  # This should be called after a class is defined, as for example `MyObject.register()`.
  # FIXME: Would be neat if this were automagic somehow.
  @register: ->
    # Add to the index.
    types[@::charId] = this
    # Set the character code, which is the network identifier.
    @::charCodeId = @::charId.charCodeAt(0)


# Exports.
module.exports = WorldObject
