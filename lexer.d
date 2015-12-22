module declarative.lexer;

import std.range, std.algorithm, std.conv, std.stdio;

import declarative.lexer_tools, declarative.common;

static immutable whitespaceChars = " \n\t\r";
static immutable delimChars = "()[]{}%*-+/#,:|.<>=!";
static immutable intChars = "0123456789";

static immutable codeBlockBegin = "{#";
static immutable codeBlockEnd = "#}";
static immutable mixedBlockBegin = "{*" ;
static immutable mixedBlockEnd = "*}";
static immutable commentBlockBegin = "/*";
static immutable commentBlockEnd = "*/";
static immutable rawDataBlockBegin = "{$$";
static immutable rawDataBlockEnd = "$$}";
static immutable exprBlockBegin = "{{";
static immutable exprBlockEnd = "}}";
static immutable subDirectiveSep = "#"


enum LexemeType {
	Unknown = 0,
	Add,
	Assign,
	Colon,
	Comma,
	Div,
	Dot,
	Equal,
	GT,
	GTEqual,
	LBrace,
	LBracket,
	LParen,
	LT,
	LTEqual,
	Mod,
	Mul,
	NotEqual,
	Pipe,
	Pow,
	RBrace,
	RBracket,
	RParen,
	Semicolon,
	Sub, 
	Tilde,
	Hash,
	// WhiteSpace,
	Integer,
	Float,
	String,
	Name,
	ExprBlockBegin,
	ExprBlockEnd,
	CodeBlockBegin,
	CodeBlockEnd,
	MixedBlockBegin,
	MixedBlockEnd,
	RawDataBlockBegin,
	RawDataBlockEnd,
	CommentBlockBegin,
	CommentBlockEnd,
	Comment,
	// LineStatementBegin,
	// LineStatementEnd,
	// LineCommentBegin,
	// LineCommentEnd,
	// LineComment,
	Data,
	RawDataBlock,
	Invalid,
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
	Separator = 1 << 8
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

enum ContextState { CodeContext, MixedContext, RawDataContext };

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

	
	static LexRule[] mixedContextRules = [
		staticRule( codeBlockBegin, LexemeType.CodeBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( mixedBlockBegin, LexemeType.MixedBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( mixedBlockEnd, LexemeType.MixedBlockEnd, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( exprBlockBegin, LexemeType.ExprBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		dynamicRule( &parseData, LexemeType.Data, LexemeFlag.Literal )
	];
	
	static LexRule[] codeContextRules = [
		dynamicRule( &parseRawData, LexemeType.RawDataBlock, LexemeFlag.Literal ),
	
		staticRule( codeBlockBegin, LexemeType.CodeBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( codeBlockEnd, LexemeType.CodeBlockEnd, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( mixedBlockBegin, LexemeType.MixedBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( mixedBlockEnd, LexemeType.MixedBlockEnd, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( exprBlockBegin, LexemeType.ExprBlockBegin, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( exprBlockEnd, LexemeType.ExprBlockEnd, LexemeFlag.Paren, LexemeFlag.Right ),
		
		staticRule( "+", LexemeType.Add, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "==", LexemeType.Equal, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "=", LexemeType.Assign, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( ":", LexemeType.Colon, LexemeFlag.Operator ),
		staticRule( ",", LexemeType.Comma, LexemeFlag.Operator ),
		staticRule( "/", LexemeType.Div, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( ".", LexemeType.Dot, LexemeFlag.Operator ),
		staticRule( ">=", LexemeType.GTEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( ">", LexemeType.GT, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "{", LexemeType.LBrace, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( "[", LexemeType.LBracket, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( "(", LexemeType.LParen, LexemeFlag.Paren, LexemeFlag.Left ),
		staticRule( "<=", LexemeType.LTEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "<", LexemeType.LT, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "%", LexemeType.Mod, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "**", LexemeType.Pow, LexemeFlag.Operator, LexemeFlag.Compare ),
		staticRule( "*", LexemeType.Mul, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "!=", LexemeType.NotEqual, LexemeFlag.Operator, LexemeFlag.Compare ),
		// staticRule( "|", LexemeType.Pipe, LexemeFlag.Operator ),
		staticRule( "}", LexemeType.RBrace, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( "]", LexemeType.RBracket, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( ")", LexemeType.RParen, LexemeFlag.Paren, LexemeFlag.Right ),
		staticRule( ";", LexemeType.Semicolon, LexemeFlag.Separator),
		staticRule( "-", LexemeType.Sub, LexemeFlag.Operator, LexemeFlag.Arithmetic ),
		staticRule( "~", LexemeType.Tilde, LexemeFlag.Operator),
		staticRule( "#", LexemeType.Hash, LexemeFlag.Separator),
		
		dynamicRule( &parseFloat, LexemeType.Float, LexemeFlag.Literal ),
		dynamicRule( &parseInteger, LexemeType.Integer, LexemeFlag.Literal ),
		dynamicRule( &parseName, LexemeType.Name ),
		dynamicRule( &parseString, LexemeType.String, LexemeFlag.Literal )
	];

	static LexRule[] allRules;
	static LexRule[LexTypeIndex] allRulesByType;
	
	static LexTypeIndex[LexTypeIndex] matchingParens;
	
	static this()
	{
		allRules = mixedContextRules ~ codeContextRules;
		
		foreach( rule; allRules )
		{
			allRulesByType[rule.lexemeInfo.typeIndex] = rule;
		}

		matchingParens = [
			LexemeType.CodeBlockEnd: LexemeType.CodeBlockBegin,
			LexemeType.MixedBlockEnd: LexemeType.MixedBlockBegin,
			LexemeType.RawDataBlockEnd: LexemeType.RawDataBlockBegin,
			LexemeType.RBrace: LexemeType.LBrace,
			LexemeType.RBracket: LexemeType.LBracket,
			LexemeType.RParen: LexemeType.LParen
		];		
	}
	
	struct LexerContext
	{
		ContextState[] statesStack;
		LexTypeIndex[] parenStack;
		
		this(this)
		{
			parenStack = parenStack.dup;
		}
		
		ref LexerContext opAssign(ref LexerContext rhs)
		{
			statesStack = rhs.statesStack.dup;
			parenStack = rhs.parenStack.dup;
			return this;
		}
		
		@property ContextState state()
		{
			return statesStack.empty ? ContextState.CodeContext : statesStack.back;	
		}
		
	}

	LexemeT[] lexemes;
	SourceRange sourceRange; //Source range. Don't modify it!
	SourceRange currentRange;
	LexerContext _ctx;
		
	/+private+/ LexemeT _front;
	
	@disable this(this);	
	
	this( String src ) 
	{
		auto newRange = SourceRange(src);
		this( newRange );
	}
	
	this( ref const(SourceRange) srcRange )
	{
		sourceRange = srcRange.save;
		currentRange = sourceRange.save;
	}
	
	void parse()
	{
		while( !currentRange.empty )
		{
			popFront();
		}
	}

	static LexemeT parseFront(ref SourceRange source, ref LexerContext ctx)
	{
		import std.conv: to;
		
		LexemeT lex;
		// if( inCode )
			skipWhiteSpaces(source);
			
		if( source.empty )
		{
			if( !ctx.parenStack.empty )
				assert( 0, 
					"Expected matching parenthesis for " 
					~ (cast(LexemeType) ctx.parenStack.back).to!string  
					~ ", but unexpected end of input found!!!" 
				);
			
			return createLexemeAt(source, LexemeType.EndOfFile);
		}
		
		LexRule[] rules;
		
		if( ctx.state == ContextState.CodeContext )
			rules = codeContextRules;
		else if( ctx.state == ContextState.MixedContext )
			rules = mixedContextRules;
		else
			rules = null;

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

		return lex;
	}

	void popFront()
	{
		import std.array: array;
		import std.conv: to;
		
		_front = parseFront(currentRange, _ctx);
		
		lexemes ~= _front;
		
		auto typeIndex = _front.info.typeIndex;
		
		switch( typeIndex ) with( LexemeType )
		{
			case CodeBlockBegin:
			{
				if( _ctx.state == ContextState.CodeContext )
				{
					_ctx.statesStack ~= ContextState.CodeContext;
				}
				else if( _ctx.state == ContextState.MixedContext )
				{
					_ctx.statesStack ~= ContextState.CodeContext;
				}
			
				break;
			}
			case CodeBlockEnd:
			{
				if( _ctx.state == ContextState.CodeContext )
				{
					assert( !_ctx.parenStack.empty && _ctx.parenStack.back == CodeBlockBegin, "Unexpected: "  ~ (cast(LexemeType) typeIndex).to!string );
					if( !_ctx.statesStack.empty )
						_ctx.statesStack.popBack();
				}
				
				break;
			}
			case MixedBlockBegin:
			{
				if( _ctx.state == ContextState.CodeContext )
				{
					_ctx.statesStack ~= ContextState.MixedContext;
				
				}
				else if( _ctx.state == ContextState.MixedContext )
				{
					_ctx.statesStack ~= ContextState.MixedContext;
				
				}
				break;
			}
			case MixedBlockEnd:
			{
				if( _ctx.state == ContextState.MixedContext )
				{
					assert( !_ctx.parenStack.empty && _ctx.parenStack.back == MixedBlockBegin, "Unexpected: "  ~ (cast(LexemeType) typeIndex).to!string );
					if( !_ctx.statesStack.empty )
						_ctx.statesStack.popBack();
				}
			
				break;
			}
			case LBrace:
			{
				
				break;
			}
			case RBrace:
			{
				if( _ctx.state == ContextState.CodeContext )
				{
					assert( !_ctx.parenStack.empty && _ctx.parenStack.back == LBrace, "Unexpected: "  ~ (cast(LexemeType) typeIndex).to!string );
					//_ctx.statesStack.popBack();
				}
				break;
			}
			case LParen:
			{
			
				break;
			}
			case RParen:
			{
				if( _ctx.state == ContextState.CodeContext )
				{
					assert( !_ctx.parenStack.empty && _ctx.parenStack.back == LParen, "Unexpected: "  ~ (cast(LexemeType) typeIndex).to!string );
					//_ctx.statesStack.popBack();
				}
				break;
			}
			case LBracket:
			{
			
				break;
			}
			case RBracket:
			{
				if( _ctx.state == ContextState.CodeContext )
				{
					assert( !_ctx.parenStack.empty && _ctx.parenStack.back == LBracket, "Unexpected: "  ~ (cast(LexemeType) typeIndex).to!string );
					//_ctx.statesStack.popBack();
				}
				break;
			}
			case RawDataBlockBegin:
			{	
				if( _ctx.state == ContextState.CodeContext )
				{
					_ctx.statesStack ~= ContextState.RawDataContext;
				
				}
				else if( _ctx.state == ContextState.MixedContext )
				{
					_ctx.statesStack ~= ContextState.RawDataContext;
				
				}
				break;
			}
			case RawDataBlockEnd:
			{
				if( _ctx.state == ContextState.RawDataContext )
				{
					assert( !_ctx.parenStack.empty && _ctx.parenStack.back == RawDataBlockBegin, "Unexpected: "  ~ (cast(LexemeType) typeIndex).to!string );
					if( !_ctx.statesStack.empty )
						_ctx.statesStack.popBack();
				}
				break;
			}
			default:
				break;
		}
		
		if( _front.info.isRightParen )
		{
			if( !_ctx.parenStack.empty )
			{
				int backParen = _ctx.parenStack.back;
				
				if( backParen == matchingParens[_front.info.typeIndex] )
				{
					_ctx.parenStack.popBack();
				}
				else
					assert( false, "Expected matching parenthesis!!!" );
			}
		}
		else if( _front.info.isLeftParen )
			_ctx.parenStack ~= front.info.typeIndex;
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
	
	@property auto save()
	{
		auto thisCopy = Lexer!(S, c)(sourceRange);
		thisCopy.currentRange = this.currentRange.save;
		thisCopy.lexemes = this.lexemes.dup;
	
		thisCopy._ctx = this._ctx;
		thisCopy._front = this._front;
		
		return thisCopy;
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
		
		return parseFront(parsedRange, _ctx);
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
		mixedBlockBegin,
		mixedBlockEnd,
		exprBlockBegin
	];

	static LexemeT parseData(ref SourceRange source, ref const(LexRule) rule)
	{
		writeln("lexer.parseData");
		
		SourceRange parsedRange = source.save;
		
		import std.algorithm;
		
		LexemeT lex;
		
		while( !parsedRange.empty )
		{
			foreach( ref notText; notTextLexemes )
			{
				if( parsedRange.save.match(notText) )
				{
					return extractLexeme(source, parsedRange, rule.lexemeInfo);
				}
			}
			parsedRange.popFront();
		}
		
		return extractLexeme(source, parsedRange, rule.lexemeInfo);
	}
	
	static LexemeT parseRawData(ref SourceRange source, ref const(LexRule) rule)
	{
		import std.algorithm: startsWith;
		
		SourceRange parsedRange = source.save;
		
		if( parsedRange.empty )
			return createLexemeAt(source, LexemeType.EndOfFile);
		
		if( !parsedRange.match(rawDataBlockBegin) )
			return createLexemeAt(source);
		
		while( !parsedRange.empty )
		{
			if( parsedRange.match(rawDataBlockEnd) )
				return extractLexeme(source, parsedRange, rule.lexemeInfo);
				
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