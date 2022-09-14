local prettyPrint, fs, uv = require('pretty-print'), require("fs"), require("uv")

local deboguer = args[3] == "true"

prettyPrint.loadColors(16)

local write

if deboguer then
	write = io.write
else
	write = function()end
end

local function format(str)
	return string.format(" %02x", string.byte(str))
end

local processedBytes, bytes, removedBytes, commentedBytes, replacedBytes, files = 0, 0, 0, 0, 0, 0

local debuts, debut = uv.gettimeofday()

local nonSpacePost = {" ", "(", ")", "[", "]", "{", "}", ",", ".", "=", "~", "<", ">", "+", "-", "*", "/", "\"", "\t", "\n", "\r"}

function compress( file )
	local dans, dehors = io.open( file, "rb" ), io.open( file:sub(1, -5) .. "_short.lua", "wb" )
	local prev, prev_escaped, curr, inString
	local commented = 0
	local next = dans:read(1)
	repeat
		curr = next next = dans:read(1)
		if not curr then break end
		local didWrite, wrote = false, nil
		if commented == 0 and not inString then
			if curr == "-" and next == "-" then
				commented = 1
			end
		end
		if commented == 1 and (curr == "\n" or curr == "\r") then
			commented = 0
		end
		if commented == 0 then
		local toString = curr:match("[\"']")
		if toString and not prev_escaped then
			if inString == toString then
				inString = nil
			elseif not inString then
				inString = toString
			end
		end
		if inString then
			dehors:write(curr)
			wrote = curr
			didWrite = true
		else
			if curr == " " or curr == "\t" or curr == "\n" or curr == "\r" then
				local toWrite = true
				for _,v in ipairs(nonSpacePost) do
					if prev == v then
						toWrite = false
						break
					end
					if next == v then
						toWrite = false
						break
					end
				end
				if toWrite then
					dehors:write(" ")
					wrote = " "
					didWrite = true
				end
			else
				dehors:write(curr)
				wrote = curr
				didWrite = true
			end
		end
		if didWrite then
			prev = curr
		end
		if curr == "\\" and not prev_escaped then
			prev_escaped = true
		else
			prev_escaped = false
		end
		end
		if wrote == curr then
			bytes = bytes + 1
			if inString then
				write(prettyPrint.colorize("string", format(wrote)))
			else
				write(format(wrote))
			end
		elseif wrote then
			write(prettyPrint.colorize("boolean", format(curr)))
			bytes = bytes + 1
			replacedBytes = replacedBytes + 1
		else
			if commented ~= 0 then
				write(prettyPrint.colorize("sep", format(curr)))
				commentedBytes = commentedBytes + 1
			else
				write(prettyPrint.colorize("err", format(curr)))
				removedBytes = removedBytes + 1
			end
		end
		processedBytes = processedBytes + 1
	until not next
	dans:close() dehors:close()
end

function scan(dir)
	for file,taper in fs.scandirSync(dir) do
		if taper == "directory" then
			scan(dir .. "\\" .. file)
		elseif file:sub(-4,-1) == ".lua" then
			io.write("\n\n", prettyPrint.colorize("table", dir .. "\\" .. file), "\n")
			files = files + 1
			compress( dir .. "\\" .. file )
		end
	end
end

scan(args[2])

local fins, fin = uv.gettimeofday()

io.write("\n\n", prettyPrint.colorize("table", "files: " .. files), 
	"\nprocessed: ", processedBytes,
	"\nbytes: ", bytes, "\n",
	prettyPrint.colorize("string", "removed: " .. removedBytes + commentedBytes), "\n\t",
	prettyPrint.colorize("sep", "comment: " .. commentedBytes), "\n\t",
	prettyPrint.colorize("err", "whitespace: " .. removedBytes), "\n",
	prettyPrint.colorize("boolean", "replaced: " .. replacedBytes), "\n\n",
	"duration: ", math.floor( (fin - debut) / 1e+3 ) / 1e+3 + (fins - debuts), "s\n\n"
)
