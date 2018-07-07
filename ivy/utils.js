define('ivy/utils', [
	'ivy/Consts',
	'ivy/CodeObject',
	'ivy/ExecutionFrame',
	'ivy/ExecutionFrame',
], function(Consts) {
	var DataNodeType = DataNodeType;
return {
	back: function(arr) {
		if( arr.length === 0 ) {
			throw Error('Cannot get back item, becaise array is empty!');
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
		} else if( typeof( typeof(con) === 'string' ) ) {
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
			raise Error('Unrecognized node type!');
		}
	},
	deeperCopy: function() {
		
	}
};
});