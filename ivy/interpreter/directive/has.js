define('ivy/interpreter/directive/has', [
	'ivy/interpreter/directive/utils'
], function(du) {
var IvyDataType = du.IvyDataType;
return FirClass(
	function HasDirInterpreter() {
		this._symbol = new du.DirectiveSymbol(`has`, [
			du.DirAttr("collection", du.IvyAttrType.Any),
			du.DirAttr("key", du.IvyAttrType.Any)
		]);
	}, du.BaseDirectiveInterpreter, {
		interpret: function(interp) {
			var
				collection = interp.getValue("collection"),
				key = interp.getValue("key");
			switch( du.idat.type(collection) )
			{
				case IvyDataType.AssocArray:
					if( du.idat.type(key) !== IvyDataType.String ) {
						interp.rtError('Expected String as attribute name');
					}
					interp._stack.push(collection[key] !== undefined);
					break;
				case IvyDataType.Array:
					interp._stack.push(collection.includes(key));
					break;
				default:
					interp.rtError('Unexpected collection type');
					break;
			}
		}
	});
});