import org.antlr.v4.runtime.*;
import org.antlr.v4.runtime.tree.*;

public class Main {
    public static void main(String[] args) throws Exception {
        // 1. Get filename from args or use default
        String inputFile = "example.hc";
        if (args.length > 0) inputFile = args[0];

        // 2. Read file into ANTLR input stream
        CharStream input = CharStreams.fromFileName(inputFile);

        // 3. Create lexer and tokenize input
        HypercodeLexer lexer = new HypercodeLexer(input);
        CommonTokenStream tokens = new CommonTokenStream(lexer);

        // 4. Parse token stream with HypercodeParser
        HypercodeParser parser = new HypercodeParser(tokens);
        ParseTree tree = parser.hypercode();

        // 5. Print the tree using LISP-like notation
        System.out.println(tree.toStringTree(parser));
    }
}
