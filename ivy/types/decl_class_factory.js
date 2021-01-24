define('ivy/types/decl_class_factory', [
	'ivy/types/data/decl_class'
], function(DeclClass) {
return FirClass(
	function DeclClassFactory() {}, {
		makeClass: function(name, dataDict, baseClass) {
			var
				metaClassName = dataDict.__metaClass__,
				metaClass = metaClassName? require(metaClassName): DeclClass;
			if( metaClass )
				return new metaClass(name, dataDict, baseClass);
			throw new Error('Unable to make class, because no metaclass found with name: ' + metaClassName);
		}
	});
});
