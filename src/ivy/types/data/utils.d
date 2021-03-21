module ivy.types.data.utils;

import ivy.types.data: IvyData, IvyDataType;

IvyData deeperCopy(IvyData)(auto ref IvyData node)
{
	import ivy.types.data.exception: DataNodeException;

	final switch( node.type )
	{
		case IvyDataType.Undef:
		case IvyDataType.Null:
		case IvyDataType.Boolean:
		case IvyDataType.Integer:
		case IvyDataType.Floating:
			// These types of nodes are value types, so make plain copy

		case IvyDataType.String:
			// String is not a value type, but they are immutable in D implementation,
			// so we only get new slice of existing string

		case IvyDataType.CodeObject:
		case IvyDataType.Callable:
			// We don't do deeper copy of code object or callable, because it should be used as constant
			return node;
		case IvyDataType.Array:
		{
			IvyData[] newArray;
			newArray.length = node.array.length; // Preallocating
			foreach( i, ref el; node.array ) {
				newArray[i] = deeperCopy(el);
			}
			return IvyData(newArray);
		}
		case IvyDataType.AssocArray:
		{
			IvyData[string] newAA;
			foreach( ref key, ref val; node.assocArray ) {
				newAA[key] = deeperCopy(val);
			}
			return IvyData(newAA);
		}
		case IvyDataType.ClassNode:
		case IvyDataType.ExecutionFrame:
		case IvyDataType.DataNodeRange:
		case IvyDataType.AsyncResult:
		case IvyDataType.ModuleObject:
			// These types of nodes shouldn't appear in module constants table so leave these not implemented for now
			break;
	}
	import std.conv: text;
	throw new DataNodeException(`Getting of deeper copy for "` ~ node.type.text ~ `" is not implemented for now`);
}

IvyData errorToIvyData(Throwable error)
{
	import std.conv: to;
	import std.exception: enforce;
	import trifle.backtrace: getBacktrace;

	IvyData res;
	res[`errorMsg`] = (cast(string) error.message());
	res[`traceInfo`] = getBacktrace(error);
	res[`errorFile`] = error.file;
	res[`errorLine`] = error.line;
	return res;
}