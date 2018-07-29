define('ivy/utils', [
	'exports',
	'ivy/Consts',
	'ivy/ExecutionFrame',
	'ivy/CodeObject',
	'ivy/CallableObject',
	'ivy/DataNodeRange',
	'ivy/ClassNode'
	
], function(
	exports,
	Consts,
	ExecutionFrame,
	CodeObject,
	CallableObject,
	DataNodeRange,
	ClassNode
) {
var
DataNodeType = Consts.DataNodeType,
iu = {
	back: function(arr) {
		if( arr.length === 0 ) {
			throw new Error('Cannot get back item, because array is empty!');
		}
		return arr[arr.length-1];
	},
	getDataNodeType: function(con) {
		if( con === undefined ) {
			return DataNodeType.Undef;
		} else if( con === null) {
			return DataNodeType.Null;
		} else if( con === true || con === false ) {
			return DataNodeType.Boolean;
		} else if( typeof(con) === 'string' ) {
			return DataNodeType.String;
		} else if( typeof(con) === 'number' ) {
			if( (''+con).indexOf('.') === -1 ) {
				return DataNodeType.Integer;
			} else {
				return DataNodeType.Floating;
			}
		} else if( con instanceof Array ) {
			return DataNodeType.Array;
		} else if( con instanceof CodeObject ) {
			return DataNodeType.CodeObject;
		} else if( con instanceof Date ) {
			return DataNodeType.DateTime;
		} else if( con instanceof CallableObject ) {
			return DataNodeType.Callable;
		} else if( con instanceof ExecutionFrame ) {
			return DataNodeType.ExecutionFrame;
		} else if( con instanceof DataNodeRange ) {
			return DataNodeType.DataNodeRange;
		} else if( con instanceof ClassNode ) {
			return DataNodeType.ClassNode;
		} else if( con instanceof Object ) {
			return DataNodeType.AssocArray;
		} else {
			throw new Error('Unrecognized node type!');
		}
	},
	deeperCopy: function(val) {
		var vType = this.getDataNodeType(val);
		switch( vType ) {
			case DataNodeType.Undef:
			case DataNodeType.Null:
			case DataNodeType.Boolean:
			case DataNodeType.Integer:
			case DataNodeType.Floating:
			case DataNodeType.String:
				// All of these are value types so just return plain copy
				return val;
			case DataNodeType.DateTime:
				// Copy date object
				return new Date(val.getTime());
			case DataNodeType.AssocArray: {
				var newObj = {};
				for( var key in val ) {
					if( val.hasOwnProperty(key) ) {
						newObj[key] = this.deeperCopy(val[key]);
					}
				}
				return newObj;
			}
			case DataNodeType.Array: {
				var newArr = [];
				newArr.length = val.length; // Preallocate
				for( var i = 0; i < val.length; ++i ) {
					newArr[i] = val[i];
				}
				return newArr;
			}
			case DataNodeType.CodeObject:
				// CodeObject's are constants so don't do copy
				return val;
			default:
				throw new Error('Getting of deeper copy for this type is not implemented for now');
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