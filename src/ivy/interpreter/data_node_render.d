module ivy.interpreter.data_node_render;

import ivy.interpreter.data_node: DataNodeType;

/// Варианты типов отрисовки узла данных в буфер:
/// Text - для вывода пользователю в виде текста (не включает отображение значений внутренних типов данных)
/// TextDebug - для вывода данных в виде текста в отладочном режиме (выводятся некоторые данные для узлов внутренних типов)
/// JSON - вывод узлов, которые соответствуют типам в JSON в формате собственно JSON (остальные типы узлов выводим как null)
/// JSONFull - выводим всё максимально в JSON, сериализуя узлы внутренних типов в JSON
enum DataRenderType { Text, TextDebug, JSON, JSONFull };
/// Думаю, нужен ещё флаг isPrettyPrint

private void _writeEscapedString(OutRange)(string str, ref OutRange outRange)
{
	import std.range: put;
	foreach( char symb; str )
	{
		switch( symb )
		{
			case '\"': outRange.put("\\\""); break;
			case '\\': outRange.put("\\\\"); break;
			case '/': outRange.put("\\/"); break;
			case '\b': outRange.put("\\b"); break;
			case '\f': outRange.put("\\f"); break;
			case '\n': outRange.put("\\n"); break;
			case '\r': outRange.put("\\r"); break;
			case '\t': outRange.put("\\t"); break;
			default:	outRange.put(symb);
		}
	}
}

void renderDataNode(DataRenderType renderType, TDataNode, OutRange)(
	ref TDataNode node, ref OutRange outRange, size_t maxRecursion = size_t.max)
{
	import std.range: put;
	import std.conv: to;

	assert( maxRecursion, "Recursion is too deep!" );

	final switch(node.type) with(DataNodeType)
	{
		case Undef:
			static if( renderType == DataRenderType.Text ) {
				outRange.put("");
			} else static if( renderType == DataRenderType.TextDebug ) {
				outRange.put("undef");
			} else {
				outRange.put("null");
			}
			break;
		case Null:
			static if( renderType == DataRenderType.Text ) {
				outRange.put("");
			} else {
				outRange.put("null");
			}
			break;
		case Boolean:
			outRange.put(node.boolean ? "true" : "false");
			break;
		case Integer:
			outRange.put(node.integer.to!string);
			break;
		case Floating:
			outRange.put(node.floating.to!string);
			break;
		case String:
			static if( renderType == DataRenderType.Text ) {
				outRange.put(node.str);
			}
			else
			{
				outRange.put("\"");
				_writeEscapedString(node.str, outRange);
				outRange.put("\"");
			}
			break;
		case DateTime:
			static if( renderType == DataRenderType.Text ) {
				outRange.put(node.dateTime.toISOExtString());
			}
			else
			{
				outRange.put("\"");
				_writeEscapedString(node.dateTime.toISOExtString(), outRange);
				outRange.put("\"");
			}
			break;
		case Array:
			static if( renderType == DataRenderType.Text ) {
				foreach( i, ref el; node.array ) {
					renderDataNode!(renderType)(el, outRange, maxRecursion - 1);
				}
			} else {
				outRange.put("[");
				foreach( i, ref el; node.array )
				{
					if( i != 0 )
						outRange.put(", ");

					renderDataNode!(renderType)(el, outRange, maxRecursion - 1);
				}
				outRange.put("]");
			}
			break;
		case AssocArray:
			outRange.put("{");
			size_t i = 0;
			foreach( ref key, ref val; node.assocArray )
			{
				if( i != 0 )
					outRange.put(", ");

				outRange.put("\"");
				_writeEscapedString(key, outRange);
				outRange.put("\"");
				outRange.put(": ");

				renderDataNode!(renderType)(val, outRange, maxRecursion - 1);
				++i;
			}
			outRange.put("}");
			break;
		case ClassNode:
			import std.conv: text;
			if( node.classNode )
			{
				TDataNode serialized = node.classNode.__serialize__();
				if( serialized.isUndef )
				{
					static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
						outRange.put("\"<class node>\"");
					} else {
						outRange.put("<class node>");
					}
				} else {
					renderDataNode!(renderType)(serialized, outRange, maxRecursion - 1);
				}
			}
			else
			{
				static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
					outRange.put("\"<class node (null)>\"");
				} else {
					outRange.put("<class node (null)>");
				}
			}
			break;
		case CodeObject:
			static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
				outRange.put("\"");
			}

			import std.conv: text;
			if( node.codeObject ) {
				outRange.put("<code object, size: " ~ node.codeObject._instrs.length.text ~ ">");
			} else {
				outRange.put("<code object (null)>");
			}

			static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
				outRange.put("\"");
			}
			break;
		case Callable:
			static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
				outRange.put("\"");
			}
			if( node.callable ) {
				outRange.put("<callable object, " ~ node.callable._kind.to!string ~ ", " ~ node.callable._name ~ ">");
			} else {
				outRange.put("<callable object (null)>");
			}
			static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
				outRange.put("\"");
			}
			break;
		case ExecutionFrame:
			static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
				outRange.put("\"");
			}
			outRange.put( "<execution frame>" );
			static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
				outRange.put("\"");
			}
			break;
		case DataNodeRange:
			static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
				outRange.put("\"");
			}
			outRange.put( "<data node range>" );
			static if( renderType == DataRenderType.JSON || renderType == DataRenderType.JSONFull ) {
				outRange.put("\"");
			}
			break;
	}
}