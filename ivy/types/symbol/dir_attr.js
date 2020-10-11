define('ivy/types/symbol/dir_attr', [], function() {
return FirClass(
	function DirAttr(name, typeName) {
		var inst = firPODCtor(this, arguments);
		if( inst ) return inst;

		this.name = name;
		this.typeName = typeName;
	}
);
});