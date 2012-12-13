###

  KDTooltip

  A tooltip has a position and a direction, relative to the delegate
  element it is attached to.

  Valid positioning types are 'top','bottom','left' and 'right'
  Valid direction types are 'top','bottom','left','right' and 'center'

  Should a tooltip move off-screen, it will be relocated to be fully
  visible.

###

class KDTooltip extends KDView

  constructor:(options,data)->

    options = $.extend {}, options,
      bind  : "mouseenter mouseleave"

    super options,data

    @avoidDestroy = no

    # Container for positioning in the viewport
    @setClass 'kdtooltip'
    @setClass options.viewCssClass if options.viewCssClass?

    # Wrapper for the view and/or content of the tooltip
    @wrapper    = new KDView
      cssClass  : 'wrapper'

    # Arrow Container for Tooltip design arrows
    @arrow = new KDView
      cssClass : 'arrow'

    if @getOptions().animate
      @setClass 'out'
    else
      @hide()

    @on 'mouseenter', =>
      @avoidDestroy = yes

    @on 'mouseleave', =>
      @avoidDestroy = no
      @delayedDestroy()

    @on 'MouseEnteredAnchor', =>
      @avoidDestroy = yes
      @delayedDisplay()

    @on 'MouseLeftAnchor', =>
      @avoidDestroy = no
      @delayedDestroy()

    @on 'ReceivedClickElsewhere', =>
      @delayedDestroy 0

    KDView.appendToDOMBody @
    @getSingleton('windowController').addLayer @

  setView:(newView)->
    return unless newView

    if @wrapper.view?
      @wrapper.removeSubView @wrapper.view

    {options, data, constructorName} = newView

    options.delegate ?= @getDelegate()
    @view = new constructorName options, data
    @wrapper.addSubView @view

  getView:->
    @view

  delayedDisplay:(timeout = @getOptions().delayIn)->
    @utils.killWait @displayTimer
    @displayTimer = @utils.wait timeout, =>
      if @avoidDestroy
        @display()
      else
        @delayedDestroy()

  delayedDestroy:(timeout = @getOptions().delayOut)->
    @utils.killWait @deleteTimer
    @deleteTimer = @utils.wait timeout, =>
      unless @avoidDestroy
        # return 1
        if @getOptions().animate
          @unsetClass 'in'

          @utils.killWait @animatedDeleteTimer
          @animatedDeleteTimer = @utils.wait 2000, =>

            @getDelegate().removeTooltip @

        else
          @getDelegate().removeTooltip @

  translateCompassDirections:(o)->

    {placement,gravity} = o
    o.placement = placementMap[placement]
    o.direction = directionMap(o.placement, gravity)

    # unless o.placement and o.direction
    #   switch o.placement
    #     when 'above'
    #       o.placement = 'top'
    #       switch o.gravity
    #         when 'n','s'
    #           o.direction = 'center'
    #         when 'e','ne','se'
    #           o.direction = 'left'
    #         when 'w','nw','sw'
    #           o.direction = 'right'
    #     when 'below'
    #       o.placement = 'bottom'
    #       switch o.gravity
    #         when 'n','s'
    #           o.direction = 'center'
    #         when 'e','ne','se'
    #           o.direction = 'left'
    #         when 'w','nw','sw'
    #           o.direction = 'right'
    #     when 'left'
    #       switch o.gravity
    #         when 'n','nw','ne'
    #           o.direction = 'top'
    #         when 'e','w'
    #           o.direction = 'left'
    #         when 's','sw','se'
    #           o.direction = 'bottom'
    #     when 'right'
    #       switch o.gravity
    #         when 'n','ne','nw'
    #           o.direction = 'top'
    #         when 'e','w'
    #           o.direction = 'right'
    #         when 'w','se','sw'
    #           o.direction = 'bottom'
    return o

  display:(o = @getOptions())->

    # converts NESW-Values to topbottomleftright and retains them in
    # @getOptions
    o = @translateCompassDirections o if o.gravity

    if o.animate
      @show()
      @setClass 'in'

    else
      @show()

    @setPosition(o)

  getCorrectPositionCoordinates:(o={},positionValues,callback=noop)->
    # values that can/will be used in all the submethods
    container       = @$()
    containerHeight = container.height()
    containerWidth  = container.width()
    selector        = @getDelegate().$(o.selector)
    selectorOffset  = selector.offset()
    selectorHeight  = selector.height()
    selectorWidth   = selector.width()

    # will return an object with the amount of clipped pixels
    boundaryViolations = (coordinates,width,height)=>
      violations = {}
      if coordinates.left < 0
        violations.left   = -(coordinates.left)
      if coordinates.top  < 0
        violations.top    = -(coordinates.top)
      if coordinates.left+width > window.innerWidth
        violations.right  = coordinates.left+width-window.innerWidth
      if coordinates.top+height > window.innerHeight
        violations.bottom = coordinates.top+height-window.innerHeight
      violations

    # get default coordinates for tooltip placement
    getCoordsFromPositionValues = (placement,direction)=>

      c =
        top  : selectorOffset.top
        left : selectorOffset.left



      switch placement
        when 'top'
          c.top       -= containerHeight+10
          switch direction
            when 'left'
              c.left  += selectorWidth-containerWidth
            when 'center'
              c.left  += (selectorWidth-containerWidth)/2
        when 'bottom'
          c.top       += selectorHeight+10
          switch direction
            when 'left'
              c.left  += selectorWidth-containerWidth
            when 'center'
              c.left  += (selectorWidth-containerWidth)/2
        when 'right'
          c.left      += selectorWidth+10
          switch direction
            when 'top'
              c.top   += selectorHeight-containerHeight
            when 'center'
              c.top   += (selectorHeight-containerHeight)/2
        when 'left'
          c.left      -= containerWidth+25
          switch direction
            when 'top'
              c.top   += selectorHeight-containerHeight
            when 'center'
              c.top   += (selectorHeight-containerHeight)/2
      return c

    {placement,direction} = positionValues

    # check the default values for overlapping boundaries, then
    # recalculate if there are overlaps

    violations = boundaryViolations getCoordsFromPositionValues(placement, direction), containerWidth, containerHeight

    if Object.keys(violations).length > 0
      variants = [
        ['top','left']
        ['top','center']
        ['top','right']
        ['right','top']
        ['right','center']
        ['right','bottom']
        ['bottom','right']
        ['bottom','center']
        ['bottom','left']
        ['left','bottom']
        ['left','center']
        ['left','top']
      ]

      for variant in variants
        if Object.keys(boundaryViolations(getCoordsFromPositionValues(variant[0],variant[1]), containerWidth, containerHeight)).length is 0
          [placement,direction] = variant
          break

    correctValues =
      coords : getCoordsFromPositionValues placement, direction
      placement : placement
      direction : direction

    callback correctValues
    return correctValues

  setPosition:(o={})->

    placement = o.placement or 'top'
    direction = o.direction or 'right'

    offset =
      if Number is typeof o.offset
        top   : o.offset
        left  : 0
      else
        o.offset

    # Correct impossible combinations
    direction =
      if placement in ['top','bottom'] and direction in ['top','bottom']
        'center'
      else if placement in ['left','right'] and direction in ['left','right']
         'center'
        else direction

    # fetch corrected placement and coordinated for positioning
    {coords,placement,direction} = @getCorrectPositionCoordinates o,{placement,direction}

    # css classes for arrow positioning
    for placement_ in ['top','bottom','left','right']
      if placement is placement_
        @setClass 'placement-'+placement_
      else
        @unsetClass 'placement-'+placement_

    for direction_ in ['top','bottom','left','right','center']
      if direction is direction_
        @setClass 'direction-'+direction_
      else
        @unsetClass 'direction-'+direction_

    @$().css
      left : coords.left+offset.left
      top : coords.top+offset.top

  setTitle:(title,o={})->
    unless o.html is no
      @wrapper.updatePartial title
    else
      @wrapper.updatePartial Encoder.htmlEncode title

  viewAppended:->
    super()
    o = @getOptions()

    if o.view?
      @setView o.view
    else
      @setClass 'just-text'
      @setTitle o.title, o

    @setTemplate @pistachio()
    @template.update()

    if @getDelegate()?
      @getDelegate().emit 'TooltipReady'
    else
      @parent?.emit 'TooltipReady'

  pistachio:->
    """
     {{> @arrow}}
     {{> @wrapper}}
    """

  directionMap = (placement, gravity)->
    if placement in ["top", "bottom"]
      if /e/.test gravity then "left"
      else if /w/.test gravity then "right"
      else "center"
    else if placement in ["left", "right"]
      if /n/.test gravity then "top"
      else if /s/.test gravity then "bottom"
      else placement

  placementMap =
    above   : "top"
    below   : "bottom"
    left    : "left"
    right   : "right"
