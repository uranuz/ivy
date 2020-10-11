module ivy.types.data.conv.ivy_to_std_json;

import std.json: JSONValue;
import ivy.types.data: IvyData, IvyDataType;

JSONValue toStdJSON(ref IvyData src)
{
	import ivy.types.data.conv.ivy_to_std_json: toStdJSON2;

	import std.exception: enforce;

	final switch( src.type )
	{
		case IvyDataType.Undef:
		case IvyDataType.Null:
			return JSONValue(null);
		case IvyDataType.Boolean:
			return JSONValue(src.boolean);
		case IvyDataType.Integer:
			return JSONValue(src.integer);
		case IvyDataType.Floating:
			return JSONValue(src.floating);
		case IvyDataType.String:
			return JSONValue(src.str);
		case IvyDataType.Array:
		{
			JSONValue[] nodeArray;
			nodeArray.length = src.array.length;
			foreach( size_t i, val; src.array ) {
				nodeArray[i] = val.toStdJSON;
			}
			return JSONValue(nodeArray);
		}
		case IvyDataType.AssocArray:
		{
			JSONValue[string] nodeAA;
			foreach( string key, val; src.assocArray ) {
				if( val.type != IvyDataType.Undef ) {
					nodeAA[key] = val.toStdJSON;
				}
			}
			return JSONValue(nodeAA);
		}
		case IvyDataType.ClassNode:
			return src.classNode.__serialize__().toStdJSON2();
		case IvyDataType.CodeObject:
		case IvyDataType.Callable:
		case IvyDataType.ExecutionFrame:
		case IvyDataType.DataNodeRange:
		case IvyDataType.ModuleObject:
		case IvyDataType.AsyncResult:
			enforce(false, `Cannot serialize type`);
	}
	assert(false, `This should never happen`);
}

JSONValue toStdJSON2(IvyData con)
{
	import ivy.types.data.conv.consts: IvySrlField;

	final switch( con.type )
	{
		case IvyDataType.Undef: return JSONValue("undef");
		case IvyDataType.Null: return JSONValue();
		case IvyDataType.Boolean: return JSONValue(con.boolean);
		case IvyDataType.Integer: return JSONValue(con.integer);
		case IvyDataType.Floating: return JSONValue(con.floating);
		case IvyDataType.String: return JSONValue(con.str);
		case IvyDataType.Array: {
			JSONValue[] arr;
			foreach( IvyData node; con.array ) {
				arr ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case IvyDataType.AssocArray: {
			JSONValue[string] arr;
			foreach( string key, IvyData node; con.assocArray ) {
				arr[key] ~= toStdJSON(node);
			}
			return JSONValue(arr);
		}
		case IvyDataType.CodeObject: {
			return con.codeObject.toStdJSON();
		}
		case IvyDataType.Callable:
		case IvyDataType.ClassNode:
		case IvyDataType.ExecutionFrame:
		case IvyDataType.DataNodeRange:
		case IvyDataType.AsyncResult:
		case IvyDataType.ModuleObject: {
			return JSONValue([IvySrlField.type: con.type]);
		}
	}
	assert(false);
}
