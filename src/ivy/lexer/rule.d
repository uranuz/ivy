module ivy.lexer.rule;

import std.range: isForwardRange;

struct LexicalRule(R)
	if( isForwardRange!R )
{
	import ivy.lexer.lexeme: Lexeme;
	import ivy.lexer.lexeme_info: LexemeInfo;

	import std.traits: Unqual;
	import std.range: ElementEncodingType;

	alias SourceRange = R;
	alias Char = Unqual!( ElementEncodingType!R );
	alias String = immutable(Char)[];

	// Methods of this type should return true if starting part of range matches this rule
	// and consume this part. Otherwise it should return false
	alias ParseMethodType = bool function(ref SourceRange source, ref const(LexicalRule!R) rule);

	String val;
	ParseMethodType parseMethod;
	LexemeInfo lexemeInfo;

	bool apply(ref SourceRange currentRange) inout {
		return parseMethod(currentRange, this);
	}

	@property const
	{
		bool isDynamic() {
			return lexemeInfo.isDynamic;
		}

		bool isStatic() {
			return lexemeInfo.isStatic;
		}
	}
}