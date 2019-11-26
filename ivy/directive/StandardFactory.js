define('ivy/directive/StandardFactory', [
	'ivy/directive/Factory',
	'ivy/directive/DateTimeGet',
	'ivy/directive/Empty',
	'ivy/directive/BoolCtor',
	'ivy/directive/FloatCtor',
	'ivy/directive/Has',
	'ivy/directive/IntCtor',
	'ivy/directive/Len',
	'ivy/directive/Range',
	'ivy/directive/Scope',
	'ivy/directive/StrCtor',
	'ivy/directive/TypeStr'
], function(
	DirectiveFactory,
	DateTimeGet,
	Empty,
	BoolCtor,
	FloatCtor,
	Has,
	IntCtor,
	Len,
	Range,
	Scope,
	StrCtor,
	ToJSONBase64,
	TypeStr
) {
	return (function StandardFactory() {
		var factory = new DirectiveFactory();
		factory.add(new DateTimeGet);
		factory.add(new Empty);
		factory.add(new BoolCtor);
		factory.add(new FloatCtor);
		factory.add(new Has);
		factory.add(new IntCtor);
		factory.add(new Len);
		factory.add(new Range);
		factory.add(new Scope);
		factory.add(new StrCtor);
		factory.add(new TypeStr);
		return factory;
	});
});