module ivy.node;

import ivy.common;
import ivy.node_visitor;

interface IvyNode
{
	@property {
		IvyNode parent();
		IvyNode[] children();
		
		Location location() const;             // Location info for internal usage
		PlainLocation plainLocation() const;   // Location for user info
		ExtendedLocation extLocation() const;  // Extended location info
		LocationConfig locationConfig() const; // Configuration of available location data

		string kind();
	}
	
	@property {
		void parent(IvyNode node);
	}
	
	void accept(AbstractNodeVisitor visitor);

	// string toString();
}

enum LiteralType { NotLiteral, Null, Boolean, Integer, Floating, String, Array, AssocArray };

interface IExpression: IvyNode
{
	// bool checkValue();
	// bool checkScalar();
	// bool checkBoolean();
	// bool checkIntegral();
	// bool checkFloating();
	// bool checkArithmetic();
	// bool checkString();
	@property {
		IStatement asStatement();
		
		LiteralType literalType();
		
		bool isScalar();
		bool isNullExpr();
	}

	bool toBoolean();
	int toInteger();
	double toFloating();
	string toStr();
}

interface IPlainExpression: IExpression {


}

interface ILiteralExpression: IPlainExpression
{


}


enum Operator {
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

interface IOperatorExpression: IPlainExpression
{
	@property const {
		int operatorIndex();
	}
}

interface IUnaryExpression: IOperatorExpression
{
	@property
	{
		IExpression expr();
	}

}

interface IBinaryExpression: IOperatorExpression
{
	@property {
		IExpression leftExpr();
		IExpression rightExpr();
	}

}

interface IIdentifier
{
	@property {
		string name();
	}
}


class Identifier: IIdentifier
{

private:
	string _fullName;
	
	
public:
	this( string fullName )
	{
		_fullName = fullName;
	}
	
	override @property {
		string name()
		{
			return _fullName;
		}
	}

}

interface INameExpression: IPlainExpression
{
	@property string name();
}

interface IKeyValueAttribute: IvyNode
{
	@property {
		string name();
		IvyNode value();
	}

}

interface IAssocArrayPair: IvyNode
{
	@property {
		string key();
		IExpression value();
	}
}

interface IStatement: IvyNode
{
	@property {
		bool isCompoundStatement();
		ICompoundStatement asCompoundStatement();
		bool isDirectiveStatement();
		IDirectiveStatement asDirectiveStatement();
	}
}

interface IDataFragmentStatement: IStatement
{
	@property {
		string data();
	}
}

interface ICompoundStatement: IStatement
{
	//@property size_t length();
	
	//@property IStatement first();
	//@property IStatement last();
	
	IStatementRange opSlice();
	IStatementRange opSlice(size_t begin, size_t end);

	bool isList() @property;
	
	//IStatement opIndex(size_t index);
}

interface IStatementRange
{
	@property IStatement front();
	void popFront();
	
	@property IStatement back();
	void popBack();
	
	@property bool empty();
	//@property size_t length();
	
	@property IStatementRange save();
	
	IStatement opIndex(size_t index);
}

interface IDirectiveStatementRange: IStatementRange
{
	// Covariant overrides
	override @property IDirectiveStatement front();
	override @property IDirectiveStatement back();
	override @property IDirectiveStatementRange save();
	override IDirectiveStatement opIndex(size_t index);
}

interface ICodeBlockStatement: ICompoundStatement
{
	override IDirectiveStatementRange opSlice();
	override IDirectiveStatementRange opSlice(size_t begin, size_t end);
}

interface IAttributeRange
{
	@property IvyNode front();
	void popFront();
	
	@property IvyNode back();
	void popBack();
	
	@property bool empty();
	//@property size_t length();
	
	@property IAttributeRange save();
	
	IvyNode opIndex(size_t index);
}

interface IDirectiveStatement: IStatement
{
	@property {
		string name(); //Returns name of directive
	}

	IAttributeRange opSlice();
	IAttributeRange opSlice(size_t begin, size_t end);
}