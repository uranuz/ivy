define('ivy/types/data/control_render', [
	'ivy/types/data/render'
], function(
	DataRender
) {
var 
	renderDataNode2 = DataRender.renderDataNode2,
	DataRenderType = DataRender.DataRenderType,
	ParseState = {
		init: 0,
		tagOpened: 1,
		tagClosed: 2
	};

return FirClass(function(outRange, classNode, interp) {
		this._outRange = outRange;
		this._classNode = classNode;
		this._interp = interp;

		this._state = ParseState.init;
		this._isQuotedAttr = false;
	}, {
		put: function(val) {
			if (this._state == ParseState.tagClosed) {
				// If tag is closed then just put rest data to out range
				this._outRange.put(val);
				return;
			}
			
			while( !val.empty )
			{
				this.put(val.front);
				// Move to the next character
				val.popFront();
			}
		},

		put: function(ch) {
			this._handleChar(ch);
			// Put character into output
			this._outRange.put(ch);
		},


		_handleChar: function(ch) {
			if( ch == '"' )
			{
				// Handle quotes around tag attributes and toggle "quoted" mode
				this._isQuotedAttr = !this._isQuotedAttr;
				return;
			}
			if( this._isQuotedAttr ) {
				// If we are in quoted mode then don't analyze tag open/ close...
				return;
			}
			if( ch == '<' && this._state == ParseState.init ) {
				// If we are in init state then detect that first tag was opened...
				this._state = ParseState.tagOpened;
				return;
			}
			if( ch == '>' && this._state == ParseState.tagOpened )
			{
				// If first tag was opened then detect that it was closed
				this._state = ParseState.tagClosed;
				// Inject extra data before closing tag
				this._injectExtras();
			}
		},

		_injectExtras: function() {
			var
				moduleName = this._classNode.__getAttr__("moduleName").str;
				encodedOpts = Base64.encode(renderDataNode2(DataRenderType.JSON, IvyData(this._classNode), this._interp));

			this._outRange.put(" data-fir-module=\"");
			this._outRange.put(moduleName);
			this._outRange.put("\" data-fir-opts=\"");
			this._outRange.put(encodedOpts);
			this._outRange.put("\"");
		}
	});

})