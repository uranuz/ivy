module ivy.common;

// Base class for Ivy exceptions
class IvyException: Exception
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow {
		super(msg, file, line, next);
	}
}

enum LogInfoType
{
	info, // Regular log message for debug or smth
	warn, // Warning about strange conditions
	error, // Regular error, caused by wrong template syntax, wrong user input or smth
	internalError // Error that caused by wrong Ivy implementation or smth that should never happens
};

// Struct consolidating info for logging
struct LogInfo
{
	string msg; // Log message
	LogInfoType type; // Kind of log event
	string sourceFuncName; // D function name where log event happens
	string sourceFileName; // D source file name where log event happens
	size_t sourceLine; // D code source line where log event happens
	string processedFile; // Path or name to processed file
	size_t processedLine; // Line number of processed file where log event happens
	string processedText; // Short fragment of processed text where log event happens
}

string getShortFuncName(string func)
{
	import std.algorithm: splitter;
	import std.range: retro, take;
	import std.array: array, join;

	return func.splitter('.').retro.take(2).array.retro.join(".");
}

mixin template LogerProxyImpl(ExceptionType, bool isDebugMode = false)
{
	string func;
	string file;
	int line;

	string genericWrite(T...)(LogInfoType logInfoType, T data)
	{
		import std.format: formattedWrite;
		import std.array: appender;
		auto logMessage = appender!string();
		foreach(item; data) {
			formattedWrite(logMessage, "%s", item);
		}

		this.sendLogInfo(logInfoType, logMessage.data()); /// This method need to be implemented to actualy send log message
		return logMessage.data();
	}

	// Write regular log message
	void write(T...)(T data) {
		static if(isDebugMode) {
			genericWrite(LogInfoType.info, data);
		}
	}

	// Write warning message
	void warn(T...)(T data) {
		genericWrite(LogInfoType.warn, data);
	}

	// Write error message and throw exception
	void error(T...)(T data) {
		throw new ExceptionType(genericWrite(LogInfoType.error, data));
	}

	// Write internal error message and throw exception
	void internalError(T...)(T data) {
		throw new ExceptionType(genericWrite(LogInfoType.internalError, data));
	}

	// Test assertion. If assertion is false then logs internal error and throws
	void internalAssert(T...)(T data) {
		assert( data[0], genericWrite(LogInfoType.internalError, data) );
	}
}

/+
enum LocationFlag
{
	None = 0,
	WithGraphemeIndex = 1 << 0,
	WithLineIndex = 1 << 1,
	WithColumnIndex = 1 << 2,
	WithGraphemeColumnIndex = 1 << 3,
	WithSize = 1 << 4
}

private string generateLocationConfigProperties(string[] propNames)
{
	string codeString;
	codeString ~= 
"	@property const 
	{
";
	
	foreach( name; propNames )
	{
		codeString ~= 
"		bool with" ~ name ~ "()
		{
			return cast(bool)( flags & LocationFlag.With" ~ name ~ " );
		}
";
	}
	
	codeString ~= 
"	}

";

	codeString ~= 
"	@property 
	{
";
	foreach( name; propNames )
	{
		codeString ~= 
"		void with" ~ name ~ "(bool value)
		{
			flags = flags & ~LocationFlag.With" ~ name ~ ";
			if( value )
				flags |= LocationFlag.With" ~ name ~ ";
		}

";
	}
	codeString ~= 
"	}
";
	return codeString;
}

struct LocationConfig
{
	import std.typecons: BitFlags;
	
	BitFlags!LocationFlag flags;
	
	enum propCode = generateLocationConfigProperties(
		[ "GraphemeIndex", "LineIndex", "ColumnIndex", "GraphemeColumnIndex", "Size" ]
	);
	
	mixin( propCode );
}

+/

struct LocationConfig
{
	bool withGraphemeIndex = true;
	bool withLineIndex = true;
	bool withColumnIndex = true;
	bool withGraphemeColumnIndex = true;
	bool withSize = true;
}

enum IndentStyle: char { none = 0, tab = '\t', space = ' ' };

struct Location
{
	string fileName;  // Name of source file
	size_t index;     // Start code unit index or grapheme index (if available)
	size_t length;    // Length of source text in code units or in graphemes (if available)
	size_t indentCount;
	IndentStyle indentStyle;
}

struct PlainLocation
{
	string fileName;
	size_t lineIndex;
	size_t columnIndex;
}

struct ExtendedLocation
{
	string fileName; // File name for this source
	size_t index; // Index of UTF code unit that starts element
	size_t length; // Length of element in code units
	size_t graphemeIndex; // Index of grapheme that starts element
	size_t graphemeLength; // Length of element in graphemes
	size_t lineIndex; // Index of line at which element starts
	size_t lineCount; // Number of lines in element (number of CR LF/ CR / LF exactly)
	size_t columnIndex; // Index of code unit in line that starts element
	size_t graphemeColumnIndex; // Index of grapheme in line that starts element
	size_t indentCount; // Line indent count for element
	IndentStyle indentStyle; // Determines if element indented with tabs or spaces
}

struct CustomizedLocation(LocationConfig c)
{
	enum config = c;
	
	string fileName;
	
	size_t index;
	
	static if( config.withSize )
		size_t length;
		
	static if( config.withGraphemeIndex )
	{
		size_t graphemeIndex;
		
		static if( config.withSize )
			size_t graphemeLength;
	}
	
	static if( config.withLineIndex )
	{
		size_t lineIndex;
		
		static if( config.withSize )
			size_t lineCount;
		
		static if( config.withColumnIndex )
			size_t columnIndex;
		
		static if( config.withGraphemeColumnIndex )
			size_t graphemeColumnIndex;
	}
	
	size_t indentCount;
	IndentStyle indentStyle;
	
	Location toLocation() const
	{
		Location loc;
		loc.fileName = fileName;
		loc.index = index;
		loc.indentCount = indentCount;
		loc.indentStyle = indentStyle;
		
		static if( config.withSize )
			loc.length = length;
			
		return loc;
	}
	
	PlainLocation toPlainLocation() const
	{
		PlainLocation loc;
		loc.fileName = fileName;
		
		static if( config.withLineIndex )
			loc.lineIndex = lineIndex;
	
		static if( config.withLineIndex && config.withGraphemeColumnIndex )
			loc.columnIndex = graphemeColumnIndex;
		else static if( config.withLineIndex && config.withColumnIndex )
			loc.columnIndex = columnIndex;
		else static if( config.withGraphemeIndex )
			loc.columnIndex = graphemeIndex;
		else
			loc.columnIndex = index;
			
		return loc;
	}
	
	ExtendedLocation toExtendedLocation() const
	{
		ExtendedLocation loc;
		
		loc.fileName = fileName;
		loc.index = index;		
		
		static if( config.withSize )
			loc.length = length;
		
		static if( config.withGraphemeIndex )
		{
			loc.graphemeIndex = graphemeIndex;
			
			static if( config.withSize )
				loc.graphemeLength = graphemeLength;
		}
		
		static if( config.withLineIndex )
		{
			loc.lineIndex = lineIndex;
			
			static if( config.withSize )
				loc.lineCount = lineCount;
			
			static if( config.withColumnIndex )
				loc.columnIndex = columnIndex;
			
			static if( config.withGraphemeColumnIndex )
				loc.graphemeColumnIndex = graphemeColumnIndex;
		}
		
		loc.indentCount = indentCount;
		loc.indentStyle = indentStyle;
		
		return loc;
	}
	
}

import ivy.node : IvyNode;
import ivy.node_visitor : AbstractNodeVisitor;

mixin template BaseDeclNodeImpl(LocationConfig c)
{
	enum locConfig = c;
	alias CustLocation = CustomizedLocation!locConfig;
	
	private IvyNode _parentNode;
	private CustLocation _location;
	
	public @property override
	{ 
		IvyNode parent()
		{
			return _parentNode;
		}
	
		Location location() const
		{
			return _location.toLocation();
		}
		
		PlainLocation plainLocation() const
		{
			return _location.toPlainLocation();
		}
		
		ExtendedLocation extLocation() const
		{
			return _location.toExtendedLocation();
		}
		
		LocationConfig locationConfig() const
		{
			return _location.config;
		}
	}
	
	public @property override
	{
		void parent(IvyNode node)
		{
			_parentNode = node;
		}
	}
	
	public override void accept(AbstractNodeVisitor visitor)
	{
		visitor.visit(this);
	}
}

