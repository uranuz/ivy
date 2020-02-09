module ivy.ast.consts;

enum LiteralType
{
	NotLiteral,
	Undef,
	Null,
	Boolean,
	Integer,
	Floating,
	String,
	Array,
	AssocArray
}

enum Operator
{
	None = 0,

	//Unary arithmetic
	UnaryPlus = 1,
	UnaryMin,

	//Binary arithmetic
	Add,
	Sub,
	Mul,
	Div,
	Mod,

	//Concatenation
	Concat,

	//Logical operators
	Not, //Unary
	And,
	Or,
	Xor,

	//Compare operators
	Equal,
	NotEqual,
	LT,
	GT,
	LTEqual,
	GTEqual
}