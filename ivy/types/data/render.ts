import { Interpreter } from 'ivy/interpreter/interpreter';
import {IvyDataType} from 'ivy/types/data/consts';

import {FirControlRender} from 'ivy/types/data/control_render';
import { IvyData } from 'ivy/types/data/data';
import { IClassNode } from 'ivy/types/data/iface/class_node';

export enum DataRenderType{
	Text,
	TextDebug,
	HTML,
	JSON,
	JSONFull,
	HTMLDebug
};

export class appender {
	private _data: string;
	constructor() {
		this._data = '';
	}

	put(val: string) {
		this._data += val;
	}

	get data(): string {
		return this._data;
	}
}

type OutRange = appender | FirControlRender;


function _writeStr(renderType: DataRenderType, sink: OutRange, src: string) {
	if( renderType == DataRenderType.Text ) {
		sink.put(src); // There is no escaping for plain text render
	} else {
		var isQuoted = ![DataRenderType.Text, DataRenderType.HTML].includes(renderType);
		var isHTML = [DataRenderType.HTML, DataRenderType.HTMLDebug].includes(renderType);
		if( isHTML ) {
			writeHTMLStr(sink, src, isQuoted);
		} else {
			writeQuotedStr(sink, src, isQuoted);
		}
	}
}

function writeHTMLStr(sink: OutRange, src: string, isQuoted: boolean) {
	sink.put(src);
}

function writeQuotedStr(sink: OutRange, src: string, isQuoted: boolean) {
	sink.put(src);
}

export function renderDataNode(renderType: DataRenderType, sink: OutRange, node: IvyData, interp: Interpreter) {
	switch(node.type) {
		case IvyDataType.Undef:
			if( [DataRenderType.Text, DataRenderType.HTML].includes(renderType) ) {
				sink.put("");
			} else if( [DataRenderType.JSON, DataRenderType.JSONFull].includes(renderType) ) {
				sink.put("\"undef\""); // Serialize undef as string in JSON
			} else {
				sink.put("undef");
			}
			break;
		case IvyDataType.Null:
			if( [DataRenderType.Text, DataRenderType.HTML].includes(renderType) ) {
				sink.put("");
			} else {
				sink.put("null");
			}
			break;
		case IvyDataType.Boolean:
			sink.put(node? "true" : "false");
			break;
		case IvyDataType.Integer:
			sink.put(String(node));
			break;
		case IvyDataType.Floating:
			sink.put(String(node));
			break;
		case IvyDataType.String:
			_writeStr(renderType, sink, node);
			break;
		case IvyDataType.Array: {
			var asArray = ![DataRenderType.Text, DataRenderType.HTML].includes(renderType);
			if( asArray ) sink.put("[");
			node.forEach((el: IvyData, i: number) => {
				if( asArray && i != 0 ) {
					sink.put(", ");
				}

				renderDataNode(renderType, sink, el, interp);
			});
			if( asArray ) sink.put("]");
			break;
		}
		case IvyDataType.AssocArray: {
			sink.put("{");
			Object.entries(node).forEach((pair: any, i: number) => {
				if( i != 0 ) {
					sink.put(", ");
				}

				_writeStr(renderType, sink, pair[0]);
				sink.put(": ");

				renderDataNode(renderType, sink, pair[1], interp);
			});
			sink.put("}");
			break;
		}
		case IvyDataType.ClassNode: {
			if( interp != null ) {
				_renderClassNode(renderType, sink, node, interp);
			} else {
				_writeStr(renderType, sink, "[[class node]]");
			}
			break;
		}
		case IvyDataType.CodeObject:
			_writeStr(renderType, sink, "[[code object: " + node.symbol.name + "]]");
			break;
		case IvyDataType.Callable:
			_writeStr(renderType, sink, "[[callable object: " + node.symbol.name + "]]");
			break;
		case IvyDataType.ExecutionFrame:
			_writeStr(renderType, sink, "[[execution frame]]");
			break;
		case IvyDataType.IvyDataRange:
			_writeStr(renderType, sink, "[[data node range]]");
			break;
		case IvyDataType.AsyncResult:
			_writeStr(renderType, sink, "[[async result]]");
			break;
		case IvyDataType.ModuleObject:
			_writeStr(renderType, sink, "[[module object]]");
			break;
	}
}

export function renderDataNode2(
		renderType: DataRenderType,
		node: IvyData,
		interp?: Interpreter
	) {
	let sink = new appender();
	this.renderDataNode(renderType, sink, node, interp);
	return sink.data;
}

function _renderClassNode(
		renderType: DataRenderType,
		sink: OutRange,
		classNode: IClassNode,
		interp: Interpreter
	) {
	let useRender = [
		DataRenderType.Text,
		DataRenderType.TextDebug,
		DataRenderType.HTML,
		DataRenderType.HTMLDebug,
	].includes(renderType);
	let firRender;

	if( useRender ) {
		if( interp instanceof FirControlRender ) {
			firRender = new FirControlRender((<FirControlRender>sink)._outRange, classNode, interp);
		} else {
			firRender = new FirControlRender(sink, classNode, interp);
		}
		renderDataNode(renderType, firRender, interp.execClassMethodSync(classNode, "render"), interp);
	} else {
		renderDataNode(renderType, <appender>sink, interp.execClassMethodSync(classNode, "__serialize__"), interp);
	}
}