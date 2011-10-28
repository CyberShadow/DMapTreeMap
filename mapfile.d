module mapfile; // salvaged from Diamond

import std.file;
import std.string;
import std.algorithm : sort;

import ae.utils.text;

struct Symbol
{
	ulong address;
	string name;
}

final class MapFile
{
	this(string fileName)
	{
		auto lines = splitAsciiLines(cast(string)read(fileName));
		bool parsing = false;
		foreach (line; lines)
		{
			// OPTLINK format
			if (parsing)
			{
				if (line.length > 30 && line[5]==':' && line[17]==' ')
				{
					// 0002:00078A44       _D5win327objbase11IsEqualGUIDFS5win328basetyps4GUIDS5win328basetyps4GUIDZi 0047CA44
					Symbol s;
					auto line2 = line[21..$];
					s.name = line2[0..line2.indexOf(' ')];
					s.address = fromHex(line2[$-8..$]);
					symbols ~= s;
				}
			}
			else
				if (line.indexOf("Publics by Value")>0)
					parsing = true;
				
			// LD format
			auto stripped = line.strip();
			//                 0x00000000080eaa10                _D20TypeInfo_E2WA6Nation6__initZ
			if (stripped.length>10 && stripped[0..2]=="0x")
			{
				auto words = stripped.split();
				if (words.length != 2)
					continue;
				Symbol s;
				s.name = words[1];
				s.address = fromHex!ulong(words[0][2..$]);
				symbols ~= s;
			}
		}
		sort!q{a.address < b.address}(symbols);
	}

	Symbol[] symbols;
}
