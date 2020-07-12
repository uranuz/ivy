define('ivy/utils', [
	'exports',
	'ivy/Consts',
	'ivy/ExecutionFrame',
	'ivy/CodeObject',
	'ivy/CallableObject',
	'ivy/DataNodeRange',
	'ivy/ClassNode',
	'ivy/AsyncResult'
], function(
	exports,
	Consts,
	ExecutionFrame,
	CodeObject,
	CallableObject,
	DataNodeRange,
	ClassNode,
	AsyncResult
) {
var
IvyDataType = Consts.IvyDataType,
iu = {
	back: function(arr) {
		if( arr.length === 0 ) {
			throw new Error('Cannot get back item, because array is empty!');
		}
		return arr[arr.length-1];
	},
	getDataNodeType: function(con) {
		if( con === undefined ) {
			return IvyDataType.Undef;
		} else if( con === null) {
			return IvyDataType.Null;
		} else if( con === true || con === false || con instanceof Boolean ) {
			return IvyDataType.Boolean;
		} else if( typeof(con) === 'string' || con instanceof String ) {
			return IvyDataType.String;
		} else if( typeof(con) === 'number' || con instanceof Number ) {
			return Number.isInteger(con)? IvyDataType.Integer: IvyDataType.Floating;
		} else if( con instanceof Array ) {
			return IvyDataType.Array;
		} else if( con instanceof CodeObject ) {
			return IvyDataType.CodeObject;
		} else if( con instanceof AsyncResult ) {
			return IvyDataType.AsyncResult;
		} else if( con instanceof Date ) {
			return IvyDataType.DateTime;
		} else if( con instanceof CallableObject ) {
			return IvyDataType.Callable;
		} else if( con instanceof ExecutionFrame ) {
			return IvyDataType.ExecutionFrame;
		} else if( con instanceof DataNodeRange ) {
			return IvyDataType.DataNodeRange;
		} else if( con instanceof ClassNode ) {
			return IvyDataType.ClassNode;
		} else if( con instanceof Object ) {
			return IvyDataType.AssocArray;
		} else {
			throw new Error('Unrecognized node type!');
		}
	},
	deeperCopy: function(val) {
		var vType = this.getDataNodeType(val);
		switch( vType ) {
			case IvyDataType.Undef:
			case IvyDataType.Null:
			case IvyDataType.Boolean:
			case IvyDataType.Integer:
			case IvyDataType.Floating:
			case IvyDataType.String:
				// All of these are value types so just return plain copy
				return val;
			case IvyDataType.DateTime:
				// Copy date object
				return new Date(val.getTime());
			case IvyDataType.AssocArray: {
				var newObj = {};
				for( var key in val ) {
					if( val.hasOwnProperty(key) ) {
						newObj[key] = this.deeperCopy(val[key]);
					}
				}
				return newObj;
			}
			case IvyDataType.Array: {
				var newArr = [];
				newArr.length = val.length; // Preallocate
				for( var i = 0; i < val.length; ++i ) {
					newArr[i] = this.deeperCopy(val[i]);
				}
				return newArr;
			}
			case IvyDataType.CodeObject: case IvyDataType.Callable:
				// CodeObject's and Callable's are constants so don't do copy
				return val;
			default:
				throw new Error('Getting of deeper copy for this type is not implemented for now');
		}
	},
	toString: function(val) {
		var vType = this.getDataNodeType(val);
		switch( vType ) {
			case IvyDataType.Undef:
			case IvyDataType.Null:
				return '';
			case IvyDataType.Boolean:
				return (val? 'true': 'false');
			case IvyDataType.Integer:
			case IvyDataType.Floating:
				return '' + val;
			case IvyDataType.String:
				return val;
			case IvyDataType.DateTime:
				return '' + val;
			case IvyDataType.AssocArray: {
				var result = '{';
				for( var key in val ) {
					if( val.hasOwnProperty(key) ) {
						result += '"' + key + '": ' + this.toString(val[key]);
					}
				}
				result += '}';
				return result;
			}
			case IvyDataType.Array: {
				var result = '';
				for( var i = 0; i < val.length; ++i ) {
					result += this.toString(val[i]);
				}
				return result;
			}
			case IvyDataType.ClassNode: {
				return this.toString(val.serialize());
			}
			default:
				throw new Error('Getting of deeper copy for this type is not implemented for now');
		}
	},
	toStdJSON: function(val) {
		return JSON.stringify(val, iu._replaceIntoJSON);
	},
	_replaceIntoJSON: function(key, val) {
		switch( iu.getDataNodeType(val) ) {
			case IvyDataType.ClassNode:
				return val.serialize();
			default: break;
		}
		return val;
	},
	getEmpty: function(val)
	{
		switch( iu.getDataNodeType(val) )
		{
			case IvyDataType.Undef: case IvyDataType.Null:
				return true;
			case IvyDataType.Integer:
			case IvyDataType.Floating:
			case IvyDataType.DateTime:
			case IvyDataType.Boolean:
				// Considering numbers just non-empty there. Not try to interpret 0 or 0.0 as logical false,
				// because in many cases they could be treated as significant values
				// DateTime and Boolean are not empty too, because we cannot say what value should be treated as empty
				return false;
			case IvyDataType.String:
			case IvyDataType.Array:
				return !val.length;
			case IvyDataType.AssocArray:
				return !Object.keys(val).length;
			case IvyDataType.DataNodeRange:
				return val.empty();
			case IvyDataType.ClassNode:
				return !!val.getLength();
			default:
				break;
		}
		throw new Error('Cannot test value for emptyness');
	},
	reversed: function(arr)
	{
		if( !(arr instanceof Array) ) {
			throw new Error('Expected array');
		}
		var i = arr.length;
		return {
			next: function() {
				return i > 0? {
					done: false,
					value: arr[i-1]
				}: {
					done: true
				}
			}
		}
	}
};
// For now use CommonJS format to resolve cycle dependencies
for( var key in iu ) {
	if( iu.hasOwnProperty(key) ) {
		exports[key] = iu[key];
	}
}
});