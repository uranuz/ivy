define('ivy/types/data/utils', [
	'exports',
	'ivy/types/data/consts',
	'ivy/types/data/data'
], function(
	dutil,
	DataConsts,
	idat
) {
var IvyDataType = DataConsts.IvyDataType;

Object.assign(dutil, {
	deeperCopy: function(val) {
		switch( idat.type(val) ) {
			case IvyDataType.Undef:
			case IvyDataType.Null:
			case IvyDataType.Boolean:
			case IvyDataType.Integer:
			case IvyDataType.Floating:
			case IvyDataType.String:
				// All of these are value types so just return plain copy
				return val;
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
			case IvyDataType.CodeObject:
			case IvyDataType.Callable:
				// CodeObject's and Callable's are constants so don't do copy
				return val;
			default:
				throw new Error('Getting of deeper copy for this type is not implemented for now');
		}
	}
});
});