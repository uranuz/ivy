module ivy.interpreter.directive.base;

import ivy.interpreter.directive.iface: IDirectiveInterpreter;
import ivy.types.symbol.directive: DirectiveSymbol;
import ivy.types.symbol.dir_attr: DirAttr;

class DirectiveInterpreter: IDirectiveInterpreter
{
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.types.symbol.iface: ICallableSymbol;

	import std.exception: enforce;

	alias MethodType = void function(Interpreter);

	this(MethodType method, ICallableSymbol symb)
	{
		enforce(method !is null, "Expected directive method");
		enforce(symb !is null, "Expected directive symbol");
		this._method = method;
		this._symbol = symb;
	}

	protected MethodType _method;
	protected ICallableSymbol _symbol;

	override void interpret(Interpreter interp) {
		this._method(interp);
	}

	override ICallableSymbol symbol() @property
	{
		import std.conv: text;
		enforce(this._symbol !is null, "Directive symbol is not set for: " ~ typeid(this).text);
		return this._symbol;
	}

	override ICallableSymbol moduleSymbol() @property
	{
		import ivy.types.symbol.global: globalSymbol;
		return globalSymbol;
	}
}


template makeIvyMethod(alias Method)
{
	import std.traits:
		Parameters,
		ReturnType,
		ParameterIdentifierTuple,
		isIntegral,
		isSomeString,
		isFloatingPoint;
	import std.exception: enforce;
	import std.functional: toDelegate;
	import std.typecons: Tuple;
	import std.conv: to;

	import ivy.interpreter.interpreter: Interpreter;
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.data.iface.class_node: IClassNode;

	alias ParamTypes = Parameters!(Method);
	alias ResultType = ReturnType!(Method);
	alias ParamNames = ParameterIdentifierTuple!(Method);

	void makeIvyMethod(Interpreter interp)
	{
		Tuple!(ParamTypes) argTuple;
		foreach( i, type; ParamTypes )
		{
			alias paramName = ParamNames[i];
			static if( is(type : Interpreter) )
			{
				// В методе может использоваться производный класс HTTP-контекста
				auto typedInterp = cast(type) interp;
				enforce(
					typedInterp !is null,
					"Unable to convert parameter \"" ~ paramName ~ "\" to type \"" ~ type.stringof ~ "\"");
				argTuple[i] = typedInterp;
				continue;
			}
			else
			{
				IvyData ivyParam = interp.getValue(paramName);
				static if( is(type : bool) ) {
					argTuple[i] = ivyParam.boolean;
				} else static if( isIntegral!type )  {
					argTuple[i] = ivyParam.integer.to!type;
				} else static if( isSomeString!type ) {
					argTuple[i] = ivyParam.str.to!type;
				} else static if( isFloatingPoint!type ) {
					argTuple[i] = ivyParam.floating.to!type;
				} else static if( is(type : IClassNode) ) {
					auto typedClassNode = cast(type) ivyParam.classNode;
					enforce(
						typedClassNode !is null,
						"Unable convert parameter \"" ~ paramName ~ "\" to type \"" ~ type.stringof ~ "\"");
					argTuple[i] = typedClassNode;
				} else static if( is(type : IvyData) ) {
					argTuple[i] = ivyParam;
				} else
					static assert(false, "Unable convert parameter \"" ~ paramName ~ "\" to type \"" ~ type.stringof ~ "\"");
			}
		}

		typeof(toDelegate(&Method)) asDel;
		if( interp.hasValue("this") )
		{
			asDel.funcptr = &Method;
			asDel.ptr = cast(void*) interp.getValue("this").classNode;
		} else {
			asDel = toDelegate(&Method);
		}

		static if( is( ResultType == void ) ) {
			asDel(argTuple.expand);
			interp._stack.push(IvyData());
		} else {
			interp._stack.push(IvyData(asDel(argTuple.expand)));
		}
	}
}

IDirectiveInterpreter makeDir(alias Method)(string symbolName, DirAttr[] attrs = null) {
	return new DirectiveInterpreter(&makeIvyMethod!Method, new DirectiveSymbol(symbolName, attrs));
}