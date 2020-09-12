define('ivy/interpreter/directive/standard_factory', [
	'ivy/interpreter/directive/factory',
	'ivy/interpreter/directive/empty',
	'ivy/interpreter/directive/bool_ctor',
	'ivy/interpreter/directive/float_ctor',
	'ivy/interpreter/directive/has',
	'ivy/interpreter/directive/int_ctor',
	'ivy/interpreter/directive/len',
	'ivy/interpreter/directive/range',
	'ivy/interpreter/directive/scope',
	'ivy/interpreter/directive/str_ctor',
	'ivy/interpreter/directive/typestr'
], function(
	DirectiveFactory,
	Empty,
	BoolCtor,
	FloatCtor,
	Has,
	IntCtor,
	Len,
	Range,
	Scope,
	StrCtor,
	TypeStr
) {
	return (function StandardFactory() {
		var factory = new DirectiveFactory();
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