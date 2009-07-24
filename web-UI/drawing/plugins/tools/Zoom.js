dojo.provide("drawing.plugins.tools.Zoom");
dojo.require("drawing.plugins._Plugin");

drawing.plugins.tools.Zoom = drawing.util.oo.declare(
	// summary:
	//	A plugin that allows for zooming the canvas in and out. An
	//	actiontool is added to the toolbar with plus, minus and 100%
	//	buttons.
	// example:
	//	|	<div dojoType="drawing.Toolbar" drawingId="drawingNode" class="drawingToolbar vertical">
	//	|		<div tool="drawing.tools.Line" selected="true">Line</div>
	//	|		<div plugin="drawing.plugins.tools.Zoom" options="{zoomInc:.1,minZoom:.5,maxZoom:2}">Zoom</div>
	//	|	</div>
	//
	drawing.plugins._Plugin,
	function(options){
		var cls = options.node.className;
		var txt = options.node.innerHTML;
		this.domNode = dojo.create("div", {id:"btnZoom", "class":"toolCombo"}, options.node, "replace");
		
		this.makeButton("ZoomIn", this.topClass);
		this.makeButton("Zoom100", this.midClass);
		this.makeButton("ZoomOut", this.botClass);
		
	},
	{
		type:"drawing.plugins.tools.Zoom",
		//
		// 	zoomInc: Float
		//		The amount of zoom that will occur upon each click.
		zoomInc:.1,
		//
		//	maxZoom: Number
		//		The maximum the canvas can be zoomed in. 10 = 1000%
		maxZoom:10,
		//
		//	minZoom: Float
		//		The most the canvas can be zoomed out. .1 = 10%
		minZoom:.1,
		//
		//	zoomFactor: [readonly] Float
		//		The current zoom amount
		zoomFactor:1,
		//
		//	baseClass: String
		//		The CSS class added to the Toolbar buttons
		baseClass:"drawingButton",
		//
		//	topClass: String
		//		The CSS class added to the top (or left) Toolbar button
		topClass:"toolComboTop",
		//
		//	midClass: String
		//		The CSS class added to the middle Toolbar button
		midClass:"toolComboMid",
		//
		//	botClass: String
		//		The CSS class added to the bottom (or right) Toolbar button
		botClass:"toolComboBot",
		//
		makeButton: function(name, cls){
			// summary:
			//	Internal. Creates one of the buttons in the zoom-button set.
			//
			var node = dojo.create("div", {id:"btn"+name, "class":this.baseClass+" "+cls,
				innerHTML:'<div title="Zoom In" class="icon icon'+name+'"></div>'}, this.domNode);
			
			dojo.connect(document, "mouseup", function(evt){
				dojo.stopEvent(evt);
				dojo.removeClass(node, "active");
			});
			dojo.connect(node, "mouseup", this, function(evt){
				dojo.stopEvent(evt);
				dojo.removeClass(node, "active");
				this["on"+name](); // this is what calls the methods below
			});
			dojo.connect(node, "mouseover", function(evt){
				dojo.stopEvent(evt);
				dojo.addClass(node, "hover");
			});
			dojo.connect(node, "mousedown", this, function(evt){
				dojo.stopEvent(evt);
				dojo.addClass(node, "active");
			});
			
			dojo.connect(node, "mouseout", this, function(evt){
				dojo.stopEvent(evt);
				dojo.removeClass(node, "hover");
			});
		
		},
		
		onZoomIn: function(/*Mouse Event*/evt){
			// summary:
			//	Handles zoom in.
			//
			this.zoomFactor += this.zoomInc;
			this.zoomFactor = Math.min(this.zoomFactor, this.maxZoom);
			this.canvas.setZoom(this.zoomFactor);
			this.mouse.setZoom(this.zoomFactor);
		},
		onZoom100: function(/*Mouse Event*/evt){
			// summary:
			//	Zooms to 100%
			//
			this.zoomFactor = 1;
			this.canvas.setZoom(this.zoomFactor);
			this.mouse.setZoom(this.zoomFactor);
		},
		onZoomOut: function(/*Mouse Event*/evt){
			// summary:
			//	Handles zoom out.
			//
			this.zoomFactor -= this.zoomInc;
			this.zoomFactor = Math.max(this.zoomFactor, this.minZoom);
			this.canvas.setZoom(this.zoomFactor);
			this.mouse.setZoom(this.zoomFactor);
		}
	}
);