define('ivy/types/symbol/dir_body_attrs', [], function() {
return FirClass(
	function DirBodyAttrs(isNoscope, isNoescape) {
		var inst = firPODCtor(this, DirBodyAttrs, arguments);
		if( inst ) return inst;

		this.isNoscope = isNoscope || false;
		this.isNoescape = isNoescape || false;
	}
);
});