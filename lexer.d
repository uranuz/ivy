module declarative.lexer;

import std.range, std.algorithm, std.conv, std.stdio;

import declarative.lexer_tools, declarative.common;

static immutable whitespaceChars = " \n\t\r";
static immutable delimChars = "()[]{}%*-+/#,:|.<>=!";
static immutable intChars = "0123456789";

static immutable codeBlockBegin = "{%";
static immutable codeBlockEnd = "%}";
static immutable dataBlockBegin = "{*" ;
static immutable dataBlockEnd = "*}";
static immutable commentBlockBegin = "{#";
static immutable commentBlockEnd = "#}";
static immutable evalBlockBegin = "{{";
static immutable evalBlockEnd = "}}";

static immutable lineStatementBegin = "%%";
static immutable lineCommentBegin = "##";

enum LexemeType {
	Unknown = 0, //0
	Add,
	Assign,
	Colon,
	Comma,
	Div,   //5
	Dot,
	Equal,
	GT,
	GTEqual,
	LBrace, //10
	LBracket,
	LParen,
	LT,
	LTEqual,
	Mod,   //15
	Mul,
	NotEqual,
	Pipe,
	Pow,
	RBrace, //20
	RBracket,
	RParen,
	Semicolon,
	Sub, 
	Tilde, //25
	// WhiteSpace,
	Integer,
	Float,
	String,
	Name,
	CodeBlockBegin, //30
	CodeBlockEnd,
	DataBlockBegin,
	DataBlockEnd,
	RawDataBlockBegin,
	RawDataBlockEnd, //35
	CommentBlockBegin,
	CommentBlockEnd,
	Comment,
	// LineStatementBegin,
	// LineStatementEnd,
	// LineCommentBegin,
	// LineCommentEnd,
	// LineComment,
	Data,
	Invalid, //40
	EndOfFile,
	CoreTypesEnd,
	
	ExtensionTypesStart = 100
};


enum LexemeFlag: uint
{
	None = 0,
	Literal = 1 << 0,
	Dynamic = 1 << 1,
	Operator = 1 << 2,
	Paren = 1 << 3,
	Left = 1 << 4,
	Right = 1 << 5,
	Arithmetic = 1 << 6,
	Compare = 1 << 7,
	
}

//Minimal information about type of lexeme
struct LexemeInfo
{
	import std.typecons: BitFlags;

	int typeIndex = 0;
	BitFlags!LexemeFlag flags;
		
	@property const
	{
		bool isLiteral()
		{
			return cast(bool)( flags & LexemeFlag.Literal );
		}
		
		bool isDynamic()
		{
			return cast(bool)( flags & LexemeFlag.Dynamic );
		}
		
		bool isStatic()
		{
			return !( flags & LexemeFlag.Dynamic );
		}
		
		bool isOperator()
		{
			return cast(bool)( flags & LexemeFlag.Operator );
		}
		
		bool isParen()
		{
			return cast(bool)( flags & LexemeFlag.Paren );
		}
		
		bool isLeftParen()
		{
			return cast(bool)( 
				( flags & LexemeFlag.Paren )
				&& ( flags & LexemeFlag.Left ) 
			);
		}
		
		bool isRightParen()
		{
			return cast(bool)( 
				( flags & LexemeFlag.Paren )
				&& ( flags & LexemeFlag.Right ) 
			);
		}
		
		bool isArithmeticOperator()
		{
			return cast(bool)( 
				( flags & LexemeFlag.Operator )
				&& ( flags & LexemeFlag.Arithmetic ) 
			);
		}
		
		bool isCompareOperator()
		{
			return cast(bool)( 
				( flags & LexemeFlag.Operator )
				&& ( flags & LexemeFlag.Compare ) 
			);
		}
		
		bool isValidCoreType()
		{
			return LexemeType.Unknown < typeIndex && typeIndex < LexemeType.Invalid;
		}
		
		bool isExtensionType()
		{
			return typeIndex >= LexemeType.ExtensionTypesStart;
		}
		
		bool isValidType()
		{
			return typeIndex != LexemeType.Unknown && typeIndex != LexemeType.EndOfFile && typeIndex != LexemeType.Invalid;
		}
		
		bool isUnknown()
		{
			return typeIndex == LexemeType.Unknown;
		}
		
		bool isInvalid()
		{
			return typeIndex == LexemeType.Invalid;
		}
		
		bool isEndOfFile()
		{
			return typeIndex == LexemeType.EndOfFile;
		}
	}
}

///Minumal info about found lexeme
struct Lexeme(LocationConfig c)
{
	enum config = c;
	
	size_t index; //Index of UTF code unit that starts lexeme
	size_t length; //Length of lexeme in code units
	LexemeInfo info; //Field containing information about this lexeme
	
	static if( config.withGraphemeIndex )
	{
		size_t graphemeIndex; //Index of grapheme that starts lexeme
		size_t graphemeLength; //Length of lexeme in graphemes
	}
	
	static if( config.withLineIndex )
	{
		size_t lineIndex; //Index of line at which lexeme starts
		size_t lineCount; //Number of lines in lexeme (number of CR LF/ CR / LF exactly)
		
		static if( config.withColumnIndex )
			size_t columnIndex; //Index of code unit in line that starts lexeme
		
		static if( config.withGraphemeColumnIndex )
			size_t graphemeColumnIndex; //Index of grapheme in line that starts lexeme
	}
	

	bool test(int testType) const
	{
		return this.info.typeIndex == testType;
	}

	auto getSlice(SourceRange)(ref SourceRange sourceRange) const
	{
		return sourceRange[index .. index + length];
	}
}


template GetSourceRangeConfig(R)
{
	static if( is( typeof(R.config) == LocationConfig ) )
	{
		enum GetSourceRangeConfig = R.config;
	}
	else
	{
		enum GetSourceRangeConfig = ( () {
			LocationConfig c;
			
			return c;
		} )();
	}
}

template createLexemeAt(SourceRange)
{
	alias config = GetSourceRangeConfig!SourceRange;
	alias LexemeT = Lexeme!(config);

	LexemeT createLexemeAt(ref SourceRange source, LexemeType lexType = LexemeType.Unknown)
	{
		LexemeT lex;
		lex.info = LexemeInfo(lexType);
		lex.index = source.index;
		lex.length = 0;
		
		static if( config.withGraphemeIndex )
		{
			lex.graphemeIndex = source.graphemeIndex;
			lex.graphemeLength = 0;
		}
		
		static if( config.withLineIndex )
		{
			lex.lineIndex = source.lineIndex;
			lex.lineCount = 0;
		
			static if( config.withColumnIndex )
				lex.columnIndex = source.columnIndex;
			
			static if( config.withGraphemeColumnIndex )
				lex.graphemeColumnIndex = source.graphemeColumnIndex;
		}
		
		return lex;
	}
}


auto extractLexeme(SourceRange)(ref SourceRange beginRange, ref const(SourceRange) endRange, ref const(LexemeInfo) lexemeInfo)
{
	enum LocationConfig config = GetSourceRangeConfig!SourceRange;
	
	Lexeme!(config) lex;
	lex.info = lexemeInfo;
	lex.index = beginRange.index;
	lex.length = endRange.index - beginRange.index;
	
	static if( config.withGraphemeIndex )
	{
		lex.graphemeIndex = beginRange.graphemeIndex;
		lex.graphemeLength = endRange.graphemeIndex - beginRange.graphemeIndex;
	}
	
	static if( config.withLineIndex )
	{
		lex.lineIndex = beginRange.lineIndex;
		lex.lineCount = endRange.lineIndex - beginRange.lineIndex;
	
		static if( config.withColumnIndex )
			lex.columnIndex = beginRange.columnIndex;
		
		static if( config.withGraphemeColumnIndex )
			lex.graphemeColumnIndex = beginRange.graphemeColumnIndex;
	}
	
	beginRange = endRange.save; //Move start currentRange to point of end currentRange
	return lex;
}

LexRule.LexemeT parseStaticLexeme(SourceRange, LexRule)(ref SourceRange source, ref const(LexRule) rule) 
{
	import std.utf;
	enum config = SourceRange.config;
	
	if( source.save.startsWith(rule.val) )
	{
		LexRule.LexemeT newLexeme;
		newLexeme.info = rule.lexemeInfo;
		newLexeme.index = source.index;
		newLexeme.length = rule.val.length;		
		
		static if( config.withGraphemeIndex )
		{
			newLexeme.graphemeIndex = source.graphemeIndex;
			newLexeme.graphemeLength = std.utf.count(rule.val);
		}
		
		static if( config.withLineIndex )
		{
			newLexeme.lineIndex = source.lineIndex;
			newLexeme.lineCount = 0;
			
			static if( config.withColumnIndex )
			{
				newLexeme.columnIndex = rule.val.length;
			}
			
			static if( config.withGraphemeColumnIndex )
			{
				newLexeme.graphemeColumnIndex = source.graphemeIndex;
			}
		}
		
		source.popFrontN(rule.val.length);
		
		return newLexeme;
	}
	
	return createLexemeAt(source);
}


struct LexicalRule(R)
	if( isForwardRange!R )
{
	import std.traits: Unqual;
	
	alias SourceRange = R;
	enum config = GetSourceRangeConfig!R;
	alias Char = Unqual!( ElementEncodingType!R );
	alias String = immutable(Char)[];
	alias LexemeT = Lexeme!(config);
	alias ParseMethodType = LexemeT function(ref SourceRange source, ref const(LexicalRule!R) rule);
	alias parseStaticMethod = parseStaticLexeme!( SourceRange, LexicalRule!R );
	
	String val;
	ParseMethodType parseMethod;
	LexemeInfo lexemeInfo;

	LexemeT parse(ref SourceRange currentRange) inout
	{
		return parseMethod(currentRange, this);
	}
	
	@property const
	{
		bool isDynamic()
		{
			return lexemeInfo.isDynamic;
		}
		
		bool isStatic()
		{
			return lexemeInfo.isStatic;
		}
	}
}

struct Lexer(S, LocationConfig c = LocationConfig.init)
{
	import std.typecons: BitFlags;	
	
	alias SourceRange = TextForwardRange!(String, c);
	alias LexRule = LexicalRule!(SourceRange);
	alias LexemeT = LexRule.LexemeT;
	alias Char = SourceRange.Char;
	alias String = S;
	enum LocationConfig config = c;
	alias LexTypeIndex = int;
		
	static auto staticRule(Flags...)(String str, LexemeType lexType, Flags extraFlags)
	{
		BitFlags!LexemeFlag newFlags;
		
		foreach(flag; extraFlags)
			newFlags |= flag;
			
		newFlags &= ~LexemeFlag.Dynamic;
		
		return LexRule( str, &parseStaticLexeme!(SourceRange, LexRule), LexemeInfo( lexType, newFlags ) );
	}
	
	static auto dynamicRule(Flags...)(LexRule.ParseMethodType method, LexemeType lexType, Flags extraFlags)
	{
		BitFlags!LexemeFlag newFlags;
		
		foreach(flag; extraFlags)
			newFlags |= flag;
			
		newFlags |= LexemeFlag.Dynamic;
		
		return LexRule( null, method, LexemeInfo( lexType, newFlags ) );
	}

	public:

	
	static LexRule[] inDataRules = [
		// staticRule( codeBlockBegin, LexemeType.CodeBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		// dynamicRule(&parseData, LexemeType.Data)
	];
	
	static LexRule[] inCodeRules = [
		staticRule( codeBlockBegin, LexemeType.CodeBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( codeBlockEnd, LexemeType.CodeBlockEnd, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( dataBlockBegin, LexemeType.DataBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( dataBlockEnd, LexemeType.DataBlockEnd, LexemeFlag.Paren, LexemeFlag.Right ),
		
		staticRule( "+", LexemeType.Add, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "=", LexemeType.Assign, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( ":", LexemeType.Colon, LexemeFlag.Operator ),
		staticRule( ",", LexemeType.Comma, LexemeFlag.Operator ),
		staticRule( "/", LexemeType.Div, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( ".", LexemeType.Dot, LexemeFlag.Operator ),
		staticRule( "==", LexemeType.Equal, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( ">", LexemeType.GT, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( ">=", LexemeType.GTEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "{", LexemeType.LBrace, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( "[", LexemeType.LBracket, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( "(", LexemeType.LParen, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( "<", LexemeType.LT, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "<=", LexemeType.LTEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "%", LexemeType.Mod, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "**", LexemeType.Pow, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "*", LexemeType.Mul, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "!=", LexemeType.NotEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		// staticRule( "|", LexemeType.Pipe, LexemeFlag.Operator ),
		staticRule( "}", LexemeType.RBrace, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( "]", LexemeType.RBracket, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( ")", LexemeType.RParen, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( ";", LexemeType.Semicolon, LexemeFlag.Operator),
		staticRule( "-", LexemeType.Sub, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "~", LexemeType.Tilde, LexemeFlag.Operator),
		
		dynamicRule( &parseFloat, LexemeType.Float, LexemeFlag.Literal ),
		dynamicRule( &parseInteger, LexemeType.Integer, LexemeFlag.Literal ),
		dynamicRule( &parseName, LexemeType.Name ),
		dynamicRule( &parseString, LexemeType.String, LexemeFlag.Literal ),
	];

	static LexRule[] allRules;
	static LexRule[LexTypeIndex] allRulesByType;
	
	static LexTypeIndex[LexTypeIndex] matchingParens;
	
	shared static this()
	{
		foreach( rule; allRules )
		{
			allRulesByType[rule.lexemeInfo.typeIndex] = rule;
		}
		
		allRules = inDataRules ~ inCodeRules;
		
		matchingParens = [
			LexemeType.CodeBlockEnd: LexemeType.CodeBlockBegin,
			LexemeType.DataBlockEnd: LexemeType.DataBlockBegin,
			LexemeType.RBrace: LexemeType.LBrace,
			LexemeType.RBracket: LexemeType.LBracket,
			LexemeType.RParen: LexemeType.LParen
		];
	}
	
	enum ContextState { DataContext, CodeContext };
	
	LexemeT[] lexemes;
	const(SourceRange) sourceRange; //Source range. Don't modify it!
	SourceRange currentRange;
	bool inCode = false;
	
	ContextState ctxState;
	LexTypeIndex[] balancingStack;
	private LexemeT _front;
	
	@disable this(this);	
	
	this( String src ) 
	{
		sourceRange = SourceRange(src);
		currentRange = sourceRange.save;

		// if( !this.empty )
			// popFront();
	}
	
	void parse()
	{
		while( !currentRange.empty )
		{
			popFront();
		}
	}

/+
	static LexemeT parseFront(ref SourceRange source, ref int[] balancingStack, bool inCode)
	{
		LexemeT lex;
		if( inCode )
			skipWhiteSpaces(source);
		
		auto rules = inCode ? inCodeRules : inDataRules;
		foreach( ref rule; rules )
		{
			lex = rule.parse(source);
			if( lex.info.typeIndex != LexemeType.Unknown )
				break;
		}
		
		if( lex.info.typeIndex == LexemeType.Unknown )
			assert(false, "Expected token!");
		if( lex.info.isRightParen )
		{
			if( balancingStack.length > 0 )
			{
				if( balancingStack.back == matchingParens[lex.info.typeIndex] )
				{
					balancingStack.popBack();
				}
				else
					assert( false, "Expected matching parenthesis!!!" );
			}
		}
		return lex;
	}
+/

	static LexemeT parseFront(ref SourceRange source, ref int[] balancingStack, bool inCode)
	{
		LexemeT lex;
		// if( inCode )
			skipWhiteSpaces(source);
			
		if( source.empty )
			return createLexemeAt(source, LexemeType.EndOfFile);
		
		auto rules = allRules;

		foreach( rule; rules )
		{
			lex = rule.parse(source);
			if( lex.info.isValidType )
			{
				break;
			}
		}


		if( !lex.info.isValidType )
			assert(false, "Expected valid token!");
			
		if( lex.info.isRightParen )
		{
			if( balancingStack.length > 0 )
			{
				int backParen = balancingStack.back;
				
				if( backParen == matchingParens[lex.info.typeIndex] )
				{
					balancingStack.popBack();
				}
				else
					assert( false, "Expected matching parenthesis!!!" );
			}
		}

		return lex;
	}

	void popFront()
	{
		_front = parseFront(currentRange, balancingStack, inCode);
		
		lexemes ~= _front;

		if( inCode && ( front.info.typeIndex == LexemeType.CodeBlockEnd /+|| front.info.typeIndex == LexemeType.VariableEnd+/ ) )
			inCode = false;
		else if( !inCode && ( front.info.typeIndex == LexemeType.CodeBlockBegin /+|| front.typeIndex == LexemeType.VariableBegin+/ ) )
			inCode = true;
		
		if( front.info.isLeftParen )
			balancingStack ~= front.info.typeIndex;

	}
	
	bool empty()
	{	return currentRange.empty || _front.info.isEndOfFile;
	}
	
	LexemeT front() @property
	{
		return _front;
	}
	
	auto frontValue() @property
	{
		return front.getSlice(sourceRange);
	}
	
	void fail_expectation(LexemeType lexType, size_t line, String value = String.init )
	{
		String whatExpected = `lexeme of typeIndex "` ~ lexType.to!String ~ `"`;
		if( !value.empty )
			whatExpected ~= ` with value "` ~ value ~ `"`;

		assert( !this.empty, `Expected ` ~ whatExpected ~ ` but end of input found!!!` );
		
		String whatGot = `lexeme of typeIndex "` ~ front.info.typeIndex.to!String ~ `"`;
		if( !front.getSlice(sourceRange).empty )
			whatGot ~= ` with value "` ~ front.getSlice(sourceRange).array ~ `"`;
		
		assert( false,  `[` ~ line.to!String ~ `] Expected ` ~ whatExpected ~ ` but got ` ~ whatGot ~ `!!!` );
	}
	
	LexemeT expect(LexemeType lexType, String value, size_t line = __LINE__)
	{
		import std.algorithm: equal;
		
		if( this.empty )
			fail_expectation(lexType, line, value);
		
		LexemeT lex = this.front;
		if( lex.info.typeIndex == lexType && lex.getSlice(sourceRange).equal(value) )
		{
			this.popFront();
			return lex;
		}
		
		fail_expectation(lexType, line, value);
		assert(0);
	}

	LexemeT expect(LexemeType lexType, size_t line = __LINE__)
	{
		if( this.empty )
			fail_expectation(lexType, line);
		
		LexemeT lex = this.front;
		if( lex.info.typeIndex == lexType )
		{
			this.popFront();
			return lex;
		}
		
		fail_expectation(lexType, line);
		assert(0);
	}
		
	bool skipIf(LexemeType lexType)
	{
		if( this.empty )
			return false;
		
		auto lex = this.front;
		if( lex.info.typeIndex == lexType )
		{
			this.popFront();
			return true;
		}
		return false;
	}
	
	bool skipIf(LexemeType typeIndex, String value)
	{
		import std.algorithm: equal;
		
		if( this.empty )
			return false;
		
		auto lex = this.front;
		if( lex.info.typeIndex == typeIndex && lex.getSlice(sourceRange).equal(value) )
		{
			this.popFront();
			return true;
		}
		return false;
	}
	
	LexemeT next() @property
	{
		//Creates copy of currentRange in order to not modify original one
		SourceRange parsedRange = currentRange.save; 
		if( this.empty )
			assert( false, "Cannot peek lexeme, because currentRange is empty!!!" );
		
		return parseFront(parsedRange, balancingStack, inCode);
	}
	
	static void skipWhiteSpaces(ref SourceRange source)
	{
		Char ch;
		while( !source.empty )
		{
			ch = source.front();
			if( !whitespaceChars.canFind(ch) )
				return;
			source.popFront();
		}
	}

	static immutable string[] stringQuotes = [
		`"`, `'`
	];

	import std.traits;

	static LexemeT parseString(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseString");
		
		String quoteLex;
		SourceRange parsedRange = source.save;
		
		foreach( ref quote; stringQuotes )
		{
			if( parsedRange.match(quote) )
			{
				quoteLex = quote;
				break;
			}
		}
		
		if( quoteLex.empty )
			return createLexemeAt(source, LexemeType.EndOfFile);
		
		while( !parsedRange.empty )
		{
			if( parsedRange.match(quoteLex) )
				return extractLexeme(source, parsedRange, rule.lexemeInfo);
			else
				parsedRange.popFront();
		}
		
		assert(0, `Expected <` ~ quoteLex.to!string ~ `> but end of input found!!!` );
	}

	static LexemeT parseInteger(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseInteger");
		
		SourceRange parsedRange = source.save;
		Char ch;
		
		if( parsedRange.empty )
			return createLexemeAt(source, LexemeType.EndOfFile);
		
		ch = parsedRange.front;
		if( !('0' <= ch && ch <= '9') )
			return createLexemeAt(source);
		parsedRange.popFront();
		
		while( !parsedRange.empty )
		{
			ch = parsedRange.front;
			if( !('0' <= ch && ch <= '9') )
				break;
			parsedRange.popFront();
		}
		
		return extractLexeme(source, parsedRange, rule.lexemeInfo);
	}

	static LexemeT parseFloat(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseFloat");
		
		SourceRange parsedRange = source.save;
		Char ch;
		
		if( parsedRange.empty )
			return createLexemeAt(source, LexemeType.EndOfFile);
		
		ch = parsedRange.front;
		if( !('0' <= ch && ch <= '9') )
			return createLexemeAt(source);
		parsedRange.popFront();
		
		while( !parsedRange.empty )
		{
			ch = parsedRange.front;
			if( !('0' <= ch && ch <= '9') )
				break;
			parsedRange.popFront();
		}
		
		if( parsedRange.empty )
			return createLexemeAt(source, LexemeType.EndOfFile);
		
		ch = parsedRange.front;
		if( ch != '.' )
			return createLexemeAt(source);
		parsedRange.popFront();
		
		if( parsedRange.empty )
			assert( false, `Expected decimal part of float!!!` );
		
		ch = parsedRange.front;
		if( !('0' <= ch && ch <= '9') )
			assert( false, `Expected decimal part of float!!!` );
		parsedRange.popFront();
		
		while( !parsedRange.empty )
		{
			ch = parsedRange.front;
			if( !('0' <= ch && ch <= '9') )
				break;
			parsedRange.popFront();
		}
		
		return extractLexeme(source, parsedRange, rule.lexemeInfo);
	}
	
	static immutable notTextLexemes = [
		codeBlockBegin,
		// BLOCK_END,
		// // VARIABLE_START,
		// VARIABLE_END,
		// // COMMENT_START,
		// COMMENT_END
	];

	static LexemeT parseData(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseData");
		
		SourceRange parsedRange = source.save;
		
		import std.algorithm;
		
		LexemeT lex;
		
		while( !parsedRange.empty )
		{
			foreach( ref notText; notTextLexemes )
			{
				if( parsedRange.save.startsWith(notText) )
					return extractLexeme(source, parsedRange, rule.lexemeInfo);
			}
			parsedRange.popFront();
		}
		
		return extractLexeme(source, parsedRange, rule.lexemeInfo);
	}
	
	static LexemeT parseName(ref SourceRange source, ref const(LexRule) rule)
	{
		//writeln("lexer.parseName");
		
		SourceRange parsedRange = source.save;
		
		Char ch;
		dchar dch;
		ubyte len;
		
		if( parsedRange.empty )
			return createLexemeAt(source, LexemeType.EndOfFile);
		
		ch = parsedRange.front();
		
		if( !isStartCodeUnit(ch) )
			return createLexemeAt(source);
		
		dch = parsedRange.decodeFront();
		len = parsedRange.frontUnitLength();
		if( !isNameChar(dch) || isNumberChar(dch) )
			return createLexemeAt(source);
		
		parsedRange.popFrontN(len);
		
		while( !parsedRange.empty )
		{
			len = parsedRange.frontUnitLength();
			dch = parsedRange.decodeFront();
			
			if( !isNameChar(dch) )
				break;
			
			parsedRange.popFrontN(len);
		}
		
		return extractLexeme(source, parsedRange, rule.lexemeInfo);
	}
	
}

/+
import std.stdio;

void main()
{
	string str = `{%%}+- 0.1  "Vasya" ***  -100500.05 hello null array.length ` ;
	
	import std.uni: isAlpha;
	alias MyLexer = Lexer!(string, LocationConfig.init);
	
	MyLexer lexer = MyLexer(str);
		
 	try {
		lexer.parse();
	} catch (Throwable e){}

	
	foreach( lex; lexer.lexemes )
	{
		writeln( "lex.index: ", lex.index, " ", "lex.length: ", lex.length, ", lex.type: ", cast(LexemeType) lex.info.typeIndex, ", content: ", lex.getSlice(lexer.sourceRange).toString() );
	}

}
+/