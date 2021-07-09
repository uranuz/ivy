module ivy.types.data.conv.ivy_to_std_json;

import std.json: JSONValue;
import ivy.types.data: IvyData, IvyDataType;

import ivy.types.data.iface.class_node: IClassNode;

JSONValue toStdJSON2(Interp...)(IvyData src, Interp interp)
{
	import ivy.types.data.conv.consts: IvySrlField;
	import ivy.types.data.conv.ivy_to_std_json: toStdJSON2;

	final switch( src.type )
	{
		case IvyDataType.Undef: return JSONValue("undef");
		case IvyDataType.Null: return JSONValue(null);
		case IvyDataType.Boolean: return JSONValue(src.boolean);
		case IvyDataType.Integer: return JSONValue(src.integer);
		case IvyDataType.Floating: return JSONValue(src.floating);
		case IvyDataType.String: return JSONValue(src.str);
		case IvyDataType.Array:
		{
			JSONValue[] nodeArray;
			nodeArray.length = src.array.length;
			foreach( size_t i, val; src.array ) {
				nodeArray[i] = val.toStdJSON2;
			}
			return JSONValue(nodeArray);
		}
		case IvyDataType.AssocArray:
		{
			JSONValue[string] nodeAA;
			foreach( string key, val; src.assocArray ) {
				if( val.type != IvyDataType.Undef ) {
					nodeAA[key] = val.toStdJSON2;
				}
			}
			return JSONValue(nodeAA);
		}
		case IvyDataType.ClassNode:
		{
			static if( interp.length == 0 ) {
				return JSONValue([
					IvySrlField.type: src.type
				]);
			} else {
				return interp[0].execClassMethodSync(src.callableNode, "__serialize__").toStdJSON2(interp);
			}
		}
		case IvyDataType.CodeObject:
			return src.codeObject.toStdJSON();
		case IvyDataType.Callable:
		case IvyDataType.ExecutionFrame:
		case IvyDataType.DataNodeRange:
		case IvyDataType.AsyncResult:
		case IvyDataType.ModuleObject: {
			return JSONValue([
				IvySrlField.type: src.type
			]);
		}
	}
	assert(false, "This should never happen");
}