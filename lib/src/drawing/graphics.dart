part of stagexl.drawing;

/// A vector graphics drawing surface.
///
/// Example:
///
///     // draw a red circle
///     var shape = new Shape();
///     shape.graphics.circle(100, 100, 60);
///     shape.graphics.fillColor(Color.Red);
///     stage.addChild(shape);
///
/// **Note:** Stroke and fill operations act on the *preceding* vector
/// drawing operations.
///
/// **Warning:** The WebGL backend does not support vector graphics yet.
/// If you want to draw Graphics display objects please use the
/// [DisplayObject.applyCache] method which renders the vector graphics
/// to a texture or do not opt-in for the WebGL renderer.

class Graphics {

  static const Map _BASE_64 = const {
    "A": 0,"B": 1,"C": 2,"D": 3,"E": 4,"F": 5,"G": 6,"H": 7,
    "I": 8,"J": 9,"K":10,"L":11,"M":12,"N":13,"O":14,"P":15,
    "Q":16,"R":17,"S":18,"T":19,"U":20,"V":21,"W":22,"X":23,
    "Y":24,"Z":25,"a":26,"b":27,"c":28,"d":29,"e":30,"f":31,
    "g":32,"h":33,"i":34,"j":35,"k":36,"l":37,"m":38,"n":39,
    "o":40,"p":41,"q":42,"r":43,"s":44,"t":45,"u":46,"v":47,
    "w":48,"x":49,"y":50,"z":51,"0":52,"1":53,"2":54,"3":55,
    "4":56,"5":57,"6":58,"7":59,"8":60,"9":61,"+":62,"/":63};

  final List<GraphicsCommand> _commands = new List<GraphicsCommand>();

  //---------------------------------------------------------------------------

  /// Clear all previously added graphics commands.
  void clear() {
    _commands.clear();
  }

  /// Start drawing a freeform path.
  void beginPath() {
    _commands.add(new _GraphicsCommandBeginPath());
  }

  /// Stop drawing a freeform path.
  void closePath() {
    _commands.add(new _GraphicsCommandClosePath());
  }

  //---------------------------------------------------------------------------

  /// Moves the next point in the path to [x] and [y]
  void moveTo(num x, num y) {
    _commands.add(new _GraphicsCommandMoveTo(x, y));
  }

  /// From the current point in the path, draw a line to [x] and [y]
  void lineTo(num x, num y) {
    _commands.add(new _GraphicsCommandLineTo(x, y));
  }

  /// Draw a rectangle at [x] and [y]
  void rect(num x, num y, num width, num height) {
    _commands.add(new _GraphicsCommandRect(x, y, width, height));
  }

  /// Draw a rounded rectangle at [x] and [y].
  void rectRound(num x, num y, num width, num height, num ellipseWidth, num ellipseHeight) {
    _commands.add(new _GraphicsCommandRectRound(x, y, width, height, ellipseWidth, ellipseHeight));
  }

  /// Draw an arc at [x] and [y].
  void arc(num x, num y, num radius, num startAngle, num endAngle, [bool antiClockwise = false]) {
    _commands.add(new _GraphicsCommandArc(x, y, radius, startAngle, endAngle, antiClockwise));
  }

  /// From the current point in the path, draw an arc to [endX] and [endY]
  void arcTo(num controlX, num controlY, num endX, num endY, num radius) {
    _commands.add(new _GraphicsCommandArcTo(controlX, controlY, endX, endY, radius));
  }

  /// Draw a circle at [x] and [y]
  void circle(num x, num y, num radius, [bool antiClockwise = false]) {
    _commands.add(new _GraphicsCommandCircle(x, y, radius, antiClockwise));
  }

  /// Draw an ellipse at [x] and [y]
  void ellipse(num x, num y, num width, num height) {
    _commands.add(new _GraphicsCommandEllipse(x, y, width, height));
  }

  /// From the current point in the path, draw a quadratic curve to [endX] and [endY]
  void quadraticCurveTo(num controlX, num controlY, num endX, num endY) {
    _commands.add(new _GraphicsCommandQuadraticCurveTo(controlX, controlY, endX, endY));
  }

  /// From the current point in the path, draw a bezier curve to [endX] and [endY]
  void bezierCurveTo(num controlX1, num controlY1, num controlX2, num controlY2, num endX, num endY) {
    _commands.add(new _GraphicsCommandBezierCurveTo(controlX1, controlY1, controlX2, controlY2, endX, endY));
  }

  //---------------------------------------------------------------------------

  /// Apply a fill color to the **previously drawn** vector object.
  void fillColor(int color) {
    _commands.add(new _GraphicsCommandFillColor(color));
  }

  /// Apply a fill gradient to the **previously drawn** vector object.
  void fillGradient(GraphicsGradient gradient) {
    _commands.add(new _GraphicsCommandFillGradient(gradient));
  }

  /// Apply a fill pattern to the **previously drawn** vector object.
  void fillPattern(GraphicsPattern pattern) {
    _commands.add(new _GraphicsCommandFillPattern(pattern));
  }

  //---------------------------------------------------------------------------

  /// Apply a stroke color to the **previously drawn** vector object.
  void strokeColor(int color, [num width = 1.0, String joints = JointStyle.ROUND, String caps = CapsStyle.ROUND]) {
    _commands.add(new _GraphicsCommandStrokeColor(color, width, joints, caps));
  }

  /// Apply a stroke color to the **previously drawn** vector object.
  void strokeGradient(GraphicsGradient gradient, [num width = 1.0, String joints = JointStyle.ROUND, String caps = CapsStyle.ROUND]) {
    _commands.add(new _GraphicsCommandStrokeGradient(gradient, width, joints, caps));
  }

  /// Apply a stroke pattern to the **previously drawn** vector object.
  void strokePattern(GraphicsPattern pattern, [num width = 1.0, String joints = JointStyle.ROUND, String caps = CapsStyle.ROUND]) {
    _commands.add(new _GraphicsCommandStrokePattern(pattern, width, joints, caps));
  }

  //---------------------------------------------------------------------------

  void decode(String str)  {

    var base64 = _BASE_64;
    var instructions = [moveTo, lineTo, quadraticCurveTo, bezierCurveTo, closePath];
    List<int> paramCount = [2, 2, 4, 6, 0];
    List<num> params = new List<num>();
    var x=0, y=0;
    var i=0, l=str.length;

    while (i<l) {
      var c = str[i];
      var n = base64[c];
      var fi = n>>3; // highest order bits 1-3 code for operation.
      var f = instructions[fi];
      // check that we have a valid instruction & that the unused bits are empty:
      if (f == null || (n&3) > 0) throw new StateError("bad path data (@$i): $c");
      var pl = paramCount[fi];
      if (fi == 0) x=y=0; // move operations reset the position.
      params.length = 0;
      i++;
      var charCount = (n>>2&1)+2;  // 4th header bit indicates number size for this operation.
      for (var p=0; p<pl; p++) {
        var v = base64[str[i]];
        var sign = (v>>5) > 0 ? -1 : 1;
        v = ((v&31)<<6)|(base64[str[i+1]]);
        if (charCount == 3) v = (v<<6)|(base64[str[i+2]]);
        v = sign*v/10;
        if (p%2 > 0) x = (v += x);
        else y = (v += y);
        params.add(v);
        i += charCount;
      }
      Function.apply(f, params);
    }
  }

  //---------------------------------------------------------------------------
  //---------------------------------------------------------------------------

  Rectangle<num> get bounds {
    var graphicsContext = new GraphicsContextBounds();
    graphicsContext.applyGraphicsCommands(_commands);
    return graphicsContext.bounds;
  }

  bool hitTest(num localX, num localY) {
    var graphicsContext = new GraphicsContextHitTest();
    graphicsContext.applyGraphicsCommands(_commands);
    return graphicsContext.hit;
  }

  void render(RenderState renderState) {
    if (renderState.renderContext is RenderContextCanvas) {
      var graphicsContext = new GraphicsContextCanvas(renderState);
      graphicsContext.applyGraphicsCommands(_commands);
    } else {
      var graphicsContext = new GraphicsContextRender(renderState);
      graphicsContext.applyGraphicsCommands(_commands);
    }
  }

  void renderMask(RenderState renderState) {
    if (renderState.renderContext is RenderContextCanvas) {
      var graphicsContext = new GraphicsContextCanvasMask(renderState);
      graphicsContext.applyGraphicsCommands(_commands);
    } else {
      var graphicsContext = new GraphicsContextRenderMask(renderState);
      graphicsContext.applyGraphicsCommands(_commands);
    }
  }

}
