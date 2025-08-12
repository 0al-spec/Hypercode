lexer grammar HypercodeLexer;

@header {
import java.util.Stack;
}
@members {
  private Stack<Integer> indentStack = new Stack<>() {{
    push(0);
  }};
  private java.util.LinkedList<Token> pendingTokens = new java.util.LinkedList<>();
  private boolean atStartOfLine = true;

  @Override
  public Token nextToken() {
    if (!pendingTokens.isEmpty()) return pendingTokens.poll();

    Token next = super.nextToken();

    if (next.getType() == NEWLINE) {
      atStartOfLine = true;
      return next;
    }

    if (next.getType() == INDENT_WS && atStartOfLine) {
      int indent = next.getText().length();
      int prev = indentStack.peek();

      if (indent > prev) {
        indentStack.push(indent);
        pendingTokens.add(createToken(INDENT, next));
      } else {
        while (indent < prev) {
          pendingTokens.add(createToken(DEDENT, next));
          indentStack.pop();
          prev = indentStack.peek();
        }
      }

      atStartOfLine = false;
      return nextToken(); // skip INDENT_WS manually
    }

    atStartOfLine = false;

    if (next.getType() == Token.EOF) {
        int prev = indentStack.peek();
        while (prev > 0) {
            pendingTokens.add(createToken(DEDENT, next));
            indentStack.pop();
            prev = indentStack.peek();
        }
        pendingTokens.add(next); // push EOF last
        return pendingTokens.poll();
    }

    return next;
  }

  private Token createToken(int type, Token base) {
    return _factory.create(
      new Pair<>(this, this._input),
      type, "", Token.DEFAULT_CHANNEL,
      base.getStartIndex(), base.getStopIndex(),
      base.getLine(), base.getCharPositionInLine()
    );
  }

  @Override
  public void reset() {
    super.reset();
    this.indentStack.clear();
    this.indentStack.push(0);
    this.pendingTokens.clear();
    this.atStartOfLine = true;
  }
}

// These are never matched directly, only inserted from @members
INDENT: '<INDENT>';
DEDENT: '<DEDENT>';

// Track indentation at line start
INDENT_WS: [ \t]+ ;

// Regular skip whitespace
SKIP_WS: [ \t]+ -> skip;

NEWLINE: ('\r'? '\n')+ ;

IDENTIFIER: [a-zA-Z] [a-zA-Z0-9_-]* ;

DOT: '.';
HASH: '#';
