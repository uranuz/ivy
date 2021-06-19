module ivy.types.data.control_render;

struct FirControlRender(O, Interp)
{
	import std.range: empty;
	import trifle.parse_utils: front, popFront;

	import ivy.types.data.iface.class_node: IClassNode;

	alias OutRange = O;

	OutRange* _outRange;
	IClassNode _classNode;
	Interp _interp;

	ParseState _state;
	bool _isQuotedAttr = false;

	enum ParseState: ubyte {
		init,
		tagOpened,
		tagClosed
	}


	this(ref OutRange outRange, IClassNode classNode, Interp interp)
	{
		this._outRange = &outRange;
		this._classNode = classNode;
		this._interp = interp;
	}

	void put(string val)
	{
		if (this._state == ParseState.tagClosed) {
			// If tag is closed then just put rest data to out range
			(*this._outRange).put(val);
			return;
		}
		
		while( !val.empty )
		{
			this.put(val.front);
			// Move to the next character
			val.popFront();
		}
	}

	void put(char ch)
	{
		import std.conv: to;

		this._handleChar(ch);
		// Put character into output
		(*this._outRange).put(ch.to!string);
	}


	void _handleChar(char ch)
	{
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
	}

	void _injectExtras()
	{
		import ivy.types.data: IvyData;

		import std.base64: Base64;

		import ivy.types.data.render: renderDataNode2, DataRenderType;

		string moduleName = this._classNode.__getAttr__("moduleName").str;
		string encodedOpts = cast(string) Base64.encode(
			cast(ubyte[]) renderDataNode2!(DataRenderType.JSON)(IvyData(this._classNode), this._interp));

		(*this._outRange).put(" data-fir-module=\"");
		(*this._outRange).put(moduleName);
		(*this._outRange).put("\" data-fir-opts=\"");
		(*this._outRange).put(encodedOpts);
		(*this._outRange).put("\"");
	}
}