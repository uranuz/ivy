module ivy.node;

import ivy.common;
import ivy.node_visitor;

interface IDeclNode
{
	@property {
		IDeclNode parent();
		IDeclNode[] children();
		
		Location location() const;             // Location info for internal usage
		PlainLocation plainLocation() const;   // Location for user info
		ExtendedLocation extLocation() const;  // Extended location info
		LocationConfig locationConfig() const; // Configuration of available location data

		string kind();
	}
	
	@property {
		void parent(IDeclNode node);
	}
	
	void accept(AbstractNodeVisitor visitor);

	// string toString();
}

enum LiteralType { NotLiteral, Null, Boolean, Integer, Floating, String, Array, AssocArray };

interface IExpression: IDeclNode
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

interface ILiteralExpression: IExpression
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

interface IOperatorExpression: IExpression
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

interface INameExpression: IExpression
{
	@property string name();
}

interface IKeyValueAttribute: IDeclNode
{
	@property {
		string name();
		IDeclNode value();
	}

}

interface IAssocArrayPair: IExpression
{
	@property {
		string key();
		IExpression value();
	}
}

interface IStatement: IDeclNode
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
	
	//IStatement opIndex(size_t index);
}

interface IStatementRange
{
	@property IStatement front();
	void popFront();
	
	@property IStatement back();
	void popBack();
	
	bool empty();
	//@property size_t length();
	
	@property IStatementRange save();
	
	IStatement opIndex(size_t index);

}

interface IAttributesRange
{
	@property IDeclNode front();
	void popFront();
	
	@property IDeclNode back();
	void popBack();
	
	@property bool empty();
	//@property size_t length();
	
	@property IAttributesRange save();
	
	IDeclNode opIndex(size_t index);
}

interface IDirectiveStatement: IStatement
{
	@property {
		string name(); //Returns name of the first subdirective
	}
	
	//@property size_t length();
	
	//@property IDirectiveSection first();
	//@property IDirectiveSection last();

	IAttributesRange opSlice();
	IAttributesRange opSlice(size_t begin, size_t end);
	
	//IDirectiveSectionStatement opIndex(size_t index);
	//IDirectiveSectionStatementRange filterByName(string name);
}