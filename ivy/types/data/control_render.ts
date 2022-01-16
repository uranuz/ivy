import {renderDataNode2, DataRenderType, appender} from 'ivy/types/data/render';
import {IClassNode} from 'ivy/types/data/iface/class_node';
import {Interpreter} from 'ivy/interpreter/interpreter';

declare var Base64: any;

enum ParseState{
	init,
	tagOpened,
	tagClosed
}

export class FirControlRender {
	public _outRange: appender | FirControlRender;
	private _classNode: IClassNode;
	private _interp: Interpreter;

	private _state: ParseState;
	private _isQuotedAttr: boolean;

	constructor(outRange: appender | FirControlRender, classNode: IClassNode, interp: Interpreter) {
		this._outRange = outRange;
		this._classNode = classNode;
		this._interp = interp;

		this._state = ParseState.init;
		this._isQuotedAttr = false;
	}

	put(val: string): void {
		if (this._state == ParseState.tagClosed) {
			// If tag is closed then just put rest data to out range
			this._outRange.put(val);
			return;
		}

		for( let ch of val ) {
			this.putCh(ch);
		}
	}

	putCh(ch: string): void {
		this._handleChar(ch);
		// Put character into output
		this._outRange.put(ch);
	}


	_handleChar(ch: string): void {
		if( ch.length !== 1 ) {
			throw Error('Single character expected!');
		}
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

	_injectExtras(): void {
		var moduleName = this._classNode.__getAttr__("moduleName").str;
		var encodedOpts = Base64.encode(renderDataNode2(DataRenderType.JSON, this._classNode, this._interp));

		this._outRange.put(" data-fir-module=\"");
		this._outRange.put(moduleName);
		this._outRange.put("\" data-fir-opts=\"");
		this._outRange.put(encodedOpts);
		this._outRange.put("\"");
	}
}
