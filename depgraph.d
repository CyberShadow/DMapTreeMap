import std.array;
import std.exception;
import std.file;
import std.path;
import std.regex;
import std.stdio;
import std.string;

import ae.sys.cmd;

import dsym;

void main(string[] args)
{
	enforce(args.length == 2, "Usage: "~args[0]~" input.asm");

	enum symbols = regex(`<([^>+]+)(\+[^>]+)?>`);
	string[string] syms;
	bool[string][string] deps, rdeps;

	struct Node
	{
		Node[string] children;
		string[][string] leaves;
	}
	Node root;

	void addSym(string sym)
	{
		if (sym !in syms)
		{
			string dem;
			auto segments = parseDSymbol(sym, dem);
			auto node = &root;
			foreach (s; segments[0..$-1])
			{
				auto p = s in node.children;
				if (!p)
				{
					node.children[s] = Node();
					p = s in node.children;
				}
				node = p;
			}
			node.leaves[segments[$-1]] ~= sym;
			syms[sym] = dem;
		}
	}

	bool symOk(string sym)
	{
		return sym != "_GLOBAL_OFFSET_TABLE_"
			&& sym != "_init"
			&& !sym.startsWith("_TMP");
	}

	string currentSymbol;
	foreach (line; readText(args[1]).splitLines)
	{
		if (line.endsWith(">:"))
		{
			currentSymbol = line[line.indexOf("<")+1 .. $-2];
			addSym(currentSymbol);
		}
		else
		if (line.indexOf('<') >= 0)
		{
			foreach (m; match(line, symbols))
			{
				auto targetSymbol = m.captures[1];
				if (currentSymbol != targetSymbol && symOk(currentSymbol) && symOk(targetSymbol))
				{
					deps[currentSymbol][targetSymbol] = true;
					rdeps[targetSymbol][currentSymbol] = true;
					addSym(targetSymbol);
				}
			}
		}
	}

	void dumpDot(string fn)
	{
		File f;

		string id(string sym)
		{
			return `"` ~ sym.replace(`"`, `\"`) ~ `"`;
		}

		void dumpNode(ref Node node, string path, string indent = "\t")
		{
			foreach (name, ref child; node.children)
			{
				auto childPath = path ~ "_" ~ name;
				auto childIndent = indent ~ "\t";
				f.writeln(indent, `subgraph `, id(childPath), ` {`);
				f.writeln(childIndent, `graph [label=`, id(name), `]`);
				dumpNode(child, childPath, childIndent);
				f.writeln(indent, `}`);
			}
			foreach (name, syms; node.leaves)
				foreach (sym; syms)
					f.writeln(indent, id(sym), " [label=", id(name), "]");
		}

		f.open(fn, "wt");
		f.writeln("digraph {");
		dumpNode(root, "cluster");
		foreach (from, tos; deps)
			foreach (to; tos.byKey())
				f.writeln("\t", id(from), "->", id(to));
		f.writeln("}");
		f.close();
	}

	void dumpHtml(string fn)
	{
		File f;

		f.open(fn, "wt");
		f.writeln(`<p><a href="`, setExtension(baseName(fn), "dot"), `">GraphViz .dot file</a></p><hr>`);
		foreach (sym; syms.keys.sort)
		{
			f.writeln(`<h3 id="`, sym, `">`, syms[sym], `</h3>`);
			auto p = sym in rdeps;
			if (p && p.length)
			{
				f.writeln(`<p>Used by:</p>`);
				f.writeln(`<ul>`);
				foreach (sym2; p.byKey())
					f.writeln(`<li><a href="#`, sym2, `">`, syms[sym2], `</a></li>`);
				f.writeln(`</ul>`);
			}

			p = sym in deps;
			if (p && p.length)
			{
				f.writeln(`<p>Uses:</p>`);
				f.writeln(`<ul>`);
				foreach (sym2; p.byKey())
					f.writeln(`<li><a href="#`, sym2, `">`, syms[sym2], `</a></li>`);
				f.writeln(`</ul>`);
			}
		}
		f.close();
	}

	dumpDot (setExtension(args[1], "dot"));
	dumpHtml(setExtension(args[1], "html"));
}
